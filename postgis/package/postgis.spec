Summary:        Geospatial extensions for Greenplum Database
License:        GPLv2
Name:           postgis
Version:        %{postgis_ver}
Release:        %{postgis_rel}
Group:          Development/Tools
Prefix:         /temp
AutoReq:        no
AutoProv:       no
Provides:       postgis = %{postgis_ver}

%define _build_id_links none

%description
The PostGIS module provides geospatial extensions for Greenplum Database.

%install
make -C %{postgis_dir} BLD_TOP=%{bld_top} install prefix=%{buildroot}/temp

mkdir -p %{buildroot}/temp/bin
cp $GPHOME/bin/pgsql2shp %{buildroot}/temp/bin
cp $GPHOME/bin/shp2pgsql %{buildroot}/temp/bin
cp $GPHOME/bin/raster2pgsql %{buildroot}/temp/bin

mkdir -p %{buildroot}/temp/lib/postgresql
cp $GPHOME/lib/postgresql/postgis-2.5.so %{buildroot}/temp/lib/postgresql/postgis-2.5.so
cp $GPHOME/lib/postgresql/rtpostgis-2.5.so %{buildroot}/temp/lib/postgresql/rtpostgis-2.5.so
cp $GPHOME/lib/postgresql/address_standardizer.so %{buildroot}/temp/lib/postgresql/address_standardizer.so

mkdir -p %{buildroot}/temp/share/postgresql/contrib/postgis-2.5/
mkdir -p %{buildroot}/temp/share/postgresql/contrib/postgis-2.5/{install,upgrade,uninstall}/
mkdir -p %{buildroot}/temp/share/postgresql/extension/

cp $GPHOME/share/postgresql/contrib/postgis-2.5/postgis.sql %{buildroot}/temp/share/postgresql/contrib/postgis-2.5/install/
cp $GPHOME/share/postgresql/contrib/postgis-2.5/rtpostgis.sql %{buildroot}/temp/share/postgresql/contrib/postgis-2.5/install/
cp $GPHOME/share/postgresql/contrib/postgis-2.5/*comments.sql %{buildroot}/temp/share/postgresql/contrib/postgis-2.5/install/
cp $GPHOME/share/postgresql/contrib/postgis-2.5/spatial_ref_sys.sql %{buildroot}/temp/share/postgresql/contrib/postgis-2.5/install/

cp $GPHOME/share/postgresql/contrib/postgis-2.5/*upgrade*.sql %{buildroot}/temp/share/postgresql/contrib/postgis-2.5/upgrade/
cp $GPHOME/share/postgresql/contrib/postgis-2.5/legacy*.sql %{buildroot}/temp/share/postgresql/contrib/postgis-2.5/upgrade/
cp $GPHOME/share/postgresql/contrib/postgis-2.5/rtpostgis_legacy.sql %{buildroot}/temp/share/postgresql/contrib/postgis-2.5/upgrade/

cp $GPHOME/share/postgresql/contrib/postgis-2.5/uninstall*.sql %{buildroot}/temp/share/postgresql/contrib/postgis-2.5/uninstall/

cp %{postgis_dir}/../../package/postgis_manager.sh %{buildroot}/temp/share/postgresql/contrib/postgis-2.5/postgis_manager.sh

cp %{postgis_dir}/../../package/postgis_replace_views.sql %{buildroot}/temp/share/postgresql/contrib/postgis-2.5/postgis_replace_views.sql
cp %{postgis_dir}/../../package/postgis--unpackaged--2.1.5.sql %{buildroot}/temp/share/postgresql/contrib/postgis-2.5/upgrade/
cp %{postgis_dir}/../../package/postgis.control-2.1.5 %{buildroot}/temp/share/postgresql/contrib/postgis-2.5/upgrade/

cp $GPHOME/share/postgresql/extension/postgis.control %{buildroot}/temp/share/postgresql/extension/
cp $GPHOME/share/postgresql/extension/postgis_tiger_geocoder.control %{buildroot}/temp/share/postgresql/extension/
cp $GPHOME/share/postgresql/extension/address_standardizer.control %{buildroot}/temp/share/postgresql/extension/
cp $GPHOME/share/postgresql/extension/address_standardizer_data_us.control %{buildroot}/temp/share/postgresql/extension/
cp $GPHOME/share/postgresql/extension/postgis*.sql %{buildroot}/temp/share/postgresql/extension/
cp $GPHOME/share/postgresql/extension/address_standardizer*.sql %{buildroot}/temp/share/postgresql/extension/

%files
/temp/bin/pgsql2shp
/temp/bin/raster2pgsql
/temp/bin/shp2pgsql
/temp/include/liblwgeom.h
/temp/include/liblwgeom_topo.h
/temp/lib/liblwgeom-2.5.so.0.0.0
/temp/lib/liblwgeom-2.5.so.0
/temp/lib/liblwgeom.a
/temp/lib/liblwgeom.la
/temp/lib/liblwgeom.so
/temp/lib/postgresql/postgis-2.5.so
/temp/lib/postgresql/rtpostgis-2.5.so
/temp/lib/postgresql/address_standardizer.so
/temp/share/postgresql/contrib/postgis-2.5/postgis_manager.sh
/temp/share/postgresql/contrib/postgis-2.5/postgis_replace_views.sql
/temp/share/postgresql/contrib/postgis-2.5/install/postgis.sql
/temp/share/postgresql/contrib/postgis-2.5/install/postgis_comments.sql
/temp/share/postgresql/contrib/postgis-2.5/install/raster_comments.sql
/temp/share/postgresql/contrib/postgis-2.5/install/rtpostgis.sql
/temp/share/postgresql/contrib/postgis-2.5/install/spatial_ref_sys.sql
/temp/share/postgresql/contrib/postgis-2.5/install/topology_comments.sql
/temp/share/postgresql/contrib/postgis-2.5/install/sfcgal_comments.sql
/temp/share/postgresql/contrib/postgis-2.5/uninstall/uninstall_legacy.sql
/temp/share/postgresql/contrib/postgis-2.5/uninstall/uninstall_postgis.sql
/temp/share/postgresql/contrib/postgis-2.5/uninstall/uninstall_rtpostgis.sql
/temp/share/postgresql/contrib/postgis-2.5/upgrade/legacy.sql
/temp/share/postgresql/contrib/postgis-2.5/upgrade/legacy_gist.sql
/temp/share/postgresql/contrib/postgis-2.5/upgrade/legacy_minimal.sql
/temp/share/postgresql/contrib/postgis-2.5/upgrade/rtpostgis_legacy.sql
/temp/share/postgresql/contrib/postgis-2.5/upgrade/postgis_upgrade.sql
/temp/share/postgresql/contrib/postgis-2.5/upgrade/postgis_upgrade_for_extension.sql
/temp/share/postgresql/contrib/postgis-2.5/upgrade/rtpostgis_upgrade.sql
/temp/share/postgresql/contrib/postgis-2.5/upgrade/rtpostgis_upgrade_for_extension.sql
/temp/share/postgresql/contrib/postgis-2.5/upgrade/postgis--unpackaged--2.1.5.sql
/temp/share/postgresql/contrib/postgis-2.5/upgrade/postgis.control-2.1.5
/temp/share/postgresql/extension/postgis.control
/temp/share/postgresql/extension/postgis_tiger_geocoder.control
/temp/share/postgresql/extension/address_standardizer.control
/temp/share/postgresql/extension/address_standardizer_data_us.control
/temp/share/postgresql/extension/postgis--ANY--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.5.4next--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.5.4--2.5.4next.sql
/temp/share/postgresql/extension/postgis--2.0.3--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.0.2--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.0.1--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.0.0--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.0.7--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.0.6--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.0.5--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.0.4--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.1.3--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.1.2--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.1.1--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.1.0--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.1.7--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.1.6--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.1.5--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.1.4--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.2.1--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.2.0--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.1.9--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.1.8--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.2.5--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.2.4--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.2.3--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.2.2--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.3.0--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.2.8--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.2.7--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.2.6--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.3.4--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.3.3--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.3.2--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.3.1--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.3.7--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.3.6--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.3.5--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.4.0--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.3.9--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.3.8--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.3.10--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.4.4--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.4.3--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.4.2--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.4.1--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.4.8--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.4.7--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.4.6--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.4.5--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.5.3--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.5.2--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.5.1--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.5.0--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.5.4dev--2.5.4.sql
/temp/share/postgresql/extension/postgis--unpackaged--2.5.4.sql
/temp/share/postgresql/extension/postgis--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--ANY--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.5.4next--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.5.4--2.5.4next.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.0.0--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.0.4--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.0.3--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.0.2--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.0.1--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.1.0--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.0.7--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.0.6--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.0.5--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.1.3--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.1.2--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.1.1--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.1.7--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.1.6--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.1.5--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.1.4--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.2.1--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.2.0--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.1.9--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.1.8--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.2.4--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.2.3--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.2.2--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.2.8--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.2.7--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.2.6--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.2.5--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.3.3--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.3.2--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.3.1--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.3.0--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.3.7--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.3.6--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.3.5--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.3.4--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.4.0--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.3.9--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.3.8--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.3.10--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.4.4--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.4.3--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.4.2--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.4.1--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.4.8--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.4.7--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.4.6--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.4.5--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.5.3--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.5.2--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.5.1--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.5.0--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.5.4dev--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--unpackaged--2.5.4.sql
/temp/share/postgresql/extension/postgis_tiger_geocoder--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.5.4next--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.5.4--2.5.4next.sql
/temp/share/postgresql/extension/address_standardizer--2.0.3--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.0.2--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.0.1--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.0.0--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.0.7--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.0.6--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.0.5--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.0.4--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.1.3--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.1.2--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.1.1--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.1.0--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.1.7--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.1.6--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.1.5--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.1.4--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.2.1--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.2.0--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.1.9--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.1.8--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.2.5--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.2.4--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.2.3--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.2.2--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.3.0--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.2.8--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.2.7--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.2.6--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.3.4--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.3.3--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.3.2--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.3.1--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.3.7--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.3.6--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.3.5--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.4.0--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.3.9--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.3.8--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.3.10--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.4.4--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.4.3--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.4.2--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.4.1--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.4.8--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.4.7--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.4.6--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.4.5--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.5.3--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.5.2--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.5.1--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.5.0--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer.sql
/temp/share/postgresql/extension/address_standardizer--2.5.4dev--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer_data_us.sql
/temp/share/postgresql/extension/address_standardizer_data_us--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer_data_us--2.5.4next--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer_data_us--2.5.4--2.5.4next.sql
/temp/share/postgresql/extension/address_standardizer--ANY--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--2.5.4.sql
/temp/share/postgresql/extension/address_standardizer--1.0--2.5.4.sql
/temp/share/postgresql/contrib/postgis-2.5/uninstall/uninstall_sfcgal.sql
/temp/share/postgresql/contrib/postgis-2.5/upgrade/sfcgal_upgrade.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.0.0--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.0.1--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.0.2--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.0.3--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.0.4--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.0.5--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.0.6--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.0.7--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.1.0--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.1.1--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.1.2--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.1.3--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.1.4--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.1.5--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.1.6--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.1.7--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.1.8--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.1.9--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.2.0--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.2.1--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.2.2--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.2.3--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.2.4--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.2.5--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.2.6--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.2.7--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.2.8--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.3.0--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.3.1--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.3.10--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.3.2--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.3.3--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.3.4--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.3.5--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.3.6--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.3.7--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.3.8--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.3.9--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.4.0--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.4.1--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.4.2--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.4.3--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.4.4--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.4.5--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.4.6--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.4.7--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.4.8--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.5.0--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.5.1--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.5.2--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.5.3--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.5.4--2.5.4next.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.5.4dev--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--2.5.4next--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--ANY--2.5.4.sql
/temp/share/postgresql/extension/postgis_sfcgal--unpackaged--2.5.4.sql

