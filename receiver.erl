-module(receiver).
-export([start/2]).

%%  ____ _____  ___  _____ _____
%% / ___|_   _|/ _ \|  _  \_   _|
%% |___ | | | |  _  |  _ <  | |
%% |____/ |_| |_| |_|_| |_| |_|

start(Station,Socket)->

    %% get the current system second as frame
    CurrentFrame=tools:getCurrentFrame(),

    %% assign process which receives messages to socket
    gen_udp:controlling_process(Socket,self()),

    %% start receive loop
    loop(Station,Socket,CurrentFrame).

%%  _     _____ _____ ____
%% | |   |  _  |  _  |  _ \
%% | |___| |_| | |_| |  __/
%% |_____|_____|_____|_|

loop(Station,Socket,LastFrame)->
    receive
        {udp,Socket,IP,Port,Packet}->

            %% get the current system second as frame
            CurrentFrame=tools:getCurrentFrame(),
            
            %% get the current system time in milliseconds
            Time=tools:getTimestamp(),
            
            %% get the current slot for the system time
            Slot=tools:getSlotForMsec(Time),

            %% inform the station of the incoming message
            Station ! {received,Slot,Time,Packet},
            
            loop(Station,Socket,CurrentFrame);
        kill -> 
            io:format("kill"),
            gen_udp:close(Socket),
            exit(normal);
        Any ->
            io:format("any: ~p~n",[Any])
    end.