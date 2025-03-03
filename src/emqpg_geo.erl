%%%-------------------------------------------------------------------
%%% @author wangcw
%%% @copyright (C) 2024, REDGREAT
%%% @doc
%%%
%%% 经纬度计算相关函数
%%%
%%% @end
%%% Created : 2024-07-01 下午2:11
%%%-------------------------------------------------------------------
-module(emqpg_geo).
-author("wangcw").

%%%===================================================================
%%% 函数导出
%%%===================================================================
-export([wgs84_to_gcj02/1, distance/2, speed/4]).

-define(PI, 3.14159265358979323846).
-define(X_PI, 3.0 * ?PI).
-define(A, 6378245.0). % 地球长半径（米）
-define(R, 6371000.0). % 地球半径（米）
-define(EE, 0.00669342162296594323).

%%====================================================================
%% API 函数
%%====================================================================
%% @doc
%% 国际WSG84坐标系转换为国内GCJ02高德坐标系，火星坐标系
%% @end
wgs84_to_gcj02({Lng, Lat}) ->
    case out_of_china({Lng, Lat}) of
        true -> {Lng, Lat};
        false ->
            DLat = convertlat(Lng - 105.0, Lat - 35.0),
            DLng = convertlng(Lng - 105.0, Lat - 35.0),
            RadLat = Lat * ?PI / 180.0,
            Magic = math:sin(RadLat),
            MagicResult = 1 - ?EE * Magic * Magic,
            SqrtMagic = math:sqrt(MagicResult),
            FinalDLat = (DLat * 180.0) / ((?A * (1 - ?EE)) / (MagicResult * SqrtMagic) * ?PI),
            FinalDLng = (DLng * 180.0) / (?A / SqrtMagic * math:cos(RadLat) * ?PI),
            MgLat = Lat + FinalDLat,
            MgLng = Lng + FinalDLng,
            {MgLng, MgLat}
    end.

%% @doc
%% 计算两个经纬度点之间的距离（米）
%% 使用Haversine公式计算球面距离
%% @end
distance({Lng1, Lat1}, {Lng2, Lat2}) ->
    % 将经纬度转换为弧度
    Rad1 = {Lng1 * ?PI / 180.0, Lat1 * ?PI / 180.0},
    Rad2 = {Lng2 * ?PI / 180.0, Lat2 * ?PI / 180.0},
    
    % 提取弧度值
    {RadLng1, RadLat1} = Rad1,
    {RadLng2, RadLat2} = Rad2,
    
    % 计算差值
    DLat = RadLat2 - RadLat1,
    DLng = RadLng2 - RadLng1,
    
    % Haversine公式
    A = math:pow(math:sin(DLat / 2), 2) + 
        math:cos(RadLat1) * math:cos(RadLat2) * 
        math:pow(math:sin(DLng / 2), 2),
    C = 2 * math:atan2(math:sqrt(A), math:sqrt(1 - A)),
        
    % 计算距离（米）
    Distance = ?R * C,
    Distance.

%% @doc
%% 计算两点间移动速度（米/秒）
%% @end
speed({Lng1, Lat1}, Time1, {Lng2, Lat2}, Time2) ->
    Distance = distance({Lng1, Lat1}, {Lng2, Lat2}),
    TimeDiff = max(Time2 - Time1, 1), % 防止零除
    Distance / TimeDiff.

%%====================================================================
%% 内部函数
%%====================================================================
%% @doc
%% 坐标点是否在国内（外国坐标点不在火星系坐标范围内）
%% @end
out_of_china({Lng, Lat}) ->
    Lng > 73.66 andalso Lng < 135.05 andalso Lat > 3.86 andalso Lat < 53.55.

%% @doc
%% 经纬度坐标转换
%% @end
convertlat(Lng, Lat) ->
    Ret = -100.0 + 2.0 * Lng + 3.0 * Lat + 0.2 * Lat * Lat +
        0.1 * Lng * Lat + 0.2 * math:sqrt(erlang:abs(Lng)),
    Ret + sin_convert(Lng, 6.0, 20.0) * 2.0 / 3.0 +
        sin_convert(Lat, 1.0, 20.0) * 2.0 / 3.0 +
        sin_convert(Lat, 12.0, 160.0, 320.0) * 2.0 / 3.0.

convertlng(Lng, Lat) ->
    Ret = 300.0 + Lng + 2.0 * Lat + 0.1 * Lng * Lng +
        0.1 * Lng * Lat + 0.1 * math:sqrt(erlang:abs(Lng)),
    Ret + sin_convert(Lng, 6.0, 20.0) * 2.0 / 3.0 +
        sin_convert(Lng, 1.0, 20.0, 40.0) * 2.0 / 3.0 +
        sin_convert(Lng, 12.0, 150.0, 300.0) * 2.0 / 3.0.

%% @doc
%% 正弦计算函数
%% @end
sin_convert(Coord, Div, Amp1) ->
    Amp1 * math:sin(Coord * Div) + Amp1 * math:sin(Coord / Div).

sin_convert(Coord, Div1, Amp1, Amp2) ->
    Amp1 * math:sin(Coord * Div1) + Amp2 * math:sin(Coord / Div1).
