# $Id: Makefile,v 1.1 2003-03-28 10:36:56 turbo Exp $

install all: clean
	@(for file in addcname create_keys sign zone_ldap zone_sign zone_update ; do \
	    file="dnssec-$$file.sh"; \
	    cp -v $$file /afs/bayour.com/common/noarch/sbin/; \
	    rcp -x $$file root@rmgztk:/usr/local/sbin/; \
	    echo "\`$$file' -> \`root@rmgztk:/usr/local/sbin/$$file'"; \
	  done; \
	)

clean:
	@rm -f *~ .#*
