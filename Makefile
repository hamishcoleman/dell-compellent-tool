
NAME := compellenttool
INSTALLROOT := installdir
INSTALLDIR := $(INSTALLROOT)/$(NAME)

describe := $(shell git describe --dirty)
tarfile := $(NAME)-$(describe).tar.gz

all:    test

build_dep:
	aptitude install libtext-csv-perl liblwp-protocol-https-perl libio-socket-ssl-perl libxml-twig-perl

build_dep_rpm:
	yum install perl-Text-CSV perl-Crypt-SSLeay perl-IO-Socket-SSL perl-XML-Twig

install: clean
	install -d $(INSTALLDIR)
	cp -pr lib $(INSTALLDIR)
	rm -f $(INSTALLDIR)/lib/HC/.git
	install -p -t $(INSTALLDIR) clitest check_blocksremaining
	echo install -p test_harness $(INSTALLDIR)

tar:    $(tarfile)

$(tarfile):
	$(MAKE) install
	tar -v -c -z -C $(INSTALLROOT) -f $(tarfile) .

clean:
	rm -rf $(INSTALLROOT)

cover:
	cover -delete
	-COVER=true $(MAKE) test
	cover

test:
	~/s/bin/lib/test_harness

