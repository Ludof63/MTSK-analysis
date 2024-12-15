FROM cedardb

#just a script to load stations and prices based on .env
COPY scripts/loadMTS-K.sh /scripts/
RUN mkdir -p /docker-entrypoint-initdb.d && \
    echo '/scripts/loadMTS-K.sh -c -s -p $PRICES_FOLDER -r' > /docker-entrypoint-initdb.d/load.sh
