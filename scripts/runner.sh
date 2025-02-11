#!/bin/bash
set -e

DOCKER=docker
if [ -n "$USE_PODMAN" ]; then
    DOCKER=podman
    echo "Using Podman as the container runtime."
fi

down(){
    set -x
    $DOCKER stop cedar || true
    $DOCKER stop grafana || true
    $DOCKER network rm net_db || true

    #$DOCKER stop postgres || true
}


up() {
    down

    set -x
    $DOCKER network create net_db
    $DOCKER run --rm -d --name cedar   --network net_db -p 5432:5432 --env-file .env -v ./data:/data -v cedardb_data:/var/lib/cedardb/data cedardb
    $DOCKER run --rm -d --name grafana --network net_db -p 3000:3000 -e GF_DASHBOARDS_MIN_REFRESH_INTERVAL=100ms -v grafana_data:/var/lib/grafana grafana/grafana:latest

    #docker run -d --rm --name postgres -p 54321:5432 -e POSTGRES_USER=client -e POSTGRES_PASSWORD=client -e POSTGRES_DB=client postgres:latest
}

if [ "$1" == "up" ]; then
    up
elif [ "$1" == "down" ]; then
    down
else
    echo "Usage: $0 {up|down}"
    exit 1
fi
