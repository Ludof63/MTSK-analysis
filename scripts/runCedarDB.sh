#!/bin/bash
CONTAINER_DIR=/datasets
IMAGE=cedardb
PORT=5432

INIT_DB=sql/initdb.sql  
PG_CONN_STR="host=localhost dbname=client user=client password=client"

volume="${IMAGE}_data"
container_name="${IMAGE}_runner"

set -x  #log everything

docker stop $container_name
docker volume create $volume

docker run -d --rm  -p $PORT:5432 --log-driver=journald -e PGHOST=/tmp -v .:$CONTAINER_DIR -v $volume:/var/lib/cedardb/data  --name=$container_name $IMAGE 
sleep 2

#initialize db if needed
docker exec $container_name psql "$PG_CONN_STR" 2>/dev/null || docker exec $container_name psql -U postgres -f $CONTAINER_DIR/$INIT_DB 