#!/bin/sh

# $Id: dnssec-zone_update.sh,v 1.1 2004-07-14 11:17:46 turbo Exp $

TTL=3600
ZONE=bayour.com
HOSTNAME=meduza
NS=212.214.70.50

# Don't change anything below...
# ------------------------------

KEYFILE=/var/cache/bind/HostKeys/K`echo $HOSTNAME`.`echo $ZONE`*.private

# Get IP on 'external' interface
TMPFILE=`tempfile --prefix=dns.`
wget --quiet --output-document=$TMPFILE http://checkip.dyndns.org
IP=`cat $TMPFILE | sed -e 's@.*: @@' -e 's@<.*@@'`
rm -f $TMPFILE

exit 1

if [ -z "$1" ]; then
    new_ip_address=$IP
else
    new_ip_address=$1
fi

nsupdate -v -k $KEYFILE > /dev/null <<EOF
server $NS
zone $ZONE.
update delete $HOSTNAME.$ZONE A
update add $HOSTNAME.$ZONE $TTL A $new_ip_address
send
EOF
