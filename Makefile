#
# Makefile
#

all:

clean:

install:
	mkdir -p $(DESTDIR)
	install -m 755 -d $(DESTDIR)/etc/apt/sources.list.d
	install -m 755 -d $(DESTDIR)/usr/share/keyrings
	install -m 644 movealong.list $(DESTDIR)/etc/apt/sources.list.d/
	install -m 644 inkblot-movealong-keyring.gpg $(DESTDIR)/usr/share/keyrings/
