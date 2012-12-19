-module(tools).
-compile(export_all).
-author("Raimund Wege").

getCurrentFrame()->
	{_,Secs,_}=>now(),
	Secs.
    
getTimestamp()->
    {MegaSecs,Secs,MicroSecs}=now(),
    ((MegaSecs*1000000+Secs)*1000000+MicroSecs) div 1000.

getSlotForMsec(Time)->
    trunc(((Time rem 1000)/50)).

getStationConfigData() ->
	{ok, Configurations} = file:consult("station.cfg"),
	A = proplists:get_value(a, Configurations),
	B = proplists:get_value(b, Configurations),
	C = proplists:get_value(c, Configurations),
	{A,B,C}.