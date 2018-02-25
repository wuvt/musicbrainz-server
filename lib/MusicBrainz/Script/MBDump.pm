package MusicBrainz::Script::MBDump;

use DBDefs;
use File::Copy qw( copy );
use File::Path qw( make_path );
use File::Spec::Functions qw( catfile );
use File::Temp qw( tempdir );
use Moose;
use MusicBrainz::Script::Utils qw( log );
use String::ShellQuote qw( shell_quote );
use Time::HiRes qw( gettimeofday tv_interval );

has c => (
    handles => ['sql', 'dbh'],
    is => 'ro',
    isa => 'MusicBrainz::Server::Context',
    required => 1,
);

has keep_files => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

# overrides the user-specified keep_files
has erase_files_on_exit => (
    is => 'rw',
    isa => 'Bool',
    default => 1,
);

has tmp_dir => (
    is => 'rw',
    isa => 'Str',
    default => '/tmp',
);

has export_dir => (
    is => 'rw',
    isa => 'Str',
    default => '',
);

has output_dir => (
    is => 'rw',
    isa => 'Str',
    default => '.',
);

has compression => (
    is => 'rw',
    isa => 'Str',
    default => 'bzip2',
);

has replication_sequence => (
    is => 'ro',
    isa => 'Maybe[Int]',
);

sub BUILD { shift->begin_dump }

sub begin_dump {
    my ($self) = @_;

    make_path($self->output_dir);

    my $export_dir = tempdir(
        'mbexport-XXXXXX', DIR => $self->tmp_dir, CLEANUP => 0);
    mkdir "$export_dir/mbdump" or die $!;
    log("Exporting to $export_dir");
    $self->export_dir($export_dir);

    # Write the TIMESTAMP file.
    # This used to be free text; now it's parseable. It contains a PostgreSQL
    # TIMESTAMP WITH TIME ZONE expression.
    my $now = $self->sql->select_single_value('SELECT NOW()');
    $self->write_file('TIMESTAMP', "$now\n");

    # Write the README file.
    $self->copy_readme();

    my $replication_control = $self->sql->select_single_row_hash(
        'SELECT current_replication_sequence, current_schema_sequence
           FROM replication_control'
    );
    my $replication_sequence = $self->replication_sequence //
        $replication_control->{current_replication_sequence};
    my $schema_sequence = $replication_control->{current_schema_sequence};
    my $dbdefs_schema_sequence = DBDefs->DB_SCHEMA_SEQUENCE;
    $schema_sequence
        or die "Don't know what schema sequence number we're using";
    $schema_sequence == $dbdefs_schema_sequence
        or die "Stored schema sequence ($schema_sequence) does not match " .
               "DBDefs->DB_SCHEMA_SEQUENCE ($dbdefs_schema_sequence)";

    # Write the SCHEMA_SEQUENCE and REPLICATION_SEQUENCE files. Again, this
    # is parseable - it's just an integer.
    $self->write_file('SCHEMA_SEQUENCE', "$schema_sequence\n");
    $self->write_file('REPLICATION_SEQUENCE', "$replication_sequence\n");
}

our $readme_text = <<'EOF';
The files in this directory are snapshots of the MusicBrainz database,
in a format suitable for import into a PostgreSQL database. To import
them, you need a compatible version of the MusicBrainz server software.
EOF

sub copy_readme() {
    my ($self) = @_;
    $self->write_file('README', $readme_text);
}

sub gpg_sign {
    my ($self, $file_to_be_signed) = @_;

    my $sign_with = DBDefs->GPG_SIGN_KEY;
    return unless $sign_with;

    system 'gpg',
           '--default-key', $sign_with,
           '--detach-sign',
           '--armor',
           $file_to_be_signed;

    if ($? != 0) {
        print STDERR "Failed to sign $file_to_be_signed\n",
                     "GPG returned $?\n";
    }
}

sub make_tar {
    my ($self, $tar_file, @files) = @_;

    # These ones go first, so MBImport can quickly find them.
    unshift @files, qw(
        TIMESTAMP
        COPYING
        README
        REPLICATION_SEQUENCE
        SCHEMA_SEQUENCE
    );

    my $t0 = [gettimeofday];
    my $output_dir = $self->output_dir;
    my $compression = $self->compression;
    my $_compression = $compression;

    if ($compression eq 'xz') {
        $compression = '';
        $tar_file =~ s/\.xz$//;
    }

    log("Creating $tar_file");
    chomp (my $tar_bin = `which gtar` || `which tar`);
    system $tar_bin,
           '-C', $self->export_dir,
           ($compression ? "--$compression" : ()),
           '--create',
           '--verbose',
           '--file', "$output_dir/$tar_file",
           '--',
           @files;

    $? == 0 or die "Tar returned $?";
    log(sprintf "Tar completed in %d seconds\n", tv_interval($t0));

    # This is done separately instead of using --xz in order to take
    # advantage of the multithreading option.
    if ($_compression eq 'xz') {
        $t0 = [gettimeofday];

        log("Compressing $tar_file with xz");

        my $tar_path = catfile($output_dir, $tar_file);
        system qw( xz -T 0 -k -z ), $tar_path;
        $? == 0 or die "xz returned $?";

        log(sprintf "xz completed in %d seconds\n", tv_interval($t0));

        unlink $tar_path;
        $tar_file .= '.xz';
    }

    $self->gpg_sign("$output_dir/$tar_file");
}

sub copy_file {
    my ($self, $src_path, $dst_path) = @_;

    my $export_dir = $self->export_dir;
    ($export_dir && -d $export_dir) or die 'No export directory';
    $dst_path = (defined $dst_path && $dst_path ne '') ?
        catfile($export_dir, $dst_path) : $export_dir;
    copy($src_path, $dst_path);
}

sub write_file {
    my ($self, $file, $contents) = @_;

    open(my $fh, '>' . $self->export_dir . "/$file") or die $!;
    print $fh $contents or die $!;
    close $fh or die $!;
}

sub DEMOLISH {
    my ($self) = @_;

    my $export_dir = $self->export_dir;
    if (
        $self->erase_files_on_exit &&
        !$self->keep_files &&
        defined($export_dir) &&
        -d $export_dir &&
        -d "$export_dir/mbdump"
    ) {
        # Buffer this so concurrent processes don't overlap.
        my $log_output .= "Disk space just before erasing $export_dir:\n";
        $log_output .= qx(/bin/df -m 2>&1);
        $log_output .= "Erasing $export_dir\n";
        my $quoted_dir = shell_quote($export_dir);
        $log_output .= qx(/bin/rm -rf $quoted_dir 2>&1);
        log($log_output);
    }
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;
