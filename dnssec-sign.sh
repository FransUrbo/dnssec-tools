#!/bin/sh -e

# --------------
# Set some default variables
DIR_BIND=/etc/bind			# Where is the zones files (db.*)?
DIR_KEYS=/var/cache/bind		# Keyfiles must be in 'directory' clause of named.conf!
CURRENTDATE=`date +"%Y%m%d%H%M%S"`	# Current day and time (YYYYMMDDHHMMSS) -> 20030218160510
CURRENTWORKDIR=`pwd`

KEY_TTL=86400				# Key TTL in seconds (86400 -> 24 hours)
KEY_ALG=RSA				# Key algorithm: RSA | RSAMD5 | DH | DSA | HMAC-MD5
KEY_LEN=1024				# Key size, in bits:	RSA:		[512..4096]
					#			DH:		[128..4096]
					#			DSA:		[512..1024] and divisible by 64
					#			HMAC-MD5:	[1..512]


# DEBUG
# DIR_KEYS=$CURRENTWORKDIR/cache

# --------------
# Get the old "K$zone.+[0-9]*[0-9].key" file
get_old_key () {
    local zone="$1"

    [ ! -z "$verbose" ] && echo -n "Getting OLD key: "
    OLDKEY="`(cd $DIR_KEYS && find -name "K$zone.+[0-9]*[0-9].key" -maxdepth 1 | sed 's@^\./@@')`"
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
    [ ! -z "$verbose" ] && echo -n "Generating key ($KEY_ALG/$KEY_LEN): "
    KEY_ZONE=`dnssec-keygen -a $KEY_ALG -b $KEY_LEN -n ZONE $zone.`
    [ ! -z "$verbose" ] && echo "done."

    # Should we include the old key?
    [ ! -z "$resign" ] && get_old_key $zone

    # Generate keyset (possibly with the old key)
    [ ! -z "$OLDKEY" ] && echo_line=" (w/ old key)"
    [ ! -z "$verbose" ] && echo -n "Generating keyset$echo_line: "
    KEY_SET=`dnssec-makekeyset -t $KEY_TTL -s +1 -e +2592000 $OLDKEY $KEY_ZONE.key`
    [ ! -z "$verbose" ] && echo "done."

    # Sign the keyset
    [ ! -z "$OLDKEY" ] && echo_line=" (inc old key)"
    [ ! -z "$verbose" ] && echo -n "Signing zone key$echo_line: "
    KEY_SIGNED=`dnssec-signkey $KEY_SET $KEY_ZONE.private`
    [ ! -z "$verbose" ] && echo "done."

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

    cd $DIR_KEYS

    # A temp file for temporary storage
    TMPFILE=`tempfile`

    # Include the key file(s) into the zone file
    [ ! -z "$verbose" ] && echo -n "Setting up zone file: "
    (cat $CURRENTWORKDIR/$file ; echo "\$INCLUDE $KEY_ZONE.key") > $TMPFILE
    [ ! -z "$OLDKEY" ] && (cat $CURRENTWORKDIR/$file ; echo "\$INCLUDE $OLDKEY") >> $TMPFILE
    [ ! -z "$verbose" ] && echo "done."

    # Sign the zone file
    [ ! -z "$verbose" ] && echo -n "Signing zone file: "
    SIGNED=`dnssec-signzone -a -d . -o $zone. $TMPFILE $KEY_ZONE.private 2> /dev/null`
    [ ! -z "$verbose" ] && echo "done."

    # Move the signed zone file to the current directory
    mv $SIGNED $CURRENTWORKDIR/$file.signed
    # ...  remember it for later
    SIGNED_FILES="$SIGNED_FILES $CURRENTWORKDIR/$file.signed"
    # .. and remove the temp file
    rm $TMPFILE

    OLDFILES=`echo $OLDKEY | sed 's@\.key@\*@'`
    [ ! -z "$OLDFILES" ] && mv $OLDFILES $DIR_KEYS/old
}

# --------------
# Show help message and quit
help () {
    echo "Usage:   `basename $0` [option] zone"
    echo "Options: -h,--help     Show this help"
    echo "         -v,--verbose  Be verbose about what's going on"
    echo "         -r,--resign   Re-sign zone file"
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
    TEMP=`getopt -o hrv --long help,resign,verbose -- "$@"`
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
	    --)
		shift ; ZONES="$*" ; break ;;
	    *)
		echo "Internal error!" ; exit 1 ;;
	esac
    done
fi

# --------------
# Check if (ANY of) the zone file(s) exists
for zone in $ZONES; do
    if [ -f "db.$zone" ]; then
	ZONE="$ZONE$zone"
    fi
    [ ! -z "$ZONE" ] && ZONE="$ZONE "
done
ZONES=$ZONE

# --------------
# Go through the zones files, creating new and signing those
if [ ! -z "$ZONES" ]; then
    temp_dir
    
    for zone in $ZONES; do
	create_key $zone
	sign_zone $zone db.$zone
    done
else
    echo "No zonefiles!"
    exit 1
fi

# --------------
echo "Signed files:"
for file in $SIGNED_FILES; do
    echo "  $file"
done
