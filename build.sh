#!/bin/bash

IMAGE=orrisroot/php
REGISTORY=docker.io/${IMAGE}

function build_image () {
  IMAGE=$1
  VERSION=$2
  TYPE=$3
  TAG="${VERSION}-${TYPE}"
  pushd ${VERSION}/${TYPE}
  docker build --pull --force-rm -t ${IMAGE}:${TAG} .
  IMAGE_ID=$(docker image ls ${IMAGE}:${TAG} -q)
  VERSION_=$(docker run --rm -it ${IMAGE}:${TAG} php -r "echo phpversion();")
  docker image tag ${IMAGE_ID} ${IMAGE}:${VERSION_}-${TYPE}
  popd
}

cd $(dirname $0)

# 7.4-apache
build_image ${IMAGE} 7.4 apache

# 7.4-fpm
build_image ${IMAGE} 7.4 fpm

# 8.0-apache
build_image ${IMAGE} 8.0 apache

# 8.0-fpm
build_image ${IMAGE} 8.0 fpm

#docker login
echo Done! To push built images, run the following command.
echo docker image push --all-tags ${IMAGE}

