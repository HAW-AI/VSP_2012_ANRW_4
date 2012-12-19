-module(sender).
-export([start/4]).

%%  ____ _____  ___  _____ _____
%% / ___|_   _|/ _ \|  _  \_   _|
%% |___ | | | |  _  |  _ <  | |
%% |____/ |_| |_| |_|_| |_| |_|

start(Ip,Port,MultiIp,ReceiverPort)->
	Socket=tools:get_socket(sender,Port,Ip),
	werkzeug:logging("mysenderlog.log",lists:concat(["SendSocket running on: ",Port,"\n"])),
    Dataqueue = spawn(fun()->dataqueue:start() end),
    loop(Dataqueue,Socket,MultiIp,ReceiverPort).

%%  _     _____ _____ ____
%% | |   |  _  |  _  |  _ \
%% | |___| |_| | |_| |  __/
%% |_____|_____|_____|_|

loop(Dataqueue,Socket,Ip,Port)->
    receive
    
        %% receive next slot from station
        {slot,NextSlot}->
            werkzeug:logging("mysenderlog.log", lists:concat(["[sender] next slot: ",NextSlot,"\n"])),
            Dataqueue ! {get_data,self()},
            receive
                
                %% receive data from dataqueue
                {input,{value,Input}} ->
                    
                    %% wait in realtime for the next slot
                    waitForSlot(NextSlot),
                    
                    %% create a new packet
                    Packet = newPacket(Input,NextSlot),
                    werkzeug:logging("mysenderlog.log", lists:concat(["[sender] ready to send: ",binary_to_list(Packet),"\n"])),
                    
                    %% send packet with socket to ip:port
                    gen_udp:send(Socket,Ip,Port,Packet),
                    
                    %% repeat
                    loop(Dataqueue,Socket,Ip,Port);
                
                %% if data is empty
                {input,empty} ->
                    
                    %% repeat
                    loop(Dataqueue,Socket,Ip,Port)
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
    werkzeug:logging("mysenderlog.log", lists:concat(["[sender] next slot time: ",SlotTime,"\n"])),
    werkzeug:logging("mysenderlog.log", lists:concat(["[sender] current time: ",CurrentTime,"\n"])),
    
    %% wait for the next slottime
    %% get the rest of the actual second and substract in from the slottime
    %% the result ist the time to sleep
    %% is the result nagativ their is no time to wait!
    case SlotTime-(CurrentTime rem 1000) of
        TimeToWait when (TimeToWait>0)->
            werkzeug:logging("mysenderlog.log", lists:concat(["[sender] time to wait: ",TimeToWait,"~n"])),
            timer:sleep(TimeToWait);
        _TimeToWait->
            werkzeug:logging("mysenderlog.log", "[sender] no time to wait\n"),
            ok
    end.