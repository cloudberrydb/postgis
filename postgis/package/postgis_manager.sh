#!/bin/bash -l

function upgrade_postgis() {
	## Verify which version of PostGIS is installed
	## and call the corresponding upgrade function.
	postgis_version=`psql -t -d $1 -c "SELECT postgis_version();" | head -n 1`
	if [[ $postgis_version == *"2.5"* ]]; then
		echo "Postgis version 2.5 already installed."
		upgrade_254_254 $1
	elif [[ $postgis_version == *"2.1"* ]]; then
		echo "Upgrading to 2.5!"
		upgrade_215_254 $1
	else
		echo "Postgis not installed in the current DB. Exiting!"
		exit 1
	fi
}

function test_ret_code() {
	if [ ! -z "${1}" ];then
		echo "Exiting upgrade with ${retcode}"
		exit 1
	fi
}

function upgrade_215_254() {
	has_extension=`psql -t -d $1 -c "SELECT count(*) FROM pg_extension WHERE extname = 'postgis';" | head -n 1`
	all_hosts=`psql -t -d $1 -c "SELECT distinct(hostname) FROM pg_catalog.gp_segment_configuration WHERE role = 'p';"`
	if [ "$has_extension" -eq 0 ]; then
		## Copy the control file for 2.1.5 to extension folder and CREATE postgis as extension
		echo "$all_hosts" > $GPHOME/share/postgresql/contrib/postgis-2.5/upgrade/all_hosts
		retcode=`gpssh -f $GPHOME/share/postgresql/contrib/postgis-2.5/upgrade/all_hosts "cp $GPHOME/share/postgresql/extension/postgis.control $GPHOME/share/postgresql/extension/postgis.control-2.5.4" | grep ERROR | cat`
		test_ret_code $retcode
		retcode=`gpssh -f $GPHOME/share/postgresql/contrib/postgis-2.5/upgrade/all_hosts "cp $GPHOME/share/postgresql/contrib/postgis-2.5/upgrade/postgis.control-2.1.5 $GPHOME/share/postgresql/extension/postgis.control" | grep ERROR | cat`
		test_ret_code $retcode
		retcode=`gpssh -f $GPHOME/share/postgresql/contrib/postgis-2.5/upgrade/all_hosts "cp $GPHOME/share/postgresql/contrib/postgis-2.5/upgrade/postgis--unpackaged--2.1.5.sql $GPHOME/share/postgresql/extension/" | grep ERROR | cat`
		test_ret_code $retcode
		echo "Creating PostGIS 2.1.5 as extension"
		psql -d $1 -c "CREATE EXTENSION postgis FROM unpackaged;"
		## Copy the control file for 2.5.4 to extension folder
		retcode=`gpssh -f $GPHOME/share/postgresql/contrib/postgis-2.5/upgrade/all_hosts "mv $GPHOME/share/postgresql/extension/postgis.control-2.5.4 $GPHOME/share/postgresql/extension/postgis.control" | grep ERROR | cat`
		test_ret_code $retcode
		retcode=`gpssh -f $GPHOME/share/postgresql/contrib/postgis-2.5/upgrade/all_hosts "rm -f $GPHOME/share/postgresql/extension/postgis--unpackaged--2.1.5.sql" | grep ERROR | cat`
		test_ret_code $retcode
	fi
	## Alter postgis extension to 2.5.4
	echo "Updating PostGIS extension to PostGIS 2.5.4"
	psql -d $1 -c "ALTER EXTENSION postgis UPDATE to '2.5.4';"
}

function upgrade_254_254() {
	has_extension=`psql -t -d $1 -c "SELECT count(*) FROM pg_extension WHERE extname = 'postgis';" | head -n 1`
	if [ "$has_extension" -eq 0 ]; then
		## CREATE postgis as extension if not created
		psql -d $1 -c "CREATE EXTENSION postgis FROM unpackaged;"
	fi
}

install_postgis()
{
	echo "Please use CREATE EXTENSION syntax per the docs for installing postgis. Exiting!"
}

uninstall_postgis()
{
	echo "Please use DROP EXTENSION syntax per the docs for uninstalling postgis. Exiting!"
}
if [ "$#" -eq 2 ]
	then
	if [ "$2" = "install" ]
	then
		install_postgis
	elif [ "$2" = "upgrade" ]
	then
		upgrade_postgis $1
	elif [ "$2" = "uninstall" ]
	then
		uninstall_postgis
	else
		echo "Invalid option. Please try install, upgrade or uninstall"
	fi
elif [ "$#" -eq 3 ]
then
	is_schema_in_db=`psql -t -d $1 -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name='$2';" | head -n 1`
	if [ -z $is_schema_in_db ]
	then
		echo "Schema('$2') does not exist in database('$1')"
		exit 1
	fi
	if [ "$3" = "install" ]
	then
		install_postgis
	elif [ "$3" = "upgrade" ]
	then
		upgrade_postgis $1
	elif [ "$3" = "uninstall" ]
	then
		uninstall_postgis
	else
		echo "Invalid option. Please try install, upgrade or uninstall"
	fi
else
	echo "Invalid arguements. Usage: ./postgis_manager.sh <dbname> [<schema_name>] install/uninstall/upgrade "
fi
