#!/bin/sh

if [ ! -z "$1" ]; then
    CNAME=$1
    if host $CNAME > /dev/null 2>&1; then
	echo "$CNAME already exists!"
	exit 1
    fi
else
    echo "Usage: $0 <cname to papadoc>"
    exit 1
fi
TTL=3600
SERVER=195.163.1.188
ZONE=bayour.com

nsupdate -v -k /var/cache/bind/Krmgztk.bayour.com.+157+37129.private > /dev/null <<EOF
server $SERVER
zone $ZONE.
update add $CNAME $TTL CNAME papadoc.bayour.com.
send
EOF
