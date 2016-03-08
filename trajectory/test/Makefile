#Makefile for Geospatial/Traje/testdirctory/Regression

top_builddir = ../../../../../
testdir = .

# ape from cdb-pg/src/Makefile.global
ifndef PG_CONFIG
PG_CONFIG = pg_config
endif
libdir := $(shell $(PG_CONFIG) --libdir)
bindir := $(shell $(PG_CONFIG) --bindir)
shardir := $(shell $(PG_CONFIG) --sharedir)

# where to find psql for running the tests
PSQLDIR = $(bindir)
EMPTY_GIS_TABLE = gis
TRJTABLE = regression
TRJTABLE_PRE = trjregression
REGRESS_OPTS = --dbname=$(TRJTABLE)

# regression tests
TEST_FIRST = \
	check_postgis_installed

# trajectory construction 
TEST_IO = \
	create_delete_trajectory \
	append_trajectory \
	extra_columns

# not used
TEST_LAST =
TEST_METADATA =
TEST_BASIC_FUNC = 
TEST_OPERATOR =
TEST_UTILITY =
TEST_ADVANCED_FUNC =
TEST_LOADER =

REGRESS = $(TEST_FIRST) \
	$(TEST_METADATA) \
	$(TEST_IO) \
	$(TEST_BASIC_FUNC) \
	$(TEST_OPERATOR) \
	$(TEST_UTILITY) \
	$(TEST_ADVANCED_FUNC) \
	$(TEST_LOADER) \
	$(TEST_LAST)



all check: installcheck

FAST_TEST = yes
ifdef FAST_TEST
# now we use compiled 'pg_regress' for test
installcheck: pre_install_gis_fast
	$(libdir)/postgresql/pgxs/src/test/regress/pg_regress --inputdir=$(testdir) --psqldir=$(PSQLDIR) $(REGRESS_OPTS) $(REGRESS)
else
# we need to compile 'pg_regress' firstly and install postgis in time
installcheck: submake pre_install_gis
	$(top_builddir)/src/test/regress/pg_regress --inputdir=$(testdir) --psqldir=$(PSQLDIR) $(REGRESS_OPTS) $(REGRESS)
endif

.PHONY: submake
submake:
	$(MAKE) -C $(top_builddir)/src/test/regress pg_regress$(X)

# we choose 'postgis-2.0' rather than 'postgis-2.1' is because we're 
#   developing and testing on gpdb 4.3.6, not 5.0
quickprepare pre_install_gis_fast:
	$(PSQLDIR)/dropdb $(TRJTABLE_PRE)
	$(PSQLDIR)/createdb $(TRJTABLE_PRE) -T $(EMPTY_GIS_TABLE)
	$(PSQLDIR)/psql -d $(TRJTABLE_PRE) -f $(shardir)/contrib/trajectory.sql > ./pre_install_gis.log

prepare pre_install_gis:
	$(PSQLDIR)/dropdb $(EMPTY_GIS_TABLE)
	$(PSQLDIR)/createdb $(EMPTY_GIS_TABLE)
	$(PSQLDIR)/psql -d $(EMPTY_GIS_TABLE) -f $(shardir)/contrib/postgis-2.0/postgis.sql > ./pre_install_gis.log
	$(PSQLDIR)/psql -d $(EMPTY_GIS_TABLE) -f $(shardir)/contrib/postgis-2.0/postgis_comments.sql > ./pre_install_gis.log
	$(PSQLDIR)/psql -d $(EMPTY_GIS_TABLE) -f $(shardir)/contrib/postgis-2.0/spatial_ref_sys.sql > ./pre_install_gis.log

clean:
	rm -rf results
	rm -f regression.diffs regression.out optimizer_status.out
	rm -f expected/*.out.bak
	rm -f pre_install_gis.log

# ------------------------------------------------------------------------
# for developing use. 
#	Update: generate expected/*.out from sql/*.sql for the 1st time; 
#	Backup: copy result/*.out to expected/*.out
# -----------------------------------------------------------------------
update: quickprepare 
	@for f in $(REGRESS); do \
		mv $(testdir)/expected/$$f.out $(testdir)/expected/$$f.out.bak; \
		$(PSQLDIR)/psql -d $(TRJTABLE_PRE) -f $(testdir)/sql/$$f.sql -X -a -q > $(testdir)/expected/$$f.out 2>&1; \
	done

backup: 
	@for f in $(REGRESS); do \
		cp $(testdir)/results/$$f.out $(testdir)/expected/$$f.out; \
	done
