#!/bin/bash
# example usage: 15011 10 "225.10.1.2" eth0
IF_IP=$(/sbin/ifconfig $4 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $2}')
echo "Using IP:" $IF_IP "for interface" $4
CLASSPATH=`dirname $0`
HOST_NO=${HOSTNAME##lab}
java -cp $CLASSPATH datasource.DataSource $2 $HOST_NO | erl -sname sender -setcookie hallo -boot start_sasl -noshell -s station start $1 $2 $HOST_NO $3 $IF_IP > $HOSTNAME.log &
echo $! > $HOSTNAME.pid