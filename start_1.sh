#!/bin/bash
# example usage: 15100 10 1 "225.10.1.2" eth0
IF_IP=$(/sbin/ifconfig $5 | grep 'inet ' | cut -d: -f2 | awk '{ print $2}')
echo "Using IP:" $IF_IP "for interface" $5
CLASSPATH=`dirname $0`
HOST_NO=${HOSTNAME##lab}
java -cp $CLASSPATH datasource.DataSource $2 $3 | erl -sname sender$3 -setcookie hallo -boot start_sasl -noshell -s station start $1 $3 $4 $IF_IP > $3.log &
echo $! > $3.pid
