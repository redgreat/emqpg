%%%-------------------------------------------------------------------
%%% @author wangcw
%%% @copyright (C) 2025, REDGREAT
%%% @doc
%%%
%%% Oracle数据库连接池管理
%%%
%%% @end
%%% Created : 2025-3-4 16:28:03
%%%-------------------------------------------------------------------
-module(emqpg_orapool).
-author("wangcw").

%%%===================================================================
%%% 函数导出
%%%===================================================================
-export([init/0, get_connection/0, stop/0]).

-define(POOL_SIZE, 10).
-define(ConnOpts, [
  {host, "adb.ap-seoul-1.oraclecloud.com"},
  {port, 1521},
  {user, "eadm"},
  {password, "Mm198904250512"},
  {sid, "g4f0c472d565d4c_eadm_high.adb.oraclecloud.com"},
  {app_name, "edbc"}
]).

%%%===================================================================
%%% 资源
%%%===================================================================
-include_lib("stdlib/include/assert.hrl").

%%%===================================================================
%%% 宏定义
%%%===================================================================
%% Global variable to store connections
-define(GLOBAL_CONN_POOL, conn_pool).

%%%===================================================================
%%% API 函数
%%%===================================================================
init() ->
    ConnPool = lists:map(
        fun(_) -> jamdb_oracle:start([{role, 1}] ++ ?ConnOpts) end,
        lists:seq(1, ?POOL_SIZE)),
    put(?GLOBAL_CONN_POOL, ConnPool).

get_connection() ->
    ConnPool = get(?GLOBAL_CONN_POOL),
    hd(ConnPool).

stop() ->
    ConnPool = get(?GLOBAL_CONN_POOL),
    lists:foreach(fun(Conn) -> jamdb_oracle:stop(Conn) end, ConnPool),
    ok. 