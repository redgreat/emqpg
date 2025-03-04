%%%-------------------------------------------------------------------
%%% @author wangcw
%%% @copyright (C) 2025, REDGREAT
%%% @doc
%%%
%%% 数据库入库模块
%%%
%%% @end
%%% Created : 2025-3-1 17:08:55
%%%-------------------------------------------------------------------
-module(emqpg_db).
-author("wangcw").

%%%===================================================================
%%% 函数导出
%%%===================================================================
-export([db_pg_gnss/2, db_pg_780eg/8]).

%%====================================================================
%% API 函数
%%====================================================================
%% @doc
%% 合宙gnss设备定位信息入库
%% @end
db_pg_gnss(Imei, {Lng, Lat}) ->
    try
        emqpg_pgpool:equery("insert into lc_hzgnss(imei, lng, lat)
        values($1, $2, $3);", [Imei, Lng, Lat])
    catch
        Exception:Error -> 
            lager:error("Database Insert Failed: ~p:~p", [Exception, Error])
    end.

%% @doc
%% 合宙780eg定位信息入库
%% @end
db_pg_780eg(Imei, Lng, Lat, Height, Direction, Speed, Satellite, InsertTime) ->
    try
        emqpg_pgpool:equery("insert into lc_hzgnss(imei, lng, lat, height, direction, speed, satellite, inserttime)
        values($1, $2, $3, $4, $5, $6, $7, $8);", [Imei, Lng, Lat, Height, Direction, Speed, Satellite, InsertTime])
    catch
        Exception:Error -> 
            lager:error("Database Insert Failed: ~p:~p", [Exception, Error])
    end.
%%====================================================================
%% 内部函数
%%====================================================================
