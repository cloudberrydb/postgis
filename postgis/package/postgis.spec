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
Requires:       geos = %{geos_ver}, proj = %{proj_ver}, json-c = %{json_ver}, gdal = %{gdal_ver}

%description
The PostGIS module provides geospatial extensions for Greenplum Database.

%install
make -C %{postgis_dir} BLD_TOP=%{bld_top} install prefix=%{buildroot}/temp

mkdir -p %{buildroot}/temp/bin
cp $GPHOME/bin/pgsql2shp %{buildroot}/temp/bin
cp $GPHOME/bin/shp2pgsql %{buildroot}/temp/bin
cp $GPHOME/bin/raster2pgsql %{buildroot}/temp/bin

mkdir -p %{buildroot}/temp/lib/postgresql
cp $GPHOME/lib/postgresql/postgis-2.1.so %{buildroot}/temp/lib/postgresql/postgis-2.1.so
cp $GPHOME/lib/postgresql/rtpostgis-2.1.so %{buildroot}/temp/lib/postgresql/rtpostgis-2.1.so

mkdir -p %{buildroot}/temp/share/postgresql/contrib/postgis-2.1/
cp $GPHOME/share/postgresql/contrib/postgis-2.1/*.sql %{buildroot}/temp/share/postgresql/contrib/postgis-2.1/

%files
/temp
