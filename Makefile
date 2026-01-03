all: smelulater

smelulater: gmp_wrapper.o smelulater.o
	gdc gmp_wrapper.o smelulater.o -o smelulater -lgmp

gmp_wrapper.o: gmp_wrapper.d
	gdc -c gmp_wrapper.d -Ilibgmp/source

smelulater.o: smelulater.d gmp_wrapper.d
	gdc -c smelulater.d -Ilibgmp/source
