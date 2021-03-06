#!/usr/bin/env bash

# This script mounts the project into a container that provides Node 10.14, Bash, and Git.
# By default the container starts with Bash. Pass a different command to the script
# to run that command instead in the container.
# Examples:
#   scripts/mount-project.sh npm ci
#   scripts/mount-project.sh npm run build
#
# For convenience, shortcuts are defined for common commands. E.g.,
#   scripts/mount-project.sh build
#   scripts/mount-project.sh serve
#   scripts/mount-project.sh test

# Change to the directory of this script so that relative paths resolve correctly
cd $(dirname "$0")

# Read this module's environment variables from file
source ../mount-project-node/variables.sh

# Store values in unique variables, to avoid potential collisions
MPN_VERSION=${VERSION}
MPN_IMAGE_BASE_NAME="${IMAGE_BASE_NAME}"


# Change to the project root from `node_modules/.bin/`
cd ../..


# Read project's environment variables from file
# TODO: REFACTOR: Maybe add a flexible env var handler
if [[ -f .env ]]; then
  source .env
fi


# -- Helper functions
# Given the name of a Docker network, return 0 if the network exists, else 1
dockerNetworkExists () {
  local DOCKER_NETWORK=$1

  if [[ -n $(docker network ls --quiet --filter name=${DOCKER_NETWORK}) ]]; then
    return 0
  else
    return 1
  fi
}

# Generate a random ID to append to the container name
randomString () {
  local LENGTH=${1:4}
  echo $(perl -pe 'binmode(STDIN, ":bytes"); tr/a-zA-Z0-9//dc;' < /dev/urandom | head -c 4)
}


# Defaults. Override by setting these values in environment variables or `.env`
DOCKER_NETWORK=${DOCKER_NETWORK:='default'}
MPN_DEFAULT_CMD=${MPN_DEFAULT_CMD:='bash'}
PROJECT_ID=${PROJECT_ID:='node10-app'}
WEB_SERVER_PORT=${WEB_SERVER_PORT:='8080'}


# Process command-line arguments, if any
if [[ -n $@ ]]; then
  CMD="$@"

  # Shortcut arguments
  if [[ ${CMD} == 'build' ]]; then
    CMD='npm run build'
  fi

  if [[ ${CMD} == 'serve' ]]; then
    CMD="http-server -p ${WEB_SERVER_PORT} dist"
  fi
else
  CMD=${MPN_DEFAULT_CMD}
fi


# The code below respects `NODE_ENV`, defaulting to `development` if NODE_ENV isn't set
if [[ ${CMD} == 'test' ]]; then
  CMD='npm run test'
  NODE_ENV='development'
else
  NODE_ENV=${NODE_ENV:='development'}
fi

if [[ ${DOCKER_NETWORK} != 'default' ]]; then
  if ! dockerNetworkExists ${DOCKER_NETWORK}; then
    echo "WARNING: No Docker network with the name '${DOCKER_NETWORK}' was found. The 'default' network will be used" 1>&2
    DOCKER_NETWORK='default'
  fi
fi

echo -e "Mounting the project into a container:"
echo "|  command:     ${CMD}"
echo "|  environment: ${NODE_ENV}"
echo "|  network:     ${DOCKER_NETWORK}"


docker container run \
  --interactive \
  --rm \
  --tty \
  --env NODE_ENV=${NODE_ENV} \
  --expose ${WEB_SERVER_PORT} \
  --mount type=bind,source=${PWD},target=/var/project \
  --name ${PROJECT_ID}-$(randomString 4) \
  --network ${DOCKER_NETWORK} \
  --publish ${WEB_SERVER_PORT}:${WEB_SERVER_PORT} \
  --workdir /var/project \
  ${MPN_IMAGE_BASE_NAME}:${MPN_VERSION} \
  ${CMD}
