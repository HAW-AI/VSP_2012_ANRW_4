-module(station).
-export([start/1]).

start([TeamNo,StationNo,MulticastIp,LocalIp])->
    {ok,MulticastIpTuple}=inet_parse:address(atom_to_list(MulticastIp)),
    {ok,LocalIpTuple}=inet_parse:address(atom_to_list(LocalIp)),
    init(list_to_integer(atom_to_list(TeamNo)),list_to_integer(atom_to_list(StationNo)),MulticastIpTuple,LocalIpTuple).
start(TeamNo,StationNo,MulticastIp,LocalIp)->
	ReceivePort=15000+TeamNo,
    SendPort=14000+TeamNo,
	Receiver=spawn(reseiver:start(self(),LocalIp,MulticastIp,ReceivePort)),
	Sender=spawn(sender:start(LocalIp,SendPort)),
	wait_for_full_second(self()),
	SlotTimer=send_interval(1000,  self(), calculate_slot),
	loop(Sender,Receiver,Timer).
%%on timer error
loop(Sender,Receiver,{error,Reason})->
	werkzeug:logging("mylog.log",Reason).

loop(Sender,Receiver,{ok, SlotTimer},Slot)->
	receive 
		calculate_slot ->
			NewSlot = get_slot(Slot,UsedSlots),
			Sender ! {slot,NewSlot},
			loop(Sender,Receiver,{ok, SlotTimer},Slot)
		{received,SenderSlot,Time,Packet} ->
			werkzeug:logging("mylog.log",
				erl_format("coordinator: Received: slot:~p;time: ~p;packet: ~p~n",
				[SenderSlot,Time,tools:message_to_string(Packet)])),
			if	has_collision(SenderSlot, UsedSlots,Slot) ->
					werkzeug:logging("mylog.log",
						erl_format("coordinator: Collision detected in Slot ~p~n",[SenderSlot])),
					SlotWishesNew = update_slot_wishes(Packet, SlotWishes),
					%%CollidedStations = dict:fetch(Slot, SlotWishesNew),
					OwnStationInvolved = Slot == CurrentSlot,
					if
						OwnStationInvolved ->	
							SlotWishesWithOwn = dict:append(Slot, StationNo, SlotWishesNew),	
							loop(State#state{slotWishes=SlotWishesWithOwn, ownPacketCollided = true});
						true ->
							loop(State#state{slotWishes=SlotWishesNew})
					end;
				true ->
					SlotWishesNew=update_slot_wishes(Packet,SlotWishes),
					UsedSlotsNew = lists:append([Slot], UsedSlots),
					loop(State#state{slotWishes=SlotWishesNew, usedSlots=UsedSlotsNew})
			end;
			case has_collision() of
				true ->NewSlot=reset_slot();
				false-> update_used_slots()
			end,
			loop(Sender,Receiver,{ok, SlotTimer},Slot)
		kill ->
			Sender ! kill,
			Receiver ! kill,
			cancel(SlotTimer)
	end.
%% wait for first slot / first full second
wait_for_full_second()->
	timer:sleep(1000 - (tools:getTimestamp() rem 1000)). 
get_slot()->

get_free_slot(UsedSlots) ->
	ValidSlotWishes = dict:filter(fun(_,V) -> (length(V) == 1) end, UsedSlots),		%%remove collisions
	FreeSlots = lists:subtract(lists:seq(0,19), dict:fetch_keys(ValidSlotWishes)),
	{NthSlotList,_}=random:uniform_s(length(FreeSlots),now()),
	io:format("Choosing Slot ~p from ~p~n",[NthSlotList, FreeSlots]),
	lists:nth(NthSlotList, FreeSlots).
has_collision(Slot, UsedSlots,CurrentSlot) ->
	((lists:member(Slot, UsedSlots)) or (Slot == CurrentSlot)).
reset_slot() ->.
update_used_slots(Packet,UsedSlots) ->
    {Station,Slot,_,_} = tools:match_message(Packet),
	%% Appends the Clients to each SlotWish, so we can choose free slots afterwards
    dict:append(Slot,Station,UsedSlots).