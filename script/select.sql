SELECT * 
FROM lc_hzgnss
ORDER BY id DESC
LIMIT 10;

SELECT COUNT(1)
FROM lc_hzgnss
LIMIT 10;

insert into lc_hzgnss(topic, lng, lat)
values('pos/gns', 120.5211292, 36.411615);

truncate table lc_hzgnss;

SELECT pg_get_serial_sequence('lc_hzgnss', 'id');

ALTER SEQUENCE public.lc_hzgnss_id_seq RESTART WITH 1;

select max(id) from public.lc_hzgnss;
