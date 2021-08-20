#!/bin/bash

IMAGE=docker.io/orrisroot/php
VERSION=7.4.22

# 7.4-fpm
pushd 7.4/fpm
docker build --pull --force-rm -t ${IMAGE}:7.4-fpm .
IMAGE_ID=$(docker image ls orrisroot/php:7.4-fpm -q)
docker image tag ${IMAGE_ID} ${IMAGE}:${VERSION}-fpm
popd

# 7.4-apache
pushd 7.4/apache
docker build --pull --force-rm -t ${IMAGE}:7.4-apache .
IMAGE_ID=$(docker image ls orrisroot/php:7.4-apache -q)
docker image tag ${IMAGE_ID} ${IMAGE}:${VERSION}-apache
popd

#docker login
#docker image push --all-tags ${IMAGE}

