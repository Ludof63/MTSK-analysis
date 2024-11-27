
docker-compose down

VOLUME_NAME=mts-k_cedardb_data
if docker volume inspect "$VOLUME_NAME" &>/dev/null; then
  echo "Removing existing volume: $VOLUME_NAME"
  docker volume rm "$VOLUME_NAME"
else
  echo "Volume $VOLUME_NAME does not exist, skipping removal."
fi

docker-compose up --build -d