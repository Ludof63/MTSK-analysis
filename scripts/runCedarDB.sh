#!/bin/bash
# RUN IN THE ROOT OF THE PROJECT
ENV_FILE=.env
source .env

# Default values
IMAGE_NAME=mts-k-cedardb
CONTAINER=cedardb_runner
CONN_STR="host=localhost user=$CEDAR_USER dbname=$CEDAR_DB password=$CEDAR_PASSWORD"

DOCKER=docker
BUILD_IMAGE=true
CUSTOM_IMAGE=""

# Parse command-line arguments
while getopts "bi:" opt; do
  case $opt in
    b)
      BUILD_IMAGE=true
      ;;
    i)
      BUILD_IMAGE=false
      CUSTOM_IMAGE=$OPTARG
      ;;
    *)
      echo "Usage: $0 [-b] [-p] [-i <image_name>]"
      exit 1
      ;;
  esac
done

if [ -n "$USE_PODMAN" ]; then
    DOCKER=podman
    echo "Using Podman as the container runtime."
fi


if [ -n "$CUSTOM_IMAGE" ]; then
  IMAGE_NAME="$CUSTOM_IMAGE"
  echo "Using custom image: $IMAGE_NAME"
fi

set -x


if [ "$BUILD_IMAGE" = true ]; then
  $DOCKER build -t "$IMAGE_NAME" . || exit 1
fi


$DOCKER stop $CONTAINER 2>/dev/null || true
sleep 2

$DOCKER run --rm -d \
    --name $CONTAINER -p 5432:5432 \
    --env-file $ENV_FILE \
    -v ./data:$DATA_FOLDER -v ./sql:$SQL_FOLDER \
    -v cedardb_data:/var/lib/cedardb/data \
    $IMAGE_NAME || exit 1

sleep 2

#activate more logs -> if not ready connect to stream of logs
$DOCKER exec $CONTAINER psql -v ON_ERROR_STOP=1 "$CONN_STR" -c "set debug.verbosity='debug1';" || $DOCKER logs -f $CONTAINER


