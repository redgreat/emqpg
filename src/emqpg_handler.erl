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
-module(emqpg_handler).
-author("wangcw").

-behaviour(gen_server).

%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
  code_change/3]).

-include_lib("emqtt/include/emqtt.hrl").

%%%===================================================================
%%% API
%%%===================================================================

%% @doc Spawns the server and registers the local name (unique)
-spec(start_link() ->
  {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================
init([]) ->
  {ok, Host} = application:get_env(emqpg, emqx_host),
  {ok, Port} = application:get_env(emqpg, emqx_port),
  {ok, Username} = application:get_env(emqpg, emqx_username),
  {ok, Password} = application:get_env(emqpg, emqx_password),
  {ok, ClientId} = application:get_env(emqpg, emqx_client_id),
  {ok, Topic} = application:get_env(emqpg, emqx_topic),

  Options = [
    {host, Host},
    {port, Port},
    {clientid, ClientId},
    {username, Username},
    {password, Password},
    {keepalive, 60},
    {clean_start, true}
  ],

  {ok, ClientPid} = emqtt:start_link(Options),
  lager:info("MQTT client process started: ~p", [ClientPid]),

  case emqtt:connect(ClientPid) of
    {ok, _} ->
      lager:info("Connected to EMQX broker at ~p:~p", [Host, Port]),
      case emqtt:subscribe(ClientPid, Topic, 0) of
        {ok, _, _} ->
          lager:info("Subscribed to MQTT topic: ~p", [Topic]),
          {ok, #{mqtt_client => ClientPid}};
        {error, Reason} ->
          lager:error("Failed to subscribe to topic ~p: ~p", [Topic, Reason]),
          {stop, {failed_to_subscribe, Reason}}
      end;
    {error, Reason} ->
      lager:error("Failed to connect to EMQX broker: ~p", [Reason]),
      {stop, {failed_to_connect, Reason}}
  end.

handle_call(_Request, _From, State) ->
  {reply, ok, State}.

handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info({publish, #{payload := Payload, topic := Topic}}, State) ->
  Msg = parse_message(Payload),
  lager:info("Received message from topic ~p: ~p", [Topic, Msg]),
  {noreply, State};

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, State) ->
  lager:info("Handler terminating."),
  case maps:get(mqtt_client, State, undefined) of
    Pid when is_pid(Pid) -> emqtt:stop(Pid);
    _ -> ok
  end,
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
%% 解析二进制消息并提取经纬度
parse_message(<<>>) ->
  {error, empty_message};
parse_message(Binary) when is_binary(Binary) ->
  HexString = binary_to_hex(Binary),
  parse_hex_string(HexString);
parse_message(_) ->
  {error, invalid_format}.

%% 将二进制转换为十六进制字符串
binary_to_hex(Binary) ->
  << <<(integer_to_binary(X, 16))/binary>> || <<X:8>> <= Binary >>.

%% 解析十六进制字符串
parse_hex_string(HexString) ->
  io:format("~p~n", [HexString]),
  case HexString of
    %% 心跳包格式（假设以 "AA" 开头）
    <<"AA", _/binary>> ->
      {ok, heartbeat};
    %% 位置数据格式（假设为 16 个字节）
    Hex when byte_size(HexString) == 16 ->
      <<Latitude:4/binary, Longitude:4/binary>> = hex_to_binary(HexString),
      {ok, {latitude, binary_to_float(Latitude), longitude, binary_to_float(Longitude)}};
    _ ->
      {error, unknown_format}
  end.

%% 将十六进制字符串转换为二进制
hex_to_binary(HexString) ->
  << <<(binary_to_integer(<<X:8, Y:8>>, 16)):8>> || <<X:8, Y:8>> <= HexString >>.

%% 将二进制数据转换为浮点数
binary_to_float(Binary) when byte_size(Binary) == 4 ->
  <<Float:32/float>> = Binary,
  Float.