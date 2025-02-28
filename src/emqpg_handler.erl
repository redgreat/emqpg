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

%%%===================================================================
%%% 函数导出
%%%===================================================================
-export([start_link/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%%%===================================================================
%%% 资源
%%%===================================================================
-include_lib("emqtt/include/emqtt.hrl").

%%%===================================================================
%%% API 函数
%%%===================================================================
%% @doc Spawns the server and registers the local name (unique)
-spec(start_link() ->
    {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%%===================================================================
%%% gen_server 函数
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
%%% 内部函数
%%%===================================================================
%% 解析二进制消息并提取经纬度
parse_message(<<>>) ->
  {error, empty_message};
parse_message(Binary) when is_binary(Binary) ->
  parse_hex_string(Binary);
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
    <<"AA", Rest/binary>> when byte_size(Rest) == 20 ->
      <<Info:8, Valid:8, Timestamp:32, Longitude:32, Latitude:32, Altitude:16, Azimuth:16, Speed:8, SNR:8, Satellites:8>> = Rest,
      {ok, {info, Info, valid, Valid, timestamp, Timestamp, longitude, Longitude, latitude, Latitude, altitude, Altitude, azimuth, Azimuth, speed, Speed, snr, SNR, satellites, Satellites}};
    %% 设备信息报文格式（假设以 "55" 开头）
    <<"55", Rest/binary>> when byte_size(Rest) == 22 ->
      <<Device:8, Open:8, Vibration:8, Unlock:8, Ignition:8, Charging:8, WireCut:8, ExternalVoltage:32, BatteryVoltage:16, GPRS:8, Extra1:8, Extra2:8>> = Rest,
      {ok, {device, Device, open, Open, vibration, Vibration, unlock, Unlock, ignition, Ignition, charging, Charging, wire_cut, WireCut, external_voltage, ExternalVoltage, battery_voltage, BatteryVoltage, gprs, GPRS, extra1, Extra1, extra2, Extra2}};
    _ ->
      {error, unknown_format}
  end.
