-module(station).
-export([start/1]).

start([Port,StationNo,MulticastIp,LocalIp])->
    {ok,MulticastIpTuple}=inet_parse:address(atom_to_list(MulticastIp)),
    {ok,LocalIpTuple}=inet_parse:address(atom_to_list(LocalIp)),
    start(list_to_integer(atom_to_list(Port)),list_to_integer(atom_to_list(StationNo)),MulticastIpTuple,LocalIpTuple).
start(Port,StationNo,MulticastIp,LocalIp)->
	ReceivePort=Port,
        SendPort=14000+StationNo,
	Station=self(),
	Receiver=spawn(fun()->receiver:start(Station,LocalIp,MulticastIp,ReceivePort) end),
	wait_for_full_second(),
	{ok, SlotTimer}=timer:send_interval(1000,  self(), frame_start),
	{Slot,_}=(random:uniform_s(20,now())),
	Sender=spawn(fun()->sender:start(Station,LocalIp,SendPort,MulticastIp,ReceivePort,Slot-1) end),
	loop(StationNo,Sender,Receiver,SlotTimer,dict:new()).

%%on timer error
loop(StationNo,Sender,Receiver,SlotTimer,SlotWishes)->
	receive 
		frame_start -> %%If reset, use new slot, else use current slot.
            io:format("--- New Frame ---~n"),
            Sender ! send,
			loop(StationNo,Sender,Receiver,SlotTimer,dict:new());

        {get_slot,CurrentSlot} ->
			io:format("[station] calculate next slot ~n"),
			Slot = get_slot(SlotWishes,CurrentSlot),
			Sender ! {next_slot,Slot},
			loop(StationNo,Sender,Receiver,SlotTimer,SlotWishes);

		{received,SenderSlot,Time,Packet} ->
			io:format("station: Received: slot: ~p; time: ~p; packet: ~p~n",[SenderSlot,Time,tools:message_to_string(Packet)]),
			SlotWishesNew = update_slot_wishes(Packet, SlotWishes),
			loop(StationNo,Sender,Receiver,SlotTimer,SlotWishesNew);
		kill ->
			Sender ! kill,
			Receiver ! kill,
			timer:cancel(SlotTimer);
		Any -> io:format("station: Received garbage: ~p~n",[Any]),
			loop(StationNo,Sender,Receiver,SlotTimer,SlotWishes)
	end.
%% wait for first slot / first full second
wait_for_full_second()->
	timer:sleep(1000 - (tools:getTimestamp() rem 1000)). 

get_slot(SlotWishes,CurrentSlot) ->
	ValidSlotWishes = dict:filter(fun(_,V) -> not (lists:member(CurrentSlot,V) andalso length(V)==1) end, SlotWishes),		%%remove CurrentSlot
	io:format("wish keys ~p~n",[dict:fetch_keys(ValidSlotWishes)]),
	FreeSlots = lists:subtract(lists:seq(0,19), dict:fetch_keys(SlotWishes)),
	{NthSlotList,_}=random:uniform_s(length(FreeSlots),now()),
	io:format("Choosing Slot ~p from ~p~n", [NthSlotList,FreeSlots]),
	lists:nth(NthSlotList, FreeSlots).

update_slot_wishes(Packet,SlotWishes) ->
    {Station,Slot,_,_} = tools:match_message(Packet),
	%% Appends the Clients to each SlotWish, so we can choose free slots afterwards
    dict:append(Slot,Station,SlotWishes).