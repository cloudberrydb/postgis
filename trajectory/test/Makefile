#Makefile for Geospatial/Traje/testdirctory/Regression

top_builddir = ../../../../cdb-pg
testdir = .

# ape from cdb-pg/src/Makefile.global
ifndef PG_CONFIG
PG_CONFIG = pg_config
endif
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
	create_delete_trajectory #\
	append_trajectory \
	add_extra_columns \
	append_with_attrs

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

installcheck: submake pre_install_gis_fast
	$(top_builddir)/src/test/regress/pg_regress --inputdir=$(testdir) --psqldir=$(PSQLDIR) $(REGRESS_OPTS) $(REGRESS)

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


	#for file in $(shell ls sql); do \
#update: pre_install_gis_fast
SQL_FILES = $(foreach n, $(testdir)/sql, $(wildcard $(n)/*.sql)) 
OUT_FILES = $(SQL_FILES:.sql=.out)
update:
	@echo sql:$(SQL_FILES) 
	@echo out:$(OUT_FILES) 
	for f in $(SQL_FILES); do \
		echo $(PSQLDIR)/psql -d $(TRJTABLE_PRE) -f $$f -a -q > $$f; \
	done

#echo $(PSQLDIR)/psql -d $(TRJTABLE_PRE) -f $$f -a -q > $($$f:sql=expected) 2>&1; \
#$(PSQLDIR)/psql -d $(TRJTABLE_PRE) -f sql/$(f) -a -q > expected/*.out; \
