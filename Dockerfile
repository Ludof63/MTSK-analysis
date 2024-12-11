FROM cedardb

#just a script to load stations and prices based on .env
COPY scripts/loadInImage.sh /docker-entrypoint-initdb.d/