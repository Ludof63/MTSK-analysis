FROM cedardb

# copy the loading script
COPY scripts/loadMTS-K.sh /scripts/  

# create a single-line script that calls the loading script
RUN mkdir -p /docker-entrypoint-initdb.d && echo '/scripts/loadMTS-K.sh -c -s -p $PRICES_FOLDER -r' > /docker-entrypoint-initdb.d/load.sh
