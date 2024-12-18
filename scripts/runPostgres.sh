#!/bin/bash
#RUN IN THE ROOT OF THE PROJECT

PORT=54321
CONTAINER_NAME=postgres_runner
ENV_FILE=.env 
VOLUME_NAME=postgres_data

if [ -n "$USE_PODMAN" ]; then
    DOCKER=podman
    echo "Using Podman as the container runtime."
fi

source $ENV_FILE

set -x
docker run -d --rm \
  --name $CONTAINER_NAME \
  -p $PORT:5432 \
  -e POSTGRES_USER=$CEDAR_USER \
  -e POSTGRES_PASSWORD=$CEDAR_PASSWORD \
  -e POSTGRES_DB=$CEDAR_DB \
  --env-file $ENV_FILE \
  -v ./data:$DATA_FOLDER \
  -v ./sql:$SQL_FOLDER \
  -v $VOLUME_NAME:/var/lib/postgresql/data \
  postgres:latest


