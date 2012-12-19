-module(receiver).
-export([start/4]).

%%  ____ _____  ___  _____ _____
%% / ___|_   _|/ _ \|  _  \_   _|
%% |___ | | | |  _  |  _ <  | |
%% |____/ |_| |_| |_|_| |_| |_|


start(Station,Ip,MultIp,Port)->
	Socket=tools:get_socket(receiver,Port,Ip,MultIp),
	%% assign process which receives messages to socket
	gen_udp:controlling_process(Socket,self()),
	werkzeug:logging("myreceiverlog.log",lists:concat(["ReceiveSocket running on: ",Port,"~n"])),

    %% start receive loop
    loop(Station,Socket).

%%  _     _____ _____ ____
%% | |   |  _  |  _  |  _ \
%% | |___| |_| | |_| |  __/
%% |_____|_____|_____|_|

loop(Station,Socket)->
    receive
        {udp,_Socket,_IP,_Port,Packet}->
            %% get the current system time in milliseconds
            Time=tools:getTimestamp(),          
            %% get the current slot for the system time
            Slot=tools:getSlotForMsec(Time),
            %% inform the station of the incoming message
            Station ! {received,Slot,Time,Packet},
            
            loop(Station,Socket);
        kill -> 
            werkzeug:logging("myreceiverlog.log","kill"),
            gen_udp:close(Socket),
            exit(normal);
        Any ->
            iwerkzeug:logging("myreceiverlog.log",lists:concat(["any: ",Any,"~n"]))
    end.