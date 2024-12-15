drop table if exists stations;
drop table if exists stations_times;
drop table if exists prices;
drop table if exists stations_clusters;

create table stations (
    id uuid primary key,
    name text,
    brand text,
    street text,
    house_number text,
    post_code text,
    city text,
    latitude double precision not null,
    longitude double precision not null,
    always_open boolean not null
);


create table stations_times (
    station_id uuid not null,
    days int not null,
    open_time time not null,
    close_time time not null
);

create table prices (
    time timestamp not null,
    station_uuid uuid,
    diesel numeric(5,3) not null,
    e5 numeric(5,3) not null,
    e10 numeric(5,3) not null,
    diesel_change smallint not null,
    e5_change smallint not null,
    e10_change smallint not null
   
    -- primary key(station_uuid,time) 
);

create table stations_clusters (
    stations_id uuid not null,    
    cluster text not null,       
    primary key(stations_id,cluster)               
);



