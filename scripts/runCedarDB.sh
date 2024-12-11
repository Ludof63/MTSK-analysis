#!/bin/bash
#RUN IN THE ROOT OF THE PROJECT
DOCKER=docker #podman or docker

IMAGE_NAME=mts-k-cedardb
ENV_FILE=.env

CONTAINER=cedardb_runner
CONN_STR="host=localhost user=$CEDAR_USER dbname=$CEDAR_DB password=$CEDAR_PASSWORD"

set -x
$DOCKER build -t $IMAGE_NAME .

$DOCKER stop $CONTAINER

sleep 2

$DOCKER run --rm -d \
    --name $CONTAINER -p 5432:5432 \
    --env-file $ENV_FILE \
    -v ./data:$DATA_FOLDER -v ./sql:/sql \
    -v cedardb_data:/var/lib/cedardb/data \
     $IMAGE_NAME

sleep 2
docker exec $CONTAINER psql -v ON_ERROR_STOP=1 "$CONN_STR" -c "set debug.verbosity='debug1';"

