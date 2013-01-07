#!/bin/bash
for host in "$@"
do
  ssh $USER@$host -o BatchMode=yes "cd $HOME/Desktop/VSP4/; kill `cat $host.pid`; rm $host.pid; killall java > /dev/null/ 2>&1"
done