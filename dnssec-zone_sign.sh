#!/bin/sh

# Where is the zones files (db.*)?
DIR_BIND=/etc/bind

# Keyfiles must be in 'directory' clause of named.conf!
DIR_KEYS=/var/cache/bind

# What zones whould we sign?
if [ -z "$1" ]; then
    ZONES="localhost 127.in-addr.arpa 0.in-addr.arpa 255.in-addr.arpa 1.168.192.in-addr.arpa bayour.com.internal bayour.com.external fjortis.com winas.com thegamestudio.com thegamestudio.se machineworx.com machineworx.org agby.net"
else
    ZONES="$*"
fi

# A temp file for temporary storage
TMPFILE=`tempfile -d $DIR_BIND -p tmp-`

# ----------

# We must have the K*.{key,private} files in current dir!
cd $DIR_KEYS

# Go through the (base) zones files, creating new and signing those
for zone in $ZONES; do
    zonefile="$zone" ; zone="`echo $zone | sed -e 's@.internal@@' -e 's@.external@@'`"
    key="$DIR_KEYS/signedkey-$zone."

    echo -n "$zone "

    (cat $DIR_BIND/.original/db.$zonefile; echo "\$INCLUDE $key") > $TMPFILE
    RES=`dnssec-signzone -a -d $DIR_KEYS -o $zone. $TMPFILE`
    mv $TMPFILE.signed $DIR_BIND/db.$zonefile.signed
done
rm $TMPFILE

# Change owner, group and modes to good ones
chown nobody.nogroup $DIR_BIND/db.*
chmod 644 $DIR_BIND/db.*
