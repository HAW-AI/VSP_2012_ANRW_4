-module(tools).
-compile(export_all).
-author("Raimund Wege").

%% the current frame is the current second
getCurrentFrame()->
	{_,Secs,_}=>now(),
	Secs.

%% the current time in milliseconds as timestamp
%% 1 megasecond are 1000000 seconds
%% 1 second are 1000000 microseconds
%% 1 microsecond div 1000 are 1000 milliseconds
getTimestamp()->
    {MegaSecs,Secs,MicroSecs}=now(),
    ((MegaSecs*1000000+Secs)*1000000+MicroSecs) div 1000.

%% the current slot for a time in milliseconds
%% 1000 is a full second in milliseconds
%% 50 is the length of a slot in milliseconds
getSlotForMsec(Time)->
    trunc(((Time rem 1000)/50)).

getStationConfigData() ->
	{ok, Configurations} = file:consult("station.cfg"),
	A = proplists:get_value(a, Configurations),
	B = proplists:get_value(b, Configurations),
	C = proplists:get_value(c, Configurations),
	{A,B,C}.