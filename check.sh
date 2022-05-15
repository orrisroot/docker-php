#!/bin/bash

BASE_REPO="docker.io/library/php"
TARGET_REPO="docker.io/orrisroot/php"

VERSIONS=("7.4" "8.0" "8.1")
FLAVORS=("apache" "fpm")

REQUIRED_COMMANDS=("skopeo" "jq" "basename")

for COMMAND in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v ${COMMAND} > /dev/null; then
        echo "Error: ${COMMAND} command is required." 1>&2
        exit 2
    fi
done

check_image () {
    local BASE_CONTAINER=$1
    local TARGET_CONTAINER=$2
    local BASE_JSON=$(skopeo inspect docker://${BASE_CONTAINER})
    [ $? -eq 0 ] || return $?
    local TARGET_JSON=$(skopeo inspect docker://${TARGET_CONTAINER})
    [ $? -eq 0 ] || return $?
    local BASE_LAYER_ID=$(echo ${BASE_JSON} | jq "(.Layers | reverse)[0]")
    local FOUND_LAYER_ID=$(echo ${TARGET_JSON} | jq ".Layers[] | select(. == ${BASE_LAYER_ID})")

    if [ "${BASE_LAYER_ID}" != "${FOUND_LAYER_ID}" ]; then
        echo "The base Docker image has been updated."
        echo "- ${BASE_CONTAINER}"
        echo "The inherited Docker image needs to be updated."
        echo "- ${TARGET_CONTAINER}"
        echo ""
        return 1
    fi

    return 0
}

RETVAL=0
for VERSION in "${VERSIONS[@]}"; do
    for FLAVOR in "${FLAVORS[@]}"; do
        TAG="${VERSION}-${FLAVOR}"
	BASE_IMAGE="${BASE_REPO}:${TAG}"
	TARGET_IMAGE="${TARGET_REPO}:${TAG}"
	check_image "${BASE_IMAGE}" "${TARGET_IMAGE}"
	if [ $? -ne 0 ]; then
		RETVAL=$?
	fi
    done
done

exit $RETVAL
