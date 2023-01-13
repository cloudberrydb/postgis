#------------------------------------------------------------------#
# To deploy PostGIS onto Greenplum Database, we need to install
# a set of 3rd-party libraries, e.g., geos, gdal, json-c, proj4,
# etc. This file is created to deal with this kind of jobs.
#
# Copyright (c) 2015 - 2016, Pivotal Inc.
#
#------------------------------------------------------------------#
MKFILE_PATH := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

EXT_TOP=$(MKFILE_PATH)/ext

#GPDB
PG_CONFIG=pg_config

PG_DEP_LIB_DIR=$($(PG_CONFIG) --libdir)
GPDB_LIB_DIR=$(PG_DEP_LIB_DIR)
GPDB_DIR=$(shell cd $(GPDB_LIB_DIR)/.. && pwd)

# versions for these 3rd party libraries and Postgis
include ../Makefile.version

#GOES
GEOS_DIR=$(EXT_TOP)/geos-$(GEOS_VER)
GEOS_CONFIG=$(GEOS_DIR)/bin/geos-config
GEOS_RPM_FLAGS="--define 'geos_dir $(GEOS_DIR)' --define 'geos_ver $(GEOS_VER)' --define 'geos_rel $(GEOS_REL)'"
GEOS_RPM=geos-$(GEOS_VER)-$(GEOS_REL).$(ARCH).rpm

#Proj.4
PROJ_DIR=$(EXT_TOP)/proj-$(PROJ_VER)
PROJ_RPM_FLAGS="--define 'proj_dir $(PROJ_DIR)' --define 'proj_ver $(PROJ_VER)' --define 'proj_rel $(PROJ_REL)'"
PROJ_RPM=proj-$(PROJ_VER)-$(PROJ_REL).$(ARCH).rpm

#json-c
JSON_DIR=$(EXT_TOP)/json-c-$(JSON_VER)
JSON_RPM_FLAGS="--define 'json_dir $(JSON_DIR)' --define 'json_ver $(JSON_VER)' --define 'json_rel $(JSON_REL)'"
JSON_RPM=json-c-$(JSON_VER)-$(JSON_REL).$(ARCH).rpm

#GDAL
GDAL_DIR=$(EXT_TOP)/gdal-$(GDAL_VER)
GDAL_CONFIG=$(GDAL_DIR)/bin/gdal-config
GDAL_RPM_FLAGS="--define 'gdal_dir $(GDAL_DIR)' --define 'gdal_ver $(GDAL_VER)' --define 'gdal_rel $(GDAL_REL)' --define 'libexpat_ver $(LIBEXPAT_VER)' --define 'libexpat_rel $(LIBEXPAT_REL)'"
GDAL_RPM=gdal-$(GDAL_VER)-$(GDAL_REL).$(ARCH).rpm

# LIBEXPAT
LIBEXPAT_DIR=$(EXT_TOP)/libexpat-$(LIBEXPAT_VER)
LIBEXPAT_RPM_FLAGS="--define 'libexpat_dir $(LIBEXPAT_DIR)' --define 'libexpat_ver $(LIBEXPAT_VER)' --define 'libexpat_rel $(LIBEXPAT_REL)'"
LIBEXPAT_RPM=libexpat-$(LIBEXPAT_VER)-$(LIBEXPAT_REL).$(ARCH).rpm

# SFCGAL
SFCGAL_DIR=$(EXT_TOP)/sfcgal-$(SFCGAL_VER)
SFCGAL_RPM_FLAGS="--define 'sfcgal_dir $(SFCGAL_DIR)' --define 'sfcgal_ver $(SFCGAL_VER)' --define 'sfcgal_rel $(SFCGAL_REL)'"
SFCGAL_RPM=sfcgal-$(SFCGAL_VER)-$(SFCGAL_REL).$(ARCH).rpm

# CGAL
CGAL_DIR=$(EXT_TOP)/cgal-$(CGAL_VER)
CGAL_RPM_FLAGS="--define 'cgal_dir $(CGAL_DIR)' --define 'cgal_ver $(CGAL_VER)' --define 'cgal_rel $(CGAL_REL)'"
CGAL_RPM=cgal-$(CGAL_VER)-$(CGAL_REL).$(ARCH).rpm

# POSTGIS
POSTGIS_DIR=$(shell cd ../build/postgis-$(POSTGIS_VER) && pwd)
POSTGIS_PKG_VER=ossv$(POSTGIS_VER)_pv$(PIVOTAL_VER)_gpdb$(GPDB_VER)orca
POSTGIS_RPM_FLAGS="--define 'postgis_dir $(POSTGIS_DIR)' --define 'postgis_ver $(POSTGIS_VER)' --define 'postgis_rel $(POSTGIS_REL)' --define 'geos_ver $(GEOS_VER)' --define 'sfcgal_ver $(SFCGAL_VER)'  --define 'cgal_ver $(CGAL_VER)' --define 'json_ver $(JSON_VER)' --define 'gdal_ver $(GDAL_VER)'"
DEPENDENT_RPMS="$(GEOS_RPM) $(GDAL_RPM) $(SFCGAL_RPM) $(JSON_RPM)"
POSTGIS_RPM=postgis-$(POSTGIS_VER)-$(POSTGIS_REL).$(ARCH).rpm

#GPPKG
POSTGIS_GPPKG=postgis-$(POSTGIS_PKG_VER)-$(OS)-$(ARCH).gppkg
TARGET_GPPKG=$(POSTGIS_GPPKG)
EXTRA_CLEAN+=$(GEOS_RPM) $(JSON_RPM) $(SFCGAL_RPM) $(CGAL_RPM) $(GDAL_RPM) $(POSTGIS_RPM) $(POSTGIS_GPPKG)

#
# Generic rules to build gppkgs included here
#
include $(MKFILE_PATH)/gppkg.mk

# trigger the compiling process
build_postgis:
	cd $(POSTGIS_DIR) && $(POSTGIS_DIR)/configure --with-geosconfig=$(GEOS_CONFIG) --with-gdalconfig=$(GDAL_CONFIG) --with-pgconfig=$(PG_CONFIG) --with-raster --without-topology	--prefix=$$GPHOME
	$(MAKE) -C ..

# for regressing
DEP_LIBS_PATH=$(GEOS_DIR) $(JSON_DIR) $(SFCGAL_DIR) $(CGAL_DIR) $(GDAL_DIR)

#for data dir copying during source-code-building (not form GPROOT)
DEP_LIBS_DATA=$(GDAL_DIR)/share/gdal $(PROJ_DIR)/share/proj

SHLIB_LINK_F = @SHLIB_LINK@
SHLIB_LINK := $(SHLIB_LINK_F) $(SHLIB_LINK)

# modify paths in libs
include Makefile.ops

gppkg_spec.yml: gppkg_spec.yml.in
	cat $< | sed "s/#arch/$(ARCH)/g" | sed "s/#os/$(OS)/g" | sed 's/#gpver/$(GP_VERSION_NUM)/g' > $@

%.gppkg: gppkg_spec.yml $(MAIN_RPM) $(DEPENDENT_RPMS)
	mkdir -p gppkg/deps
	cp gppkg_spec.yml gppkg/
	cp $(MAIN_RPM) gppkg/
ifdef DEPENDENT_RPMS
	for dep_rpm in $(DEPENDENT_RPMS); do \
		cp $${dep_rpm} gppkg/deps; \
	done
endif
	source $(INSTLOC)/greenplum_path.sh && gppkg --build gppkg
	rm -rf gppkg

# for compiling
gppkg: prepare build_postgis gppkg_only 

gppkg_only: $(GEOS_DIR) $(GDAL_DIR) $(SFCGAL_DIR) $(CGAL_DIR) $(JSON_DIR)
	$(MAKE) $(GEOS_RPM) RPM_FLAGS=$(GEOS_RPM_FLAGS)
	$(MAKE) $(GDAL_RPM) RPM_FLAGS=$(GDAL_RPM_FLAGS)
	$(MAKE) $(SFCGAL_RPM) RPM_FLAGS=$(SFCGAL_RPM_FLAGS)
	$(MAKE) $(CGAL_RPM) RPM_FLAGS=$(CGAL_RPM_FLAGS)
	$(MAKE) $(JSON_RPM) RPM_FLAGS=$(JSON_RPM_FLAGS)

	$(MAKE) $(POSTGIS_RPM) RPM_FLAGS=$(POSTGIS_RPM_FLAGS)
	#$(MAKE) $(POSTGIS_GPPKG) MAIN_RPM=$(POSTGIS_RPM) DEPENDENT_RPMS=$(DEPENDENT_RPMS)

# gppkg_only:
# 	$(MAKE) $(POSTGIS_RPM) RPM_FLAGS=$(POSTGIS_RPM_FLAGS)
# 	$(MAKE) $(POSTGIS_GPPKG) MAIN_RPM=$(POSTGIS_RPM) DEPENDENT_RPMS=

.PHONY: gppkg
