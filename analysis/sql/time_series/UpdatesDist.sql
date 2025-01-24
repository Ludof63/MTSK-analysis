WITH param AS (
    SELECT
    '2024-10-07T00:00:00Z'::TIMESTAMP AS start_t,
    '2024-10-13T23:59:59Z'::TIMESTAMP AS end_t,
    'hour' AS time_granularity,
)
SELECT 
    date_trunc(time_granularity, time) AS datetime,
    COUNT(*) as n_updates
FROM param,prices
WHERE (diesel_change IN (1,3) OR e5_change IN (1,3) OR e10_change IN (1,3))
 	AND time >= param.start_t AND time <= param.end_t
GROUP BY datetime
ORDER BY datetime;



-- for grafana
WITH param AS (
    SELECT
    $__timeFrom()::TIMESTAMP AS start_t,
    $__timeTo()::TIMESTAMP AS end_t,
    '$time_granularity' AS time_granularity,
)