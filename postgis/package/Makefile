#------------------------------------------------------------#
# To deploy PostGIS onto Greenplum Database, we need to package 
# PostGIS together with its dependent libraries, e.g, geos, gdal,
# etc. This file will genearte postgis-2.1.5-OS-Arch.gppkg for GPDB.
#
# Kuien Liu <kliu@pivotal.io>, 7 April 2015.
#-------------------------------------------#

all: gppkg

BLD_TOP=$(shell cd ../../../../ && pwd)
EXT_TOP=$(BLD_TOP)/ext/$(BLD_ARCH)
GPMGMT=$(BLD_TOP)/gpMgmt
include $(BLD_TOP)/releng/tools.mk
include $(BLD_TOP)/Makefile.global

OS=$(word 1,$(subst _, ,$(BLD_ARCH)))
ARCH=$(shell uname -p)

# versions for these 3rd party libraries and Postgis
include ../Makefile.version

# GEOS
GEOS_DIR=$(EXT_TOP)/geos-$(GEOS_VER)
GEOS_CONFIG=$(GEOS_DIR)/bin/geos-config
GEOS_RPM_FLAGS="--define 'geos_dir $(GEOS_DIR)' --define 'geos_ver $(GEOS_VER)' --define 'geos_rel $(GEOS_REL)'"
GEOS_RPM=geos-$(GEOS_VER)-$(GEOS_REL).$(ARCH).rpm

# PROJ.4
PROJ_DIR=$(EXT_TOP)/proj-$(PROJ_VER)
PROJ_RPM_FLAGS="--define 'proj_dir $(PROJ_DIR)' --define 'proj_ver $(PROJ_VER)' --define 'proj_rel $(PROJ_REL)'"
PROJ_RPM=proj-$(PROJ_VER)-$(PROJ_REL).$(ARCH).rpm

# JSON-C
JSON_DIR=$(EXT_TOP)/json-c-$(JSON_VER)
JSON_RPM_FLAGS="--define 'json_dir $(JSON_DIR)' --define 'json_ver $(JSON_VER)' --define 'json_rel $(JSON_REL)'"
JSON_RPM=json-c-$(JSON_VER)-$(JSON_REL).$(ARCH).rpm

# GDAL
GDAL_DIR=$(EXT_TOP)/gdal-$(GDAL_VER)
GDAL_CONFIG=$(GDAL_DIR)/bin/gdal-config
GDAL_RPM_FLAGS="--define 'gdal_dir $(GDAL_DIR)' --define 'gdal_ver $(GDAL_VER)' --define 'gdal_rel $(GDAL_REL)' --define 'libexpat_ver $(LIBEXPAT_VER)' --define 'libexpat_rel $(LIBEXPAT_REL)'"
GDAL_RPM=gdal-$(GDAL_VER)-$(GDAL_REL).$(ARCH).rpm

# LIBEXPAT
LIBEXPAT_DIR=$(EXT_TOP)/libexpat-$(LIBEXPAT_VER)
LIBEXPAT_RPM_FLAGS="--define 'libexpat_dir $(LIBEXPAT_DIR)' --define 'libexpat_ver $(LIBEXPAT_VER)' --define 'libexpat_rel $(LIBEXPAT_REL)'"
LIBEXPAT_RPM=libexpat-$(LIBEXPAT_VER)-$(LIBEXPAT_REL).$(ARCH).rpm

# POSTGIS
POSTGIS_TOP=$(shell cd ../.. && pwd)
POSTGIS_DIR=$(POSTGIS_TOP)/postgis-$(POSTGIS_VER)
POSTGIS_PKG_VER=ossv$(POSTGIS_VER)_pv$(PIVOTAL_VER)_gpdb$(GPDB_VER)
POSTGIS_RPM_FLAGS="--define 'postgis_dir $(POSTGIS_DIR)' --define 'postgis_ver $(POSTGIS_VER)' --define 'postgis_rel $(POSTGIS_REL)' --define 'geos_ver $(GEOS_VER)' --define 'proj_ver $(PROJ_VER)' --define 'json_ver $(JSON_VER)' --define 'gdal_ver $(GDAL_VER)' --define 'libexpat_ver $(LIBEXPAT_VER)'"
DEPENDENT_RPMS="$(GEOS_RPM) $(PROJ_RPM) $(JSON_RPM) $(GDAL_RPM) $(LIBEXPAT_RPM)"
POSTGIS_RPM=postgis-$(POSTGIS_VER)-$(POSTGIS_REL).$(ARCH).rpm

# GPPKG
POSTGIS_GPPKG=postgis-$(POSTGIS_PKG_VER)-$(OS)-$(ARCH).gppkg
TARGET_GPPKG=$(POSTGIS_GPPKG)
EXTRA_CLEAN+=$(GEOS_RPM) $(PROJ_RPM) $(JSON_RPM) $(GDAL_RPM) $(LIBEXPAT_RPM) $(POSTGIS_RPM) $(POSTGIS_GPPKG)

#
# Generic rules to build gppkgs included here
#
include $(BLD_TOP)/releng/gppkg.mk

# trigger the compiling process
build_postgis:
	$(MAKE) -C ..

gppkg: $(GEOS_DIR) $(PROJ_DIR) $(JSON_DIR) $(GDAL_DIR) $(LIBEXPAT_DIR) build_postgis
	$(MAKE) $(GEOS_RPM) RPM_FLAGS=$(GEOS_RPM_FLAGS)
	$(MAKE) $(PROJ_RPM) RPM_FLAGS=$(PROJ_RPM_FLAGS)
	$(MAKE) $(JSON_RPM) RPM_FLAGS=$(JSON_RPM_FLAGS)
	$(MAKE) $(GDAL_RPM) RPM_FLAGS=$(GDAL_RPM_FLAGS)
	$(MAKE) $(LIBEXPAT_RPM) RPM_FLAGS=$(LIBEXPAT_RPM_FLAGS)
	$(MAKE) $(POSTGIS_RPM) RPM_FLAGS=$(POSTGIS_RPM_FLAGS)
	$(MAKE) $(POSTGIS_GPPKG) MAIN_RPM=$(POSTGIS_RPM) DEPENDENT_RPMS=$(DEPENDENT_RPMS)

.PHONY: gppkg
