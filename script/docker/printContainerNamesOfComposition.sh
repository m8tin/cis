#/bin/bash

_COMPOSITION_FILE="${1:-./docker-compose.yml}"

[ -d "${_COMPOSITION_FILE}" ] \
    && echo "A valid composition file ('docker-compose.yml') is needed. Given parameter was: ${_COMPOSITION_FILE}" >&2 \
    && exit 1

_DOCKER_COMPOSE_CMD=""

[ "${_DOCKER_COMPOSE_CMD}" = "" ] \
    && docker compose version 2> /dev/null | grep -q version \
    && _DOCKER_COMPOSE_CMD="docker compose"

[ "${_DOCKER_COMPOSE_CMD}" = "" ] \
    && docker-compose version 2> /dev/null | grep -q version \
    && _DOCKER_COMPOSE_CMD="docker-compose"

[ "${_DOCKER_COMPOSE_CMD}" = "" ] \
    && echo "Command 'docker compose' not found" >&2 \
    && exit 1

${_DOCKER_COMPOSE_CMD} -f "${_COMPOSITION_FILE}" images | tail -n +2 | cut -d' ' -f1
