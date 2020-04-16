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

mkdir -p %{buildroot}/temp/share/postgresql/contrib/postgis-2.5/
mkdir -p %{buildroot}/temp/share/postgresql/contrib/postgis-2.5/{install,upgrade,uninstall}/

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
