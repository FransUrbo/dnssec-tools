#!/bin/sh

TTL=3600
SERVER=195.163.1.188
ZONE=bayour.com
HOSTNAME=meduza.bayour.com
KEYFILE=/var/cache/bind/Kmeduza.bayour.com.+157+51061.private
if [ -z "$1" ]; then
    new_ip_address=213.67.237.4
else
    new_ip_address=$1
fi

nsupdate -v -k $KEYFILE > /dev/null <<EOF
server $SERVER
zone $ZONE.
update delete $HOSTNAME A
update add $HOSTNAME $TTL A $new_ip_address
send
EOF
