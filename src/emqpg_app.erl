%% Feel free to use, reuse and abuse the code in this file.

%% @private
-module(emqpg_app).
-behaviour(application).

%% API.
-export([start/2]).
-export([stop/1]).

%% API.

start(_Type, _Args) ->
	application:start(lager),
	emqpg_sup:start_link().

stop(_State) ->
	application:stop(lager),
	ok.
