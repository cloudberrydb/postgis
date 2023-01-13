Notes for generating gppkg with pre-compiled libraries

### 1. Download 3rd party libraries

======================================

To build postgis gppkg, we first need to download the third-party libraries

```
GEOS: geos 3.4.2
json-c: json-c 0.12
PROJ.4: proj 4.8.0
Geospatial-Foundation: gdal 1.11.1
expat: libexpat 2.1.0
```

### 2. Compile postgis gppkg

======================================

After downloaded libraries, go to package folder. And run make BLD_TARGETS="gppkg"
with user-defined parameters, which include BLD_ARCH (the os version), GPROOT (the
location of gpAux folder),POSGIS_DIR (the location of postgis source folder), INSTLOC (the location of installed
gpdb), and use gppkg as build traget.

An example is to write a shell 'build.sh' with lines:
```sh
source ~/greenplum-db-devel/greenplum_path.sh

make \
	BLD_TARGETS="gppkg" \
	BLD_ARCH="rhel6_x86_64" \
	INSTLOC=$GPHOME \
	POSTGIS_DIR="/home/gpadmin/workspace/geospatial/postgis/build/postgis-2.5.4" \
	gppkg_only
```

To clean it, run:
```sh
	make clean
```

### 3. Verification and installation

======================================

run belowing command to verify postgis.gppkg is ready.
```sh
	gppkg --query postgis-ossv2.5.4+pivotal.2_pv2.5_gpdb6.0-rhel6-x86_64.gppkg
```

run belowing belowing to install postgis.gppkg into gpdb.
```sh
	gppkg -i postgis-ossv2.5.4+pivotal.2_pv2.5_gpdb6.0-rhel6-x86_64.gppkg
```
