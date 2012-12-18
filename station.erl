-module(station).
-export([start/4]).

start(StationNo,IpAddress,)->
	Receiver=spawn(reseiver:start()),
	Sender=spawn(sender:start()),
	wait_for_full_second(Sender),
	Timer=send_interval(1000,  self(), calculate_slot),
	loop(Sender,Receiver,Timer).
%%on timer error
loop(Sender,Receiver,{error,Reason})->
	werkzeug:logging("mylog.log",Reason).

loop(Sender,Receiver,{ok, Timer},Slot)->
	receive 
		calculate_slot ->
			NewSlot = get_slot(Slot),
			Sender ! {slot,NewSlot}
		{received,SenderSlot,Package} ->
			case has_collision() of
				true ->NewSlot=reset_slot();
				false-> update_used_slots()
			end,
			loop(Sender,Receiver,{ok, Timer},Slot)
		kill ->
			Sender ! kill,
			Receiver ! kill,
			cancel(Timer)
	end.

get_slot() ->.
has_collision() ->.
reset_slot() ->.
update_used_slots() ->.