CREATE TEMP TABLE IF NOT EXISTS row_count_temp (
    time TIMESTAMP,
    row_count BIGINT
);

SELECT ((select count(*) from prices) - row_count )  / EXTRACT(EPOCH FROM (NOW() - time)) as ins_sec
FROM row_count_temp WHERE time = (select max(time) from row_count_temp);


INSERT INTO row_count_temp SELECT NOW(), count(*) from prices;