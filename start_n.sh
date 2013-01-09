#!/bin/bash
PORT=15011
TEAM_NO=11
MULTICAST_IP="225.10.1.2"
IF_NAME=en0
for n in `seq 1 $1`
do
    ./start_1.sh $PORT $TEAM_NO $n $MULTICAST_IP $IF_NAME &
done