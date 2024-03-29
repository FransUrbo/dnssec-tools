#!/bin/sh

# $Id: dnssec-sign.sh,v 1.7 2003-04-03 09:28:58 turbo Exp $

if [ -f /etc/dnssec-tools.conf ]; then
    . /etc/dnssec-tools.conf
else
    echo "No config file found"
    exit 1
fi

# --------------
# Get the old "K$zone.+[0-9]*[0-9].key" file
get_old_key () {
    local zone="$1"

    [ ! -z "$verbose" ] && echo -n "    Getting OLD key: "
    OLDKEY="`(cd $DIR_KEYS && find -name "K$zone.+[0-9]*[0-9].key" -maxdepth 1 -exec ls -ltr {} \; | tail -n1 | sed -e 's@.*\./@@')`"
    [ ! -z "$OLDKEY" ] && OLDKEY="$DIR_KEYS/$OLDKEY"

    if [ ! -z "$verbose" ]; then
	if [ ! -z "$OLDKEY" ]; then
	    echo "$OLDKEY"
	else
	    echo "not found!"
	fi
    fi

    mkdir -p $DIR_KEYS/old
}

# --------------
# Create the keys, keysets and sign the key
create_key () {
    local zone="$1"

    # Generate private/public key
    [ ! -z "$verbose" ] && echo -n "    Generating key ($KEY_ALG/$KEY_LEN): "
    KEY_ZONE=`dnssec-keygen -a $KEY_ALG -b $KEY_LEN -n ZONE -r $RANDDEV $zone.`
    [ ! -z "$verbose" ] && echo "$PWD/$KEY_ZONE"

    # Should we include the old key?
    [ ! -z "$resign" ] && get_old_key $zone

    # Generate keyset (possibly with the old key)
    [ ! -z "$OLDKEY" ] && echo_line=" (w/ old key)"
    [ ! -z "$verbose" ] && echo -n "    Generating keyset$echo_line: "
    KEY_SET=`dnssec-makekeyset -t $KEY_TTL -s +1 -e +2592000 $OLDKEY $KEY_ZONE.key`
    [ ! -z "$verbose" ] && echo "$PWD/$KEY_SET"

    # Sign the keyset
    [ ! -z "$OLDKEY" ] && echo_line=" (inc old key)"
    [ ! -z "$verbose" ] && echo -n "    Signing zone key$echo_line: "
    KEY_SIGNED=`dnssec-signkey $KEY_SET $KEY_ZONE.private`
    [ ! -z "$verbose" ] && echo "$PWD/$KEY_SIGNED"

    if [ ! -z "$resign" -a ! -z "$OLDKEY" ]; then
	# Replace the old keyset
	mv $DIR_KEYS/signedkey-$zone. $DIR_KEYS/old
	mv $KEY_SIGNED $DIR_KEYS/signedkey-$zone.
    fi

    rm $KEY_SET ; mv * $DIR_KEYS/ && rm -R $TMPDIR
}

# --------------
# Sign the zone (replacing the entry '$INCLUDE ...' after the SOA)
sign_zone () {
    local zone="$1"
    local file="$2"

    # We MUST be in the directory of the K*.{private,key} files!
    cd $DIR_KEYS

    # A temporary zone file containing the zone key etc
    TMPFILE=`tempfile`

    # Include the NEW key file into the zone file
    [ ! -z "$verbose" ] && echo -n "    Setting up zone file: "
    (cat $DIR_BIND/.original/$file ; echo "\$INCLUDE $KEY_ZONE.key") > $TMPFILE
    # Possibly include the OLD key file into the zone file
    [ ! -z "$OLDKEY" ] && (cat $DIR_BIND/.original/$file ; echo "\$INCLUDE $OLDKEY") >> $TMPFILE
    [ ! -z "$verbose" ] && echo "$TMPFILE"

    # Sign the zone file
    [ ! -z "$verbose" ] && echo -n "    Signing zone file: "
    SIGNED=`dnssec-signzone -a -d . -o $zone. $TMPFILE $KEY_ZONE.private 2> /dev/null`
    SIGNED_NEW="$DIR_BIND/db.$zone.signed.new"
    [ ! -z "$verbose" ] && echo "$SIGNED"

    # Move the signed zone file to the current directory
    [ ! -z "$verbose" ] && echo -n "    Moving temp zone file: $SIGNED -> "
    mv $SIGNED $SIGNED_NEW
    chown nobody.nogroup $SIGNED_NEW
    chmod 660 $SIGNED_NEW
    # ...  remember it for later
    SIGNED_FILES="$SIGNED_FILES $SIGNED_NEW"
    # .. and remove the temp file
    rm $TMPFILE
    [ ! -z "$verbose" ] && echo "[1m$SIGNED_NEW[0m"

    # Move the OLD keyfile out of the way
    OLDFILES=`echo $OLDKEY | sed 's@\.key@\*@'`
    [ ! -z "$OLDFILES" ] && mv $OLDFILES $DIR_KEYS/old
}

# --------------
# Setup DNSSEC keys etc
dnssec_keys () {
    (cat <<EOF
// Setup DNSSEC keys etc
trusted-keys {
EOF
	for key in $DIR_KEYS/K*.key; do
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
}

# --------------
# Show help message and quit
help () {
    echo "Usage:   `basename $0` [option] zone"
    echo "Options: -h,--help       Show this help"
    echo "         -v,--verbose    Be verbose about what's going on"
    echo "         -r,--resign     Re-sign zone file"
    echo "         -a,--all-zones  Sign all zones found"
    echo
    exit 0
}

# --------------
# Create a temp directory and cd into it
temp_dir () {
    TMPDIR=`tempfile` ; rm $TMPDIR ; mkdir $TMPDIR
    chmod 700 $TMPDIR ; cd $TMPDIR
}

# =============================================================================

# --------------
# Get the CLI options...
if [ "$#" -lt 1 ]; then
    help
else
    TEMP=`getopt -o hrva --long help,resign,verbose,all-zones -- "$@"`
    eval set -- "$TEMP"
    while true ; do
	case "$1" in
	    -h|--help)
		help
		;;
	    -r|--resign)
		resign=1 ; shift ;;
	    -v|--verbose)
		verbose=1 ; shift ;;
	    -a|--all-zones)
		allzones=1 ; shift ;;
	    --)
		shift ; ZONES="$*" ; break ;;
	    *)
		echo "Internal error!" ; exit 1 ;;
	esac
    done
fi

# --------------
# Check if (ANY of) the zone file(s) exists
if [ ! -z "$allzones" ]; then
    for zone in `find $DIR_BIND/.original/* | egrep -v 'root|localhost|new$|in-addr.arpa'`; do
	zone=`echo $zone | sed "s@$DIR_BIND/.original/db.@@"`
	ZONES="$ZONES $zone"
    done
fi

ZONE=
for zone in $ZONES; do
    if [ -f "$DIR_BIND/.original/db.$zone" ]; then
	ZONE="$ZONE$zone"
    fi
    [ ! -z "$ZONE" ] && ZONE="$ZONE "
done
ZONES=$ZONE

# --------------
# Go through the zones files, creating new and signing those
if [ ! -z "$ZONES" ]; then
    [ ! -z "$verbose" ] && echo "Zones to (re-)sign: $ZONES"

    for zone in $ZONES; do
	[ ! -z "$verbose" ] && echo "  Zone: $zone"
	temp_dir
	create_key $zone
	sign_zone $zone db.$zone
    done
else
    echo "No zonefiles!"
    exit 1
fi

# --------------
# Update the named.conf.trusted-keys file
dnssec_keys

# --------------
echo "Signed files:"
for file in $SIGNED_FILES; do
    echo "  $file"
done
