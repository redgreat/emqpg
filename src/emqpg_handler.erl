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
% -include_lib("emqtt/include/emqtt.hrl").

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
  lager:info("MQTT client process started: ~p~n", [ClientPid]),
    
  case emqtt:connect(ClientPid) of
    {ok, _} ->
      lager:info("Connected to EMQX broker at ~p:~p~n", [Host, Port]),
      case emqtt:subscribe(ClientPid, Topic, 0) of
        {ok, _, _} ->
          lager:info("Subscribed to MQTT topic: ~p~n", [Topic]),
          % 初始化状态，增加last_location和last_timestamp字段
          {ok, #{mqtt_client => ClientPid, 
                 last_location => undefined, 
                 last_timestamp => undefined,
                 last_alert_time => 0}};
        {error, Reason} ->
          lager:error("Failed to subscribe to topic ~p: ~p~n", [Topic, Reason]),
          {stop, {failed_to_subscribe, Reason}}
      end;
    {error, Reason} ->
      lager:error("Failed to connect to EMQX broker: ~p~n", [Reason]),
      {stop, {failed_to_connect, Reason}}
  end.

handle_call(_Request, _From, State) ->
  {reply, ok, State}.

handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info({publish, #{payload := Payload, topic := Topic}}, State) ->
  case parse_message(Payload) of
    {Lng, Lat} ->
      % 获取当前时间戳
      CurrentTimestamp = erlang:system_time(second),
      % 获取上次位置和时间戳
      LastLocation = maps:get(last_location, State, undefined),
      LastTimestamp = maps:get(last_timestamp, State, undefined),
      
      {NewState, MovementInfo} = calculate_movement({Lng, Lat}, CurrentTimestamp, LastLocation, LastTimestamp, State),
      
      case MovementInfo of
        {Distance, Speed} ->
          if 
            Speed > 25 ->
              CurrentTime = erlang:system_time(second),
              LastAlertTime = maps:get(last_alert_time, State, 0),
              if
                CurrentTime - LastAlertTime > 300 ->
                  emqpg_push:send_msg(unicode:characters_to_binary(io_lib:format("电动车超速啦，当前速度：~p km/h", [Speed]), utf8)),
                  NewAlertTime = CurrentTime;
                true ->
                  NewAlertTime = LastAlertTime
              end,
              % lager:info("Movement detected: Speed=~p km/h", [Speed]),
              {noreply, State#{last_alert_time => NewAlertTime}};
            true -> ok
          end,
          if
            Distance > 10 ->
              emqpg_db:db_pg_gnss(Topic, {Lng, Lat});
              % lager:info("Movement detected: Distance=~p meters", [Distance]);
            true -> ok
          end
      end,
      
      {noreply, NewState};
    {error, Reason} ->
      lager:error("Failed to parse message: ~p~n", [Reason]),
      {noreply, State}
  end;

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
  case binary_to_list(Binary) of
    [] -> {error, empty_message};
    Str -> parse_coordinate_string(Str)
  end;
parse_message(_) ->
  {error, invalid_format}.

%% 解析经纬度字符串（格式："经度_纬度"）
parse_coordinate_string(Str) ->
  try
    case string:split(Str, "_") of
      [LngStr, LatStr] ->
        Lng = list_to_float(LngStr),
        Lat = list_to_float(LatStr),
        emqpg_geo:wgs84_to_gcj02({Lng, Lat});
      _ ->
        lager:info("Payload Data Error!")
    end
  catch
    error:_ -> {error, invalid_coordinate_format}
  end.

%% 计算移动信息（距离和速度）
calculate_movement(CurrentLocation, CurrentTimestamp, undefined, _, State) ->
  NewState = State#{last_location => CurrentLocation, last_timestamp => CurrentTimestamp},
  {NewState, {0, 0}};

calculate_movement(CurrentLocation, CurrentTimestamp, LastLocation, LastTimestamp, State) ->
  Distance = emqpg_geo:distance(LastLocation, CurrentLocation),
  SpeedMps = emqpg_geo:speed(LastLocation, LastTimestamp, CurrentLocation, CurrentTimestamp),
  Speed = SpeedMps * 3.6,
  NewState = State#{last_location => CurrentLocation, last_timestamp => CurrentTimestamp},
  {NewState, {Distance, Speed}}.
