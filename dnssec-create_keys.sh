#!/bin/sh

# $Id: dnssec-create_keys.sh,v 1.3 2003-03-28 12:43:50 turbo Exp $

# --------------
# Set some default variables
DIR_BIND=/etc/bind			# Where is the zones files (db.*) that Bind9 loads (ie, the signed zone files)?
					#  - Original zone files are in $DIR_BIND/.original
DIR_KEYS=/var/cache/bind		# Keyfiles must be in 'directory' clause of named.conf!

CURRENTDATE=`date +"%Y%m%d%H%M%S"`	# Current day and time (YYYYMMDDHHMMSS) -> 20030218160510

KEY_TTL=86400				# Key TTL in seconds (86400 -> 24 hours)
KEY_ALG=RSA				# Key algorithm: RSA | RSAMD5 | DH | DSA | HMAC-MD5
KEY_LEN=2048				# Key size, in bits:	RSA:		[512..4096]
					#			DH:		[128..4096]
					#			DSA:		[512..1024] and divisible by 64
					#			HMAC-MD5:	[1..512]

# What zones whould we create keys for?
if [ -z "$1" ]; then
    ZONES=""
    for zone in `find $DIR_BIND/.original/* | egrep -v 'root|localhost|new$|in-addr.arpa'`; do
	zone=`echo $zone | sed "s@$DIR_BIND/.original/db.@@"`
	ZONES="$ZONES $zone"
    done
else
    ZONES="$*"
fi

# A temp file for temporary storage
TMPFILE=`tempfile`

# ----------

# We must have the K*.{key,private} files in current dir!
cd $DIR_KEYS

# Go through the (base) zones files, creating new and signing those
for zone in $ZONES; do
    zonefile="db.$zone"

    # Create the keys, keysets and sign the key
    echo -n "$zone"
    KEY_ZONE=`dnssec-keygen -a $KEY_ALG -b $KEY_LEN -n ZONE $zone.` && echo -n "."
    KEY_SET=`dnssec-makekeyset -t $KEY_TTL -s +1 -e +2592000 $KEY_ZONE.key` && echo -n "."
    KEY_SIGNED=`dnssec-signkey $KEY_SET $KEY_ZONE.private` && echo -n "."

    # Sign the zone (replacing the entry '$INCLUDE ...' after the SOA)
    (cat $DIR_BIND/.original/$zonefile ; echo "\$INCLUDE $DIR_KEYS/$KEY_ZONE.key") > $TMPFILE
    dnssec-signzone -a -d $DIR_KEYS -o $zone. $TMPFILE
    mv $TMPFILE.signed $DIR_BIND/$zonefile.signed
done
rm $TMPFILE

(cat <<EOF 
// Setup DNSSEC keys etc
trusted-keys {
EOF
for key in $DIR_KEYS/HostKeys/K*.key; do
    cat $key | perl -n -e '
local ($dn, $class, $type, $flags, $proto, $alg, @rest) = split;
local $key = join("", @rest);
if($alg ne "157") {
print "\t\"$dn\" $flags $proto $alg \"$key\";\n";
}
'
done
cat <<EOF
};
EOF
) > $TMPFILE
mv $TMPFILE $DIR_BIND/named.conf.trusted-keys

chown nobody.nogroup $DIR_BIND/db.* && chmod 644 $DIR_BIND/db.*
chown nobody.nogroup $DIR_KEYS/K*.key && chmod 644 $DIR_KEYS/K*.key
chown root.root $DIR_KEYS/{signedkey,keyset}-* && chmod 600 $DIR_KEYS/{signedkey,keyset}-*
chown root.root $DIR_KEYS/*.private && chmod 600 $DIR_KEYS/*.private
chown bind9.bind9 $DIR_BIND/named.conf*
chmod 640 $DIR_BIND/named.conf*
