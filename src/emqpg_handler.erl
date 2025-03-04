%%%-------------------------------------------------------------------
%%% @author wangcw
%%% @copyright (C) 2025, REDGREAT
%%% @doc
%%%
%%% EMQX消息处理逻辑
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
%%% 宏定义
%%%===================================================================
%%% GNSS设备imei
-define(GNSS_IMEI, <<"860678076874157">>).

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
  {ok, Topics} = application:get_env(emqpg, emqx_topics),

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
      lists:foreach(fun(Topic) ->
        case emqtt:subscribe(ClientPid, Topic, 0) of
          {ok, _, _} ->
            lager:info("Subscribed to MQTT topic: ~p~n", [Topic]);
          {error, Reason} ->
            lager:error("Failed to subscribe to topic ~p: ~p~n", [Topic, Reason])
        end
      end, Topics),
      {ok, #{mqtt_client => ClientPid}};
    {error, Reason} ->
      lager:error("Failed to connect to EMQX broker: ~p~n", [Reason]),
      {stop, {failed_to_connect, Reason}}
  end.

handle_call(_Request, _From, State) ->
  {reply, ok, State}.

handle_cast(_Msg, State) ->
  {noreply, State}.

handle_info({publish, #{payload := Payload, topic := Topic}}, State) ->
  case Topic of
    <<"pos/gnss">> ->
      handle_gnss_data(Payload, State);
    <<"pos/780eg/", Imei/binary>> ->
      handle_780eg_data(Payload, Imei, State);
    _ ->
      lager:warning("Received message on unknown topic: ~p", [Topic]),
      {noreply, State}
  end;

handle_info(_Info, State) ->
  {noreply, State}.

handle_gnss_data(Payload, State) ->
  case parse_gnss_message(Payload) of
    {Lng, Lat} ->
      CurrentTimestamp = erlang:system_time(second),
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
              {noreply, State#{last_alert_time => NewAlertTime}};
            true -> ok
          end,
          if
            Distance > 10 ->
              emqpg_db:db_pg_gnss(?GNSS_IMEI, {Lng, Lat});
            true -> ok
          end
      end,
      
      {noreply, NewState};
    {error, Reason} ->
      lager:error("Failed to parse message: ~p~n", [Reason]),
      {noreply, State}
  end.

handle_780eg_data(Payload, Imei, State) ->
  Messages = string:split(Payload, "_", all),
  lists:foreach(fun(Message) ->
    try
      BinaryMessage = case is_binary(Message) of
        true -> Message;
        false -> list_to_binary(Message)
      end,
      DecodedMsg = json:decode(BinaryMessage),
        case maps:get(<<"msg">>, DecodedMsg, undefined) of
          undefined ->
            lager:error("No msg field in message: ~p~n", [DecodedMsg]);
          Msg ->
            [Result, HardwareTimestamp, LngStr, LatStr, Height, Direction, Speed, Satellite] = Msg,
            case Result of
              true ->
                lager:warning("Gps status not fixed!");
              false ->
                WsgLng = list_to_float(LngStr),
                WsgLat = list_to_float(LatStr),
                {Lng, Lat} = emqpg_geo:wgs84_to_gcj02({WsgLng, WsgLat}),
                CurrentTimestamp = erlang:system_time(second),
                LastLocation = maps:get(last_location, State, undefined),
                LastTimestamp = maps:get(last_timestamp, State, undefined),

                {NewState, MovementInfo} = calculate_movement({Lng, Lat}, CurrentTimestamp, LastLocation, LastTimestamp, State),

                case MovementInfo of
                  {Distance, Speed} ->
                    if 
                      Speed > 60 ->
                        CurrentTime = erlang:system_time(second),
                        LastAlertTime = maps:get(last_alert_time, State, 0),
                        if
                          CurrentTime - LastAlertTime > 300 ->
                            emqpg_push:send_msg(unicode:characters_to_binary(io_lib:format("开车超速啦，当前速度：~p km/h", [Speed]), utf8)),
                            NewAlertTime = CurrentTime;
                          true ->
                            NewAlertTime = LastAlertTime
                        end,
                        {noreply, State#{last_alert_time => NewAlertTime}};
                      true -> ok
                    end,
                    if
                      Distance > 10 ->
                        InsertTime = timestamp_to_pg_datetime(HardwareTimestamp),
                        emqpg_db:db_pg_780eg(Imei, Lng, Lat, Height, Direction, Speed, Satellite, InsertTime);
                      true -> ok
                    end
                end,
                {noreply, NewState};
              _ ->
                lager:warning("no result!")
            end
        end
    catch
      error:Error ->
        lager:error("Failed to decode message: ~p, Error: ~p~n", [Message, Error])
    end
  end, Messages),
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

parse_gnss_message(<<>>) ->
  {error, empty_message};
parse_gnss_message(Binary) when is_binary(Binary) ->
  case binary_to_list(Binary) of
    [] -> {error, empty_message};
    Str -> parse_gnss_string(Str)
  end;
parse_gnss_message(_) ->
  {error, invalid_format}.

%% 解析经纬度字符串（格式："经度_纬度"）
parse_gnss_string(Str) ->
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

timestamp_to_pg_datetime(Timestamp) when is_integer(Timestamp) ->
  DateTime = calendar:system_time_to_universal_time(Timestamp, second),
  format_datetime_for_pg(DateTime).

format_datetime_for_pg({{Year, Month, Day}, {Hour, Minute, Second}}) ->
  lists:flatten(io_lib:format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B:~2..0B", 
                             [Year, Month, Day, Hour, Minute, Second])).