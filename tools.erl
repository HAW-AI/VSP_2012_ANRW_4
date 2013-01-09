-module(tools).
-compile(export_all).
-author("Raimund Wege").
-define(SOL_SOCKET,   16#ffff).
-define(SO_REUSEPORT, 16#0200).

reuse_port() ->
{raw,?SOL_SOCKET,?SO_REUSEPORT,<<1:32/native>>}.

%% the current frame is the current second
getCurrentFrame()->
	{_,Secs,_}=now(),
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

%%binary => Received Packet is delivered as a binary.
%%{active, true} => If the value is true, which is the default, everything received from the socket will be sent as messages to the receiving process.
%%{ip, IP} => If the host has several network interfaces, this option specifies which one to use.
get_socket(sender,Port,IP)->
	{ok,Socket}=gen_udp:open(Port, [binary, {active, true}, {ip, IP}, inet, {multicast_loop, true}, {multicast_if, IP}]),
	Socket.
get_socket(receiver,Port,IP,MultIP)->
	{ok,Socket}=gen_udp:open(Port, [binary, {active, true}, {multicast_if, IP}, inet,{reuseaddr,true},reuse_port(), {multicast_loop, true}, {add_membership, {MultIP,IP}}]),
	Socket.

match_message(_Packet= <<_Rest:8/binary,StationBin:2/binary,NutzdatenBin:14/binary,SlotBin:8/integer,TimestampBin:64/integer>>)	->
	Station=list_to_integer(binary_to_list(StationBin)),
    Slot=SlotBin,
	Timestamp=TimestampBin,
	Nutzdaten= binary_to_list(NutzdatenBin),
	{Station,Slot,Nutzdaten,Timestamp}.

match_message_for_to_string(_Packet= <<PrefixBin:10/binary,NutzdatenBin:14/binary,SlotBin:8/integer,TimestampBin:64/integer>>)	->
	Prefix = binary_to_list(PrefixBin),
    	Slot=SlotBin,
	Timestamp=TimestampBin,
	Nutzdaten= binary_to_list(NutzdatenBin),
	{Prefix,Slot,Nutzdaten,Timestamp}.

message_to_string(Packet) ->
	{Prefix,Slot,Nutzdaten,Timestamp} = match_message_for_to_string(Packet),
	[Prefix,Slot,Nutzdaten,Timestamp].
