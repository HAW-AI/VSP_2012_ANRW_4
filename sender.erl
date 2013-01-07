-module(sender).
-export([start/5,newPacket/2]).

%%  ____ _____  ___  _____ _____
%% / ___|_   _|/ _ \|  _  \_   _|
%% |___ | | | |  _  |  _ <  | |
%% |____/ |_| |_| |_|_| |_| |_|

start(Station,Ip,Port,MultiIp,ReceiverPort)->
	Socket=tools:get_socket(sender,Port,Ip),
	gen_udp:controlling_process(Socket,self()),
	io:format("SendSocket running on: ~p~n",[Port]),
    Dataqueue = spawn(fun()->dataqueue:start() end),
    loop(Station,Dataqueue,Socket,MultiIp,ReceiverPort).

%%  _     _____ _____ ____
%% | |   |  _  |  _  |  _ \
%% | |___| |_| | |_| |  __/
%% |_____|_____|_____|_|

loop(Station,Dataqueue,Socket,Ip,Port)->
    receive
    
        %% receive next slot from station
        {slot,NextSlot}->
            io:format("[sender] next slot: ~p~n",[NextSlot]),
            Dataqueue ! {get_data,self()},
            receive
                
                %% receive data from dataqueue
                {input,{value,Input}} ->
                    %% wait in realtime for the next slot
                    waitForSlot(NextSlot),
                    
                    
                    Station ! {get_slot, NextSlot},
                    receive
                        {new_slot,Slot} ->
                            io:format("[sender] valid slot: ~p~n",[Slot]),
                            %% create a new packet
                            Packet = newPacket(Input,Slot),
                            io:format("[sender] ready to send: ~p~n",[Packet]),
                            %% send packet with socket to ip:port
                            gen_udp:send(Socket,Ip,Port,Packet)
                    end,


                    %% repeat
                    loop(Station,Dataqueue,Socket,Ip,Port);
                %% if data is empty
                {input,empty} ->
                    %% repeat
                    loop(Station,Dataqueue,Socket,Ip,Port)
            end
	end.

newPacket(Input,NextSlot)->
    Timestamp=tools:getTimestamp(),
    <<(list_to_binary(Input))/binary,NextSlot,Timestamp:64/integer>>.

waitForSlot(Slot)->
    
    %% 50 is the length of a slot in milliseconds
    %% add 25 milliseconds to send the packet in the middle of a slot
    SlotTime=Slot*50+25,
    
    %% get the current system time in milliseconds
    CurrentTime=tools:getTimestamp(),
    io:format("[sender] next slot time: ~p~n",[SlotTime]),
    io:format("[sender] current time: ~p~n",[CurrentTime]),
    
    %% wait for the next slottime
    %% get the rest of the actual second and substract in from the slottime
    %% the result ist the time to sleep
    %% is the result nagativ their is no time to wait!
    case SlotTime-(CurrentTime rem 1000) of
        TimeToWait when (TimeToWait>0)->
            io:format("[sender] time to wait: ~p~n",[TimeToWait]),
            timer:sleep(TimeToWait);
        _TimeToWait->
            io:format("[sender] no time to wait~n"),
            ok
    end.