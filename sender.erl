-module(sender).
-export([start/3]).

%%  ____ _____  ___  _____ _____
%% / ___|_   _|/ _ \|  _  \_   _|
%% |___ | | | |  _  |  _ <  | |
%% |____/ |_| |_| |_|_| |_| |_|

start(Socket,Ip,Port)->
    Dataqueue = spawn(fun()->dataqueue:start() end),
    loop(Dataqueue,Socket,Ip,Port).

%%  _     _____ _____ ____
%% | |   |  _  |  _  |  _ \
%% | |___| |_| | |_| |  __/
%% |_____|_____|_____|_|

loop(Dataqueue,Socket,Ip,Port)->
    receive
        {slot, NextSlot} ->
            io:format("[sender] next slot: ~p~n",[NextSlot]),
            Dataqueue ! {get_data,self()},
            receive
                {input,{value,Input}} ->
                    waitForSlot(NextSlot),
                    Packet = newPacket(Input,NextSlot),
                    io:format("[sender] ready to send: ~p~n",[Packet]),
                    gen_udp:send(Socket,Ip,Port,Packet),
                    loop(Dataqueue,Socket,Ip,Port);
                {input,empty} ->
                    loop(Dataqueue,Socket,Ip,Port)
            end
	end.

newPacket(Input,NextSlot)->
    Timestamp=tools:getTimestamp(),
    <<(list_to_binary(Input))/binary,NextSlot,Timestamp:64/integer>>.

waitForSlot(Slot)->
    NextSlotTime=Slot*50+25,
    CurrentTimeInMs=tools:getTimestamp(),
    io:format("[sender] next slot time: ~p~n",[NextSlotTime]),
    io:format("[sender] current time in ms: ~p~n",[CurrentTimeInMs]),
    case NextSlotTime-(CurrentTimeInMs rem 1000) of
        TimeToWait when TimeToWait > 0 ->
            io:format("[sender] time to wait: ~p~n",[TimeToWait]),
            timer:sleep(TimeToWait);
        _TimeToWait ->
            io:format("[sender] no time to wait~n"),
            ok
    end.