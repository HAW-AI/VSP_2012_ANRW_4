-module(station).
-export([start/1]).

start([TeamNo,StationNo,MulticastIp,LocalIp])->
    {ok,MulticastIpTuple}=inet_parse:address(atom_to_list(MulticastIp)),
    {ok,LocalIpTuple}=inet_parse:address(atom_to_list(LocalIp)),
    start(list_to_integer(atom_to_list(TeamNo)),list_to_integer(atom_to_list(StationNo)),MulticastIpTuple,LocalIpTuple).
start(TeamNo,StationNo,MulticastIp,LocalIp)->
	ReceivePort=15000+TeamNo,
    SendPort=14000+TeamNo,
	Receiver=spawn(receiver:start(self(),LocalIp,MulticastIp,ReceivePort)),
	Sender=spawn(sender:start(LocalIp,SendPort)),
	wait_for_full_second(),
	{ok, SlotTimer}=timer:send_interval(1000,  self(), calculate_slot),
	{Slot,_}=(random:uniform_s(20,now())),
	loop(StationNo,Sender,Receiver,SlotTimer,Slot-1,[],dict:new(),false).
%%on timer error
loop(StationNo,Sender,Receiver,SlotTimer,Slot,UsedSlots,SlotWishes,Reset)->
	receive 
		calculate_slot -> %%If reset, use new slot, else use current slot.
			NewSlot = get_slot(Slot,SlotWishes,Reset),
			Sender ! {slot,NewSlot},
			loop(StationNo,Sender,Receiver,SlotTimer,NewSlot,[],dict:new(),false);
		{received,SenderSlot,Time,Packet} ->
			werkzeug:logging("mylog.log", lists:concat(["coordinator: Received: slot:",SenderSlot,";time: ", Time,";packet: ",tools:message_to_string(Packet),"\n"])),
			SlotWishesNew = update_slot_wishes(Packet, SlotWishes),
			HasColl = has_collision(SenderSlot,UsedSlots,Slot),
			if	
				HasColl ->
					werkzeug:logging("mylog.log", lists:concat(["coordinator: Collision detected in Slot ",SenderSlot,"\n"])),
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
		Any -> io:format("coordinator: Received garbage: ~p~n",[Any]),
			loop(StationNo,Sender,Receiver,SlotTimer,Slot,UsedSlots,SlotWishes,Reset)
	end.
%% wait for first slot / first full second
wait_for_full_second()->
	timer:sleep(1000 - (tools:getTimestamp() rem 1000)). 

get_slot(_,SlotWishes,true) ->
	ValidSlotWishes = dict:filter(fun(_,V) -> (length(V) == 1) end, SlotWishes),		%%remove collisions
	FreeSlots = lists:subtract(lists:seq(0,19), dict:fetch_keys(ValidSlotWishes)),
	{NthSlotList,_}=random:uniform_s(length(FreeSlots),now()),
	werkzeug:logging("mylog.log", lists:concat(["Choosing Slot ", NthSlotList," from ", FreeSlots,"\n"])),
	lists:nth(NthSlotList, FreeSlots);

get_slot(Slot,_,false) -> Slot.

has_collision(Slot,UsedSlots,CurrentSlot) ->
	((lists:member(Slot, UsedSlots)) or (Slot == CurrentSlot)).

update_slot_wishes(Packet,SlotWishes) ->
    {Station,Slot,_,_} = utilities:match_message(Packet),
	%% Appends the Clients to each SlotWish, so we can choose free slots afterwards
    dict:append(Slot,Station,SlotWishes).