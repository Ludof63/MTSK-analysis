#!/bin/bash
set -e

ENV_FILE=.env
source $ENV_FILE

DOCKER=docker
if [ -n "$USE_PODMAN" ]; then
    DOCKER=podman
    echo "Using Podman as the container runtime."
fi

set -x

docker stop cedar || true
docker stop grafana || true

docker run --rm -d --name cedar -p 5432:5432 --env-file $ENV_FILE -v ./data:/data -v cedardb_data:/var/lib/cedardb/data cedardb
docker run --rm -d --name grafana --network host -v ./grafana:/var/lib/grafana grafana/grafana:latest

#docker run -d --rm --name postgres -p 54321:5432 -e POSTGRES_USER=client -e POSTGRES_PASSWORD=client -e POSTGRES_DB=client postgres:latest