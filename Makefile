# $Id: Makefile,v 1.2 2003-03-28 11:33:56 turbo Exp $

install all: clean
	@(for file in addcname create_keys sign zone_ldap zone_sign zone_update ; do \
	    file="dnssec-$$file.sh"; \
	    cp -v $$file /afs/bayour.com/common/noarch/sbin/; \
	  done; \
	)
	@rcp -x dnssec-sign.sh root@rmgztk:/usr/local/sbin/; \
	@echo "\`dnssec-sign.sh' -> \`root@rmgztk:/usr/local/sbin/dnssec-sign.sh'"; \

clean:
	@rm -f *~ .#*
