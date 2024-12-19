#!/bin/bash
GRAFANA_VOLUME=grafana_volume
GRAFANA_CONTAINER=grafana

if [ -n "$USE_PODMAN" ]; then
    DOCKER=podman
    echo "Using Podman as the container runtime."
fi

set -x  #log everything
docker stop $GRAFANA_CONTAINER 
docker volume create $GRAFANA_VOLUME
docker run --rm -d --network host -v $GRAFANA_VOLUME:/var/lib/grafana --name $GRAFANA_CONTAINER grafana/grafana-enterprise