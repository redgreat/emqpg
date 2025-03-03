%%%-------------------------------------------------------------------
%%% @author wangcw
%%% @copyright (C) 2025, REDGREAT
%%% @doc
%%%
%%% 
%%%
%%% @end
%%% Created : 2025-02-14 15:04
%%%-------------------------------------------------------------------
-module(emqpg_app).
-behaviour(application).

%%%===================================================================
%%% 函数导出
%%%===================================================================
-export([start/2]).
-export([stop/1]).

%%%===================================================================
%%% API 函数
%%%===================================================================
start(_Type, _Args) ->
	application:start(lager),
	emqpg_sup:start_link().

stop(_State) ->
	application:stop(lager),
	ok.
