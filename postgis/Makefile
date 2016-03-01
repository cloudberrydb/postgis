# common settings for compiling and gppkg generation
include Makefile.version

# compiling directory
POSTGIS_BLD_TOP     = $(shell cd .. && pwd)
POSTGIS_BLD_DIR     = $(POSTGIS_BLD_TOP)/postgis-$(POSTGIS_VER)

# tar ball and patch file
POSTGIS_TAR_BALL    = postgis-$(POSTGIS_VER).tar.gz
POSTGIS_PATCH_FILE  = patch/postgis-$(POSTGIS_VER)-GPDB.patch

# entry
all install uninstall clean distclean maintainer-clean test check installcheck docs docs-install docs-uninstall utils: prepare 
	make -C $(POSTGIS_BLD_DIR) $@

# prepare the compiling dir
prepare:
	@echo
	@echo "-----------------------------------------------------------------------"
	@echo "Prepare the compiling directory for postgis-$(POSTGIS_VER)."
	@echo "-----------------------------------------------------------------------"
	@if [ -d $(POSTGIS_BLD_DIR) ]; then \
		echo "WARNING: $(POSTGIS_BLD_DIR) already exists. It's better to run 'make remove' firstly."; \
	else \
		echo "    extract $(POSTGIS_TAR_BALL) to $(POSTGIS_BLD_DIR) ..."; \
		tar -zxf $(POSTGIS_TAR_BALL) -C $(POSTGIS_BLD_TOP); \
		echo "    patch it with $(POSTGIS_PATCH_FILE) ..."; \
		patch -d $(POSTGIS_BLD_DIR) -p 4 --silent < $(POSTGIS_PATCH_FILE); \
		echo "    copy Makefile.version to $(POSTGIS_BLD_DIR)"; \
		cp -u Makefile.version $(POSTGIS_BLD_DIR); \
		echo "-----------------------------------------------------------------------"; \
		echo "Done"; \
		echo "-----------------------------------------------------------------------"; \
	fi

remove:
	rm -rf $(POSTGIS_BLD_DIR)
