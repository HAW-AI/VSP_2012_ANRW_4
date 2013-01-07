#!/bin/bash
for pid_name in `ls -1 | grep [\.]pid`
do
host=${pid_name%.pid}
   echo "Killing: " $host
   ssh $USER@$host -o StrictHostKeyChecking=no -o BatchMode=yes "cd $HOME/Desktop/VSP4/; kill `cat $host.pid`; rm $host.pid; killall java > /dev/null 2>&1"
done