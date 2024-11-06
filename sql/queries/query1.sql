with diesel_data as (
select
	s.city as city,
	COUNT(*) as n_diesel_events,
	COUNT(distinct s.id) as n_stations_diesel,
	AVG(p.diesel) as avg_diesel_price
from
	stations s
join 
        prices p on
	s.id = p.station_uuid
where
	p.diesel_change in (1, 3)
group by
	s.city
having
	COUNT(*) > 100
),
e5_data as (
select
	s.city as city,
	COUNT(*) as n_e5_events,
	COUNT(distinct s.id) as n_stations_e5,
	AVG(p.e5) as avg_e5_price
from
	stations s
join 
        prices p on
	s.id = p.station_uuid
where
	p.e5_change in (1, 3)
group by
	s.city
having
	COUNT(*) > 100
),
e10_data as (
select
	s.city as city,
	COUNT(*) as n_e10_events,
	COUNT(distinct s.id) as n_stations_e10,
	AVG(p.e10) as avg_e10_price
from
	stations s
join 
        prices p on
	s.id = p.station_uuid
where
	p.e10_change in (1, 3)
group by
	s.city
having
	COUNT(*) > 100
)
select
	diesel_data.city,
	greatest(diesel_data.n_stations_diesel,
	e5_data.n_stations_e5,
	e10_data.n_stations_e10) as n_stations,
	-- diesel_data.n_diesel_events,
	CAST(diesel_data.avg_diesel_price AS NUMERIC(10, 5)) as avg_diesel_price,
	-- ROUND(diesel_data.avg_diesel_price,5),
	-- e5_data.n_e5_events,
	CAST(e5_data.avg_e5_price AS NUMERIC(10, 5)) as avg_e5_price,
	 -- e10_data.n_e10_events,
	CAST(e10_data.avg_e10_price AS NUMERIC(10, 5)) as avg_e10_price
from
	diesel_data
left join 
    e5_data on
	diesel_data.city = e5_data.city
left join 
    e10_data on
	diesel_data.city = e10_data.city
order by
	n_stations desc;
