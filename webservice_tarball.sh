#!/bin/sh
tarball=musicbrainz-webservice.tar
git archive -o $tarball master
tar -rf $tarball --owner=root --group=root -C docker/musicbrainz-webservice Dockerfile
gzip $tarball
