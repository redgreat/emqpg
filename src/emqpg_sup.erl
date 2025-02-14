%%%-------------------------------------------------------------------
%%% @author wangcw
%%% @copyright (C) 2024, REDGREAT
%% @doc
%%
%% eadm top level supervisor.
%%
%% @end
%%% Created : 2024-01-23 17:30:14
%%%-------------------------------------------------------------------
-module(emqpg_sup).
-author("wangcw").

%%%===================================================================
%%% 函数行为
%%%===================================================================
-behaviour(supervisor).

%%%===================================================================
%%% 函数导出
%%%===================================================================
-export([start_link/0, add_pool/3]).
-export([init/1]).

%%%===================================================================
%%% 定义
%%%===================================================================
-define(SERVER, ?MODULE).

%%====================================================================
%% API 函数
%%====================================================================
-spec start_link() -> {ok, pid()}.
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
  Pools = application:get_env(epgsql, pools, []),
  %% lager:info("数据库连接参数：~p~n", [Pools]),
  PoolSpec = lists:map(fun ({PoolName, SizeArgs, WorkerArgs}) ->
    PoolArgs = [{name, {local, PoolName}},
      {worker_module, emqpg_pgpool_worker}] ++ SizeArgs,
    poolboy:child_spec(PoolName, PoolArgs, WorkerArgs)
                       end, Pools),
  % Handler
  MqttHandlerSpec = {emqpg_handler, {emqpg_handler, start_link, []},
    permanent, 5000, worker, [emqpg_handler]},

  ChildSpecs = [MqttHandlerSpec | PoolSpec],

  {ok, { {one_for_one, 10, 10}, ChildSpecs} }.

add_pool(Name, PoolArgs, WorkerArgs) ->
  ChildSpec = poolboy:child_spec(Name, PoolArgs, WorkerArgs),
  supervisor:start_child(?MODULE, ChildSpec).
