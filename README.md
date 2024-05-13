# PostGIS for Cloudberry Database

[![Slack](https://img.shields.io/badge/Join_Slack-6a32c9)](https://communityinviter.com/apps/cloudberrydb/welcome)
[![Twitter Follow](https://img.shields.io/twitter/follow/cloudberrydb)](https://twitter.com/cloudberrydb)
[![Website](https://img.shields.io/badge/Visit%20Website-eebc46)](https://cloudberrydb.org)
[![GitHub Discussions](https://img.shields.io/github/discussions/cloudberrydb/cloudberrydb)](https://github.com/orgs/cloudberrydb/discussions)

---

## What's PostGIS

[PostGIS](https://postgis.net/) extends the capabilities of the PostgreSQL by adding support for storing, indexing, and querying geospatial data. This repo is dedicated and optimized for Cloudberry Database clusters.

## Compile PostGIS for Cloudberry Database

We need to install the pre-requested dependencies and compile a few components before we install the PostGIS for Cloudberry Database. Currently, we only support compiling it on CentOS (Rocky Linux is in the plan). 

Also, please make sure Cloudberry Database has been installed on your machine correctly before we start. If not, please follow the [document](https://cloudberrydb.org/docs/) to install.

Now, let's get started.

1. Install the pre-requested dependencies.

   ```bash
   yum install -y libtool proj-devel boost-devel gmp-devel mpfr-devel pcre-devel protobuf protobuf-c protobuf-devel protobuf-c-devel && \
   yum install -y gcc make subversion gcc-c++ sqlite-devel libxml2-devel swig expat-devel libcurl-devel python36-devel json-c
   ```

2. Build the components (GDAL, CGAL, SFCGAL, and GEOS). Make sure to build them by `root`.

   2.1 Build GDAL

   [GDAL](https://gdal.org/index.html) is a translator library for raster and vector geospatial data formats. Follow the commands to install it:

   ```bash
   wget https://download.osgeo.org/gdal/2.2.1/gdal-2.2.1.tar.gz --no-check-certificate
   tar xf gdal-2.2.1.tar.gz
   cd gdal-2.2.1/
   ./configure --prefix=/usr/local/gdal-2.2.1
   make && make install
   ```

   2.2 Build CGAL

   [CGAL](https://www.cgal.org/) provides easy access to efficient and reliable geometric algorithms in the form of a C++ library. Follow the commands to install it:

   ```bash
   wget https://github.com/CGAL/cgal/archive/releases/CGAL-4.13.tar.gz
   tar xf CGAL-4.13.tar.gz
   cd cgal-releases-CGAL-4.13/
   mkdir build && cd build
   cmake ..
   make && make install
   ```

   2.3 Build SFCGAL

   [SFCGAL](https://github.com/Oslandia/SFCGAL) is a C++ wrapper library around CGAL to support ISO 19107:2013 and OGC Simple Features Access 1.2 for 3D operations. Follow the commands to install it:

   ```bash
   wget https://github.com/Oslandia/SFCGAL/archive/v1.3.6.tar.gz
   tar xf v1.3.6.tar.gz
   cd SFCGAL-1.3.6/
   mkdir build && cd build
   cmake -DCMAKE_INSTALL_PREFIX=/usr/local/sfcgal-1.3.6 ..
   make && make install
   ```

   2.4 Build GEOS

   [GEOS](https://libgeos.org/) is a C/C++ library for computational geometry with a focus on algorithms used in geographic information systems (GIS) software. Follow the commands to install it:

   ```bash
   wget https://download.osgeo.org/geos/geos-3.7.0.tar.bz2 --no-check-certificate
   tar xf geos-3.7.0.tar.bz2
   cd geos-3.7.0/
   ./configure --prefix=/usr/local/geos-3.7.0/
   make && make install
   ```

   2.5 Update `/etc/ld.so.conf`

   After installing the above components, we need to update `/etc/ld.so.conf` to configure the dynamic loader to search for their directories:

   ```bash
   cat << EOF >> /etc/ld.so.conf
   /usr/lib/
   /usr/lib64/
   /usr/local/sfcgal-1.3.6/lib64/
   /usr/local/gdal-2.2.1/lib/
   /usr/local/geos-3.7.0/lib/
   EOF
   ```

   then run the command `ldconfig`.

3. Build and install the PostGIS

   3.1 Download this repo to your `gpadmin` directory:

   ```bash
   git clone https://github.com/cloudberrydb/postgis.git /home/gpadmin/postgis
   chown -R gpadmin:gpadmin /home/gpadmin/postgis
   ```

   3.2 Compile the PostGIS

   Before starting the compile process, run the following commands to make sure the environment variables are set ready:

   ```bash
   source /usr/local/cloudberrydb/greenplum_path.sh
   source /home/gpadmin/cloudberrydb/gpAux/gpdemo/gpdemo-env.sh
   scl enable devtoolset-10 bash
   source /opt/rh/devtoolset-10/enable
   ```

   Then we continue:

   ```bash
   cd /home/gpadmin/postgis/postgis/build/postgis-2.5.4/
   ./autogen.sh
   ./configure --prefix="${GPHOME}" --with-pgconfig="${GPHOME}"/bin/pg_config --with-raster --without-topology --with-gdalconfig=/usr/local/gdal-2.2.1/bin/gdal-config --with-sfcgal=/usr/local/sfcgal-1.3.6/bin/sfcgal-config --with-geosconfig=/usr/local/geos-3.7.0/bin/geos-config
   make && make install
   ```

## Use the PostGIS in Cloudberry Database

Assume you installed the Cloudberry Database sucessfully and started the demo cluster. Then you can run the following commands to enable it:

   ```sql
   $ psql -p 7000 postgres

   postgres=# CREATE EXTENSION postgis; -- enables postgis and raster
   postgres=# CREATE EXTENSION fuzzystrmatch; -- required for installing tiger geocoder
   postgres=# CREATE EXTENSION postgis_tiger_geocoder; -- enables tiger geocoder
   postgres=# CREATE EXTENSION address_standardizer; -- enable address_standardizer
   postgres=# CREATE EXTENSION address_standardizer_data_us;
   ```

For more usages, you can follow [PostGIS manual](https://postgis.net/documentation/manual/).

## License

This project is under GPL v2, because PostGIS is under GPL v2, see the [LICENSE](./LICENSE). PostGIS also includes some files not
under GPL v2 license, you can check the original [LICENSE](./postgis/build/postgis-2.5.4/LICENSE.TXT) in PostGIS
project for details.

## Acknowledgment

PostGIS is one project forked from [greenplum-db/geopatial](https://github.com/greenplum-db/geospatial/). Thanks to all the original contributors.
