-- @author wangcw
-- @copyright (c) 2025, redgreat
-- created : 2025-3-3 09:02:39
-- postgres表结构设计

-- 设置查询路径
alter role user_eadm set search_path to eadm, public;

--设置 本地时区
set time zone 'asia/shanghai';

-- 业务数据_合宙设备定位信息
drop table if exists lc_hzgnss cascade;
create table lc_hzgnss (
  id serial,
  imei varchar(50),
  lat decimal(10, 7),
  lng decimal(10, 7),
  height integer,
  direction integer,
  speed integer,
  satellite integer,
  inserttime timestamptz not null default current_timestamp
);

alter table lc_hzgnss owner to user_eadm;
alter table lc_hzgnss drop constraint if exists pk_hzgnss_id cascade;
alter table lc_hzgnss add constraint pk_hzgnss_id primary key (id);

comment on column lc_hzgnss.id is '自增主键';
comment on column lc_hzgnss.imei is '设备imei';
comment on column lc_hzgnss.lat is '定位纬度(gcj02)';
comment on column lc_hzgnss.lng is '定位经度(gcj02)';
comment on column lc_hzgnss.height is '海拔';
comment on column lc_hzgnss.direction is '方向角';
comment on column lc_hzgnss.speed is '速度';
comment on column lc_hzgnss.satellite is '卫星信号';
comment on column lc_hzgnss.inserttime is '创建时间';
comment on table lc_hzgnss is '业务数据_合宙设备定位信息';
