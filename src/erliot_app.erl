%% Feel free to use, reuse and abuse the code in this file.

%% @private
-module(erliot_app).
-behaviour(application).

%% API.
-export([start/2]).
-export([stop/1]).

%% API.

start(_Type, _Args) ->
	application:start(lager),
	case ranch:start_listener(erliot,
		ranch_tcp, #{socket_opts => [{port, 8090}],
			max_connections => 10,
			num_conns_sups => 2
		},
		erliot_protocol, []) of
		{ok, _} ->
			erliot_sup:start_link();
		{error, Reason} ->
			lager:error("Failed to start listener: ~p", [Reason]),
			{error, Reason}
	end.

stop(_State) ->
	application:stop(lager),
	ranch:stop_listener(erliot),
	ok.
