#!/bin/sh

TMPFILE=`tempfile`

zone2ldap () {
    echo -n "Loading zone '$2' into '$1'"
    /usr/sbin/zone2ldap -D 'cn=admin,ou=People,dc=bayour,dc=com' -w r92bi5q9 -c -h 192.168.1.5 -b $1 -z $2 -f $3
    echo "done."
}

# Find current ou=DNS entries (so we can delete them recursivly)
echo -n "Deleting the ou=DNS organizationalUnit's... "
ldapsearch -LLL ou=DNS > $TMPFILE 2> /dev/null
cat $TMPFILE | grep ^dn: | sed 's@dn: @@' | ldapdelete -r 2> /dev/null
echo "done."

# Add the organizationalUnit's again
echo -n "Adding the organizationalUnit's... "
ldapadd -f $TMPFILE > /dev/null 2>&1
# Create the ou=Internal, ou=External and ou=Reverse for bayour.com
ldapadd -U turbo <<EOF > /dev/null 2>&1
dn: ou=External,ou=DNS,dc=bayour,dc=com
objectClass: top
objectClass: organizationalUnit
ou: External

dn: ou=Internal,ou=DNS,dc=bayour,dc=com
objectClass: top
objectClass: organizationalUnit
ou: Internal

dn: ou=Reverse,ou=DNS,dc=bayour,dc=com
objectClass: top
objectClass: organizationalUnit
ou: ou=Reverse
EOF
echo "done."

# Load the zones into LDAP database
zone2ldap 'ou=Internal,ou=DNS,dc=bayour,dc=com' bayour.com /etc/bind/db.bayour.com.internal.signed 
zone2ldap 'ou=External,ou=DNS,dc=bayour,dc=com' bayour.com /etc/bind/db.bayour.com.external.signed 
zone2ldap 'ou=Reverse,ou=DNS,dc=bayour,dc=com' 1.168.192.in-addr.arpa /etc/bind/db.1.168.192.in-addr.arpa.signed 
zone2ldap 'ou=Reverse,ou=DNS,dc=bayour,dc=com' localhost /etc/bind/db.localhost.signed
zone2ldap 'ou=Reverse,ou=DNS,dc=bayour,dc=com' 127.in-addr.arpa /etc/bind/db.127.in-addr.arpa.signed
zone2ldap 'ou=Reverse,ou=DNS,dc=bayour,dc=com' 0.in-addr.arpa /etc/bind/db.0.in-addr.arpa.signed
zone2ldap 'ou=Reverse,ou=DNS,dc=bayour,dc=com' 255.in-addr.arpa /etc/bind/db.255.in-addr.arpa.signed
zone2ldap 'ou=DNS,dc=intelligence-5,dc=com' fjortis.com /etc/bind/db.fjortis.com.signed
zone2ldap 'ou=DNS,dc=winas,dc=com' winas.com /etc/bind/db.winas.com.signed
zone2ldap 'ou=DNS,dc=gamestudio,dc=com' thegamestudio.com /etc/bind/db.thegamestudio.com.signed
zone2ldap 'ou=DNS,dc=gamestudio,dc=com' thegamestudio.se /etc/bind/db.thegamestudio.se.signed
zone2ldap 'ou=DNS,dc=gamestudio,dc=com' machineworx.com /etc/bind/db.machineworx.com.signed
zone2ldap 'ou=DNS,dc=gamestudio,dc=com' machineworx.org /etc/bind/db.machineworx.org.signed
zone2ldap 'ou=DNS,dc=agby,dc=com' agby.net /etc/bind/db.agby.net.signed
