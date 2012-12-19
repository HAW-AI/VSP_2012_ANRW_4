#!/bin/bash
# example usage: 10 "225.10.1.2" eth0
IF_IP=$(/sbin/ifconfig $3 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
echo "Using IP:" $IF_IP "for interface" $3
CLASSPATH=`dirname $0`
HOST_NO=${HOSTNAME##lab}
java -cp $CLASSPATH datasource.DataSource $1 $HOST_NO | erl -sname sender -setcookie hallo -boot start_sasl -noshell -s coordinator start $1 $HOST_NO $2 $IF_IP > $HOSTNAME.log &
echo $! > $HOSTNAME.pid