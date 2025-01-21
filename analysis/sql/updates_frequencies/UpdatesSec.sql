WITH entries_per_second AS (
    SELECT date_trunc('second', time) AS datetime, COUNT(*) as n_entries
    FROM prices
    WHERE (diesel_change IN (1,3) OR e5_change IN (1,3) OR e10_change IN (1,3))
    GROUP BY datetime
)
SELECT SUM(n_entries) / EXTRACT(EPOCH FROM (max(datetime) - min(datetime))) as avg_updates_per_sec 
FROM entries_per_second;
