#!/bin/bash
PORT=15011
TEAM_NO=11
MULTICAST_IP="225.10.1.6"
IF_NAME=eth2
for host in "$@"
do
ssh $USER@$host -o StrictHostKeyChecking=no -o BatchMode=yes "cd /$HOME/Desktop/VSP4/; ./start.sh $PORT $TEAM_NO $MULTICAST_IP $IF_NAME &"
done 
