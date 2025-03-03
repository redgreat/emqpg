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
  topic varchar(50),
  lat decimal(10, 7),
  lng decimal(10, 7),
  inserttime timestamptz not null default current_timestamp
);

alter table lc_hzgnss owner to user_eadm;
alter table lc_hzgnss drop constraint if exists pk_hzgnss_id cascade;
alter table lc_hzgnss add constraint pk_hzgnss_id primary key (id);

comment on column lc_hzgnss.id is '自增主键';
comment on column lc_hzgnss.topic is '用户id(eadm_user.id)';
comment on column lc_hzgnss.lat is '定位纬度(gcj02)';
comment on column lc_hzgnss.lng is '定位经度(gcj02)';
comment on column lc_hzgnss.inserttime is '创建时间';
comment on table lc_hzgnss is '业务数据_合宙设备定位信息';
