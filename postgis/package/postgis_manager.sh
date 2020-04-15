#!/bin/bash -l

if [ "$#" -eq 2 ]
	then
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
elif [ "$#" -eq 3 ]
then
	is_schema_in_db=`psql -t -d $1 -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name='$2';" | HEAD -n 1`
	if [ -z $is_schema_in_db ]
	then
		echo "Schema('$2') does not exist in database('$1')"
		exit 1
	fi
	if [ "$3" = "install" ]
	then
		env PGOPTIONS='--search_path=$2' psql --no-psqlrc -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/install/postgis.sql;
		env PGOPTIONS='--search_path=$2' psql --no-psqlrc -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/install/rtpostgis.sql;
		env PGOPTIONS='--search_path=$2' psql --no-psqlrc -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/install/postgis_comments.sql;
		env PGOPTIONS='--search_path=$2' psql --no-psqlrc -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/install/raster_comments.sql;
		env PGOPTIONS='--search_path=$2' psql --no-psqlrc -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/install/spatial_ref_sys.sql;
	elif [ "$3" = "upgrade" ]
	then
		env PGOPTIONS='--search_path=$2' psql --no-psqlrc -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/upgrade/legacy.sql;
		env PGOPTIONS='--search_path=$2' psql --no-psqlrc -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/upgrade/postgis_upgrade_20_21.sql;
		env PGOPTIONS='--search_path=$2' psql --no-psqlrc -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/upgrade/postgis_upgrade_21_minor.sql;
	elif [ "$3" = "uninstall" ]
	then
		env PGOPTIONS='--search_path=$2' psql --no-psqlrc -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/uninstall/uninstall_rtpostgis.sql;
		env PGOPTIONS='--search_path=$2' psql --no-psqlrc -d $1 -f $GPHOME/share/postgresql/contrib/postgis-2.5/uninstall/uninstall_postgis.sql;
	else
		echo "Invalid option. Please try install, upgrade or uninstall"
	fi
else
	echo "Invalid arguements. Usage: ./postgis_manager.sh <dbname> [<schema_name>] install/uninstall/upgrade "
fi
