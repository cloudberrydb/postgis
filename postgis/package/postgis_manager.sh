#!/bin/bash -l

if [ "$2" = "install" ]
then
	psql -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/install/postgis.sql;
	psql -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/install/rtpostgis.sql;
	psql -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/install/postgis_comments.sql;
	psql -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/install/raster_comments.sql;
	psql -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/install/spatial_ref_sys.sql;
elif [ "$2" = "upgrade" ]
then
	psql -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/upgrade/legacy.sql;
	psql -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/upgrade/postgis_upgrade_20_21.sql;
	psql -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/upgrade/postgis_upgrade_21_minor.sql;
elif [ "$2" = "uninstall" ]
then
	psql -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/uninstall/uninstall_rtpostgis.sql;
	psql -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/uninstall/uninstall_postgis.sql;
else
	echo "Invalid option. Please try install, upgrade or uninstall"
fi
