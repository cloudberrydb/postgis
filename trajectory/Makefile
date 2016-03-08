#Makefile for Geospatial/Trajectory

.PHONY: trjactory

subdir= src
testdir = test

all: trajectory 

trajectory:
	$(MAKE) -C $(subdir)

install: all
	$(MAKE) -C $(subdir) install 

uninstall: all
	$(MAKE) -C $(subdir) uninstall 

clean: clean_test
	$(MAKE) -C $(subdir) $@
	$(MAKE) -C $(testdir) $@

clean_test:
	rm -rf results
	rm -f regression.diffs regression.out optimizer_status.out

check: installcheck

installcheck:
	$(MAKE) -C $(testdir) $@
