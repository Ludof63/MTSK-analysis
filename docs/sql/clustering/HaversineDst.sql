DROP FUNCTION haversine_dst;
CREATE FUNCTION 
    haversine_dst(lat1 double precision, lon1 double precision, lat2 double precision, lon2 double precision)
    returns double precision language sql AS 
    '6371 * ACOS(COS(RADIANS(lat2)) * COS(RADIANS(lat1)) * COS(RADIANS(lon1) - RADIANS(lon2)) + SIN(RADIANS(lat2)) * SIN(RADIANS(lat1)))';

