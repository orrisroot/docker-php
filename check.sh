#!/bin/bash

BASE_REPO="docker.io/library/php"
TARGET_REPO="docker.io/orrisroot/php"

VERSIONS=("8.2" "8.3" "8.4")
FLAVORS=("apache" "fpm")

REQUIRED_COMMANDS=("skopeo" "jq" "basename")

for COMMAND in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v ${COMMAND} > /dev/null; then
        echo "Error: ${COMMAND} command is required." 1>&2
        exit 2
    fi
done

SKOPEO_OPTS="--retry-times 3 --retry-delay 30s"
if [ -f "${HOME}/.docker/config.json" ] \
    && jq -e '.auths["https://index.docker.io/v1/"]' "${HOME}/.docker/config.json" > /dev/null 2>&1; then
    AUTHFILE=$(mktemp)
    jq '{auths: {"https://index.docker.io/v1/": .auths["https://index.docker.io/v1/"]}}' \
        "${HOME}/.docker/config.json" > "${AUTHFILE}"
    SKOPEO_OPTS="--authfile ${AUTHFILE} ${SKOPEO_OPTS}"
    trap "rm -f ${AUTHFILE}" EXIT
fi

check_image () {
    local BASE_CONTAINER=$1
    local TARGET_CONTAINER=$2
    local BASE_JSON TARGET_JSON BASE_LAYER_ID FOUND_LAYER_ID ERR_FILE
    ERR_FILE=$(mktemp)
    BASE_JSON=$(skopeo inspect --config ${SKOPEO_OPTS} docker://${BASE_CONTAINER} 2>${ERR_FILE})
    if [ $? -ne 0 ] || [ -z "${BASE_JSON}" ]; then
        echo "Error: failed to inspect ${BASE_CONTAINER}" 1>&2
        cat ${ERR_FILE} 1>&2
        rm -f ${ERR_FILE}
        return 1
    fi
    TARGET_JSON=$(skopeo inspect --config ${SKOPEO_OPTS} docker://${TARGET_CONTAINER} 2>${ERR_FILE})
    if [ $? -ne 0 ] || [ -z "${TARGET_JSON}" ]; then
        echo "Error: failed to inspect ${TARGET_CONTAINER}" 1>&2
        cat ${ERR_FILE} 1>&2
        rm -f ${ERR_FILE}
        return 1
    fi
    rm -f ${ERR_FILE}
    BASE_LAYER_ID=$(echo ${BASE_JSON} | jq "(.rootfs.diff_ids | reverse)[0]")
    FOUND_LAYER_ID=$(echo ${TARGET_JSON} | jq ".rootfs.diff_ids[] | select(. == ${BASE_LAYER_ID})")

    if [ "${BASE_LAYER_ID}" != "${FOUND_LAYER_ID}" ]; then
        echo "The Docker image needs to be updated."
        echo "- ${TARGET_CONTAINER}"
        echo "  |- ${BASE_CONTAINER}  [newer version found]"
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
	RESULT=$?
	if [ ${RESULT} -ne 0 ]; then
		RETVAL=${RESULT}
	fi
    done
done

exit $RETVAL
