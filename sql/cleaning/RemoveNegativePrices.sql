DELETE 
--select *
FROM prices 
WHERE (diesel_change in (1,3) and diesel < 0) OR (e5_change in (1,3) and e5 < 0) OR (e10_change in (1,3) and e10 < 0);