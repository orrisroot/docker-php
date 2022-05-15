#!/bin/bash

IMAGE=orrisroot/php
REGISTORY=docker.io/${IMAGE}
VERSIONS=("7.4" "8.0" "8.1")
FLAVORS=("apache" "fpm")

cd $(dirname $0)

[ ! -d logs ] && mkdir -p logs

for VERSION in "${VERSIONS[@]}"; do
  for FLAVOR in "${FLAVORS[@]}"; do
    ./build.sh ${VERSION} ${FLAVOR} > logs/${VERSION}-${FLAVOR}.log &
  done
done

wait

echo Done! To push built images, run the following command.
echo docker login
echo docker image push --all-tags orrisroot/php
