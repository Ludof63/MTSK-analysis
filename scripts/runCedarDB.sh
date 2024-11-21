#!/bin/bash
CONTAINER_DIR=/datasets
INIT_DB=../sql/initdb.sql  #relative path

IMAGE=cedardb
PORT=5432
PG_CONN_STR="host=localhost dbname=client user=client password=client"

volume="${IMAGE}_data"
container_name="${IMAGE}_runner"

get_real_path() {
    set +x
    local relative_path="$1"
    local script_dir="$(dirname "$(realpath "$0")")"
    echo "$(realpath "$script_dir/$relative_path")"
    set -x
}

set -x  #log everything

docker stop $container_name
docker volume create $volume

docker run -d --rm  -p $PORT:5432 --log-driver=journald -e PGHOST=/tmp -v .:$CONTAINER_DIR -v $volume:/var/lib/cedardb/data  --name=$container_name $IMAGE 
sleep 2

#initialize db if needed
docker exec $container_name psql "$PG_CONN_STR" 2>/dev/null || docker exec $container_name psql -U postgres -c "$(cat $(get_real_path $INIT_DB))"
docker exec $container_name psql "$PG_CONN_STR" -c "set debug.verbosity='debug1';" #more logs from cedardb