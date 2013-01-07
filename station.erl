-module(station).
-export([start/1]).

start([Port,TeamNo,StationNo,MulticastIp,LocalIp])->
    {ok,MulticastIpTuple}=inet_parse:address(atom_to_list(MulticastIp)),
    {ok,LocalIpTuple}=inet_parse:address(atom_to_list(LocalIp)),
    start(list_to_integer(atom_to_list(Port)),list_to_integer(atom_to_list(TeamNo)),list_to_integer(atom_to_list(StationNo)),MulticastIpTuple,LocalIpTuple).
start(Port,TeamNo,StationNo,MulticastIp,LocalIp)->
	ReceivePort=Port,
    SendPort=14000+TeamNo,
	Station=self(),
	Receiver=spawn(fun()->receiver:start(Station,LocalIp,MulticastIp,ReceivePort) end),
	Sender=spawn(fun()->sender:start(Station,LocalIp,SendPort,MulticastIp,ReceivePort) end),
	wait_for_full_second(),
	{ok, SlotTimer}=timer:send_interval(1000,  self(), calculate_slot),
	{Slot,_}=(random:uniform_s(20,now())),
	loop(StationNo,Sender,Receiver,SlotTimer,Slot-1,[],dict:new(),true).
%%on timer error
loop(StationNo,Sender,Receiver,SlotTimer,Slot,UsedSlots,SlotWishes,Reset)->
	receive 
		calculate_slot -> %%If reset, use new slot, else use current slot.
			NewSlot = get_slot(Slot,SlotWishes,Reset),
            Sender ! {slot,NewSlot},
            loop(StationNo,Sender,Receiver,SlotTimer,NewSlot,[],dict:new(),false);


        {get_slot, Slot} ->
            IsValid = not dict:is_key(Slot, SlotWishes),
            NewSlot = get_slot(Slot,SlotWishes,IsValid),
            Sender ! {new_slot,NewSlot},
            loop(StationNo,Sender,Receiver,SlotTimer,NewSlot,[],dict:new(),false);


        {received,SenderSlot,Time,Packet} ->
			io:format("station: Received: slot: ~p; time: ~p; packet: ~p~n",[SenderSlot,Time,tools:message_to_string(Packet)]),
			SlotWishesNew = update_slot_wishes(Packet, SlotWishes),
			HasColl = has_collision(SenderSlot,UsedSlots,Slot),
			if	
				HasColl ->
					io:format("station: Collision detected in Slot ~p~n",[SenderSlot]),
					if	SenderSlot == Slot -> %%Collision with own slot, use a new slot.
							SlotWishesWithOwn = dict:append(SenderSlot, StationNo, SlotWishesNew),	
							loop(StationNo,Sender,Receiver,SlotTimer,Slot,UsedSlots,SlotWishesWithOwn,true);
						true -> %%Collision with another slot, just ignore.
							loop(StationNo,Sender,Receiver,SlotTimer,Slot,UsedSlots,SlotWishesNew,false)
					end;
				true -> %%All is well
					SlotWishesNew=update_slot_wishes(Packet,SlotWishes),
					UsedSlotsNew = lists:append([Slot], UsedSlots),
					loop(StationNo,Sender,Receiver,SlotTimer,Slot,UsedSlotsNew,SlotWishesNew,Reset)
			end;			
		kill ->
			Sender ! kill,
			Receiver ! kill,
			timer:cancel(SlotTimer);
		Any -> io:format("station: Received garbage: ~n"),
			loop(StationNo,Sender,Receiver,SlotTimer,Slot,UsedSlots,SlotWishes,Reset)
	end.
%% wait for first slot / first full second
wait_for_full_second()->
	timer:sleep(1000 - (tools:getTimestamp() rem 1000)). 

get_slot(_,SlotWishes,true) ->
	ValidSlotWishes = dict:filter(fun(_,V) -> (length(V) == 1) end, SlotWishes),		%%remove collisions
	FreeSlots = lists:subtract(lists:seq(0,19), dict:fetch_keys(ValidSlotWishes)),
	{NthSlotList,_}=random:uniform_s(length(FreeSlots),now()),
	io:format("Choosing Slot ~p from ~p~n", [NthSlotList,FreeSlots]),
	lists:nth(NthSlotList, FreeSlots);

get_slot(Slot,_,false) -> Slot.

has_collision(Slot,UsedSlots,CurrentSlot) ->
	((lists:member(Slot, UsedSlots)) or (Slot == CurrentSlot)).

update_slot_wishes(Packet,SlotWishes) ->
    {Station,Slot,_,_} = tools:match_message(Packet),
	%% Appends the Clients to each SlotWish, so we can choose free slots afterwards
    dict:append(Slot,Station,SlotWishes).