DATE = `date +%Y%m%d`

# ����ʪ��Ĥ��롣
dist:
	tar cf - jmarcfilter.c dict.h | gzip -c9 > jmarc-C.$(DATE).tar.gz
	tar cf - jmarc.pl jmarcfilter.pl | gzip -c9 > jmarc-Perl.$(DATE).tar.gz
	mv jmarc-C.$(DATE).tar.gz jmarc-Perl.$(DATE).tar.gz ../marc-web/tools/
