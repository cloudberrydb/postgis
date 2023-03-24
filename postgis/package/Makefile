#------------------------------------------------------------------#
# To deploy PostGIS onto Greenplum Database, we need to install
# a set of 3rd-party libraries, e.g., geos, gdal, json-c, proj4,
# etc. This file is created to deal with this kind of jobs.
#
# Copyright (c) 2015 - 2016, Pivotal Inc.
#
#------------------------------------------------------------------#

include $(BLD_TOP)/Makefile.global     # for BLD_ARCH
include $(BLD_TOP)/releng/tools.mk
EXT_TOP=$(BLD_TOP)/ext/$(BLD_ARCH)

pg_config_path := $(BLD_TOP)/../src/include/pg_config.h
GP_VERSION_NUM := $(shell grep 'define  *GP_VERSION_NUM' $(pg_config_path) \
        | perl -ne '$$m1=int($$1/10000),$$m2=int(($$1-$$m1*10000)/100) if/^.*?([0-9]+)/;print "$$m1.$$m2$$/"' )
OS=$(word 1,$(subst _, ,$(BLD_ARCH)))
ARCH=$(shell uname -p)

#GPDB
PG_CONFIG=$(BLD_TOP)/../src/bin/pg_config/pg_config

PG_DEP_LIB_DIR=$(shell $(PG_CONFIG) --libdir)
GPDB_LIB_DIR=$(PG_DEP_LIB_DIR)
GPDB_DIR=$(shell cd $(GPDB_LIB_DIR)/.. && pwd)

#ape from $(BLD_TOP)/src/Makefile.global etc
INSTALL=$(BLD_TOP)/config/install-sh -c
INSTALL_SHLIB=$(BLD_TOP)/config/install-sh -c -m 755
INSTALL_DATA=$(BLD_TOP)/config/install-sh -c -m 644
INSTALL_PROGRAM=$(BLD_TOP)/config/install-sh -s
mkinstalldirs=$(BLD_TOP)/config/mkinstalldirs

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

# POSTGIS
POSTGIS_DIR=$(shell cd ../build/postgis-$(POSTGIS_VER) && pwd)
POSTGIS_PKG_VER=ossv$(POSTGIS_VER)_pv$(PIVOTAL_VER)_gpdb$(GPDB_VER)orca
POSTGIS_RPM_FLAGS="--define 'bld_top $(BLD_TOP)' --define 'postgis_dir $(POSTGIS_DIR)' --define 'postgis_ver $(POSTGIS_VER)' --define 'postgis_rel $(POSTGIS_REL)' --define 'geos_ver $(GEOS_VER)' --define 'proj_ver $(PROJ_VER)' --define 'json_ver $(JSON_VER)' --define 'gdal_ver $(GDAL_VER)' --define 'libexpat_ver $(LIBEXPAT_VER)'"
DEPENDENT_RPMS="$(GEOS_RPM) $(PROJ_RPM) $(JSON_RPM) $(GDAL_RPM) $(LIBEXPAT_RPM)"
POSTGIS_RPM=postgis-$(POSTGIS_VER)-$(POSTGIS_REL).$(ARCH).rpm

#GPPKG
POSTGIS_GPPKG=postgis-$(POSTGIS_PKG_VER)-$(OS)-$(ARCH).gppkg
TARGET_GPPKG=$(POSTGIS_GPPKG)
EXTRA_CLEAN+=$(GEOS_RPM) $(PROJ_RPM) $(JSON_RPM) $(GDAL_RPM) $(LIBEXPAT_RPM) $(POSTGIS_RPM) $(POSTGIS_GPPKG)
ifeq ($(GPPKG),)
GPPKG=gppkg
endif

#
# Generic rules to build gppkgs included here
#
# include $(BLD_TOP)/releng/gppkg.mk

# trigger the compiling process
build_postgis:
	cd $(POSTGIS_DIR) && $(POSTGIS_DIR)/configure --with-geosconfig=$(GEOS_CONFIG) --with-gdalconfig=$(GDAL_CONFIG) --with-pgconfig=$(PG_CONFIG) --with-raster --without-topology	--prefix=$$GPHOME
	$(MAKE) -C ..

# for regressing
DEP_LIBS_PATH=$(GEOS_DIR) $(PROJ_DIR) $(JSON_DIR) $(GDAL_DIR) $(LIBEXPAT_DIR)

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

gppkg_only: $(GEOS_DIR) $(PROJ_DIR) $(JSON_DIR) $(GDAL_DIR) $(LIBEXPAT_DIR)
	$(MAKE) $(GEOS_RPM) RPM_FLAGS=$(GEOS_RPM_FLAGS)
	$(MAKE) $(PROJ_RPM) RPM_FLAGS=$(PROJ_RPM_FLAGS)
	$(MAKE) $(JSON_RPM) RPM_FLAGS=$(JSON_RPM_FLAGS)
	$(MAKE) $(GDAL_RPM) RPM_FLAGS=$(GDAL_RPM_FLAGS)
	$(MAKE) $(LIBEXPAT_RPM) RPM_FLAGS=$(LIBEXPAT_RPM_FLAGS)
	$(MAKE) $(POSTGIS_RPM) RPM_FLAGS=$(POSTGIS_RPM_FLAGS)
	$(MAKE) $(POSTGIS_GPPKG) MAIN_RPM=$(POSTGIS_RPM) DEPENDENT_RPMS=$(DEPENDENT_RPMS)

gppkg_spec_v2.yml: gppkg_spec_v2.yml.in
	cat $< | sed "s/#arch/$(ARCH)/g" | sed "s/#os/$(OS)/g" | sed 's/#gpver/$(GP_VERSION_NUM)/g' > $@

gppkgv2-geos:
	install -d gppkg_build/files/lib/
	install $(GEOS_DIR)/lib64/libgeos*so* -t gppkg_build/files/lib/

gppkgv2-proj:
	install -d gppkg_build/files/lib
	install -d gppkg_build/files/share/proj
	install $(PROJ_DIR)/lib64/libproj*so* -t gppkg_build/files/lib
	install $(PROJ_DIR)/share/proj/*    -t gppkg_build/files/share/proj

gppkgv2-jsonc:
	install -d gppkg_build/files/lib
	install $(JSON_DIR)/lib/libjson-c*so* -t gppkg_build/files/lib

gppkgv2-gdal:
	install -d gppkg_build/files/lib
	install -d gppkg_build/files/share/gdal
	install -d gppkg_build/files/etc/environment.d
	install $(GDAL_DIR)/lib64/libgdal*so* -t gppkg_build/files/lib/
	install $(GDAL_DIR)/share/gdal/*    -t gppkg_build/files/share/gdal
	# environment.d available since GPDB7
	# https://github.com/greenplum-db/gpdb/pull/14327
	install ./30-postgis.conf           -t gppkg_build/files/etc/environment.d

gppkgv2-libexpat:
	install -d gppkg_build/files/lib
	install $(LIBEXPAT_DIR)/lib/libexpat*so* -t gppkg_build/files/lib/

gppkgv2-postgis:
	make -C $(POSTGIS_DIR) BLD_TOP=$(BLD_TOP) install DESTDIR=$(PWD)/gppkg_build/gphome || true
	cp -r $(PWD)/gppkg_build/gphome/usr/local/greenplum-db-devel/* $(PWD)/gppkg_build/files

gppkgv2: gppkg_spec_v2.yml gppkgv2-geos gppkgv2-proj gppkgv2-jsonc gppkgv2-gdal gppkgv2-libexpat gppkgv2-postgis
	$(GPPKG) build \
		-f \
		--input $(PWD)/gppkg_build/files \
		--config $(PWD)/gppkg_spec_v2.yml \
		--output $(POSTGIS_GPPKG)

gppkgv2-clean:
	rm $(PWD)/gppkg_spec_v2.yml
	rm -rf $(PWD)/gppkg_build

.PHONY: gppkg gppkgv2
