FROM ubuntu:xenial

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install --no-install-suggests --no-install-recommends -y sudo wget && \
    rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash musicbrainz

WORKDIR /home/musicbrainz/musicbrainz-server
RUN mkdir -p /home/musicbrainz/musicbrainz-server && \
    chown -R musicbrainz:musicbrainz /home/musicbrainz/musicbrainz-server

COPY cpanfile cpanfile.snapshot ./

ENV PERL_CARTON_PATH /home/musicbrainz/carton-local
ENV PERL_CPANM_OPT --notest --no-interactive

RUN apt-get update && \
    apt-get install --no-install-suggests --no-install-recommends -y build-essential libdb-dev libexpat1-dev libicu-dev libperl-dev libpq-dev libssl-dev libxml2-dev ca-certificates libdb5.3 libexpat1 libicu55 libpq5 libssl1.0.0 perl postgresql-client-9.5 postgresql-server-dev-9.5 && \
    rm -rf /var/lib/apt/lists/* && \
    wget -q -O - https://cpanmin.us | perl - App::cpanminus && \
    cpanm Carton && \
    mkdir -p $PERL_CARTON_PATH && \
    chown -R musicbrainz:musicbrainz $PERL_CARTON_PATH && \
    sudo -E -H -u musicbrainz carton install --deployment && \
    apt-get purge --auto-remove -y build-essential libdb-dev libexpat1-dev libicu-dev libperl-dev libpq-dev libssl-dev libxml2-dev

COPY admin/ admin/
COPY app.psgi entities.json ./
COPY bin/ bin/
COPY docker/scripts/mbs_constants.sh /etc/
COPY lib/ lib/

RUN mkdir -p /home/musicbrainz/musicbrainz-server && \
    chown -R musicbrainz:musicbrainz /home/musicbrainz/musicbrainz-server && \
    ln -s /data/config/DBDefs.pm /home/musicbrainz/musicbrainz-server/lib/DBDefs.pm

COPY docker/musicbrainz-webservice/consul-template.conf /etc/

COPY docker/scripts/start_musicbrainz_server.sh /usr/local/bin/
