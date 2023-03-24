\echo Use "CREATE EXTENSION postgis" to load this file. \quit
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--
----
-- PostGIS - Spatial Types for PostgreSQL
-- http://postgis.net
--
-- Copyright (C) 2011 Regina Obe <lr@pcorp.us>
-- Modifications Copyright (c) 2017 - Present Pivotal Software, Inc. All Rights Reserved.
--
-- This is free software; you can redistribute and/or modify it under
-- the terms of the GNU General Public Licence. See the COPYING file.
--
-- Author: Regina Obe <lr@pcorp.us>
--
-- This is a suite of SQL helper functions for use during a PostGIS extension install/upgrade
-- The functions get uninstalled after the extention install/upgrade process
---------------------------
-- postgis_extension_remove_objects: This function removes objects of a particular class from an extension
-- this is needed because there is no ALTER EXTENSION DROP FUNCTION/AGGREGATE command
-- and we can't CREATE OR REPALCe functions whose signatures have changed and we can drop them if they are part of an extention
-- So we use this to remove it from extension first before we drop
CREATE OR REPLACE FUNCTION postgis_extension_remove_objects(param_extension text, param_type text)
  RETURNS boolean AS
$$
DECLARE
	var_sql text := '';
	var_r record;
	var_result boolean := false;
	var_class text := '';
	var_is_aggregate boolean := false;
	var_sql_list text := '';
	var_pgsql_version integer := current_setting('server_version_num');
BEGIN
		var_class := CASE WHEN lower(param_type) = 'function' OR lower(param_type) = 'aggregate' THEN 'pg_proc' ELSE '' END;
		var_is_aggregate := CASE WHEN lower(param_type) = 'aggregate' THEN true ELSE false END;

		IF var_pgsql_version < 110000 THEN
			var_sql_list := $sql$SELECT 'ALTER EXTENSION ' || e.extname || ' DROP ' || $3 || ' ' || COALESCE(proc.proname || '(' || oidvectortypes(proc.proargtypes) || ')' ,typ.typname, cd.relname, op.oprname,
					cs.typname || ' AS ' || ct.typname || ') ', opcname, opfname) || ';' AS remove_command
			FROM pg_depend As d INNER JOIN pg_extension As e
				ON d.refobjid = e.oid INNER JOIN pg_class As c ON
					c.oid = d.classid
					LEFT JOIN pg_proc AS proc ON proc.oid = d.objid
					LEFT JOIN pg_type AS typ ON typ.oid = d.objid
					LEFT JOIN pg_class As cd ON cd.oid = d.objid
					LEFT JOIN pg_operator As op ON op.oid = d.objid
					LEFT JOIN pg_cast AS ca ON ca.oid = d.objid
					LEFT JOIN pg_type AS cs ON ca.castsource = cs.oid
					LEFT JOIN pg_type AS ct ON ca.casttarget = ct.oid
					LEFT JOIN pg_opclass As oc ON oc.oid = d.objid
					LEFT JOIN pg_opfamily As ofa ON ofa.oid = d.objid
			WHERE d.deptype = 'e' and e.extname = $1 and c.relname = $2 AND COALESCE(proc.proisagg, false) = $4;$sql$;
		ELSE -- for PostgreSQL 11 and above, they removed proc.proisagg among others and replaced with some func type thing
			var_sql_list := $sql$SELECT 'ALTER EXTENSION ' || e.extname || ' DROP ' || $3 || ' ' || COALESCE(proc.proname || '(' || oidvectortypes(proc.proargtypes) || ')' ,typ.typname, cd.relname, op.oprname,
					cs.typname || ' AS ' || ct.typname || ') ', opcname, opfname) || ';' AS remove_command
			FROM pg_depend As d INNER JOIN pg_extension As e
				ON d.refobjid = e.oid INNER JOIN pg_class As c ON
					c.oid = d.classid
					LEFT JOIN pg_proc AS proc ON proc.oid = d.objid
					LEFT JOIN pg_type AS typ ON typ.oid = d.objid
					LEFT JOIN pg_class As cd ON cd.oid = d.objid
					LEFT JOIN pg_operator As op ON op.oid = d.objid
					LEFT JOIN pg_cast AS ca ON ca.oid = d.objid
					LEFT JOIN pg_type AS cs ON ca.castsource = cs.oid
					LEFT JOIN pg_type AS ct ON ca.casttarget = ct.oid
					LEFT JOIN pg_opclass As oc ON oc.oid = d.objid
					LEFT JOIN pg_opfamily As ofa ON ofa.oid = d.objid
			WHERE d.deptype = 'e' and e.extname = $1 and c.relname = $2 AND (proc.prokind = 'a')  = $4;$sql$;
		END IF;

		FOR var_r IN EXECUTE var_sql_list  USING param_extension, var_class, param_type, var_is_aggregate
		LOOP
			var_sql := var_sql || var_r.remove_command || ';';
		END LOOP;
		IF var_sql > '' THEN
			EXECUTE var_sql;
			var_result := true;
		END IF;

		RETURN var_result;
END;
$$
LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION postgis_extension_drop_if_exists(param_extension text, param_statement text)
  RETURNS boolean AS
$$
DECLARE
	var_sql_ext text := 'ALTER EXTENSION ' || quote_ident(param_extension) || ' ' || replace(param_statement, 'IF EXISTS', '');
	var_result boolean := false;
BEGIN
	BEGIN
		EXECUTE var_sql_ext;
		var_result := true;
	EXCEPTION
		WHEN OTHERS THEN
			--this is to allow ignoring if the object does not exist in extension
			var_result := false;
	END;
	RETURN var_result;
END;
$$
LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION postgis_extension_AddToSearchPath(a_schema_name varchar)
RETURNS text
AS
$$
DECLARE
	var_result text;
	var_cur_search_path text;
BEGIN
	SELECT reset_val INTO var_cur_search_path FROM pg_settings WHERE name = 'search_path';
	IF var_cur_search_path LIKE '%' || quote_ident(a_schema_name) || '%' THEN
		var_result := a_schema_name || ' already in database search_path';
	ELSE
		var_cur_search_path := var_cur_search_path || ', '
                        || quote_ident(a_schema_name);
		EXECUTE 'ALTER DATABASE ' || quote_ident(current_database())
                              || ' SET search_path = ' || var_cur_search_path;
		var_result := a_schema_name || ' has been added to end of database search_path ';
	END IF;

	EXECUTE 'SET search_path = ' || var_cur_search_path;

  RETURN var_result;
END
$$
LANGUAGE 'plpgsql' VOLATILE STRICT;
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--
--
-- PostGIS - Spatial Types for PostgreSQL
-- http://postgis.net
--
-- Copyright (C) 2011-2012 Sandro Santilli <strk@kbt.io>
-- Copyright (C) 2010-2013 Regina Obe <lr@pcorp.us>
-- Copyright (C) 2009      Paul Ramsey <pramsey@cleverelephant.ca>
-- Modifications Copyright (c) 2017 - Present Pivotal Software, Inc. All Rights Reserved.
--
-- This is free software; you can redistribute and/or modify it under
-- the terms of the GNU General Public Licence. See the COPYING file.
--
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--
-- This file contains drop commands for obsoleted items that need
-- to be dropped _before_ upgrade of old functions.
-- Changes to this file affect postgis_upgrade*.sql script.
--
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS AddGeometryColumn(varchar,varchar,varchar,varchar,integer,varchar,integer,boolean)');
DROP FUNCTION IF EXISTS AddGeometryColumn(varchar,varchar,varchar,varchar,integer,varchar,integer,boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MakeEnvelope(float8, float8, float8, float8)');
DROP FUNCTION IF EXISTS ST_MakeEnvelope(float8, float8, float8, float8);
--changed name of prec arg to be consistent with ST_AsGML/KML
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsX3D(geometry, integer, integer)');
DROP FUNCTION IF EXISTS ST_AsX3D(geometry, integer, integer);
--changed name of arg: http://trac.osgeo.org/postgis/ticket/1606
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS UpdateGeometrySRID(varchar,varchar,varchar,varchar,integer)');
DROP FUNCTION IF EXISTS UpdateGeometrySRID(varchar,varchar,varchar,varchar,integer);

--deprecated and removed in 2.1
-- Hack to fix 2.0 naming
-- We can't just drop it since its bound to opclass
-- See ticket 2279 for why we need to do this
-- We can get rid of this DO code when 3.0 comes along
DO  language 'plpgsql' $$
BEGIN
	-- fix geometry ops --
	IF EXISTS(SELECT oprname from pg_operator where oprname = '&&' AND oprrest::text = 'geometry_gist_sel_2d') THEN
	--it is bound to old name, drop new, rename old to new, install will fix body of code
		DROP FUNCTION IF EXISTS gserialized_gist_sel_2d(internal, oid, internal, int4) ;
		ALTER FUNCTION geometry_gist_sel_2d(internal, oid, internal, int4) RENAME TO gserialized_gist_sel_2d;
	END IF;
	IF EXISTS(SELECT oprname from pg_operator where oprname = '&&' AND oprjoin::text = 'geometry_gist_joinsel_2d') THEN
	--it is bound to old name, drop new, rename old to new,  install will fix body of code
		DROP FUNCTION IF EXISTS gserialized_gist_joinsel_2d(internal, oid, internal, smallint) ;
		ALTER FUNCTION geometry_gist_joinsel_2d(internal, oid, internal, smallint) RENAME TO gserialized_gist_joinsel_2d;
	END IF;
	-- fix geography ops --
	IF EXISTS(SELECT oprname from pg_operator where oprname = '&&' AND oprrest::text = 'geography_gist_selectivity') THEN
	--it is bound to old name, drop new, rename old to new, install will fix body of code
		DROP FUNCTION IF EXISTS gserialized_gist_sel_nd(internal, oid, internal, int4) ;
		ALTER FUNCTION geography_gist_selectivity(internal, oid, internal, int4) RENAME TO gserialized_gist_sel_nd;
	END IF;

	IF EXISTS(SELECT oprname from pg_operator where oprname = '&&' AND oprjoin::text = 'geography_gist_join_selectivity') THEN
	--it is bound to old name, drop new, rename old to new, install will fix body of code
		DROP FUNCTION IF EXISTS gserialized_gist_joinsel_nd(internal, oid, internal, smallint) ;
		ALTER FUNCTION geography_gist_join_selectivity(internal, oid, internal, smallint) RENAME TO gserialized_gist_joinsel_nd;
	END IF;
END;
$$ ;

-- Going from multiple functions to default args
-- Need to drop old multiple variants to not get in trouble.
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsLatLonText(geometry)');
DROP FUNCTION IF EXISTS ST_AsLatLonText(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsLatLonText(geometry, text)');
DROP FUNCTION IF EXISTS ST_AsLatLonText(geometry, text);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsTWKB(geometry,int4)');
DROP FUNCTION IF EXISTS ST_AsTWKB(geometry,int4);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsTWKB(geometry,int4,int8)');
DROP FUNCTION IF EXISTS ST_AsTWKB(geometry,int4,int8);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsTWKB(geometry,int4,int8,boolean)');
DROP FUNCTION IF EXISTS ST_AsTWKB(geometry,int4,int8,boolean);

-- Old signatures for protobuf related functions improved in 2.4.0 RC/final
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS ST_AsMVT(text, int4, text, anyelement)');
DROP AGGREGATE IF EXISTS ST_AsMVT(text, int4, text, anyelement);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsMVTGeom(geom geometry, bounds box2d, extent int4, buffer int4, clip_geom bool)');
DROP FUNCTION IF EXISTS ST_AsMVTGeom(geom geometry, bounds box2d, extent int4, buffer int4, clip_geom bool);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS ST_AsGeobuf(text, anyelement)');
DROP AGGREGATE IF EXISTS ST_AsGeobuf(text, anyelement);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS pgis_asgeobuf_transfn(internal, text, anyelement)');
DROP FUNCTION IF EXISTS pgis_asgeobuf_transfn(internal, text, anyelement);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS pgis_asmvt_transfn(internal, text, int4, text, anyelement)');
DROP FUNCTION IF EXISTS pgis_asmvt_transfn(internal, text, int4, text, anyelement);
-- Going from multiple functions to default args
-- Need to drop old multiple variants to not get in trouble.
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS  ST_CurveToLine(geometry, integer)');
DROP FUNCTION IF EXISTS  ST_CurveToLine(geometry, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS  ST_CurveToLine(geometry)');
DROP FUNCTION IF EXISTS  ST_CurveToLine(geometry);

SELECT postgis_extension_drop_if_exists('postgis', 'DROP VIEW IF EXISTS geometry_columns');
DROP VIEW IF EXISTS geometry_columns; -- removed cast 2.2.0 so need to recreate

--
-- UPGRADE SCRIPT TO PostGIS 2.5
--

LOAD '$libdir/postgis-2.5';

CREATE OR REPLACE FUNCTION postgis_major_version_check()
RETURNS text
AS '
DECLARE
	old_scripts text;
	new_scripts text;
	old_maj text;
	new_maj text;
BEGIN
	--
	-- This uses postgis_lib_version() rather then
	-- postgis_scripts_installed() as in 1.0 because
	-- in the 1.0 => 1.1 transition that would result
	-- in an impossible upgrade:
	--
	--   from 0.3.0 to 1.1.0
	--
	-- Next releases will still be ok as
	-- postgis_lib_version() and postgis_scripts_installed()
	-- would both return actual PostGIS release number.
	--
	BEGIN
		SELECT into old_scripts postgis_lib_version();
	EXCEPTION WHEN OTHERS THEN
		RAISE DEBUG ''Got %'', SQLERRM;
		SELECT into old_scripts postgis_scripts_installed();
	END;
	SELECT into new_scripts ''2.5'';
	SELECT into old_maj substring(old_scripts from 1 for 2);
	SELECT into new_maj substring(new_scripts from 1 for 2);

	IF old_maj != new_maj THEN
		RAISE EXCEPTION ''Upgrade of postgis from version % to version % requires a dump/reload. See PostGIS manual for instructions'', old_scripts, new_scripts;
	ELSE
		RETURN ''Scripts versions checked for upgrade: ok'';
	END IF;
END
'
LANGUAGE 'plpgsql';

SELECT postgis_major_version_check();

SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION postgis_major_version_check()');
DROP FUNCTION postgis_major_version_check();

CREATE TEMPORARY TABLE _postgis_upgrade_info AS WITH versions AS (
  SELECT '2.5'::text as upgraded,
  postgis_scripts_installed() as installed
) SELECT
  upgraded as scripts_upgraded,
  installed as scripts_installed,
  substring(upgraded from '([0-9]*)\.')::int * 100 +
  substring(upgraded from '[0-9]*\.([0-9]*)\.')::int
    as version_to_num,
  substring(installed from '([0-9]*)\.')::int * 100 +
  substring(installed from '[0-9]*\.([0-9]*)\.')::int
    as version_from_num,
  installed ~ 'dev|alpha|beta'
    as version_from_isdev
  FROM versions
;

CREATE OR REPLACE FUNCTION _postgis_deprecate(oldname text, newname text, version text)
RETURNS void AS
$$
DECLARE
  curver_text text;
BEGIN
  --
  -- Raises a NOTICE if it was deprecated in this version,
  -- a WARNING if in a previous version (only up to minor version checked)
  --
    curver_text := '2.5.4';
    IF split_part(curver_text,'.',1)::int > split_part(version,'.',1)::int OR
       ( split_part(curver_text,'.',1) = split_part(version,'.',1) AND
         split_part(curver_text,'.',2) != split_part(version,'.',2) )
    THEN
      RAISE WARNING '% signature was deprecated in %. Please use %', oldname, version, newname;
    ELSE
      RAISE DEBUG '% signature was deprecated in %. Please use %', oldname, version, newname;
    END IF;
END;
$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION spheroid_in(cstring)
	RETURNS spheroid
	AS '$libdir/postgis-2.5','ellipsoid_in'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION spheroid_out(spheroid)
	RETURNS cstring
	AS '$libdir/postgis-2.5','ellipsoid_out'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Type spheroid -- LastUpdated: 5
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 5 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE spheroid (
	alignment = double,
	internallength = 65,
	input = spheroid_in,
	output = spheroid_out
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_in(cstring)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOM_in'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_out(geometry)
	RETURNS cstring
	AS '$libdir/postgis-2.5','LWGEOM_out'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_typmod_in(cstring[])
	RETURNS integer
	AS '$libdir/postgis-2.5','geometry_typmod_in'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_typmod_out(integer)
	RETURNS cstring
	AS '$libdir/postgis-2.5','postgis_typmod_out'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_analyze(internal)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'gserialized_analyze_nd'
	LANGUAGE 'c' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION geometry_recv(internal)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOM_recv'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_send(geometry)
	RETURNS bytea
	AS '$libdir/postgis-2.5','LWGEOM_send'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Type geometry -- LastUpdated: 1
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 1 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE geometry (
	internallength = variable,
	input = geometry_in,
	output = geometry_out,
	send = geometry_send,
	receive = geometry_recv,
	typmod_in = geometry_typmod_in,
	typmod_out = geometry_typmod_out,
	delimiter = ':',
	alignment = double,
	analyze = geometry_analyze,
	storage = main
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry(geometry, integer, boolean)
	RETURNS geometry
	AS '$libdir/postgis-2.5','geometry_enforce_typmod'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (geometry AS geometry)');
DROP CAST IF EXISTS (geometry AS geometry);
CREATE CAST (geometry AS geometry) WITH FUNCTION geometry(geometry, integer, boolean) AS IMPLICIT;
CREATE OR REPLACE FUNCTION geometry(point)
	RETURNS geometry
	AS '$libdir/postgis-2.5','point_to_geometry'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION point(geometry)
	RETURNS point
	AS '$libdir/postgis-2.5','geometry_to_point'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry(path)
	RETURNS geometry
	AS '$libdir/postgis-2.5','path_to_geometry'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION path(geometry)
	RETURNS path
	AS '$libdir/postgis-2.5','geometry_to_path'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry(polygon)
	RETURNS geometry
	AS '$libdir/postgis-2.5','polygon_to_geometry'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION polygon(geometry)
	RETURNS polygon
	AS '$libdir/postgis-2.5','geometry_to_polygon'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (geometry AS point)');
DROP CAST IF EXISTS (geometry AS point);
CREATE CAST (geometry AS point) WITH FUNCTION point(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (point AS geometry)');
DROP CAST IF EXISTS (point AS geometry);
CREATE CAST (point AS geometry) WITH FUNCTION geometry(point);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (geometry AS path)');
DROP CAST IF EXISTS (geometry AS path);
CREATE CAST (geometry AS path) WITH FUNCTION path(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (path AS geometry)');
DROP CAST IF EXISTS (path AS geometry);
CREATE CAST (path AS geometry) WITH FUNCTION geometry(path);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (geometry AS polygon)');
DROP CAST IF EXISTS (geometry AS polygon);
CREATE CAST (geometry AS polygon) WITH FUNCTION polygon(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (polygon AS geometry)');
DROP CAST IF EXISTS (polygon AS geometry);
CREATE CAST (polygon AS geometry) WITH FUNCTION geometry(polygon);
CREATE OR REPLACE FUNCTION ST_X(geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5','LWGEOM_x_point'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Y(geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5','LWGEOM_y_point'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Z(geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5','LWGEOM_z_point'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_M(geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5','LWGEOM_m_point'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION box3d_in(cstring)
	RETURNS box3d
	AS '$libdir/postgis-2.5', 'BOX3D_in'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION box3d_out(box3d)
	RETURNS cstring
	AS '$libdir/postgis-2.5', 'BOX3D_out'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Type box3d -- LastUpdated: 1
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 1 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE box3d (
	alignment = double,
	internallength = 52,
	input = box3d_in,
	output = box3d_out
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION box2d_in(cstring)
	RETURNS box2d
	AS '$libdir/postgis-2.5','BOX2D_in'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION box2d_out(box2d)
	RETURNS cstring
	AS '$libdir/postgis-2.5','BOX2D_out'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Type box2d -- LastUpdated: 8
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 8 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE box2d (
	internallength = 65,
	input = box2d_in,
	output = box2d_out,
	storage = plain
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION box2df_in(cstring)
	RETURNS box2df
	AS '$libdir/postgis-2.5','box2df_in'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION box2df_out(box2df)
	RETURNS cstring
	AS '$libdir/postgis-2.5','box2df_out'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Type box2df -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE box2df (
	internallength = 16,
	input = box2df_in,
	output = box2df_out,
	storage = plain,
	alignment = double
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION gidx_in(cstring)
	RETURNS gidx
	AS '$libdir/postgis-2.5','gidx_in'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION gidx_out(gidx)
	RETURNS cstring
	AS '$libdir/postgis-2.5','gidx_out'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Type gidx -- LastUpdated: 105
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 105 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE gidx (
	internallength = variable,
	input = gidx_in,
	output = gidx_out,
	storage = plain,
	alignment = double
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_lt(geom1 geometry, geom2 geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'lwgeom_lt'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_le(geom1 geometry, geom2 geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'lwgeom_le'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_gt(geom1 geometry, geom2 geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'lwgeom_gt'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_ge(geom1 geometry, geom2 geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'lwgeom_ge'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_eq(geom1 geometry, geom2 geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'lwgeom_eq'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_cmp(geom1 geometry, geom2 geometry)
	RETURNS integer
	AS '$libdir/postgis-2.5', 'lwgeom_cmp'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry < -- LastUpdated: 9
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 9 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR < (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_lt,
	COMMUTATOR = '>', NEGATOR = '>=',
	RESTRICT = contsel, JOIN = contjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geometry <= -- LastUpdated: 9
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 9 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR <= (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_le,
	COMMUTATOR = '>=', NEGATOR = '>',
	RESTRICT = contsel, JOIN = contjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geometry = -- LastUpdated: 9
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 9 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR = (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_eq,
	COMMUTATOR = '=', -- we might implement a faster negator here
	RESTRICT = contsel, JOIN = contjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geometry >= -- LastUpdated: 9
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 9 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR >= (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_ge,
	COMMUTATOR = '<=', NEGATOR = '<',
	RESTRICT = contsel, JOIN = contjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geometry > -- LastUpdated: 9
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 9 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR > (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_gt,
	COMMUTATOR = '<', NEGATOR = '<=',
	RESTRICT = contsel, JOIN = contjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator class btree_geometry_ops -- LastUpdated: 9
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 9 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$
    CREATE OPERATOR CLASS btree_geometry_ops
	DEFAULT FOR TYPE geometry USING btree AS
	OPERATOR	1	< ,
	OPERATOR	2	<= ,
	OPERATOR	3	= ,
	OPERATOR	4	>= ,
	OPERATOR	5	> ,
	FUNCTION	1	geometry_cmp (geom1 geometry, geom2 geometry);
    $postgis_proc_upgrade_parsed_def$;
  END IF; -- version_from >= 9
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_hash(geometry)
	RETURNS integer
	AS '$libdir/postgis-2.5','lwgeom_hash'
	LANGUAGE 'c' STRICT IMMUTABLE PARALLEL SAFE;
-- Operator class hash_geometry_ops -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$
    CREATE OPERATOR CLASS hash_geometry_ops
	DEFAULT FOR TYPE geometry USING hash AS
    OPERATOR    1   = ,
    FUNCTION    1   geometry_hash(geometry);
    $postgis_proc_upgrade_parsed_def$;
  END IF; -- version_from >= 205
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_gist_distance_2d(internal,geometry,int4)
	RETURNS float8
	AS '$libdir/postgis-2.5' ,'gserialized_gist_distance_2d'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_gist_consistent_2d(internal,geometry,int4)
	RETURNS bool
	AS '$libdir/postgis-2.5' ,'gserialized_gist_consistent_2d'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_gist_compress_2d(internal)
	RETURNS internal
	AS '$libdir/postgis-2.5','gserialized_gist_compress_2d'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_gist_penalty_2d(internal,internal,internal)
	RETURNS internal
	AS '$libdir/postgis-2.5' ,'gserialized_gist_penalty_2d'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_gist_picksplit_2d(internal, internal)
	RETURNS internal
	AS '$libdir/postgis-2.5' ,'gserialized_gist_picksplit_2d'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_gist_union_2d(bytea, internal)
	RETURNS internal
	AS '$libdir/postgis-2.5' ,'gserialized_gist_union_2d'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_gist_same_2d(geom1 geometry, geom2 geometry, internal)
	RETURNS internal
	AS '$libdir/postgis-2.5' ,'gserialized_gist_same_2d'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_gist_decompress_2d(internal)
	RETURNS internal
	AS '$libdir/postgis-2.5' ,'gserialized_gist_decompress_2d'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _postgis_selectivity(tbl regclass, att_name text, geom geometry, mode text default '2')
	RETURNS float8
	AS '$libdir/postgis-2.5', '_postgis_gserialized_sel'
	LANGUAGE 'c' STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _postgis_join_selectivity(regclass, text, regclass, text, text default '2')
	RETURNS float8
	AS '$libdir/postgis-2.5', '_postgis_gserialized_joinsel'
	LANGUAGE 'c' STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _postgis_stats(tbl regclass, att_name text, text default '2')
	RETURNS text
	AS '$libdir/postgis-2.5', '_postgis_gserialized_stats'
	LANGUAGE 'c' STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _postgis_index_extent(tbl regclass, col text)
	RETURNS box2d
	AS '$libdir/postgis-2.5','_postgis_gserialized_index_extent'
	LANGUAGE 'c' STABLE STRICT;
CREATE OR REPLACE FUNCTION gserialized_gist_sel_2d (internal, oid, internal, int4)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'gserialized_gist_sel_2d'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION gserialized_gist_sel_nd (internal, oid, internal, int4)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'gserialized_gist_sel_nd'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION gserialized_gist_joinsel_2d (internal, oid, internal, smallint)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'gserialized_gist_joinsel_2d'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION gserialized_gist_joinsel_nd (internal, oid, internal, smallint)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'gserialized_gist_joinsel_nd'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_overlaps(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5' ,'gserialized_overlaps_2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry && -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR && (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_overlaps,
	COMMUTATOR = '&&',
	RESTRICT = gserialized_gist_sel_2d,
	JOIN = gserialized_gist_joinsel_2d
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_same(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5' ,'gserialized_same_2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry ~= -- LastUpdated: 1
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 1 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR ~= (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_same,
	RESTRICT = contsel, JOIN = contjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_distance_centroid(geom1 geometry, geom2 geometry)
	RETURNS float8

  AS '$libdir/postgis-2.5' ,'distance'



	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_distance_box(geom1 geometry, geom2 geometry)
	RETURNS float8
  AS '$libdir/postgis-2.5' ,'gserialized_distance_box_2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry <-> -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR <-> (
    LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_distance_centroid,
    COMMUTATOR = '<->'
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geometry <#> -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR <#> (
    LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_distance_box,
    COMMUTATOR = '<#>'
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_contains(geom1 geometry, geom2 geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'gserialized_contains_2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_within(geom1 geometry, geom2 geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'gserialized_within_2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry @ -- LastUpdated: 1
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 1 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR @ (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_within,
	COMMUTATOR = '~',
	RESTRICT = contsel, JOIN = contjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geometry ~ -- LastUpdated: 1
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 1 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR ~ (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_contains,
	COMMUTATOR = '@',
	RESTRICT = contsel, JOIN = contjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_left(geom1 geometry, geom2 geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'gserialized_left_2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry << -- LastUpdated: 1
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 1 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR << (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_left,
	COMMUTATOR = '>>',
	RESTRICT = positionsel, JOIN = positionjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_overleft(geom1 geometry, geom2 geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'gserialized_overleft_2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry &< -- LastUpdated: 1
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 1 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR &< (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_overleft,
	RESTRICT = positionsel, JOIN = positionjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_below(geom1 geometry, geom2 geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'gserialized_below_2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry <<| -- LastUpdated: 1
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 1 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR <<| (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_below,
	COMMUTATOR = '|>>',
	RESTRICT = positionsel, JOIN = positionjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_overbelow(geom1 geometry, geom2 geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'gserialized_overbelow_2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry &<| -- LastUpdated: 1
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 1 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR &<| (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_overbelow,
	RESTRICT = positionsel, JOIN = positionjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_overright(geom1 geometry, geom2 geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'gserialized_overright_2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry &> -- LastUpdated: 1
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 1 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR &> (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_overright,
	RESTRICT = positionsel, JOIN = positionjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_right(geom1 geometry, geom2 geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'gserialized_right_2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry >> -- LastUpdated: 1
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 1 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR >> (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_right,
	COMMUTATOR = '<<',
	RESTRICT = positionsel, JOIN = positionjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_overabove(geom1 geometry, geom2 geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'gserialized_overabove_2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry |&> -- LastUpdated: 1
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 1 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR |&> (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_overabove,
	RESTRICT = positionsel, JOIN = positionjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_above(geom1 geometry, geom2 geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'gserialized_above_2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry |>> -- LastUpdated: 1
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 1 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR |>> (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_above,
	COMMUTATOR = '<<|',
	RESTRICT = positionsel, JOIN = positionjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator class gist_geometry_ops_2d -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$
    CREATE OPERATOR CLASS gist_geometry_ops_2d
	DEFAULT FOR TYPE geometry USING GIST AS
	STORAGE box2df,
	OPERATOR        1        <<  ,
	OPERATOR        2        &<	 ,
	OPERATOR        3        &&  ,
	OPERATOR        4        &>	 ,
	OPERATOR        5        >>	 ,
	OPERATOR        6        ~=	 ,
	OPERATOR        7        ~	 ,
	OPERATOR        8        @	 ,
	OPERATOR        9        &<| ,
	OPERATOR        10       <<| ,
	OPERATOR        11       |>> ,
	OPERATOR        12       |&> ,
	OPERATOR        13       <-> FOR ORDER BY pg_catalog.float_ops,
	OPERATOR        14       <#> FOR ORDER BY pg_catalog.float_ops,
	FUNCTION        8        geometry_gist_distance_2d (internal, geometry, int4),
	FUNCTION        1        geometry_gist_consistent_2d (internal, geometry, int4),
	FUNCTION        2        geometry_gist_union_2d (bytea, internal),
	FUNCTION        3        geometry_gist_compress_2d (internal),
	FUNCTION        4        geometry_gist_decompress_2d (internal),
	FUNCTION        5        geometry_gist_penalty_2d (internal, internal, internal),
	FUNCTION        6        geometry_gist_picksplit_2d (internal, internal),
	FUNCTION        7        geometry_gist_same_2d (geom1 geometry, geom2 geometry, internal);
    $postgis_proc_upgrade_parsed_def$;
  END IF; -- version_from >= 200
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_gist_consistent_nd(internal,geometry,int4)
	RETURNS bool
	AS '$libdir/postgis-2.5' ,'gserialized_gist_consistent'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_gist_compress_nd(internal)
	RETURNS internal
	AS '$libdir/postgis-2.5','gserialized_gist_compress'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_gist_penalty_nd(internal,internal,internal)
	RETURNS internal
	AS '$libdir/postgis-2.5' ,'gserialized_gist_penalty'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_gist_picksplit_nd(internal, internal)
	RETURNS internal
	AS '$libdir/postgis-2.5' ,'gserialized_gist_picksplit'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_gist_union_nd(bytea, internal)
	RETURNS internal
	AS '$libdir/postgis-2.5' ,'gserialized_gist_union'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_gist_same_nd(geometry, geometry, internal)
	RETURNS internal
	AS '$libdir/postgis-2.5' ,'gserialized_gist_same'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_gist_decompress_nd(internal)
	RETURNS internal
	AS '$libdir/postgis-2.5' ,'gserialized_gist_decompress'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_overlaps_nd(geometry, geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5' ,'gserialized_overlaps'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry &&& -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR &&& (
	LEFTARG = geometry, RIGHTARG = geometry, PROCEDURE = geometry_overlaps_nd,
	COMMUTATOR = '&&&',
	RESTRICT = gserialized_gist_sel_nd,
	JOIN = gserialized_gist_joinsel_nd
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_distance_centroid_nd(geometry,geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'gserialized_distance_nd'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry <<->> -- LastUpdated: 202
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 202 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR <<->> (
    LEFTARG = geometry, RIGHTARG = geometry,
    PROCEDURE = geometry_distance_centroid_nd,
    COMMUTATOR = '<<->>'
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_distance_cpa(geometry, geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'ST_DistanceCPA'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry |=| -- LastUpdated: 202
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 202 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR |=| (
    LEFTARG = geometry, RIGHTARG = geometry,
    PROCEDURE = geometry_distance_cpa,
    COMMUTATOR = '|=|'
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_gist_distance_nd(internal,geometry,int4)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'gserialized_gist_distance'
	LANGUAGE 'c' PARALLEL SAFE;
-- Operator class gist_geometry_ops_nd -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$
    CREATE OPERATOR CLASS gist_geometry_ops_nd
	FOR TYPE geometry USING GIST AS
	STORAGE 	gidx,
	OPERATOR        3        &&&	,
	OPERATOR        13       <<->> FOR ORDER BY pg_catalog.float_ops,

	OPERATOR        20       |=| FOR ORDER BY pg_catalog.float_ops,

	FUNCTION        8        geometry_gist_distance_nd (internal, geometry, int4),
	FUNCTION        1        geometry_gist_consistent_nd (internal, geometry, int4),
	FUNCTION        2        geometry_gist_union_nd (bytea, internal),
	FUNCTION        3        geometry_gist_compress_nd (internal),
	FUNCTION        4        geometry_gist_decompress_nd (internal),
	FUNCTION        5        geometry_gist_penalty_nd (internal, internal, internal),
	FUNCTION        6        geometry_gist_picksplit_nd (internal, internal),
	FUNCTION        7        geometry_gist_same_nd (geometry, geometry, internal);
    $postgis_proc_upgrade_parsed_def$;
  ELSE -- version_from >= 200
    -- Last Updated: 202
    IF 202 > version_from_num FROM _postgis_upgrade_info THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$
        ALTER OPERATOR FAMILY gist_geometry_ops_nd USING gist
          ADD OPERATOR        13       <<->> (geometry,geometry) FOR ORDER BY pg_catalog.float_ops;
      $postgis_proc_upgrade_parsed_def$;
    END IF;
  
    -- Last Updated: 202
    IF 202 > version_from_num FROM _postgis_upgrade_info THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$
        ALTER OPERATOR FAMILY gist_geometry_ops_nd USING gist
          ADD OPERATOR        20       |=| (geometry,geometry) FOR ORDER BY pg_catalog.float_ops;
      $postgis_proc_upgrade_parsed_def$;
    END IF;
  
    -- Last Updated: 202
    IF 202 > version_from_num FROM _postgis_upgrade_info THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$
        ALTER OPERATOR FAMILY gist_geometry_ops_nd USING gist
          ADD FUNCTION        8 (geometry,geometry)        geometry_gist_distance_nd (internal, geometry, int4);
      $postgis_proc_upgrade_parsed_def$;
    END IF;
  END IF; -- version_from >= 202
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION ST_ShiftLongitude(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_longitude_shift'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_WrapX(geom geometry, wrap float8, move float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_WrapX'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Shift_Longitude(geometry)
	RETURNS geometry AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Shift_Longitude', 'ST_ShiftLongitude', '2.2.0');
    SELECT @extschema@.ST_ShiftLongitude($1);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_XMin(box3d)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5','BOX3D_xmin'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_YMin(box3d)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5','BOX3D_ymin'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_ZMin(box3d)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5','BOX3D_zmin'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_XMax(box3d)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5','BOX3D_xmax'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_YMax(box3d)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5','BOX3D_ymax'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_ZMax(box3d)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5','BOX3D_zmax'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Expand(box2d,float8)
	RETURNS box2d
	AS '$libdir/postgis-2.5', 'BOX2D_expand'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Expand(box box2d, dx float8, dy float8)
	RETURNS box2d
	AS '$libdir/postgis-2.5', 'BOX2D_expand'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION postgis_getbbox(geometry)
	RETURNS box2d
	AS '$libdir/postgis-2.5','LWGEOM_to_BOX2DF'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MakeBox2d(geom1 geometry, geom2 geometry)
	RETURNS box2d
	AS '$libdir/postgis-2.5', 'BOX2D_construct'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_EstimatedExtent(text,text,text,boolean) RETURNS box2d AS
	'$libdir/postgis-2.5', 'gserialized_estimated_extent'
	LANGUAGE 'c' IMMUTABLE STRICT SECURITY DEFINER;
CREATE OR REPLACE FUNCTION ST_EstimatedExtent(text,text,text) RETURNS box2d AS
	'$libdir/postgis-2.5', 'gserialized_estimated_extent'
	LANGUAGE 'c' IMMUTABLE STRICT SECURITY DEFINER;
CREATE OR REPLACE FUNCTION ST_estimated_extent(text,text,text) RETURNS box2d AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Estimated_Extent', 'ST_EstimatedExtent', '2.1.0');
    -- We use security invoker instead of security definer
    -- to prevent malicious injection of a different same named function
    SELECT @extschema@.ST_EstimatedExtent($1, $2, $3);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT SECURITY INVOKER;
CREATE OR REPLACE FUNCTION ST_EstimatedExtent(text,text) RETURNS box2d AS
	'$libdir/postgis-2.5', 'gserialized_estimated_extent'
	LANGUAGE 'c' IMMUTABLE STRICT SECURITY DEFINER;
CREATE OR REPLACE FUNCTION ST_estimated_extent(text,text) RETURNS box2d AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Estimated_Extent', 'ST_EstimatedExtent', '2.1.0');
    -- We use security invoker instead of security definer
    -- to prevent malicious injection of a same named different function
    -- that would be run under elevated permissions
    SELECT @extschema@.ST_EstimatedExtent($1, $2);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT SECURITY INVOKER;
CREATE OR REPLACE FUNCTION ST_FindExtent(text,text,text) RETURNS box2d AS
$$
DECLARE
	schemaname alias for $1;
	tablename alias for $2;
	columnname alias for $3;
	myrec RECORD;
BEGIN
	FOR myrec IN EXECUTE 'SELECT @extschema@.ST_Extent("' || columnname || '") As extent FROM "' || schemaname || '"."' || tablename || '"' LOOP
		return myrec.extent;
	END LOOP;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_find_extent(text,text,text) RETURNS box2d AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Find_Extent', 'ST_FindExtent', '2.2.0');
    SELECT @extschema@.ST_FindExtent($1,$2,$3);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_FindExtent(text,text) RETURNS box2d AS
$$
DECLARE
	tablename alias for $1;
	columnname alias for $2;
	myrec RECORD;

BEGIN
	FOR myrec IN EXECUTE 'SELECT @extschema@.ST_Extent("' || columnname || '") As extent FROM "' || tablename || '"' LOOP
		return myrec.extent;
	END LOOP;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_find_extent(text,text) RETURNS box2d AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Find_Extent', 'ST_FindExtent', '2.2.0');
    SELECT @extschema@.ST_FindExtent($1,$2);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION postgis_addbbox(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOM_addBBOX'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION postgis_dropbbox(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOM_dropBBOX'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION postgis_hasbbox(geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'LWGEOM_hasBBOX'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_QuantizeCoordinates(g geometry, prec_x int, prec_y int DEFAULT NULL, prec_z int DEFAULT NULL, prec_m int DEFAULT NULL)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_QuantizeCoordinates'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_MemSize(geometry)
	RETURNS int4
	AS '$libdir/postgis-2.5', 'LWGEOM_mem_size'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 5;
CREATE OR REPLACE FUNCTION ST_mem_size(geometry)
	RETURNS int4 AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Mem_Size', 'ST_MemSize', '2.2.0');
    SELECT @extschema@.ST_MemSize($1);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT SECURITY INVOKER;
CREATE OR REPLACE FUNCTION ST_summary(geometry)
	RETURNS text
	AS '$libdir/postgis-2.5', 'LWGEOM_summary'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 25;
CREATE OR REPLACE FUNCTION ST_Npoints(geometry)
	RETURNS int4
	AS '$libdir/postgis-2.5', 'LWGEOM_npoints'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_nrings(geometry)
	RETURNS int4
	AS '$libdir/postgis-2.5', 'LWGEOM_nrings'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_3DLength(geometry)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5', 'LWGEOM_length_linestring'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 20;
CREATE OR REPLACE FUNCTION ST_Length2d(geometry)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5', 'LWGEOM_length2d_linestring'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_Length(geometry)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5', 'LWGEOM_length2d_linestring'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_LengthSpheroid(geometry, spheroid)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5','LWGEOM_length_ellipsoid_linestring'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 500;
CREATE OR REPLACE FUNCTION ST_3DLength_spheroid(geometry, spheroid)
	RETURNS FLOAT8 AS
  $$ SELECT @extschema@._postgis_deprecate('ST_3DLength_Spheroid', 'ST_LengthSpheroid', '2.2.0');
    SELECT @extschema@.ST_LengthSpheroid($1,$2);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION ST_length_spheroid(geometry, spheroid)
	RETURNS FLOAT8 AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Length_Spheroid', 'ST_LengthSpheroid', '2.2.0');
    SELECT @extschema@.ST_LengthSpheroid($1,$2);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Length2DSpheroid(geometry, spheroid)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5','LWGEOM_length2d_ellipsoid'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 500;
CREATE OR REPLACE FUNCTION ST_length2d_spheroid(geometry, spheroid)
	RETURNS FLOAT8 AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Length2D_Spheroid', 'ST_Length2DSpheroid', '2.2.0');
    SELECT @extschema@.ST_Length2DSpheroid($1,$2);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_3DPerimeter(geometry)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5', 'LWGEOM_perimeter_poly'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_perimeter2d(geometry)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5', 'LWGEOM_perimeter2d_poly'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_Perimeter(geometry)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5', 'LWGEOM_perimeter2d_poly'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_area2d(geometry)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5', 'LWGEOM_area_polygon'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_Area(geometry)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5','area'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_IsPolygonCW(geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5','ST_IsPolygonCW'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_IsPolygonCCW(geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5','ST_IsPolygonCCW'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_DistanceSpheroid(geom1 geometry, geom2 geometry,spheroid)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5','LWGEOM_distance_ellipsoid'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 200; --upped this
CREATE OR REPLACE FUNCTION ST_distance_spheroid(geom1 geometry, geom2 geometry,spheroid)
	RETURNS FLOAT8 AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Distance_Spheroid', 'ST_DistanceSpheroid', '2.2.0');
    SELECT @extschema@.ST_DistanceSpheroid($1,$2,$3);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Distance(geom1 geometry, geom2 geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'distance'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 25; --changed from 100 should be 1/5th to 1/10 spheroid
CREATE OR REPLACE FUNCTION ST_PointInsideCircle(geometry,float8,float8,float8)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'LWGEOM_inside_circle_point'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_point_inside_circle(geometry,float8,float8,float8)
	RETURNS bool AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Point_Inside_Circle', 'ST_PointInsideCircle', '2.2.0');
    SELECT @extschema@.ST_PointInsideCircle($1,$2,$3,$4);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_azimuth(geom1 geometry, geom2 geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'LWGEOM_azimuth'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Angle(pt1 geometry, pt2 geometry, pt3 geometry, pt4 geometry default 'POINT EMPTY'::geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'LWGEOM_angle'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Force2D(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_force_2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_force_2d(geometry)
	RETURNS geometry AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Force_2d', 'ST_Force2D', '2.1.0');
    SELECT @extschema@.ST_Force2D($1);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Force3DZ(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_force_3dz'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_force_3dz(geometry)
	RETURNS geometry AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Force_3dz', 'ST_Force3DZ', '2.1.0');
    SELECT @extschema@.ST_Force3DZ($1);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Force3D(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_force_3dz'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_force_3d(geometry)
	RETURNS geometry AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Force_3d', 'ST_Force3D', '2.1.0');
    SELECT @extschema@.ST_Force3D($1);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Force3DM(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_force_3dm'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_force_3dm(geometry)
	RETURNS geometry AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Force_3dm', 'ST_Force3DM', '2.1.0');
    SELECT @extschema@.ST_Force3DM($1);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Force4D(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_force_4d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_force_4d(geometry)
	RETURNS geometry AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Force_4d', 'ST_Force4D', '2.1.0');
    SELECT @extschema@.ST_Force4D($1);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_ForceCollection(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_force_collection'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_force_collection(geometry)
	RETURNS geometry AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Force_Collection', 'ST_ForceCollection', '2.1.0');
    SELECT @extschema@.ST_ForceCollection($1);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_CollectionExtract(geometry, integer)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_CollectionExtract'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_CollectionHomogenize(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_CollectionHomogenize'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Multi(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_force_multi'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_ForceCurve(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_force_curve'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_ForceSFS(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_force_sfs'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_ForceSFS(geometry, version text)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_force_sfs'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_Expand(box3d,float8)
	RETURNS box3d
	AS '$libdir/postgis-2.5', 'BOX3D_expand'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_Expand(box box3d, dx float8, dy float8, dz float8 DEFAULT 0)
	RETURNS box3d
	AS '$libdir/postgis-2.5', 'BOX3D_expand'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_Expand(geometry,float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_expand'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_Expand(geom geometry, dx float8, dy float8, dz float8 DEFAULT 0, dm float8 DEFAULT 0)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_expand'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_Envelope(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_envelope'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_BoundingDiagonal(geom geometry, fits boolean DEFAULT false)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_BoundingDiagonal'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Reverse(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_reverse'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_ForcePolygonCW(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_force_clockwise_poly'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 15;
CREATE OR REPLACE FUNCTION ST_ForcePolygonCCW(geometry)
	RETURNS geometry
	AS $$ SELECT @extschema@.ST_Reverse(@extschema@.ST_ForcePolygonCW($1)) $$
	LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE
	COST 15;
CREATE OR REPLACE FUNCTION ST_ForceRHR(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_force_clockwise_poly'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION postgis_noop(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_noop'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_Normalize(geom geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_Normalize'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_zmflag(geometry)
	RETURNS smallint
	AS '$libdir/postgis-2.5', 'LWGEOM_zmflag'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 5;
CREATE OR REPLACE FUNCTION ST_NDims(geometry)
	RETURNS smallint
	AS '$libdir/postgis-2.5', 'LWGEOM_ndims'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 5;
CREATE OR REPLACE FUNCTION ST_AsEWKT(geometry)
	RETURNS TEXT
	AS '$libdir/postgis-2.5','LWGEOM_asEWKT'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 750; --this looks suspicious, requires recheck
CREATE OR REPLACE FUNCTION ST_AsTWKB(geom geometry, prec int4 default NULL, prec_z int4 default NULL, prec_m int4 default NULL, with_sizes boolean default NULL, with_boxes boolean default NULL)
	RETURNS bytea
	AS '$libdir/postgis-2.5','TWKBFromLWGEOM'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsTWKB(geom geometry[], ids bigint[], prec int4 default NULL, prec_z int4 default NULL, prec_m int4 default NULL, with_sizes boolean default NULL, with_boxes boolean default NULL)
	RETURNS bytea
	AS '$libdir/postgis-2.5','TWKBFromLWGEOMArray'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsEWKB(geometry)
	RETURNS BYTEA
	AS '$libdir/postgis-2.5','WKBFromLWGEOM'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_AsHEXEWKB(geometry)
	RETURNS TEXT
	AS '$libdir/postgis-2.5','LWGEOM_asHEXEWKB'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 25;
CREATE OR REPLACE FUNCTION ST_AsHEXEWKB(geometry, text)
	RETURNS TEXT
	AS '$libdir/postgis-2.5','LWGEOM_asHEXEWKB'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 25;
CREATE OR REPLACE FUNCTION ST_AsEWKB(geometry,text)
	RETURNS bytea
	AS '$libdir/postgis-2.5','WKBFromLWGEOM'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_AsLatLonText(geom geometry, tmpl text DEFAULT '')
	RETURNS text
	AS '$libdir/postgis-2.5','LWGEOM_to_latlon'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION GeomFromEWKB(bytea)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOMFromEWKB'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomFromEWKB(bytea)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOMFromEWKB'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomFromTWKB(bytea)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOMFromTWKB'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION GeomFromEWKT(text)
	RETURNS geometry
	AS '$libdir/postgis-2.5','parse_WKT_lwgeom'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomFromEWKT(text)
	RETURNS geometry
	AS '$libdir/postgis-2.5','parse_WKT_lwgeom'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION postgis_cache_bbox()
	RETURNS trigger
	AS '$libdir/postgis-2.5', 'cache_bbox'
	LANGUAGE 'c';
CREATE OR REPLACE FUNCTION ST_MakePoint(float8, float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_makepoint'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MakePoint(float8, float8, float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_makepoint'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MakePoint(float8, float8, float8, float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_makepoint'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MakePointM(float8, float8, float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_makepoint3dm'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_3DMakeBox(geom1 geometry, geom2 geometry)
	RETURNS box3d
	AS '$libdir/postgis-2.5', 'BOX3D_construct'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MakeLine (geometry[])
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_makeline_garray'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LineFromMultiPoint(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_line_from_mpoint'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MakeLine(geom1 geometry, geom2 geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_makeline'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AddPoint(geom1 geometry, geom2 geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_addpoint'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AddPoint(geom1 geometry, geom2 geometry, integer)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_addpoint'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_RemovePoint(geometry, integer)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_removepoint'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_SetPoint(geometry, integer, geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_setpoint_linestring'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MakeEnvelope(float8, float8, float8, float8, integer DEFAULT 0)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_MakeEnvelope'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MakePolygon(geometry, geometry[])
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_makepoly'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MakePolygon(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_makepoly'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_BuildArea(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_BuildArea'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_Polygonize (geometry[])
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'polygonize_garray'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_ClusterIntersecting(geometry[])
    RETURNS geometry[]
    AS '$libdir/postgis-2.5',  'clusterintersecting_garray'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_ClusterWithin(geometry[], float8)
    RETURNS geometry[]
    AS '$libdir/postgis-2.5',  'cluster_within_distance_garray'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_ClusterDBSCAN (geometry, eps float8, minpoints int)
	RETURNS int
	AS '$libdir/postgis-2.5', 'ST_ClusterDBSCAN'
	LANGUAGE 'c' IMMUTABLE STRICT WINDOW PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LineMerge(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'linemerge'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_Affine(geometry,float8,float8,float8,float8,float8,float8,float8,float8,float8,float8,float8,float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_affine'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_Affine(geometry,float8,float8,float8,float8,float8,float8)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_Affine($1,  $2, $3, 0,  $4, $5, 0,  0, 0, 1,  $6, $7, 0)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Rotate(geometry,float8)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_Affine($1,  cos($2), -sin($2), 0,  sin($2), cos($2), 0,  0, 0, 1,  0, 0, 0)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Rotate(geometry,float8,float8,float8)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_Affine($1,  cos($2), -sin($2), 0,  sin($2),  cos($2), 0, 0, 0, 1,	$3 - cos($2) * $3 + sin($2) * $4, $4 - sin($2) * $3 - cos($2) * $4, 0)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Rotate(geometry,float8,geometry)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_Affine($1,  cos($2), -sin($2), 0,  sin($2),  cos($2), 0, 0, 0, 1, @extschema@.ST_X($3) - cos($2) * @extschema@.ST_X($3) + sin($2) * @extschema@.ST_Y($3), @extschema@.ST_Y($3) - sin($2) * @extschema@.ST_X($3) - cos($2) * @extschema@.ST_Y($3), 0)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_RotateZ(geometry,float8)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_Rotate($1, $2)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_RotateX(geometry,float8)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_Affine($1, 1, 0, 0, 0, cos($2), -sin($2), 0, sin($2), cos($2), 0, 0, 0)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_RotateY(geometry,float8)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_Affine($1,  cos($2), 0, sin($2),  0, 1, 0,  -sin($2), 0, cos($2), 0,  0, 0)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Translate(geometry,float8,float8,float8)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_Affine($1, 1, 0, 0, 0, 1, 0, 0, 0, 1, $2, $3, $4)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Translate(geometry,float8,float8)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_Translate($1, $2, $3, 0)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Scale(geometry,geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_Scale'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Scale(geometry,geometry,origin geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_Scale'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Scale(geometry,float8,float8,float8)
	RETURNS geometry
	--AS 'SELECT ST_Affine($1,  $2, 0, 0,  0, $3, 0,  0, 0, $4,  0, 0, 0)'
	AS 'SELECT @extschema@.ST_Scale($1, @extschema@.ST_MakePoint($2, $3, $4))'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Scale(geometry,float8,float8)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_Scale($1, $2, $3, 1)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Transscale(geometry,float8,float8,float8,float8)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_Affine($1,  $4, 0, 0,  0, $5, 0,
		0, 0, 1,  $2 * $4, $3 * $5, 0)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
-- Type geometry_dump -- LastUpdated: 100
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 100 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE geometry_dump AS (
	path integer[],
	geom geometry
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION ST_Dump(geometry)
	RETURNS SETOF geometry_dump
	AS '$libdir/postgis-2.5', 'LWGEOM_dump'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION ST_DumpRings(geometry)
	RETURNS SETOF geometry_dump
	AS '$libdir/postgis-2.5', 'LWGEOM_dump_rings'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_DumpPoints(geometry)
       	RETURNS SETOF geometry_dump
	AS '$libdir/postgis-2.5', 'LWGEOM_dumppoints'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION populate_geometry_columns(use_typmod boolean DEFAULT true)
	RETURNS text AS
$$
DECLARE
	inserted    integer;
	oldcount    integer;
	probed      integer;
	stale       integer;
	gcs         RECORD;
	gc          RECORD;
	gsrid       integer;
	gndims      integer;
	gtype       text;
	query       text;
	gc_is_valid boolean;

BEGIN
	SELECT count(*) INTO oldcount FROM @extschema@.geometry_columns;
	inserted := 0;

	-- Count the number of geometry columns in all tables and views
	SELECT count(DISTINCT c.oid) INTO probed
	FROM pg_class c,
		 pg_attribute a,
		 pg_type t,
		 pg_namespace n
	WHERE c.relkind IN('r','v','f')
		AND t.typname = 'geometry'
		AND a.attisdropped = false
		AND a.atttypid = t.oid
		AND a.attrelid = c.oid
		AND c.relnamespace = n.oid
		AND n.nspname NOT ILIKE 'pg_temp%' AND c.relname != 'raster_columns' ;

	-- Iterate through all non-dropped geometry columns
	RAISE DEBUG 'Processing Tables.....';

	FOR gcs IN
	SELECT DISTINCT ON (c.oid) c.oid, n.nspname, c.relname
		FROM pg_class c,
			 pg_attribute a,
			 pg_type t,
			 pg_namespace n
		WHERE c.relkind IN( 'r', 'f')
		AND t.typname = 'geometry'
		AND a.attisdropped = false
		AND a.atttypid = t.oid
		AND a.attrelid = c.oid
		AND c.relnamespace = n.oid
		AND n.nspname NOT ILIKE 'pg_temp%' AND c.relname != 'raster_columns'
	LOOP

		inserted := inserted + @extschema@.populate_geometry_columns(gcs.oid, use_typmod);
	END LOOP;

	IF oldcount > inserted THEN
	    stale = oldcount-inserted;
	ELSE
	    stale = 0;
	END IF;

	RETURN 'probed:' ||probed|| ' inserted:'||inserted;
END

$$
LANGUAGE 'plpgsql' VOLATILE;
CREATE OR REPLACE FUNCTION populate_geometry_columns(tbl_oid oid, use_typmod boolean DEFAULT true)
	RETURNS integer AS
$$
DECLARE
	gcs         RECORD;
	gc          RECORD;
	gc_old      RECORD;
	gsrid       integer;
	gndims      integer;
	gtype       text;
	query       text;
	gc_is_valid boolean;
	inserted    integer;
	constraint_successful boolean := false;

BEGIN
	inserted := 0;

	-- Iterate through all geometry columns in this table
	FOR gcs IN
	SELECT n.nspname, c.relname, a.attname
		FROM pg_class c,
			 pg_attribute a,
			 pg_type t,
			 pg_namespace n
		WHERE c.relkind IN('r', 'f')
		AND t.typname = 'geometry'
		AND a.attisdropped = false
		AND a.atttypid = t.oid
		AND a.attrelid = c.oid
		AND c.relnamespace = n.oid
		AND n.nspname NOT ILIKE 'pg_temp%'
		AND c.oid = tbl_oid
	LOOP

        RAISE DEBUG 'Processing column %.%.%', gcs.nspname, gcs.relname, gcs.attname;

        gc_is_valid := true;
        -- Find the srid, coord_dimension, and type of current geometry
        -- in geometry_columns -- which is now a view

        SELECT type, srid, coord_dimension INTO gc_old
            FROM geometry_columns
            WHERE f_table_schema = gcs.nspname AND f_table_name = gcs.relname AND f_geometry_column = gcs.attname;

        IF upper(gc_old.type) = 'GEOMETRY' THEN
        -- This is an unconstrained geometry we need to do something
        -- We need to figure out what to set the type by inspecting the data
            EXECUTE 'SELECT @extschema@.ST_srid(' || quote_ident(gcs.attname) || ') As srid, @extschema@.GeometryType(' || quote_ident(gcs.attname) || ') As type, @extschema@.ST_NDims(' || quote_ident(gcs.attname) || ') As dims ' ||
                     ' FROM ONLY ' || quote_ident(gcs.nspname) || '.' || quote_ident(gcs.relname) ||
                     ' WHERE ' || quote_ident(gcs.attname) || ' IS NOT NULL LIMIT 1;'
                INTO gc;
            IF gc IS NULL THEN -- there is no data so we can not determine geometry type
            	RAISE WARNING 'No data in table %.%, so no information to determine geometry type and srid', gcs.nspname, gcs.relname;
            	RETURN 0;
            END IF;
            gsrid := gc.srid; gtype := gc.type; gndims := gc.dims;

            IF use_typmod THEN
                BEGIN
                    EXECUTE 'ALTER TABLE ' || quote_ident(gcs.nspname) || '.' || quote_ident(gcs.relname) || ' ALTER COLUMN ' || quote_ident(gcs.attname) ||
                        ' TYPE geometry(' || postgis_type_name(gtype, gndims, true) || ', ' || gsrid::text  || ') ';
                    inserted := inserted + 1;
                EXCEPTION
                        WHEN invalid_parameter_value OR feature_not_supported THEN
                        RAISE WARNING 'Could not convert ''%'' in ''%.%'' to use typmod with srid %, type %: %', quote_ident(gcs.attname), quote_ident(gcs.nspname), quote_ident(gcs.relname), gsrid, postgis_type_name(gtype, gndims, true), SQLERRM;
                            gc_is_valid := false;
                END;

            ELSE
                -- Try to apply srid check to column
            	constraint_successful = false;
                IF (gsrid > 0 AND postgis_constraint_srid(gcs.nspname, gcs.relname,gcs.attname) IS NULL ) THEN
                    BEGIN
                        EXECUTE 'ALTER TABLE ONLY ' || quote_ident(gcs.nspname) || '.' || quote_ident(gcs.relname) ||
                                 ' ADD CONSTRAINT ' || quote_ident('enforce_srid_' || gcs.attname) ||
                                 ' CHECK (ST_srid(' || quote_ident(gcs.attname) || ') = ' || gsrid || ')';
                        constraint_successful := true;
                    EXCEPTION
                        WHEN check_violation THEN
                            RAISE WARNING 'Not inserting ''%'' in ''%.%'' into geometry_columns: could not apply constraint CHECK (st_srid(%) = %)', quote_ident(gcs.attname), quote_ident(gcs.nspname), quote_ident(gcs.relname), quote_ident(gcs.attname), gsrid;
                            gc_is_valid := false;
                    END;
                END IF;

                -- Try to apply ndims check to column
                IF (gndims IS NOT NULL AND postgis_constraint_dims(gcs.nspname, gcs.relname,gcs.attname) IS NULL ) THEN
                    BEGIN
                        EXECUTE 'ALTER TABLE ONLY ' || quote_ident(gcs.nspname) || '.' || quote_ident(gcs.relname) || '
                                 ADD CONSTRAINT ' || quote_ident('enforce_dims_' || gcs.attname) || '
                                 CHECK (st_ndims(' || quote_ident(gcs.attname) || ') = '||gndims||')';
                        constraint_successful := true;
                    EXCEPTION
                        WHEN check_violation THEN
                            RAISE WARNING 'Not inserting ''%'' in ''%.%'' into geometry_columns: could not apply constraint CHECK (st_ndims(%) = %)', quote_ident(gcs.attname), quote_ident(gcs.nspname), quote_ident(gcs.relname), quote_ident(gcs.attname), gndims;
                            gc_is_valid := false;
                    END;
                END IF;

                -- Try to apply geometrytype check to column
                IF (gtype IS NOT NULL AND postgis_constraint_type(gcs.nspname, gcs.relname,gcs.attname) IS NULL ) THEN
                    BEGIN
                        EXECUTE 'ALTER TABLE ONLY ' || quote_ident(gcs.nspname) || '.' || quote_ident(gcs.relname) || '
                        ADD CONSTRAINT ' || quote_ident('enforce_geotype_' || gcs.attname) || '
                        CHECK (geometrytype(' || quote_ident(gcs.attname) || ') = ' || quote_literal(gtype) || ')';
                        constraint_successful := true;
                    EXCEPTION
                        WHEN check_violation THEN
                            -- No geometry check can be applied. This column contains a number of geometry types.
                            RAISE WARNING 'Could not add geometry type check (%) to table column: %.%.%', gtype, quote_ident(gcs.nspname),quote_ident(gcs.relname),quote_ident(gcs.attname);
                    END;
                END IF;
                 --only count if we were successful in applying at least one constraint
                IF constraint_successful THEN
                	inserted := inserted + 1;
                END IF;
            END IF;
	    END IF;

	END LOOP;

	RETURN inserted;
END

$$
LANGUAGE 'plpgsql' VOLATILE;
CREATE OR REPLACE FUNCTION AddGeometryColumn(catalog_name varchar,schema_name varchar,table_name varchar,column_name varchar,new_srid_in integer,new_type varchar,new_dim integer, use_typmod boolean DEFAULT true)
	RETURNS text
	AS
$$
DECLARE
	rec RECORD;
	sr varchar;
	real_schema name;
	sql text;
	new_srid integer;

BEGIN

	-- Verify geometry type
	IF (postgis_type_name(new_type,new_dim) IS NULL )
	THEN
		RAISE EXCEPTION 'Invalid type name "%(%)" - valid ones are:
	POINT, MULTIPOINT,
	LINESTRING, MULTILINESTRING,
	POLYGON, MULTIPOLYGON,
	CIRCULARSTRING, COMPOUNDCURVE, MULTICURVE,
	CURVEPOLYGON, MULTISURFACE,
	GEOMETRY, GEOMETRYCOLLECTION,
	POINTM, MULTIPOINTM,
	LINESTRINGM, MULTILINESTRINGM,
	POLYGONM, MULTIPOLYGONM,
	CIRCULARSTRINGM, COMPOUNDCURVEM, MULTICURVEM
	CURVEPOLYGONM, MULTISURFACEM, TRIANGLE, TRIANGLEM,
	POLYHEDRALSURFACE, POLYHEDRALSURFACEM, TIN, TINM
	or GEOMETRYCOLLECTIONM', new_type, new_dim;
		RETURN 'fail';
	END IF;

	-- Verify dimension
	IF ( (new_dim >4) OR (new_dim <2) ) THEN
		RAISE EXCEPTION 'invalid dimension';
		RETURN 'fail';
	END IF;

	IF ( (new_type LIKE '%M') AND (new_dim!=3) ) THEN
		RAISE EXCEPTION 'TypeM needs 3 dimensions';
		RETURN 'fail';
	END IF;

	-- Verify SRID
	IF ( new_srid_in > 0 ) THEN
		IF new_srid_in > 998999 THEN
			RAISE EXCEPTION 'AddGeometryColumn() - SRID must be <= %', 998999;
		END IF;
		new_srid := new_srid_in;
		SELECT SRID INTO sr FROM spatial_ref_sys WHERE SRID = new_srid;
		IF NOT FOUND THEN
			RAISE EXCEPTION 'AddGeometryColumn() - invalid SRID';
			RETURN 'fail';
		END IF;
	ELSE
		new_srid := @extschema@.ST_SRID('POINT EMPTY'::@extschema@.geometry);
		IF ( new_srid_in != new_srid ) THEN
			RAISE NOTICE 'SRID value % converted to the officially unknown SRID value %', new_srid_in, new_srid;
		END IF;
	END IF;

	-- Verify schema
	IF ( schema_name IS NOT NULL AND schema_name != '' ) THEN
		sql := 'SELECT nspname FROM pg_namespace ' ||
			'WHERE text(nspname) = ' || quote_literal(schema_name) ||
			'LIMIT 1';
		RAISE DEBUG '%', sql;
		EXECUTE sql INTO real_schema;

		IF ( real_schema IS NULL ) THEN
			RAISE EXCEPTION 'Schema % is not a valid schemaname', quote_literal(schema_name);
			RETURN 'fail';
		END IF;
	END IF;

	IF ( real_schema IS NULL ) THEN
		RAISE DEBUG 'Detecting schema';
		sql := 'SELECT n.nspname AS schemaname ' ||
			'FROM pg_catalog.pg_class c ' ||
			  'JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace ' ||
			'WHERE c.relkind = ' || quote_literal('r') ||
			' AND n.nspname NOT IN (' || quote_literal('pg_catalog') || ', ' || quote_literal('pg_toast') || ')' ||
			' AND pg_catalog.pg_table_is_visible(c.oid)' ||
			' AND c.relname = ' || quote_literal(table_name);
		RAISE DEBUG '%', sql;
		EXECUTE sql INTO real_schema;

		IF ( real_schema IS NULL ) THEN
			RAISE EXCEPTION 'Table % does not occur in the search_path', quote_literal(table_name);
			RETURN 'fail';
		END IF;
	END IF;

	-- Add geometry column to table
	IF use_typmod THEN
	     sql := 'ALTER TABLE ' ||
            quote_ident(real_schema) || '.' || quote_ident(table_name)
            || ' ADD COLUMN ' || quote_ident(column_name) ||
            ' geometry(' || @extschema@.postgis_type_name(new_type, new_dim) || ', ' || new_srid::text || ')';
        RAISE DEBUG '%', sql;
	ELSE
        sql := 'ALTER TABLE ' ||
            quote_ident(real_schema) || '.' || quote_ident(table_name)
            || ' ADD COLUMN ' || quote_ident(column_name) ||
            ' geometry ';
        RAISE DEBUG '%', sql;
    END IF;
	EXECUTE sql;

	IF NOT use_typmod THEN
        -- Add table CHECKs
        sql := 'ALTER TABLE ' ||
            quote_ident(real_schema) || '.' || quote_ident(table_name)
            || ' ADD CONSTRAINT '
            || quote_ident('enforce_srid_' || column_name)
            || ' CHECK (st_srid(' || quote_ident(column_name) ||
            ') = ' || new_srid::text || ')' ;
        RAISE DEBUG '%', sql;
        EXECUTE sql;

        sql := 'ALTER TABLE ' ||
            quote_ident(real_schema) || '.' || quote_ident(table_name)
            || ' ADD CONSTRAINT '
            || quote_ident('enforce_dims_' || column_name)
            || ' CHECK (st_ndims(' || quote_ident(column_name) ||
            ') = ' || new_dim::text || ')' ;
        RAISE DEBUG '%', sql;
        EXECUTE sql;

        IF ( NOT (new_type = 'GEOMETRY')) THEN
            sql := 'ALTER TABLE ' ||
                quote_ident(real_schema) || '.' || quote_ident(table_name) || ' ADD CONSTRAINT ' ||
                quote_ident('enforce_geotype_' || column_name) ||
                ' CHECK (GeometryType(' ||
                quote_ident(column_name) || ')=' ||
                quote_literal(new_type) || ' OR (' ||
                quote_ident(column_name) || ') is null)';
            RAISE DEBUG '%', sql;
            EXECUTE sql;
        END IF;
    END IF;

	RETURN
		real_schema || '.' ||
		table_name || '.' || column_name ||
		' SRID:' || new_srid::text ||
		' TYPE:' || new_type ||
		' DIMS:' || new_dim::text || ' ';
END;
$$
LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION AddGeometryColumn(schema_name varchar,table_name varchar,column_name varchar,new_srid integer,new_type varchar,new_dim integer, use_typmod boolean DEFAULT true) RETURNS text AS $$
DECLARE
	ret  text;
BEGIN
	SELECT @extschema@.AddGeometryColumn('',$1,$2,$3,$4,$5,$6,$7) into ret;
	RETURN ret;
END;
$$
LANGUAGE 'plpgsql' STABLE STRICT;
CREATE OR REPLACE FUNCTION AddGeometryColumn(table_name varchar,column_name varchar,new_srid integer,new_type varchar,new_dim integer, use_typmod boolean DEFAULT true) RETURNS text AS $$
DECLARE
	ret  text;
BEGIN
	SELECT @extschema@.AddGeometryColumn('','',$1,$2,$3,$4,$5, $6) into ret;
	RETURN ret;
END;
$$
LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION DropGeometryColumn(catalog_name varchar, schema_name varchar,table_name varchar,column_name varchar)
	RETURNS text
	AS
$$
DECLARE
	myrec RECORD;
	okay boolean;
	real_schema name;

BEGIN

	-- Find, check or fix schema_name
	IF ( schema_name != '' ) THEN
		okay = false;

		FOR myrec IN SELECT nspname FROM pg_namespace WHERE text(nspname) = schema_name LOOP
			okay := true;
		END LOOP;

		IF ( okay <>  true ) THEN
			RAISE NOTICE 'Invalid schema name - using current_schema()';
			SELECT current_schema() into real_schema;
		ELSE
			real_schema = schema_name;
		END IF;
	ELSE
		SELECT current_schema() into real_schema;
	END IF;

	-- Find out if the column is in the geometry_columns table
	okay = false;
	FOR myrec IN SELECT * from @extschema@.geometry_columns where f_table_schema = text(real_schema) and f_table_name = table_name and f_geometry_column = column_name LOOP
		okay := true;
	END LOOP;
	IF (okay <> true) THEN
		RAISE EXCEPTION 'column not found in geometry_columns table';
		RETURN false;
	END IF;

	-- Remove table column
	EXECUTE 'ALTER TABLE ' || quote_ident(real_schema) || '.' ||
		quote_ident(table_name) || ' DROP COLUMN ' ||
		quote_ident(column_name);

	RETURN real_schema || '.' || table_name || '.' || column_name ||' effectively removed.';

END;
$$
LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION DropGeometryColumn(schema_name varchar, table_name varchar,column_name varchar)
	RETURNS text
	AS
$$
DECLARE
	ret text;
BEGIN
	SELECT @extschema@.DropGeometryColumn('',$1,$2,$3) into ret;
	RETURN ret;
END;
$$
LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION DropGeometryColumn(table_name varchar, column_name varchar)
	RETURNS text
	AS
$$
DECLARE
	ret text;
BEGIN
	SELECT @extschema@.DropGeometryColumn('','',$1,$2) into ret;
	RETURN ret;
END;
$$
LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION DropGeometryTable(catalog_name varchar, schema_name varchar, table_name varchar)
	RETURNS text
	AS
$$
DECLARE
	real_schema name;

BEGIN

	IF ( schema_name = '' ) THEN
		SELECT current_schema() into real_schema;
	ELSE
		real_schema = schema_name;
	END IF;

	-- TODO: Should we warn if table doesn't exist probably instead just saying dropped
	-- Remove table
	EXECUTE 'DROP TABLE IF EXISTS '
		|| quote_ident(real_schema) || '.' ||
		quote_ident(table_name) || ' RESTRICT';

	RETURN
		real_schema || '.' ||
		table_name ||' dropped.';

END;
$$
LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION DropGeometryTable(schema_name varchar, table_name varchar) RETURNS text AS
$$ SELECT @extschema@.DropGeometryTable('',$1,$2) $$
LANGUAGE 'sql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION DropGeometryTable(table_name varchar) RETURNS text AS
$$ SELECT @extschema@.DropGeometryTable('','',$1) $$
LANGUAGE 'sql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION UpdateGeometrySRID(catalogn_name varchar,schema_name varchar,table_name varchar,column_name varchar,new_srid_in integer)
	RETURNS text
	AS
$$
DECLARE
	myrec RECORD;
	okay boolean;
	cname varchar;
	real_schema name;
	unknown_srid integer;
	new_srid integer := new_srid_in;

BEGIN

	-- Find, check or fix schema_name
	IF ( schema_name != '' ) THEN
		okay = false;

		FOR myrec IN SELECT nspname FROM pg_namespace WHERE text(nspname) = schema_name LOOP
			okay := true;
		END LOOP;

		IF ( okay <> true ) THEN
			RAISE EXCEPTION 'Invalid schema name';
		ELSE
			real_schema = schema_name;
		END IF;
	ELSE
		SELECT INTO real_schema current_schema()::text;
	END IF;

	-- Ensure that column_name is in geometry_columns
	okay = false;
	FOR myrec IN SELECT type, coord_dimension FROM @extschema@.geometry_columns WHERE f_table_schema = text(real_schema) and f_table_name = table_name and f_geometry_column = column_name LOOP
		okay := true;
	END LOOP;
	IF (NOT okay) THEN
		RAISE EXCEPTION 'column not found in geometry_columns table';
		RETURN false;
	END IF;

	-- Ensure that new_srid is valid
	IF ( new_srid > 0 ) THEN
		IF ( SELECT count(*) = 0 from spatial_ref_sys where srid = new_srid ) THEN
			RAISE EXCEPTION 'invalid SRID: % not found in spatial_ref_sys', new_srid;
			RETURN false;
		END IF;
	ELSE
		unknown_srid := @extschema@.ST_SRID('POINT EMPTY'::@extschema@.geometry);
		IF ( new_srid != unknown_srid ) THEN
			new_srid := unknown_srid;
			RAISE NOTICE 'SRID value % converted to the officially unknown SRID value %', new_srid_in, new_srid;
		END IF;
	END IF;

	IF postgis_constraint_srid(real_schema, table_name, column_name) IS NOT NULL THEN
	-- srid was enforced with constraints before, keep it that way.
        -- Make up constraint name
        cname = 'enforce_srid_'  || column_name;

        -- Drop enforce_srid constraint
        EXECUTE 'ALTER TABLE ' || quote_ident(real_schema) ||
            '.' || quote_ident(table_name) ||
            ' DROP constraint ' || quote_ident(cname);

        -- Update geometries SRID
        EXECUTE 'UPDATE ' || quote_ident(real_schema) ||
            '.' || quote_ident(table_name) ||
            ' SET ' || quote_ident(column_name) ||
            ' = @extschema@.ST_SetSRID(' || quote_ident(column_name) ||
            ', ' || new_srid::text || ')';

        -- Reset enforce_srid constraint
        EXECUTE 'ALTER TABLE ' || quote_ident(real_schema) ||
            '.' || quote_ident(table_name) ||
            ' ADD constraint ' || quote_ident(cname) ||
            ' CHECK (st_srid(' || quote_ident(column_name) ||
            ') = ' || new_srid::text || ')';
    ELSE
        -- We will use typmod to enforce if no srid constraints
        -- We are using postgis_type_name to lookup the new name
        -- (in case Paul changes his mind and flips geometry_columns to return old upper case name)
        EXECUTE 'ALTER TABLE ' || quote_ident(real_schema) || '.' || quote_ident(table_name) ||
        ' ALTER COLUMN ' || quote_ident(column_name) || ' TYPE  geometry(' || @extschema@.postgis_type_name(myrec.type, myrec.coord_dimension, true) || ', ' || new_srid::text || ') USING @extschema@.ST_SetSRID(' || quote_ident(column_name) || ',' || new_srid::text || ');' ;
    END IF;

	RETURN real_schema || '.' || table_name || '.' || column_name ||' SRID changed to ' || new_srid::text;

END;
$$
LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION UpdateGeometrySRID(varchar,varchar,varchar,integer)
	RETURNS text
	AS $$
DECLARE
	ret  text;
BEGIN
	SELECT @extschema@.UpdateGeometrySRID('',$1,$2,$3,$4) into ret;
	RETURN ret;
END;
$$
LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION UpdateGeometrySRID(varchar,varchar,integer)
	RETURNS text
	AS $$
DECLARE
	ret  text;
BEGIN
	SELECT @extschema@.UpdateGeometrySRID('','',$1,$2,$3) into ret;
	RETURN ret;
END;
$$
LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION find_srid(varchar,varchar,varchar) RETURNS int4 AS
$$
DECLARE
	schem varchar =  $1;
	tabl varchar = $2;
	sr int4;
BEGIN
-- if the table contains a . and the schema is empty
-- split the table into a schema and a table
-- otherwise drop through to default behavior
	IF ( schem = '' and strpos(tabl,'.') > 0 ) THEN
	 schem = substr(tabl,1,strpos(tabl,'.')-1);
	 tabl = substr(tabl,length(schem)+2);
	END IF;

	select SRID into sr from @extschema@.geometry_columns where (f_table_schema = schem or schem = '') and f_table_name = tabl and f_geometry_column = $3;
	IF NOT FOUND THEN
	   RAISE EXCEPTION 'find_srid() - could not find the corresponding SRID - is the geometry registered in the GEOMETRY_COLUMNS table?  Is there an uppercase/lowercase mismatch?';
	END IF;
	return sr;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION get_proj4_from_srid(integer) RETURNS text AS
$$
BEGIN
	RETURN proj4text::text FROM @extschema@.spatial_ref_sys WHERE srid= $1;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_SetSRID(geometry,int4)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOM_set_srid'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1;
CREATE OR REPLACE FUNCTION ST_SRID(geometry)
	RETURNS int4
	AS '$libdir/postgis-2.5','LWGEOM_get_srid'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 5;
CREATE OR REPLACE FUNCTION postgis_transform_geometry(geometry,text,text,int)
	RETURNS geometry
	AS '$libdir/postgis-2.5','transform_geom'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Transform(geometry,integer)
	RETURNS geometry
	AS '$libdir/postgis-2.5','transform'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_Transform(geom geometry, to_proj text)
  RETURNS geometry AS
'SELECT @extschema@.postgis_transform_geometry($1, proj4text, $2, 0)
FROM spatial_ref_sys WHERE srid=@extschema@.ST_SRID($1);'
  LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Transform(geom geometry, from_proj text, to_proj text)
  RETURNS geometry AS
'SELECT @extschema@.postgis_transform_geometry($1, $2, $3, 0)'
  LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Transform(geom geometry, from_proj text, to_srid integer)
  RETURNS geometry AS
'SELECT @extschema@.postgis_transform_geometry($1, $2, proj4text, $3)
FROM spatial_ref_sys WHERE srid=$3;'
  LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION postgis_version() RETURNS text
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' IMMUTABLE;
CREATE OR REPLACE FUNCTION postgis_liblwgeom_version() RETURNS text
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' IMMUTABLE;
CREATE OR REPLACE FUNCTION postgis_proj_version() RETURNS text
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' IMMUTABLE;
CREATE OR REPLACE FUNCTION postgis_scripts_installed() RETURNS text
	AS $$ SELECT '2.5.4'::text || ' r' || 0::text AS version $$
	LANGUAGE 'sql' IMMUTABLE;
CREATE OR REPLACE FUNCTION postgis_lib_version() RETURNS text
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' IMMUTABLE; -- a new lib will require a new session
CREATE OR REPLACE FUNCTION postgis_scripts_released() RETURNS text
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' IMMUTABLE;
CREATE OR REPLACE FUNCTION postgis_geos_version() RETURNS text
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' IMMUTABLE;
CREATE OR REPLACE FUNCTION postgis_svn_version() RETURNS text
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' IMMUTABLE;
CREATE OR REPLACE FUNCTION postgis_libxml_version() RETURNS text
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' IMMUTABLE;
CREATE OR REPLACE FUNCTION postgis_scripts_build_date() RETURNS text
	AS 'SELECT ''2023-03-27 11:32:37''::text AS version'
	LANGUAGE 'sql' IMMUTABLE;
CREATE OR REPLACE FUNCTION postgis_lib_build_date() RETURNS text
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' IMMUTABLE;
CREATE OR REPLACE FUNCTION _postgis_scripts_pgsql_version() RETURNS text
	AS 'SELECT ''120''::text AS version'
	LANGUAGE 'sql' IMMUTABLE;
CREATE OR REPLACE FUNCTION _postgis_pgsql_version() RETURNS text
AS $$
	SELECT CASE WHEN split_part(s,'.',1)::integer > 9 THEN split_part(s,'.',1) || '0' ELSE split_part(s,'.', 1) || split_part(s,'.', 2) END AS v
	FROM substring(version(), 'PostgreSQL ([0-9\.]+)') AS s;
$$ LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION postgis_extensions_upgrade() RETURNS text
AS $$
DECLARE rec record; sql text;
BEGIN
	-- if at a version different from default version or we are at a dev version,
	-- then do an upgrade to default version

	FOR rec in SELECT  name, default_version, installed_version
		FROM pg_available_extensions
		WHERE installed_version > '' AND name IN('postgis', 'postgis_sfcgal', 'postgis_tiger_geocoder', 'postgis_topology')
		AND ( default_version <> installed_version  OR
			( default_version = installed_version AND default_version ILIKE '%dev%' AND  installed_version ILIKE '%dev%'  )  ) LOOP

		-- we need to upgrade to next so our installed is different from current
		-- and then we can upgrade to default_version
		IF rec.installed_version = rec.default_version THEN
			sql = 'ALTER EXTENSION ' || rec.name || ' UPDATE TO ' || quote_ident(rec.default_version || 'next')   || ';';
			EXECUTE sql;
			RAISE NOTICE '%', sql;
		END IF;

		sql = 'ALTER EXTENSION ' || rec.name || ' UPDATE TO ' || quote_ident(rec.default_version)   || ';';
		EXECUTE sql;
		RAISE NOTICE '%', sql;
	END LOOP;

	RETURN @extschema@.postgis_full_version();

END
$$ language plpgsql;

-- Changed: 2.4.0
CREATE OR REPLACE FUNCTION postgis_full_version() RETURNS text
AS $$
DECLARE
	libver text;
	svnver text;
	projver text;
	geosver text;
	sfcgalver text;
	cgalver text;
	gdalver text;
	libxmlver text;
	liblwgeomver text;
	dbproc text;
	relproc text;
	fullver text;
	rast_lib_ver text;
	rast_scr_ver text;
	topo_scr_ver text;
	json_lib_ver text;
	protobuf_lib_ver text;
	sfcgal_lib_ver text;
	sfcgal_scr_ver text;
	pgsql_scr_ver text;
	pgsql_ver text;
	core_is_extension bool;
BEGIN
	SELECT @extschema@.postgis_lib_version() INTO libver;
	SELECT @extschema@.postgis_proj_version() INTO projver;
	SELECT @extschema@.postgis_geos_version() INTO geosver;
	SELECT @extschema@.postgis_libjson_version() INTO json_lib_ver;
	SELECT @extschema@.postgis_libprotobuf_version() INTO protobuf_lib_ver;
	SELECT @extschema@._postgis_scripts_pgsql_version() INTO pgsql_scr_ver;
	SELECT @extschema@._postgis_pgsql_version() INTO pgsql_ver;
	BEGIN
		SELECT @extschema@.postgis_gdal_version() INTO gdalver;
	EXCEPTION
		WHEN undefined_function THEN
			gdalver := NULL;
			RAISE NOTICE 'Function postgis_gdal_version() not found.  Is raster support enabled and rtpostgis.sql installed?';
	END;
	BEGIN
		SELECT @extschema@.postgis_sfcgal_version() INTO sfcgalver;
    BEGIN
      SELECT @extschema@.postgis_sfcgal_scripts_installed() INTO sfcgal_scr_ver;
    EXCEPTION
      WHEN undefined_function THEN
        sfcgal_scr_ver := 'missing';
    END;
	EXCEPTION
		WHEN undefined_function THEN
			sfcgalver := NULL;
	END;
	SELECT @extschema@.postgis_liblwgeom_version() INTO liblwgeomver;
	SELECT @extschema@.postgis_libxml_version() INTO libxmlver;
	SELECT @extschema@.postgis_scripts_installed() INTO dbproc;
	SELECT @extschema@.postgis_scripts_released() INTO relproc;
	select @extschema@.postgis_svn_version() INTO svnver;
	BEGIN
		SELECT topology.postgis_topology_scripts_installed() INTO topo_scr_ver;
	EXCEPTION
		WHEN undefined_function OR invalid_schema_name THEN
			topo_scr_ver := NULL;
			RAISE DEBUG 'Function postgis_topology_scripts_installed() not found. Is topology support enabled and topology.sql installed?';
		WHEN insufficient_privilege THEN
			RAISE NOTICE 'Topology support cannot be inspected. Is current user granted USAGE on schema "topology" ?';
		WHEN OTHERS THEN
			RAISE NOTICE 'Function postgis_topology_scripts_installed() could not be called: % (%)', SQLERRM, SQLSTATE;
	END;

	BEGIN
		SELECT postgis_raster_scripts_installed() INTO rast_scr_ver;
	EXCEPTION
		WHEN undefined_function THEN
			rast_scr_ver := NULL;
			RAISE NOTICE 'Function postgis_raster_scripts_installed() not found. Is raster support enabled and rtpostgis.sql installed?';
	END;

	BEGIN
		SELECT @extschema@.postgis_raster_lib_version() INTO rast_lib_ver;
	EXCEPTION
		WHEN undefined_function THEN
			rast_lib_ver := NULL;
			RAISE NOTICE 'Function postgis_raster_lib_version() not found. Is raster support enabled and rtpostgis.sql installed?';
	END;

	fullver = 'POSTGIS="' || libver;

	IF  svnver IS NOT NULL THEN
		fullver = fullver || ' r' || svnver;
	END IF;

	fullver = fullver || '"';

	IF EXISTS (
		SELECT * FROM pg_catalog.pg_extension
		WHERE extname = 'postgis')
	THEN
			fullver = fullver || ' [EXTENSION]';
			core_is_extension := true;
	ELSE
			core_is_extension := false;
	END IF;

	IF liblwgeomver != relproc THEN
		fullver = fullver || ' (liblwgeom version mismatch: "' || liblwgeomver || '")';
	END IF;

	fullver = fullver || ' PGSQL="' || pgsql_scr_ver || '"';
	IF pgsql_scr_ver != pgsql_ver THEN
		fullver = fullver || ' (procs need upgrade for use with "' || pgsql_ver || '")';
	END IF;

	IF  geosver IS NOT NULL THEN
		fullver = fullver || ' GEOS="' || geosver || '"';
	END IF;

	IF  sfcgalver IS NOT NULL THEN
		fullver = fullver || ' SFCGAL="' || sfcgalver || '"';
	END IF;

	IF  projver IS NOT NULL THEN
		fullver = fullver || ' PROJ="' || projver || '"';
	END IF;

	IF  gdalver IS NOT NULL THEN
		fullver = fullver || ' GDAL="' || gdalver || '"';
	END IF;

	IF  libxmlver IS NOT NULL THEN
		fullver = fullver || ' LIBXML="' || libxmlver || '"';
	END IF;

	IF json_lib_ver IS NOT NULL THEN
		fullver = fullver || ' LIBJSON="' || json_lib_ver || '"';
	END IF;

	IF protobuf_lib_ver IS NOT NULL THEN
		fullver = fullver || ' LIBPROTOBUF="' || protobuf_lib_ver || '"';
	END IF;

	IF dbproc != relproc THEN
		fullver = fullver || ' (core procs from "' || dbproc || '" need upgrade)';
	END IF;

	IF topo_scr_ver IS NOT NULL THEN
		fullver = fullver || ' TOPOLOGY';
		IF topo_scr_ver != relproc THEN
			fullver = fullver || ' (topology procs from "' || topo_scr_ver || '" need upgrade)';
		END IF;
		IF core_is_extension AND NOT EXISTS (
			SELECT * FROM pg_catalog.pg_extension
			WHERE extname = 'postgis_topology')
		THEN
				fullver = fullver || ' [UNPACKAGED!]';
		END IF;
	END IF;

	IF rast_lib_ver IS NOT NULL THEN
		fullver = fullver || ' RASTER';
		IF rast_lib_ver != relproc THEN
			fullver = fullver || ' (raster lib from "' || rast_lib_ver || '" need upgrade)';
		END IF;
	END IF;

	IF rast_scr_ver IS NOT NULL AND rast_scr_ver != relproc THEN
		fullver = fullver || ' (raster procs from "' || rast_scr_ver || '" need upgrade)';
	END IF;

	IF sfcgal_scr_ver IS NOT NULL AND sfcgal_scr_ver != relproc THEN
    fullver = fullver || ' (sfcgal procs from "' || sfcgal_scr_ver || '" need upgrade)';
	END IF;

	RETURN fullver;
END
$$
LANGUAGE 'plpgsql' IMMUTABLE;
CREATE OR REPLACE FUNCTION box2d(geometry)
	RETURNS box2d
	AS '$libdir/postgis-2.5','LWGEOM_to_BOX2D'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION box3d(geometry)
	RETURNS box3d
	AS '$libdir/postgis-2.5','LWGEOM_to_BOX3D'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION box(geometry)
	RETURNS box
	AS '$libdir/postgis-2.5','LWGEOM_to_BOX'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION box2d(box3d)
	RETURNS box2d
	AS '$libdir/postgis-2.5','BOX3D_to_BOX2D'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION box3d(box2d)
	RETURNS box3d
	AS '$libdir/postgis-2.5','BOX2D_to_BOX3D'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION box(box3d)
	RETURNS box
	AS '$libdir/postgis-2.5','BOX3D_to_BOX'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION text(geometry)
	RETURNS text
	AS '$libdir/postgis-2.5','LWGEOM_to_text'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 25;
CREATE OR REPLACE FUNCTION box3dtobox(box3d)
	RETURNS box
	AS '$libdir/postgis-2.5','BOX3D_to_BOX'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry(box2d)
	RETURNS geometry
	AS '$libdir/postgis-2.5','BOX2D_to_LWGEOM'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry(box3d)
	RETURNS geometry
	AS '$libdir/postgis-2.5','BOX3D_to_LWGEOM'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry(text)
	RETURNS geometry
	AS '$libdir/postgis-2.5','parse_WKT_lwgeom'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry(bytea)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOM_from_bytea'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION bytea(geometry)
	RETURNS bytea
	AS '$libdir/postgis-2.5','LWGEOM_to_bytea'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (geometry AS box2d)');
DROP CAST IF EXISTS (geometry AS box2d);
CREATE CAST (geometry AS box2d) WITH FUNCTION box2d(geometry) AS IMPLICIT;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (geometry AS box3d)');
DROP CAST IF EXISTS (geometry AS box3d);
CREATE CAST (geometry AS box3d) WITH FUNCTION box3d(geometry) AS IMPLICIT;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (geometry AS box)');
DROP CAST IF EXISTS (geometry AS box);
CREATE CAST (geometry AS box) WITH FUNCTION box(geometry) AS ASSIGNMENT;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (box3d AS box2d)');
DROP CAST IF EXISTS (box3d AS box2d);
CREATE CAST (box3d AS box2d) WITH FUNCTION box2d(box3d) AS IMPLICIT;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (box2d AS box3d)');
DROP CAST IF EXISTS (box2d AS box3d);
CREATE CAST (box2d AS box3d) WITH FUNCTION box3d(box2d) AS IMPLICIT;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (box2d AS geometry)');
DROP CAST IF EXISTS (box2d AS geometry);
CREATE CAST (box2d AS geometry) WITH FUNCTION geometry(box2d) AS IMPLICIT;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (box3d AS box)');
DROP CAST IF EXISTS (box3d AS box);
CREATE CAST (box3d AS box) WITH FUNCTION box(box3d) AS IMPLICIT;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (box3d AS geometry)');
DROP CAST IF EXISTS (box3d AS geometry);
CREATE CAST (box3d AS geometry) WITH FUNCTION geometry(box3d) AS IMPLICIT;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (text AS geometry)');
DROP CAST IF EXISTS (text AS geometry);
CREATE CAST (text AS geometry) WITH FUNCTION geometry(text) AS IMPLICIT;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (geometry AS text)');
DROP CAST IF EXISTS (geometry AS text);
CREATE CAST (geometry AS text) WITH FUNCTION text(geometry) AS IMPLICIT;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (bytea AS geometry)');
DROP CAST IF EXISTS (bytea AS geometry);
CREATE CAST (bytea AS geometry) WITH FUNCTION geometry(bytea) AS IMPLICIT;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (geometry AS bytea)');
DROP CAST IF EXISTS (geometry AS bytea);
CREATE CAST (geometry AS bytea) WITH FUNCTION bytea(geometry) AS IMPLICIT;
CREATE OR REPLACE FUNCTION ST_Simplify(geometry, float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_simplify2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_Simplify(geometry, float8, boolean)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_simplify2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_SimplifyVW(geometry,  float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_SetEffectiveArea'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_SetEffectiveArea(geometry,  float8 default -1, integer default 1)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_SetEffectiveArea'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_FilterByM(geometry, double precision, double precision default null, boolean default false)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_FilterByM'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_ChaikinSmoothing(geometry, integer default 1, boolean default false)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_ChaikinSmoothing'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_SnapToGrid(geometry, float8, float8, float8, float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_snaptogrid'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_SnapToGrid(geometry, float8, float8)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_SnapToGrid($1, 0, 0, $2, $3)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_SnapToGrid(geometry, float8)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_SnapToGrid($1, 0, 0, $2, $2)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_SnapToGrid(geom1 geometry, geom2 geometry, float8, float8, float8, float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_snaptogrid_pointoff'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_Segmentize(geometry, float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_segmentize2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_LineInterpolatePoint(geometry, float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_line_interpolate_point'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LineInterpolatePoints(geometry, float8, repeat boolean DEFAULT true)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_line_interpolate_point'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_line_interpolate_point(geometry, float8)
	RETURNS geometry AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Line_Interpolate_Point', 'ST_LineInterpolatePoint', '2.1.0');
    SELECT @extschema@.ST_LineInterpolatePoint($1, $2);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LineSubstring(geometry, float8, float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_line_substring'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_line_substring(geometry, float8, float8)
	RETURNS geometry AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Line_Substring', 'ST_LineSubstring', '2.1.0');
     SELECT @extschema@.ST_LineSubstring($1, $2, $3);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LineLocatePoint(geom1 geometry, geom2 geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'LWGEOM_line_locate_point'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_line_locate_point(geom1 geometry, geom2 geometry)
	RETURNS float8 AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Line_Locate_Point', 'ST_LineLocatePoint', '2.1.0');
     SELECT @extschema@.ST_LineLocatePoint($1, $2);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_locate_between_measures(geometry, float8, float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_locate_between_m'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_locate_along_measure(geometry, float8)
	RETURNS geometry
	AS $$ SELECT @extschema@.ST_locate_between_measures($1, $2, $2) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AddMeasure(geometry, float8, float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_AddMeasure'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_ClosestPointOfApproach(geometry, geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'ST_ClosestPointOfApproach'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_DistanceCPA(geometry, geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'ST_DistanceCPA'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_CPAWithin(geometry, geometry, float8)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'ST_CPAWithin'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_IsValidTrajectory(geometry)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'ST_IsValidTrajectory'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Intersection(geom1 geometry, geom2 geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5','intersection'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_Buffer(geometry,float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5','buffer'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION _ST_Buffer(geometry,float8,cstring)
	RETURNS geometry
	AS '$libdir/postgis-2.5','buffer'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_Buffer(geometry,float8,integer)
	RETURNS geometry
	AS $$ SELECT @extschema@._ST_Buffer($1, $2,
		CAST('quad_segs='||CAST($3 AS text) as cstring))
	   $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Buffer(geometry,float8,text)
	RETURNS geometry
	AS $$ SELECT @extschema@._ST_Buffer($1, $2,
		CAST( regexp_replace($3, '^[0123456789]+$',
			'quad_segs='||$3) AS cstring)
		)
	   $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MinimumBoundingRadius(geometry, OUT center geometry, OUT radius double precision)
    AS '$libdir/postgis-2.5', 'ST_MinimumBoundingRadius'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MinimumBoundingCircle(inputgeom geometry, segs_per_quarter integer DEFAULT 48)
    RETURNS geometry
    AS '$libdir/postgis-2.5', 'ST_MinimumBoundingCircle'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_OrientedEnvelope(geometry)
    RETURNS geometry
    AS '$libdir/postgis-2.5', 'ST_OrientedEnvelope'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_OffsetCurve(line geometry, distance float8, params text DEFAULT '')
       RETURNS geometry
       AS '$libdir/postgis-2.5','ST_OffsetCurve'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_GeneratePoints(area geometry, npoints numeric)
       RETURNS geometry
       AS '$libdir/postgis-2.5','ST_GeneratePoints'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_ConvexHull(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5','convexhull'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION _ST_LineCrossingDirection(geom1 geometry, geom2 geometry)
	RETURNS integer
	AS '$libdir/postgis-2.5', 'ST_LineCrossingDirection'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100; -- Guessed cost
CREATE OR REPLACE FUNCTION ST_LineCrossingDirection(geom1 geometry, geom2 geometry)
	RETURNS integer AS
	$$ SELECT CASE WHEN NOT $1 OPERATOR(@extschema@.&&) $2 THEN 0 ELSE @extschema@._ST_LineCrossingDirection($1,$2) END $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_SimplifyPreserveTopology(geometry, float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5','topologypreservesimplify'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_IsValidReason(geometry)
	RETURNS text
	AS '$libdir/postgis-2.5', 'isvalidreason'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1000;
-- Type valid_detail -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE valid_detail AS (
	valid bool,
	reason varchar,
	location geometry
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION ST_IsValidDetail(geometry)
	RETURNS valid_detail
	AS '$libdir/postgis-2.5', 'isvaliddetail'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION ST_IsValidDetail(geometry, int4)
	RETURNS valid_detail
	AS '$libdir/postgis-2.5', 'isvaliddetail'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION ST_IsValidReason(geometry, int4)
	RETURNS text
	AS $$
SELECT CASE WHEN valid THEN 'Valid Geometry' ELSE reason END FROM (
	SELECT (@extschema@.ST_isValidDetail($1, $2)).*
) foo
	$$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION ST_IsValid(geometry, int4)
	RETURNS boolean
	AS 'SELECT (@extschema@.ST_isValidDetail($1, $2)).valid'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_HausdorffDistance(geom1 geometry, geom2 geometry)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5', 'hausdorffdistance'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100; -- Guessed cost
CREATE OR REPLACE FUNCTION ST_HausdorffDistance(geom1 geometry, geom2 geometry, float8)
	RETURNS FLOAT8
	AS '$libdir/postgis-2.5', 'hausdorffdistancedensify'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100; -- Guessed cost
CREATE OR REPLACE FUNCTION ST_FrechetDistance(geom1 geometry, geom2 geometry, float8 default -1)
       RETURNS FLOAT8
       AS '$libdir/postgis-2.5', 'ST_FrechetDistance'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100; -- Guessed cost
CREATE OR REPLACE FUNCTION ST_Difference(geom1 geometry, geom2 geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5','difference'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100; --guessed based on ST_Intersection
CREATE OR REPLACE FUNCTION ST_Boundary(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5','boundary'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Points(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_Points'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_SymDifference(geom1 geometry, geom2 geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5','symdifference'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_symmetricdifference(geom1 geometry, geom2 geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5','symdifference'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Union(geom1 geometry, geom2 geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5','geomunion'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_UnaryUnion(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5','ST_UnaryUnion'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_RemoveRepeatedPoints(geom geometry, tolerance float8 default 0.0)
       RETURNS geometry
       AS '$libdir/postgis-2.5', 'ST_RemoveRepeatedPoints'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_MakeValid(geometry)
       RETURNS geometry
       AS '$libdir/postgis-2.5', 'ST_MakeValid'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_CleanGeometry(geometry)
       RETURNS geometry
       AS '$libdir/postgis-2.5', 'ST_CleanGeometry'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_Split(geom1 geometry, geom2 geometry)
       RETURNS geometry
       AS '$libdir/postgis-2.5', 'ST_Split'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_SharedPaths(geom1 geometry, geom2 geometry)
       RETURNS geometry
       AS '$libdir/postgis-2.5', 'ST_SharedPaths'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_Snap(geom1 geometry, geom2 geometry, float8)
       RETURNS geometry
       AS '$libdir/postgis-2.5', 'ST_Snap'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_RelateMatch(text, text)
       RETURNS bool
       AS '$libdir/postgis-2.5', 'ST_RelateMatch'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 100; -- Guessed cost
CREATE OR REPLACE FUNCTION ST_Node(g geometry)
       RETURNS geometry
       AS '$libdir/postgis-2.5', 'ST_Node'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_DelaunayTriangles(g1 geometry, tolerance float8 DEFAULT 0.0, flags int4 DEFAULT 0)
       RETURNS geometry
       AS '$libdir/postgis-2.5', 'ST_DelaunayTriangles'
       LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
       COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_CombineBBox(box3d,geometry)
	RETURNS box3d
	AS '$libdir/postgis-2.5', 'BOX3D_combine'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_CombineBBox(box3d,box3d)
	RETURNS box3d
	AS '$libdir/postgis-2.5', 'BOX3D_combine_BOX3D'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Combine_BBox(box3d,geometry)
	RETURNS box3d AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Combine_BBox', 'ST_CombineBbox', '2.2.0');
    SELECT @extschema@.ST_CombineBbox($1,$2);
  $$
	LANGUAGE 'sql' IMMUTABLE;
CREATE OR REPLACE FUNCTION ST_CombineBbox(box2d,geometry)
	RETURNS box2d
	AS '$libdir/postgis-2.5', 'BOX2D_combine'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Combine_BBox(box2d,geometry)
	RETURNS box2d AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Combine_BBox', 'ST_CombineBbox', '2.2.0');
    SELECT @extschema@.ST_CombineBbox($1,$2);
  $$
	LANGUAGE 'sql' IMMUTABLE;
-- Aggregate ST_Extent(geometry) -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num OR (
      203 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_Extent(geometry)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_Extent(geometry) (
	sfunc = ST_CombineBBox,
	stype = box3d,

	combinefunc = ST_CombineBBox,
	parallel = safe,

	finalfunc = box2d
	);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Aggregate ST_3DExtent(geometry) -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num OR (
      203 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_3DExtent(geometry)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_3DExtent(geometry)(
	sfunc = ST_CombineBBox,

	combinefunc = ST_CombineBBox,
	parallel = safe,

	stype = box3d
	);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION ST_Collect(geom1 geometry, geom2 geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_collect'
	LANGUAGE 'c' IMMUTABLE  PARALLEL SAFE;
-- Aggregate ST_MemCollect(geometry) -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num OR (
      203 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_MemCollect(geometry)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_MemCollect(geometry)(
	sfunc = ST_collect,

	combinefunc = ST_collect,
	parallel = safe,

	stype = geometry
	);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION ST_Collect(geometry[])
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_collect_garray'
	LANGUAGE 'c' IMMUTABLE STRICT  PARALLEL SAFE;
-- Aggregate ST_MemUnion(geometry) -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num OR (
      203 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_MemUnion(geometry)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_MemUnion(geometry) (
	sfunc = ST_Union,

	combinefunc = ST_Union,
	parallel = safe,

	stype = geometry
	);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION pgis_geometry_accum_transfn(internal, geometry)
	RETURNS internal
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_geometry_accum_transfn(internal, geometry, float8)
	RETURNS internal
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_geometry_accum_transfn(internal, geometry, float8, int)
	RETURNS internal
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_geometry_accum_finalfn(internal)
	RETURNS geometry[]
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_geometry_union_finalfn(internal)
	RETURNS geometry
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_geometry_collect_finalfn(internal)
	RETURNS geometry
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_geometry_polygonize_finalfn(internal)
	RETURNS geometry
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_geometry_clusterintersecting_finalfn(internal)
	RETURNS geometry[]
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_geometry_clusterwithin_finalfn(internal)
	RETURNS geometry[]
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_geometry_makeline_finalfn(internal)
	RETURNS geometry
	AS '$libdir/postgis-2.5'
	LANGUAGE 'c' PARALLEL SAFE;
-- Aggregate ST_Accum (geometry) -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num OR (
      205 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_Accum (geometry)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_Accum (geometry) (
	sfunc = pgis_geometry_accum_transfn,
	stype = internal,

	parallel = safe,

	finalfunc = pgis_geometry_accum_finalfn
	);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION ST_Union (geometry[])
	RETURNS geometry
	AS '$libdir/postgis-2.5','pgis_union_geometry_array'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Aggregate ST_Union (geometry) -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num OR (
      205 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_Union (geometry)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_Union (geometry) (
	sfunc = pgis_geometry_accum_transfn,
	stype = internal,

	parallel = safe,

	finalfunc = pgis_geometry_union_finalfn
	);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Aggregate ST_Collect (geometry) -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num OR (
      205 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_Collect (geometry)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_Collect (geometry) (
	SFUNC = pgis_geometry_accum_transfn,
	STYPE = internal,

	parallel = safe,

	FINALFUNC = pgis_geometry_collect_finalfn
	);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Aggregate ST_ClusterIntersecting (geometry) -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num OR (
      205 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_ClusterIntersecting (geometry)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_ClusterIntersecting (geometry) (
	SFUNC = pgis_geometry_accum_transfn,
	STYPE = internal,

	parallel = safe,

	FINALFUNC = pgis_geometry_clusterintersecting_finalfn
	);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Aggregate ST_ClusterWithin (geometry,float8) -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num OR (
      205 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_ClusterWithin (geometry,float8)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_ClusterWithin (geometry, float8) (
	SFUNC = pgis_geometry_accum_transfn,
	STYPE = internal,

	parallel = safe,

	FINALFUNC = pgis_geometry_clusterwithin_finalfn
	);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Aggregate ST_Polygonize (geometry) -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num OR (
      205 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_Polygonize (geometry)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_Polygonize (geometry) (
	SFUNC = pgis_geometry_accum_transfn,
	STYPE = internal,

	parallel = safe,

	FINALFUNC = pgis_geometry_polygonize_finalfn
	);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Aggregate ST_MakeLine (geometry) -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num OR (
      205 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_MakeLine (geometry)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_MakeLine (geometry) (
	SFUNC = pgis_geometry_accum_transfn,
	STYPE = internal,

	parallel = safe,

	FINALFUNC = pgis_geometry_makeline_finalfn
	);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION ST_ClusterKMeans(geom geometry, k integer)
  RETURNS integer
  AS '$libdir/postgis-2.5', 'ST_ClusterKMeans'
  LANGUAGE 'c' VOLATILE STRICT WINDOW;
CREATE OR REPLACE FUNCTION ST_Relate(geom1 geometry, geom2 geometry)
	RETURNS text
	AS '$libdir/postgis-2.5','relate_full'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Relate(geom1 geometry, geom2 geometry, int4)
	RETURNS text
	AS '$libdir/postgis-2.5','relate_full'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Relate(geom1 geometry, geom2 geometry,text)
	RETURNS boolean
	AS '$libdir/postgis-2.5','relate_pattern'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Disjoint(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5','disjoint'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_Touches(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5','touches'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100; -- Guessed cost
CREATE OR REPLACE FUNCTION ST_Touches(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.&&) $2 AND @extschema@._ST_Touches($1,$2)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_DWithin(geom1 geometry, geom2 geometry,float8)
	RETURNS boolean
	AS '$libdir/postgis-2.5', 'LWGEOM_dwithin'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100; -- Guessed cost
CREATE OR REPLACE FUNCTION ST_DWithin(geom1 geometry, geom2 geometry, float8)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.&&) @extschema@.ST_Expand($2,$3) AND $2 OPERATOR(@extschema@.&&) @extschema@.ST_Expand($1,$3) AND @extschema@._ST_DWithin($1, $2, $3)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_Intersects(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5','intersects'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100; -- Guessed cost
CREATE OR REPLACE FUNCTION ST_Intersects(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.&&) $2 AND @extschema@._ST_Intersects($1,$2)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_Crosses(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5','crosses'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100; -- Guessed cost
CREATE OR REPLACE FUNCTION ST_Crosses(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.&&) $2 AND @extschema@._ST_Crosses($1,$2)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_Contains(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5','contains'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100; -- Guessed cost
CREATE OR REPLACE FUNCTION ST_Contains(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.~) $2 AND @extschema@._ST_Contains($1,$2)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_CoveredBy(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5', 'coveredby'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100; -- Guessed cost
CREATE OR REPLACE FUNCTION ST_CoveredBy(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.@) $2 AND @extschema@._ST_CoveredBy($1,$2)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_Covers(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5', 'covers'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100; -- Guessed cost
CREATE OR REPLACE FUNCTION ST_Covers(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.~) $2 AND @extschema@._ST_Covers($1,$2)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_ContainsProperly(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5','containsproperly'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100; -- Guessed cost
CREATE OR REPLACE FUNCTION ST_ContainsProperly(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.~) $2 AND @extschema@._ST_ContainsProperly($1,$2)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_Overlaps(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5','overlaps'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100; -- Guessed cost
CREATE OR REPLACE FUNCTION _ST_Within(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS 'SELECT @extschema@._ST_Contains($2,$1)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Within(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS 'SELECT $2 OPERATOR(@extschema@.~) $1 AND @extschema@._ST_Contains($2,$1)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Overlaps(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.&&) $2 AND @extschema@._ST_Overlaps($1,$2)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_IsValid(geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5', 'isvalid'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION ST_MinimumClearance(geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'ST_MinimumClearance'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MinimumClearanceLine(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_MinimumClearanceLine'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Centroid(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'centroid'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_GeometricMedian(g geometry, tolerance float8 DEFAULT NULL, max_iter int DEFAULT 10000, fail_if_not_converged boolean DEFAULT false)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_GeometricMedian'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_IsRing(geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5', 'isring'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_PointOnSurface(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'pointonsurface'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_IsSimple(geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5', 'issimple'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 25;
CREATE OR REPLACE FUNCTION ST_IsCollection(geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5', 'ST_IsCollection'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 5;
CREATE OR REPLACE FUNCTION _ST_Equals(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5','ST_Equals'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100; --Guessed cost
CREATE OR REPLACE FUNCTION ST_Equals(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.~=) $2 AND @extschema@._ST_Equals($1,$2)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION Equals(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5','ST_Equals'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_GeomFromGML(text, int4)
        RETURNS geometry
        AS '$libdir/postgis-2.5','geom_from_gml'
        LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomFromGML(text, int4)
        RETURNS geometry
        AS '$libdir/postgis-2.5','geom_from_gml'
        LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomFromGML(text)
        RETURNS geometry
        AS 'SELECT @extschema@._ST_GeomFromGML($1, 0)'
        LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GMLToSQL(text)
        RETURNS geometry
        AS 'SELECT @extschema@._ST_GeomFromGML($1, 0)'
        LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GMLToSQL(text, int4)
        RETURNS geometry
        AS '$libdir/postgis-2.5','geom_from_gml'
        LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomFromKML(text)
	RETURNS geometry
	AS '$libdir/postgis-2.5','geom_from_kml'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomFromGeoJson(text)
	RETURNS geometry
	AS '$libdir/postgis-2.5','geom_from_geojson'
	LANGUAGE 'c' IMMUTABLE STRICT  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomFromGeoJson(json)
        RETURNS geometry
        AS 'SELECT @extschema@.ST_GeomFromGeoJson($1::text)'
        LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomFromGeoJson(jsonb)
        RETURNS geometry
        AS 'SELECT @extschema@.ST_GeomFromGeoJson($1::text)'
        LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION postgis_libjson_version()
	RETURNS text
	AS '$libdir/postgis-2.5','postgis_libjson_version'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LineFromEncodedPolyline(text, int4 DEFAULT 5)
	RETURNS geometry
	AS '$libdir/postgis-2.5','line_from_encoded_polyline'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsEncodedPolyline(geom geometry, int4 DEFAULT 5)
	RETURNS TEXT
	AS '$libdir/postgis-2.5','LWGEOM_asEncodedPolyline'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsSVG(geom geometry,rel int4 DEFAULT 0,maxdecimaldigits int4 DEFAULT 15)
	RETURNS TEXT
	AS '$libdir/postgis-2.5','LWGEOM_asSVG'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION _ST_AsGML(int4, geometry, int4, int4, text, text)
	RETURNS TEXT
	AS '$libdir/postgis-2.5','LWGEOM_asGML'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE
	COST 2500;
CREATE OR REPLACE FUNCTION ST_AsGML(geom geometry, maxdecimaldigits int4 DEFAULT 15, options int4 DEFAULT 0)
	RETURNS TEXT
	AS $$ SELECT @extschema@._ST_AsGML(2, $1, $2, $3, null, null); $$
	LANGUAGE 'sql' IMMUTABLE STRICT  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsGML(version int4, geom geometry, maxdecimaldigits int4 DEFAULT 15, options int4 DEFAULT 0, nprefix text DEFAULT null, id text DEFAULT null)
	RETURNS TEXT
	AS $$ SELECT @extschema@._ST_AsGML($1, $2, $3, $4, $5, $6); $$
	LANGUAGE 'sql' IMMUTABLE  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_AsKML(int4,geometry, int4, text)
	RETURNS TEXT
	AS '$libdir/postgis-2.5','LWGEOM_asKML'
	LANGUAGE 'c' IMMUTABLE  PARALLEL SAFE
	COST 5000;
CREATE OR REPLACE FUNCTION ST_AsKML(geom geometry, maxdecimaldigits int4 DEFAULT 15)
	RETURNS TEXT
	AS $$ SELECT @extschema@._ST_AsKML(2, ST_Transform($1,4326), $2, null); $$
	LANGUAGE 'sql' IMMUTABLE STRICT  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsKML(version int4, geom geometry, maxdecimaldigits int4 DEFAULT 15, nprefix text DEFAULT null)
	RETURNS TEXT
	AS $$ SELECT @extschema@._ST_AsKML($1, @extschema@.ST_Transform($2,4326), $3, $4); $$
	LANGUAGE 'sql' IMMUTABLE  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsGeoJson(geom geometry, maxdecimaldigits int4 DEFAULT 15, options int4 DEFAULT 0)
	RETURNS TEXT
	AS '$libdir/postgis-2.5','LWGEOM_asGeoJson'
	LANGUAGE 'c' IMMUTABLE STRICT  PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION _ST_AsGeoJson(int4, geometry, int4, int4)
	RETURNS TEXT
	AS $$ SELECT @extschema@.ST_AsGeoJson($2::@extschema@.geometry, $3::int4, $4::int4); $$
	LANGUAGE 'sql' IMMUTABLE STRICT  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsGeoJson(gj_version int4, geom geometry, maxdecimaldigits int4 DEFAULT 15, options int4 DEFAULT 0)
	RETURNS TEXT
	AS $$ SELECT @extschema@.ST_AsGeoJson($2::@extschema@.geometry, $3::int4, $4::int4); $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_asmvt_transfn(internal, anyelement)
	RETURNS internal
	AS '$libdir/postgis-2.5', 'pgis_asmvt_transfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_asmvt_transfn(internal, anyelement, text)
	RETURNS internal
	AS '$libdir/postgis-2.5', 'pgis_asmvt_transfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_asmvt_transfn(internal, anyelement, text, int4)
	RETURNS internal
	AS '$libdir/postgis-2.5', 'pgis_asmvt_transfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_asmvt_transfn(internal, anyelement, text, int4, text)
	RETURNS internal
	AS '$libdir/postgis-2.5', 'pgis_asmvt_transfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_asmvt_finalfn(internal)
	RETURNS bytea
	AS '$libdir/postgis-2.5', 'pgis_asmvt_finalfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_asmvt_combinefn(internal, internal)
	RETURNS internal
	AS '$libdir/postgis-2.5', 'pgis_asmvt_combinefn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_asmvt_serialfn(internal)
	RETURNS bytea
	AS '$libdir/postgis-2.5', 'pgis_asmvt_serialfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_asmvt_deserialfn(bytea, internal)
	RETURNS internal
	AS '$libdir/postgis-2.5', 'pgis_asmvt_deserialfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
-- Aggregate ST_AsMVT(anyelement) -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num OR (
      205 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_AsMVT(anyelement)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_AsMVT(anyelement)
(
	sfunc = pgis_asmvt_transfn,
	stype = internal,

	parallel = safe,
	serialfunc = pgis_asmvt_serialfn,
	deserialfunc = pgis_asmvt_deserialfn,
	combinefunc = pgis_asmvt_combinefn,

	finalfunc = pgis_asmvt_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Aggregate ST_AsMVT(anyelement,text) -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num OR (
      205 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_AsMVT(anyelement,text)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_AsMVT(anyelement, text)
(
	sfunc = pgis_asmvt_transfn,
	stype = internal,

	parallel = safe,
	serialfunc = pgis_asmvt_serialfn,
	deserialfunc = pgis_asmvt_deserialfn,
	combinefunc = pgis_asmvt_combinefn,

	finalfunc = pgis_asmvt_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Aggregate ST_AsMVT(anyelement,text,int4) -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num OR (
      205 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_AsMVT(anyelement,text,int4)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_AsMVT(anyelement, text, int4)
(
	sfunc = pgis_asmvt_transfn,
	stype = internal,

	parallel = safe,
	serialfunc = pgis_asmvt_serialfn,
	deserialfunc = pgis_asmvt_deserialfn,
	combinefunc = pgis_asmvt_combinefn,

	finalfunc = pgis_asmvt_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Aggregate ST_AsMVT(anyelement,text,int4,text) -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num OR (
      205 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_AsMVT(anyelement,text,int4,text)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_AsMVT(anyelement, text, int4, text)
(
	sfunc = pgis_asmvt_transfn,
	stype = internal,

	parallel = safe,
	serialfunc = pgis_asmvt_serialfn,
	deserialfunc = pgis_asmvt_deserialfn,
	combinefunc = pgis_asmvt_combinefn,

	finalfunc = pgis_asmvt_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION ST_AsMVTGeom(geom geometry, bounds box2d, extent int4 default 4096, buffer int4 default 256, clip_geom bool default true)
	RETURNS geometry
	AS '$libdir/postgis-2.5','ST_AsMVTGeom'
	LANGUAGE 'c' IMMUTABLE  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION postgis_libprotobuf_version()
	RETURNS text
	AS '$libdir/postgis-2.5','postgis_libprotobuf_version'
	LANGUAGE 'c' IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION pgis_asgeobuf_transfn(internal, anyelement)
	RETURNS internal
	AS '$libdir/postgis-2.5', 'pgis_asgeobuf_transfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_asgeobuf_transfn(internal, anyelement, text)
	RETURNS internal
	AS '$libdir/postgis-2.5', 'pgis_asgeobuf_transfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION pgis_asgeobuf_finalfn(internal)
	RETURNS bytea
	AS '$libdir/postgis-2.5', 'pgis_asgeobuf_finalfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
-- Aggregate ST_AsGeobuf(anyelement) -- LastUpdated: 204
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 204 > version_from_num OR (
      204 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_AsGeobuf(anyelement)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_AsGeobuf(anyelement)
(
	sfunc = pgis_asgeobuf_transfn,
	stype = internal,

	parallel = safe,

	finalfunc = pgis_asgeobuf_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Aggregate ST_AsGeobuf(anyelement,text) -- LastUpdated: 204
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 204 > version_from_num OR (
      204 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS ST_AsGeobuf(anyelement,text)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE ORDERED AGGREGATE ST_AsGeobuf(anyelement, text)
(
	sfunc = pgis_asgeobuf_transfn,
	stype = internal,

	parallel = safe,

	finalfunc = pgis_asgeobuf_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION ST_GeoHash(geom geometry, maxchars int4 DEFAULT 0)
	RETURNS TEXT
		AS '$libdir/postgis-2.5', 'ST_GeoHash'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Box2dFromGeoHash(text, int4 DEFAULT NULL)
	RETURNS box2d
	AS '$libdir/postgis-2.5','box2d_from_geohash'
	LANGUAGE 'c' IMMUTABLE  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_PointFromGeoHash(text, int4 DEFAULT NULL)
	RETURNS geometry
	AS '$libdir/postgis-2.5','point_from_geohash'
	LANGUAGE 'c' IMMUTABLE  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomFromGeoHash(text, int4 DEFAULT NULL)
	RETURNS geometry
	AS $$ SELECT CAST(@extschema@.ST_Box2dFromGeoHash($1, $2) AS geometry); $$
	LANGUAGE 'sql' IMMUTABLE  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_NumPoints(geometry)
	RETURNS int4
	AS '$libdir/postgis-2.5', 'LWGEOM_numpoints_linestring'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_NumGeometries(geometry)
	RETURNS int4
	AS '$libdir/postgis-2.5', 'LWGEOM_numgeometries_collection'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeometryN(geometry,integer)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_geometryn_collection'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Dimension(geometry)
	RETURNS int4
	AS '$libdir/postgis-2.5', 'LWGEOM_dimension'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_ExteriorRing(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOM_exteriorring_polygon'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_NumInteriorRings(geometry)
	RETURNS integer
	AS '$libdir/postgis-2.5','LWGEOM_numinteriorrings_polygon'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_NumInteriorRing(geometry)
	RETURNS integer
	AS '$libdir/postgis-2.5','LWGEOM_numinteriorrings_polygon'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_InteriorRingN(geometry,integer)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOM_interiorringn_polygon'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION GeometryType(geometry)
	RETURNS text
	AS '$libdir/postgis-2.5', 'LWGEOM_getTYPE'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10; -- COST guessed from ST_GeometryType(geometry)
CREATE OR REPLACE FUNCTION ST_GeometryType(geometry)
	RETURNS text
	AS '$libdir/postgis-2.5', 'geometry_geometrytype'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_PointN(geometry,integer)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOM_pointn_linestring'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_NumPatches(geometry)
	RETURNS int4
	AS '
	SELECT CASE WHEN @extschema@.ST_GeometryType($1) = ''ST_PolyhedralSurface''
	THEN @extschema@.ST_NumGeometries($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_PatchN(geometry, integer)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.ST_GeometryType($1) = ''ST_PolyhedralSurface''
	THEN @extschema@.ST_GeometryN($1, $2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_StartPoint(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_startpoint_linestring'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_EndPoint(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_endpoint_linestring'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_IsClosed(geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5', 'LWGEOM_isclosed'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_IsEmpty(geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5', 'LWGEOM_isempty'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_AsBinary(geometry,text)
	RETURNS bytea
	AS '$libdir/postgis-2.5','LWGEOM_asBinary'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_AsBinary(geometry)
	RETURNS bytea
	AS '$libdir/postgis-2.5','LWGEOM_asBinary'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 10;
CREATE OR REPLACE FUNCTION ST_AsText(geometry)
	RETURNS TEXT
	AS '$libdir/postgis-2.5','LWGEOM_asText'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 750; --guess
CREATE OR REPLACE FUNCTION ST_AsText(geometry, int4)
    RETURNS TEXT
    AS '$libdir/postgis-2.5','LWGEOM_asText'
    LANGUAGE 'c' IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION ST_GeometryFromText(text)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOM_from_text'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeometryFromText(text, int4)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOM_from_text'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomFromText(text)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOM_from_text'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomFromText(text, int4)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOM_from_text'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_WKTToSQL(text)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOM_from_text'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_PointFromText(text)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromText($1)) = ''POINT''
	THEN @extschema@.ST_GeomFromText($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_PointFromText(text, int4)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromText($1, $2)) = ''POINT''
	THEN @extschema@.ST_GeomFromText($1, $2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LineFromText(text)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromText($1)) = ''LINESTRING''
	THEN @extschema@.ST_GeomFromText($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LineFromText(text, int4)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromText($1, $2)) = ''LINESTRING''
	THEN @extschema@.ST_GeomFromText($1,$2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_PolyFromText(text)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromText($1)) = ''POLYGON''
	THEN @extschema@.ST_GeomFromText($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_PolyFromText(text, int4)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromText($1, $2)) = ''POLYGON''
	THEN @extschema@.ST_GeomFromText($1, $2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_PolygonFromText(text, int4)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_PolyFromText($1, $2)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_PolygonFromText(text)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_PolyFromText($1)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MLineFromText(text, int4)
	RETURNS geometry
	AS '
	SELECT CASE
	WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromText($1, $2)) = ''MULTILINESTRING''
	THEN @extschema@.ST_GeomFromText($1,$2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MLineFromText(text)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromText($1)) = ''MULTILINESTRING''
	THEN @extschema@.ST_GeomFromText($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MultiLineStringFromText(text)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_MLineFromText($1)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MultiLineStringFromText(text, int4)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_MLineFromText($1, $2)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MPointFromText(text, int4)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromText($1, $2)) = ''MULTIPOINT''
	THEN ST_GeomFromText($1, $2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MPointFromText(text)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromText($1)) = ''MULTIPOINT''
	THEN @extschema@.ST_GeomFromText($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MultiPointFromText(text)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_MPointFromText($1)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MPolyFromText(text, int4)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromText($1, $2)) = ''MULTIPOLYGON''
	THEN @extschema@.ST_GeomFromText($1,$2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MPolyFromText(text)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromText($1)) = ''MULTIPOLYGON''
	THEN @extschema@.ST_GeomFromText($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MultiPolygonFromText(text, int4)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_MPolyFromText($1, $2)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MultiPolygonFromText(text)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_MPolyFromText($1)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomCollFromText(text, int4)
	RETURNS geometry
	AS '
	SELECT CASE
	WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromText($1, $2)) = ''GEOMETRYCOLLECTION''
	THEN @extschema@.ST_GeomFromText($1,$2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomCollFromText(text)
	RETURNS geometry
	AS '
	SELECT CASE
	WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromText($1)) = ''GEOMETRYCOLLECTION''
	THEN @extschema@.ST_GeomFromText($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomFromWKB(bytea)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOM_from_WKB'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomFromWKB(bytea, int)
	RETURNS geometry
	AS 'SELECT @extschema@.ST_SetSRID(@extschema@.ST_GeomFromWKB($1), $2)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_PointFromWKB(bytea, int)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1, $2)) = ''POINT''
	THEN @extschema@.ST_GeomFromWKB($1, $2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_PointFromWKB(bytea)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1)) = ''POINT''
	THEN @extschema@.ST_GeomFromWKB($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LineFromWKB(bytea, int)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1, $2)) = ''LINESTRING''
	THEN @extschema@.ST_GeomFromWKB($1, $2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LineFromWKB(bytea)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1)) = ''LINESTRING''
	THEN @extschema@.ST_GeomFromWKB($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LinestringFromWKB(bytea, int)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1, $2)) = ''LINESTRING''
	THEN @extschema@.ST_GeomFromWKB($1, $2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LinestringFromWKB(bytea)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1)) = ''LINESTRING''
	THEN @extschema@.ST_GeomFromWKB($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_PolyFromWKB(bytea, int)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1, $2)) = ''POLYGON''
	THEN @extschema@.ST_GeomFromWKB($1, $2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_PolyFromWKB(bytea)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1)) = ''POLYGON''
	THEN @extschema@.ST_GeomFromWKB($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_PolygonFromWKB(bytea, int)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1,$2)) = ''POLYGON''
	THEN @extschema@.ST_GeomFromWKB($1, $2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_PolygonFromWKB(bytea)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1)) = ''POLYGON''
	THEN @extschema@.ST_GeomFromWKB($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MPointFromWKB(bytea, int)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1, $2)) = ''MULTIPOINT''
	THEN @extschema@.ST_GeomFromWKB($1, $2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MPointFromWKB(bytea)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1)) = ''MULTIPOINT''
	THEN @extschema@.ST_GeomFromWKB($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MultiPointFromWKB(bytea, int)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1,$2)) = ''MULTIPOINT''
	THEN @extschema@.ST_GeomFromWKB($1, $2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MultiPointFromWKB(bytea)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1)) = ''MULTIPOINT''
	THEN @extschema@.ST_GeomFromWKB($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MultiLineFromWKB(bytea)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1)) = ''MULTILINESTRING''
	THEN @extschema@.ST_GeomFromWKB($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MLineFromWKB(bytea, int)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1, $2)) = ''MULTILINESTRING''
	THEN @extschema@.ST_GeomFromWKB($1, $2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MLineFromWKB(bytea)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1)) = ''MULTILINESTRING''
	THEN @extschema@.ST_GeomFromWKB($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MPolyFromWKB(bytea, int)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1, $2)) = ''MULTIPOLYGON''
	THEN @extschema@.ST_GeomFromWKB($1, $2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MPolyFromWKB(bytea)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1)) = ''MULTIPOLYGON''
	THEN @extschema@.ST_GeomFromWKB($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MultiPolyFromWKB(bytea, int)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1, $2)) = ''MULTIPOLYGON''
	THEN @extschema@.ST_GeomFromWKB($1, $2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MultiPolyFromWKB(bytea)
	RETURNS geometry
	AS '
	SELECT CASE WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1)) = ''MULTIPOLYGON''
	THEN @extschema@.ST_GeomFromWKB($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomCollFromWKB(bytea, int)
	RETURNS geometry
	AS '
	SELECT CASE
	WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1, $2)) = ''GEOMETRYCOLLECTION''
	THEN @extschema@.ST_GeomFromWKB($1, $2)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeomCollFromWKB(bytea)
	RETURNS geometry
	AS '
	SELECT CASE
	WHEN @extschema@.geometrytype(@extschema@.ST_GeomFromWKB($1)) = ''GEOMETRYCOLLECTION''
	THEN @extschema@.ST_GeomFromWKB($1)
	ELSE NULL END
	'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_MaxDistance(geom1 geometry, geom2 geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'LWGEOM_maxdistance2d_linestring'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_MaxDistance(geom1 geometry, geom2 geometry)
	RETURNS float8
	AS 'SELECT @extschema@._ST_MaxDistance(@extschema@.ST_ConvexHull($1), @extschema@.ST_ConvexHull($2))'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_ClosestPoint(geom1 geometry, geom2 geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_closestpoint'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_ShortestLine(geom1 geometry, geom2 geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_shortestline2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_LongestLine(geom1 geometry, geom2 geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_longestline2d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LongestLine(geom1 geometry, geom2 geometry)
	RETURNS geometry
	AS 'SELECT @extschema@._ST_LongestLine(@extschema@.ST_ConvexHull($1), @extschema@.ST_ConvexHull($2))'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_DFullyWithin(geom1 geometry, geom2 geometry,float8)
	RETURNS boolean
	AS '$libdir/postgis-2.5', 'LWGEOM_dfullywithin'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_DFullyWithin(geom1 geometry, geom2 geometry, float8)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.&&) @extschema@.ST_Expand($2,$3) AND $2 OPERATOR(@extschema@.&&) @extschema@.ST_Expand($1,$3) AND @extschema@._ST_DFullyWithin(@extschema@.ST_ConvexHull($1), @extschema@.ST_ConvexHull($2), $3)'
	LANGUAGE 'sql' IMMUTABLE;
CREATE OR REPLACE FUNCTION ST_SwapOrdinates(geom geometry, ords cstring)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_SwapOrdinates'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_FlipCoordinates(geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_FlipCoordinates'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_BdPolyFromText(text, integer)
RETURNS geometry
AS $$
DECLARE
	geomtext alias for $1;
	srid alias for $2;
	mline @extschema@.geometry;
	geom @extschema@.geometry;
BEGIN
	mline := @extschema@.ST_MultiLineStringFromText(geomtext, srid);

	IF mline IS NULL
	THEN
		RAISE EXCEPTION 'Input is not a MultiLinestring';
	END IF;

	geom := @extschema@.ST_BuildArea(mline);

	IF @extschema@.GeometryType(geom) != 'POLYGON'
	THEN
		RAISE EXCEPTION 'Input returns more then a single polygon, try using BdMPolyFromText instead';
	END IF;

	RETURN geom;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_BdMPolyFromText(text, integer)
RETURNS geometry
AS $$
DECLARE
	geomtext alias for $1;
	srid alias for $2;
	mline @extschema@.geometry;
	geom @extschema@.geometry;
BEGIN
	mline := @extschema@.ST_MultiLineStringFromText(geomtext, srid);

	IF mline IS NULL
	THEN
		RAISE EXCEPTION 'Input is not a MultiLinestring';
	END IF;

	geom := @extschema@.ST_Multi(@extschema@.ST_BuildArea(mline));

	RETURN geom;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION UnlockRows(text)
	RETURNS int
	AS $$
DECLARE
	ret int;
BEGIN

	IF NOT LongTransactionsEnabled() THEN
		RAISE EXCEPTION 'Long transaction support disabled, use EnableLongTransaction() to enable.';
	END IF;

	EXECUTE 'DELETE FROM authorization_table where authid = ' ||
		quote_literal($1);

	GET DIAGNOSTICS ret = ROW_COUNT;

	RETURN ret;
END;
$$
LANGUAGE 'plpgsql'  VOLATILE STRICT;
CREATE OR REPLACE FUNCTION LockRow(text, text, text, text, timestamp)
	RETURNS int
	AS $$
DECLARE
	myschema alias for $1;
	mytable alias for $2;
	myrid   alias for $3;
	authid alias for $4;
	expires alias for $5;
	ret int;
	mytoid oid;
	myrec RECORD;

BEGIN

	IF NOT LongTransactionsEnabled() THEN
		RAISE EXCEPTION 'Long transaction support disabled, use EnableLongTransaction() to enable.';
	END IF;

	EXECUTE 'DELETE FROM authorization_table WHERE expires < now()';

	SELECT c.oid INTO mytoid FROM pg_class c, pg_namespace n
		WHERE c.relname = mytable
		AND c.relnamespace = n.oid
		AND n.nspname = myschema;

	-- RAISE NOTICE 'toid: %', mytoid;

	FOR myrec IN SELECT * FROM authorization_table WHERE
		toid = mytoid AND rid = myrid
	LOOP
		IF myrec.authid != authid THEN
			RETURN 0;
		ELSE
			RETURN 1;
		END IF;
	END LOOP;

	EXECUTE 'INSERT INTO authorization_table VALUES ('||
		quote_literal(mytoid::text)||','||quote_literal(myrid)||
		','||quote_literal(expires::text)||
		','||quote_literal(authid) ||')';

	GET DIAGNOSTICS ret = ROW_COUNT;

	RETURN ret;
END;
$$
LANGUAGE 'plpgsql'  VOLATILE STRICT;
CREATE OR REPLACE FUNCTION LockRow(text, text, text, text)
	RETURNS int
	AS
$$ SELECT LockRow($1, $2, $3, $4, now()::timestamp+'1:00'); $$
	LANGUAGE 'sql'  VOLATILE STRICT;
CREATE OR REPLACE FUNCTION LockRow(text, text, text)
	RETURNS int
	AS
$$ SELECT LockRow(current_schema(), $1, $2, $3, now()::timestamp+'1:00'); $$
	LANGUAGE 'sql'  VOLATILE STRICT;
CREATE OR REPLACE FUNCTION LockRow(text, text, text, timestamp)
	RETURNS int
	AS
$$ SELECT LockRow(current_schema(), $1, $2, $3, $4); $$
	LANGUAGE 'sql'  VOLATILE STRICT;
CREATE OR REPLACE FUNCTION AddAuth(text)
	RETURNS BOOLEAN
	AS $$
DECLARE
	lockid alias for $1;
	okay boolean;
	myrec record;
BEGIN
	-- check to see if table exists
	--  if not, CREATE TEMP TABLE mylock (transid xid, lockcode text)
	okay := 'f';
	FOR myrec IN SELECT * FROM pg_class WHERE relname = 'temp_lock_have_table' LOOP
		okay := 't';
	END LOOP;
	IF (okay <> 't') THEN
		CREATE TEMP TABLE temp_lock_have_table (transid xid, lockcode text);
			-- this will only work from pgsql7.4 up
			-- ON COMMIT DELETE ROWS;
	END IF;

	--  INSERT INTO mylock VALUES ( $1)
--	EXECUTE 'INSERT INTO temp_lock_have_table VALUES ( '||
--		quote_literal(getTransactionID()) || ',' ||
--		quote_literal(lockid) ||')';

	INSERT INTO temp_lock_have_table VALUES (getTransactionID(), lockid);

	RETURN true::boolean;
END;
$$
LANGUAGE PLPGSQL;
CREATE OR REPLACE FUNCTION CheckAuth(text, text, text)
	RETURNS INT
	AS $$
DECLARE
	schema text;
BEGIN
	IF NOT LongTransactionsEnabled() THEN
		RAISE EXCEPTION 'Long transaction support disabled, use EnableLongTransaction() to enable.';
	END IF;

	if ( $1 != '' ) THEN
		schema = $1;
	ELSE
		SELECT current_schema() into schema;
	END IF;

	-- TODO: check for an already existing trigger ?

	EXECUTE 'CREATE TRIGGER check_auth BEFORE UPDATE OR DELETE ON '
		|| quote_ident(schema) || '.' || quote_ident($2)
		||' FOR EACH ROW EXECUTE PROCEDURE CheckAuthTrigger('
		|| quote_literal($3) || ')';

	RETURN 0;
END;
$$
LANGUAGE 'plpgsql';
CREATE OR REPLACE FUNCTION CheckAuth(text, text)
	RETURNS INT
	AS
	$$ SELECT CheckAuth('', $1, $2) $$
	LANGUAGE 'sql';
CREATE OR REPLACE FUNCTION CheckAuthTrigger()
	RETURNS trigger AS
	'$libdir/postgis-2.5', 'check_authorization'
	LANGUAGE C;
CREATE OR REPLACE FUNCTION GetTransactionID()
	RETURNS xid AS
	'$libdir/postgis-2.5', 'getTransactionID'
	LANGUAGE C;
CREATE OR REPLACE FUNCTION EnableLongTransactions()
	RETURNS TEXT
	AS $$
DECLARE
	"query" text;
	exists bool;
	rec RECORD;

BEGIN

	exists = 'f';
	FOR rec IN SELECT * FROM pg_class WHERE relname = 'authorization_table'
	LOOP
		exists = 't';
	END LOOP;

	IF NOT exists
	THEN
		"query" = 'CREATE TABLE authorization_table (
			toid oid, -- table oid
			rid text, -- row id
			expires timestamp,
			authid text
		)';
		EXECUTE "query";
	END IF;

	exists = 'f';
	FOR rec IN SELECT * FROM pg_class WHERE relname = 'authorized_tables'
	LOOP
		exists = 't';
	END LOOP;

	IF NOT exists THEN
		"query" = 'CREATE VIEW authorized_tables AS ' ||
			'SELECT ' ||
			'n.nspname as schema, ' ||
			'c.relname as table, trim(' ||
			quote_literal(chr(92) || '000') ||
			' from t.tgargs) as id_column ' ||
			'FROM pg_trigger t, pg_class c, pg_proc p ' ||
			', pg_namespace n ' ||
			'WHERE p.proname = ' || quote_literal('checkauthtrigger') ||
			' AND c.relnamespace = n.oid' ||
			' AND t.tgfoid = p.oid and t.tgrelid = c.oid';
		EXECUTE "query";
	END IF;

	RETURN 'Long transactions support enabled';
END;
$$
LANGUAGE 'plpgsql';
CREATE OR REPLACE FUNCTION LongTransactionsEnabled()
	RETURNS bool
AS $$
DECLARE
	rec RECORD;
BEGIN
	FOR rec IN SELECT oid FROM pg_class WHERE relname = 'authorized_tables'
	LOOP
		return 't';
	END LOOP;
	return 'f';
END;
$$
LANGUAGE 'plpgsql';
CREATE OR REPLACE FUNCTION DisableLongTransactions()
	RETURNS TEXT
	AS $$
DECLARE
	rec RECORD;

BEGIN

	--
	-- Drop all triggers applied by CheckAuth()
	--
	FOR rec IN
		SELECT c.relname, t.tgname, t.tgargs FROM pg_trigger t, pg_class c, pg_proc p
		WHERE p.proname = 'checkauthtrigger' and t.tgfoid = p.oid and t.tgrelid = c.oid
	LOOP
		EXECUTE 'DROP TRIGGER ' || quote_ident(rec.tgname) ||
			' ON ' || quote_ident(rec.relname);
	END LOOP;

	--
	-- Drop the authorization_table table
	--
	FOR rec IN SELECT * FROM pg_class WHERE relname = 'authorization_table' LOOP
		DROP TABLE authorization_table;
	END LOOP;

	--
	-- Drop the authorized_tables view
	--
	FOR rec IN SELECT * FROM pg_class WHERE relname = 'authorized_tables' LOOP
		DROP VIEW authorized_tables;
	END LOOP;

	RETURN 'Long transactions support disabled';
END;
$$
LANGUAGE 'plpgsql';
CREATE OR REPLACE FUNCTION geography_typmod_in(cstring[])
	RETURNS integer
	AS '$libdir/postgis-2.5','geography_typmod_in'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geography_typmod_out(integer)
	RETURNS cstring
	AS '$libdir/postgis-2.5','postgis_typmod_out'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geography_in(cstring, oid, integer)
	RETURNS geography
	AS '$libdir/postgis-2.5','geography_in'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geography_out(geography)
	RETURNS cstring
	AS '$libdir/postgis-2.5','geography_out'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geography_recv(internal, oid, integer)
	RETURNS geography
	AS '$libdir/postgis-2.5','geography_recv'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geography_send(geography)
	RETURNS bytea
	AS '$libdir/postgis-2.5','geography_send'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geography_analyze(internal)
	RETURNS bool
	AS '$libdir/postgis-2.5','gserialized_analyze_nd'
	LANGUAGE 'c' VOLATILE STRICT;
-- Type geography -- LastUpdated: 105
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 105 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE geography (
	internallength = variable,
	input = geography_in,
	output = geography_out,
	receive = geography_recv,
	send = geography_send,
	typmod_in = geography_typmod_in,
	typmod_out = geography_typmod_out,
	delimiter = ':',
	analyze = geography_analyze,
	storage = main,
	alignment = double
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geography(geography, integer, boolean)
	RETURNS geography
	AS '$libdir/postgis-2.5','geography_enforce_typmod'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (geography AS geography)');
DROP CAST IF EXISTS (geography AS geography);
CREATE CAST (geography AS geography) WITH FUNCTION geography(geography, integer, boolean) AS IMPLICIT;
CREATE OR REPLACE FUNCTION geography(bytea)
	RETURNS geography
	AS '$libdir/postgis-2.5','geography_from_binary'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION bytea(geography)
	RETURNS bytea
	AS '$libdir/postgis-2.5','LWGEOM_to_bytea'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (bytea AS geography)');
DROP CAST IF EXISTS (bytea AS geography);
CREATE CAST (bytea AS geography) WITH FUNCTION geography(bytea) AS IMPLICIT;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (geography AS bytea)');
DROP CAST IF EXISTS (geography AS bytea);
CREATE CAST (geography AS bytea) WITH FUNCTION bytea(geography) AS IMPLICIT;
CREATE OR REPLACE FUNCTION ST_AsText(geography)
	RETURNS TEXT
	AS '$libdir/postgis-2.5','LWGEOM_asText'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsText(geography, int4)
	RETURNS TEXT
	AS '$libdir/postgis-2.5','LWGEOM_asText'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsText(text)
	RETURNS text AS
	$$ SELECT @extschema@.ST_AsText($1::@extschema@.geometry);  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeographyFromText(text)
	RETURNS geography
	AS '$libdir/postgis-2.5','geography_from_text'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeogFromText(text)
	RETURNS geography
	AS '$libdir/postgis-2.5','geography_from_text'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeogFromWKB(bytea)
	RETURNS geography
	AS '$libdir/postgis-2.5','geography_from_binary'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION postgis_typmod_dims(integer)
	RETURNS integer
	AS '$libdir/postgis-2.5','postgis_typmod_dims'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION postgis_typmod_srid(integer)
	RETURNS integer
	AS '$libdir/postgis-2.5','postgis_typmod_srid'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION postgis_typmod_type(integer)
	RETURNS text
	AS '$libdir/postgis-2.5','postgis_typmod_type'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE VIEW geography_columns AS
	SELECT
		current_database() AS f_table_catalog,
		n.nspname AS f_table_schema,
		c.relname AS f_table_name,
		a.attname AS f_geography_column,
		postgis_typmod_dims(a.atttypmod) AS coord_dimension,
		postgis_typmod_srid(a.atttypmod) AS srid,
		postgis_typmod_type(a.atttypmod) AS type
	FROM
		pg_class c,
		pg_attribute a,
		pg_type t,
		pg_namespace n
	WHERE t.typname = 'geography'
		AND a.attisdropped = false
		AND a.atttypid = t.oid
		AND a.attrelid = c.oid
		AND c.relnamespace = n.oid
		AND c.relkind = ANY (ARRAY['r'::"char", 'v'::"char", 'm'::"char", 'f'::"char", 'p'::"char"] )
		AND NOT pg_is_other_temp_schema(c.relnamespace)
		AND has_table_privilege( c.oid, 'SELECT'::text );
CREATE OR REPLACE FUNCTION geography(geometry)
	RETURNS geography
	AS '$libdir/postgis-2.5','geography_from_geometry'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (geometry AS geography)');
DROP CAST IF EXISTS (geometry AS geography);
CREATE CAST (geometry AS geography) WITH FUNCTION geography(geometry) AS IMPLICIT;
CREATE OR REPLACE FUNCTION geometry(geography)
	RETURNS geometry
	AS '$libdir/postgis-2.5','geometry_from_geography'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (geography AS geometry)');
DROP CAST IF EXISTS (geography AS geometry);
CREATE CAST (geography AS geometry) WITH FUNCTION geometry(geography) ;
CREATE OR REPLACE FUNCTION geography_gist_consistent(internal,geography,int4)
	RETURNS bool
	AS '$libdir/postgis-2.5' ,'gserialized_gist_consistent'
	LANGUAGE 'c';
CREATE OR REPLACE FUNCTION geography_gist_compress(internal)
	RETURNS internal
	AS '$libdir/postgis-2.5','gserialized_gist_compress'
	LANGUAGE 'c';
CREATE OR REPLACE FUNCTION geography_gist_penalty(internal,internal,internal)
	RETURNS internal
	AS '$libdir/postgis-2.5' ,'gserialized_gist_penalty'
	LANGUAGE 'c';
CREATE OR REPLACE FUNCTION geography_gist_picksplit(internal, internal)
	RETURNS internal
	AS '$libdir/postgis-2.5' ,'gserialized_gist_picksplit'
	LANGUAGE 'c';
CREATE OR REPLACE FUNCTION geography_gist_union(bytea, internal)
	RETURNS internal
	AS '$libdir/postgis-2.5' ,'gserialized_gist_union'
	LANGUAGE 'c';
CREATE OR REPLACE FUNCTION geography_gist_same(box2d, box2d, internal)
	RETURNS internal
	AS '$libdir/postgis-2.5' ,'gserialized_gist_same'
	LANGUAGE 'c';
CREATE OR REPLACE FUNCTION geography_gist_decompress(internal)
	RETURNS internal
	AS '$libdir/postgis-2.5' ,'gserialized_gist_decompress'
	LANGUAGE 'c';
CREATE OR REPLACE FUNCTION geography_overlaps(geography, geography)
	RETURNS boolean
	AS '$libdir/postgis-2.5' ,'gserialized_overlaps'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geography && -- LastUpdated: 105
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 105 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR && (
	LEFTARG = geography, RIGHTARG = geography, PROCEDURE = geography_overlaps,
	COMMUTATOR = '&&',
	RESTRICT = gserialized_gist_sel_nd,
	JOIN = gserialized_gist_joinsel_nd
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geography_distance_knn(geography, geography)
  RETURNS float8
  AS '$libdir/postgis-2.5','geography_distance_knn'
  LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
  COST 100;
-- Operator geography <-> -- LastUpdated: 202
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 202 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR <-> (
  LEFTARG = geography, RIGHTARG = geography, PROCEDURE = geography_distance_knn,
  COMMUTATOR = '<->'
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geography_gist_distance(internal, geography, int4)
	RETURNS float8
	AS '$libdir/postgis-2.5' ,'gserialized_gist_geog_distance'
	LANGUAGE 'c';
-- Operator class gist_geography_ops -- LastUpdated: 105
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 105 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$
    CREATE OPERATOR CLASS gist_geography_ops
	DEFAULT FOR TYPE geography USING GIST AS
	STORAGE 	gidx,
	OPERATOR        3        &&	,
	OPERATOR        13       <-> FOR ORDER BY pg_catalog.float_ops,
	FUNCTION        8        geography_gist_distance (internal, geography, int4),
	FUNCTION        1        geography_gist_consistent (internal, geography, int4),
	FUNCTION        2        geography_gist_union (bytea, internal),
	FUNCTION        3        geography_gist_compress (internal),
	FUNCTION        4        geography_gist_decompress (internal),
	FUNCTION        5        geography_gist_penalty (internal, internal, internal),
	FUNCTION        6        geography_gist_picksplit (internal, internal),
	FUNCTION        7        geography_gist_same (box2d, box2d, internal);
    $postgis_proc_upgrade_parsed_def$;
  ELSE -- version_from >= 105
    -- Last Updated: 202
    IF 202 > version_from_num FROM _postgis_upgrade_info THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$
        ALTER OPERATOR FAMILY gist_geography_ops USING gist
          ADD OPERATOR        13       <-> (geography,geography) FOR ORDER BY pg_catalog.float_ops;
      $postgis_proc_upgrade_parsed_def$;
    END IF;
  
    -- Last Updated: 202
    IF 202 > version_from_num FROM _postgis_upgrade_info THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$
        ALTER OPERATOR FAMILY gist_geography_ops USING gist
          ADD FUNCTION        8 (geography,geography)        geography_gist_distance (internal, geography, int4);
      $postgis_proc_upgrade_parsed_def$;
    END IF;
  END IF; -- version_from >= 202
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION overlaps_geog(gidx, geography)
RETURNS boolean
AS '$libdir/postgis-2.5','gserialized_gidx_geog_overlaps'
LANGUAGE 'c' IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION overlaps_geog(gidx, gidx)
RETURNS boolean
AS '$libdir/postgis-2.5','gserialized_gidx_gidx_overlaps'
LANGUAGE 'c' IMMUTABLE STRICT;
-- Operator gidx && -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR && (
  LEFTARG    = gidx,
  RIGHTARG   = geography,
  PROCEDURE  = overlaps_geog,
  COMMUTATOR = &&
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION overlaps_geog(geography, gidx)
RETURNS boolean
AS
  'SELECT $2 OPERATOR(@extschema@.&&) $1;'
 LANGUAGE SQL IMMUTABLE STRICT;
-- Operator geography && -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR && (
  LEFTARG    = geography,
  RIGHTARG   = gidx,
  PROCEDURE  = overlaps_geog,
  COMMUTATOR = &&
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator gidx && -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR && (
  LEFTARG   = gidx,
  RIGHTARG  = gidx,
  PROCEDURE = overlaps_geog,
  COMMUTATOR = &&
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geog_brin_inclusion_add_value(internal, internal, internal, internal) RETURNS boolean
        AS '$libdir/postgis-2.5','geog_brin_inclusion_add_value'
        LANGUAGE 'c';
-- Operator class brin_geography_inclusion_ops -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$
    CREATE OPERATOR CLASS brin_geography_inclusion_ops
  DEFAULT FOR TYPE geography
  USING brin AS
    FUNCTION      1        brin_inclusion_opcinfo(internal),
    FUNCTION      2        geog_brin_inclusion_add_value(internal, internal, internal, internal),
    FUNCTION      3        brin_inclusion_consistent(internal, internal, internal),
    FUNCTION      4        brin_inclusion_union(internal, internal, internal),
    OPERATOR      3        &&(geography, geography),
    OPERATOR      3        &&(geography, gidx),
    OPERATOR      3        &&(gidx, geography),
    OPERATOR      3        &&(gidx, gidx),
  STORAGE gidx;
    $postgis_proc_upgrade_parsed_def$;
  END IF; -- version_from >= 203
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geography_lt(geography, geography)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'geography_lt'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geography_le(geography, geography)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'geography_le'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geography_gt(geography, geography)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'geography_gt'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geography_ge(geography, geography)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'geography_ge'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geography_eq(geography, geography)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'geography_eq'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geography_cmp(geography, geography)
	RETURNS integer
	AS '$libdir/postgis-2.5', 'geography_cmp'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geography < -- LastUpdated: 105
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 105 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR < (
	LEFTARG = geography, RIGHTARG = geography, PROCEDURE = geography_lt,
	COMMUTATOR = '>', NEGATOR = '>=',
	RESTRICT = contsel, JOIN = contjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geography <= -- LastUpdated: 105
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 105 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR <= (
	LEFTARG = geography, RIGHTARG = geography, PROCEDURE = geography_le,
	COMMUTATOR = '>=', NEGATOR = '>',
	RESTRICT = contsel, JOIN = contjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geography = -- LastUpdated: 105
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 105 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR = (
	LEFTARG = geography, RIGHTARG = geography, PROCEDURE = geography_eq,
	COMMUTATOR = '=', -- we might implement a faster negator here
	RESTRICT = contsel, JOIN = contjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geography >= -- LastUpdated: 105
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 105 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR >= (
	LEFTARG = geography, RIGHTARG = geography, PROCEDURE = geography_ge,
	COMMUTATOR = '<=', NEGATOR = '<',
	RESTRICT = contsel, JOIN = contjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geography > -- LastUpdated: 105
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 105 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR > (
	LEFTARG = geography, RIGHTARG = geography, PROCEDURE = geography_gt,
	COMMUTATOR = '<', NEGATOR = '<=',
	RESTRICT = contsel, JOIN = contjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator class btree_geography_ops -- LastUpdated: 105
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 105 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$
    CREATE OPERATOR CLASS btree_geography_ops
	DEFAULT FOR TYPE geography USING btree AS
	OPERATOR	1	< ,
	OPERATOR	2	<= ,
	OPERATOR	3	= ,
	OPERATOR	4	>= ,
	OPERATOR	5	> ,
	FUNCTION	1	geography_cmp (geography, geography);
    $postgis_proc_upgrade_parsed_def$;
  END IF; -- version_from >= 105
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION ST_AsSVG(geog geography,rel int4 DEFAULT 0,maxdecimaldigits int4 DEFAULT 15)
	RETURNS text
	AS '$libdir/postgis-2.5','geography_as_svg'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsSVG(text)
	RETURNS text AS
	$$ SELECT @extschema@.ST_AsSVG($1::@extschema@.geometry,0,15);  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_AsGML(int4, geography, int4, int4, text, text)
	RETURNS text
	AS '$libdir/postgis-2.5','geography_as_gml'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsGML(text)
	RETURNS text AS
	$$ SELECT @extschema@._ST_AsGML(2,$1::@extschema@.geometry,15,0, NULL, NULL);  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsGML(geog geography, maxdecimaldigits int4 DEFAULT 15, options int4 DEFAULT 0)
	RETURNS text
	AS 'SELECT @extschema@._ST_AsGML(2, $1, $2, $3, null, null)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsGML(version int4, geog geography, maxdecimaldigits int4 DEFAULT 15, options int4 DEFAULT 0, nprefix text DEFAULT NULL, id text DEFAULT NULL)
	RETURNS text
	AS $$ SELECT @extschema@._ST_AsGML($1, $2, $3, $4, $5, $6);$$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_AsKML(int4, geography, int4, text)
	RETURNS text
	AS '$libdir/postgis-2.5','geography_as_kml'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsKML(geog geography, maxdecimaldigits int4 DEFAULT 15)
	RETURNS text
	AS 'SELECT @extschema@._ST_AsKML(2, $1, $2, null)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsKML(text)
	RETURNS text AS
	$$ SELECT @extschema@._ST_AsKML(2, $1::@extschema@.geometry, 15, null);  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsKML(version int4, geog geography, maxdecimaldigits int4 DEFAULT 15, nprefix text DEFAULT null)
	RETURNS text
	AS 'SELECT @extschema@._ST_AsKML($1, $2, $3, $4)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_AsGeoJson(int4, geography, int4, int4)
	RETURNS text
	AS '$libdir/postgis-2.5','geography_as_geojson'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsGeoJson(text)
	RETURNS text AS
	$$ SELECT @extschema@._ST_AsGeoJson(1, $1::@extschema@.geometry,15,0);  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsGeoJson(geog geography, maxdecimaldigits int4 DEFAULT 15, options int4 DEFAULT 0)
	RETURNS text
	AS $$ SELECT @extschema@._ST_AsGeoJson(1, $1, $2, $3); $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsGeoJson(gj_version int4, geog geography, maxdecimaldigits int4 DEFAULT 15, options int4 DEFAULT 0)
	RETURNS text
	AS $$ SELECT @extschema@._ST_AsGeoJson($1, $2, $3, $4); $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_Distance(geography, geography, float8, boolean)
	RETURNS float8
	AS '$libdir/postgis-2.5','geography_distance'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION _ST_DWithin(geography, geography, float8, boolean)
	RETURNS boolean
	AS '$libdir/postgis-2.5','geography_dwithin'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION ST_Distance(geography, geography, boolean)
	RETURNS float8
	AS 'SELECT @extschema@._ST_Distance($1, $2, 0.0, $3)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Distance(geography, geography)
	RETURNS float8
	AS 'SELECT @extschema@._ST_Distance($1, $2, 0.0, true)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Distance(text, text)
	RETURNS float8 AS
	$$ SELECT @extschema@.ST_Distance($1::@extschema@.geometry, $2::@extschema@.geometry);  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_Expand(geography, float8)
	RETURNS geography
	AS '$libdir/postgis-2.5','geography_expand'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 50;
CREATE OR REPLACE FUNCTION ST_DWithin(geography, geography, float8, boolean)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.&&) @extschema@._ST_Expand($2,$3) AND $2 OPERATOR(@extschema@.&&) @extschema@._ST_Expand($1,$3) AND @extschema@._ST_DWithin($1, $2, $3, $4)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_DWithin(geography, geography, float8)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.&&) @extschema@._ST_Expand($2,$3) AND $2 OPERATOR(@extschema@.&&) @extschema@._ST_Expand($1,$3) AND @extschema@._ST_DWithin($1, $2, $3, true)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_DWithin(text, text, float8)
	RETURNS boolean AS
	$$ SELECT @extschema@.ST_DWithin($1::@extschema@.geometry, $2::@extschema@.geometry, $3);  $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_DistanceUnCached(geography, geography, float8, boolean)
	RETURNS float8
	AS '$libdir/postgis-2.5','geography_distance_uncached'
	LANGUAGE 'c' IMMUTABLE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _ST_DistanceUnCached(geography, geography, boolean)
	RETURNS float8
	AS 'SELECT @extschema@._ST_DistanceUnCached($1, $2, 0.0, $3)'
	LANGUAGE 'sql' IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION _ST_DistanceUnCached(geography, geography)
	RETURNS float8
	AS 'SELECT @extschema@._ST_DistanceUnCached($1, $2, 0.0, true)'
	LANGUAGE 'sql' IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION _ST_DistanceTree(geography, geography, float8, boolean)
	RETURNS float8
	AS '$libdir/postgis-2.5','geography_distance_tree'
	LANGUAGE 'c' IMMUTABLE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _ST_DistanceTree(geography, geography)
	RETURNS float8
	AS 'SELECT @extschema@._ST_DistanceTree($1, $2, 0.0, true)'
	LANGUAGE 'sql' IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION _ST_DWithinUnCached(geography, geography, float8, boolean)
	RETURNS boolean
	AS '$libdir/postgis-2.5','geography_dwithin_uncached'
	LANGUAGE 'c' IMMUTABLE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _ST_DWithinUnCached(geography, geography, float8)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.&&) @extschema@._ST_Expand($2,$3) AND $2 OPERATOR(@extschema@.&&) @extschema@._ST_Expand($1,$3) AND @extschema@._ST_DWithinUnCached($1, $2, $3, true)'
	LANGUAGE 'sql' IMMUTABLE;
CREATE OR REPLACE FUNCTION ST_Area(geog geography, use_spheroid boolean DEFAULT true)
	RETURNS float8
	AS '$libdir/postgis-2.5','geography_area'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION ST_Area(text)
	RETURNS float8 AS
	$$ SELECT @extschema@.ST_Area($1::@extschema@.geometry);  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Length(geog geography, use_spheroid boolean DEFAULT true)
	RETURNS float8
	AS '$libdir/postgis-2.5','geography_length'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION ST_Length(text)
	RETURNS float8 AS
	$$ SELECT @extschema@.ST_Length($1::@extschema@.geometry);  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Project(geog geography, distance float8, azimuth float8)
	RETURNS geography
	AS '$libdir/postgis-2.5','geography_project'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION ST_Azimuth(geog1 geography, geog2 geography)
	RETURNS float8
	AS '$libdir/postgis-2.5','geography_azimuth'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION ST_Perimeter(geog geography, use_spheroid boolean DEFAULT true)
	RETURNS float8
	AS '$libdir/postgis-2.5','geography_perimeter'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION _ST_PointOutside(geography)
	RETURNS geography
	AS '$libdir/postgis-2.5','geography_point_outside'
	LANGUAGE 'c' IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION _ST_Covers(geography, geography)
	RETURNS boolean
	AS '$libdir/postgis-2.5','geography_covers'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION ST_Covers(geography, geography)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.&&) $2 AND @extschema@._ST_Covers($1, $2)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Covers(text, text)
	RETURNS boolean AS
	$$ SELECT @extschema@.ST_Covers($1::@extschema@.geometry, $2::@extschema@.geometry);  $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_CoveredBy(geography, geography)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.&&) $2 AND @extschema@._ST_Covers($2, $1)'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_CoveredBy(text, text)
	RETURNS boolean AS
	$$ SELECT @extschema@.ST_CoveredBy($1::@extschema@.geometry, $2::@extschema@.geometry);  $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Segmentize(geog geography, max_segment_length float8)
	RETURNS geography
	AS '$libdir/postgis-2.5','geography_segmentize'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION ST_Intersects(geography, geography)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.&&) $2 AND @extschema@._ST_Distance($1, $2, 0.0, false) < 0.00001'
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Intersects(text, text)
	RETURNS boolean AS
	$$ SELECT @extschema@.ST_Intersects($1::@extschema@.geometry, $2::@extschema@.geometry);  $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_BestSRID(geography, geography)
	RETURNS integer
	AS '$libdir/postgis-2.5','geography_bestsrid'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_BestSRID(geography)
	RETURNS integer
	AS 'SELECT @extschema@._ST_BestSRID($1,$1)'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Buffer(geography, float8)
	RETURNS geography
	AS 'SELECT @extschema@.geography(@extschema@.ST_Transform(@extschema@.ST_Buffer(@extschema@.ST_Transform(@extschema@.geometry($1), @extschema@._ST_BestSRID($1)), $2), 4326))'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Buffer(geography, float8, integer)
	RETURNS geography
	AS 'SELECT @extschema@.geography(@extschema@.ST_Transform(@extschema@.ST_Buffer(@extschema@.ST_Transform(@extschema@.geometry($1), @extschema@._ST_BestSRID($1)), $2, $3), 4326))'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Buffer(geography, float8, text)
	RETURNS geography
	AS 'SELECT @extschema@.geography(@extschema@.ST_Transform(@extschema@.ST_Buffer(@extschema@.ST_Transform(@extschema@.geometry($1), @extschema@._ST_BestSRID($1)), $2, $3), 4326))'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Buffer(text, float8)
	RETURNS geometry AS
	$$ SELECT @extschema@.ST_Buffer($1::@extschema@.geometry, $2);  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Buffer(text, float8, integer)
	RETURNS geometry AS
	$$ SELECT @extschema@.ST_Buffer($1::@extschema@.geometry, $2, $3);  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Buffer(text, float8, text)
	RETURNS geometry AS
	$$ SELECT @extschema@.ST_Buffer($1::@extschema@.geometry, $2, $3);  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Intersection(geography, geography)
	RETURNS geography
	AS 'SELECT @extschema@.geography(@extschema@.ST_Transform(@extschema@.ST_Intersection(@extschema@.ST_Transform(@extschema@.geometry($1), @extschema@._ST_BestSRID($1, $2)), @extschema@.ST_Transform(@extschema@.geometry($2), @extschema@._ST_BestSRID($1, $2))), 4326))'
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Intersection(text, text)
	RETURNS geometry AS
	$$ SELECT @extschema@.ST_Intersection($1::@extschema@.geometry, $2::@extschema@.geometry);  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsBinary(geography)
	RETURNS bytea
	AS '$libdir/postgis-2.5','LWGEOM_asBinary'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsBinary(geography,text)
	RETURNS bytea AS
	$$ SELECT @extschema@.ST_AsBinary($1::@extschema@.geometry, $2);  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsEWKT(geography)
	RETURNS TEXT
	AS '$libdir/postgis-2.5','LWGEOM_asEWKT'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsEWKT(text)
	RETURNS text AS
	$$ SELECT @extschema@.ST_AsEWKT($1::@extschema@.geometry);  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION GeometryType(geography)
	RETURNS text
	AS '$libdir/postgis-2.5', 'LWGEOM_getTYPE'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Summary(geography)
	RETURNS text
	AS '$libdir/postgis-2.5', 'LWGEOM_summary'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_GeoHash(geog geography, maxchars int4 DEFAULT 0)
	RETURNS TEXT
	AS '$libdir/postgis-2.5', 'ST_GeoHash'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_SRID(geog geography)
	RETURNS int4
	AS '$libdir/postgis-2.5', 'LWGEOM_get_srid'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_SetSRID(geog geography, srid int4)
	RETURNS geography
	AS '$libdir/postgis-2.5', 'LWGEOM_set_srid'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Centroid(geography, use_spheroid boolean DEFAULT true)
	RETURNS geography
	AS '$libdir/postgis-2.5','geography_centroid'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Centroid(text)
	RETURNS geometry AS
	$$ SELECT @extschema@.ST_Centroid($1::@extschema@.geometry);  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_DistanceSphere(geom1 geometry, geom2 geometry)
	RETURNS FLOAT8
	AS $$
	select @extschema@.ST_distance( @extschema@.geography($1), @extschema@.geography($2),false)
	$$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE
	COST 300;
CREATE OR REPLACE FUNCTION ST_distance_sphere(geom1 geometry, geom2 geometry)
	RETURNS FLOAT8 AS
  $$ SELECT @extschema@._postgis_deprecate('ST_Distance_Sphere', 'ST_DistanceSphere', '2.2.0');
    SELECT @extschema@.ST_DistanceSphere($1,$2);
  $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE
	COST 300;
CREATE OR REPLACE FUNCTION postgis_type_name(geomname varchar, coord_dimension integer, use_new_name boolean DEFAULT true)
	RETURNS varchar
AS
$$
	SELECT CASE WHEN $3 THEN new_name ELSE old_name END As geomname
	FROM
	( VALUES
			('GEOMETRY', 'Geometry', 2),
			('GEOMETRY', 'GeometryZ', 3),
			('GEOMETRYM', 'GeometryM', 3),
			('GEOMETRY', 'GeometryZM', 4),

			('GEOMETRYCOLLECTION', 'GeometryCollection', 2),
			('GEOMETRYCOLLECTION', 'GeometryCollectionZ', 3),
			('GEOMETRYCOLLECTIONM', 'GeometryCollectionM', 3),
			('GEOMETRYCOLLECTION', 'GeometryCollectionZM', 4),

			('POINT', 'Point', 2),
			('POINT', 'PointZ', 3),
			('POINTM','PointM', 3),
			('POINT', 'PointZM', 4),

			('MULTIPOINT','MultiPoint', 2),
			('MULTIPOINT','MultiPointZ', 3),
			('MULTIPOINTM','MultiPointM', 3),
			('MULTIPOINT','MultiPointZM', 4),

			('POLYGON', 'Polygon', 2),
			('POLYGON', 'PolygonZ', 3),
			('POLYGONM', 'PolygonM', 3),
			('POLYGON', 'PolygonZM', 4),

			('MULTIPOLYGON', 'MultiPolygon', 2),
			('MULTIPOLYGON', 'MultiPolygonZ', 3),
			('MULTIPOLYGONM', 'MultiPolygonM', 3),
			('MULTIPOLYGON', 'MultiPolygonZM', 4),

			('MULTILINESTRING', 'MultiLineString', 2),
			('MULTILINESTRING', 'MultiLineStringZ', 3),
			('MULTILINESTRINGM', 'MultiLineStringM', 3),
			('MULTILINESTRING', 'MultiLineStringZM', 4),

			('LINESTRING', 'LineString', 2),
			('LINESTRING', 'LineStringZ', 3),
			('LINESTRINGM', 'LineStringM', 3),
			('LINESTRING', 'LineStringZM', 4),

			('CIRCULARSTRING', 'CircularString', 2),
			('CIRCULARSTRING', 'CircularStringZ', 3),
			('CIRCULARSTRINGM', 'CircularStringM' ,3),
			('CIRCULARSTRING', 'CircularStringZM', 4),

			('COMPOUNDCURVE', 'CompoundCurve', 2),
			('COMPOUNDCURVE', 'CompoundCurveZ', 3),
			('COMPOUNDCURVEM', 'CompoundCurveM', 3),
			('COMPOUNDCURVE', 'CompoundCurveZM', 4),

			('CURVEPOLYGON', 'CurvePolygon', 2),
			('CURVEPOLYGON', 'CurvePolygonZ', 3),
			('CURVEPOLYGONM', 'CurvePolygonM', 3),
			('CURVEPOLYGON', 'CurvePolygonZM', 4),

			('MULTICURVE', 'MultiCurve', 2),
			('MULTICURVE', 'MultiCurveZ', 3),
			('MULTICURVEM', 'MultiCurveM', 3),
			('MULTICURVE', 'MultiCurveZM', 4),

			('MULTISURFACE', 'MultiSurface', 2),
			('MULTISURFACE', 'MultiSurfaceZ', 3),
			('MULTISURFACEM', 'MultiSurfaceM', 3),
			('MULTISURFACE', 'MultiSurfaceZM', 4),

			('POLYHEDRALSURFACE', 'PolyhedralSurface', 2),
			('POLYHEDRALSURFACE', 'PolyhedralSurfaceZ', 3),
			('POLYHEDRALSURFACEM', 'PolyhedralSurfaceM', 3),
			('POLYHEDRALSURFACE', 'PolyhedralSurfaceZM', 4),

			('TRIANGLE', 'Triangle', 2),
			('TRIANGLE', 'TriangleZ', 3),
			('TRIANGLEM', 'TriangleM', 3),
			('TRIANGLE', 'TriangleZM', 4),

			('TIN', 'Tin', 2),
			('TIN', 'TinZ', 3),
			('TINM', 'TinM', 3),
			('TIN', 'TinZM', 4) )
			 As g(old_name, new_name, coord_dimension)
	WHERE (upper(old_name) = upper($1) OR upper(new_name) = upper($1))
		AND coord_dimension = $2;
$$
LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE COST 200;
CREATE OR REPLACE FUNCTION postgis_constraint_srid(geomschema text, geomtable text, geomcolumn text) RETURNS integer AS
$$
SELECT replace(replace(split_part(s.consrc, ' = ', 2), ')', ''), '(', '')::integer
		 FROM pg_class c, pg_namespace n, pg_attribute a
		 , (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
		    FROM pg_constraint) AS s
		 WHERE n.nspname = $1
		 AND c.relname = $2
		 AND a.attname = $3
		 AND a.attrelid = c.oid
		 AND s.connamespace = n.oid
		 AND s.conrelid = c.oid
		 AND a.attnum = ANY (s.conkey)
		 AND s.consrc LIKE '%srid(% = %';
$$
LANGUAGE 'sql' STABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION postgis_constraint_dims(geomschema text, geomtable text, geomcolumn text) RETURNS integer AS
$$
SELECT  replace(split_part(s.consrc, ' = ', 2), ')', '')::integer

		 FROM pg_class c, pg_namespace n, pg_attribute a
		 , (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
		    FROM pg_constraint) AS s
		 WHERE n.nspname = $1
		 AND c.relname = $2
		 AND a.attname = $3
		 AND a.attrelid = c.oid
		 AND s.connamespace = n.oid
		 AND s.conrelid = c.oid
		 AND a.attnum = ANY (s.conkey)
		 AND s.consrc LIKE '%ndims(% = %';
$$
LANGUAGE 'sql' STABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION postgis_constraint_type(geomschema text, geomtable text, geomcolumn text) RETURNS varchar AS
$$
SELECT  replace(split_part(s.consrc, '''', 2), ')', '')::varchar

		 FROM pg_class c, pg_namespace n, pg_attribute a
		 , (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
		    FROM pg_constraint) AS s
		 WHERE n.nspname = $1
		 AND c.relname = $2
		 AND a.attname = $3
		 AND a.attrelid = c.oid
		 AND s.connamespace = n.oid
		 AND s.conrelid = c.oid
		 AND a.attnum = ANY (s.conkey)
		 AND s.consrc LIKE '%geometrytype(% = %';
$$
LANGUAGE 'sql' STABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE VIEW geometry_columns AS
 SELECT current_database()::character varying(256) AS f_table_catalog,
    n.nspname AS f_table_schema,
    c.relname AS f_table_name,
    a.attname AS f_geometry_column,
    COALESCE(postgis_typmod_dims(a.atttypmod), sn.ndims, 2) AS coord_dimension,
    COALESCE(NULLIF(postgis_typmod_srid(a.atttypmod), 0), sr.srid, 0) AS srid,
    replace(replace(COALESCE(NULLIF(upper(postgis_typmod_type(a.atttypmod)), 'GEOMETRY'::text), st.type, 'GEOMETRY'::text), 'ZM'::text, ''::text), 'Z'::text, ''::text)::character varying(30) AS type
   FROM pg_class c
     JOIN pg_attribute a ON a.attrelid = c.oid AND NOT a.attisdropped
     JOIN pg_namespace n ON c.relnamespace = n.oid
     JOIN pg_type t ON a.atttypid = t.oid
     LEFT JOIN ( SELECT s.connamespace,
            s.conrelid,
            s.conkey, replace(split_part(s.consrc, ''''::text, 2), ')'::text, ''::text) As type
           FROM (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
				FROM pg_constraint) AS s
          WHERE s.consrc ~~* '%geometrytype(% = %'::text

) st ON st.connamespace = n.oid AND st.conrelid = c.oid AND (a.attnum = ANY (st.conkey))
     LEFT JOIN ( SELECT s.connamespace,
            s.conrelid,
            s.conkey, replace(split_part(s.consrc, ' = '::text, 2), ')'::text, ''::text)::integer As ndims
           FROM (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
		    FROM pg_constraint) AS s
          WHERE s.consrc ~~* '%ndims(% = %'::text

) sn ON sn.connamespace = n.oid AND sn.conrelid = c.oid AND (a.attnum = ANY (sn.conkey))
     LEFT JOIN ( SELECT s.connamespace,
            s.conrelid,
            s.conkey, replace(replace(split_part(s.consrc, ' = '::text, 2), ')'::text, ''::text), '('::text, ''::text)::integer As srid
           FROM (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
		    FROM pg_constraint) AS s
          WHERE s.consrc ~~* '%srid(% = %'::text

) sr ON sr.connamespace = n.oid AND sr.conrelid = c.oid AND (a.attnum = ANY (sr.conkey))
  WHERE (c.relkind = ANY (ARRAY['r'::"char", 'v'::"char", 'm'::"char", 'f'::"char", 'p'::"char"]))
  AND NOT c.relname = 'raster_columns'::name AND t.typname = 'geometry'::name
  AND NOT pg_is_other_temp_schema(c.relnamespace) AND has_table_privilege(c.oid, 'SELECT'::text);
CREATE OR REPLACE RULE geometry_columns_insert AS
        ON INSERT TO geometry_columns
        DO INSTEAD NOTHING;
CREATE OR REPLACE RULE geometry_columns_update AS
        ON UPDATE TO geometry_columns
        DO INSTEAD NOTHING;
CREATE OR REPLACE RULE geometry_columns_delete AS
        ON DELETE TO geometry_columns
        DO INSTEAD NOTHING;
CREATE OR REPLACE FUNCTION ST_3DDistance(geom1 geometry, geom2 geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'distance3d'
	LANGUAGE 'c' IMMUTABLE STRICT  PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION ST_3DMaxDistance(geom1 geometry, geom2 geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'LWGEOM_maxdistance3d'
	LANGUAGE 'c' IMMUTABLE STRICT  PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION ST_3DClosestPoint(geom1 geometry, geom2 geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_closestpoint3d'
	LANGUAGE 'c' IMMUTABLE STRICT  PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_3DShortestLine(geom1 geometry, geom2 geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_shortestline3d'
	LANGUAGE 'c' IMMUTABLE STRICT  PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION ST_3DLongestLine(geom1 geometry, geom2 geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_longestline3d'
	LANGUAGE 'c' IMMUTABLE STRICT  PARALLEL SAFE
	COST 1; -- reset cost, see #3675
CREATE OR REPLACE FUNCTION _ST_3DDWithin(geom1 geometry, geom2 geometry,float8)
	RETURNS boolean
	AS '$libdir/postgis-2.5', 'LWGEOM_dwithin3d'
	LANGUAGE 'c' IMMUTABLE STRICT  PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION ST_3DDWithin(geom1 geometry, geom2 geometry,float8)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.&&) @extschema@.ST_Expand($2,$3) AND $2 OPERATOR(@extschema@.&&) @extschema@.ST_Expand($1,$3) AND @extschema@._ST_3DDWithin($1, $2, $3)'
	LANGUAGE 'sql' IMMUTABLE  PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION _ST_3DDFullyWithin(geom1 geometry, geom2 geometry,float8)
	RETURNS boolean
	AS '$libdir/postgis-2.5', 'LWGEOM_dfullywithin3d'
	LANGUAGE 'c' IMMUTABLE STRICT  PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION ST_3DDFullyWithin(geom1 geometry, geom2 geometry,float8)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.&&) @extschema@.ST_Expand($2,$3) AND $2 OPERATOR(@extschema@.&&) @extschema@.ST_Expand($1,$3) AND @extschema@._ST_3DDFullyWithin($1, $2, $3)'
	LANGUAGE 'sql' IMMUTABLE  PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION _ST_3DIntersects(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5','intersects3d'
	LANGUAGE 'c' IMMUTABLE STRICT  PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION ST_3DIntersects(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS 'SELECT $1 OPERATOR(@extschema@.&&) $2 AND @extschema@._ST_3DIntersects($1, $2)'
	LANGUAGE 'sql' IMMUTABLE  PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION ST_CoordDim(Geometry geometry)
	RETURNS smallint
	AS '$libdir/postgis-2.5', 'LWGEOM_ndims'
	LANGUAGE 'c' IMMUTABLE STRICT  PARALLEL SAFE
	COST 5;
CREATE OR REPLACE FUNCTION ST_CurveToLine(geom geometry, tol float8 DEFAULT 32, toltype integer DEFAULT 0, flags integer DEFAULT 0)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_CurveToLine'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_HasArc(Geometry geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5', 'LWGEOM_has_arc'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LineToCurve(Geometry geometry)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_line_desegmentize'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_OrderingEquals(GeometryA geometry, GeometryB geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5', 'LWGEOM_same'
	LANGUAGE 'c' IMMUTABLE STRICT  PARALLEL SAFE
	COST 100;
CREATE OR REPLACE FUNCTION ST_OrderingEquals(GeometryA geometry, GeometryB geometry)
	RETURNS boolean
	AS $$
	SELECT $1 OPERATOR(@extschema@.~=) $2 AND @extschema@._ST_OrderingEquals($1, $2)
	$$
	LANGUAGE 'sql' IMMUTABLE  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Point(float8, float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'LWGEOM_makepoint'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Polygon(geometry, int)
	RETURNS geometry
	AS $$
	SELECT @extschema@.ST_SetSRID(@extschema@.ST_MakePolygon($1), $2)
	$$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_WKBToSQL(WKB bytea)
	RETURNS geometry
	AS '$libdir/postgis-2.5','LWGEOM_from_WKB'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LocateBetween(Geometry geometry, FromMeasure float8, ToMeasure float8, LeftRightOffset float8 default 0.0)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_LocateBetween'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LocateAlong(Geometry geometry, Measure float8, LeftRightOffset float8 default 0.0)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_LocateAlong'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_LocateBetweenElevations(Geometry geometry, FromElevation float8, ToElevation float8)
	RETURNS geometry
	AS '$libdir/postgis-2.5', 'ST_LocateBetweenElevations'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_InterpolatePoint(Line geometry, Point geometry)
	RETURNS float8
	AS '$libdir/postgis-2.5', 'ST_InterpolatePoint'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION contains_2d(box2df, geometry)
RETURNS boolean
AS '$libdir/postgis-2.5','gserialized_contains_box2df_geom_2d'
LANGUAGE 'c' IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION is_contained_2d(box2df, geometry)
RETURNS boolean
AS '$libdir/postgis-2.5','gserialized_within_box2df_geom_2d'
LANGUAGE 'c' IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION overlaps_2d(box2df, geometry)
RETURNS boolean
AS '$libdir/postgis-2.5','gserialized_overlaps_box2df_geom_2d'
LANGUAGE 'c' IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION overlaps_2d(box2df, box2df)
RETURNS boolean
AS '$libdir/postgis-2.5','gserialized_contains_box2df_box2df_2d'
LANGUAGE 'c' IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION contains_2d(box2df, box2df)
RETURNS boolean
AS '$libdir/postgis-2.5','gserialized_contains_box2df_box2df_2d'
LANGUAGE 'c' IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION is_contained_2d(box2df, box2df)
RETURNS boolean
AS '$libdir/postgis-2.5','gserialized_contains_box2df_box2df_2d'
LANGUAGE 'c' IMMUTABLE STRICT;
-- Operator box2df ~ -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR ~ (
	LEFTARG    = box2df,
	RIGHTARG   = geometry,
	PROCEDURE  = contains_2d,
	COMMUTATOR = @
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator box2df @ -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR @ (
	LEFTARG    = box2df,
	RIGHTARG   = geometry,
	PROCEDURE  = is_contained_2d,
	COMMUTATOR = ~
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator box2df && -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR && (
	LEFTARG    = box2df,
	RIGHTARG   = geometry,
	PROCEDURE  = overlaps_2d,
	COMMUTATOR = &&
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION contains_2d(geometry, box2df)
RETURNS boolean
AS
	'SELECT $2 OPERATOR(@extschema@.@) $1;'
LANGUAGE SQL IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION is_contained_2d(geometry, box2df)
RETURNS boolean
AS
	'SELECT $2 OPERATOR(@extschema@.~) $1;'
LANGUAGE SQL IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION overlaps_2d(geometry, box2df)
RETURNS boolean
AS
	'SELECT $2 OPERATOR(@extschema@.&&) $1;'
LANGUAGE SQL IMMUTABLE STRICT;
-- Operator geometry ~ -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR ~ (
	LEFTARG = geometry,
	RIGHTARG = box2df,
	COMMUTATOR = @,
	PROCEDURE  = contains_2d
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geometry @ -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR @ (
	LEFTARG = geometry,
	RIGHTARG = box2df,
	COMMUTATOR = ~,
	PROCEDURE = is_contained_2d
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geometry && -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR && (
	LEFTARG    = geometry,
	RIGHTARG   = box2df,
	PROCEDURE  = overlaps_2d,
	COMMUTATOR = &&
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator box2df && -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR && (
	LEFTARG   = box2df,
	RIGHTARG  = box2df,
	PROCEDURE = overlaps_2d,
	COMMUTATOR = &&
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator box2df @ -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR @ (
	LEFTARG   = box2df,
	RIGHTARG  = box2df,
	PROCEDURE = is_contained_2d,
	COMMUTATOR = ~
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator box2df ~ -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR ~ (
	LEFTARG   = box2df,
	RIGHTARG  = box2df,
	PROCEDURE = contains_2d,
	COMMUTATOR = @
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION overlaps_nd(gidx, geometry)
RETURNS boolean
AS '$libdir/postgis-2.5','gserialized_gidx_geom_overlaps'
LANGUAGE 'c' IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION overlaps_nd(gidx, gidx)
RETURNS boolean
AS '$libdir/postgis-2.5','gserialized_gidx_gidx_overlaps'
LANGUAGE 'c' IMMUTABLE STRICT;
-- Operator gidx &&& -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR &&& (
	LEFTARG    = gidx,
	RIGHTARG   = geometry,
	PROCEDURE  = overlaps_nd,
	COMMUTATOR = &&&
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION overlaps_nd(geometry, gidx)
RETURNS boolean
AS
	'SELECT $2 OPERATOR(@extschema@.&&&) $1;'
LANGUAGE SQL IMMUTABLE STRICT;
-- Operator geometry &&& -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR &&& (
	LEFTARG    = geometry,
	RIGHTARG   = gidx,
	PROCEDURE  = overlaps_nd,
	COMMUTATOR = &&&
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator gidx &&& -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR &&& (
	LEFTARG   = gidx,
	RIGHTARG  = gidx,
	PROCEDURE = overlaps_nd,
	COMMUTATOR = &&&
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geom2d_brin_inclusion_add_value(internal, internal, internal, internal) RETURNS boolean
	AS '$libdir/postgis-2.5','geom2d_brin_inclusion_add_value'
	LANGUAGE 'c';
CREATE OR REPLACE FUNCTION geom3d_brin_inclusion_add_value(internal, internal, internal, internal) RETURNS boolean
	AS '$libdir/postgis-2.5','geom3d_brin_inclusion_add_value'
	LANGUAGE 'c';
CREATE OR REPLACE FUNCTION geom4d_brin_inclusion_add_value(internal, internal, internal, internal) RETURNS boolean
	AS '$libdir/postgis-2.5','geom4d_brin_inclusion_add_value'
	LANGUAGE 'c';
-- Operator class brin_geometry_inclusion_ops_2d -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$
    CREATE OPERATOR CLASS brin_geometry_inclusion_ops_2d
  DEFAULT FOR TYPE geometry
  USING brin AS
    FUNCTION      1        brin_inclusion_opcinfo(internal),
    FUNCTION      2        geom2d_brin_inclusion_add_value(internal, internal, internal, internal),
    FUNCTION      3        brin_inclusion_consistent(internal, internal, internal),
    FUNCTION      4        brin_inclusion_union(internal, internal, internal),
    OPERATOR      3         &&(box2df, box2df),
    OPERATOR      3         &&(box2df, geometry),
    OPERATOR      3         &&(geometry, box2df),
    OPERATOR      3        &&(geometry, geometry),
    OPERATOR      7         ~(box2df, box2df),
    OPERATOR      7         ~(box2df, geometry),
    OPERATOR      7         ~(geometry, box2df),
    OPERATOR      7        ~(geometry, geometry),
    OPERATOR      8         @(box2df, box2df),
    OPERATOR      8         @(box2df, geometry),
    OPERATOR      8         @(geometry, box2df),
    OPERATOR      8        @(geometry, geometry),
  STORAGE box2df;
    $postgis_proc_upgrade_parsed_def$;
  END IF; -- version_from >= 203
END
$postgis_proc_upgrade$;
-- Operator class brin_geometry_inclusion_ops_3d -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$
    CREATE OPERATOR CLASS brin_geometry_inclusion_ops_3d
  FOR TYPE geometry
  USING brin AS
    FUNCTION      1        brin_inclusion_opcinfo(internal) ,
    FUNCTION      2        geom3d_brin_inclusion_add_value(internal, internal, internal, internal),
    FUNCTION      3        brin_inclusion_consistent(internal, internal, internal),
    FUNCTION      4        brin_inclusion_union(internal, internal, internal),
    OPERATOR      3        &&&(geometry, geometry),
    OPERATOR      3        &&&(geometry, gidx),
    OPERATOR      3        &&&(gidx, geometry),
    OPERATOR      3        &&&(gidx, gidx),
  STORAGE gidx;
    $postgis_proc_upgrade_parsed_def$;
  END IF; -- version_from >= 203
END
$postgis_proc_upgrade$;
-- Operator class brin_geometry_inclusion_ops_4d -- LastUpdated: 203
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 203 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$
    CREATE OPERATOR CLASS brin_geometry_inclusion_ops_4d
  FOR TYPE geometry
  USING brin AS
    FUNCTION      1        brin_inclusion_opcinfo(internal),
    FUNCTION      2        geom4d_brin_inclusion_add_value(internal, internal, internal, internal),
    FUNCTION      3        brin_inclusion_consistent(internal, internal, internal),
    FUNCTION      4        brin_inclusion_union(internal, internal, internal),
    OPERATOR      3        &&&(geometry, geometry),
    OPERATOR      3        &&&(geometry, gidx),
    OPERATOR      3        &&&(gidx, geometry),
    OPERATOR      3        &&&(gidx, gidx),
  STORAGE gidx;
    $postgis_proc_upgrade_parsed_def$;
  END IF; -- version_from >= 203
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_concavehull(param_inputgeom geometry)
  RETURNS geometry AS
$$
	DECLARE
	vexhull @extschema@.geometry;
	var_resultgeom @extschema@.geometry;
	var_inputgeom @extschema@.geometry;
	vexring @extschema@.geometry;
	cavering @extschema@.geometry;
	cavept @extschema@.geometry[];
	seglength double precision;
	var_tempgeom @extschema@.geometry;
	scale_factor float := 1;
	i integer;
	BEGIN
		-- First compute the ConvexHull of the geometry
		vexhull := @extschema@.ST_ConvexHull(param_inputgeom);
		var_inputgeom := param_inputgeom;
		--A point really has no concave hull
		IF @extschema@.ST_GeometryType(vexhull) = 'ST_Point' OR @extschema@.ST_GeometryType(vexHull) = 'ST_LineString' THEN
			RETURN vexhull;
		END IF;

		-- convert the hull perimeter to a linestring so we can manipulate individual points
		vexring := CASE WHEN @extschema@.ST_GeometryType(vexhull) = 'ST_LineString' THEN vexhull ELSE @extschema@.ST_ExteriorRing(vexhull) END;
		IF abs(@extschema@.ST_X(@extschema@.ST_PointN(vexring,1))) < 1 THEN --scale the geometry to prevent stupid precision errors - not sure it works so make low for now
			scale_factor := 100;
			vexring := @extschema@.ST_Scale(vexring, scale_factor,scale_factor);
			var_inputgeom := @extschema@.ST_Scale(var_inputgeom, scale_factor, scale_factor);
			--RAISE NOTICE 'Scaling';
		END IF;
		seglength := @extschema@.ST_Length(vexring)/least(@extschema@.ST_NPoints(vexring)*2,1000) ;

		vexring := @extschema@.ST_Segmentize(vexring, seglength);
		-- find the point on the original geom that is closest to each point of the convex hull and make a new linestring out of it.
		cavering := @extschema@.ST_Collect(
			ARRAY(

				SELECT
					@extschema@.ST_ClosestPoint(var_inputgeom, pt ) As the_geom
					FROM (
						SELECT  @extschema@.ST_PointN(vexring, n ) As pt, n
							FROM
							generate_series(1, @extschema@.ST_NPoints(vexring) ) As n
						) As pt

				)
			)
		;

		var_resultgeom := @extschema@.ST_MakeLine(geom)
			FROM @extschema@.ST_Dump(cavering) As foo;

		IF @extschema@.ST_IsSimple(var_resultgeom) THEN
			var_resultgeom := @extschema@.ST_MakePolygon(var_resultgeom);
			--RAISE NOTICE 'is Simple: %', var_resultgeom;
		ELSE 
			--RAISE NOTICE 'is not Simple: %', var_resultgeom;
			var_resultgeom := @extschema@.ST_ConvexHull(var_resultgeom);
		END IF;

		IF scale_factor > 1 THEN -- scale the result back
			var_resultgeom := @extschema@.ST_Scale(var_resultgeom, 1/scale_factor, 1/scale_factor);
		END IF;

		-- make sure result covers original (#3638)
		-- Using ST_UnaryUnion since SFCGAL doesn't replace with its own implementation
		-- and SFCGAL one chokes for some reason
		var_resultgeom := @extschema@.ST_UnaryUnion(@extschema@.ST_Collect(param_inputgeom, var_resultgeom) );
		RETURN var_resultgeom;

	END;
$$
  LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_ConcaveHull(param_geom geometry, param_pctconvex float, param_allow_holes boolean DEFAULT false) RETURNS geometry AS
$$
	DECLARE
		var_convhull @extschema@.geometry := @extschema@.ST_ForceSFS(@extschema@.ST_ConvexHull(param_geom));
		var_param_geom @extschema@.geometry := @extschema@.ST_ForceSFS(param_geom);
		var_initarea float := @extschema@.ST_Area(var_convhull);
		var_newarea float := var_initarea;
		var_div integer := 6; 
		var_tempgeom @extschema@.geometry;
		var_tempgeom2 @extschema@.geometry;
		var_cent @extschema@.geometry;
		var_geoms @extschema@.geometry[4]; 
		var_enline @extschema@.geometry;
		var_resultgeom @extschema@.geometry;
		var_atempgeoms @extschema@.geometry[];
		var_buf float := 1; 
	BEGIN
		-- We start with convex hull as our base
		var_resultgeom := var_convhull;

		IF param_pctconvex = 1 THEN
			-- this is the same as asking for the convex hull
			return var_resultgeom;
		ELSIF @extschema@.ST_GeometryType(var_param_geom) = 'ST_Polygon' THEN -- it is as concave as it is going to get
			IF param_allow_holes THEN -- leave the holes
				RETURN var_param_geom;
			ELSE -- remove the holes
				var_resultgeom := @extschema@.ST_MakePolygon(@extschema@.ST_ExteriorRing(var_param_geom));
				RETURN var_resultgeom;
			END IF;
		END IF;
		IF @extschema@.ST_Dimension(var_resultgeom) > 1 AND param_pctconvex BETWEEN 0 and 0.98 THEN
		-- get linestring that forms envelope of geometry
			var_enline := @extschema@.ST_Boundary(@extschema@.ST_Envelope(var_param_geom));
			var_buf := @extschema@.ST_Length(var_enline)/1000.0;
			IF @extschema@.ST_GeometryType(var_param_geom) = 'ST_MultiPoint' AND @extschema@.ST_NumGeometries(var_param_geom) BETWEEN 4 and 200 THEN
			-- we make polygons out of points since they are easier to cave in.
			-- Note we limit to between 4 and 200 points because this process is slow and gets quadratically slow
				var_buf := sqrt(@extschema@.ST_Area(var_convhull)*0.8/(@extschema@.ST_NumGeometries(var_param_geom)*@extschema@.ST_NumGeometries(var_param_geom)));
				var_atempgeoms := ARRAY(SELECT geom FROM @extschema@.ST_DumpPoints(var_param_geom));
				-- 5 and 10 and just fudge factors
				var_tempgeom := @extschema@.ST_Union(ARRAY(SELECT geom
						FROM (
						-- fuse near neighbors together
						SELECT DISTINCT ON (i) i,  @extschema@.ST_Distance(var_atempgeoms[i],var_atempgeoms[j]), @extschema@.ST_Buffer(@extschema@.ST_MakeLine(var_atempgeoms[i], var_atempgeoms[j]) , var_buf*5, 'quad_segs=3') As geom
								FROM generate_series(1,array_upper(var_atempgeoms, 1)) As i
									INNER JOIN generate_series(1,array_upper(var_atempgeoms, 1)) As j
										ON (
								 NOT @extschema@.ST_Intersects(var_atempgeoms[i],var_atempgeoms[j])
									AND @extschema@.ST_DWithin(var_atempgeoms[i],var_atempgeoms[j], var_buf*10)
									)
								UNION ALL
						-- catch the ones with no near neighbors
								SELECT i, 0, @extschema@.ST_Buffer(var_atempgeoms[i] , var_buf*10, 'quad_segs=3') As geom
								FROM generate_series(1,array_upper(var_atempgeoms, 1)) As i
									LEFT JOIN generate_series(ceiling(array_upper(var_atempgeoms,1)/2)::integer,array_upper(var_atempgeoms, 1)) As j
										ON (
								 NOT @extschema@.ST_Intersects(var_atempgeoms[i],var_atempgeoms[j])
									AND @extschema@.ST_DWithin(var_atempgeoms[i],var_atempgeoms[j], var_buf*10)
									)
									WHERE j IS NULL
								ORDER BY 1, 2
							) As foo	) );
				IF @extschema@.ST_IsValid(var_tempgeom) AND @extschema@.ST_GeometryType(var_tempgeom) = 'ST_Polygon' THEN
					var_tempgeom := @extschema@.ST_ForceSFS(@extschema@.ST_Intersection(var_tempgeom, var_convhull));
					IF param_allow_holes THEN
						var_param_geom := var_tempgeom;
					ELSIF @extschema@.ST_GeometryType(var_tempgeom) = 'ST_Polygon' THEN
						var_param_geom := @extschema@.ST_ForceSFS(@extschema@.ST_MakePolygon(@extschema@.ST_ExteriorRing(var_tempgeom)));
					ELSE
						var_param_geom := @extschema@.ST_ForceSFS(@extschema@.ST_ConvexHull(var_param_geom));
					END IF;
					-- make sure result covers original (#3638)
					var_param_geom := @extschema@.ST_Union(param_geom, var_param_geom);
					return var_param_geom;
				ELSIF @extschema@.ST_IsValid(var_tempgeom) THEN
					var_param_geom := @extschema@.ST_ForceSFS(@extschema@.ST_Intersection(var_tempgeom, var_convhull));
				END IF;
			END IF;

			IF @extschema@.ST_GeometryType(var_param_geom) = 'ST_Polygon' THEN
				IF NOT param_allow_holes THEN
					var_param_geom := @extschema@.ST_ForceSFS(@extschema@.ST_MakePolygon(@extschema@.ST_ExteriorRing(var_param_geom)));
				END IF;
				-- make sure result covers original (#3638)
				--var_param_geom := @extschema@.ST_Union(param_geom, var_param_geom);
				return var_param_geom;
			END IF;
            var_cent := @extschema@.ST_Centroid(var_param_geom);
            IF (@extschema@.ST_XMax(var_enline) - @extschema@.ST_XMin(var_enline) ) > var_buf AND (@extschema@.ST_YMax(var_enline) - @extschema@.ST_YMin(var_enline) ) > var_buf THEN
                    IF @extschema@.ST_Dwithin(@extschema@.ST_Centroid(var_convhull) , @extschema@.ST_Centroid(@extschema@.ST_Envelope(var_param_geom)), var_buf/2) THEN
                -- If the geometric dimension is > 1 and the object is symettric (cutting at centroid will not work -- offset a bit)
                        var_cent := @extschema@.ST_Translate(var_cent, (@extschema@.ST_XMax(var_enline) - @extschema@.ST_XMin(var_enline))/1000,  (@extschema@.ST_YMAX(var_enline) - @extschema@.ST_YMin(var_enline))/1000);
                    ELSE
                        -- uses closest point on geometry to centroid. I can't explain why we are doing this
                        var_cent := @extschema@.ST_ClosestPoint(var_param_geom,var_cent);
                    END IF;
                    IF @extschema@.ST_DWithin(var_cent, var_enline,var_buf) THEN
                        var_cent := @extschema@.ST_centroid(@extschema@.ST_Envelope(var_param_geom));
                    END IF;
                    -- break envelope into 4 triangles about the centroid of the geometry and returned the clipped geometry in each quadrant
                    FOR i in 1 .. 4 LOOP
                       var_geoms[i] := @extschema@.ST_MakePolygon(@extschema@.ST_MakeLine(ARRAY[@extschema@.ST_PointN(var_enline,i), @extschema@.ST_PointN(var_enline,i+1), var_cent, @extschema@.ST_PointN(var_enline,i)]));
                       var_geoms[i] := @extschema@.ST_ForceSFS(@extschema@.ST_Intersection(var_param_geom, @extschema@.ST_Buffer(var_geoms[i],var_buf)));
                       IF @extschema@.ST_IsValid(var_geoms[i]) THEN

                       ELSE
                            var_geoms[i] := @extschema@.ST_BuildArea(@extschema@.ST_MakeLine(ARRAY[@extschema@.ST_PointN(var_enline,i), @extschema@.ST_PointN(var_enline,i+1), var_cent, @extschema@.ST_PointN(var_enline,i)]));
                       END IF;
                    END LOOP;
                    var_tempgeom := @extschema@.ST_Union(ARRAY[@extschema@.ST_ConvexHull(var_geoms[1]), @extschema@.ST_ConvexHull(var_geoms[2]) , @extschema@.ST_ConvexHull(var_geoms[3]), @extschema@.ST_ConvexHull(var_geoms[4])]);
                    --RAISE NOTICE 'Curr vex % ', @extschema@.ST_AsText(var_tempgeom);
                    IF @extschema@.ST_Area(var_tempgeom) <= var_newarea AND @extschema@.ST_IsValid(var_tempgeom)  THEN --AND @extschema@.ST_GeometryType(var_tempgeom) ILIKE '%Polygon'

                        var_tempgeom := @extschema@.ST_Buffer(@extschema@.ST_ConcaveHull(var_geoms[1],least(param_pctconvex + param_pctconvex/var_div),true),var_buf, 'quad_segs=2');
                        FOR i IN 1 .. 4 LOOP
                            var_geoms[i] := @extschema@.ST_Buffer(@extschema@.ST_ConcaveHull(var_geoms[i],least(param_pctconvex + param_pctconvex/var_div),true), var_buf, 'quad_segs=2');
                            IF @extschema@.ST_IsValid(var_geoms[i]) Then
                                var_tempgeom := @extschema@.ST_Union(var_tempgeom, var_geoms[i]);
                            ELSE
                                RAISE NOTICE 'Not valid % %', i, @extschema@.ST_AsText(var_tempgeom);
                                var_tempgeom := @extschema@.ST_Union(var_tempgeom, @extschema@.ST_ConvexHull(var_geoms[i]));
                            END IF;
                        END LOOP;

                        --RAISE NOTICE 'Curr concave % ', @extschema@.ST_AsText(var_tempgeom);
                        IF @extschema@.ST_IsValid(var_tempgeom) THEN
                            var_resultgeom := var_tempgeom;
                        END IF;
                        var_newarea := @extschema@.ST_Area(var_resultgeom);
                    ELSIF @extschema@.ST_IsValid(var_tempgeom) THEN
                        var_resultgeom := var_tempgeom;
                    END IF;

                    IF @extschema@.ST_NumGeometries(var_resultgeom) > 1  THEN
                        var_tempgeom := @extschema@._ST_ConcaveHull(var_resultgeom);
                        IF @extschema@.ST_IsValid(var_tempgeom) AND @extschema@.ST_GeometryType(var_tempgeom) ILIKE 'ST_Polygon' THEN
                            var_resultgeom := var_tempgeom;
                        ELSE
                            var_resultgeom := @extschema@.ST_Buffer(var_tempgeom,var_buf, 'quad_segs=2');
                        END IF;
                    END IF;
                    IF param_allow_holes = false THEN
                    -- only keep exterior ring since we do not want holes
                        var_resultgeom := @extschema@.ST_MakePolygon(@extschema@.ST_ExteriorRing(var_resultgeom));
                    END IF;
                ELSE
                    var_resultgeom := @extschema@.ST_Buffer(var_resultgeom,var_buf);
                END IF;
                var_resultgeom := @extschema@.ST_ForceSFS(@extschema@.ST_Intersection(var_resultgeom, @extschema@.ST_ConvexHull(var_param_geom)));
            ELSE
                -- dimensions are too small to cut
                var_resultgeom := @extschema@._ST_ConcaveHull(var_param_geom);
            END IF;

            RETURN var_resultgeom;
	END;
$$
LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_AsX3D(int4, geometry, int4, int4, text)
	RETURNS TEXT
	AS '$libdir/postgis-2.5','LWGEOM_asX3D'
	LANGUAGE 'c' IMMUTABLE  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_AsX3D(geom geometry, maxdecimaldigits integer DEFAULT 15, options integer DEFAULT 0)
	RETURNS TEXT
	AS $$SELECT @extschema@._ST_AsX3D(3,$1,$2,$3,'');$$
	LANGUAGE 'sql' IMMUTABLE  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Angle(line1 geometry, line2 geometry)
	RETURNS float8 AS 'SELECT ST_Angle(St_StartPoint($1), ST_EndPoint($1), St_StartPoint($2), ST_EndPoint($2))'
	LANGUAGE 'sql' IMMUTABLE STRICT;
GRANT SELECT ON TABLE geography_columns TO public;
GRANT SELECT ON TABLE geometry_columns TO public;
GRANT SELECT ON TABLE spatial_ref_sys TO public;


-- moved to separate file cause its invovled



-- ---------- ---------- ---------- ---------- ---------- ---------- ----------
-- SP-GiST 2D Support Functions
-- ---------- ---------- ---------- ---------- ---------- ---------- ----------
-- Availability: 2.5.0
CREATE OR REPLACE FUNCTION geometry_spgist_config_2d(internal, internal)
	RETURNS void
	AS '$libdir/postgis-2.5' ,'gserialized_spgist_config_2d'
	LANGUAGE C IMMUTABLE STRICT  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_spgist_choose_2d(internal, internal)
	RETURNS void
	AS '$libdir/postgis-2.5' ,'gserialized_spgist_choose_2d'
	LANGUAGE C IMMUTABLE STRICT  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_spgist_picksplit_2d(internal, internal)
	RETURNS void
	AS '$libdir/postgis-2.5' ,'gserialized_spgist_picksplit_2d'
	LANGUAGE C IMMUTABLE STRICT  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_spgist_inner_consistent_2d(internal, internal)
	RETURNS void
	AS '$libdir/postgis-2.5' ,'gserialized_spgist_inner_consistent_2d'
	LANGUAGE C IMMUTABLE STRICT  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_spgist_leaf_consistent_2d(internal, internal)
	RETURNS bool
	AS '$libdir/postgis-2.5' ,'gserialized_spgist_leaf_consistent_2d'
	LANGUAGE C IMMUTABLE STRICT  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_spgist_compress_2d(internal)
	RETURNS internal
	AS '$libdir/postgis-2.5' ,'gserialized_spgist_compress_2d'
	LANGUAGE C IMMUTABLE STRICT  PARALLEL SAFE;
-- Operator class spgist_geometry_ops_2d -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$
    CREATE OPERATOR CLASS spgist_geometry_ops_2d
	DEFAULT FOR TYPE geometry USING SPGIST AS
	OPERATOR        1        <<  ,
	OPERATOR        2        &<	 ,
	OPERATOR        3        &&  ,
	OPERATOR        4        &>	 ,
	OPERATOR        5        >>	 ,
	OPERATOR        6        ~=	 ,
	OPERATOR        7        ~	 ,
	OPERATOR        8        @	 ,
	OPERATOR        9        &<| ,
	OPERATOR        10       <<| ,
	OPERATOR        11       |>> ,
	OPERATOR        12       |&> ,
	FUNCTION		1		geometry_spgist_config_2d(internal, internal),
	FUNCTION		2		geometry_spgist_choose_2d(internal, internal),
	FUNCTION		3		geometry_spgist_picksplit_2d(internal, internal),
	FUNCTION		4		geometry_spgist_inner_consistent_2d(internal, internal),
	FUNCTION		5		geometry_spgist_leaf_consistent_2d(internal, internal),
	FUNCTION		6		geometry_spgist_compress_2d(internal);
    $postgis_proc_upgrade_parsed_def$;
  END IF; -- version_from >= 205
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_overlaps_3d(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5' ,'gserialized_overlaps_3d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_contains_3d(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5' ,'gserialized_contains_3d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_contained_3d(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5' ,'gserialized_contained_3d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_same_3d(geom1 geometry, geom2 geometry)
	RETURNS boolean
	AS '$libdir/postgis-2.5' ,'gserialized_same_3d'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator geometry &/& -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR &/& (
	PROCEDURE = geometry_overlaps_3d,
	LEFTARG = geometry, RIGHTARG = geometry,
	COMMUTATOR = &/&,
	RESTRICT = gserialized_gist_sel_nd, JOIN = gserialized_gist_joinsel_nd
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geometry @>> -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR @>> (
	PROCEDURE = geometry_contains_3d,
	LEFTARG = geometry, RIGHTARG = geometry,
	COMMUTATOR = <<@,
	RESTRICT = gserialized_gist_sel_nd, JOIN = gserialized_gist_joinsel_nd
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geometry <<@ -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR <<@ (
	PROCEDURE = geometry_contained_3d,
	LEFTARG = geometry, RIGHTARG = geometry,
	COMMUTATOR = @>>,
	RESTRICT = gserialized_gist_sel_nd, JOIN = gserialized_gist_joinsel_nd
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geometry ~== -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR ~== (
	PROCEDURE = geometry_same_3d,
	LEFTARG = geometry, RIGHTARG = geometry,
	COMMUTATOR = ~==,
	RESTRICT = gserialized_gist_sel_nd, JOIN = gserialized_gist_joinsel_nd
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION geometry_spgist_config_3d(internal, internal)
	RETURNS void
	AS '$libdir/postgis-2.5', 'gserialized_spgist_config_3d'
	LANGUAGE C IMMUTABLE STRICT  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_spgist_choose_3d(internal, internal)
	RETURNS void
	AS '$libdir/postgis-2.5', 'gserialized_spgist_choose_3d'
	LANGUAGE C IMMUTABLE STRICT  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_spgist_picksplit_3d(internal, internal)
	RETURNS void
	AS '$libdir/postgis-2.5', 'gserialized_spgist_picksplit_3d'
	LANGUAGE C IMMUTABLE STRICT  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_spgist_inner_consistent_3d(internal, internal)
	RETURNS void
	AS '$libdir/postgis-2.5', 'gserialized_spgist_inner_consistent_3d'
	LANGUAGE C IMMUTABLE STRICT  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_spgist_leaf_consistent_3d(internal, internal)
	RETURNS bool
	AS '$libdir/postgis-2.5', 'gserialized_spgist_leaf_consistent_3d'
	LANGUAGE C IMMUTABLE STRICT  PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_spgist_compress_3d(internal)
	RETURNS internal
	AS '$libdir/postgis-2.5', 'gserialized_spgist_compress_3d'
	LANGUAGE C IMMUTABLE STRICT  PARALLEL SAFE;
-- Operator class spgist_geometry_ops_3d -- LastUpdated: 205
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 205 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$
    CREATE OPERATOR CLASS spgist_geometry_ops_3d
	FOR TYPE geometry USING SPGIST AS
	OPERATOR        3        &/&	,
	OPERATOR        6        ~==	,
	OPERATOR        7        @>>	,
	OPERATOR        8        <<@	,
	FUNCTION	1	geometry_spgist_config_3d(internal, internal),
	FUNCTION	2	geometry_spgist_choose_3d(internal, internal),
	FUNCTION	3	geometry_spgist_picksplit_3d(internal, internal),
	FUNCTION	4	geometry_spgist_inner_consistent_3d(internal, internal),
	FUNCTION	5	geometry_spgist_leaf_consistent_3d(internal, internal),
	FUNCTION	6	geometry_spgist_compress_3d(internal);
    $postgis_proc_upgrade_parsed_def$;
  END IF; -- version_from >= 205
END
$postgis_proc_upgrade$;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP TABLE _postgis_upgrade_info');
DROP TABLE _postgis_upgrade_info;
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--
--
-- PostGIS - Spatial Types for PostgreSQL
-- http://postgis.net
--
-- Copyright (C) 2011-2012 Sandro Santilli <strk@kbt.io>
-- Copyright (C) 2010-2012 Regina Obe <lr@pcorp.us>
-- Copyright (C) 2009      Paul Ramsey <pramsey@cleverelephant.ca>
-- Modifications Copyright (c) 2017 - Present Pivotal Software, Inc. All Rights Reserved.
--
-- This is free software; you can redistribute and/or modify it under
-- the terms of the GNU General Public Licence. See the COPYING file.
--
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--
-- This file contains drop commands for obsoleted items that need
-- to be dropped _after_ upgrade of old functions.
-- Changes to this file affect postgis_upgrade*.sql script.
--
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

-- First drop old aggregates
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS memgeomunion(geometry)');
DROP AGGREGATE IF EXISTS memgeomunion(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS geomunion(geometry)');
DROP AGGREGATE IF EXISTS geomunion(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS polygonize(geometry)');
DROP AGGREGATE IF EXISTS polygonize(geometry); -- Deprecated in 1.2.3, Dropped in 2.0.0
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS collect(geometry)');
DROP AGGREGATE IF EXISTS collect(geometry); -- Deprecated in 1.2.3, Dropped in 2.0.0
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS st_geomunion(geometry)');
DROP AGGREGATE IF EXISTS st_geomunion(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS accum_old(geometry)');
DROP AGGREGATE IF EXISTS accum_old(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS st_accum_old(geometry)');
DROP AGGREGATE IF EXISTS st_accum_old(geometry);

SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS st_astwkb_agg(geometry, integer)');
DROP AGGREGATE IF EXISTS st_astwkb_agg(geometry, integer); -- temporarely introduced before 2.2.0 final
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS st_astwkb_agg(geometry, integer, bigint)');
DROP AGGREGATE IF EXISTS st_astwkb_agg(geometry, integer, bigint); -- temporarely introduced before 2.2.0 final
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS st_astwkbagg(geometry, integer)');
DROP AGGREGATE IF EXISTS st_astwkbagg(geometry, integer); -- temporarely introduced before 2.2.0 final
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS st_astwkbagg(geometry, integer, bigint)');
DROP AGGREGATE IF EXISTS st_astwkbagg(geometry, integer, bigint); -- temporarely introduced before 2.2.0 final
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS st_astwkbagg(geometry, integer, bigint, boolean)');
DROP AGGREGATE IF EXISTS st_astwkbagg(geometry, integer, bigint, boolean); -- temporarely introduced before 2.2.0 final
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS st_astwkbagg(geometry, integer, bigint, boolean, boolean)');
DROP AGGREGATE IF EXISTS st_astwkbagg(geometry, integer, bigint, boolean, boolean); -- temporarely introduced before 2.2.0 final

-- BEGIN Management functions that now have default param for typmod --
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS AddGeometryColumn(varchar,varchar,varchar,varchar,integer,varchar,integer)');
DROP FUNCTION IF EXISTS AddGeometryColumn(varchar,varchar,varchar,varchar,integer,varchar,integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS AddGeometryColumn(varchar,varchar,varchar,integer,varchar,integer)');
DROP FUNCTION IF EXISTS AddGeometryColumn(varchar,varchar,varchar,integer,varchar,integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS AddGeometryColumn(varchar,varchar,integer,varchar,integer)');
DROP FUNCTION IF EXISTS AddGeometryColumn(varchar,varchar,integer,varchar,integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS populate_geometry_columns()');
DROP FUNCTION IF EXISTS populate_geometry_columns();
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS populate_geometry_columns(oid)');
DROP FUNCTION IF EXISTS populate_geometry_columns(oid);

-- END Management functions now have default parameter for typmod --
-- Then drop old functions
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS box2d_overleft(box2d, box2d)');
DROP FUNCTION IF EXISTS box2d_overleft(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS box2d_overright(box2d, box2d)');
DROP FUNCTION IF EXISTS box2d_overright(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS box2d_left(box2d, box2d)');
DROP FUNCTION IF EXISTS box2d_left(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS box2d_right(box2d, box2d)');
DROP FUNCTION IF EXISTS box2d_right(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS box2d_contain(box2d, box2d)');
DROP FUNCTION IF EXISTS box2d_contain(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS box2d_contained(box2d, box2d)');
DROP FUNCTION IF EXISTS box2d_contained(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS box2d_overlap(box2d, box2d)');
DROP FUNCTION IF EXISTS box2d_overlap(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS box2d_same(box2d, box2d)');
DROP FUNCTION IF EXISTS box2d_same(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS box2d_intersects(box2d, box2d)');
DROP FUNCTION IF EXISTS box2d_intersects(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_area(geography)');
DROP FUNCTION IF EXISTS st_area(geography); -- this one changed to use default parameters
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsGeoJson(geometry)');
DROP FUNCTION IF EXISTS ST_AsGeoJson(geometry); -- this one changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsGeoJson(geography)');
DROP FUNCTION IF EXISTS ST_AsGeoJson(geography); -- this one changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsGeoJson(geometry,int4)');
DROP FUNCTION IF EXISTS ST_AsGeoJson(geometry,int4); -- this one changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsGeoJson(geography,int4)');
DROP FUNCTION IF EXISTS ST_AsGeoJson(geography,int4); -- this one changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsGeoJson(int4,geometry)');
DROP FUNCTION IF EXISTS ST_AsGeoJson(int4,geometry); -- this one changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsGeoJson(int4,geography)');
DROP FUNCTION IF EXISTS ST_AsGeoJson(int4,geography); -- this one changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsGeoJson(int4,geometry,int4)');
DROP FUNCTION IF EXISTS ST_AsGeoJson(int4,geometry,int4); -- this one changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsGeoJson(int4,geography,int4)');
DROP FUNCTION IF EXISTS ST_AsGeoJson(int4,geography,int4); -- this one changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_asgml(geometry)');
DROP FUNCTION IF EXISTS st_asgml(geometry); -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_asgml(geometry, int4)');
DROP FUNCTION IF EXISTS st_asgml(geometry, int4);  -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_asgml(int4, geometry)');
DROP FUNCTION IF EXISTS st_asgml(int4, geometry);  -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_asgml(int4, geometry, int4)');
DROP FUNCTION IF EXISTS st_asgml(int4, geometry, int4);  -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_asgml(int4, geometry, int4,int4)');
DROP FUNCTION IF EXISTS st_asgml(int4, geometry, int4,int4);  -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_asgml(int4, geometry, int4,int4,text)');
DROP FUNCTION IF EXISTS st_asgml(int4, geometry, int4,int4,text); -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_asgml(geography)');
DROP FUNCTION IF EXISTS st_asgml(geography); -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_asgml(geography, int4)');
DROP FUNCTION IF EXISTS st_asgml(geography, int4);  -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_asgml(int4, geography)');
DROP FUNCTION IF EXISTS st_asgml(int4, geography);  -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_asgml(int4, geography, int4)');
DROP FUNCTION IF EXISTS st_asgml(int4, geography, int4);  -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_asgml(int4, geography, int4,int4)');
DROP FUNCTION IF EXISTS st_asgml(int4, geography, int4,int4);  -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_asgml(int4, geography, int4,int4,text)');
DROP FUNCTION IF EXISTS st_asgml(int4, geography, int4,int4,text); -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_asgml(int4, geometry, int4,int4,text)');
DROP FUNCTION IF EXISTS _st_asgml(int4, geometry, int4,int4,text); -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_asgml(int4, geography, int4,int4,text)');
DROP FUNCTION IF EXISTS _st_asgml(int4, geography, int4,int4,text); -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsKML(geometry)');
DROP FUNCTION IF EXISTS ST_AsKML(geometry); -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsKML(geography)');
DROP FUNCTION IF EXISTS ST_AsKML(geography); -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsKML(int4, geometry, int4)');
DROP FUNCTION IF EXISTS ST_AsKML(int4, geometry, int4); -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsKML(int4, geography, int4)');
DROP FUNCTION IF EXISTS ST_AsKML(int4, geography, int4); -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_asx3d(geometry)');
DROP FUNCTION IF EXISTS st_asx3d(geometry); -- this one changed to use default parameters so full function deals with it
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_asx3d(geometry, int4)');
DROP FUNCTION IF EXISTS st_asx3d(geometry, int4); -- introduce variant with opts so get rid of other without ops
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_assvg(geometry)');
DROP FUNCTION IF EXISTS st_assvg(geometry); -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_assvg(geometry,int4)');
DROP FUNCTION IF EXISTS st_assvg(geometry,int4); -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_assvg(geography)');
DROP FUNCTION IF EXISTS st_assvg(geography); -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_assvg(geography,int4)');
DROP FUNCTION IF EXISTS st_assvg(geography,int4); -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box2d_overleft(box2d, box2d)');
DROP FUNCTION IF EXISTS st_box2d_overleft(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box2d_overright(box2d, box2d)');
DROP FUNCTION IF EXISTS st_box2d_overright(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box2d_left(box2d, box2d)');
DROP FUNCTION IF EXISTS st_box2d_left(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box2d_right(box2d, box2d)');
DROP FUNCTION IF EXISTS st_box2d_right(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box2d_contain(box2d, box2d)');
DROP FUNCTION IF EXISTS st_box2d_contain(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box2d_contained(box2d, box2d)');
DROP FUNCTION IF EXISTS st_box2d_contained(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box2d_overlap(box2d, box2d)');
DROP FUNCTION IF EXISTS st_box2d_overlap(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box2d_same(box2d, box2d)');
DROP FUNCTION IF EXISTS st_box2d_same(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box2d_intersects(box2d, box2d)');
DROP FUNCTION IF EXISTS st_box2d_intersects(box2d, box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box2d_in(cstring)');
DROP FUNCTION IF EXISTS st_box2d_in(cstring);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box2d_out(box2d)');
DROP FUNCTION IF EXISTS st_box2d_out(box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box2d(geometry)');
DROP FUNCTION IF EXISTS st_box2d(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box2d(box3d)');
DROP FUNCTION IF EXISTS st_box2d(box3d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box3d(box2d)');
DROP FUNCTION IF EXISTS st_box3d(box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box(box3d)');
DROP FUNCTION IF EXISTS st_box(box3d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box3d(geometry)');
DROP FUNCTION IF EXISTS st_box3d(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_box(geometry)');
DROP FUNCTION IF EXISTS st_box(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_ConcaveHull(geometry,float)');
DROP FUNCTION IF EXISTS ST_ConcaveHull(geometry,float); -- this one changed to use default parameters
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_text(geometry)');
DROP FUNCTION IF EXISTS st_text(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_geometry(box2d)');
DROP FUNCTION IF EXISTS st_geometry(box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_geometry(box3d)');
DROP FUNCTION IF EXISTS st_geometry(box3d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_geometry(text)');
DROP FUNCTION IF EXISTS st_geometry(text);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_geometry(bytea)');
DROP FUNCTION IF EXISTS st_geometry(bytea);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_bytea(geometry)');
DROP FUNCTION IF EXISTS st_bytea(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_addbbox(geometry)');
DROP FUNCTION IF EXISTS st_addbbox(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_dropbbox(geometry)');
DROP FUNCTION IF EXISTS st_dropbbox(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_hasbbox(geometry)');
DROP FUNCTION IF EXISTS st_hasbbox(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS cache_bbox()');
DROP FUNCTION IF EXISTS cache_bbox();
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_cache_bbox()');
DROP FUNCTION IF EXISTS st_cache_bbox();
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_GeoHash(geometry)');
DROP FUNCTION IF EXISTS ST_GeoHash(geometry); -- changed to use default args
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_length(geography)');
DROP FUNCTION IF EXISTS st_length(geography); -- this one changed to use default parameters
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_perimeter(geography)');
DROP FUNCTION IF EXISTS st_perimeter(geography); -- this one changed to use default parameters
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS transform_geometry(geometry,text,text,int)');
DROP FUNCTION IF EXISTS transform_geometry(geometry,text,text,int);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS collector(geometry, geometry)');
DROP FUNCTION IF EXISTS collector(geometry, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_collector(geometry, geometry)');
DROP FUNCTION IF EXISTS st_collector(geometry, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS geom_accum (geometry[],geometry)');
DROP FUNCTION IF EXISTS geom_accum (geometry[],geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_geom_accum (geometry[],geometry)');
DROP FUNCTION IF EXISTS st_geom_accum (geometry[],geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS collect_garray (geometry[])');
DROP FUNCTION IF EXISTS collect_garray (geometry[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_collect_garray (geometry[])');
DROP FUNCTION IF EXISTS st_collect_garray (geometry[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS geosnoop(geometry)');
DROP FUNCTION IF EXISTS geosnoop(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS jtsnoop(geometry)');
DROP FUNCTION IF EXISTS jtsnoop(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_noop(geometry)');
DROP FUNCTION IF EXISTS st_noop(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_max_distance(geometry, geometry)');
DROP FUNCTION IF EXISTS st_max_distance(geometry, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS  ST_MinimumBoundingCircle(geometry)');
DROP FUNCTION IF EXISTS  ST_MinimumBoundingCircle(geometry); --changed to use default parameters
-- Drop internals that should never have existed --
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_geometry_analyze(internal)');
DROP FUNCTION IF EXISTS st_geometry_analyze(internal);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_geometry_in(cstring)');
DROP FUNCTION IF EXISTS st_geometry_in(cstring);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_geometry_out(geometry)');
DROP FUNCTION IF EXISTS st_geometry_out(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_geometry_recv(internal)');
DROP FUNCTION IF EXISTS st_geometry_recv(internal);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_geometry_send(geometry)');
DROP FUNCTION IF EXISTS st_geometry_send(geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_spheroid_in(cstring)');
DROP FUNCTION IF EXISTS st_spheroid_in(cstring);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_spheroid_out(spheroid)');
DROP FUNCTION IF EXISTS st_spheroid_out(spheroid);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_geometry_lt(geometry, geometry)');
DROP FUNCTION IF EXISTS st_geometry_lt(geometry, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_geometry_gt(geometry, geometry)');
DROP FUNCTION IF EXISTS st_geometry_gt(geometry, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_geometry_ge(geometry, geometry)');
DROP FUNCTION IF EXISTS st_geometry_ge(geometry, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_geometry_eq(geometry, geometry)');
DROP FUNCTION IF EXISTS st_geometry_eq(geometry, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_geometry_cmp(geometry, geometry)');
DROP FUNCTION IF EXISTS st_geometry_cmp(geometry, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS SnapToGrid(geometry, float8, float8)');
DROP FUNCTION IF EXISTS SnapToGrid(geometry, float8, float8);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_removerepeatedpoints(geometry)');
DROP FUNCTION IF EXISTS st_removerepeatedpoints(geometry);
-- FIX_ME_POSTGIS_254: Re-enable, when adding support for GEOS 3.5
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_voronoi(geometry, geometry, double precision, boolean)');
DROP FUNCTION IF EXISTS st_voronoi(geometry, geometry, double precision, boolean); --temporarely introduced before 2.3.0 final

SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS geometry_gist_sel_2d (internal, oid, internal, int4)');
DROP FUNCTION IF EXISTS geometry_gist_sel_2d (internal, oid, internal, int4);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS geometry_gist_joinsel_2d(internal, oid, internal, smallint)');
DROP FUNCTION IF EXISTS geometry_gist_joinsel_2d(internal, oid, internal, smallint);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS geography_gist_selectivity (internal, oid, internal, int4)');
DROP FUNCTION IF EXISTS geography_gist_selectivity (internal, oid, internal, int4);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS geography_gist_join_selectivity(internal, oid, internal, smallint)');
DROP FUNCTION IF EXISTS geography_gist_join_selectivity(internal, oid, internal, smallint);

SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsBinary(text)');
DROP FUNCTION IF EXISTS ST_AsBinary(text); -- deprecated in 2.0
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS postgis_uses_stats()');
DROP FUNCTION IF EXISTS postgis_uses_stats(); -- deprecated in 2.0

-- Old accum aggregate support type, removed in 2.5.0
SELECT postgis_extension_drop_if_exists('postgis', 'DROP TYPE IF EXISTS pgis_abs CASCADE');
DROP TYPE IF EXISTS pgis_abs CASCADE;

SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_astwkb(geometry,integer,bigint,bool,bool)');
DROP FUNCTION IF EXISTS st_astwkb(geometry,integer,bigint,bool,bool); -- temporarely introduced before 2.2.0 final
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS pgis_twkb_accum_transfn(internal,geometry,integer)');
DROP FUNCTION IF EXISTS pgis_twkb_accum_transfn(internal,geometry,integer); -- temporarely introduced before 2.2.0 final
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS pgis_twkb_accum_transfn(internal,geometry,integer,bigint)');
DROP FUNCTION IF EXISTS pgis_twkb_accum_transfn(internal,geometry,integer,bigint); -- temporarely introduced before 2.2.0 final
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS pgis_twkb_accum_transfn(internal,geometry,integer,bigint,bool)');
DROP FUNCTION IF EXISTS pgis_twkb_accum_transfn(internal,geometry,integer,bigint,bool); -- temporarely introduced before 2.2.0 final
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS pgis_twkb_accum_transfn(internal,geometry,integer,bigint,bool,bool)');
DROP FUNCTION IF EXISTS pgis_twkb_accum_transfn(internal,geometry,integer,bigint,bool,bool); -- temporarely introduced before 2.2.0 final
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS pgis_twkb_accum_finalfn(internal)');
DROP FUNCTION IF EXISTS pgis_twkb_accum_finalfn(internal); -- temporarely introduced before 2.2.0 final

SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_seteffectivearea(geometry, double precision)');
DROP FUNCTION IF EXISTS st_seteffectivearea(geometry, double precision); -- temporarely introduced before 2.2.0 final

SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS geometry_distance_box_nd(geometry,geometry)');
DROP FUNCTION IF EXISTS geometry_distance_box_nd(geometry,geometry); -- temporarely introduced before 2.2.0 final

SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _ST_DumpPoints( geometry, integer[])');
DROP FUNCTION IF EXISTS _ST_DumpPoints( geometry, integer[]); -- removed 2.4.0, but really should have been removed 2.1.0 when ST_DumpPoints got reimpmented in C

-- Temporary clean-up while we wait to return these to action in dev
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _ST_DistanceRectTree(g1 geometry, g2 geometry)');
DROP FUNCTION IF EXISTS _ST_DistanceRectTree(g1 geometry, g2 geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _ST_DistanceRectTreeCached(g1 geometry, g2 geometry)');
DROP FUNCTION IF EXISTS _ST_DistanceRectTreeCached(g1 geometry, g2 geometry);

DO language 'plpgsql'
$$
BEGIN
IF _postgis_scripts_pgsql_version()::integer >= 96 THEN
-- mark ST_Union agg as parallel safe if it is not already
        BEGIN
            UPDATE pg_proc SET proparallel = 's'
            WHERE oid = 'st_union(geometry)'::regprocedure AND proparallel = 'u';
        EXCEPTION WHEN OTHERS THEN
            RAISE DEBUG 'Could not update st_union(geometry): %', SQLERRM;
        END;
END IF;
END;
$$;

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--
--
-- PostGIS Raster - Raster Type for PostGIS
-- http://trac.osgeo.org/postgis/wiki/WKTRaster
--
-- Copyright (c) 2011 Regina Obe <lr@pcorp.us>
-- Copyright (C) 2011 Regents of the University of California
--   <bkpark@ucdavis.edu>
-- Modifications Copyright (c) 2017 - Present Pivotal Software, Inc. All Rights Reserved.
--
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software Foundation,
-- Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
--
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--
-- WARNING: Any change in this file must be evaluated for compatibility.
--
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--
-- This section is take add / drop things like CASTS, TYPES etc. that have changed
-- Since these are normally excluded from sed upgrade generator
-- they must be explicitly added
-- So that they can immediately be recreated.
-- It is not run thru the sed processor to prevent it from being stripped
-- Note: We put these in separate file from drop since the extension module has
-- to add additional logic to drop them from the extension as well
--
-- TODO: tag each item with the version in which it was changed
--
















































-- drop st_bytea
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (raster AS bytea)');
DROP CAST IF EXISTS (raster AS bytea);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_bytea(raster)');
DROP FUNCTION IF EXISTS st_bytea(raster);

CREATE OR REPLACE FUNCTION bytea(raster)
    RETURNS bytea
    AS '$libdir/rtpostgis-2.5', 'RASTER_to_bytea'
    LANGUAGE 'c' IMMUTABLE STRICT;
CREATE CAST (raster AS bytea)
    WITH FUNCTION bytea(raster) AS ASSIGNMENT;

-- drop box2d
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (raster AS box2d)');
DROP CAST IF EXISTS (raster AS box2d);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS box2d(raster)');
DROP FUNCTION IF EXISTS box2d(raster);

-- make geometry cast ASSIGNMENT
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (raster AS geometry)');
DROP CAST IF EXISTS (raster AS geometry);
CREATE CAST (raster AS geometry)
	WITH FUNCTION st_convexhull(raster) AS ASSIGNMENT;

-- add missing OPERATORs
-- TODO: drop, relying on proc_upgrade.pl output ?
DO LANGUAGE 'plpgsql' $$
BEGIN
	IF NOT EXISTS (
			SELECT
				proname
			FROM pg_proc f
			JOIN pg_type r
				ON r.typname = 'raster'
					AND (f.proargtypes::oid[])[0] = r.oid
			JOIN pg_type g
				ON g.typname = 'geometry'
					AND (f.proargtypes::oid[])[1] = g.oid
			WHERE proname = 'raster_contained_by_geometry'
		) THEN
		CREATE OR REPLACE FUNCTION raster_contained_by_geometry(raster, geometry)
			RETURNS bool
	    AS 'select $1::geometry @ $2'
	    LANGUAGE 'sql' IMMUTABLE STRICT;
		CREATE OPERATOR @ (
			LEFTARG = raster, RIGHTARG = geometry, PROCEDURE = raster_contained_by_geometry,
	    COMMUTATOR = '~',
		  RESTRICT = contsel, JOIN = contjoinsel
		);
	END IF;

	IF NOT EXISTS (
			SELECT
				proname
			FROM pg_proc f
			JOIN pg_type r
				ON r.typname = 'raster'
					AND (f.proargtypes::oid[])[1] = r.oid
			JOIN pg_type g
				ON g.typname = 'geometry'
					AND (f.proargtypes::oid[])[0] = g.oid
			WHERE proname = 'geometry_contained_by_raster'
		) THEN
		CREATE OR REPLACE FUNCTION geometry_contained_by_raster(geometry, raster)
	    RETURNS bool
		  AS 'select $1 @ $2::geometry'
	    LANGUAGE 'sql' IMMUTABLE STRICT;
		CREATE OPERATOR @ (
	    LEFTARG = geometry, RIGHTARG = raster, PROCEDURE = geometry_contained_by_raster,
		  COMMUTATOR = '~',
			RESTRICT = contsel, JOIN = contjoinsel
    );
	END IF;
END;
$$;

--these were renamed to ST_MapAlgebraExpr or argument names changed --
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MapAlgebra(raster, integer, text, text, nodatavaluerepl text)');
DROP FUNCTION IF EXISTS ST_MapAlgebra(raster, integer, text, text, nodatavaluerepl text);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MapAlgebra(raster, pixeltype text, expression text, nodatavaluerepl text)');
DROP FUNCTION IF EXISTS ST_MapAlgebra(raster, pixeltype text, expression text, nodatavaluerepl text);

--signatures or arg names changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MapAlgebraExpr(raster, integer, text, text, text)');
DROP FUNCTION IF EXISTS ST_MapAlgebraExpr(raster, integer, text, text, text);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MapAlgebraExpr(raster, text, text, text)');
DROP FUNCTION IF EXISTS ST_MapAlgebraExpr(raster, text, text, text);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MapalgebraFct(raster, regprocedure)');
DROP FUNCTION IF EXISTS ST_MapalgebraFct(raster, regprocedure);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, text, regprocedure, VARIADIC text[])');
DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, text, regprocedure, VARIADIC text[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, text, regprocedure)');
DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, text, regprocedure);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, regprocedure, VARIADIC text[])');
DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, regprocedure, VARIADIC text[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, integer, regprocedure, variadic text[])');
DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, integer, regprocedure, variadic text[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, integer, text, regprocedure, VARIADIC text[])');
DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, integer, text, regprocedure, VARIADIC text[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, integer, text, regprocedure)');
DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, integer, text, regprocedure);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, integer, regprocedure, variadic text[])');
DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, integer, regprocedure, variadic text[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MapalgebraFct(raster, integer, regprocedure)');
DROP FUNCTION IF EXISTS ST_MapalgebraFct(raster, integer, regprocedure);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, raster, regprocedure, text, text, VARIADIC text[])');
DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, raster, regprocedure, text, text, VARIADIC text[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, integer, raster, integer, regprocedure, text, text, VARIADIC text[])');
DROP FUNCTION IF EXISTS ST_MapAlgebraFct(raster, integer, raster, integer, regprocedure, text, text, VARIADIC text[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_MapAlgebraFctNgb(raster, integer, text, integer, integer, regprocedure, text,  VARIADIC text[])');
DROP FUNCTION IF EXISTS ST_MapAlgebraFctNgb(raster, integer, text, integer, integer, regprocedure, text,  VARIADIC text[]);

--dropped functions
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS  ST_MapAlgebraFct(raster, raster, regprocedure, VARIADIC text[])');
DROP FUNCTION IF EXISTS  ST_MapAlgebraFct(raster, raster, regprocedure, VARIADIC text[]);

--added extra parameter so these are obsolete --
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsRaster(geometry , integer , integer , double precision , double precision , text , double precision , double precision , double precision , double precision )');
DROP FUNCTION IF EXISTS ST_AsRaster(geometry , integer , integer , double precision , double precision , text , double precision , double precision , double precision , double precision );
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsRaster(geometry , integer , integer , text[] , double precision[] , double precision[] , double precision , double precision , double precision , double precision )');
DROP FUNCTION IF EXISTS ST_AsRaster(geometry , integer , integer , text[] , double precision[] , double precision[] , double precision , double precision , double precision , double precision );
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsRaster(geometry , integer , integer , text , double precision , double precision , double precision , double precision , double precision , double precision )');
DROP FUNCTION IF EXISTS ST_AsRaster(geometry , integer , integer , text , double precision , double precision , double precision , double precision , double precision , double precision );
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsRaster(geometry , integer , integer , double precision , double precision , text[] , double precision[] , double precision[] , double precision , double precision )');
DROP FUNCTION IF EXISTS ST_AsRaster(geometry , integer , integer , double precision , double precision , text[] , double precision[] , double precision[] , double precision , double precision );
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsRaster(geometry , integer , integer , double precision , double precision , text[] , double precision[] , double precision[] , double precision , double precision )');
DROP FUNCTION IF EXISTS ST_AsRaster(geometry , integer , integer , double precision , double precision , text[] , double precision[] , double precision[] , double precision , double precision );
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsRaster(geometry , double precision , double precision , text , double precision , double precision , double precision , double precision , double precision , double precision )');
DROP FUNCTION IF EXISTS ST_AsRaster(geometry , double precision , double precision , text , double precision , double precision , double precision , double precision , double precision , double precision );
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_AsRaster(geometry , raster , text , double precision , double precision )');
DROP FUNCTION IF EXISTS ST_AsRaster(geometry , raster , text , double precision , double precision );
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _ST_AsRaster(geometry,double precision , double precision, integer , integer,text[] , double precision[] ,double precision[] ,  double precision,  double precision, double precision,double precision, double precision, double precision,touched boolean)');
DROP FUNCTION IF EXISTS _ST_AsRaster(geometry,double precision , double precision, integer , integer,text[] , double precision[] ,double precision[] ,  double precision,  double precision, double precision,double precision, double precision, double precision,touched boolean);
-- arg names changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _ST_Resample(raster, text, double precision, integer, double precision, double precision, double precision, double precision, double precision, double precision)');
DROP FUNCTION IF EXISTS _ST_Resample(raster, text, double precision, integer, double precision, double precision, double precision, double precision, double precision, double precision);

-- signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_Resample(raster, raster, text, double precision)');
DROP FUNCTION IF EXISTS ST_Resample(raster, raster, text, double precision);

-- default parameters added
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_HasNoBand(raster)');
DROP FUNCTION IF EXISTS ST_HasNoBand(raster);

--function out parameters changed so can not just create or replace
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_BandMetaData(raster, integer)');
DROP FUNCTION IF EXISTS ST_BandMetaData(raster, integer);

--function out parameter changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_BandNoDataValue(raster, integer)');
DROP FUNCTION IF EXISTS ST_BandNoDataValue(raster, integer);
--function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_BandNoDataValue(raster)');
DROP FUNCTION IF EXISTS ST_BandNoDataValue(raster);

--function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_SetGeoReference(raster, text)');
DROP FUNCTION IF EXISTS ST_SetGeoReference(raster, text);
-- signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_SetGeoReference(raster, text, text)');
DROP FUNCTION IF EXISTS ST_SetGeoReference(raster, text, text);

--function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_setbandisnodata(raster)');
DROP FUNCTION IF EXISTS st_setbandisnodata(raster);
-- signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_setbandisnodata(raster, integer)');
DROP FUNCTION IF EXISTS st_setbandisnodata(raster, integer);

--function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_setbandnodatavalue(raster, integer, double precision)');
DROP FUNCTION IF EXISTS st_setbandnodatavalue(raster, integer, double precision);
-- signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_setbandnodatavalue(raster, integer, double precision, boolean)');
DROP FUNCTION IF EXISTS st_setbandnodatavalue(raster, integer, double precision, boolean);

--function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_dumpaspolygons(raster)');
DROP FUNCTION IF EXISTS st_dumpaspolygons(raster);
-- signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_dumpaspolygons(raster, integer)');
DROP FUNCTION IF EXISTS st_dumpaspolygons(raster, integer);

--function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_polygon(raster)');
DROP FUNCTION IF EXISTS st_polygon(raster);
-- signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_polygon(raster, integer)');
DROP FUNCTION IF EXISTS st_polygon(raster, integer);

-- function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_makeemptyraster(int, int, float8, float8, float8, float8, float8, float8)');
DROP FUNCTION IF EXISTS st_makeemptyraster(int, int, float8, float8, float8, float8, float8, float8);
-- signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_makeemptyraster(int, int, float8, float8, float8, float8, float8, float8, int4)');
DROP FUNCTION IF EXISTS st_makeemptyraster(int, int, float8, float8, float8, float8, float8, float8, int4);

-- function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_addband(raster, text)');
DROP FUNCTION IF EXISTS st_addband(raster, text);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_addband(raster, text, float8)');
DROP FUNCTION IF EXISTS st_addband(raster, text, float8);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_addband(raster, int, text)');
DROP FUNCTION IF EXISTS st_addband(raster, int, text);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_addband(raster, int, text, float8)');
DROP FUNCTION IF EXISTS st_addband(raster, int, text, float8);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_addband(raster, raster, int)');
DROP FUNCTION IF EXISTS st_addband(raster, raster, int);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_addband(raster, raster)');
DROP FUNCTION IF EXISTS st_addband(raster, raster);
-- signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_addband(raster, text, float8, float8)');
DROP FUNCTION IF EXISTS st_addband(raster, text, float8, float8);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_addband(raster, int, text, float8, float8)');
DROP FUNCTION IF EXISTS st_addband(raster, int, text, float8, float8);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_addband(raster, raster, int, int)');
DROP FUNCTION IF EXISTS st_addband(raster, raster, int, int);

-- function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_bandisnodata(raster)');
DROP FUNCTION IF EXISTS st_bandisnodata(raster);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_bandisnodata(raster, integer)');
DROP FUNCTION IF EXISTS st_bandisnodata(raster, integer);
-- signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_bandisnodata(raster, integer, boolean)');
DROP FUNCTION IF EXISTS st_bandisnodata(raster, integer, boolean);

-- function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_bandpath(raster)');
DROP FUNCTION IF EXISTS st_bandpath(raster);
-- signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_bandpath(raster, integer)');
DROP FUNCTION IF EXISTS st_bandpath(raster, integer);

-- function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_bandpixeltype(raster)');
DROP FUNCTION IF EXISTS st_bandpixeltype(raster);
-- signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_bandpixeltype(raster, integer)');
DROP FUNCTION IF EXISTS st_bandpixeltype(raster, integer);

-- function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_value(raster, integer, integer, integer)');
DROP FUNCTION IF EXISTS st_value(raster, integer, integer, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_value(raster, integer, integer)');
DROP FUNCTION IF EXISTS st_value(raster, integer, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_value(raster, integer, geometry)');
DROP FUNCTION IF EXISTS st_value(raster, integer, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_value(raster, geometry)');
DROP FUNCTION IF EXISTS st_value(raster, geometry);
-- signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_value(raster, integer, integer, integer, boolean)');
DROP FUNCTION IF EXISTS st_value(raster, integer, integer, integer, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_value(raster, integer, integer, boolean)');
DROP FUNCTION IF EXISTS st_value(raster, integer, integer, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_value(raster, integer, geometry, boolean)');
DROP FUNCTION IF EXISTS st_value(raster, integer, geometry, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_value(raster, geometry, boolean)');
DROP FUNCTION IF EXISTS st_value(raster, geometry, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_value(raster, integer, geometry, double precision)');
DROP FUNCTION IF EXISTS st_value(raster, integer, geometry, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_value(raster, geometry, double precision)');
DROP FUNCTION IF EXISTS st_value(raster, geometry, double precision);

-- function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_georeference(raster)');
DROP FUNCTION IF EXISTS st_georeference(raster);
-- signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_georeference(raster, text)');
DROP FUNCTION IF EXISTS st_georeference(raster, text);

-- function name change
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS dumpaswktpolygons(raster, integer)');
DROP FUNCTION IF EXISTS dumpaswktpolygons(raster, integer);

-- signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_bandmetadata(raster, VARIADIC int[])');
DROP FUNCTION IF EXISTS st_bandmetadata(raster, VARIADIC int[]);

--change to use default parameters
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_PixelAsPolygons(raster)');
DROP FUNCTION IF EXISTS ST_PixelAsPolygons(raster);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_PixelAsPolygons(raster,integer)');
DROP FUNCTION IF EXISTS ST_PixelAsPolygons(raster,integer);

-- TYPE summarystats removed in version 2.1.0
-- TODO: only DROP if source version is 2.1.0
-- See http://trac.osgeo.org/postgis/ticket/2908
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_summarystats(raster,int, boolean)');
DROP FUNCTION IF EXISTS st_summarystats(raster,int, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_summarystats(raster, boolean)');
DROP FUNCTION IF EXISTS st_summarystats(raster, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxsummarystats(raster,int, boolean, double precision)');
DROP FUNCTION IF EXISTS st_approxsummarystats(raster,int, boolean, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxsummarystats(raster,int, double precision)');
DROP FUNCTION IF EXISTS st_approxsummarystats(raster,int, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxsummarystats(raster, boolean, double precision)');
DROP FUNCTION IF EXISTS st_approxsummarystats(raster, boolean, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxsummarystats(raster, double precision)');
DROP FUNCTION IF EXISTS st_approxsummarystats(raster, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_summarystats(text, text,integer, boolean)');
DROP FUNCTION IF EXISTS st_summarystats(text, text,integer, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_summarystats(text, text, boolean)');
DROP FUNCTION IF EXISTS st_summarystats(text, text, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxsummarystats(text, text,integer, boolean, double precision)');
DROP FUNCTION IF EXISTS st_approxsummarystats(text, text,integer, boolean, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxsummarystats(text, text,integer, double precision)');
DROP FUNCTION IF EXISTS st_approxsummarystats(text, text,integer, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxsummarystats(text, text, boolean)');
DROP FUNCTION IF EXISTS st_approxsummarystats(text, text, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxsummarystats(text, text, double precision)');
DROP FUNCTION IF EXISTS st_approxsummarystats(text, text, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_summarystats(raster,int, boolean, double precision)');
DROP FUNCTION IF EXISTS _st_summarystats(raster,int, boolean, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_summarystats(text, text,integer, boolean, double precision)');
DROP FUNCTION IF EXISTS _st_summarystats(text, text,integer, boolean, double precision);

-- remove TYPE quantile
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_quantile(raster, int, boolean, double precision[])');
DROP FUNCTION IF EXISTS st_quantile(raster, int, boolean, double precision[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_quantile(raster, int, double precision[])');
DROP FUNCTION IF EXISTS st_quantile(raster, int, double precision[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_quantile(raster, double precision[])');
DROP FUNCTION IF EXISTS st_quantile(raster, double precision[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxquantile(raster, int, boolean, double precision, double precision[])');
DROP FUNCTION IF EXISTS st_approxquantile(raster, int, boolean, double precision, double precision[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxquantile(raster, int, double precision, double precision[])');
DROP FUNCTION IF EXISTS st_approxquantile(raster, int, double precision, double precision[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxquantile(raster, double precision, double precision[])');
DROP FUNCTION IF EXISTS st_approxquantile(raster, double precision, double precision[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxquantile(raster, double precision[])');
DROP FUNCTION IF EXISTS st_approxquantile(raster, double precision[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_quantile(text, text, int, boolean, double precision[])');
DROP FUNCTION IF EXISTS st_quantile(text, text, int, boolean, double precision[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_quantile(text, text, int, double precision[])');
DROP FUNCTION IF EXISTS st_quantile(text, text, int, double precision[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_quantile(text, text, double precision[])');
DROP FUNCTION IF EXISTS st_quantile(text, text, double precision[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxquantile(text, text, int, boolean, double precision, double precision[])');
DROP FUNCTION IF EXISTS st_approxquantile(text, text, int, boolean, double precision, double precision[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxquantile(text, text, int, double precision, double precision[])');
DROP FUNCTION IF EXISTS st_approxquantile(text, text, int, double precision, double precision[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxquantile(text, text, double precision, double precision[])');
DROP FUNCTION IF EXISTS st_approxquantile(text, text, double precision, double precision[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxquantile(text, text, double precision[])');
DROP FUNCTION IF EXISTS st_approxquantile(text, text, double precision[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_quantile(raster, int, boolean, double precision, double precision[])');
DROP FUNCTION IF EXISTS _st_quantile(raster, int, boolean, double precision, double precision[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_quantile(text, text, int, boolean, double precision, double precision[])');
DROP FUNCTION IF EXISTS _st_quantile(text, text, int, boolean, double precision, double precision[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP TYPE IF EXISTS quantile');
DROP TYPE IF EXISTS quantile;

-- remove TYPE valuecount
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_valuecount(text, text, integer, double precision, double precision)');
DROP FUNCTION IF EXISTS st_valuecount(text, text, integer, double precision, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_valuecount(text, text, integer, boolean, double precision[], double precision)');
DROP FUNCTION IF EXISTS st_valuecount(text, text, integer, boolean, double precision[], double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_valuecount(text, text, double precision[], double precision)');
DROP FUNCTION IF EXISTS st_valuecount(text, text, double precision[], double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_valuecount(text, text, integer, double precision[], double precision)');
DROP FUNCTION IF EXISTS st_valuecount(text, text, integer, double precision[], double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_valuecount(text, text, integer, boolean, double precision, double precision)');
DROP FUNCTION IF EXISTS st_valuecount(text, text, integer, boolean, double precision, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_valuecount(text, text, double precision, double precision)');
DROP FUNCTION IF EXISTS st_valuecount(text, text, double precision, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_valuecount(raster, integer, boolean, double precision[], double precision)');
DROP FUNCTION IF EXISTS st_valuecount(raster, integer, boolean, double precision[], double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_valuecount(raster, integer, double precision[], double precision)');
DROP FUNCTION IF EXISTS st_valuecount(raster, integer, double precision[], double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_valuecount(raster, double precision[], double precision)');
DROP FUNCTION IF EXISTS st_valuecount(raster, double precision[], double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_valuecount(text, text, integer, boolean, double precision[], double precision)');
DROP FUNCTION IF EXISTS _st_valuecount(text, text, integer, boolean, double precision[], double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_valuecount(raster, integer, boolean, double precision[], double precision)');
DROP FUNCTION IF EXISTS _st_valuecount(raster, integer, boolean, double precision[], double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP TYPE IF EXISTS valuecount');
DROP TYPE IF EXISTS valuecount;

-- remove TYPE histogram
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_histogram(raster, int, boolean, int, double precision[], boolean)');
DROP FUNCTION IF EXISTS st_histogram(raster, int, boolean, int, double precision[], boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_histogram(raster, int, boolean, int, boolean)');
DROP FUNCTION IF EXISTS st_histogram(raster, int, boolean, int, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_histogram(raster, int, int, double precision[], boolean)');
DROP FUNCTION IF EXISTS st_histogram(raster, int, int, double precision[], boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_histogram(raster, int, int, boolean)');
DROP FUNCTION IF EXISTS st_histogram(raster, int, int, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxhistogram( raster, int, boolean, double precision, int, double precision[], boolean)');
DROP FUNCTION IF EXISTS st_approxhistogram( raster, int, boolean, double precision, int, double precision[], boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxhistogram(raster, int, boolean, double precision, int, boolean)');
DROP FUNCTION IF EXISTS st_approxhistogram(raster, int, boolean, double precision, int, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxhistogram(raster, int, double precision)');
DROP FUNCTION IF EXISTS st_approxhistogram(raster, int, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxhistogram(raster, double precision)');
DROP FUNCTION IF EXISTS st_approxhistogram(raster, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxhistogram(raster, int, double precision, int, double precision[], boolean)');
DROP FUNCTION IF EXISTS st_approxhistogram(raster, int, double precision, int, double precision[], boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxhistogram(raster, int, double precision, int, boolean)');
DROP FUNCTION IF EXISTS st_approxhistogram(raster, int, double precision, int, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_histogram(text, text, int, boolean, int, double precision[], boolean)');
DROP FUNCTION IF EXISTS st_histogram(text, text, int, boolean, int, double precision[], boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_histogram(text, text, int, boolean, int, boolean)');
DROP FUNCTION IF EXISTS st_histogram(text, text, int, boolean, int, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_histogram(text, text, int, int, double precision[], boolean)');
DROP FUNCTION IF EXISTS st_histogram(text, text, int, int, double precision[], boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_histogram(text, text, int, int, boolean)');
DROP FUNCTION IF EXISTS st_histogram(text, text, int, int, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxhistogram( text, text, int, boolean, double precision, int, double precision[], boolean)');
DROP FUNCTION IF EXISTS st_approxhistogram( text, text, int, boolean, double precision, int, double precision[], boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxhistogram(text, text, int, boolean, double precision, int, boolean)');
DROP FUNCTION IF EXISTS st_approxhistogram(text, text, int, boolean, double precision, int, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxhistogram(text, text, int, double precision)');
DROP FUNCTION IF EXISTS st_approxhistogram(text, text, int, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxhistogram(text, text, double precision)');
DROP FUNCTION IF EXISTS st_approxhistogram(text, text, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxhistogram(text, text, int, double precision, int, double precision[], boolean)');
DROP FUNCTION IF EXISTS st_approxhistogram(text, text, int, double precision, int, double precision[], boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_approxhistogram(text, text, int, double precision, int, boolean)');
DROP FUNCTION IF EXISTS st_approxhistogram(text, text, int, double precision, int, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_histogram( raster, int, boolean, double precision, int, double precision[], boolean, double precision, double precision)');
DROP FUNCTION IF EXISTS _st_histogram( raster, int, boolean, double precision, int, double precision[], boolean, double precision, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_histogram( text, text, int, boolean, double precision, int, double precision[], boolean)');
DROP FUNCTION IF EXISTS _st_histogram( text, text, int, boolean, double precision, int, double precision[], boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP TYPE IF EXISTS histogram');
DROP TYPE IF EXISTS histogram;

-- no longer needed functions changed to use out parameters
SELECT postgis_extension_drop_if_exists('postgis', 'DROP TYPE IF EXISTS bandmetadata');
DROP TYPE IF EXISTS bandmetadata;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP TYPE IF EXISTS geomvalxy');
DROP TYPE IF EXISTS geomvalxy;

-- raster_columns and raster_overviews tables are deprecated
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _rename_raster_tables()');
DROP FUNCTION IF EXISTS _rename_raster_tables();
CREATE OR REPLACE FUNCTION _rename_raster_tables()
	RETURNS void AS $$
	DECLARE
		cnt int;
	BEGIN
		SELECT count(*) INTO cnt
		FROM pg_class c
		JOIN pg_namespace n
			ON c.relnamespace = n.oid
		WHERE c.relname = 'raster_columns'
			AND c.relkind = 'r'::char
			AND NOT pg_is_other_temp_schema(c.relnamespace);

		IF cnt > 0 THEN
			EXECUTE 'ALTER TABLE raster_columns RENAME TO deprecated_raster_columns';
		END IF;

		SELECT count(*) INTO cnt
		FROM pg_class c
		JOIN pg_namespace n
			ON c.relnamespace = n.oid
		WHERE c.relname = 'raster_overviews'
			AND c.relkind = 'r'::char
			AND NOT pg_is_other_temp_schema(c.relnamespace);

		IF cnt > 0 THEN
			EXECUTE 'ALTER TABLE raster_overviews RENAME TO deprecated_raster_overviews';
		END IF;

	END;
	$$ LANGUAGE 'plpgsql' VOLATILE;
SELECT _rename_raster_tables();
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION _rename_raster_tables()');
DROP FUNCTION _rename_raster_tables();

-- inserted new column into view
SELECT postgis_extension_drop_if_exists('postgis', 'DROP VIEW IF EXISTS raster_columns');
DROP VIEW IF EXISTS raster_columns;

-- functions no longer supported
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS AddRasterColumn(varchar, varchar, varchar, varchar, integer, varchar[], boolean, boolean, double precision[], double precision, double precision, integer, integer, geometry)');
DROP FUNCTION IF EXISTS AddRasterColumn(varchar, varchar, varchar, varchar, integer, varchar[], boolean, boolean, double precision[], double precision, double precision, integer, integer, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS AddRasterColumn(varchar, varchar, varchar, integer, varchar[], boolean, boolean, double precision[], double precision, double precision, integer, integer, geometry)');
DROP FUNCTION IF EXISTS AddRasterColumn(varchar, varchar, varchar, integer, varchar[], boolean, boolean, double precision[], double precision, double precision, integer, integer, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS AddRasterColumn(varchar, varchar, integer, varchar[], boolean, boolean, double precision[], double precision, double precision, integer, integer, geometry)');
DROP FUNCTION IF EXISTS AddRasterColumn(varchar, varchar, integer, varchar[], boolean, boolean, double precision[], double precision, double precision, integer, integer, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS DropRasterColumn(varchar, varchar, varchar, varchar)');
DROP FUNCTION IF EXISTS DropRasterColumn(varchar, varchar, varchar, varchar);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS DropRasterColumn(varchar, varchar, varchar)');
DROP FUNCTION IF EXISTS DropRasterColumn(varchar, varchar, varchar);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS DropRasterColumn(varchar, varchar)');
DROP FUNCTION IF EXISTS DropRasterColumn(varchar, varchar);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS DropRasterTable(varchar, varchar, varchar)');
DROP FUNCTION IF EXISTS DropRasterTable(varchar, varchar, varchar);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS DropRasterTable(varchar, varchar)');
DROP FUNCTION IF EXISTS DropRasterTable(varchar, varchar);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS DropRasterTable(varchar)');
DROP FUNCTION IF EXISTS DropRasterTable(varchar);

-- function parameters added
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS AddRasterConstraints(name, name, name, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean)');
DROP FUNCTION IF EXISTS AddRasterConstraints(name, name, name, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS AddRasterConstraints(name, name, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean)');
DROP FUNCTION IF EXISTS AddRasterConstraints(name, name, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS DropRasterConstraints(name, name, name, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean)');
DROP FUNCTION IF EXISTS DropRasterConstraints(name, name, name, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS DropRasterConstraints(name, name, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean)');
DROP FUNCTION IF EXISTS DropRasterConstraints(name, name, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean);

-- function parameters renamed
CREATE OR REPLACE FUNCTION _drop_st_samealignment()
	RETURNS void AS $$
	DECLARE
		cnt int;
	BEGIN
		SELECT count(*) INTO cnt
		FROM pg_proc
		WHERE lower(proname) = 'st_samealignment'
			AND pronargs = 2
			AND (
				proargnames = '{rasta,rastb}'::text[] OR
				proargnames = '{rastA,rastB}'::text[]
			);

		IF cnt > 0 THEN
			RAISE NOTICE 'Dropping ST_SameAlignment(raster, raster) due to parameter name changes.  Unfortunately, this is a DROP ... CASCADE as the alignment raster constraint uses ST_SameAlignment(raster, raster).  You will need to reapply AddRasterConstraint(''SCHEMA'', ''TABLE'', ''COLUMN'', ''alignment'') to any raster column that requires this constraint.';
			DROP FUNCTION IF EXISTS st_samealignment(raster, raster) CASCADE;
		END IF;
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE;
SELECT _drop_st_samealignment();
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION _drop_st_samealignment()');
DROP FUNCTION _drop_st_samealignment();

SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_intersects(raster, integer, raster, integer)');
DROP FUNCTION IF EXISTS _st_intersects(raster, integer, raster, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_intersects(raster, integer, raster, integer)');
DROP FUNCTION IF EXISTS st_intersects(raster, integer, raster, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_intersects(raster, raster)');
DROP FUNCTION IF EXISTS st_intersects(raster, raster);

-- functions have changed dramatically
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_intersection(raster, integer, geometry)');
DROP FUNCTION IF EXISTS st_intersection(raster, integer, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_intersection(raster, geometry)');
DROP FUNCTION IF EXISTS st_intersection(raster, geometry);

-- function was renamed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_minpossibleval(text)');
DROP FUNCTION IF EXISTS st_minpossibleval(text);

-- function deprecated previously
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_pixelaspolygon(raster, integer, integer, integer)');
DROP FUNCTION IF EXISTS st_pixelaspolygon(raster, integer, integer, integer);

-- function signatures changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_intersection(raster, int, geometry, text, regprocedure)');
DROP FUNCTION IF EXISTS st_intersection(raster, int, geometry, text, regprocedure);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_intersection(raster, int, geometry, regprocedure)');
DROP FUNCTION IF EXISTS st_intersection(raster, int, geometry, regprocedure);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_intersection(raster, geometry, text, regprocedure)');
DROP FUNCTION IF EXISTS st_intersection(raster, geometry, text, regprocedure);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_intersection(raster, geometry, regprocedure)');
DROP FUNCTION IF EXISTS st_intersection(raster, geometry, regprocedure);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_clip(raster, integer, geometry, boolean)');
DROP FUNCTION IF EXISTS st_clip(raster, integer, geometry, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_clip(raster, geometry, float8, boolean)');
DROP FUNCTION IF EXISTS st_clip(raster, geometry, float8, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_clip(raster, geometry, boolean)');
DROP FUNCTION IF EXISTS st_clip(raster, geometry, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_clip(raster, int, geometry, float8, boolean)');
DROP FUNCTION IF EXISTS st_clip(raster, int, geometry, float8, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_clip(raster, geometry, float8[], boolean)');
DROP FUNCTION IF EXISTS st_clip(raster, geometry, float8[], boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_clip(raster, integer, geometry, float8[], boolean)');
DROP FUNCTION IF EXISTS st_clip(raster, integer, geometry, float8[], boolean);

-- refactoring of functions
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_dumpaswktpolygons(raster, integer)');
DROP FUNCTION IF EXISTS _st_dumpaswktpolygons(raster, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP TYPE IF EXISTS wktgeomval');
DROP TYPE IF EXISTS wktgeomval;

-- function parameter names changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_nearestvalue(raster, integer, integer, integer, boolean)');
DROP FUNCTION IF EXISTS st_nearestvalue(raster, integer, integer, integer, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_nearestvalue(raster, integer, integer, boolean)');
DROP FUNCTION IF EXISTS st_nearestvalue(raster, integer, integer, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_neighborhood(raster, integer, integer, integer, integer, boolean)');
DROP FUNCTION IF EXISTS st_neighborhood(raster, integer, integer, integer, integer, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_neighborhood(raster, integer, integer, integer, boolean)');
DROP FUNCTION IF EXISTS st_neighborhood(raster, integer, integer, integer, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_neighborhood(raster, integer, geometry, integer, boolean)');
DROP FUNCTION IF EXISTS st_neighborhood(raster, integer, geometry, integer, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_neighborhood(raster, geometry, integer, boolean)');
DROP FUNCTION IF EXISTS st_neighborhood(raster, geometry, integer, boolean);

-- variants of st_intersection with regprocedure no longer exist
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_intersection(raster, integer, raster, integer, text, regprocedure)');
DROP FUNCTION IF EXISTS st_intersection(raster, integer, raster, integer, text, regprocedure);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_intersection(raster, integer, raster, integer, regprocedure)');
DROP FUNCTION IF EXISTS st_intersection(raster, integer, raster, integer, regprocedure);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_intersection(raster, raster, text, regprocedure)');
DROP FUNCTION IF EXISTS st_intersection(raster, raster, text, regprocedure);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_intersection(raster, raster, regprocedure)');
DROP FUNCTION IF EXISTS st_intersection(raster, raster, regprocedure);

-- function deprecated
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_pixelaspolygons(raster, integer)');
DROP FUNCTION IF EXISTS st_pixelaspolygons(raster, integer);

-- function deprecated
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_bandsurface(raster, integer)');
DROP FUNCTION IF EXISTS st_bandsurface(raster, integer);

-- function no longer exist or refactored
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_intersects(raster, integer, geometry)');
DROP FUNCTION IF EXISTS st_intersects(raster, integer, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_intersects(raster, geometry, integer)');
DROP FUNCTION IF EXISTS st_intersects(raster, geometry, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_intersects(geometry, raster, integer)');
DROP FUNCTION IF EXISTS st_intersects(geometry, raster, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_intersects(raster, geometry, integer)');
DROP FUNCTION IF EXISTS _st_intersects(raster, geometry, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_intersects(geometry, raster, integer)');
DROP FUNCTION IF EXISTS _st_intersects(geometry, raster, integer);

-- function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_overlaps(geometry, raster, integer)');
DROP FUNCTION IF EXISTS st_overlaps(geometry, raster, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_overlaps(raster, integer, geometry)');
DROP FUNCTION IF EXISTS st_overlaps(raster, integer, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_overlaps(raster, geometry, integer)');
DROP FUNCTION IF EXISTS st_overlaps(raster, geometry, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_overlaps(raster, geometry, integer)');
DROP FUNCTION IF EXISTS _st_overlaps(raster, geometry, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_overlaps(geometry, raster, integer)');
DROP FUNCTION IF EXISTS _st_overlaps(geometry, raster, integer);

-- function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_touches(geometry, raster, integer)');
DROP FUNCTION IF EXISTS st_touches(geometry, raster, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_touches(raster, geometry, integer)');
DROP FUNCTION IF EXISTS st_touches(raster, geometry, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_touches(raster, integer, geometry)');
DROP FUNCTION IF EXISTS st_touches(raster, integer, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_touches(geometry, raster, integer)');
DROP FUNCTION IF EXISTS _st_touches(geometry, raster, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_touches(raster, geometry, integer)');
DROP FUNCTION IF EXISTS _st_touches(raster, geometry, integer);

-- function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_contains(raster, geometry, integer)');
DROP FUNCTION IF EXISTS st_contains(raster, geometry, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_contains(raster, integer, geometry)');
DROP FUNCTION IF EXISTS st_contains(raster, integer, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_contains(geometry, raster, integer)');
DROP FUNCTION IF EXISTS st_contains(geometry, raster, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_contains(raster, geometry, integer)');
DROP FUNCTION IF EXISTS _st_contains(raster, geometry, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_contains(geometry, raster, integer)');
DROP FUNCTION IF EXISTS _st_contains(geometry, raster, integer);

-- function signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_addband(raster, raster[], integer)');
DROP FUNCTION IF EXISTS st_addband(raster, raster[], integer);

-- function signatures changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_slope(raster, integer, text, text, double precision, boolean)');
DROP FUNCTION IF EXISTS st_slope(raster, integer, text, text, double precision, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_slope(raster, integer, text, boolean)');
DROP FUNCTION IF EXISTS st_slope(raster, integer, text, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_slope(raster, integer, text)');
DROP FUNCTION IF EXISTS st_slope(raster, integer, text);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_aspect(raster, integer, text, text, boolean)');
DROP FUNCTION IF EXISTS st_aspect(raster, integer, text, text, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_aspect(raster, integer, text, boolean)');
DROP FUNCTION IF EXISTS st_aspect(raster, integer, text, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_aspect(raster, integer, text)');
DROP FUNCTION IF EXISTS st_aspect(raster, integer, text);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_hillshade(raster, integer, text, double precision, double precision, double precision, double precision, boolean)');
DROP FUNCTION IF EXISTS st_hillshade(raster, integer, text, double precision, double precision, double precision, double precision, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_hillshade(raster, integer, text, float, float, float, float, boolean)');
DROP FUNCTION IF EXISTS st_hillshade(raster, integer, text, float, float, float, float, boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_hillshade(raster, integer, text, float, float, float, float)');
DROP FUNCTION IF EXISTS st_hillshade(raster, integer, text, float, float, float, float);

-- function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_tile(raster, integer, integer, integer[])');
DROP FUNCTION IF EXISTS st_tile(raster, integer, integer, integer[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_tile(raster, integer, integer, integer)');
DROP FUNCTION IF EXISTS st_tile(raster, integer, integer, integer);

-- function signatures changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_setvalue(raster, integer, geometry, double precision)');
DROP FUNCTION IF EXISTS st_setvalue(raster, integer, geometry, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_setvalue(raster, geometry, double precision)');
DROP FUNCTION IF EXISTS st_setvalue(raster, geometry, double precision);

-- function name change
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_world2rastercoord(raster, double precision, double precision)');
DROP FUNCTION IF EXISTS st_world2rastercoord(raster, double precision, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_world2rastercoord(raster, geometry)');
DROP FUNCTION IF EXISTS st_world2rastercoord(raster, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_world2rastercoord(raster, double precision, double precision)');
DROP FUNCTION IF EXISTS _st_world2rastercoord(raster, double precision, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_world2rastercoordx(raster, float8, float8)');
DROP FUNCTION IF EXISTS st_world2rastercoordx(raster, float8, float8);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_world2rastercoordx(raster, float8)');
DROP FUNCTION IF EXISTS st_world2rastercoordx(raster, float8);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_world2rastercoordx(raster, geometry)');
DROP FUNCTION IF EXISTS st_world2rastercoordx(raster, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_world2rastercoordy(raster, float8, float8)');
DROP FUNCTION IF EXISTS st_world2rastercoordy(raster, float8, float8);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_world2rastercoordy(raster, float8)');
DROP FUNCTION IF EXISTS st_world2rastercoordy(raster, float8);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_world2rastercoordy(raster, geometry)');
DROP FUNCTION IF EXISTS st_world2rastercoordy(raster, geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_raster2worldcoord( raster, integer, integer)');
DROP FUNCTION IF EXISTS st_raster2worldcoord( raster, integer, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_raster2worldcoord(raster, integer, integer)');
DROP FUNCTION IF EXISTS _st_raster2worldcoord(raster, integer, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_raster2worldcoordx(raster, int, int)');
DROP FUNCTION IF EXISTS st_raster2worldcoordx(raster, int, int);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_raster2worldcoordx(raster, int)');
DROP FUNCTION IF EXISTS st_raster2worldcoordx(raster, int);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_raster2worldcoordy(raster, int, int)');
DROP FUNCTION IF EXISTS st_raster2worldcoordy(raster, int, int);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_raster2worldcoordy(raster, int)');
DROP FUNCTION IF EXISTS st_raster2worldcoordy(raster, int);

-- function name change
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_resample(raster, text, double precision, integer, double precision, double precision, double precision, double precision, double precision, double precision, integer, integer)');
DROP FUNCTION IF EXISTS _st_resample(raster, text, double precision, integer, double precision, double precision, double precision, double precision, double precision, double precision, integer, integer);

-- function signatures changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_resample(raster, integer, double precision, double precision, double precision, double precision, double precision, double precision, text, double precision)');
DROP FUNCTION IF EXISTS st_resample(raster, integer, double precision, double precision, double precision, double precision, double precision, double precision, text, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_resample(raster, integer, integer, integer, double precision, double precision, double precision, double precision, text, double precision)');
DROP FUNCTION IF EXISTS st_resample(raster, integer, integer, integer, double precision, double precision, double precision, double precision, text, double precision);

-- function signatures changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_tile(raster, integer, integer, int[])');
DROP FUNCTION IF EXISTS _st_tile(raster, integer, integer, int[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_tile(raster, integer[], integer, integer)');
DROP FUNCTION IF EXISTS st_tile(raster, integer[], integer, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_tile(raster, integer, integer, integer)');
DROP FUNCTION IF EXISTS st_tile(raster, integer, integer, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_tile(raster, integer, integer)');
DROP FUNCTION IF EXISTS st_tile(raster, integer, integer);

-- function no longer exists
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _add_raster_constraint_regular_blocking(name, name, name)');
DROP FUNCTION IF EXISTS _add_raster_constraint_regular_blocking(name, name, name);

-- function signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_asbinary(raster)');
DROP FUNCTION IF EXISTS st_asbinary(raster);

SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_aspect4ma(float8[], text, text[])');
DROP FUNCTION IF EXISTS _st_aspect4ma(float8[], text, text[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_hillshade4ma(float8[], text, text[])');
DROP FUNCTION IF EXISTS _st_hillshade4ma(float8[], text, text[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_slope4ma(float8[], text, text[])');
DROP FUNCTION IF EXISTS _st_slope4ma(float8[], text, text[]);

-- function signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_gdaldrivers()');
DROP FUNCTION IF EXISTS st_gdaldrivers();

-- function signature change
-- return value changed
DO LANGUAGE 'plpgsql' $$
DECLARE
	cnt bigint;
BEGIN
	SELECT
		count(*)
	INTO cnt
	FROM pg_proc f
	JOIN pg_type t
		ON f.prorettype = t.oid
	WHERE lower(f.proname) = '_raster_constraint_nodata_values'
		AND f.pronargs = 1
		AND t.typname = '_float8'; -- array form

	IF cnt > 0 THEN
		RAISE NOTICE 'Dropping _raster_constraint_nodata_values(raster) due to return value changes.  Unfortunately, this is a DROP ... CASCADE as the NODATA raster constraint uses _raster_constraint_nodata_values(raster).  You will need to reapply AddRasterConstraint(''SCHEMA'', ''TABLE'', ''COLUMN'', ''nodata'') to any raster column that requires this constraint.';
		DROP FUNCTION IF EXISTS _raster_constraint_nodata_values(raster) CASCADE;
	END IF;
END;
$$;

-- 2.5.0 signature changed
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_bandmetadata(raster, int[])');
DROP FUNCTION IF EXISTS st_bandmetadata(raster, int[]);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS st_bandmetadata(raster, int)');
DROP FUNCTION IF EXISTS st_bandmetadata(raster, int);


--
-- UPGRADE SCRIPT TO PostGIS 2.5
--

LOAD '$libdir/rtpostgis-2.5';

CREATE OR REPLACE FUNCTION postgis_major_version_check()
RETURNS text
AS '
DECLARE
	old_scripts text;
	new_scripts text;
	old_maj text;
	new_maj text;
BEGIN
	--
	-- This uses postgis_lib_version() rather then
	-- postgis_raster_scripts_installed() as in 1.0 because
	-- in the 1.0 => 1.1 transition that would result
	-- in an impossible upgrade:
	--
	--   from 0.3.0 to 1.1.0
	--
	-- Next releases will still be ok as
	-- postgis_lib_version() and postgis_raster_scripts_installed()
	-- would both return actual PostGIS release number.
	--
	BEGIN
		SELECT into old_scripts postgis_raster_lib_version();
	EXCEPTION WHEN OTHERS THEN
		RAISE DEBUG ''Got %'', SQLERRM;
		SELECT into old_scripts postgis_raster_scripts_installed();
	END;
	SELECT into new_scripts ''2.5'';
	SELECT into old_maj substring(old_scripts from 1 for 2);
	SELECT into new_maj substring(new_scripts from 1 for 2);

	IF old_maj != new_maj THEN
		RAISE EXCEPTION ''Upgrade of postgis_raster from version % to version % requires a dump/reload. See PostGIS manual for instructions'', old_scripts, new_scripts;
	ELSE
		RETURN ''Scripts versions checked for upgrade: ok'';
	END IF;
END
'
LANGUAGE 'plpgsql';

SELECT postgis_major_version_check();

SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION postgis_major_version_check()');
DROP FUNCTION postgis_major_version_check();

CREATE TEMPORARY TABLE _postgis_upgrade_info AS WITH versions AS (
  SELECT '2.5'::text as upgraded,
  postgis_raster_scripts_installed() as installed
) SELECT
  upgraded as scripts_upgraded,
  installed as scripts_installed,
  substring(upgraded from '([0-9]*)\.')::int * 100 +
  substring(upgraded from '[0-9]*\.([0-9]*)\.')::int
    as version_to_num,
  substring(installed from '([0-9]*)\.')::int * 100 +
  substring(installed from '[0-9]*\.([0-9]*)\.')::int
    as version_from_num,
  installed ~ 'dev|alpha|beta'
    as version_from_isdev
  FROM versions
;

CREATE OR REPLACE FUNCTION raster_in(cstring)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5','RASTER_in'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_out(raster)
    RETURNS cstring
    AS '$libdir/rtpostgis-2.5','RASTER_out'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_recv(internal)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5','RASTER_recv'
    LANGUAGE 'c' IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION raster_send(raster)
    RETURNS bytea
    AS '$libdir/rtpostgis-2.5','RASTER_send'
    LANGUAGE 'c' IMMUTABLE STRICT;
-- Type raster -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE raster (
    alignment = double,
    internallength = variable,
    input = raster_in,
    output = raster_out,
    send = raster_send,
    receive = raster_recv,
    storage = extended
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION postgis_raster_lib_version()
    RETURNS text
    AS '$libdir/rtpostgis-2.5', 'RASTER_lib_version'
    LANGUAGE 'c' IMMUTABLE PARALLEL SAFE; -- a new lib will require a new session
CREATE OR REPLACE FUNCTION postgis_raster_scripts_installed() RETURNS text
       AS $$ SELECT '2.5.4'::text || ' r' || 0::text AS version $$
       LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION postgis_raster_lib_build_date()
    RETURNS text
    AS '$libdir/rtpostgis-2.5', 'RASTER_lib_build_date'
    LANGUAGE 'c' IMMUTABLE PARALLEL SAFE; -- a new lib will require a new session
CREATE OR REPLACE FUNCTION postgis_gdal_version()
    RETURNS text
    AS '$libdir/rtpostgis-2.5', 'RASTER_gdal_version'
    LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
-- Type rastbandarg -- LastUpdated: 201
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 201 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE rastbandarg AS (
	rast raster,
	nband integer
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Type geomval -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE geomval AS (
	geom geometry,
	val double precision
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION st_envelope(raster)
	RETURNS geometry
	AS '$libdir/rtpostgis-2.5','RASTER_envelope'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_convexhull(raster)
    RETURNS geometry
    AS '$libdir/rtpostgis-2.5','RASTER_convex_hull'
    LANGUAGE 'c' IMMUTABLE STRICT
    COST 300;
CREATE OR REPLACE FUNCTION st_minconvexhull(
	rast raster,
	nband integer DEFAULT NULL
)
	RETURNS geometry
	AS '$libdir/rtpostgis-2.5','RASTER_convex_hull'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION box3d(raster)
    RETURNS box3d
    AS 'select box3d( @extschema@.ST_convexhull($1))'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_height(raster)
    RETURNS integer
    AS '$libdir/rtpostgis-2.5','RASTER_getHeight'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_numbands(raster)
    RETURNS integer
    AS '$libdir/rtpostgis-2.5','RASTER_getNumBands'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_scalex(raster)
    RETURNS float8
    AS '$libdir/rtpostgis-2.5','RASTER_getXScale'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_scaley(raster)
    RETURNS float8
    AS '$libdir/rtpostgis-2.5','RASTER_getYScale'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_skewx(raster)
    RETURNS float8
    AS '$libdir/rtpostgis-2.5','RASTER_getXSkew'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_skewy(raster)
    RETURNS float8
    AS '$libdir/rtpostgis-2.5','RASTER_getYSkew'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_srid(raster)
    RETURNS integer
    AS '$libdir/rtpostgis-2.5','RASTER_getSRID'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_upperleftx(raster)
    RETURNS float8
    AS '$libdir/rtpostgis-2.5','RASTER_getXUpperLeft'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_upperlefty(raster)
    RETURNS float8
    AS '$libdir/rtpostgis-2.5','RASTER_getYUpperLeft'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_width(raster)
    RETURNS integer
    AS '$libdir/rtpostgis-2.5','RASTER_getWidth'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_pixelwidth(raster)
    RETURNS float8
    AS '$libdir/rtpostgis-2.5', 'RASTER_getPixelWidth'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_pixelheight(raster)
    RETURNS float8
    AS '$libdir/rtpostgis-2.5', 'RASTER_getPixelHeight'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_geotransform(raster,
    OUT imag double precision,
    OUT jmag double precision,
    OUT theta_i double precision,
    OUT theta_ij double precision,
    OUT xoffset double precision,
    OUT yoffset double precision)
    AS '$libdir/rtpostgis-2.5', 'RASTER_getGeotransform'
    LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_rotation(raster)
    RETURNS float8
    AS $$ SELECT ( @extschema@.ST_Geotransform($1)).theta_i $$
    LANGUAGE 'sql' VOLATILE;
CREATE OR REPLACE FUNCTION st_metadata(
	rast raster,
	OUT upperleftx double precision,
	OUT upperlefty double precision,
	OUT width int,
	OUT height int,
	OUT scalex double precision,
	OUT scaley double precision,
	OUT skewx double precision,
	OUT skewy double precision,
	OUT srid int,
	OUT numbands int
)
	AS '$libdir/rtpostgis-2.5', 'RASTER_metadata'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_summary(rast raster)
	RETURNS text
	AS $$
	DECLARE
		extent box2d;
		metadata record;
		bandmetadata record;
		msg text;
		msgset text[];
	BEGIN
		extent := @extschema@.ST_Extent(rast::@extschema@.geometry);
		metadata := @extschema@.ST_Metadata(rast);

		msg := 'Raster of ' || metadata.width || 'x' || metadata.height || ' pixels has ' || metadata.numbands || ' ';

		IF metadata.numbands = 1 THEN
			msg := msg || 'band ';
		ELSE
			msg := msg || 'bands ';
		END IF;
		msg := msg || 'and extent of ' || extent::text;

		IF
			round(metadata.skewx::numeric, 10) <> round(0::numeric, 10) OR
			round(metadata.skewy::numeric, 10) <> round(0::numeric, 10)
		THEN
			msg := 'Skewed ' || overlay(msg placing 'r' from 1 for 1);
		END IF;

		msgset := Array[]::text[] || msg;

		FOR bandmetadata IN SELECT * FROM @extschema@.ST_BandMetadata(rast, ARRAY[]::int[]) LOOP
			msg := 'band ' || bandmetadata.bandnum || ' of pixtype ' || bandmetadata.pixeltype || ' is ';
			IF bandmetadata.isoutdb IS FALSE THEN
				msg := msg || 'in-db ';
			ELSE
				msg := msg || 'out-db ';
			END IF;

			msg := msg || 'with ';
			IF bandmetadata.nodatavalue IS NOT NULL THEN
				msg := msg || 'NODATA value of ' || bandmetadata.nodatavalue;
			ELSE
				msg := msg || 'no NODATA value';
			END IF;

			msgset := msgset || ('    ' || msg);
		END LOOP;

		RETURN array_to_string(msgset, E'\n');
	END;
	$$ LANGUAGE 'plpgsql' STABLE STRICT;
CREATE OR REPLACE FUNCTION ST_MemSize(raster)
	RETURNS int4
	AS '$libdir/rtpostgis-2.5', 'RASTER_memsize'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_makeemptyraster(width int, height int, upperleftx float8, upperlefty float8, scalex float8, scaley float8, skewx float8, skewy float8, srid int4 DEFAULT 0)
    RETURNS RASTER
    AS '$libdir/rtpostgis-2.5', 'RASTER_makeEmpty'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_makeemptyraster(width int, height int, upperleftx float8, upperlefty float8, pixelsize float8)
    RETURNS raster
    AS $$ SELECT  @extschema@.ST_makeemptyraster($1, $2, $3, $4, $5, -($5), 0, 0, @extschema@.ST_SRID('POINT(0 0)'::@extschema@.geometry)) $$
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_makeemptyraster(rast raster)
    RETURNS raster
    AS $$
		DECLARE
			w int;
			h int;
			ul_x double precision;
			ul_y double precision;
			scale_x double precision;
			scale_y double precision;
			skew_x double precision;
			skew_y double precision;
			sr_id int;
		BEGIN
			SELECT width, height, upperleftx, upperlefty, scalex, scaley, skewx, skewy, srid INTO w, h, ul_x, ul_y, scale_x, scale_y, skew_x, skew_y, sr_id FROM @extschema@.ST_Metadata(rast);
			RETURN  @extschema@.ST_makeemptyraster(w, h, ul_x, ul_y, scale_x, scale_y, skew_x, skew_y, sr_id);
		END;
    $$ LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
-- Type addbandarg -- LastUpdated: 201
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 201 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE addbandarg AS (
	index int,
	pixeltype text,
	initialvalue float8,
	nodataval float8
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION st_addband(rast raster, addbandargset addbandarg[])
	RETURNS RASTER
	AS '$libdir/rtpostgis-2.5', 'RASTER_addBand'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_addband(
	rast raster,
	index int,
	pixeltype text,
	initialvalue float8 DEFAULT 0.,
	nodataval float8 DEFAULT NULL
)
	RETURNS raster
	AS $$ SELECT  @extschema@.ST_addband($1, ARRAY[ROW($2, $3, $4, $5)]::addbandarg[]) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_addband(
	rast raster,
	pixeltype text,
	initialvalue float8 DEFAULT 0.,
	nodataval float8 DEFAULT NULL
)
	RETURNS raster
	AS $$ SELECT  @extschema@.ST_addband($1, ARRAY[ROW(NULL, $2, $3, $4)]::addbandarg[]) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_addband(
	torast raster,
	fromrast raster,
	fromband int DEFAULT 1,
	torastindex int DEFAULT NULL
)
	RETURNS raster
	AS '$libdir/rtpostgis-2.5', 'RASTER_copyBand'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_addband(
	torast raster,
	fromrasts raster[], fromband integer DEFAULT 1,
	torastindex int DEFAULT NULL
)
	RETURNS raster
	AS '$libdir/rtpostgis-2.5', 'RASTER_addBandRasterArray'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_addband(
	rast raster,
	index int,
	outdbfile text, outdbindex int[],
	nodataval double precision DEFAULT NULL
)
	RETURNS raster
	AS '$libdir/rtpostgis-2.5', 'RASTER_addBandOutDB'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_addband(
	rast raster,
	outdbfile text, outdbindex int[],
	index int DEFAULT NULL,
	nodataval double precision DEFAULT NULL
)
	RETURNS raster
	AS $$ SELECT @extschema@.ST_AddBand($1, $4, $2, $3, $5) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_band(rast raster, nbands int[] DEFAULT ARRAY[1])
	RETURNS RASTER
	AS '$libdir/rtpostgis-2.5', 'RASTER_band'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_band(rast raster, nband int)
	RETURNS RASTER
	AS $$ SELECT  @extschema@.ST_band($1, ARRAY[$2]) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_band(rast raster, nbands text, delimiter char DEFAULT ',')
	RETURNS RASTER
	AS $$ SELECT  @extschema@.ST_band($1, regexp_split_to_array(regexp_replace($2, '[[:space:]]', '', 'g'), E'\\' || array_to_string(regexp_split_to_array($3, ''), E'\\'))::int[]) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
-- Type summarystats -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num
OR version_from_num IN ( 201 )     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE summarystats AS (
	count bigint,
	sum double precision,
	mean double precision,
	stddev double precision,
	min double precision,
	max double precision
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_summarystats(
	rast raster,
	nband int DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	sample_percent double precision DEFAULT 1
)
	RETURNS summarystats
	AS '$libdir/rtpostgis-2.5','RASTER_summaryStats'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_summarystats(
	rast raster,
	nband int DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE
)
	RETURNS summarystats
	AS $$ SELECT @extschema@._ST_summarystats($1, $2, $3, 1) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_summarystats(
	rast raster,
	exclude_nodata_value boolean
)
	RETURNS summarystats
	AS $$ SELECT @extschema@._ST_summarystats($1, 1, $2, 1) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxsummarystats(
	rast raster,
	nband int DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	sample_percent double precision DEFAULT 0.1
)
	RETURNS summarystats
	AS $$ SELECT @extschema@._ST_summarystats($1, $2, $3, $4) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxsummarystats(
	rast raster,
	nband int,
	sample_percent double precision
)
	RETURNS summarystats
	AS $$ SELECT @extschema@._ST_summarystats($1, $2, TRUE, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxsummarystats(
	rast raster,
	exclude_nodata_value boolean,
	sample_percent double precision DEFAULT 0.1
)
	RETURNS summarystats
	AS $$ SELECT @extschema@._ST_summarystats($1, 1, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxsummarystats(
	rast raster,
	sample_percent double precision
)
	RETURNS summarystats
	AS $$ SELECT @extschema@._ST_summarystats($1, 1, TRUE, $2) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_summarystats_finalfn(internal)
	RETURNS summarystats
	AS '$libdir/rtpostgis-2.5', 'RASTER_summaryStats_finalfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_summarystats_transfn(
	internal,
	raster, integer,
	boolean, double precision
)
	RETURNS internal
	AS '$libdir/rtpostgis-2.5', 'RASTER_summaryStats_transfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
-- Aggregate st_summarystatsagg(raster,integer,boolean,double precision) -- LastUpdated: 204
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 204 > version_from_num OR (
      204 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS st_summarystatsagg(raster,integer,boolean,double precision)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE AGGREGATE st_summarystatsagg(raster, integer, boolean, double precision) (
	SFUNC = _st_summarystats_transfn,
	STYPE = internal,

	parallel = safe,

	FINALFUNC = _st_summarystats_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_summarystats_transfn(
	internal,
	raster, boolean, double precision
)
	RETURNS internal
	AS '$libdir/rtpostgis-2.5', 'RASTER_summaryStats_transfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
-- Aggregate st_summarystatsagg(raster,boolean,double precision) -- LastUpdated: 204
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 204 > version_from_num OR (
      204 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS st_summarystatsagg(raster,boolean,double precision)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE AGGREGATE st_summarystatsagg(raster, boolean, double precision) (
	SFUNC = _st_summarystats_transfn,
	STYPE = internal,

	parallel = safe,

	FINALFUNC = _st_summarystats_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_summarystats_transfn(
	internal,
	raster, int, boolean
)
	RETURNS internal
	AS '$libdir/rtpostgis-2.5', 'RASTER_summaryStats_transfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
-- Aggregate st_summarystatsagg(raster,int,boolean) -- LastUpdated: 204
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 204 > version_from_num OR (
      204 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS st_summarystatsagg(raster,int,boolean)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE AGGREGATE st_summarystatsagg(raster, int, boolean) (
	SFUNC = _st_summarystats_transfn,
	STYPE = internal,

	parallel = safe,

	FINALFUNC = _st_summarystats_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_summarystats(
	rastertable text,
	rastercolumn text,
	nband integer DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	sample_percent double precision DEFAULT 1
)
	RETURNS summarystats
	AS $$
	DECLARE
		stats summarystats;
	BEGIN
		EXECUTE 'SELECT (stats).* FROM (SELECT @extschema@.ST_SummaryStatsAgg('
			|| quote_ident($2) || ', '
			|| $3 || ', '
			|| $4 || ', '
			|| $5 || ') AS stats '
			|| 'FROM ' || quote_ident($1)
			|| ') foo'
			INTO stats;
		RETURN stats;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_summarystats(
	rastertable text,
	rastercolumn text,
	nband integer DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE
)
	RETURNS summarystats
	AS $$ SELECT @extschema@._ST_summarystats($1, $2, $3, $4, 1) $$
	LANGUAGE 'sql' STABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_summarystats(
	rastertable text,
	rastercolumn text,
	exclude_nodata_value boolean
)
	RETURNS summarystats
	AS $$ SELECT @extschema@._ST_summarystats($1, $2, 1, $3, 1) $$
	LANGUAGE 'sql' STABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxsummarystats(
	rastertable text,
	rastercolumn text,
	nband integer DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	sample_percent double precision DEFAULT 0.1
)
	RETURNS summarystats
	AS $$ SELECT @extschema@._ST_summarystats($1, $2, $3, $4, $5) $$
	LANGUAGE 'sql' STABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxsummarystats(
	rastertable text,
	rastercolumn text,
	nband integer,
	sample_percent double precision
)
	RETURNS summarystats
	AS $$ SELECT @extschema@._ST_summarystats($1, $2, $3, TRUE, $4) $$
	LANGUAGE 'sql' STABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxsummarystats(
	rastertable text,
	rastercolumn text,
	exclude_nodata_value boolean
)
	RETURNS summarystats
	AS $$ SELECT @extschema@._ST_summarystats($1, $2, 1, $3, 0.1) $$
	LANGUAGE 'sql' STABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxsummarystats(
	rastertable text,
	rastercolumn text,
	sample_percent double precision
)
	RETURNS summarystats
	AS $$ SELECT @extschema@._ST_summarystats($1, $2, 1, TRUE, $3) $$
	LANGUAGE 'sql' STABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_count(rast raster, nband int DEFAULT 1, exclude_nodata_value boolean DEFAULT TRUE, sample_percent double precision DEFAULT 1)
	RETURNS bigint
	AS $$
	DECLARE
		rtn bigint;
	BEGIN
		IF exclude_nodata_value IS FALSE THEN
			SELECT width * height INTO rtn FROM @extschema@.ST_Metadata(rast);
		ELSE
			SELECT count INTO rtn FROM @extschema@._ST_summarystats($1, $2, $3, $4);
		END IF;

		RETURN rtn;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_count(rast raster, nband int DEFAULT 1, exclude_nodata_value boolean DEFAULT TRUE)
	RETURNS bigint
	AS $$ SELECT @extschema@._ST_count($1, $2, $3, 1) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_count(rast raster, exclude_nodata_value boolean)
	RETURNS bigint
	AS $$ SELECT @extschema@._ST_count($1, 1, $2, 1) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxcount(rast raster, nband int DEFAULT 1, exclude_nodata_value boolean DEFAULT TRUE, sample_percent double precision DEFAULT 0.1)
	RETURNS bigint
	AS $$ SELECT @extschema@._ST_count($1, $2, $3, $4) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxcount(rast raster, nband int, sample_percent double precision)
	RETURNS bigint
	AS $$ SELECT @extschema@._ST_count($1, $2, TRUE, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxcount(rast raster, exclude_nodata_value boolean, sample_percent double precision DEFAULT 0.1)
	RETURNS bigint
	AS $$ SELECT @extschema@._ST_count($1, 1, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxcount(rast raster, sample_percent double precision)
	RETURNS bigint
	AS $$ SELECT @extschema@._ST_count($1, 1, TRUE, $2) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
-- Type agg_count -- LastUpdated: 202
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 202 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE agg_count AS (
	count bigint,
	nband integer,
	exclude_nodata_value boolean,
	sample_percent double precision
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_countagg_finalfn(agg agg_count)
	RETURNS bigint
	AS $$
	BEGIN
		IF agg IS NULL THEN
			RAISE EXCEPTION 'Cannot count coverage';
		END IF;

		RETURN agg.count;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION __st_countagg_transfn(
	agg agg_count,
	rast raster,
 	nband integer DEFAULT 1, exclude_nodata_value boolean DEFAULT TRUE,
	sample_percent double precision DEFAULT 1
)
	RETURNS agg_count
	AS $$
	DECLARE
		_count bigint;
		rtn_agg agg_count;
	BEGIN

		-- only process parameter args once
		IF agg IS NULL THEN
			rtn_agg.count := 0;

			IF nband < 1 THEN
				RAISE EXCEPTION 'Band index must be greater than zero (1-based)';
			ELSE
				rtn_agg.nband := nband;
			END IF;

			IF exclude_nodata_value IS FALSE THEN
				rtn_agg.exclude_nodata_value := FALSE;
			ELSE
				rtn_agg.exclude_nodata_value := TRUE;
			END IF;

			IF sample_percent < 0. OR sample_percent > 1. THEN
				RAISE EXCEPTION 'Sample percent must be between zero and one';
			ELSE
				rtn_agg.sample_percent := sample_percent;
			END IF;
		ELSE
			rtn_agg := agg;
		END IF;

		IF rast IS NOT NULL THEN
			IF rtn_agg.exclude_nodata_value IS FALSE THEN
				SELECT width * height INTO _count FROM @extschema@.ST_Metadata(rast);
			ELSE
				SELECT count INTO _count FROM @extschema@._ST_summarystats(
					rast,
				 	rtn_agg.nband, rtn_agg.exclude_nodata_value,
					rtn_agg.sample_percent
				);
			END IF;
		END IF;

		rtn_agg.count := rtn_agg.count + _count;
		RETURN rtn_agg;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_countagg_transfn(
	agg agg_count,
	rast raster,
 	nband integer, exclude_nodata_value boolean,
	sample_percent double precision
)
	RETURNS agg_count
	AS $$
	DECLARE
		rtn_agg agg_count;
	BEGIN
		rtn_agg :=  @extschema@.__st_countagg_transfn(
			agg,
			rast,
			nband, exclude_nodata_value,
			sample_percent
		);
		RETURN rtn_agg;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
-- Aggregate st_countagg(raster,integer,boolean,double precision) -- LastUpdated: 202
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 202 > version_from_num OR (
      202 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS st_countagg(raster,integer,boolean,double precision)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE AGGREGATE st_countagg(raster, integer, boolean, double precision) (
	SFUNC = _st_countagg_transfn,
	STYPE = agg_count,

	parallel = safe,

	FINALFUNC = _st_countagg_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_countagg_transfn(
	agg agg_count,
	rast raster,
 	nband integer, exclude_nodata_value boolean
)
	RETURNS agg_count
	AS $$
	DECLARE
		rtn_agg agg_count;
	BEGIN
		rtn_agg :=  @extschema@.__ST_countagg_transfn(
			agg,
			rast,
			nband, exclude_nodata_value,
			1
		);
		RETURN rtn_agg;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
-- Aggregate st_countagg(raster,integer,boolean) -- LastUpdated: 202
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 202 > version_from_num OR (
      202 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS st_countagg(raster,integer,boolean)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE AGGREGATE st_countagg(raster, integer, boolean) (
	SFUNC = _st_countagg_transfn,
	STYPE = agg_count,

	parallel = safe,

	FINALFUNC = _st_countagg_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_countagg_transfn(
	agg agg_count,
	rast raster,
 	exclude_nodata_value boolean
)
	RETURNS agg_count
	AS $$
	DECLARE
		rtn_agg agg_count;
	BEGIN
		rtn_agg :=  @extschema@.__ST_countagg_transfn(
			agg,
			rast,
			1, exclude_nodata_value,
			1
		);
		RETURN rtn_agg;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
-- Aggregate st_countagg(raster,boolean) -- LastUpdated: 202
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 202 > version_from_num OR (
      202 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS st_countagg(raster,boolean)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE AGGREGATE st_countagg(raster, boolean) (
	SFUNC = _st_countagg_transfn,
	STYPE = agg_count,

	parallel = safe,

	FINALFUNC = _st_countagg_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_count(rastertable text, rastercolumn text, nband integer DEFAULT 1, exclude_nodata_value boolean DEFAULT TRUE, sample_percent double precision DEFAULT 1)
	RETURNS bigint
	AS $$
	DECLARE
		count bigint;
	BEGIN
		EXECUTE 'SELECT @extschema@.ST_CountAgg('
			|| quote_ident($2) || ', '
			|| $3 || ', '
			|| $4 || ', '
			|| $5 || ') '
			|| 'FROM ' || quote_ident($1)
	 	INTO count;
		RETURN count;
	END;
 	$$ LANGUAGE 'plpgsql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_count(rastertable text, rastercolumn text, nband int DEFAULT 1, exclude_nodata_value boolean DEFAULT TRUE)
	RETURNS bigint
	AS $$ SELECT @extschema@._ST_count($1, $2, $3, $4, 1) $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_count(rastertable text, rastercolumn text, exclude_nodata_value boolean)
	RETURNS bigint
	AS $$ SELECT @extschema@._ST_count($1, $2, 1, $3, 1) $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_approxcount(rastertable text, rastercolumn text, nband int DEFAULT 1, exclude_nodata_value boolean DEFAULT TRUE, sample_percent double precision DEFAULT 0.1)
	RETURNS bigint
	AS $$ SELECT @extschema@._ST_count($1, $2, $3, $4, $5) $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_approxcount(rastertable text, rastercolumn text, nband int, sample_percent double precision)
	RETURNS bigint
	AS $$ SELECT @extschema@._ST_count($1, $2, $3, TRUE, $4) $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_approxcount(rastertable text, rastercolumn text, exclude_nodata_value boolean, sample_percent double precision DEFAULT 0.1)
	RETURNS bigint
	AS $$ SELECT @extschema@._ST_count($1, $2, 1, $3, $4) $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_approxcount(rastertable text, rastercolumn text, sample_percent double precision)
	RETURNS bigint
	AS $$ SELECT @extschema@._ST_count($1, $2, 1, TRUE, $3) $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION _st_histogram(
	rast raster, nband int DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	sample_percent double precision DEFAULT 1,
	bins int DEFAULT 0, width double precision[] DEFAULT NULL,
	right boolean DEFAULT FALSE,
	min double precision DEFAULT NULL, max double precision DEFAULT NULL,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS '$libdir/rtpostgis-2.5','RASTER_histogram'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_histogram(
	rast raster, nband int DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	bins int DEFAULT 0, width double precision[] DEFAULT NULL,
	right boolean DEFAULT FALSE,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT min, max, count, percent FROM @extschema@._ST_histogram($1, $2, $3, 1, $4, $5, $6) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_histogram(
	rast raster, nband int,
	exclude_nodata_value boolean,
	bins int,
	right boolean,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT min, max, count, percent FROM @extschema@._ST_histogram($1, $2, $3, 1, $4, NULL, $5) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_histogram(
	rast raster, nband int,
	bins int, width double precision[] DEFAULT NULL,
	right boolean DEFAULT FALSE,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT min, max, count, percent FROM @extschema@._ST_histogram($1, $2, TRUE, 1, $3, $4, $5) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_histogram(
	rast raster, nband int,
	bins int,
	right boolean,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT min, max, count, percent FROM @extschema@._ST_histogram($1, $2, TRUE, 1, $3, NULL, $4) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxhistogram(
	rast raster, nband int DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	sample_percent double precision DEFAULT 0.1,
	bins int DEFAULT 0, width double precision[] DEFAULT NULL,
	right boolean DEFAULT FALSE,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT min, max, count, percent FROM @extschema@._ST_histogram($1, $2, $3, $4, $5, $6, $7) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxhistogram(
	rast raster, nband int,
	exclude_nodata_value boolean,
	sample_percent double precision,
	bins int,
	right boolean,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT min, max, count, percent FROM @extschema@._ST_histogram($1, $2, $3, $4, $5, NULL, $6) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxhistogram(
	rast raster, nband int,
	sample_percent double precision,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT min, max, count, percent FROM @extschema@._ST_histogram($1, $2, TRUE, $3, 0, NULL, FALSE) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxhistogram(
	rast raster,
	sample_percent double precision,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT min, max, count, percent FROM @extschema@._ST_histogram($1, 1, TRUE, $2, 0, NULL, FALSE) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxhistogram(
	rast raster, nband int,
	sample_percent double precision,
	bins int, width double precision[] DEFAULT NULL,
	right boolean DEFAULT FALSE,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT min, max, count, percent FROM @extschema@._ST_histogram($1, $2, TRUE, $3, $4, $5, $6) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxhistogram(
	rast raster, nband int,
	sample_percent double precision,
	bins int, right boolean,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT min, max, count, percent FROM @extschema@._ST_histogram($1, $2, TRUE, $3, $4, NULL, $5) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_histogram(
	rastertable text, rastercolumn text,
	nband int DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	sample_percent double precision DEFAULT 1,
	bins int DEFAULT 0, width double precision[] DEFAULT NULL,
	right boolean DEFAULT FALSE,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS '$libdir/rtpostgis-2.5','RASTER_histogramCoverage'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_histogram(
	rastertable text, rastercolumn text, nband int DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	bins int DEFAULT 0, width double precision[] DEFAULT NULL,
	right boolean DEFAULT FALSE,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_histogram($1, $2, $3, $4, 1, $5, $6, $7) $$
	LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION st_histogram(
	rastertable text, rastercolumn text, nband int,
	exclude_nodata_value boolean,
	bins int,
	right boolean,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_histogram($1, $2, $3, $4, 1, $5, NULL, $6) $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_histogram(
	rastertable text, rastercolumn text, nband int,
	bins int, width double precision[] DEFAULT NULL,
	right boolean DEFAULT FALSE,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_histogram($1, $2, $3, TRUE, 1, $4, $5, $6) $$
	LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION st_histogram(
	rastertable text, rastercolumn text, nband int,
	bins int,
	right boolean,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_histogram($1, $2, $3, TRUE, 1, $4, NULL, $5) $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_approxhistogram(
	rastertable text, rastercolumn text,
	nband int DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	sample_percent double precision DEFAULT 0.1,
	bins int DEFAULT 0, width double precision[] DEFAULT NULL,
	right boolean DEFAULT FALSE,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_histogram($1, $2, $3, $4, $5, $6, $7, $8) $$
	LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION st_approxhistogram(
	rastertable text, rastercolumn text, nband int,
	exclude_nodata_value boolean,
	sample_percent double precision,
	bins int,
	right boolean,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_histogram($1, $2, $3, $4, $5, $6, NULL, $7) $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_approxhistogram(
	rastertable text, rastercolumn text, nband int,
	sample_percent double precision,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_histogram($1, $2, $3, TRUE, $4, 0, NULL, FALSE) $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_approxhistogram(
	rastertable text, rastercolumn text,
	sample_percent double precision,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_histogram($1, $2, 1, TRUE, $3, 0, NULL, FALSE) $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_approxhistogram(
	rastertable text, rastercolumn text, nband int,
	sample_percent double precision,
	bins int, width double precision[] DEFAULT NULL,
	right boolean DEFAULT FALSE,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_histogram($1, $2, $3, TRUE, $4, $5, $6, $7) $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_approxhistogram(
	rastertable text, rastercolumn text, nband int,
	sample_percent double precision,
	bins int,
	right boolean,
	OUT min double precision,
	OUT max double precision,
	OUT count bigint,
	OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_histogram($1, $2, $3, TRUE, $4, $5, NULL, $6) $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION _st_quantile(
	rast raster,
	nband int DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	sample_percent double precision DEFAULT 1,
	quantiles double precision[] DEFAULT NULL,
	OUT quantile double precision,
	OUT value double precision
)
	RETURNS SETOF record
	AS '$libdir/rtpostgis-2.5','RASTER_quantile'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_quantile(
	rast raster,
	nband int DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	quantiles double precision[] DEFAULT NULL,
	OUT quantile double precision,
	OUT value double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_quantile($1, $2, $3, 1, $4) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_quantile(
	rast raster,
	nband int,
	quantiles double precision[],
	OUT quantile double precision,
	OUT value double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_quantile($1, $2, TRUE, 1, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_quantile(
	rast raster,
	quantiles double precision[],
	OUT quantile double precision,
	OUT value double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_quantile($1, 1, TRUE, 1, $2) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_quantile(rast raster, nband int, exclude_nodata_value boolean, quantile double precision)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, $2, $3, 1, ARRAY[$4]::double precision[])).value $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_quantile(rast raster, nband int, quantile double precision)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, $2, TRUE, 1, ARRAY[$3]::double precision[])).value $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_quantile(rast raster, exclude_nodata_value boolean, quantile double precision DEFAULT NULL)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, 1, $2, 1, ARRAY[$3]::double precision[])).value $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_quantile(rast raster, quantile double precision)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, 1, TRUE, 1, ARRAY[$2]::double precision[])).value $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxquantile(
	rast raster,
	nband int DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	sample_percent double precision DEFAULT 0.1,
	quantiles double precision[] DEFAULT NULL,
	OUT quantile double precision,
	OUT value double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_quantile($1, $2, $3, $4, $5) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxquantile(
	rast raster,
	nband int,
	sample_percent double precision,
	quantiles double precision[] DEFAULT NULL,
	OUT quantile double precision,
	OUT value double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_quantile($1, $2, TRUE, $3, $4) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxquantile(
	rast raster,
	sample_percent double precision,
	quantiles double precision[] DEFAULT NULL,
	OUT quantile double precision,
	OUT value double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_quantile($1, 1, TRUE, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxquantile(
	rast raster,
	quantiles double precision[],
	OUT quantile double precision,
	OUT value double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_quantile($1, 1, TRUE, 0.1, $2) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxquantile(rast raster, nband int, exclude_nodata_value boolean, sample_percent double precision, quantile double precision)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, $2, $3, $4, ARRAY[$5]::double precision[])).value $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxquantile(rast raster, nband int, sample_percent double precision, quantile double precision)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, $2, TRUE, $3, ARRAY[$4]::double precision[])).value $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxquantile(rast raster, sample_percent double precision, quantile double precision)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, 1, TRUE, $2, ARRAY[$3]::double precision[])).value $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxquantile(rast raster, exclude_nodata_value boolean, quantile double precision DEFAULT NULL)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, 1, $2, 0.1, ARRAY[$3]::double precision[])).value $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_approxquantile(rast raster, quantile double precision)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, 1, TRUE, 0.1, ARRAY[$2]::double precision[])).value $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_quantile(
	rastertable text,
	rastercolumn text,
	nband int DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	sample_percent double precision DEFAULT 1,
	quantiles double precision[] DEFAULT NULL,
	OUT quantile double precision,
	OUT value double precision
)
	RETURNS SETOF record
	AS '$libdir/rtpostgis-2.5','RASTER_quantileCoverage'
	LANGUAGE 'c' STABLE;
CREATE OR REPLACE FUNCTION st_quantile(
	rastertable text,
	rastercolumn text,
	nband int DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	quantiles double precision[] DEFAULT NULL,
	OUT quantile double precision,
	OUT value double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_quantile($1, $2, $3, $4, 1, $5) $$
	LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION st_quantile(
	rastertable text,
	rastercolumn text,
	nband int,
	quantiles double precision[],
	OUT quantile double precision,
	OUT value double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_quantile($1, $2, $3, TRUE, 1, $4) $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_quantile(
	rastertable text,
	rastercolumn text,
	quantiles double precision[],
	OUT quantile double precision,
	OUT value double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_quantile($1, $2, 1, TRUE, 1, $3) $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_quantile(rastertable text, rastercolumn text, nband int, exclude_nodata_value boolean, quantile double precision)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, $2, $3, $4, 1, ARRAY[$5]::double precision[])).value $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_quantile(rastertable text, rastercolumn text, nband int, quantile double precision)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, $2, $3, TRUE, 1, ARRAY[$4]::double precision[])).value $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_quantile(rastertable text, rastercolumn text, exclude_nodata_value boolean, quantile double precision DEFAULT NULL)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, $2, 1, $3, 1, ARRAY[$4]::double precision[])).value $$
	LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION st_quantile(rastertable text, rastercolumn text, quantile double precision)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, $2, 1, TRUE, 1, ARRAY[$3]::double precision[])).value $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_approxquantile(
	rastertable text,
	rastercolumn text,
	nband int DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	sample_percent double precision DEFAULT 0.1,
	quantiles double precision[] DEFAULT NULL,
	OUT quantile double precision,
	OUT value double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_quantile($1, $2, $3, $4, $5, $6) $$
	LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION st_approxquantile(
	rastertable text,
	rastercolumn text,
	nband int,
	sample_percent double precision,
	quantiles double precision[] DEFAULT NULL,
	OUT quantile double precision,
	OUT value double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_quantile($1, $2, $3, TRUE, $4, $5) $$
	LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION st_approxquantile(
	rastertable text,
	rastercolumn text,
	sample_percent double precision,
	quantiles double precision[] DEFAULT NULL,
	OUT quantile double precision,
	OUT value double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_quantile($1, $2, 1, TRUE, $3, $4) $$
	LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION st_approxquantile(
	rastertable text,
	rastercolumn text,
	quantiles double precision[],
	OUT quantile double precision,
	OUT value double precision
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@._ST_quantile($1, $2, 1, TRUE, 0.1, $3) $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_approxquantile(rastertable text, rastercolumn text, nband int, exclude_nodata_value boolean, sample_percent double precision, quantile double precision)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, $2, $3, $4, $5, ARRAY[$6]::double precision[])).value $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_approxquantile(rastertable text, rastercolumn text, nband int, sample_percent double precision, quantile double precision)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, $2, $3, TRUE, $4, ARRAY[$5]::double precision[])).value $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_approxquantile(rastertable text, rastercolumn text, sample_percent double precision, quantile double precision)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, $2, 1, TRUE, $3, ARRAY[$4]::double precision[])).value $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_approxquantile(rastertable text, rastercolumn text, exclude_nodata_value boolean, quantile double precision DEFAULT NULL)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, $2, 1, $3, 0.1, ARRAY[$4]::double precision[])).value $$
	LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION st_approxquantile(rastertable text, rastercolumn text, quantile double precision)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_quantile($1, $2, 1, TRUE, 0.1, ARRAY[$3]::double precision[])).value $$
	LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION _st_valuecount(
	rast raster, nband integer DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	searchvalues double precision[] DEFAULT NULL,
	roundto double precision DEFAULT 0,
	OUT value double precision,
	OUT count integer,
	OUT percent double precision
)
	RETURNS SETOF record
	AS '$libdir/rtpostgis-2.5', 'RASTER_valueCount'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_valuecount(
	rast raster, nband integer DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	searchvalues double precision[] DEFAULT NULL,
	roundto double precision DEFAULT 0,
	OUT value double precision, OUT count integer
)
	RETURNS SETOF record
	AS $$ SELECT value, count FROM @extschema@._ST_valuecount($1, $2, $3, $4, $5) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_valuecount(rast raster, nband integer, searchvalues double precision[], roundto double precision DEFAULT 0, OUT value double precision, OUT count integer)
	RETURNS SETOF record
	AS $$ SELECT value, count FROM @extschema@._ST_valuecount($1, $2, TRUE, $3, $4) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_valuecount(rast raster, searchvalues double precision[], roundto double precision DEFAULT 0, OUT value double precision, OUT count integer)
	RETURNS SETOF record
	AS $$ SELECT value, count FROM @extschema@._ST_valuecount($1, 1, TRUE, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_valuecount(rast raster, nband integer, exclude_nodata_value boolean, searchvalue double precision, roundto double precision DEFAULT 0)
	RETURNS integer
	AS $$ SELECT ( @extschema@._ST_valuecount($1, $2, $3, ARRAY[$4]::double precision[], $5)).count $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_valuecount(rast raster, nband integer, searchvalue double precision, roundto double precision DEFAULT 0)
	RETURNS integer
	AS $$ SELECT ( @extschema@._ST_valuecount($1, $2, TRUE, ARRAY[$3]::double precision[], $4)).count $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_valuecount(rast raster, searchvalue double precision, roundto double precision DEFAULT 0)
	RETURNS integer
	AS $$ SELECT ( @extschema@._ST_valuecount($1, 1, TRUE, ARRAY[$2]::double precision[], $3)).count $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_valuepercent(
	rast raster, nband integer DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	searchvalues double precision[] DEFAULT NULL,
	roundto double precision DEFAULT 0,
	OUT value double precision, OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT value, percent FROM @extschema@._ST_valuecount($1, $2, $3, $4, $5) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_valuepercent(rast raster, nband integer, searchvalues double precision[], roundto double precision DEFAULT 0, OUT value double precision, OUT percent double precision)
	RETURNS SETOF record
	AS $$ SELECT value, percent FROM @extschema@._ST_valuecount($1, $2, TRUE, $3, $4) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_valuepercent(rast raster, searchvalues double precision[], roundto double precision DEFAULT 0, OUT value double precision, OUT percent double precision)
	RETURNS SETOF record
	AS $$ SELECT value, percent FROM @extschema@._ST_valuecount($1, 1, TRUE, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_valuepercent(rast raster, nband integer, exclude_nodata_value boolean, searchvalue double precision, roundto double precision DEFAULT 0)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_valuecount($1, $2, $3, ARRAY[$4]::double precision[], $5)).percent $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_valuepercent(rast raster, nband integer, searchvalue double precision, roundto double precision DEFAULT 0)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_valuecount($1, $2, TRUE, ARRAY[$3]::double precision[], $4)).percent $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_valuepercent(rast raster, searchvalue double precision, roundto double precision DEFAULT 0)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_valuecount($1, 1, TRUE, ARRAY[$2]::double precision[], $3)).percent $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_valuecount(
	rastertable text,
	rastercolumn text,
	nband integer DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	searchvalues double precision[] DEFAULT NULL,
	roundto double precision DEFAULT 0,
	OUT value double precision,
	OUT count integer,
	OUT percent double precision
)
	RETURNS SETOF record
	AS '$libdir/rtpostgis-2.5', 'RASTER_valueCountCoverage'
	LANGUAGE 'c' STABLE;
CREATE OR REPLACE FUNCTION st_valuecount(
	rastertable text, rastercolumn text,
	nband integer DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	searchvalues double precision[] DEFAULT NULL,
	roundto double precision DEFAULT 0,
	OUT value double precision, OUT count integer
)
	RETURNS SETOF record
	AS $$ SELECT value, count FROM @extschema@._ST_valuecount($1, $2, $3, $4, $5, $6) $$
	LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION st_valuecount(rastertable text, rastercolumn text, nband integer, searchvalues double precision[], roundto double precision DEFAULT 0, OUT value double precision, OUT count integer)
	RETURNS SETOF record
	AS $$ SELECT value, count FROM @extschema@._ST_valuecount($1, $2, $3, TRUE, $4, $5) $$
	LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION st_valuecount(rastertable text, rastercolumn text, searchvalues double precision[], roundto double precision DEFAULT 0, OUT value double precision, OUT count integer)
	RETURNS SETOF record
	AS $$ SELECT value, count FROM @extschema@._ST_valuecount($1, $2, 1, TRUE, $3, $4) $$
	LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION st_valuecount(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, searchvalue double precision, roundto double precision DEFAULT 0)
	RETURNS integer
	AS $$ SELECT ( @extschema@._ST_valuecount($1, $2, $3, $4, ARRAY[$5]::double precision[], $6)).count $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_valuecount(rastertable text, rastercolumn text, nband integer, searchvalue double precision, roundto double precision DEFAULT 0)
	RETURNS integer
	AS $$ SELECT ( @extschema@._ST_valuecount($1, $2, $3, TRUE, ARRAY[$4]::double precision[], $5)).count $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_valuecount(rastertable text, rastercolumn text, searchvalue double precision, roundto double precision DEFAULT 0)
	RETURNS integer
	AS $$ SELECT ( @extschema@._ST_valuecount($1, $2, 1, TRUE, ARRAY[$3]::double precision[], $4)).count $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_valuepercent(
	rastertable text, rastercolumn text,
	nband integer DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	searchvalues double precision[] DEFAULT NULL,
	roundto double precision DEFAULT 0,
	OUT value double precision, OUT percent double precision
)
	RETURNS SETOF record
	AS $$ SELECT value, percent FROM @extschema@._ST_valuecount($1, $2, $3, $4, $5, $6) $$
	LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION st_valuepercent(rastertable text, rastercolumn text, nband integer, searchvalues double precision[], roundto double precision DEFAULT 0, OUT value double precision, OUT percent double precision)
	RETURNS SETOF record
	AS $$ SELECT value, percent FROM @extschema@._ST_valuecount($1, $2, $3, TRUE, $4, $5) $$
	LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION st_valuepercent(rastertable text, rastercolumn text, searchvalues double precision[], roundto double precision DEFAULT 0, OUT value double precision, OUT percent double precision)
	RETURNS SETOF record
	AS $$ SELECT value, percent FROM @extschema@._ST_valuecount($1, $2, 1, TRUE, $3, $4) $$
	LANGUAGE 'sql' STABLE;
CREATE OR REPLACE FUNCTION st_valuepercent(rastertable text, rastercolumn text, nband integer, exclude_nodata_value boolean, searchvalue double precision, roundto double precision DEFAULT 0)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_valuecount($1, $2, $3, $4, ARRAY[$5]::double precision[], $6)).percent $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_valuepercent(rastertable text, rastercolumn text, nband integer, searchvalue double precision, roundto double precision DEFAULT 0)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_valuecount($1, $2, $3, TRUE, ARRAY[$4]::double precision[], $5)).percent $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION st_valuepercent(rastertable text, rastercolumn text, searchvalue double precision, roundto double precision DEFAULT 0)
	RETURNS double precision
	AS $$ SELECT ( @extschema@._ST_valuecount($1, $2, 1, TRUE, ARRAY[$3]::double precision[], $4)).percent $$
	LANGUAGE 'sql' STABLE STRICT;
-- Type reclassarg -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE reclassarg AS (
	nband int,
	reclassexpr text,
	pixeltype text,
	nodataval double precision
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_reclass(rast raster, VARIADIC reclassargset reclassarg[])
	RETURNS raster
	AS '$libdir/rtpostgis-2.5', 'RASTER_reclass'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_reclass(rast raster, VARIADIC reclassargset reclassarg[])
	RETURNS raster
	AS $$
	DECLARE
		i int;
		expr text;
	BEGIN
		-- for each reclassarg, validate elements as all except nodataval cannot be NULL
		FOR i IN SELECT * FROM generate_subscripts($2, 1) LOOP
			IF $2[i].nband IS NULL OR $2[i].reclassexpr IS NULL OR $2[i].pixeltype IS NULL THEN
				RAISE WARNING 'Values are required for the nband, reclassexpr and pixeltype attributes.';
				RETURN rast;
			END IF;
		END LOOP;

		RETURN @extschema@._ST_reclass($1, VARIADIC $2);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_reclass(rast raster, nband int, reclassexpr text, pixeltype text, nodataval double precision DEFAULT NULL)
	RETURNS raster
	AS $$ SELECT st_reclass($1, ROW($2, $3, $4, $5)) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_reclass(rast raster, reclassexpr text, pixeltype text)
	RETURNS raster
	AS $$ SELECT st_reclass($1, ROW(1, $2, $3, NULL)) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_colormap(
	rast raster, nband int,
	colormap text,
	method text DEFAULT 'INTERPOLATE'
)
	RETURNS raster
	AS '$libdir/rtpostgis-2.5', 'RASTER_colorMap'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_colormap(
	rast raster, nband int DEFAULT 1,
	colormap text DEFAULT 'grayscale',
	method text DEFAULT 'INTERPOLATE'
)
	RETURNS raster
	AS $$
	DECLARE
		_ismap boolean;
		_colormap text;
		_element text[];
	BEGIN
		_ismap := TRUE;

		-- clean colormap to see what it is
		_colormap := split_part(colormap, E'\n', 1);
		_colormap := regexp_replace(_colormap, E':+', ' ', 'g');
		_colormap := regexp_replace(_colormap, E',+', ' ', 'g');
		_colormap := regexp_replace(_colormap, E'\\t+', ' ', 'g');
		_colormap := regexp_replace(_colormap, E' +', ' ', 'g');
		_element := regexp_split_to_array(_colormap, ' ');

		-- treat as colormap
		IF (array_length(_element, 1) > 1) THEN
			_colormap := colormap;
		-- treat as keyword
		ELSE
			method := 'INTERPOLATE';
			CASE lower(trim(both from _colormap))
				WHEN 'grayscale', 'greyscale' THEN
					_colormap := '
100%   0
  0% 254
  nv 255
					';
				WHEN 'pseudocolor' THEN
					_colormap := '
100% 255   0   0 255
 50%   0 255   0 255
  0%   0   0 255 255
  nv   0   0   0   0
					';
				WHEN 'fire' THEN
					_colormap := '
  100% 243 255 221 255
93.75% 242 255 178 255
 87.5% 255 255 135 255
81.25% 255 228  96 255
   75% 255 187  53 255
68.75% 255 131   7 255
 62.5% 255  84   0 255
56.25% 255  42   0 255
   50% 255   0   0 255
43.75% 255  42   0 255
 37.5% 224  74   0 255
31.25% 183  91   0 255
   25% 140  93   0 255
18.75%  99  82   0 255
 12.5%  58  58   1 255
 6.25%  12  15   0 255
    0%   0   0   0 255
    nv   0   0   0   0
					';
				WHEN 'bluered' THEN
					_colormap := '
100.00% 165   0  33 255
 94.12% 216  21  47 255
 88.24% 247  39  53 255
 82.35% 255  61  61 255
 76.47% 255 120  86 255
 70.59% 255 172 117 255
 64.71% 255 214 153 255
 58.82% 255 241 188 255
 52.94% 255 255 234 255
 47.06% 234 255 255 255
 41.18% 188 249 255 255
 35.29% 153 234 255 255
 29.41% 117 211 255 255
 23.53%  86 176 255 255
 17.65%  61 135 255 255
 11.76%  40  87 255 255
  5.88%  24  28 247 255
  0.00%  36   0 216 255
     nv   0   0   0   0
					';
				ELSE
					RAISE EXCEPTION 'Unknown colormap keyword: %', colormap;
			END CASE;
		END IF;

		RETURN @extschema@._ST_colormap($1, $2, _colormap, $4);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_colormap(
	rast raster,
	colormap text,
	method text DEFAULT 'INTERPOLATE'
)
	RETURNS RASTER
	AS $$ SELECT @extschema@.ST_ColorMap($1, 1, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_fromgdalraster(gdaldata bytea, srid integer DEFAULT NULL)
	RETURNS raster
	AS '$libdir/rtpostgis-2.5', 'RASTER_fromGDALRaster'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_gdaldrivers(
	OUT idx int,
	OUT short_name text,
	OUT long_name text,
	OUT can_read boolean,
	OUT can_write boolean,
	OUT create_options text
)
  RETURNS SETOF record
	AS '$libdir/rtpostgis-2.5', 'RASTER_getGDALDrivers'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asgdalraster(rast raster, format text, options text[] DEFAULT NULL, srid integer DEFAULT NULL)
	RETURNS bytea
	AS '$libdir/rtpostgis-2.5', 'RASTER_asGDALRaster'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_astiff(rast raster, options text[] DEFAULT NULL, srid integer DEFAULT NULL)
	RETURNS bytea
	AS $$
	DECLARE
		i int;
		num_bands int;
		nodata double precision;
		last_nodata double precision;
	BEGIN
		IF rast IS NULL THEN
			RETURN NULL;
		END IF;

		num_bands := st_numbands($1);

		-- TIFF only allows one NODATA value for ALL bands
		FOR i IN 1..num_bands LOOP
			nodata := st_bandnodatavalue($1, i);
			IF last_nodata IS NULL THEN
				last_nodata := nodata;
			ELSEIF nodata != last_nodata THEN
				RAISE NOTICE 'The TIFF format only permits one NODATA value for all bands.  The value used will be the last band with a NODATA value.';
			END IF;
		END LOOP;

		RETURN st_asgdalraster($1, 'GTiff', $2, $3);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_astiff(rast raster, nbands int[], options text[] DEFAULT NULL, srid integer DEFAULT NULL)
	RETURNS bytea
	AS $$ SELECT st_astiff(st_band($1, $2), $3, $4) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_astiff(rast raster, compression text, srid integer DEFAULT NULL)
	RETURNS bytea
	AS $$
	DECLARE
		compression2 text;
		c_type text;
		c_level int;
		i int;
		num_bands int;
		options text[];
	BEGIN
		IF rast IS NULL THEN
			RETURN NULL;
		END IF;

		compression2 := trim(both from upper(compression));

		IF length(compression2) > 0 THEN
			-- JPEG
			IF position('JPEG' in compression2) != 0 THEN
				c_type := 'JPEG';
				c_level := substring(compression2 from '[0-9]+$');

				IF c_level IS NOT NULL THEN
					IF c_level > 100 THEN
						c_level := 100;
					ELSEIF c_level < 1 THEN
						c_level := 1;
					END IF;

					options := array_append(options, 'JPEG_QUALITY=' || c_level);
				END IF;

				-- per band pixel type check
				num_bands := st_numbands($1);
				FOR i IN 1..num_bands LOOP
					IF @extschema@.ST_BandPixelType($1, i) != '8BUI' THEN
						RAISE EXCEPTION 'The pixel type of band % in the raster is not 8BUI.  JPEG compression can only be used with the 8BUI pixel type.', i;
					END IF;
				END LOOP;

			-- DEFLATE
			ELSEIF position('DEFLATE' in compression2) != 0 THEN
				c_type := 'DEFLATE';
				c_level := substring(compression2 from '[0-9]+$');

				IF c_level IS NOT NULL THEN
					IF c_level > 9 THEN
						c_level := 9;
					ELSEIF c_level < 1 THEN
						c_level := 1;
					END IF;

					options := array_append(options, 'ZLEVEL=' || c_level);
				END IF;

			ELSE
				c_type := compression2;

				-- CCITT
				IF position('CCITT' in compression2) THEN
					-- per band pixel type check
					num_bands := st_numbands($1);
					FOR i IN 1..num_bands LOOP
						IF @extschema@.ST_BandPixelType($1, i) != '1BB' THEN
							RAISE EXCEPTION 'The pixel type of band % in the raster is not 1BB.  CCITT compression can only be used with the 1BB pixel type.', i;
						END IF;
					END LOOP;
				END IF;

			END IF;

			-- compression type check
			IF ARRAY[c_type] <@ ARRAY['JPEG', 'LZW', 'PACKBITS', 'DEFLATE', 'CCITTRLE', 'CCITTFAX3', 'CCITTFAX4', 'NONE'] THEN
				options := array_append(options, 'COMPRESS=' || c_type);
			ELSE
				RAISE NOTICE 'Unknown compression type: %.  The outputted TIFF will not be COMPRESSED.', c_type;
			END IF;
		END IF;

		RETURN st_astiff($1, options, $3);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_astiff(rast raster, nbands int[], compression text, srid integer DEFAULT NULL)
	RETURNS bytea
	AS $$ SELECT st_astiff(st_band($1, $2), $3, $4) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asjpeg(rast raster, options text[] DEFAULT NULL)
	RETURNS bytea
	AS $$
	DECLARE
		rast2 @extschema@.raster;
		num_bands int;
		i int;
	BEGIN
		IF rast IS NULL THEN
			RETURN NULL;
		END IF;

		num_bands := st_numbands($1);

		-- JPEG allows 1 or 3 bands
		IF num_bands <> 1 AND num_bands <> 3 THEN
			RAISE NOTICE 'The JPEG format only permits one or three bands.  The first band will be used.';
			rast2 := st_band(rast, ARRAY[1]);
			num_bands := st_numbands(rast);
		ELSE
			rast2 := rast;
		END IF;

		-- JPEG only supports 8BUI pixeltype
		FOR i IN 1..num_bands LOOP
			IF @extschema@.ST_BandPixelType(rast, i) != '8BUI' THEN
				RAISE EXCEPTION 'The pixel type of band % in the raster is not 8BUI.  The JPEG format can only be used with the 8BUI pixel type.', i;
			END IF;
		END LOOP;

		RETURN st_asgdalraster(rast2, 'JPEG', $2, NULL);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asjpeg(rast raster, nbands int[], options text[] DEFAULT NULL)
	RETURNS bytea
	AS $$ SELECT st_asjpeg(st_band($1, $2), $3) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asjpeg(rast raster, nbands int[], quality int)
	RETURNS bytea
	AS $$
	DECLARE
		quality2 int;
		options text[];
	BEGIN
		IF quality IS NOT NULL THEN
			IF quality > 100 THEN
				quality2 := 100;
			ELSEIF quality < 10 THEN
				quality2 := 10;
			ELSE
				quality2 := quality;
			END IF;

			options := array_append(options, 'QUALITY=' || quality2);
		END IF;

		RETURN @extschema@.st_asjpeg(st_band($1, $2), options);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asjpeg(rast raster, nband int, options text[] DEFAULT NULL)
	RETURNS bytea
	AS $$ SELECT @extschema@.st_asjpeg(st_band($1, $2), $3) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asjpeg(rast raster, nband int, quality int)
	RETURNS bytea
	AS $$ SELECT @extschema@.st_asjpeg($1, ARRAY[$2], $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_aspng(rast raster, options text[] DEFAULT NULL)
	RETURNS bytea
	AS $$
	DECLARE
		rast2 @extschema@.raster;
		num_bands int;
		i int;
		pt text;
	BEGIN
		IF rast IS NULL THEN
			RETURN NULL;
		END IF;

		num_bands := st_numbands($1);

		-- PNG allows 1, 3 or 4 bands
		IF num_bands <> 1 AND num_bands <> 3 AND num_bands <> 4 THEN
			RAISE NOTICE 'The PNG format only permits one, three or four bands.  The first band will be used.';
			rast2 := @extschema@.st_band($1, ARRAY[1]);
			num_bands := @extschema@.st_numbands(rast2);
		ELSE
			rast2 := rast;
		END IF;

		-- PNG only supports 8BUI and 16BUI pixeltype
		FOR i IN 1..num_bands LOOP
			pt = @extschema@.ST_BandPixelType(rast, i);
			IF pt != '8BUI' AND pt != '16BUI' THEN
				RAISE EXCEPTION 'The pixel type of band % in the raster is not 8BUI or 16BUI.  The PNG format can only be used with 8BUI and 16BUI pixel types.', i;
			END IF;
		END LOOP;

		RETURN @extschema@.st_asgdalraster(rast2, 'PNG', $2, NULL);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_aspng(rast raster, nbands int[], options text[] DEFAULT NULL)
	RETURNS bytea
	AS $$ SELECT @extschema@.st_aspng(st_band($1, $2), $3) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_aspng(rast raster, nbands int[], compression int)
	RETURNS bytea
	AS $$
	DECLARE
		compression2 int;
		options text[];
	BEGIN
		IF compression IS NOT NULL THEN
			IF compression > 9 THEN
				compression2 := 9;
			ELSEIF compression < 1 THEN
				compression2 := 1;
			ELSE
				compression2 := compression;
			END IF;

			options := array_append(options, 'ZLEVEL=' || compression2);
		END IF;

		RETURN @extschema@.st_aspng(st_band($1, $2), options);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_aspng(rast raster, nband int, options text[] DEFAULT NULL)
	RETURNS bytea
	AS $$ SELECT @extschema@.st_aspng(st_band($1, $2), $3) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_aspng(rast raster, nband int, compression int)
	RETURNS bytea
	AS $$ SELECT @extschema@.st_aspng($1, ARRAY[$2], $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_asraster(
	geom geometry,
	scalex double precision DEFAULT 0, scaley double precision DEFAULT 0,
	width integer DEFAULT 0, height integer DEFAULT 0,
	pixeltype text[] DEFAULT ARRAY['8BUI']::text[],
	value double precision[] DEFAULT ARRAY[1]::double precision[],
	nodataval double precision[] DEFAULT ARRAY[0]::double precision[],
	upperleftx double precision DEFAULT NULL, upperlefty double precision DEFAULT NULL,
	gridx double precision DEFAULT NULL, gridy double precision DEFAULT NULL,
	skewx double precision DEFAULT 0, skewy double precision DEFAULT 0,
	touched boolean DEFAULT FALSE
)
	RETURNS raster
	AS '$libdir/rtpostgis-2.5', 'RASTER_asRaster'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asraster(
	geom geometry,
	scalex double precision, scaley double precision,
	gridx double precision DEFAULT NULL, gridy double precision DEFAULT NULL,
	pixeltype text[] DEFAULT ARRAY['8BUI']::text[],
	value double precision[] DEFAULT ARRAY[1]::double precision[],
	nodataval double precision[] DEFAULT ARRAY[0]::double precision[],
	skewx double precision DEFAULT 0, skewy double precision DEFAULT 0,
	touched boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_asraster($1, $2, $3, NULL, NULL, $6, $7, $8, NULL, NULL, $4, $5, $9, $10, $11) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asraster(
	geom geometry,
	scalex double precision, scaley double precision,
	pixeltype text[],
	value double precision[] DEFAULT ARRAY[1]::double precision[],
	nodataval double precision[] DEFAULT ARRAY[0]::double precision[],
	upperleftx double precision DEFAULT NULL, upperlefty double precision DEFAULT NULL,
	skewx double precision DEFAULT 0, skewy double precision DEFAULT 0,
	touched boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_asraster($1, $2, $3, NULL, NULL, $4, $5, $6, $7, $8, NULL, NULL,	$9, $10, $11) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asraster(
	geom geometry,
	width integer, height integer,
	gridx double precision DEFAULT NULL, gridy double precision DEFAULT NULL,
	pixeltype text[] DEFAULT ARRAY['8BUI']::text[],
	value double precision[] DEFAULT ARRAY[1]::double precision[],
	nodataval double precision[] DEFAULT ARRAY[0]::double precision[],
	skewx double precision DEFAULT 0, skewy double precision DEFAULT 0,
	touched boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_asraster($1, NULL, NULL, $2, $3, $6, $7, $8, NULL, NULL, $4, $5, $9, $10, $11) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asraster(
	geom geometry,
	width integer, height integer,
	pixeltype text[],
	value double precision[] DEFAULT ARRAY[1]::double precision[],
	nodataval double precision[] DEFAULT ARRAY[0]::double precision[],
	upperleftx double precision DEFAULT NULL, upperlefty double precision DEFAULT NULL,
	skewx double precision DEFAULT 0, skewy double precision DEFAULT 0,
	touched boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_asraster($1, NULL, NULL, $2, $3, $4, $5, $6, $7, $8, NULL, NULL,	$9, $10, $11) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asraster(
	geom geometry,
	scalex double precision, scaley double precision,
	gridx double precision, gridy double precision,
	pixeltype text,
	value double precision DEFAULT 1,
	nodataval double precision DEFAULT 0,
	skewx double precision DEFAULT 0, skewy double precision DEFAULT 0,
	touched boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_asraster($1, $2, $3, NULL, NULL, ARRAY[$6]::text[], ARRAY[$7]::double precision[], ARRAY[$8]::double precision[], NULL, NULL, $4, $5, $9, $10, $11) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asraster(
	geom geometry,
	scalex double precision, scaley double precision,
	pixeltype text,
	value double precision DEFAULT 1,
	nodataval double precision DEFAULT 0,
	upperleftx double precision DEFAULT NULL, upperlefty double precision DEFAULT NULL,
	skewx double precision DEFAULT 0, skewy double precision DEFAULT 0,
	touched boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_asraster($1, $2, $3, NULL, NULL, ARRAY[$4]::text[], ARRAY[$5]::double precision[], ARRAY[$6]::double precision[], $7, $8, NULL, NULL, $9, $10, $11) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asraster(
	geom geometry,
	width integer, height integer,
	gridx double precision, gridy double precision,
	pixeltype text,
	value double precision DEFAULT 1,
	nodataval double precision DEFAULT 0,
	skewx double precision DEFAULT 0, skewy double precision DEFAULT 0,
	touched boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_asraster($1, NULL, NULL, $2, $3, ARRAY[$6]::text[], ARRAY[$7]::double precision[], ARRAY[$8]::double precision[], NULL, NULL, $4, $5, $9, $10, $11) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asraster(
	geom geometry,
	width integer, height integer,
	pixeltype text,
	value double precision DEFAULT 1,
	nodataval double precision DEFAULT 0,
	upperleftx double precision DEFAULT NULL, upperlefty double precision DEFAULT NULL,
	skewx double precision DEFAULT 0, skewy double precision DEFAULT 0,
	touched boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_asraster($1, NULL, NULL, $2, $3, ARRAY[$4]::text[], ARRAY[$5]::double precision[], ARRAY[$6]::double precision[], $7, $8, NULL, NULL,$9, $10, $11) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asraster(
	geom geometry,
	ref raster,
	pixeltype text[] DEFAULT ARRAY['8BUI']::text[],
	value double precision[] DEFAULT ARRAY[1]::double precision[],
	nodataval double precision[] DEFAULT ARRAY[0]::double precision[],
	touched boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$
	DECLARE
		g @extschema@.geometry;
		g_srid integer;

		ul_x double precision;
		ul_y double precision;
		scale_x double precision;
		scale_y double precision;
		skew_x double precision;
		skew_y double precision;
		sr_id integer;
	BEGIN
		SELECT upperleftx, upperlefty, scalex, scaley, skewx, skewy, srid INTO ul_x, ul_y, scale_x, scale_y, skew_x, skew_y, sr_id FROM @extschema@.ST_Metadata(ref);
		--RAISE NOTICE '%, %, %, %, %, %, %', ul_x, ul_y, scale_x, scale_y, skew_x, skew_y, sr_id;

		-- geometry and raster has different SRID
		g_srid := @extschema@.ST_SRID(geom);
		IF g_srid != sr_id THEN
			RAISE NOTICE 'The geometry''s SRID (%) is not the same as the raster''s SRID (%).  The geometry will be transformed to the raster''s projection', g_srid, sr_id;
			g := @extschema@.ST_Transform(geom, sr_id);
		ELSE
			g := geom;
		END IF;

		RETURN @extschema@._ST_asraster(g, scale_x, scale_y, NULL, NULL, $3, $4, $5, NULL, NULL, ul_x, ul_y, skew_x, skew_y, $6);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asraster(
	geom geometry,
	ref raster,
	pixeltype text,
	value double precision DEFAULT 1,
	nodataval double precision DEFAULT 0,
	touched boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$ SELECT  @extschema@.ST_AsRaster($1, $2, ARRAY[$3]::text[], ARRAY[$4]::double precision[], ARRAY[$5]::double precision[], $6) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_gdalwarp(
	rast raster,
	algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125,
	srid integer DEFAULT NULL,
	scalex double precision DEFAULT 0, scaley double precision DEFAULT 0,
	gridx double precision DEFAULT NULL, gridy double precision DEFAULT NULL,
	skewx double precision DEFAULT 0, skewy double precision DEFAULT 0,
	width integer DEFAULT NULL, height integer DEFAULT NULL
)
	RETURNS raster
	AS '$libdir/rtpostgis-2.5', 'RASTER_GDALWarp'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_resample(
	rast raster,
	scalex double precision DEFAULT 0, scaley double precision DEFAULT 0,
	gridx double precision DEFAULT NULL, gridy double precision DEFAULT NULL,
	skewx double precision DEFAULT 0, skewy double precision DEFAULT 0,
	algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_gdalwarp($1, $8,	$9, NULL, $2, $3, $4, $5, $6, $7) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_resample(
	rast raster,
	width integer, height integer,
	gridx double precision DEFAULT NULL, gridy double precision DEFAULT NULL,
	skewx double precision DEFAULT 0, skewy double precision DEFAULT 0,
	algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_gdalwarp($1, $8,	$9, NULL, NULL, NULL, $4, $5, $6, $7, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_resample(
	rast raster,
	ref raster,
	algorithm text DEFAULT 'NearestNeighbour',
	maxerr double precision DEFAULT 0.125,
	usescale boolean DEFAULT TRUE
)
	RETURNS raster
	AS $$
	DECLARE
		rastsrid int;

		_srid int;
		_dimx int;
		_dimy int;
		_scalex double precision;
		_scaley double precision;
		_gridx double precision;
		_gridy double precision;
		_skewx double precision;
		_skewy double precision;
	BEGIN
		SELECT srid, width, height, scalex, scaley, upperleftx, upperlefty, skewx, skewy INTO _srid, _dimx, _dimy, _scalex, _scaley, _gridx, _gridy, _skewx, _skewy FROM st_metadata($2);

		rastsrid := @extschema@.ST_SRID($1);

		-- both rasters must have the same SRID
		IF (rastsrid != _srid) THEN
			RAISE EXCEPTION 'The raster to be resampled has a different SRID from the reference raster';
			RETURN NULL;
		END IF;

		IF usescale IS TRUE THEN
			_dimx := NULL;
			_dimy := NULL;
		ELSE
			_scalex := NULL;
			_scaley := NULL;
		END IF;

		RETURN @extschema@._ST_gdalwarp($1, $3, $4, NULL, _scalex, _scaley, _gridx, _gridy, _skewx, _skewy, _dimx, _dimy);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_resample(
	rast raster,
	ref raster,
	usescale boolean,
	algorithm text DEFAULT 'NearestNeighbour',
	maxerr double precision DEFAULT 0.125
)
	RETURNS raster
	AS $$ SELECT @extschema@.st_resample($1, $2, $4, $5, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_transform(rast raster, srid integer, algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125, scalex double precision DEFAULT 0, scaley double precision DEFAULT 0)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_gdalwarp($1, $3, $4, $2, $5, $6) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_transform(rast raster, srid integer, scalex double precision, scaley double precision, algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_gdalwarp($1, $5, $6, $2, $3, $4) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_transform(rast raster, srid integer, scalexy double precision, algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_gdalwarp($1, $4, $5, $2, $3, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_transform(
	rast raster,
	alignto raster,
	algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125
)
	RETURNS raster
	AS $$
	DECLARE
		_srid integer;
		_scalex double precision;
		_scaley double precision;
		_gridx double precision;
		_gridy double precision;
		_skewx double precision;
		_skewy double precision;
	BEGIN
		SELECT srid, scalex, scaley, upperleftx, upperlefty, skewx, skewy INTO _srid, _scalex, _scaley, _gridx, _gridy, _skewx, _skewy FROM st_metadata($2);

		RETURN @extschema@._ST_gdalwarp($1, $3, $4, _srid, _scalex, _scaley, _gridx, _gridy, _skewx, _skewy, NULL, NULL);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_rescale(rast raster, scalex double precision, scaley double precision, algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125)
	RETURNS raster
	AS $$ SELECT  @extschema@._ST_GdalWarp($1, $4, $5, NULL, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_rescale(rast raster, scalexy double precision, algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125)
	RETURNS raster
	AS $$ SELECT  @extschema@._ST_GdalWarp($1, $3, $4, NULL, $2, $2) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_reskew(rast raster, skewx double precision, skewy double precision, algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_GdalWarp($1, $4, $5, NULL, 0, 0, NULL, NULL, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_reskew(rast raster, skewxy double precision, algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_GdalWarp($1, $3, $4, NULL, 0, 0, NULL, NULL, $2, $2) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_snaptogrid(
	rast raster,
	gridx double precision, gridy double precision,
	algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125,
	scalex double precision DEFAULT 0, scaley double precision DEFAULT 0
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_GdalWarp($1, $4, $5, NULL, $6, $7, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_snaptogrid(
	rast raster,
	gridx double precision, gridy double precision,
	scalex double precision, scaley double precision,
	algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_gdalwarp($1, $6, $7, NULL, $4, $5, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_snaptogrid(
	rast raster,
	gridx double precision, gridy double precision,
	scalexy double precision,
	algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_gdalwarp($1, $5, $6, NULL, $4, $4, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_resize(
	rast raster,
	width text, height text,
	algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125
)
	RETURNS raster
	AS $$
	DECLARE
		i integer;

		wh text[2];

		whi integer[2];
		whd double precision[2];

		_width integer;
		_height integer;
	BEGIN
		wh[1] := trim(both from $2);
		wh[2] := trim(both from $3);

		-- see if width and height are percentages
		FOR i IN 1..2 LOOP
			IF position('%' in wh[i]) > 0 THEN
				BEGIN
					wh[i] := (regexp_matches(wh[i], E'^(\\d*.?\\d*)%{1}$'))[1];
					IF length(wh[i]) < 1 THEN
						RAISE invalid_parameter_value;
					END IF;

					whd[i] := wh[i]::double precision * 0.01;
				EXCEPTION WHEN OTHERS THEN -- TODO: WHEN invalid_parameter_value !
					RAISE EXCEPTION 'Invalid percentage value provided for width/height';
					RETURN NULL;
				END;
			ELSE
				BEGIN
					whi[i] := abs(wh[i]::integer);
				EXCEPTION WHEN OTHERS THEN -- TODO: only handle appropriate SQLSTATE
					RAISE EXCEPTION 'Non-integer value provided for width/height';
					RETURN NULL;
				END;
			END IF;
		END LOOP;

		IF whd[1] IS NOT NULL OR whd[2] IS NOT NULL THEN
			SELECT foo.width, foo.height INTO _width, _height FROM @extschema@.ST_Metadata($1) AS foo;

			IF whd[1] IS NOT NULL THEN
				whi[1] := round(_width::double precision * whd[1])::integer;
			END IF;

			IF whd[2] IS NOT NULL THEN
				whi[2] := round(_height::double precision * whd[2])::integer;
			END IF;

		END IF;

		-- should NEVER be here
		IF whi[1] IS NULL OR whi[2] IS NULL THEN
			RAISE EXCEPTION 'Unable to determine appropriate width or height';
			RETURN NULL;
		END IF;

		FOR i IN 1..2 LOOP
			IF whi[i] < 1 THEN
				whi[i] = 1;
			END IF;
		END LOOP;

		RETURN @extschema@._ST_gdalwarp(
			$1,
			$4, $5,
			NULL,
			NULL, NULL,
			NULL, NULL,
			NULL, NULL,
			whi[1], whi[2]
		);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_resize(
	rast raster,
	width integer, height integer,
	algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_gdalwarp($1, $4, $5, NULL, NULL, NULL, NULL, NULL, NULL, NULL, abs($2), abs($3)) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_resize(
	rast raster,
	percentwidth double precision, percentheight double precision,
	algorithm text DEFAULT 'NearestNeighbour', maxerr double precision DEFAULT 0.125
)
	RETURNS raster
	AS $$
	DECLARE
		_width integer;
		_height integer;
	BEGIN
		-- range check
		IF $2 <= 0. OR $2 > 1. OR $3 <= 0. OR $3 > 1. THEN
			RAISE EXCEPTION 'Percentages must be a value greater than zero and less than or equal to one, e.g. 0.5 for 50%%';
		END IF;

		SELECT width, height INTO _width, _height FROM @extschema@.ST_Metadata($1);

		_width := round(_width::double precision * $2)::integer;
		_height:= round(_height::double precision * $3)::integer;

		IF _width < 1 THEN
			_width := 1;
		END IF;
		IF _height < 1 THEN
			_height := 1;
		END IF;

		RETURN @extschema@._ST_gdalwarp(
			$1,
			$4, $5,
			NULL,
			NULL, NULL,
			NULL, NULL,
			NULL, NULL,
			_width, _height
		);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebraexpr(rast raster, band integer, pixeltype text,
        expression text, nodataval double precision DEFAULT NULL)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5', 'RASTER_mapAlgebraExpr'
    LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebraexpr(rast raster, pixeltype text, expression text,
        nodataval double precision DEFAULT NULL)
    RETURNS raster
    AS $$ SELECT @extschema@.ST_mapalgebraexpr($1, 1, $2, $3, $4) $$
    LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebrafct(rast raster, band integer,
        pixeltype text, onerastuserfunc regprocedure, variadic args text[])
    RETURNS raster
    AS '$libdir/rtpostgis-2.5', 'RASTER_mapAlgebraFct'
    LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebrafct(rast raster, band integer,
        pixeltype text, onerastuserfunc regprocedure)
    RETURNS raster
    AS $$ SELECT @extschema@.ST_mapalgebrafct($1, $2, $3, $4, NULL) $$
    LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebrafct(rast raster, band integer,
        onerastuserfunc regprocedure, variadic args text[])
    RETURNS raster
    AS $$ SELECT @extschema@.ST_mapalgebrafct($1, $2, NULL, $3, VARIADIC $4) $$
    LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebrafct(rast raster, band integer,
        onerastuserfunc regprocedure)
    RETURNS raster
    AS $$ SELECT @extschema@.ST_mapalgebrafct($1, $2, NULL, $3, NULL) $$
    LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebrafct(rast raster, pixeltype text,
        onerastuserfunc regprocedure, variadic args text[])
    RETURNS raster
    AS $$ SELECT @extschema@.ST_mapalgebrafct($1, 1, $2, $3, VARIADIC $4) $$
    LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebrafct(rast raster, pixeltype text,
        onerastuserfunc regprocedure)
    RETURNS raster
    AS $$ SELECT @extschema@.ST_mapalgebrafct($1, 1, $2, $3, NULL) $$
    LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebrafct(rast raster, onerastuserfunc regprocedure,
        variadic args text[])
    RETURNS raster
    AS $$ SELECT @extschema@.ST_mapalgebrafct($1, 1, NULL, $2, VARIADIC $3) $$
    LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebrafct(rast raster, onerastuserfunc regprocedure)
    RETURNS raster
    AS $$ SELECT @extschema@.ST_mapalgebrafct($1, 1, NULL, $2, NULL) $$
    LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebraexpr(
	rast1 raster, band1 integer,
	rast2 raster, band2 integer,
	expression text,
	pixeltype text DEFAULT NULL, extenttype text DEFAULT 'INTERSECTION',
	nodata1expr text DEFAULT NULL, nodata2expr text DEFAULT NULL,
	nodatanodataval double precision DEFAULT NULL
)
	RETURNS raster
	AS '$libdir/rtpostgis-2.5', 'RASTER_mapAlgebra2'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebraexpr(
	rast1 raster,
	rast2 raster,
	expression text,
	pixeltype text DEFAULT NULL, extenttype text DEFAULT 'INTERSECTION',
	nodata1expr text DEFAULT NULL, nodata2expr text DEFAULT NULL,
	nodatanodataval double precision DEFAULT NULL
)
	RETURNS raster
	AS $$ SELECT @extschema@.ST_mapalgebraexpr($1, 1, $2, 1, $3, $4, $5, $6, $7, $8) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebrafct(
	rast1 raster, band1 integer,
	rast2 raster, band2 integer,
	tworastuserfunc regprocedure,
	pixeltype text DEFAULT NULL, extenttype text DEFAULT 'INTERSECTION',
	VARIADIC userargs text[] DEFAULT NULL
)
	RETURNS raster
	AS '$libdir/rtpostgis-2.5', 'RASTER_mapAlgebra2'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebrafct(
	rast1 raster,
	rast2 raster,
	tworastuserfunc regprocedure,
	pixeltype text DEFAULT NULL, extenttype text DEFAULT 'INTERSECTION',
	VARIADIC userargs text[] DEFAULT NULL
)
	RETURNS raster
	AS $$ SELECT @extschema@.ST_mapalgebrafct($1, 1, $2, 1, $3, $4, $5, VARIADIC $6) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebrafctngb(
    rast raster,
    band integer,
    pixeltype text,
    ngbwidth integer,
    ngbheight integer,
    onerastngbuserfunc regprocedure,
    nodatamode text,
    variadic args text[]
)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5', 'RASTER_mapAlgebraFctNgb'
    LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_max4ma(matrix float[][], nodatamode text, variadic args text[])
    RETURNS float AS
    $$
    DECLARE
        _matrix float[][];
        max float;
    BEGIN
        _matrix := matrix;
        max := '-Infinity'::float;
        FOR x in array_lower(_matrix, 1)..array_upper(_matrix, 1) LOOP
            FOR y in array_lower(_matrix, 2)..array_upper(_matrix, 2) LOOP
                IF _matrix[x][y] IS NULL THEN
                    IF NOT nodatamode = 'ignore' THEN
                        _matrix[x][y] := nodatamode::float;
                    END IF;
                END IF;
                IF max < _matrix[x][y] THEN
                    max := _matrix[x][y];
                END IF;
            END LOOP;
        END LOOP;
        RETURN max;
    END;
    $$
    LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_min4ma(matrix float[][], nodatamode text, variadic args text[])
    RETURNS float AS
    $$
    DECLARE
        _matrix float[][];
        min float;
    BEGIN
        _matrix := matrix;
        min := 'Infinity'::float;
        FOR x in array_lower(_matrix, 1)..array_upper(_matrix, 1) LOOP
            FOR y in array_lower(_matrix, 2)..array_upper(_matrix, 2) LOOP
                IF _matrix[x][y] IS NULL THEN
                    IF NOT nodatamode = 'ignore' THEN
                        _matrix[x][y] := nodatamode::float;
                    END IF;
                END IF;
                IF min > _matrix[x][y] THEN
                    min := _matrix[x][y];
                END IF;
            END LOOP;
        END LOOP;
        RETURN min;
    END;
    $$
    LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_sum4ma(matrix float[][], nodatamode text, variadic args text[])
    RETURNS float AS
    $$
    DECLARE
        _matrix float[][];
        sum float;
    BEGIN
        _matrix := matrix;
        sum := 0;
        FOR x in array_lower(matrix, 1)..array_upper(matrix, 1) LOOP
            FOR y in array_lower(matrix, 2)..array_upper(matrix, 2) LOOP
                IF _matrix[x][y] IS NULL THEN
                    IF nodatamode = 'ignore' THEN
                        _matrix[x][y] := 0;
                    ELSE
                        _matrix[x][y] := nodatamode::float;
                    END IF;
                END IF;
                sum := sum + _matrix[x][y];
            END LOOP;
        END LOOP;
        RETURN sum;
    END;
    $$
    LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mean4ma(matrix float[][], nodatamode text, variadic args text[])
    RETURNS float AS
    $$
    DECLARE
        _matrix float[][];
        sum float;
        count float;
    BEGIN
        _matrix := matrix;
        sum := 0;
        count := 0;
        FOR x in array_lower(matrix, 1)..array_upper(matrix, 1) LOOP
            FOR y in array_lower(matrix, 2)..array_upper(matrix, 2) LOOP
                IF _matrix[x][y] IS NULL THEN
                    IF nodatamode = 'ignore' THEN
                        _matrix[x][y] := 0;
                    ELSE
                        _matrix[x][y] := nodatamode::float;
                        count := count + 1;
                    END IF;
                ELSE
                    count := count + 1;
                END IF;
                sum := sum + _matrix[x][y];
            END LOOP;
        END LOOP;
        IF count = 0 THEN
            RETURN NULL;
        END IF;
        RETURN sum / count;
    END;
    $$
    LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_range4ma(matrix float[][], nodatamode text, variadic args text[])
    RETURNS float AS
    $$
    DECLARE
        _matrix float[][];
        min float;
        max float;
    BEGIN
        _matrix := matrix;
        min := 'Infinity'::float;
        max := '-Infinity'::float;
        FOR x in array_lower(matrix, 1)..array_upper(matrix, 1) LOOP
            FOR y in array_lower(matrix, 2)..array_upper(matrix, 2) LOOP
                IF _matrix[x][y] IS NULL THEN
                    IF NOT nodatamode = 'ignore' THEN
                        _matrix[x][y] := nodatamode::float;
                    END IF;
                END IF;
                IF min > _matrix[x][y] THEN
                    min = _matrix[x][y];
                END IF;
                IF max < _matrix[x][y] THEN
                    max = _matrix[x][y];
                END IF;
            END LOOP;
        END LOOP;
        IF max = '-Infinity'::float OR min = 'Infinity'::float THEN
            RETURN NULL;
        END IF;
        RETURN max - min;
    END;
    $$
    LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_distinct4ma(matrix float[][], nodatamode TEXT, VARIADIC args TEXT[])
    RETURNS float AS
    $$ SELECT COUNT(DISTINCT unnest)::float FROM unnest($1) $$
    LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_stddev4ma(matrix float[][], nodatamode TEXT, VARIADIC args TEXT[])
    RETURNS float AS
    $$ SELECT stddev(unnest) FROM unnest($1) $$
    LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_mapalgebra(
	rastbandargset rastbandarg[],
	callbackfunc regprocedure,
	pixeltype text DEFAULT NULL,
	distancex integer DEFAULT 0, distancey integer DEFAULT 0,
	extenttype text DEFAULT 'INTERSECTION', customextent raster DEFAULT NULL,
	mask double precision[][] DEFAULT NULL, weighted boolean DEFAULT NULL,
	VARIADIC userargs text[] DEFAULT NULL
)
	RETURNS raster
	AS '$libdir/rtpostgis-2.5', 'RASTER_nMapAlgebra'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebra(
	rastbandargset rastbandarg[],
	callbackfunc regprocedure,
	pixeltype text DEFAULT NULL,
	extenttype text DEFAULT 'INTERSECTION', customextent raster DEFAULT NULL,
	distancex integer DEFAULT 0, distancey integer DEFAULT 0,
	VARIADIC userargs text[] DEFAULT NULL
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_MapAlgebra($1, $2, $3, $6, $7, $4, $5,NULL::double precision [],NULL::boolean, VARIADIC $8) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebra(
	rast raster, nband int[],
	callbackfunc regprocedure,
	pixeltype text DEFAULT NULL,
	extenttype text DEFAULT 'FIRST', customextent raster DEFAULT NULL,
	distancex integer DEFAULT 0, distancey integer DEFAULT 0,
	VARIADIC userargs text[] DEFAULT NULL
)
	RETURNS raster
	AS $$
	DECLARE
		x int;
		argset rastbandarg[];
	BEGIN
		IF $2 IS NULL OR array_ndims($2) < 1 OR array_length($2, 1) < 1 THEN
			RAISE EXCEPTION 'Populated 1D array must be provided for nband';
			RETURN NULL;
		END IF;

		FOR x IN array_lower($2, 1)..array_upper($2, 1) LOOP
			IF $2[x] IS NULL THEN
				CONTINUE;
			END IF;

			argset := argset || ROW($1, $2[x])::rastbandarg;
		END LOOP;

		IF array_length(argset, 1) < 1 THEN
			RAISE EXCEPTION 'Populated 1D array must be provided for nband';
			RETURN NULL;
		END IF;

		RETURN @extschema@._ST_MapAlgebra(argset, $3, $4, $7, $8, $5, $6,NULL::double precision [],NULL::boolean, VARIADIC $9);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebra(
	rast raster, nband int,
	callbackfunc regprocedure,
	pixeltype text DEFAULT NULL,
	extenttype text DEFAULT 'FIRST', customextent raster DEFAULT NULL,
	distancex integer DEFAULT 0, distancey integer DEFAULT 0,
	VARIADIC userargs text[] DEFAULT NULL
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_MapAlgebra(ARRAY[ROW($1, $2)]::rastbandarg[], $3, $4, $7, $8, $5, $6,NULL::double precision [],NULL::boolean, VARIADIC $9) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebra(
	rast1 raster, nband1 int,
	rast2 raster, nband2 int,
	callbackfunc regprocedure,
	pixeltype text DEFAULT NULL,
	extenttype text DEFAULT 'INTERSECTION', customextent raster DEFAULT NULL,
	distancex integer DEFAULT 0, distancey integer DEFAULT 0,
	VARIADIC userargs text[] DEFAULT NULL
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_MapAlgebra(ARRAY[ROW($1, $2), ROW($3, $4)]::rastbandarg[], $5, $6, $9, $10, $7, $8,NULL::double precision [],NULL::boolean, VARIADIC $11) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebra(
	rast raster, nband int,
	callbackfunc regprocedure,
	mask double precision [][], weighted boolean,
	pixeltype text DEFAULT NULL,
	extenttype text DEFAULT 'INTERSECTION', customextent raster DEFAULT NULL,
	VARIADIC userargs text[] DEFAULT NULL
)
	RETURNS raster
	AS $$
	select @extschema@._ST_mapalgebra(ARRAY[ROW($1,$2)]::rastbandarg[],$3,$6,NULL::integer,NULL::integer,$7,$8,$4,$5,VARIADIC $9)
	$$ LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_mapalgebra(
	rastbandargset rastbandarg[],
	expression text,
	pixeltype text DEFAULT NULL, extenttype text DEFAULT 'INTERSECTION',
	nodata1expr text DEFAULT NULL, nodata2expr text DEFAULT NULL,
	nodatanodataval double precision DEFAULT NULL
)
	RETURNS raster
	AS '$libdir/rtpostgis-2.5', 'RASTER_nMapAlgebraExpr'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebra(
	rast raster, nband integer,
	pixeltype text,
	expression text, nodataval double precision DEFAULT NULL
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_mapalgebra(ARRAY[ROW($1, $2)]::rastbandarg[], $4, $3, 'FIRST', $5::text) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebra(
	rast raster,
	pixeltype text,
	expression text, nodataval double precision DEFAULT NULL
)
	RETURNS raster
	AS $$ SELECT @extschema@.ST_mapalgebra($1, 1, $2, $3, $4) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebra(
	rast1 raster, band1 integer,
	rast2 raster, band2 integer,
	expression text,
	pixeltype text DEFAULT NULL, extenttype text DEFAULT 'INTERSECTION',
	nodata1expr text DEFAULT NULL, nodata2expr text DEFAULT NULL,
	nodatanodataval double precision DEFAULT NULL
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_mapalgebra(ARRAY[ROW($1, $2), ROW($3, $4)]::rastbandarg[], $5, $6, $7, $8, $9, $10) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mapalgebra(
	rast1 raster,
	rast2 raster,
	expression text,
	pixeltype text DEFAULT NULL, extenttype text DEFAULT 'INTERSECTION',
	nodata1expr text DEFAULT NULL, nodata2expr text DEFAULT NULL,
	nodatanodataval double precision DEFAULT NULL
)
	RETURNS raster
	AS $$ SELECT @extschema@.ST_mapalgebra($1, 1, $2, 1, $3, $4, $5, $6, $7, $8) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_convertarray4ma(value double precision[][])
	RETURNS double precision[][][]
	AS $$
	DECLARE
		_value double precision[][][];
		x int;
		y int;
	BEGIN
		IF array_ndims(value) != 2 THEN
			RAISE EXCEPTION 'Function parameter must be a 2-dimension array';
		END IF;

		_value := array_fill(NULL::double precision, ARRAY[1, array_length(value, 1), array_length(value, 2)]::int[], ARRAY[1, array_lower(value, 1), array_lower(value, 2)]::int[]);

		-- row
		FOR y IN array_lower(value, 1)..array_upper(value, 1) LOOP
			-- column
			FOR x IN array_lower(value, 2)..array_upper(value, 2) LOOP
				_value[1][y][x] = value[y][x];
			END LOOP;
		END LOOP;

		RETURN _value;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_max4ma(value double precision[][][], pos integer[][], VARIADIC userargs text[] DEFAULT NULL)
	RETURNS double precision
	AS $$
	DECLARE
		_value double precision[][][];
		max double precision;
		x int;
		y int;
		z int;
		ndims int;
	BEGIN
		max := '-Infinity'::double precision;

		ndims := array_ndims(value);
		-- add a third dimension if 2-dimension
		IF ndims = 2 THEN
			_value := @extschema@._ST_convertarray4ma(value);
		ELSEIF ndims != 3 THEN
			RAISE EXCEPTION 'First parameter of function must be a 3-dimension array';
		ELSE
			_value := value;
		END IF;

		-- raster
		FOR z IN array_lower(_value, 1)..array_upper(_value, 1) LOOP
			-- row
			FOR y IN array_lower(_value, 2)..array_upper(_value, 2) LOOP
				-- column
				FOR x IN array_lower(_value, 3)..array_upper(_value, 3) LOOP
					IF _value[z][y][x] IS NULL THEN
						IF array_length(userargs, 1) > 0 THEN
							_value[z][y][x] = userargs[array_lower(userargs, 1)]::double precision;
						ELSE
							CONTINUE;
						END IF;
					END IF;

					IF _value[z][y][x] > max THEN
						max := _value[z][y][x];
					END IF;
				END LOOP;
			END LOOP;
		END LOOP;

		IF max = '-Infinity'::double precision THEN
			RETURN NULL;
		END IF;

		RETURN max;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_min4ma(value double precision[][][], pos integer[][], VARIADIC userargs text[] DEFAULT NULL)
	RETURNS double precision
	AS $$
	DECLARE
		_value double precision[][][];
		min double precision;
		x int;
		y int;
		z int;
		ndims int;
	BEGIN
		min := 'Infinity'::double precision;

		ndims := array_ndims(value);
		-- add a third dimension if 2-dimension
		IF ndims = 2 THEN
			_value := @extschema@._ST_convertarray4ma(value);
		ELSEIF ndims != 3 THEN
			RAISE EXCEPTION 'First parameter of function must be a 3-dimension array';
		ELSE
			_value := value;
		END IF;

		-- raster
		FOR z IN array_lower(_value, 1)..array_upper(_value, 1) LOOP
			-- row
			FOR y IN array_lower(_value, 2)..array_upper(_value, 2) LOOP
				-- column
				FOR x IN array_lower(_value, 3)..array_upper(_value, 3) LOOP
					IF _value[z][y][x] IS NULL THEN
						IF array_length(userargs, 1) > 0 THEN
							_value[z][y][x] = userargs[array_lower(userargs, 1)]::double precision;
						ELSE
							CONTINUE;
						END IF;
					END IF;

					IF _value[z][y][x] < min THEN
						min := _value[z][y][x];
					END IF;
				END LOOP;
			END LOOP;
		END LOOP;

		IF min = 'Infinity'::double precision THEN
			RETURN NULL;
		END IF;

		RETURN min;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_sum4ma(value double precision[][][], pos integer[][], VARIADIC userargs text[] DEFAULT NULL)
	RETURNS double precision
	AS $$
	DECLARE
		_value double precision[][][];
		sum double precision;
		x int;
		y int;
		z int;
		ndims int;
	BEGIN
		sum := 0;

		ndims := array_ndims(value);
		-- add a third dimension if 2-dimension
		IF ndims = 2 THEN
			_value := @extschema@._ST_convertarray4ma(value);
		ELSEIF ndims != 3 THEN
			RAISE EXCEPTION 'First parameter of function must be a 3-dimension array';
		ELSE
			_value := value;
		END IF;

		-- raster
		FOR z IN array_lower(_value, 1)..array_upper(_value, 1) LOOP
			-- row
			FOR y IN array_lower(_value, 2)..array_upper(_value, 2) LOOP
				-- column
				FOR x IN array_lower(_value, 3)..array_upper(_value, 3) LOOP
					IF _value[z][y][x] IS NULL THEN
						IF array_length(userargs, 1) > 0 THEN
							_value[z][y][x] = userargs[array_lower(userargs, 1)]::double precision;
						ELSE
							CONTINUE;
						END IF;
					END IF;

					sum := sum + _value[z][y][x];
				END LOOP;
			END LOOP;
		END LOOP;

		RETURN sum;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mean4ma(value double precision[][][], pos integer[][], VARIADIC userargs text[] DEFAULT NULL)
	RETURNS double precision
	AS $$
	DECLARE
		_value double precision[][][];
		sum double precision;
		count int;
		x int;
		y int;
		z int;
		ndims int;
	BEGIN
		sum := 0;
		count := 0;

		ndims := array_ndims(value);
		-- add a third dimension if 2-dimension
		IF ndims = 2 THEN
			_value := @extschema@._ST_convertarray4ma(value);
		ELSEIF ndims != 3 THEN
			RAISE EXCEPTION 'First parameter of function must be a 3-dimension array';
		ELSE
			_value := value;
		END IF;

		-- raster
		FOR z IN array_lower(_value, 1)..array_upper(_value, 1) LOOP
			-- row
			FOR y IN array_lower(_value, 2)..array_upper(_value, 2) LOOP
				-- column
				FOR x IN array_lower(_value, 3)..array_upper(_value, 3) LOOP
					IF _value[z][y][x] IS NULL THEN
						IF array_length(userargs, 1) > 0 THEN
							_value[z][y][x] = userargs[array_lower(userargs, 1)]::double precision;
						ELSE
							CONTINUE;
						END IF;
					END IF;

					sum := sum + _value[z][y][x];
					count := count + 1;
				END LOOP;
			END LOOP;
		END LOOP;

		IF count < 1 THEN
			RETURN NULL;
		END IF;

		RETURN sum / count::double precision;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_range4ma(value double precision[][][], pos integer[][], VARIADIC userargs text[] DEFAULT NULL)
	RETURNS double precision
	AS $$
	DECLARE
		_value double precision[][][];
		min double precision;
		max double precision;
		x int;
		y int;
		z int;
		ndims int;
	BEGIN
		min := 'Infinity'::double precision;
		max := '-Infinity'::double precision;

		ndims := array_ndims(value);
		-- add a third dimension if 2-dimension
		IF ndims = 2 THEN
			_value := @extschema@._ST_convertarray4ma(value);
		ELSEIF ndims != 3 THEN
			RAISE EXCEPTION 'First parameter of function must be a 3-dimension array';
		ELSE
			_value := value;
		END IF;

		-- raster
		FOR z IN array_lower(_value, 1)..array_upper(_value, 1) LOOP
			-- row
			FOR y IN array_lower(_value, 2)..array_upper(_value, 2) LOOP
				-- column
				FOR x IN array_lower(_value, 3)..array_upper(_value, 3) LOOP
					IF _value[z][y][x] IS NULL THEN
						IF array_length(userargs, 1) > 0 THEN
							_value[z][y][x] = userargs[array_lower(userargs, 1)]::double precision;
						ELSE
							CONTINUE;
						END IF;
					END IF;

					IF _value[z][y][x] < min THEN
						min := _value[z][y][x];
					END IF;
					IF _value[z][y][x] > max THEN
						max := _value[z][y][x];
					END IF;
				END LOOP;
			END LOOP;
		END LOOP;

		IF max = '-Infinity'::double precision OR min = 'Infinity'::double precision THEN
			RETURN NULL;
		END IF;

		RETURN max - min;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_distinct4ma(value double precision[][][], pos integer[][], VARIADIC userargs text[] DEFAULT NULL)
	RETURNS double precision
	AS $$ SELECT COUNT(DISTINCT unnest)::double precision FROM unnest($1) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_stddev4ma(value double precision[][][], pos integer[][], VARIADIC userargs text[] DEFAULT NULL)
	RETURNS double precision
	AS $$ SELECT stddev(unnest) FROM unnest($1) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_invdistweight4ma(value double precision[][][], pos integer[][], VARIADIC userargs text[] DEFAULT NULL)
	RETURNS double precision
	AS $$
	DECLARE
		_value double precision[][][];
		ndims int;

		k double precision DEFAULT 1.;
		_k double precision DEFAULT 1.;
		z double precision[];
		d double precision[];
		_d double precision;
		z0 double precision;

		_z integer;
		x integer;
		y integer;

		cx integer;
		cy integer;
		cv double precision;
		cw double precision DEFAULT NULL;

		w integer;
		h integer;
		max_dx double precision;
		max_dy double precision;
	BEGIN
--		RAISE NOTICE 'value = %', value;
--		RAISE NOTICE 'userargs = %', userargs;

		ndims := array_ndims(value);
		-- add a third dimension if 2-dimension
		IF ndims = 2 THEN
			_value := @extschema@._ST_convertarray4ma(value);
		ELSEIF ndims != 3 THEN
			RAISE EXCEPTION 'First parameter of function must be a 3-dimension array';
		ELSE
			_value := value;
		END IF;

		-- only use the first raster passed to this function
		IF array_length(_value, 1) > 1 THEN
			RAISE NOTICE 'Only using the values from the first raster';
		END IF;
		_z := array_lower(_value, 1);

		-- width and height (0-based)
		h := array_upper(_value, 2) - array_lower(_value, 2);
		w := array_upper(_value, 3) - array_lower(_value, 3);

		-- max distance from center pixel
		max_dx := w / 2;
		max_dy := h / 2;
--		RAISE NOTICE 'max_dx, max_dy = %, %', max_dx, max_dy;

		-- correct width and height (1-based)
		w := w + 1;
		h := h + 1;
--		RAISE NOTICE 'w, h = %, %', w, h;

		-- width and height should be odd numbers
		IF w % 2. != 1 THEN
			RAISE EXCEPTION 'Width of neighborhood array does not permit for a center pixel';
		END IF;
		IF h % 2. != 1 THEN
			RAISE EXCEPTION 'Height of neighborhood array does not permit for a center pixel';
		END IF;

		-- center pixel's coordinates
		cy := max_dy + array_lower(_value, 2);
		cx := max_dx + array_lower(_value, 3);
--		RAISE NOTICE 'cx, cy = %, %', cx, cy;

		-- if userargs provided, only use the first two args
		IF userargs IS NOT NULL AND array_ndims(userargs) = 1 THEN
			-- first arg is power factor
			k := userargs[array_lower(userargs, 1)]::double precision;
			IF k IS NULL THEN
				k := _k;
			ELSEIF k < 0. THEN
				RAISE NOTICE 'Power factor (< 0) must be between 0 and 1.  Defaulting to 0';
				k := 0.;
			ELSEIF k > 1. THEN
				RAISE NOTICE 'Power factor (> 1) must be between 0 and 1.  Defaulting to 1';
				k := 1.;
			END IF;

			-- second arg is what to do if center pixel has a value
			-- this will be a weight to apply for the center pixel
			IF array_length(userargs, 1) > 1 THEN
				cw := abs(userargs[array_lower(userargs, 1) + 1]::double precision);
				IF cw IS NOT NULL THEN
					IF cw < 0. THEN
						RAISE NOTICE 'Weight (< 0) of center pixel value must be between 0 and 1.  Defaulting to 0';
						cw := 0.;
					ELSEIF cw > 1 THEN
						RAISE NOTICE 'Weight (> 1) of center pixel value must be between 0 and 1.  Defaulting to 1';
						cw := 1.;
					END IF;
				END IF;
			END IF;
		END IF;
--		RAISE NOTICE 'k = %', k;
		k = abs(k) * -1;

		-- center pixel value
		cv := _value[_z][cy][cx];

		-- check to see if center pixel has value
--		RAISE NOTICE 'cw = %', cw;
		IF cw IS NULL AND cv IS NOT NULL THEN
			RETURN cv;
		END IF;

		FOR y IN array_lower(_value, 2)..array_upper(_value, 2) LOOP
			FOR x IN array_lower(_value, 3)..array_upper(_value, 3) LOOP
--				RAISE NOTICE 'value[%][%][%] = %', _z, y, x, _value[_z][y][x];

				-- skip NODATA values and center pixel
				IF _value[_z][y][x] IS NULL OR (x = cx AND y = cy) THEN
					CONTINUE;
				END IF;

				z := z || _value[_z][y][x];

				-- use pythagorean theorem
				_d := sqrt(power(cx - x, 2) + power(cy - y, 2));
--				RAISE NOTICE 'distance = %', _d;

				d := d || _d;
			END LOOP;
		END LOOP;
--		RAISE NOTICE 'z = %', z;
--		RAISE NOTICE 'd = %', d;

		-- neighborhood is NODATA
		IF z IS NULL OR array_length(z, 1) < 1 THEN
			-- center pixel has value
			IF cv IS NOT NULL THEN
				RETURN cv;
			ELSE
				RETURN NULL;
			END IF;
		END IF;

		z0 := 0;
		_d := 0;
		FOR x IN array_lower(z, 1)..array_upper(z, 1) LOOP
			d[x] := power(d[x], k);
			z[x] := z[x] * d[x];
			_d := _d + d[x];
			z0 := z0 + z[x];
		END LOOP;
		z0 := z0 / _d;
--		RAISE NOTICE 'z0 = %', z0;

		-- apply weight for center pixel if center pixel has value
		IF cv IS NOT NULL THEN
			z0 := (cw * cv) + ((1 - cw) * z0);
--			RAISE NOTICE '*z0 = %', z0;
		END IF;

		RETURN z0;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_mindist4ma(value double precision[][][], pos integer[][], VARIADIC userargs text[] DEFAULT NULL)
	RETURNS double precision
	AS $$
	DECLARE
		_value double precision[][][];
		ndims int;

		d double precision DEFAULT NULL;
		_d double precision;

		z integer;
		x integer;
		y integer;

		cx integer;
		cy integer;
		cv double precision;

		w integer;
		h integer;
		max_dx double precision;
		max_dy double precision;
	BEGIN

		ndims := array_ndims(value);
		-- add a third dimension if 2-dimension
		IF ndims = 2 THEN
			_value := @extschema@._ST_convertarray4ma(value);
		ELSEIF ndims != 3 THEN
			RAISE EXCEPTION 'First parameter of function must be a 3-dimension array';
		ELSE
			_value := value;
		END IF;

		-- only use the first raster passed to this function
		IF array_length(_value, 1) > 1 THEN
			RAISE NOTICE 'Only using the values from the first raster';
		END IF;
		z := array_lower(_value, 1);

		-- width and height (0-based)
		h := array_upper(_value, 2) - array_lower(_value, 2);
		w := array_upper(_value, 3) - array_lower(_value, 3);

		-- max distance from center pixel
		max_dx := w / 2;
		max_dy := h / 2;

		-- correct width and height (1-based)
		w := w + 1;
		h := h + 1;

		-- width and height should be odd numbers
		IF w % 2. != 1 THEN
			RAISE EXCEPTION 'Width of neighborhood array does not permit for a center pixel';
		END IF;
		IF h % 2. != 1 THEN
			RAISE EXCEPTION 'Height of neighborhood array does not permit for a center pixel';
		END IF;

		-- center pixel's coordinates
		cy := max_dy + array_lower(_value, 2);
		cx := max_dx + array_lower(_value, 3);

		-- center pixel value
		cv := _value[z][cy][cx];

		-- check to see if center pixel has value
		IF cv IS NOT NULL THEN
			RETURN 0.;
		END IF;

		FOR y IN array_lower(_value, 2)..array_upper(_value, 2) LOOP
			FOR x IN array_lower(_value, 3)..array_upper(_value, 3) LOOP

				-- skip NODATA values and center pixel
				IF _value[z][y][x] IS NULL OR (x = cx AND y = cy) THEN
					CONTINUE;
				END IF;

				-- use pythagorean theorem
				_d := sqrt(power(cx - x, 2) + power(cy - y, 2));
--				RAISE NOTICE 'distance = %', _d;

				IF d IS NULL OR _d < d THEN
					d := _d;
				END IF;
			END LOOP;
		END LOOP;
--		RAISE NOTICE 'd = %', d;

		RETURN d;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_slope4ma(value double precision[][][], pos integer[][], VARIADIC userargs text[] DEFAULT NULL)
	RETURNS double precision
	AS $$
	DECLARE
		x integer;
		y integer;
		z integer;

		_pixwidth double precision;
		_pixheight double precision;
		_width double precision;
		_height double precision;
		_units text;
		_scale double precision;

		dz_dx double precision;
		dz_dy double precision;

		slope double precision;

		_value double precision[][][];
		ndims int;
	BEGIN

		ndims := array_ndims(value);
		-- add a third dimension if 2-dimension
		IF ndims = 2 THEN
			_value := @extschema@._ST_convertarray4ma(value);
		ELSEIF ndims != 3 THEN
			RAISE EXCEPTION 'First parameter of function must be a 3-dimension array';
		ELSE
			_value := value;
		END IF;

		-- only use the first raster passed to this function
		IF array_length(_value, 1) > 1 THEN
			RAISE NOTICE 'Only using the values from the first raster';
		END IF;
		z := array_lower(_value, 1);

		IF (
			array_lower(_value, 2) != 1 OR array_upper(_value, 2) != 3 OR
			array_lower(_value, 3) != 1 OR array_upper(_value, 3) != 3
		) THEN
			RAISE EXCEPTION 'First parameter of function must be a 1x3x3 array with each of the lower bounds starting from 1';
		END IF;

		IF array_length(userargs, 1) < 6 THEN
			RAISE EXCEPTION 'At least six elements must be provided for the third parameter';
		END IF;

		_pixwidth := userargs[1]::double precision;
		_pixheight := userargs[2]::double precision;
		_width := userargs[3]::double precision;
		_height := userargs[4]::double precision;
		_units := userargs[5];
		_scale := userargs[6]::double precision;

		





		-- check that center pixel isn't NODATA
		IF _value[z][2][2] IS NULL THEN
			RETURN NULL;
		-- substitute center pixel for any neighbor pixels that are NODATA
		ELSE
			FOR y IN 1..3 LOOP
				FOR x IN 1..3 LOOP
					IF _value[z][y][x] IS NULL THEN
						_value[z][y][x] = _value[z][2][2];
					END IF;
				END LOOP;
			END LOOP;
		END IF;

		dz_dy := ((_value[z][3][1] + _value[z][3][2] + _value[z][3][2] + _value[z][3][3]) -
			(_value[z][1][1] + _value[z][1][2] + _value[z][1][2] + _value[z][1][3])) / _pixheight;
		dz_dx := ((_value[z][1][3] + _value[z][2][3] + _value[z][2][3] + _value[z][3][3]) -
			(_value[z][1][1] + _value[z][2][1] + _value[z][2][1] + _value[z][3][1])) / _pixwidth;

		slope := sqrt(dz_dx * dz_dx + dz_dy * dz_dy) / (8 * _scale);

		-- output depends on user preference
		CASE substring(upper(trim(leading from _units)) for 3)
			-- percentages
			WHEN 'PER' THEN
				slope := 100.0 * slope;
			-- radians
			WHEN 'rad' THEN
				slope := atan(slope);
			-- degrees (default)
			ELSE
				slope := degrees(atan(slope));
		END CASE;

		RETURN slope;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_slope(
	rast raster, nband integer,
	customextent raster,
	pixeltype text DEFAULT '32BF', units text DEFAULT 'DEGREES',
	scale double precision DEFAULT 1.0,	interpolate_nodata boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$
	DECLARE
		_rast @extschema@.raster;
		_nband integer;
		_pixtype text;
		_pixwidth double precision;
		_pixheight double precision;
		_width integer;
		_height integer;
		_customextent @extschema@.raster;
		_extenttype text;
	BEGIN
		_customextent := customextent;
		IF _customextent IS NULL THEN
			_extenttype := 'FIRST';
		ELSE
			_extenttype := 'CUSTOM';
		END IF;

		IF interpolate_nodata IS TRUE THEN
			_rast := @extschema@.ST_MapAlgebra(
				ARRAY[ROW(rast, nband)]::rastbandarg[],
				'@extschema@.st_invdistweight4ma(double precision[][][], integer[][], text[])'::regprocedure,
				pixeltype,
				'FIRST', NULL,
				1, 1
			);
			_nband := 1;
			_pixtype := NULL;
		ELSE
			_rast := rast;
			_nband := nband;
			_pixtype := pixeltype;
		END IF;

		-- get properties
		_pixwidth := @extschema@.ST_PixelWidth(_rast);
		_pixheight := @extschema@.ST_PixelHeight(_rast);
		SELECT width, height INTO _width, _height FROM @extschema@.ST_Metadata(_rast);

		RETURN @extschema@.ST_MapAlgebra(
			ARRAY[ROW(_rast, _nband)]::rastbandarg[],
			' @extschema@._ST_slope4ma(double precision[][][], integer[][], text[])'::regprocedure,
			_pixtype,
			_extenttype, _customextent,
			1, 1,
			_pixwidth::text, _pixheight::text,
			_width::text, _height::text,
			units::text, scale::text
		);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_slope(
	rast raster, nband integer DEFAULT 1,
	pixeltype text DEFAULT '32BF', units text DEFAULT 'DEGREES',
	scale double precision DEFAULT 1.0,	interpolate_nodata boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$ SELECT @extschema@.ST_slope($1, $2, NULL::@extschema@.raster, $3, $4, $5, $6) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_aspect4ma(value double precision[][][], pos integer[][], VARIADIC userargs text[] DEFAULT NULL)
	RETURNS double precision
	AS $$
	DECLARE
		x integer;
		y integer;
		z integer;

		_width double precision;
		_height double precision;
		_units text;

		dz_dx double precision;
		dz_dy double precision;
		aspect double precision;
		halfpi double precision;

		_value double precision[][][];
		ndims int;
	BEGIN
		ndims := array_ndims(value);
		-- add a third dimension if 2-dimension
		IF ndims = 2 THEN
			_value := @extschema@._ST_convertarray4ma(value);
		ELSEIF ndims != 3 THEN
			RAISE EXCEPTION 'First parameter of function must be a 3-dimension array';
		ELSE
			_value := value;
		END IF;

		IF (
			array_lower(_value, 2) != 1 OR array_upper(_value, 2) != 3 OR
			array_lower(_value, 3) != 1 OR array_upper(_value, 3) != 3
		) THEN
			RAISE EXCEPTION 'First parameter of function must be a 1x3x3 array with each of the lower bounds starting from 1';
		END IF;

		IF array_length(userargs, 1) < 3 THEN
			RAISE EXCEPTION 'At least three elements must be provided for the third parameter';
		END IF;

		-- only use the first raster passed to this function
		IF array_length(_value, 1) > 1 THEN
			RAISE NOTICE 'Only using the values from the first raster';
		END IF;
		z := array_lower(_value, 1);

		_width := userargs[1]::double precision;
		_height := userargs[2]::double precision;
		_units := userargs[3];

		





		-- check that center pixel isn't NODATA
		IF _value[z][2][2] IS NULL THEN
			RETURN NULL;
		-- substitute center pixel for any neighbor pixels that are NODATA
		ELSE
			FOR y IN 1..3 LOOP
				FOR x IN 1..3 LOOP
					IF _value[z][y][x] IS NULL THEN
						_value[z][y][x] = _value[z][2][2];
					END IF;
				END LOOP;
			END LOOP;
		END IF;

		dz_dy := ((_value[z][3][1] + _value[z][3][2] + _value[z][3][2] + _value[z][3][3]) -
			(_value[z][1][1] + _value[z][1][2] + _value[z][1][2] + _value[z][1][3]));
		dz_dx := ((_value[z][1][3] + _value[z][2][3] + _value[z][2][3] + _value[z][3][3]) -
			(_value[z][1][1] + _value[z][2][1] + _value[z][2][1] + _value[z][3][1]));

		-- aspect is flat
		IF abs(dz_dx) = 0::double precision AND abs(dz_dy) = 0::double precision THEN
			RETURN -1;
		END IF;

		-- aspect is in radians
		aspect := atan2(dz_dy, -dz_dx);

		-- north = 0, pi/2 = east, 3pi/2 = west
		halfpi := pi() / 2.0;
		IF aspect > halfpi THEN
			aspect := (5.0 * halfpi) - aspect;
		ELSE
			aspect := halfpi - aspect;
		END IF;

		IF aspect = 2 * pi() THEN
			aspect := 0.;
		END IF;

		-- output depends on user preference
		CASE substring(upper(trim(leading from _units)) for 3)
			-- radians
			WHEN 'rad' THEN
				RETURN aspect;
			-- degrees (default)
			ELSE
				RETURN degrees(aspect);
		END CASE;

	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_aspect(
	rast raster, nband integer,
	customextent raster,
	pixeltype text DEFAULT '32BF', units text DEFAULT 'DEGREES',
	interpolate_nodata boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$
	DECLARE
		_rast @extschema@.raster;
		_nband integer;
		_pixtype text;
		_width integer;
		_height integer;
		_customextent @extschema@.raster;
		_extenttype text;
	BEGIN
		_customextent := customextent;
		IF _customextent IS NULL THEN
			_extenttype := 'FIRST';
		ELSE
			_extenttype := 'CUSTOM';
		END IF;

		IF interpolate_nodata IS TRUE THEN
			_rast := @extschema@.ST_MapAlgebra(
				ARRAY[ROW(rast, nband)]::rastbandarg[],
				'@extschema@.st_invdistweight4ma(double precision[][][], integer[][], text[])'::regprocedure,
				pixeltype,
				'FIRST', NULL,
				1, 1
			);
			_nband := 1;
			_pixtype := NULL;
		ELSE
			_rast := rast;
			_nband := nband;
			_pixtype := pixeltype;
		END IF;

		-- get properties
		SELECT width, height INTO _width, _height FROM @extschema@.ST_Metadata(_rast);

		RETURN @extschema@.ST_MapAlgebra(
			ARRAY[ROW(_rast, _nband)]::rastbandarg[],
			' @extschema@._ST_aspect4ma(double precision[][][], integer[][], text[])'::regprocedure,
			_pixtype,
			_extenttype, _customextent,
			1, 1,
			_width::text, _height::text,
			units::text
		);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_aspect(
	rast raster, nband integer DEFAULT 1,
	pixeltype text DEFAULT '32BF', units text DEFAULT 'DEGREES',
	interpolate_nodata boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$ SELECT @extschema@.ST_aspect($1, $2, NULL::@extschema@.raster, $3, $4, $5) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_hillshade4ma(value double precision[][][], pos integer[][], VARIADIC userargs text[] DEFAULT NULL)
	RETURNS double precision
	AS $$
	DECLARE
		_pixwidth double precision;
		_pixheight double precision;
		_width double precision;
		_height double precision;
		_azimuth double precision;
		_altitude double precision;
		_bright double precision;
		_scale double precision;

		dz_dx double precision;
		dz_dy double precision;
		azimuth double precision;
		zenith double precision;
		slope double precision;
		aspect double precision;
		shade double precision;

		_value double precision[][][];
		ndims int;
		z int;
	BEGIN
		ndims := array_ndims(value);
		-- add a third dimension if 2-dimension
		IF ndims = 2 THEN
			_value := @extschema@._ST_convertarray4ma(value);
		ELSEIF ndims != 3 THEN
			RAISE EXCEPTION 'First parameter of function must be a 3-dimension array';
		ELSE
			_value := value;
		END IF;

		IF (
			array_lower(_value, 2) != 1 OR array_upper(_value, 2) != 3 OR
			array_lower(_value, 3) != 1 OR array_upper(_value, 3) != 3
		) THEN
			RAISE EXCEPTION 'First parameter of function must be a 1x3x3 array with each of the lower bounds starting from 1';
		END IF;

		IF array_length(userargs, 1) < 8 THEN
			RAISE EXCEPTION 'At least eight elements must be provided for the third parameter';
		END IF;

		-- only use the first raster passed to this function
		IF array_length(_value, 1) > 1 THEN
			RAISE NOTICE 'Only using the values from the first raster';
		END IF;
		z := array_lower(_value, 1);

		_pixwidth := userargs[1]::double precision;
		_pixheight := userargs[2]::double precision;
		_width := userargs[3]::double precision;
		_height := userargs[4]::double precision;
		_azimuth := userargs[5]::double precision;
		_altitude := userargs[6]::double precision;
		_bright := userargs[7]::double precision;
		_scale := userargs[8]::double precision;

		-- check that pixel is not edge pixel
		IF (pos[1][1] = 1 OR pos[1][2] = 1) OR (pos[1][1] = _width OR pos[1][2] = _height) THEN
			RETURN NULL;
		END IF;

		-- clamp azimuth
		IF _azimuth < 0. THEN
			RAISE NOTICE 'Clamping provided azimuth value % to 0', _azimuth;
			_azimuth := 0.;
		ELSEIF _azimuth >= 360. THEN
			RAISE NOTICE 'Converting provided azimuth value % to be between 0 and 360', _azimuth;
			_azimuth := _azimuth - (360. * floor(_azimuth / 360.));
		END IF;
		azimuth := 360. - _azimuth + 90.;
		IF azimuth >= 360. THEN
			azimuth := azimuth - 360.;
		END IF;
		azimuth := radians(azimuth);
		--RAISE NOTICE 'azimuth = %', azimuth;

		-- clamp altitude
		IF _altitude < 0. THEN
			RAISE NOTICE 'Clamping provided altitude value % to 0', _altitude;
			_altitude := 0.;
		ELSEIF _altitude > 90. THEN
			RAISE NOTICE 'Clamping provided altitude value % to 90', _altitude;
			_altitude := 90.;
		END IF;
		zenith := radians(90. - _altitude);
		--RAISE NOTICE 'zenith = %', zenith;

		-- clamp bright
		IF _bright < 0. THEN
			RAISE NOTICE 'Clamping provided bright value % to 0', _bright;
			_bright := 0.;
		ELSEIF _bright > 255. THEN
			RAISE NOTICE 'Clamping provided bright value % to 255', _bright;
			_bright := 255.;
		END IF;

		dz_dy := ((_value[z][3][1] + _value[z][3][2] + _value[z][3][2] + _value[z][3][3]) -
			(_value[z][1][1] + _value[z][1][2] + _value[z][1][2] + _value[z][1][3])) / (8 * _pixheight);
		dz_dx := ((_value[z][1][3] + _value[z][2][3] + _value[z][2][3] + _value[z][3][3]) -
			(_value[z][1][1] + _value[z][2][1] + _value[z][2][1] + _value[z][3][1])) / (8 * _pixwidth);

		slope := atan(sqrt(dz_dx * dz_dx + dz_dy * dz_dy) / _scale);

		IF dz_dx != 0. THEN
			aspect := atan2(dz_dy, -dz_dx);

			IF aspect < 0. THEN
				aspect := aspect + (2.0 * pi());
			END IF;
		ELSE
			IF dz_dy > 0. THEN
				aspect := pi() / 2.;
			ELSEIF dz_dy < 0. THEN
				aspect := (2. * pi()) - (pi() / 2.);
			-- set to pi as that is the expected PostgreSQL answer in Linux
			ELSE
				aspect := pi();
			END IF;
		END IF;

		shade := _bright * ((cos(zenith) * cos(slope)) + (sin(zenith) * sin(slope) * cos(azimuth - aspect)));

		IF shade < 0. THEN
			shade := 0;
		END IF;

		RETURN shade;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_hillshade(
	rast raster, nband integer,
	customextent raster,
	pixeltype text DEFAULT '32BF',
	azimuth double precision DEFAULT 315.0, altitude double precision DEFAULT 45.0,
	max_bright double precision DEFAULT 255.0, scale double precision DEFAULT 1.0,
	interpolate_nodata boolean DEFAULT FALSE
)
	RETURNS RASTER
	AS $$
	DECLARE
		_rast @extschema@.raster;
		_nband integer;
		_pixtype text;
		_pixwidth double precision;
		_pixheight double precision;
		_width integer;
		_height integer;
		_customextent @extschema@.raster;
		_extenttype text;
	BEGIN
		_customextent := customextent;
		IF _customextent IS NULL THEN
			_extenttype := 'FIRST';
		ELSE
			_extenttype := 'CUSTOM';
		END IF;

		IF interpolate_nodata IS TRUE THEN
			_rast := @extschema@.ST_MapAlgebra(
				ARRAY[ROW(rast, nband)]::rastbandarg[],
				'@extschema@.st_invdistweight4ma(double precision[][][], integer[][], text[])'::regprocedure,
				pixeltype,
				'FIRST', NULL,
				1, 1
			);
			_nband := 1;
			_pixtype := NULL;
		ELSE
			_rast := rast;
			_nband := nband;
			_pixtype := pixeltype;
		END IF;

		-- get properties
		_pixwidth := @extschema@.ST_PixelWidth(_rast);
		_pixheight := @extschema@.ST_PixelHeight(_rast);
		SELECT width, height, scalex INTO _width, _height FROM @extschema@.ST_Metadata(_rast);

		RETURN @extschema@.ST_MapAlgebra(
			ARRAY[ROW(_rast, _nband)]::rastbandarg[],
			' @extschema@._ST_hillshade4ma(double precision[][][], integer[][], text[])'::regprocedure,
			_pixtype,
			_extenttype, _customextent,
			1, 1,
			_pixwidth::text, _pixheight::text,
			_width::text, _height::text,
			$5::text, $6::text,
			$7::text, $8::text
		);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_hillshade(
	rast raster, nband integer DEFAULT 1,
	pixeltype text DEFAULT '32BF',
	azimuth double precision DEFAULT 315.0, altitude double precision DEFAULT 45.0,
	max_bright double precision DEFAULT 255.0, scale double precision DEFAULT 1.0,
	interpolate_nodata boolean DEFAULT FALSE
)
	RETURNS RASTER
	AS $$ SELECT @extschema@.ST_hillshade($1, $2, NULL::@extschema@.raster, $3, $4, $5, $6, $7, $8) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_tpi4ma(value double precision[][][], pos integer[][], VARIADIC userargs text[] DEFAULT NULL)
	RETURNS double precision
	AS $$
	DECLARE
		x integer;
		y integer;
		z integer;

		Z1 double precision;
		Z2 double precision;
		Z3 double precision;
		Z4 double precision;
		Z5 double precision;
		Z6 double precision;
		Z7 double precision;
		Z8 double precision;
		Z9 double precision;

		tpi double precision;
		mean double precision;
		_value double precision[][][];
		ndims int;
	BEGIN
		ndims := array_ndims(value);
		-- add a third dimension if 2-dimension
		IF ndims = 2 THEN
			_value := @extschema@._ST_convertarray4ma(value);
		ELSEIF ndims != 3 THEN
			RAISE EXCEPTION 'First parameter of function must be a 3-dimension array';
		ELSE
			_value := value;
		END IF;

		-- only use the first raster passed to this function
		IF array_length(_value, 1) > 1 THEN
			RAISE NOTICE 'Only using the values from the first raster';
		END IF;
		z := array_lower(_value, 1);

		IF (
			array_lower(_value, 2) != 1 OR array_upper(_value, 2) != 3 OR
			array_lower(_value, 3) != 1 OR array_upper(_value, 3) != 3
		) THEN
			RAISE EXCEPTION 'First parameter of function must be a 1x3x3 array with each of the lower bounds starting from 1';
		END IF;

		-- check that center pixel isn't NODATA
		IF _value[z][2][2] IS NULL THEN
			RETURN NULL;
		-- substitute center pixel for any neighbor pixels that are NODATA
		ELSE
			FOR y IN 1..3 LOOP
				FOR x IN 1..3 LOOP
					IF _value[z][y][x] IS NULL THEN
						_value[z][y][x] = _value[z][2][2];
					END IF;
				END LOOP;
			END LOOP;
		END IF;

		-------------------------------------------------
		--|   Z1= Z(-1,1) |  Z2= Z(0,1)	| Z3= Z(1,1)  |--
		-------------------------------------------------
		--|   Z4= Z(-1,0) |  Z5= Z(0,0) | Z6= Z(1,0)  |--
		-------------------------------------------------
		--|   Z7= Z(-1,-1)|  Z8= Z(0,-1)|  Z9= Z(1,-1)|--
		-------------------------------------------------

		Z1 := _value[z][1][1];
		Z2 := _value[z][2][1];
		Z3 := _value[z][3][1];
		Z4 := _value[z][1][2];
		Z5 := _value[z][2][2];
		Z6 := _value[z][3][2];
		Z7 := _value[z][1][3];
		Z8 := _value[z][2][3];
		Z9 := _value[z][3][3];

		mean := (Z1 + Z2 + Z3 + Z4 + Z6 + Z7 + Z8 + Z9)/8;
		tpi := Z5-mean;

		return tpi;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_tpi(
	rast raster, nband integer,
	customextent raster,
	pixeltype text DEFAULT '32BF', interpolate_nodata boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$
	DECLARE
		_rast @extschema@.raster;
		_nband integer;
		_pixtype text;
		_pixwidth double precision;
		_pixheight double precision;
		_width integer;
		_height integer;
		_customextent @extschema@.raster;
		_extenttype text;
	BEGIN
		_customextent := customextent;
		IF _customextent IS NULL THEN
			_extenttype := 'FIRST';
		ELSE
			_extenttype := 'CUSTOM';
		END IF;

		IF interpolate_nodata IS TRUE THEN
			_rast := @extschema@.ST_MapAlgebra(
				ARRAY[ROW(rast, nband)]::rastbandarg[],
				'@extschema@.st_invdistweight4ma(double precision[][][], integer[][], text[])'::regprocedure,
				pixeltype,
				'FIRST', NULL,
				1, 1
			);
			_nband := 1;
			_pixtype := NULL;
		ELSE
			_rast := rast;
			_nband := nband;
			_pixtype := pixeltype;
		END IF;

		-- get properties
		_pixwidth := @extschema@.ST_PixelWidth(_rast);
		_pixheight := @extschema@.ST_PixelHeight(_rast);
		SELECT width, height INTO _width, _height FROM @extschema@.ST_Metadata(_rast);

		RETURN @extschema@.ST_MapAlgebra(
			ARRAY[ROW(_rast, _nband)]::rastbandarg[],
			' @extschema@._ST_tpi4ma(double precision[][][], integer[][], text[])'::regprocedure,
			_pixtype,
			_extenttype, _customextent,
			1, 1);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_tpi(
	rast raster, nband integer DEFAULT 1,
	pixeltype text DEFAULT '32BF', interpolate_nodata boolean DEFAULT FALSE
)
	RETURNS RASTER
	AS $$ SELECT @extschema@.ST_tpi($1, $2, NULL::@extschema@.raster, $3, $4) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_roughness4ma(value double precision[][][], pos integer[][], VARIADIC userargs text[] DEFAULT NULL)
	RETURNS double precision
	AS $$
	DECLARE
		x integer;
		y integer;
		z integer;

		minimum double precision;
		maximum double precision;

		_value double precision[][][];
		ndims int;
	BEGIN

		ndims := array_ndims(value);
		-- add a third dimension if 2-dimension
		IF ndims = 2 THEN
			_value := @extschema@._ST_convertarray4ma(value);
		ELSEIF ndims != 3 THEN
			RAISE EXCEPTION 'First parameter of function must be a 3-dimension array';
		ELSE
			_value := value;
		END IF;

		-- only use the first raster passed to this function
		IF array_length(_value, 1) > 1 THEN
			RAISE NOTICE 'Only using the values from the first raster';
		END IF;
		z := array_lower(_value, 1);

		IF (
			array_lower(_value, 2) != 1 OR array_upper(_value, 2) != 3 OR
			array_lower(_value, 3) != 1 OR array_upper(_value, 3) != 3
		) THEN
			RAISE EXCEPTION 'First parameter of function must be a 1x3x3 array with each of the lower bounds starting from 1';
		END IF;

		-- check that center pixel isn't NODATA
		IF _value[z][2][2] IS NULL THEN
			RETURN NULL;
		-- substitute center pixel for any neighbor pixels that are NODATA
		ELSE
			FOR y IN 1..3 LOOP
				FOR x IN 1..3 LOOP
					IF _value[z][y][x] IS NULL THEN
						_value[z][y][x] = _value[z][2][2];
					END IF;
				END LOOP;
			END LOOP;
		END IF;

		minimum := _value[z][1][1];
		maximum := _value[z][1][1];

		FOR Y IN 1..3 LOOP
		    FOR X IN 1..3 LOOP
		    	 IF _value[z][y][x] < minimum THEN
			    minimum := _value[z][y][x];
			 ELSIF _value[z][y][x] > maximum THEN
			    maximum := _value[z][y][x];
			 END IF;
		    END LOOP;
		END LOOP;

		RETURN maximum - minimum;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_roughness(
	rast raster, nband integer,
	customextent raster,
	pixeltype text DEFAULT '32BF', interpolate_nodata boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$
	DECLARE
		_rast @extschema@.raster;
		_nband integer;
		_pixtype text;
		_pixwidth double precision;
		_pixheight double precision;
		_width integer;
		_height integer;
		_customextent @extschema@.raster;
		_extenttype text;
	BEGIN
		_customextent := customextent;
		IF _customextent IS NULL THEN
			_extenttype := 'FIRST';
		ELSE
			_extenttype := 'CUSTOM';
		END IF;

		IF interpolate_nodata IS TRUE THEN
			_rast := @extschema@.ST_MapAlgebra(
				ARRAY[ROW(rast, nband)]::rastbandarg[],
				'@extschema@.st_invdistweight4ma(double precision[][][], integer[][], text[])'::regprocedure,
				pixeltype,
				'FIRST', NULL,
				1, 1
			);
			_nband := 1;
			_pixtype := NULL;
		ELSE
			_rast := rast;
			_nband := nband;
			_pixtype := pixeltype;
		END IF;

		RETURN @extschema@.ST_MapAlgebra(
			ARRAY[ROW(_rast, _nband)]::rastbandarg[],
			' @extschema@._ST_roughness4ma(double precision[][][], integer[][], text[])'::regprocedure,
			_pixtype,
			_extenttype, _customextent,
			1, 1);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_roughness(
	rast raster, nband integer DEFAULT 1,
	pixeltype text DEFAULT '32BF', interpolate_nodata boolean DEFAULT FALSE
)
	RETURNS RASTER
	AS $$ SELECT @extschema@.ST_roughness($1, $2, NULL::@extschema@.raster, $3, $4) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_tri4ma(value double precision[][][], pos integer[][], VARIADIC userargs text[] DEFAULT NULL)
	RETURNS double precision
	AS $$
	DECLARE
		x integer;
		y integer;
		z integer;

		Z1 double precision;
		Z2 double precision;
		Z3 double precision;
		Z4 double precision;
		Z5 double precision;
		Z6 double precision;
		Z7 double precision;
		Z8 double precision;
		Z9 double precision;

		tri double precision;
		_value double precision[][][];
		ndims int;
	BEGIN
		ndims := array_ndims(value);
		-- add a third dimension if 2-dimension
		IF ndims = 2 THEN
			_value := @extschema@._ST_convertarray4ma(value);
		ELSEIF ndims != 3 THEN
			RAISE EXCEPTION 'First parameter of function must be a 3-dimension array';
		ELSE
			_value := value;
		END IF;

		-- only use the first raster passed to this function
		IF array_length(_value, 1) > 1 THEN
			RAISE NOTICE 'Only using the values from the first raster';
		END IF;
		z := array_lower(_value, 1);

		IF (
			array_lower(_value, 2) != 1 OR array_upper(_value, 2) != 3 OR
			array_lower(_value, 3) != 1 OR array_upper(_value, 3) != 3
		) THEN
			RAISE EXCEPTION 'First parameter of function must be a 1x3x3 array with each of the lower bounds starting from 1';
		END IF;

		-- check that center pixel isn't NODATA
		IF _value[z][2][2] IS NULL THEN
			RETURN NULL;
		-- substitute center pixel for any neighbor pixels that are NODATA
		ELSE
			FOR y IN 1..3 LOOP
				FOR x IN 1..3 LOOP
					IF _value[z][y][x] IS NULL THEN
						_value[z][y][x] = _value[z][2][2];
					END IF;
				END LOOP;
			END LOOP;
		END IF;

		-------------------------------------------------
		--|   Z1= Z(-1,1) |  Z2= Z(0,1)	| Z3= Z(1,1)  |--
		-------------------------------------------------
		--|   Z4= Z(-1,0) |  Z5= Z(0,0) | Z6= Z(1,0)  |--
		-------------------------------------------------
		--|   Z7= Z(-1,-1)|  Z8= Z(0,-1)|  Z9= Z(1,-1)|--
		-------------------------------------------------

		-- _scale width and height units / z units to make z units equal to height width units
		Z1 := _value[z][1][1];
		Z2 := _value[z][2][1];
		Z3 := _value[z][3][1];
		Z4 := _value[z][1][2];
		Z5 := _value[z][2][2];
		Z6 := _value[z][3][2];
		Z7 := _value[z][1][3];
		Z8 := _value[z][2][3];
		Z9 := _value[z][3][3];

		tri := ( abs(Z1 - Z5 ) + abs( Z2 - Z5 ) + abs( Z3 - Z5 ) + abs( Z4 - Z5 ) + abs( Z6 - Z5 ) + abs( Z7 - Z5 ) + abs( Z8 - Z5 ) + abs ( Z9 - Z5 )) / 8;

		return tri;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_tri(
	rast raster, nband integer,
	customextent raster,
	pixeltype text DEFAULT '32BF',	interpolate_nodata boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$
	DECLARE
		_rast @extschema@.raster;
		_nband integer;
		_pixtype text;
		_pixwidth double precision;
		_pixheight double precision;
		_width integer;
		_height integer;
		_customextent @extschema@.raster;
		_extenttype text;
	BEGIN
		_customextent := customextent;
		IF _customextent IS NULL THEN
			_extenttype := 'FIRST';
		ELSE
			_extenttype := 'CUSTOM';
		END IF;

		IF interpolate_nodata IS TRUE THEN
			_rast := @extschema@.ST_MapAlgebra(
				ARRAY[ROW(rast, nband)]::rastbandarg[],
				'@extschema@.st_invdistweight4ma(double precision[][][], integer[][], text[])'::regprocedure,
				pixeltype,
				'FIRST', NULL,
				1, 1
			);
			_nband := 1;
			_pixtype := NULL;
		ELSE
			_rast := rast;
			_nband := nband;
			_pixtype := pixeltype;
		END IF;

		-- get properties
		_pixwidth := @extschema@.ST_PixelWidth(_rast);
		_pixheight := @extschema@.ST_PixelHeight(_rast);
		SELECT width, height INTO _width, _height FROM @extschema@.ST_Metadata(_rast);

		RETURN @extschema@.ST_MapAlgebra(
			ARRAY[ROW(_rast, _nband)]::rastbandarg[],
			' @extschema@._ST_tri4ma(double precision[][][], integer[][], text[])'::regprocedure,
			_pixtype,
			_extenttype, _customextent,
			1, 1);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_tri(
	rast raster, nband integer DEFAULT 1,
	pixeltype text DEFAULT '32BF', interpolate_nodata boolean DEFAULT FALSE
)
	RETURNS RASTER
	AS $$ SELECT @extschema@.ST_tri($1, $2, NULL::@extschema@.raster, $3, $4) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_grayscale4ma(value double precision[][][], pos integer[][], VARIADIC userargs text[] DEFAULT NULL)
	RETURNS double precision
	AS $$
	DECLARE
		ndims integer;
		_value double precision[][][];

		red double precision;
		green double precision;
		blue double precision;

		gray double precision;
	BEGIN

		ndims := array_ndims(value);
		-- add a third dimension if 2-dimension
		IF ndims = 2 THEN
			_value := @extschema@._ST_convertarray4ma(value);
		ELSEIF ndims != 3 THEN
			RAISE EXCEPTION 'First parameter of function must be a 3-dimension array';
		ELSE
			_value := value;
		END IF;

		red := _value[1][1][1];
		green := _value[2][1][1];
		blue := _value[3][1][1];

		gray = round(0.2989 * red + 0.5870 * green + 0.1140 * blue);
		RETURN gray;

	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_grayscale(
	rastbandargset rastbandarg[],
	extenttype text DEFAULT 'INTERSECTION'
)
	RETURNS RASTER
	AS $$
	DECLARE

		_NBANDS integer DEFAULT 3;
		_NODATA integer DEFAULT 255;
		_PIXTYPE text DEFAULT '8BUI';

		_set rastbandarg[];

		nrast integer;
		idx integer;
		rast @extschema@.raster;
		nband integer;

		stats summarystats;
		nodata double precision;
		nodataval integer;
		reclassexpr text;

	BEGIN

		-- check for three rastbandarg
		nrast := array_length(rastbandargset, 1);
		IF nrast < _NBANDS THEN
			RAISE EXCEPTION '''rastbandargset'' must have three bands for red, green and blue';
		ELSIF nrast > _NBANDS THEN
			RAISE WARNING 'Only the first three elements of ''rastbandargset'' will be used';
			_set := rastbandargset[1:3];
		ELSE
			_set := rastbandargset;
		END IF;

		FOR idx IN 1.._NBANDS LOOP

			rast := _set[idx].rast;
			nband := _set[idx].nband;

			-- check that each raster has the specified band
			IF @extschema@.ST_HasNoBand(rast, nband) THEN

				RAISE EXCEPTION 'Band at index ''%'' not found for raster ''%''', nband, idx;

			-- check that each band is 8BUI. if not, reclassify to 8BUI
			ELSIF @extschema@.ST_BandPixelType(rast, nband) != _PIXTYPE THEN

				stats := @extschema@.ST_SummaryStats(rast, nband);
				nodata := @extschema@.ST_BandNoDataValue(rast, nband);

				IF nodata IS NOT NULL THEN
					nodataval := _NODATA;
					reclassexpr := concat(
						concat('[', nodata , '-', nodata, ']:', _NODATA, '-', _NODATA, ','),
						concat('[', stats.min , '-', stats.max , ']:0-', _NODATA - 1)
					);
				ELSE
					nodataval := NULL;
					reclassexpr := concat('[', stats.min , '-', stats.max , ']:0-', _NODATA);
				END IF;

				_set[idx] := ROW(
					@extschema@.ST_Reclass(
						rast,
						ROW(nband, reclassexpr, _PIXTYPE, nodataval)::reclassarg
					),
					nband
				)::rastbandarg;

			END IF;

		END LOOP;

		-- call map algebra with _st_grayscale4ma
		RETURN @extschema@.ST_MapAlgebra(
			_set,
			'@extschema@._ST_Grayscale4MA(double precision[][][], integer[][], text[])'::regprocedure,
			'8BUI',
			extenttype
		);

	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_grayscale(
	rast raster,
 	redband integer DEFAULT 1,
 	greenband integer DEFAULT 2,
 	blueband integer DEFAULT 3,
	extenttype text DEFAULT 'INTERSECTION'
)
	RETURNS RASTER
	AS $$
	DECLARE
	BEGIN

		RETURN @extschema@.ST_Grayscale(
			ARRAY[
				ROW(rast, redband)::rastbandarg,
				ROW(rast, greenband)::rastbandarg,
				ROW(rast, blueband)::rastbandarg
			]::rastbandarg[],
			extenttype
		);

	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_isempty(rast raster)
    RETURNS boolean
    AS '$libdir/rtpostgis-2.5', 'RASTER_isEmpty'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_hasnoband(rast raster, nband int DEFAULT 1)
    RETURNS boolean
    AS '$libdir/rtpostgis-2.5', 'RASTER_hasNoBand'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_bandnodatavalue(rast raster, band integer DEFAULT 1)
    RETURNS double precision
    AS '$libdir/rtpostgis-2.5','RASTER_getBandNoDataValue'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_bandisnodata(rast raster, band integer DEFAULT 1, forceChecking boolean DEFAULT FALSE)
    RETURNS boolean
    AS '$libdir/rtpostgis-2.5', 'RASTER_bandIsNoData'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_bandisnodata(rast raster, forceChecking boolean)
    RETURNS boolean
    AS $$ SELECT @extschema@.ST_bandisnodata($1, 1, $2) $$
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_bandpath(rast raster, band integer DEFAULT 1)
    RETURNS text
    AS '$libdir/rtpostgis-2.5','RASTER_getBandPath'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_BandPixelType(rast raster, band integer DEFAULT 1)
    RETURNS text
    AS '$libdir/rtpostgis-2.5','RASTER_getBandPixelTypeName'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_BandMetaData(
	rast raster,
	band int[],
	OUT bandnum int,
	OUT pixeltype text,
	OUT nodatavalue double precision,
	OUT isoutdb boolean,
	OUT path text,
	OUT outdbbandnum integer,
	OUT filesize bigint,
	OUT filetimestamp bigint
)
	AS '$libdir/rtpostgis-2.5','RASTER_bandmetadata'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_BandMetaData(
	rast raster,
	band int DEFAULT 1,
	OUT pixeltype text,
	OUT nodatavalue double precision,
	OUT isoutdb boolean,
	OUT path text,
	OUT outdbbandnum integer,
	OUT filesize bigint,
	OUT filetimestamp bigint
)
	AS $$ SELECT pixeltype, nodatavalue, isoutdb, path, outdbbandnum, filesize, filetimestamp FROM @extschema@.ST_BandMetaData($1, ARRAY[$2]::int[]) LIMIT 1 $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_BandFileSize(rast raster, band integer DEFAULT 1)
    RETURNS bigint
    AS '$libdir/rtpostgis-2.5','RASTER_getBandFileSize'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION St_BandFileTimestamp(rast raster, band integer DEFAULT 1)
    RETURNS bigint
    AS '$libdir/rtpostgis-2.5','RASTER_getBandFileTimestamp'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_value(rast raster, band integer, x integer, y integer, exclude_nodata_value boolean DEFAULT TRUE)
    RETURNS float8
    AS '$libdir/rtpostgis-2.5','RASTER_getPixelValue'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_value(rast raster, x integer, y integer, exclude_nodata_value boolean DEFAULT TRUE)
    RETURNS float8
    AS $$ SELECT st_value($1, 1, $2, $3, $4) $$
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_value(rast raster, band integer, pt geometry, exclude_nodata_value boolean DEFAULT TRUE)
    RETURNS float8 AS
    $$
    DECLARE
        x float8;
        y float8;
        gtype text;
    BEGIN
        gtype := @extschema@.ST_GeometryType(pt);
        IF ( gtype != 'ST_Point' ) THEN
            RAISE EXCEPTION 'Attempting to get the value of a pixel with a non-point geometry';
        END IF;

				IF @extschema@.ST_SRID(pt) != @extschema@.ST_SRID(rast) THEN
            RAISE EXCEPTION 'Raster and geometry do not have the same SRID';
				END IF;

        x := @extschema@.ST_x(pt);
        y := @extschema@.ST_y(pt);
        RETURN @extschema@.ST_value(rast,
                        band,
                        @extschema@.ST_worldtorastercoordx(rast, x, y),
                        @extschema@.ST_worldtorastercoordy(rast, x, y),
                        exclude_nodata_value);
    END;
    $$
    LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Value(rast raster, pt geometry, exclude_nodata_value boolean DEFAULT TRUE)
    RETURNS float8
    AS $$ SELECT @extschema@.ST_value($1, 1, $2, $3) $$
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_pixelofvalue(
	rast raster,
	nband integer,
	search double precision[],
	exclude_nodata_value boolean DEFAULT TRUE,
	OUT val double precision,
	OUT x integer,
	OUT y integer
)
	RETURNS SETOF record
	AS '$libdir/rtpostgis-2.5', 'RASTER_pixelOfValue'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_PixelofValue(
	rast raster,
	search double precision[],
	exclude_nodata_value boolean DEFAULT TRUE,
	OUT val double precision,
	OUT x integer,
	OUT y integer
)
	RETURNS SETOF record
	AS $$ SELECT val, x, y FROM @extschema@.ST_PixelOfValue($1, 1, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_pixelofvalue(
	rast raster,
	nband integer,
	search double precision,
	exclude_nodata_value boolean DEFAULT TRUE,
	OUT x integer,
	OUT y integer
)
	RETURNS SETOF record
	AS $$ SELECT x, y FROM @extschema@.ST_PixelofValue($1, $2, ARRAY[$3], $4) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_pixelofvalue(
	rast raster,
	search double precision,
	exclude_nodata_value boolean DEFAULT TRUE,
	OUT x integer,
	OUT y integer
)
	RETURNS SETOF record
	AS $$ SELECT x, y FROM @extschema@.ST_PixelOfValue($1, 1, ARRAY[$2], $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_georeference(rast raster, format text DEFAULT 'GDAL')
    RETURNS text AS
    $$
    DECLARE
				scale_x numeric;
				scale_y numeric;
				skew_x numeric;
				skew_y numeric;
				ul_x numeric;
				ul_y numeric;

        result text;
    BEGIN
			SELECT scalex::numeric, scaley::numeric, skewx::numeric, skewy::numeric, upperleftx::numeric, upperlefty::numeric
				INTO scale_x, scale_y, skew_x, skew_y, ul_x, ul_y FROM @extschema@.ST_Metadata(rast);

						-- scale x
            result := trunc(scale_x, 10) || E'\n';

						-- skew y
            result := result || trunc(skew_y, 10) || E'\n';

						-- skew x
            result := result || trunc(skew_x, 10) || E'\n';

						-- scale y
            result := result || trunc(scale_y, 10) || E'\n';

        IF format = 'ESRI' THEN
						-- upper left x
            result := result || trunc((ul_x + scale_x * 0.5), 10) || E'\n';

						-- upper left y
            result = result || trunc((ul_y + scale_y * 0.5), 10) || E'\n';
        ELSE -- IF format = 'GDAL' THEN
						-- upper left x
            result := result || trunc(ul_x, 10) || E'\n';

						-- upper left y
            result := result || trunc(ul_y, 10) || E'\n';
        END IF;

        RETURN result;
    END;
    $$
    LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE; -- WITH (isstrict);
CREATE OR REPLACE FUNCTION st_setscale(rast raster, scale float8)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5','RASTER_setScale'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_setscale(rast raster, scalex float8, scaley float8)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5','RASTER_setScaleXY'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_setskew(rast raster, skew float8)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5','RASTER_setSkew'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_setskew(rast raster, skewx float8, skewy float8)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5','RASTER_setSkewXY'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_setsrid(rast raster, srid integer)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5','RASTER_setSRID'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_setupperleft(rast raster, upperleftx float8, upperlefty float8)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5','RASTER_setUpperLeftXY'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_setrotation(rast raster, rotation float8)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5','RASTER_setRotation'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_setgeotransform(rast raster,
    imag double precision,
    jmag double precision,
    theta_i double precision,
    theta_ij double precision,
    xoffset double precision,
    yoffset double precision)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5','RASTER_setGeotransform'
    LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_setgeoreference(rast raster, georef text, format text DEFAULT 'GDAL')
    RETURNS raster AS
    $$
    DECLARE
        params text[];
        rastout @extschema@.raster;
    BEGIN
        IF rast IS NULL THEN
            RAISE WARNING 'Cannot set georeferencing on a null raster in st_setgeoreference.';
            RETURN rastout;
        END IF;

        SELECT regexp_matches(georef,
            E'(-?\\d+(?:\\.\\d+)?)\\s(-?\\d+(?:\\.\\d+)?)\\s(-?\\d+(?:\\.\\d+)?)\\s' ||
            E'(-?\\d+(?:\\.\\d+)?)\\s(-?\\d+(?:\\.\\d+)?)\\s(-?\\d+(?:\\.\\d+)?)') INTO params;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'st_setgeoreference requires a string with 6 floating point values.';
        END IF;

        IF format = 'ESRI' THEN
            -- params array is now:
            -- {scalex, skewy, skewx, scaley, upperleftx, upperlefty}
            rastout := @extschema@.ST_setscale(rast, params[1]::float8, params[4]::float8);
            rastout := @extschema@.ST_setskew(rastout, params[3]::float8, params[2]::float8);
            rastout := @extschema@.ST_setupperleft(rastout,
                                   params[5]::float8 - (params[1]::float8 * 0.5),
                                   params[6]::float8 - (params[4]::float8 * 0.5));
        ELSE
            IF format != 'GDAL' THEN
                RAISE WARNING 'Format ''%'' is not recognized, defaulting to GDAL format.', format;
            END IF;
            -- params array is now:
            -- {scalex, skewy, skewx, scaley, upperleftx, upperlefty}

            rastout := @extschema@.ST_setscale(rast, params[1]::float8, params[4]::float8);
            rastout := @extschema@.ST_setskew( rastout, params[3]::float8, params[2]::float8);
            rastout := @extschema@.ST_setupperleft(rastout, params[5]::float8, params[6]::float8);
        END IF;
        RETURN rastout;
    END;
    $$
    LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE; -- WITH (isstrict);
CREATE OR REPLACE FUNCTION st_setgeoreference(
	rast raster,
	upperleftx double precision, upperlefty double precision,
	scalex double precision, scaley double precision,
	skewx double precision, skewy double precision
)
	RETURNS raster
	AS $$ SELECT @extschema@.ST_setgeoreference($1, array_to_string(ARRAY[$4, $7, $6, $5, $2, $3], ' ')) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_tile(
	rast raster,
	width integer, height integer,
	nband integer[] DEFAULT NULL,
	padwithnodata boolean DEFAULT FALSE, nodataval double precision DEFAULT NULL
)
	RETURNS SETOF raster
	AS '$libdir/rtpostgis-2.5','RASTER_tile'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_tile(
	rast raster, nband integer[],
	width integer, height integer,
	padwithnodata boolean DEFAULT FALSE, nodataval double precision DEFAULT NULL
)
	RETURNS SETOF raster
	AS $$ SELECT @extschema@._ST_tile($1, $3, $4, $2, $5, $6) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_tile(
	rast raster, nband integer,
	width integer, height integer,
	padwithnodata boolean DEFAULT FALSE, nodataval double precision DEFAULT NULL
)
	RETURNS SETOF raster
	AS $$ SELECT @extschema@._ST_tile($1, $3, $4, ARRAY[$2]::integer[], $5, $6) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_tile(
	rast raster,
	width integer, height integer,
	padwithnodata boolean DEFAULT FALSE, nodataval double precision DEFAULT NULL
)
	RETURNS SETOF raster
	AS $$ SELECT @extschema@._ST_tile($1, $2, $3, NULL::integer[], $4, $5) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_setbandnodatavalue(rast raster, band integer, nodatavalue float8, forceChecking boolean DEFAULT FALSE)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5','RASTER_setBandNoDataValue'
    LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_setbandnodatavalue(rast raster, nodatavalue float8)
    RETURNS raster
    AS $$ SELECT @extschema@.ST_setbandnodatavalue($1, 1, $2, FALSE) $$
    LANGUAGE 'sql';
CREATE OR REPLACE FUNCTION st_setbandisnodata(rast raster, band integer DEFAULT 1)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5', 'RASTER_setBandIsNoData'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_setbandpath(rast raster, band integer, outdbpath text, outdbindex integer, force boolean DEFAULT FALSE)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5', 'RASTER_setBandPath'
    LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_setbandindex(rast raster, band integer, outdbindex integer, force boolean DEFAULT FALSE)
    RETURNS raster
		AS $$ SELECT @extschema@.ST_SetBandPath($1, $2, NULL, $3, $4) $$
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_SetValues(
	rast raster, nband integer,
	x integer, y integer,
	newvalueset double precision[][],
	noset boolean[][] DEFAULT NULL,
	hasnosetvalue boolean DEFAULT FALSE,
	nosetvalue double precision DEFAULT NULL,
	keepnodata boolean DEFAULT FALSE
)
	RETURNS raster
	AS '$libdir/rtpostgis-2.5', 'RASTER_setPixelValuesArray'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_SetValues(
	rast raster, nband integer,
	x integer, y integer,
	newvalueset double precision[][],
	noset boolean[][] DEFAULT NULL,
	keepnodata boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_setvalues($1, $2, $3, $4, $5, $6, FALSE, NULL, $7) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_SetValues(
	rast raster, nband integer,
	x integer, y integer,
	newvalueset double precision[][],
	nosetvalue double precision,
	keepnodata boolean DEFAULT FALSE
)
	RETURNS raster
	AS $$ SELECT @extschema@._ST_setvalues($1, $2, $3, $4, $5, NULL, TRUE, $6, $7) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_SetValues(
	rast raster, nband integer,
	x integer, y integer,
	width integer, height integer,
	newvalue double precision,
	keepnodata boolean DEFAULT FALSE
)
	RETURNS raster AS
	$$
	BEGIN
		IF width <= 0 OR height <= 0 THEN
			RAISE EXCEPTION 'Values for width and height must be greater than zero';
			RETURN NULL;
		END IF;
		RETURN @extschema@._ST_setvalues($1, $2, $3, $4, array_fill($7, ARRAY[$6, $5]::int[]), NULL, FALSE, NULL, $8);
	END;
	$$
	LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_SetValues(
	rast raster,
	x integer, y integer,
	width integer, height integer,
	newvalue double precision,
	keepnodata boolean DEFAULT FALSE
)
	RETURNS raster AS
	$$
	BEGIN
		IF width <= 0 OR height <= 0 THEN
			RAISE EXCEPTION 'Values for width and height must be greater than zero';
			RETURN NULL;
		END IF;
		RETURN @extschema@._ST_setvalues($1, 1, $2, $3, array_fill($6, ARRAY[$5, $4]::int[]), NULL, FALSE, NULL, $7);
	END;
	$$
	LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_SetValues(
	rast raster, nband integer,
	geomvalset geomval[],
	keepnodata boolean DEFAULT FALSE
)
	RETURNS raster
	AS '$libdir/rtpostgis-2.5', 'RASTER_setPixelValuesGeomval'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_SetValue(rast raster, band integer, x integer, y integer, newvalue float8)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5','RASTER_setPixelValue'
    LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_SetValue(rast raster, x integer, y integer, newvalue float8)
    RETURNS raster
    AS $$ SELECT @extschema@.ST_SetValue($1, 1, $2, $3, $4) $$
    LANGUAGE 'sql';
CREATE OR REPLACE FUNCTION ST_SetValue(
	rast raster, nband integer,
	geom geometry, newvalue double precision
)
	RETURNS raster
	AS $$ SELECT @extschema@.ST_setvalues($1, $2, ARRAY[ROW($3, $4)]::geomval[], FALSE) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_SetValue(
	rast raster,
	geom geometry, newvalue double precision
)
	RETURNS raster
	AS $$ SELECT @extschema@.ST_setvalues($1, 1, ARRAY[ROW($2, $3)]::geomval[], FALSE) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_dumpaspolygons(rast raster, band integer DEFAULT 1, exclude_nodata_value boolean DEFAULT TRUE)
	RETURNS SETOF geomval
	AS '$libdir/rtpostgis-2.5','RASTER_dumpAsPolygons'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_dumpvalues(
	rast raster, nband integer[] DEFAULT NULL, exclude_nodata_value boolean DEFAULT TRUE,
	OUT nband integer, OUT valarray double precision[][]
)
	RETURNS SETOF record
	AS '$libdir/rtpostgis-2.5','RASTER_dumpValues'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_dumpvalues(rast raster, nband integer, exclude_nodata_value boolean DEFAULT TRUE)
	RETURNS double precision[][]
	AS $$ SELECT valarray FROM @extschema@.ST_dumpvalues($1, ARRAY[$2]::integer[], $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_polygon(rast raster, band integer DEFAULT 1)
	RETURNS geometry
	AS '$libdir/rtpostgis-2.5','RASTER_getPolygon'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_pixelaspolygons(
	rast raster,
	band integer DEFAULT 1,
	columnx integer DEFAULT NULL,
	rowy integer DEFAULT NULL,
	exclude_nodata_value boolean DEFAULT TRUE,
	OUT geom geometry,
	OUT val double precision,
	OUT x integer,
	OUT y integer
)
	RETURNS SETOF record
	AS '$libdir/rtpostgis-2.5', 'RASTER_getPixelPolygons'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_pixelaspolygons(
	rast raster,
	band integer DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	OUT geom geometry,
	OUT val double precision,
	OUT x int,
	OUT y int
)
	RETURNS SETOF record
	AS $$ SELECT geom, val, x, y FROM @extschema@._ST_pixelaspolygons($1, $2, NULL, NULL, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_pixelaspolygon(rast raster, x integer, y integer)
	RETURNS geometry
	AS $$ SELECT geom FROM @extschema@._ST_pixelaspolygons($1, NULL, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_pixelaspoints(
	rast raster,
	band integer DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	OUT geom geometry,
	OUT val double precision,
	OUT x int,
	OUT y int
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@.ST_PointN(  @extschema@.ST_ExteriorRing(geom), 1), val, x, y FROM @extschema@._ST_pixelaspolygons($1, $2, NULL, NULL, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_pixelaspoint(rast raster, x integer, y integer)
	RETURNS geometry
	AS $$ SELECT ST_PointN(ST_ExteriorRing(geom), 1) FROM @extschema@._ST_pixelaspolygons($1, NULL, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_pixelascentroids(
	rast raster,
	band integer DEFAULT 1,
	exclude_nodata_value boolean DEFAULT TRUE,
	OUT geom geometry,
	OUT val double precision,
	OUT x int,
	OUT y int
)
	RETURNS SETOF record
	AS $$ SELECT @extschema@.ST_Centroid(geom), val, x, y FROM @extschema@._ST_pixelaspolygons($1, $2, NULL, NULL, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_pixelascentroid(rast raster, x integer, y integer)
	RETURNS geometry
	AS $$ SELECT @extschema@.ST_Centroid(geom) FROM @extschema@._ST_pixelaspolygons($1, NULL, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_worldtorastercoord(
	rast raster,
	longitude double precision DEFAULT NULL, latitude double precision DEFAULT NULL,
	OUT columnx integer,
	OUT rowy integer
)
	AS '$libdir/rtpostgis-2.5', 'RASTER_worldToRasterCoord'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_worldtorastercoord(
	rast raster,
	longitude double precision, latitude double precision,
	OUT columnx integer,
	OUT rowy integer
)
	AS $$ SELECT columnx, rowy FROM @extschema@._ST_worldtorastercoord($1, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_worldtorastercoord(
	rast raster, pt geometry,
	OUT columnx integer,
	OUT rowy integer
)
	AS
	$$
	DECLARE
		rx integer;
		ry integer;
	BEGIN
		IF @extschema@.ST_geometrytype(pt) != 'ST_Point' THEN
			RAISE EXCEPTION 'Attempting to compute raster coordinate with a non-point geometry';
		END IF;
		IF @extschema@.ST_SRID(rast) != @extschema@.ST_SRID(pt) THEN
			RAISE EXCEPTION 'Raster and geometry do not have the same SRID';
		END IF;

		SELECT rc.columnx AS x, rc.rowy AS y INTO columnx, rowy FROM @extschema@._ST_worldtorastercoord($1, @extschema@.ST_x(pt), @extschema@.ST_y(pt)) AS rc;
		RETURN;
	END;
	$$
	LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_worldtorastercoordx(rast raster, xw float8, yw float8)
	RETURNS int
	AS $$ SELECT columnx FROM @extschema@._ST_worldtorastercoord($1, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_worldtorastercoordx(rast raster, xw float8)
	RETURNS int
	AS $$ SELECT columnx FROM @extschema@._ST_worldtorastercoord($1, $2, NULL) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_worldtorastercoordx(rast raster, pt geometry)
	RETURNS int AS
	$$
	DECLARE
		xr integer;
	BEGIN
		IF ( @extschema@.ST_geometrytype(pt) != 'ST_Point' ) THEN
			RAISE EXCEPTION 'Attempting to compute raster coordinate with a non-point geometry';
		END IF;
		IF @extschema@.ST_SRID(rast) != @extschema@.ST_SRID(pt) THEN
			RAISE EXCEPTION 'Raster and geometry do not have the same SRID';
		END IF;
		SELECT columnx INTO xr FROM @extschema@._ST_worldtorastercoord($1, @extschema@.ST_x(pt), @extschema@.ST_y(pt));
		RETURN xr;
	END;
	$$
	LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_worldtorastercoordy(rast raster, xw float8, yw float8)
	RETURNS int
	AS $$ SELECT rowy FROM @extschema@._ST_worldtorastercoord($1, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_worldtorastercoordy(rast raster, yw float8)
	RETURNS int
	AS $$ SELECT rowy FROM @extschema@._ST_worldtorastercoord($1, NULL, $2) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_worldtorastercoordy(rast raster, pt geometry)
	RETURNS int AS
	$$
	DECLARE
		yr integer;
	BEGIN
		IF ( st_geometrytype(pt) != 'ST_Point' ) THEN
			RAISE EXCEPTION 'Attempting to compute raster coordinate with a non-point geometry';
		END IF;
		IF ST_SRID(rast) != ST_SRID(pt) THEN
			RAISE EXCEPTION 'Raster and geometry do not have the same SRID';
		END IF;
		SELECT rowy INTO yr FROM @extschema@._ST_worldtorastercoord($1, st_x(pt), st_y(pt));
		RETURN yr;
	END;
	$$
	LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_rastertoworldcoord(
	rast raster,
	columnx integer DEFAULT NULL, rowy integer DEFAULT NULL,
	OUT longitude double precision,
	OUT latitude double precision
)
	AS '$libdir/rtpostgis-2.5', 'RASTER_rasterToWorldCoord'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_rastertoworldcoord(
	rast raster,
	columnx integer, rowy integer,
	OUT longitude double precision,
	OUT latitude double precision
)
	AS $$ SELECT longitude, latitude FROM @extschema@._ST_rastertoworldcoord($1, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_rastertoworldcoordx(rast raster, xr int, yr int)
	RETURNS float8
	AS $$ SELECT longitude FROM @extschema@._ST_rastertoworldcoord($1, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_rastertoworldcoordx(rast raster, xr int)
	RETURNS float8
	AS $$ SELECT longitude FROM @extschema@._ST_rastertoworldcoord($1, $2, NULL) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_rastertoworldcoordy(rast raster, xr int, yr int)
	RETURNS float8
	AS $$ SELECT latitude FROM @extschema@._ST_rastertoworldcoord($1, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_rastertoworldcoordy(rast raster, yr int)
	RETURNS float8
	AS $$ SELECT latitude FROM @extschema@._ST_rastertoworldcoord($1, NULL, $2) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_minpossiblevalue(pixeltype text)
	RETURNS double precision
	AS '$libdir/rtpostgis-2.5', 'RASTER_minPossibleValue'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_rastfromwkb(bytea)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5', 'RASTER_fromWKB'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_rastfromhexwkb(text)
    RETURNS raster
    AS '$libdir/rtpostgis-2.5', 'RASTER_fromHexWKB'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_aswkb(raster, outasin boolean DEFAULT FALSE)
    RETURNS bytea
    AS '$libdir/rtpostgis-2.5', 'RASTER_asWKB'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_asbinary(raster, outasin boolean DEFAULT FALSE)
    RETURNS bytea
		AS $$ SELECT @extschema@.ST_AsWKB($1, $2) $$
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_ashexwkb(raster, outasin boolean DEFAULT FALSE)
    RETURNS text
    AS '$libdir/rtpostgis-2.5', 'RASTER_asHexWKB'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION bytea(raster)
    RETURNS bytea
    AS '$libdir/rtpostgis-2.5', 'RASTER_to_bytea'
    LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (raster AS box3d)');
DROP CAST IF EXISTS (raster AS box3d);
CREATE CAST (raster AS box3d)
    WITH FUNCTION box3d(raster) AS ASSIGNMENT;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (raster AS geometry)');
DROP CAST IF EXISTS (raster AS geometry);
CREATE CAST (raster AS geometry)
    WITH FUNCTION st_convexhull(raster) AS ASSIGNMENT;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP CAST IF EXISTS (raster AS bytea)');
DROP CAST IF EXISTS (raster AS bytea);
CREATE CAST (raster AS bytea)
    WITH FUNCTION bytea(raster) AS ASSIGNMENT;
CREATE OR REPLACE FUNCTION raster_hash(raster)
	RETURNS integer
	AS 'hashvarlena'
	LANGUAGE 'internal' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_eq(raster, raster)
	RETURNS bool
	AS $$ SELECT @extschema@.raster_hash($1) = @extschema@.raster_hash($2) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator raster = -- LastUpdated: 201
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 201 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR = (
	LEFTARG = raster, RIGHTARG = raster, PROCEDURE = raster_eq,
	COMMUTATOR = '=',
	RESTRICT = eqsel, JOIN = eqjoinsel
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator class hash_raster_ops -- LastUpdated: 201
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 201 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$
    CREATE OPERATOR CLASS hash_raster_ops
	DEFAULT FOR TYPE raster USING hash AS
	OPERATOR	1	= ,
	FUNCTION	1	raster_hash (raster);
    $postgis_proc_upgrade_parsed_def$;
  END IF; -- version_from >= 201
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION raster_overleft(raster, raster)
    RETURNS bool
    AS 'select $1::@extschema@.geometry &< $2::@extschema@.geometry'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_overright(raster, raster)
    RETURNS bool
    AS 'select $1::@extschema@.geometry &> $2::@extschema@.geometry'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_left(raster, raster)
    RETURNS bool
    AS 'select $1::@extschema@.geometry << $2::@extschema@.geometry'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_right(raster, raster)
    RETURNS bool
    AS 'select $1::@extschema@.geometry >> $2::@extschema@.geometry'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_overabove(raster, raster)
    RETURNS bool
    AS 'select $1::@extschema@.geometry |&> $2::@extschema@.geometry'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_overbelow(raster, raster)
    RETURNS bool
    AS 'select $1::@extschema@.geometry &<| $2::@extschema@.geometry'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_above(raster, raster)
    RETURNS bool
    AS 'select $1::@extschema@.geometry |>> $2::@extschema@.geometry'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_below(raster, raster)
    RETURNS bool
    AS 'select $1::@extschema@.geometry <<| $2::@extschema@.geometry'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_same(raster, raster)
    RETURNS bool
    AS 'select $1::@extschema@.geometry ~= $2::@extschema@.geometry'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_contained(raster, raster)
    RETURNS bool
    AS 'select $1::@extschema@.geometry OPERATOR(@extschema@.@) $2::@extschema@.geometry'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_contain(raster, raster)
    RETURNS bool
    AS 'select $1::@extschema@.geometry ~ $2::@extschema@.geometry'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_overlap(raster, raster)
    RETURNS bool
    AS 'select $1::@extschema@.geometry OPERATOR(@extschema@.&&) $2::@extschema@.geometry'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_geometry_contain(raster, geometry)
    RETURNS bool
    AS 'select $1::@extschema@.geometry ~ $2'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_contained_by_geometry(raster, geometry)
    RETURNS bool
    AS 'select $1::@extschema@.geometry OPERATOR(@extschema@.@) $2'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION raster_geometry_overlap(raster, geometry)
    RETURNS bool
    AS 'select $1::@extschema@.geometry OPERATOR(@extschema@.&&) $2'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_raster_contain(geometry, raster)
    RETURNS bool
    AS 'select $1 OPERATOR(@extschema@.~) $2::@extschema@.geometry'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_contained_by_raster(geometry, raster)
    RETURNS bool
    AS 'select $1 OPERATOR(@extschema@.@) $2::@extschema@.geometry'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION geometry_raster_overlap(geometry, raster)
    RETURNS bool
    AS 'select $1 OPERATOR(@extschema@.&&) $2::@extschema@.geometry'
    LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
-- Operator raster << -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR << (
    LEFTARG = raster, RIGHTARG = raster, PROCEDURE = raster_left,
    COMMUTATOR = '>>',
    RESTRICT = positionsel, JOIN = positionjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator raster &< -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR &< (
    LEFTARG = raster, RIGHTARG = raster, PROCEDURE = raster_overleft,
    COMMUTATOR = '&>',
    RESTRICT = positionsel, JOIN = positionjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator raster <<| -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR <<| (
    LEFTARG = raster, RIGHTARG = raster, PROCEDURE = raster_below,
    COMMUTATOR = '|>>',
    RESTRICT = positionsel, JOIN = positionjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator raster &<| -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR &<| (
    LEFTARG = raster, RIGHTARG = raster, PROCEDURE = raster_overbelow,
    COMMUTATOR = '|&>',
    RESTRICT = positionsel, JOIN = positionjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator raster && -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR && (
    LEFTARG = raster, RIGHTARG = raster, PROCEDURE = raster_overlap,
    COMMUTATOR = '&&',
    RESTRICT = contsel, JOIN = contjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator raster &> -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR &> (
    LEFTARG = raster, RIGHTARG = raster, PROCEDURE = raster_overright,
    COMMUTATOR = '&<',
    RESTRICT = positionsel, JOIN = positionjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator raster >> -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR >> (
    LEFTARG = raster, RIGHTARG = raster, PROCEDURE = raster_right,
    COMMUTATOR = '<<',
    RESTRICT = positionsel, JOIN = positionjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator raster |&> -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR |&> (
    LEFTARG = raster, RIGHTARG = raster, PROCEDURE = raster_overabove,
    COMMUTATOR = '&<|',
    RESTRICT = positionsel, JOIN = positionjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator raster |>> -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR |>> (
    LEFTARG = raster, RIGHTARG = raster, PROCEDURE = raster_above,
    COMMUTATOR = '<<|',
    RESTRICT = positionsel, JOIN = positionjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator raster ~= -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR ~= (
    LEFTARG = raster, RIGHTARG = raster, PROCEDURE = raster_same,
    COMMUTATOR = '~=',
    RESTRICT = eqsel, JOIN = eqjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator raster @ -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR @ (
    LEFTARG = raster, RIGHTARG = raster, PROCEDURE = raster_contained,
    COMMUTATOR = '~',
    RESTRICT = contsel, JOIN = contjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator raster ~ -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR ~ (
    LEFTARG = raster, RIGHTARG = raster, PROCEDURE = raster_contain,
    COMMUTATOR = '@',
    RESTRICT = contsel, JOIN = contjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator raster ~ -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR ~ (
    LEFTARG = raster, RIGHTARG = geometry, PROCEDURE = raster_geometry_contain,
    -- COMMUTATOR = '@', -- see http://trac.osgeo.org/postgis/ticket/2532
    RESTRICT = contsel, JOIN = contjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator raster @ -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR @ (
    LEFTARG = raster, RIGHTARG = geometry, PROCEDURE = raster_contained_by_geometry,
    COMMUTATOR = '~',
    RESTRICT = contsel, JOIN = contjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator raster && -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR && (
    LEFTARG = raster, RIGHTARG = geometry, PROCEDURE = raster_geometry_overlap,
    COMMUTATOR = '&&',
    RESTRICT = contsel, JOIN = contjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geometry ~ -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR ~ (
    LEFTARG = geometry, RIGHTARG = raster, PROCEDURE = geometry_raster_contain,
    -- COMMUTATOR = '@', -- see http://trac.osgeo.org/postgis/ticket/2532
    RESTRICT = contsel, JOIN = contjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geometry @ -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR @ (
    LEFTARG = geometry, RIGHTARG = raster, PROCEDURE = geometry_contained_by_raster,
    COMMUTATOR = '~',
    RESTRICT = contsel, JOIN = contjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
-- Operator geometry && -- LastUpdated: 200
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 200 > version_from_num FROM _postgis_upgrade_info THEN
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE OPERATOR && (
    LEFTARG = geometry, RIGHTARG = raster, PROCEDURE = geometry_raster_overlap,
    COMMUTATOR = '&&',
    RESTRICT = contsel, JOIN = contjoinsel
    );
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION st_samealignment(rast1 raster, rast2 raster)
	RETURNS boolean
	AS '$libdir/rtpostgis-2.5', 'RASTER_sameAlignment'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_samealignment(
	ulx1 double precision, uly1 double precision, scalex1 double precision, scaley1 double precision, skewx1 double precision, skewy1 double precision,
	ulx2 double precision, uly2 double precision, scalex2 double precision, scaley2 double precision, skewx2 double precision, skewy2 double precision
)
	RETURNS boolean
	AS $$ SELECT st_samealignment(st_makeemptyraster(1, 1, $1, $2, $3, $4, $5, $6), st_makeemptyraster(1, 1, $7, $8, $9, $10, $11, $12)) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
-- Type agg_samealignment -- LastUpdated: 201
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 201 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE agg_samealignment AS (
	refraster raster,
	aligned boolean
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_samealignment_transfn(agg agg_samealignment, rast raster)
	RETURNS agg_samealignment AS $$
	DECLARE
		m record;
		aligned boolean;
	BEGIN
		IF agg IS NULL THEN
			agg.refraster := NULL;
			agg.aligned := NULL;
		END IF;

		IF rast IS NULL THEN
			agg.aligned := NULL;
		ELSE
			IF agg.refraster IS NULL THEN
				m := ST_Metadata(rast);
				agg.refraster := ST_MakeEmptyRaster(1, 1, m.upperleftx, m.upperlefty, m.scalex, m.scaley, m.skewx, m.skewy, m.srid);
				agg.aligned := TRUE;
			ELSIF agg.aligned IS TRUE THEN
				agg.aligned := ST_SameAlignment(agg.refraster, rast);
			END IF;
		END IF;
		RETURN agg;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _ST_samealignment_finalfn(agg agg_samealignment)
	RETURNS boolean
	AS $$ SELECT $1.aligned $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
-- Aggregate st_samealignment(raster) -- LastUpdated: 204
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 204 > version_from_num OR (
      204 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS st_samealignment(raster)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE AGGREGATE st_samealignment(raster) (
	SFUNC = _st_samealignment_transfn,
	STYPE = agg_samealignment,

	parallel = safe,

	FINALFUNC = _st_samealignment_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION st_notsamealignmentreason(rast1 raster, rast2 raster)
	RETURNS text
	AS '$libdir/rtpostgis-2.5', 'RASTER_notSameAlignmentReason'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_iscoveragetile(rast raster, coverage raster, tilewidth integer, tileheight integer)
	RETURNS boolean
	AS $$
	DECLARE
		_rastmeta record;
		_covmeta record;
		cr record;
		max integer[];
		tile integer[];
		edge integer[];
	BEGIN
		IF NOT @extschema@.ST_SameAlignment(rast, coverage) THEN
			RAISE NOTICE 'Raster and coverage are not aligned';
			RETURN FALSE;
		END IF;

		_rastmeta := @extschema@.ST_Metadata(rast);
		_covmeta := @extschema@.ST_Metadata(coverage);

		-- get coverage grid coordinates of upper-left of rast
		cr := @extschema@.ST_WorldToRasterCoord(coverage, _rastmeta.upperleftx, _rastmeta.upperlefty);

		-- rast is not part of coverage
		IF
			(cr.columnx < 1 OR cr.columnx > _covmeta.width) OR
			(cr.rowy < 1 OR cr.rowy > _covmeta.height)
		THEN
			RAISE NOTICE 'Raster is not in the coverage';
			RETURN FALSE;
		END IF;

		-- rast isn't on the coverage's grid
		IF
			((cr.columnx - 1) % tilewidth != 0) OR
			((cr.rowy - 1) % tileheight != 0)
		THEN
			RAISE NOTICE 'Raster is not aligned to tile grid of coverage';
			RETURN FALSE;
		END IF;

		-- max # of tiles on X and Y for coverage
		max[0] := ceil(_covmeta.width::double precision / tilewidth::double precision)::integer;
		max[1] := ceil(_covmeta.height::double precision / tileheight::double precision)::integer;

		-- tile # of rast in coverge
		tile[0] := (cr.columnx / tilewidth) + 1;
		tile[1] := (cr.rowy / tileheight) + 1;

		-- inner tile
		IF tile[0] < max[0] AND tile[1] < max[1] THEN
			IF
				(_rastmeta.width != tilewidth) OR
				(_rastmeta.height != tileheight)
			THEN
				RAISE NOTICE 'Raster width/height is invalid for interior tile of coverage';
				RETURN FALSE;
			ELSE
				RETURN TRUE;
			END IF;
		END IF;

		-- edge tile

		-- edge tile may have same size as inner tile
		IF
			(_rastmeta.width = tilewidth) AND
			(_rastmeta.height = tileheight)
		THEN
			RETURN TRUE;
		END IF;

		-- get edge tile width and height
		edge[0] := _covmeta.width - ((max[0] - 1) * tilewidth);
		edge[1] := _covmeta.height - ((max[1] - 1) * tileheight);

		-- edge tile not of expected tile size
		-- right and bottom
		IF tile[0] = max[0] AND tile[1] = max[1] THEN
			IF
				_rastmeta.width != edge[0] OR
				_rastmeta.height != edge[1]
			THEN
				RAISE NOTICE 'Raster width/height is invalid for right-most AND bottom-most tile of coverage';
				RETURN FALSE;
			END IF;
		ELSEIF tile[0] = max[0] THEN
			IF
				_rastmeta.width != edge[0] OR
				_rastmeta.height != tileheight
			THEN
				RAISE NOTICE 'Raster width/height is invalid for right-most tile of coverage';
				RETURN FALSE;
			END IF;
		ELSE
			IF
				_rastmeta.width != tilewidth OR
				_rastmeta.height != edge[1]
			THEN
				RAISE NOTICE 'Raster width/height is invalid for bottom-most tile of coverage';
				RETURN FALSE;
			END IF;
		END IF;

		RETURN TRUE;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_intersects(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS '$libdir/rtpostgis-2.5', 'RASTER_intersects'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_intersects(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS $$ SELECT $1 OPERATOR(@extschema@.&&) $3 AND CASE WHEN $2 IS NULL OR $4 IS NULL THEN @extschema@._st_intersects(@extschema@.st_convexhull($1), @extschema@.st_convexhull($3)) ELSE @extschema@._st_intersects($1, $2, $3, $4) END $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_intersects(rast1 raster, rast2 raster)
	RETURNS boolean
	AS $$ SELECT @extschema@.st_intersects($1, NULL::integer, $2, NULL::integer) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION _st_intersects(geom geometry, rast raster, nband integer DEFAULT NULL)
	RETURNS boolean AS $$
	DECLARE
		hasnodata boolean := TRUE;
		_geom @extschema@.geometry;
	BEGIN
		IF @extschema@.ST_SRID(rast) != @extschema@.ST_SRID(geom) THEN
			RAISE EXCEPTION 'Raster and geometry do not have the same SRID';
		END IF;

		_geom := @extschema@.ST_ConvexHull(rast);
		IF nband IS NOT NULL THEN
			SELECT CASE WHEN bmd.nodatavalue IS NULL THEN FALSE ELSE NULL END INTO hasnodata FROM @extschema@.ST_BandMetaData(rast, nband) AS bmd;
		END IF;

		IF @extschema@.ST_Intersects(geom, _geom) IS NOT TRUE THEN
			RETURN FALSE;
		ELSEIF nband IS NULL OR hasnodata IS FALSE THEN
			RETURN TRUE;
		END IF;

		SELECT @extschema@.ST_Buffer(@extschema@.ST_Collect(t.geom), 0) INTO _geom FROM @extschema@.ST_PixelAsPolygons(rast, nband) AS t;
		RETURN @extschema@.ST_Intersects(geom, _geom);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_intersects(geom geometry, rast raster, nband integer DEFAULT NULL)
	RETURNS boolean AS
	$$ SELECT $1 OPERATOR(@extschema@.&&) $2::@extschema@.geometry AND @extschema@._st_intersects($1, $2, $3); $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_intersects(rast raster, geom geometry, nband integer DEFAULT NULL)
	RETURNS boolean
	AS $$ SELECT $1::@extschema@.geometry OPERATOR(@extschema@.&&) $2 AND @extschema@._st_intersects($2, $1, $3) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_intersects(rast raster, nband integer, geom geometry)
	RETURNS boolean
	AS $$ SELECT $1::@extschema@.geometry OPERATOR(@extschema@.&&) $3 AND @extschema@._st_intersects($3, $1, $2) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION _st_overlaps(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS '$libdir/rtpostgis-2.5', 'RASTER_overlaps'
	LANGUAGE 'c' IMMUTABLE STRICT
	COST 1000;
CREATE OR REPLACE FUNCTION st_overlaps(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS $$ SELECT $1 OPERATOR(@extschema@.&&) $3 AND CASE WHEN $2 IS NULL OR $4 IS NULL THEN @extschema@._st_overlaps(@extschema@.st_convexhull($1), @extschema@.st_convexhull($3)) ELSE @extschema@._ST_overlaps($1, $2, $3, $4) END $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_overlaps(rast1 raster, rast2 raster)
	RETURNS boolean
	AS $$ SELECT @extschema@.st_overlaps($1, NULL::integer, $2, NULL::integer) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION _st_touches(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS '$libdir/rtpostgis-2.5', 'RASTER_touches'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_touches(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS $$ SELECT $1 OPERATOR(@extschema@.&&) $3 AND CASE WHEN $2 IS NULL OR $4 IS NULL THEN @extschema@._st_touches(@extschema@.st_convexhull($1), @extschema@.st_convexhull($3)) ELSE @extschema@._st_touches($1, $2, $3, $4) END $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_touches(rast1 raster, rast2 raster)
	RETURNS boolean
	AS $$ SELECT @extschema@.st_touches($1, NULL::integer, $2, NULL::integer) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION _st_contains(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS '$libdir/rtpostgis-2.5', 'RASTER_contains'
	LANGUAGE 'c' IMMUTABLE STRICT
	COST 1000;
CREATE OR REPLACE FUNCTION st_contains(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS $$ SELECT $1 OPERATOR(@extschema@.&&) $3 AND CASE WHEN $2 IS NULL OR $4 IS NULL THEN @extschema@._st_contains(@extschema@.st_convexhull($1), @extschema@.st_convexhull($3)) ELSE @extschema@._st_contains($1, $2, $3, $4) END $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_contains(rast1 raster, rast2 raster)
	RETURNS boolean
	AS $$ SELECT @extschema@.st_contains($1, NULL::integer, $2, NULL::integer) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION _st_containsproperly(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS '$libdir/rtpostgis-2.5', 'RASTER_containsProperly'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_containsproperly(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS $$ SELECT $1 OPERATOR(@extschema@.&&) $3 AND CASE WHEN $2 IS NULL OR $4 IS NULL THEN @extschema@._st_containsproperly(@extschema@.st_convexhull($1), @extschema@.st_convexhull($3)) ELSE @extschema@._st_containsproperly($1, $2, $3, $4) END $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_containsproperly(rast1 raster, rast2 raster)
	RETURNS boolean
	AS $$ SELECT @extschema@.st_containsproperly($1, NULL::integer, $2, NULL::integer) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION _st_covers(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS '$libdir/rtpostgis-2.5', 'RASTER_covers'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_covers(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS $$ SELECT $1 OPERATOR(@extschema@.&&) $3 AND CASE WHEN $2 IS NULL OR $4 IS NULL THEN @extschema@._st_covers(@extschema@.st_convexhull($1), @extschema@.st_convexhull($3)) ELSE @extschema@._st_covers($1, $2, $3, $4) END $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_covers(rast1 raster, rast2 raster)
	RETURNS boolean
	AS $$ SELECT @extschema@.st_covers($1, NULL::integer, $2, NULL::integer) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION _st_coveredby(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS '$libdir/rtpostgis-2.5', 'RASTER_coveredby'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_coveredby(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS $$ SELECT $1 OPERATOR(@extschema@.&&) $3 AND CASE WHEN $2 IS NULL OR $4 IS NULL THEN @extschema@._st_coveredby(@extschema@.st_convexhull($1), @extschema@.st_convexhull($3)) ELSE @extschema@._st_coveredby($1, $2, $3, $4) END $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_coveredby(rast1 raster, rast2 raster)
	RETURNS boolean
	AS $$ SELECT @extschema@.st_coveredby($1, NULL::integer, $2, NULL::integer) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION _st_within(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS $$ SELECT @extschema@._st_contains($3, $4, $1, $2) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_within(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS $$ SELECT $1 OPERATOR(@extschema@.&&) $3 AND CASE WHEN $2 IS NULL OR $4 IS NULL THEN @extschema@._st_within(@extschema@.st_convexhull($1), @extschema@.st_convexhull($3)) ELSE @extschema@._st_contains($3, $4, $1, $2) END $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_within(rast1 raster, rast2 raster)
	RETURNS boolean
	AS $$ SELECT @extschema@.st_within($1, NULL::integer, $2, NULL::integer) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION _ST_DWithin(rast1 raster, nband1 integer, rast2 raster, nband2 integer, distance double precision)
	RETURNS boolean
	AS '$libdir/rtpostgis-2.5', 'RASTER_dwithin'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION ST_DWithin(rast1 raster, nband1 integer, rast2 raster, nband2 integer, distance double precision)
	RETURNS boolean
	AS $$ SELECT $1::@extschema@.geometry OPERATOR(@extschema@.&&) @extschema@.ST_Expand(@extschema@.ST_ConvexHull($3), $5) AND $3::@extschema@.geometry OPERATOR(@extschema@.&&) @extschema@.ST_Expand(@extschema@.ST_ConvexHull($1), $5) AND CASE WHEN $2 IS NULL OR $4 IS NULL THEN @extschema@._ST_dwithin(@extschema@.st_convexhull($1), @extschema@.st_convexhull($3), $5) ELSE @extschema@._ST_dwithin($1, $2, $3, $4, $5) END $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION ST_DWithin(rast1 raster, rast2 raster, distance double precision)
	RETURNS boolean
	AS $$ SELECT @extschema@.st_dwithin($1, NULL::integer, $2, NULL::integer, $3) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION _ST_DFullyWithin(rast1 raster, nband1 integer, rast2 raster, nband2 integer, distance double precision)
	RETURNS boolean
	AS '$libdir/rtpostgis-2.5', 'RASTER_dfullywithin'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION ST_DFullyWithin(rast1 raster, nband1 integer, rast2 raster, nband2 integer, distance double precision)
	RETURNS boolean
	AS $$ SELECT $1::@extschema@.geometry OPERATOR(@extschema@.&&) @extschema@.ST_Expand(@extschema@.ST_ConvexHull($3), $5) AND $3::@extschema@.geometry OPERATOR(@extschema@.&&) @extschema@.ST_Expand(@extschema@.ST_ConvexHull($1), $5) AND CASE WHEN $2 IS NULL OR $4 IS NULL THEN @extschema@._ST_DFullyWithin(@extschema@.ST_ConvexHull($1), @extschema@.ST_Convexhull($3), $5) ELSE @extschema@._ST_DFullyWithin($1, $2, $3, $4, $5) END $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION ST_DFullyWithin(rast1 raster, rast2 raster, distance double precision)
	RETURNS boolean
	AS $$ SELECT @extschema@.ST_DFullyWithin($1, NULL::integer, $2, NULL::integer, $3) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION st_disjoint(rast1 raster, nband1 integer, rast2 raster, nband2 integer)
	RETURNS boolean
	AS $$ SELECT CASE WHEN $2 IS NULL OR $4 IS NULL THEN @extschema@.ST_Disjoint(@extschema@.ST_ConvexHull($1), @extschema@.ST_ConvexHull($3)) ELSE NOT @extschema@._ST_intersects($1, $2, $3, $4) END $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION ST_Disjoint(rast1 raster, rast2 raster)
	RETURNS boolean
	AS $$ SELECT @extschema@.ST_Disjoint($1, NULL::integer, $2, NULL::integer) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE
	COST 1000;
CREATE OR REPLACE FUNCTION ST_Intersection(geomin geometry, rast raster, band integer DEFAULT 1)
	RETURNS SETOF geomval AS $$
	DECLARE
		intersects boolean := FALSE;
	BEGIN
		intersects := @extschema@.ST_Intersects(geomin, rast, band);
		IF intersects THEN
			-- Return the intersections of the geometry with the vectorized parts of
			-- the raster and the values associated with those parts, if really their
			-- intersection is not empty.
			RETURN QUERY
				SELECT
					intgeom,
					val
				FROM (
					SELECT
						@extschema@.ST_Intersection((gv).geom, geomin) AS intgeom,
						(gv).val
					FROM @extschema@.ST_DumpAsPolygons(rast, band) gv
					WHERE @extschema@.ST_Intersects((gv).geom, geomin)
				) foo
				WHERE NOT @extschema@.ST_IsEmpty(intgeom);
		ELSE
			-- If the geometry does not intersect with the raster, return an empty
			-- geometry and a null value
			RETURN QUERY
				SELECT
					emptygeom,
					NULL::float8
				FROM @extschema@.ST_GeomCollFromText('GEOMETRYCOLLECTION EMPTY', ST_SRID($1)) emptygeom;
		END IF;
	END;
	$$
	LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_intersection(rast raster, band integer, geomin geometry)
	RETURNS SETOF geomval AS
	$$ SELECT @extschema@.ST_Intersection($3, $1, $2) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Intersection(rast raster, geomin geometry)
	RETURNS SETOF geomval AS
	$$ SELECT @extschema@.ST_Intersection($2, $1, 1) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION ST_Intersection(
	rast1 raster, band1 int,
	rast2 raster, band2 int,
	returnband text DEFAULT 'BOTH',
	nodataval double precision[] DEFAULT NULL
)
	RETURNS raster
	AS $$
	DECLARE
		rtn @extschema@.raster;
		_returnband text;
		newnodata1 float8;
		newnodata2 float8;
	BEGIN
		IF ST_SRID(rast1) != ST_SRID(rast2) THEN
			RAISE EXCEPTION 'The two rasters do not have the same SRID';
		END IF;

		newnodata1 := coalesce(nodataval[1], ST_BandNodataValue(rast1, band1), ST_MinPossibleValue(@extschema@.ST_BandPixelType(rast1, band1)));
		newnodata2 := coalesce(nodataval[2], ST_BandNodataValue(rast2, band2), ST_MinPossibleValue(@extschema@.ST_BandPixelType(rast2, band2)));

		_returnband := upper(returnband);

		rtn := NULL;
		CASE
			WHEN _returnband = 'BAND1' THEN
				rtn := @extschema@.ST_MapAlgebraExpr(rast1, band1, rast2, band2, '[rast1.val]', @extschema@.ST_BandPixelType(rast1, band1), 'INTERSECTION', newnodata1::text, newnodata1::text, newnodata1);
				rtn := @extschema@.ST_SetBandNodataValue(rtn, 1, newnodata1);
			WHEN _returnband = 'BAND2' THEN
				rtn := @extschema@.ST_MapAlgebraExpr(rast1, band1, rast2, band2, '[rast2.val]', @extschema@.ST_BandPixelType(rast2, band2), 'INTERSECTION', newnodata2::text, newnodata2::text, newnodata2);
				rtn := @extschema@.ST_SetBandNodataValue(rtn, 1, newnodata2);
			WHEN _returnband = 'BOTH' THEN
				rtn := @extschema@.ST_MapAlgebraExpr(rast1, band1, rast2, band2, '[rast1.val]', @extschema@.ST_BandPixelType(rast1, band1), 'INTERSECTION', newnodata1::text, newnodata1::text, newnodata1);
				rtn := ST_SetBandNodataValue(rtn, 1, newnodata1);
				rtn := ST_AddBand(rtn, ST_MapAlgebraExpr(rast1, band1, rast2, band2, '[rast2.val]', @extschema@.ST_BandPixelType(rast2, band2), 'INTERSECTION', newnodata2::text, newnodata2::text, newnodata2));
				rtn := ST_SetBandNodataValue(rtn, 2, newnodata2);
			ELSE
				RAISE EXCEPTION 'Unknown value provided for returnband: %', returnband;
				RETURN NULL;
		END CASE;

		RETURN rtn;
	END;
	$$ LANGUAGE 'plpgsql' STABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_intersection(
	rast1 raster, band1 int,
	rast2 raster, band2 int,
	returnband text,
	nodataval double precision
)
	RETURNS raster AS
	$$ SELECT @extschema@.st_intersection($1, $2, $3, $4, $5, ARRAY[$6, $6]) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_intersection(
	rast1 raster, band1 int,
	rast2 raster, band2 int,
	nodataval double precision[]
)
	RETURNS raster AS
	$$ SELECT @extschema@.st_intersection($1, $2, $3, $4, 'BOTH', $5) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_intersection(
	rast1 raster, band1 int,
	rast2 raster, band2 int,
	nodataval double precision
)
	RETURNS raster AS
	$$ SELECT @extschema@.st_intersection($1, $2, $3, $4, 'BOTH', ARRAY[$5, $5]) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_intersection(
	rast1 raster,
	rast2 raster,
	returnband text DEFAULT 'BOTH',
	nodataval double precision[] DEFAULT NULL
)
	RETURNS raster AS
	$$ SELECT @extschema@.st_intersection($1, 1, $2, 1, $3, $4) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_intersection(
	rast1 raster,
	rast2 raster,
	returnband text,
	nodataval double precision
)
	RETURNS raster AS
	$$ SELECT @extschema@.st_intersection($1, 1, $2, 1, $3, ARRAY[$4, $4]) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_intersection(
	rast1 raster,
	rast2 raster,
	nodataval double precision[]
)
	RETURNS raster AS
	$$ SELECT @extschema@.st_intersection($1, 1, $2, 1, 'BOTH', $3) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_intersection(
	rast1 raster,
	rast2 raster,
	nodataval double precision
)
	RETURNS raster AS
	$$ SELECT @extschema@.st_intersection($1, 1, $2, 1, 'BOTH', ARRAY[$3, $3]) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
-- Type unionarg -- LastUpdated: 201
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 201 > version_from_num
     FROM _postgis_upgrade_info
  THEN
      EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE TYPE unionarg AS (
	nband int,
	uniontype text
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_union_finalfn(internal)
	RETURNS raster
	AS '$libdir/rtpostgis-2.5', 'RASTER_union_finalfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_union_transfn(internal, raster, unionarg[])
	RETURNS internal
	AS '$libdir/rtpostgis-2.5', 'RASTER_union_transfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
-- Aggregate st_union(raster,unionarg[]) -- LastUpdated: 204
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 204 > version_from_num OR (
      204 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS st_union(raster,unionarg[])';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE AGGREGATE st_union(raster, unionarg[]) (
	SFUNC = _st_union_transfn,
	STYPE = internal,

	parallel = safe,

	FINALFUNC = _st_union_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_union_transfn(internal, raster, integer, text)
	RETURNS internal
	AS '$libdir/rtpostgis-2.5', 'RASTER_union_transfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
-- Aggregate st_union(raster,integer,text) -- LastUpdated: 204
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 204 > version_from_num OR (
      204 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS st_union(raster,integer,text)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE AGGREGATE st_union(raster, integer, text) (
	SFUNC = _st_union_transfn,
	STYPE = internal,

	parallel = safe,

	FINALFUNC = _st_union_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_union_transfn(internal, raster, integer)
	RETURNS internal
	AS '$libdir/rtpostgis-2.5', 'RASTER_union_transfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
-- Aggregate st_union(raster,integer) -- LastUpdated: 204
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 204 > version_from_num OR (
      204 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS st_union(raster,integer)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE AGGREGATE st_union(raster, integer) (
	SFUNC = _st_union_transfn,
	STYPE = internal,

	parallel = safe,

	FINALFUNC = _st_union_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_union_transfn(internal, raster)
	RETURNS internal
	AS '$libdir/rtpostgis-2.5', 'RASTER_union_transfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
-- Aggregate st_union(raster) -- LastUpdated: 204
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 204 > version_from_num OR (
      204 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS st_union(raster)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE AGGREGATE st_union(raster) (
	SFUNC = _st_union_transfn,
	STYPE = internal,

	parallel = safe,

	FINALFUNC = _st_union_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_union_transfn(internal, raster, text)
	RETURNS internal
	AS '$libdir/rtpostgis-2.5', 'RASTER_union_transfn'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
-- Aggregate st_union(raster,text) -- LastUpdated: 204
DO LANGUAGE 'plpgsql'
$postgis_proc_upgrade$
BEGIN
  IF 204 > version_from_num OR (
      204 = version_from_num AND version_from_isdev
    ) FROM _postgis_upgrade_info
  THEN
    EXECUTE 'DROP AGGREGATE IF EXISTS st_union(raster,text)';
    EXECUTE $postgis_proc_upgrade_parsed_def$ CREATE AGGREGATE st_union(raster, text) (
	SFUNC = _st_union_transfn,
	STYPE = internal,

	parallel = safe,

	FINALFUNC = _st_union_finalfn
);
 $postgis_proc_upgrade_parsed_def$;
  END IF;
END
$postgis_proc_upgrade$;
CREATE OR REPLACE FUNCTION _st_clip(
	rast raster, nband integer[],
	geom geometry,
	nodataval double precision[] DEFAULT NULL, crop boolean DEFAULT TRUE
)
	RETURNS raster
	AS '$libdir/rtpostgis-2.5', 'RASTER_clip'
	LANGUAGE 'c' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_clip(
	rast raster, nband integer[],
	geom geometry,
	nodataval double precision[] DEFAULT NULL, crop boolean DEFAULT TRUE
)
	RETURNS raster
 	AS $$
	BEGIN
		-- short-cut if geometry's extent fully contains raster's extent
		IF (nodataval IS NULL OR array_length(nodataval, 1) < 1) AND @extschema@.ST_Contains(geom, @extschema@.ST_Envelope(rast)) THEN
			RETURN rast;
		END IF;

		RETURN @extschema@._ST_Clip($1, $2, $3, $4, $5);
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_clip(
	rast raster, nband integer,
	geom geometry,
	nodataval double precision, crop boolean DEFAULT TRUE
)
	RETURNS raster AS
	$$ SELECT @extschema@.ST_Clip($1, ARRAY[$2]::integer[], $3, ARRAY[$4]::double precision[], $5) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_clip(
	rast raster, nband integer,
	geom geometry,
	crop boolean
)
	RETURNS raster AS
	$$ SELECT @extschema@.ST_Clip($1, ARRAY[$2]::integer[], $3, null::double precision[], $4) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_clip(
	rast raster,
	geom geometry,
	nodataval double precision[] DEFAULT NULL, crop boolean DEFAULT TRUE
)
	RETURNS raster AS
	$$ SELECT @extschema@.ST_Clip($1, NULL, $2, $3, $4) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_clip(
	rast raster,
	geom geometry,
	nodataval double precision, crop boolean DEFAULT TRUE
)
	RETURNS raster AS
	$$ SELECT @extschema@.ST_Clip($1, NULL, $2, ARRAY[$3]::double precision[], $4) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_clip(
	rast raster,
	geom geometry,
	crop boolean
)
	RETURNS raster AS
	$$ SELECT @extschema@.ST_Clip($1, NULL, $2, null::double precision[], $3) $$
	LANGUAGE 'sql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_nearestvalue(
	rast raster, band integer,
	pt geometry,
	exclude_nodata_value boolean DEFAULT TRUE
)
	RETURNS double precision
	AS '$libdir/rtpostgis-2.5', 'RASTER_nearestValue'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_nearestvalue(
	rast raster,
	pt geometry,
	exclude_nodata_value boolean DEFAULT TRUE
)
	RETURNS double precision
	AS $$ SELECT st_nearestvalue($1, 1, $2, $3) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_nearestvalue(
	rast raster, band integer,
	columnx integer, rowy integer,
	exclude_nodata_value boolean DEFAULT TRUE
)
	RETURNS double precision
	AS $$ SELECT @extschema@.st_nearestvalue($1, $2, @extschema@.st_setsrid(@extschema@.st_makepoint(@extschema@.st_rastertoworldcoordx($1, $3, $4), @extschema@.st_rastertoworldcoordy($1, $3, $4)), @extschema@.st_srid($1)), $5) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_nearestvalue(
	rast raster,
	columnx integer, rowy integer,
	exclude_nodata_value boolean DEFAULT TRUE
)
	RETURNS double precision
	AS $$ SELECT @extschema@.st_nearestvalue($1, 1, @extschema@.st_setsrid(@extschema@.st_makepoint(@extschema@.st_rastertoworldcoordx($1, $2, $3), @extschema@.st_rastertoworldcoordy($1, $2, $3)), @extschema@.st_srid($1)), $4) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _st_neighborhood(
	rast raster, band integer,
	columnx integer, rowy integer,
	distancex integer, distancey integer,
	exclude_nodata_value boolean DEFAULT TRUE
)
	RETURNS double precision[][]
	AS '$libdir/rtpostgis-2.5', 'RASTER_neighborhood'
	LANGUAGE 'c' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_neighborhood(
	rast raster, band integer,
	columnx integer, rowy integer,
	distancex integer, distancey integer,
	exclude_nodata_value boolean DEFAULT TRUE
)
	RETURNS double precision[][]
	AS $$ SELECT @extschema@._ST_neighborhood($1, $2, $3, $4, $5, $6, $7) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_neighborhood(
	rast raster,
	columnx integer, rowy integer,
	distancex integer, distancey integer,
	exclude_nodata_value boolean DEFAULT TRUE
)
	RETURNS double precision[][]
	AS $$ SELECT @extschema@._ST_neighborhood($1, 1, $2, $3, $4, $5, $6) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_neighborhood(
	rast raster, band integer,
	pt geometry,
	distancex integer, distancey integer,
	exclude_nodata_value boolean DEFAULT TRUE
)
	RETURNS double precision[][]
	AS $$
	DECLARE
		wx double precision;
		wy double precision;
		rtn double precision[][];
	BEGIN
		IF (@extschema@.st_geometrytype($3) != 'ST_Point') THEN
			RAISE EXCEPTION 'Attempting to get the neighbor of a pixel with a non-point geometry';
		END IF;

		IF @extschema@.ST_SRID(rast) != @extschema@.ST_SRID(pt) THEN
			RAISE EXCEPTION 'Raster and geometry do not have the same SRID';
		END IF;

		wx := st_x($3);
		wy := st_y($3);

		SELECT @extschema@._ST_neighborhood(
			$1, $2,
			@extschema@.st_worldtorastercoordx(rast, wx, wy),
			@extschema@.st_worldtorastercoordy(rast, wx, wy),
			$4, $5,
			$6
		) INTO rtn;
		RETURN rtn;
	END;
	$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION st_neighborhood(
	rast raster,
	pt geometry,
	distancex integer, distancey integer,
	exclude_nodata_value boolean DEFAULT TRUE
)
	RETURNS double precision[][]
	AS $$ SELECT @extschema@.st_neighborhood($1, 1, $2, $3, $4, $5) $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _add_raster_constraint(cn name, sql text)
	RETURNS boolean AS $$
	BEGIN
		BEGIN
			EXECUTE sql;
		EXCEPTION
			WHEN duplicate_object THEN
				RAISE NOTICE 'The constraint "%" already exists.  To replace the existing constraint, delete the constraint and call ApplyRasterConstraints again', cn;
			WHEN OTHERS THEN
				RAISE NOTICE 'Unable to add constraint: %', cn;
				RAISE NOTICE 'SQL used for failed constraint: %', sql;
				RAISE NOTICE 'Returned error message: % (%)', SQLERRM, SQLSTATE;
				RETURN FALSE;
		END;

		RETURN TRUE;
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _drop_raster_constraint(rastschema name, rasttable name, cn name)
	RETURNS boolean AS $$
	DECLARE
		fqtn text;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		BEGIN
			EXECUTE 'ALTER TABLE '
				|| fqtn
				|| ' DROP CONSTRAINT '
				|| quote_ident(cn);
			RETURN TRUE;
		EXCEPTION
			WHEN undefined_object THEN
				RAISE NOTICE 'The constraint "%" does not exist.  Skipping', cn;
			WHEN OTHERS THEN
				RAISE NOTICE 'Unable to drop constraint "%": % (%)',
          cn, SQLERRM, SQLSTATE;
				RETURN FALSE;
		END;

		RETURN TRUE;
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _raster_constraint_info_srid(rastschema name, rasttable name, rastcolumn name)
	RETURNS integer AS $$
	SELECT
		regexp_replace(
			split_part(s.consrc, ' = ', 2),
			'[\(\)]', '', 'g'
		)::integer
	FROM pg_class c, pg_namespace n, pg_attribute a
		, (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
		    FROM pg_constraint) AS s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%st_srid(% = %';
	$$ LANGUAGE sql STABLE STRICT
  COST 100;
CREATE OR REPLACE FUNCTION _add_raster_constraint_srid(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS $$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr int;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_srid_' || $3;

		sql := 'SELECT @extschema@.st_srid('
			|| quote_ident($3)
			|| ') FROM ' || fqtn
			|| ' WHERE '
			|| quote_ident($3)
			|| ' IS NOT NULL LIMIT 1;';
		BEGIN
			EXECUTE sql INTO attr;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the SRID of a sample raster: % (%)',
        SQLERRM, SQLSTATE;
			RETURN FALSE;
		END;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (@extschema@.st_srid('
			|| quote_ident($3)
			|| ') = ' || attr || ')';

		RETURN  @extschema@._add_raster_constraint(cn, sql);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _drop_raster_constraint_srid(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS
	$$ SELECT  @extschema@._drop_raster_constraint($1, $2, 'enforce_srid_' || $3) $$
	LANGUAGE 'sql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _raster_constraint_info_scale(rastschema name, rasttable name, rastcolumn name, axis char)
	RETURNS double precision AS $$
	WITH c AS (SELECT
		regexp_replace(
			replace(
				split_part(
					split_part(s.consrc, ' = ', 2),
					'::', 1
				),
				'round(', ''
			),
			'[ ''''\(\)]', '', 'g'
		)::text AS val
	FROM pg_class c, pg_namespace n, pg_attribute a
		, (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
			FROM pg_constraint) AS s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%st_scale' || $4 || '(% = %')
-- if it is a comma separated list of two numbers then need to use round
   SELECT CASE WHEN split_part(c.val,',', 2) > ''
        THEN round( split_part(c.val, ',',1)::numeric, split_part(c.val,',',2)::integer )::float8
        ELSE c.val::float8 END
        FROM c;
	$$ LANGUAGE sql STABLE STRICT
  COST 100;
CREATE OR REPLACE FUNCTION _add_raster_constraint_scale(rastschema name, rasttable name, rastcolumn name, axis char)
	RETURNS boolean AS $$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr double precision;
	BEGIN
		IF lower($4) != 'x' AND lower($4) != 'y' THEN
			RAISE EXCEPTION 'axis must be either "x" or "y"';
			RETURN FALSE;
		END IF;

		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_scale' || $4 || '_' || $3;

		sql := 'SELECT @extschema@.st_scale' || $4 || '('
			|| quote_ident($3)
			|| ') FROM '
			|| fqtn
			|| ' WHERE '
			|| quote_ident($3)
			|| ' IS NOT NULL LIMIT 1;';
		BEGIN
			EXECUTE sql INTO attr;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the %-scale of a sample raster: % (%)',
        upper($4), SQLERRM, SQLSTATE;
			RETURN FALSE;
		END;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (round(@extschema@.st_scale' || $4 || '('
			|| quote_ident($3)
			|| ')::numeric, 10) = round(' || text(attr) || '::numeric, 10))';
		RETURN  @extschema@._add_raster_constraint(cn, sql);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _drop_raster_constraint_scale(rastschema name, rasttable name, rastcolumn name, axis char)
	RETURNS boolean AS $$
	BEGIN
		IF lower($4) != 'x' AND lower($4) != 'y' THEN
			RAISE EXCEPTION 'axis must be either "x" or "y"';
			RETURN FALSE;
		END IF;

		RETURN  @extschema@._drop_raster_constraint($1, $2, 'enforce_scale' || $4 || '_' || $3);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _raster_constraint_info_blocksize(rastschema name, rasttable name, rastcolumn name, axis text)
	RETURNS integer AS $$
	SELECT
		CASE
			WHEN strpos(s.consrc, 'ANY (ARRAY[') > 0 THEN
				split_part((substring(s.consrc FROM E'ARRAY\\[(.*?){1}\\]')), ',', 1)::integer
			ELSE
				regexp_replace(
					split_part(s.consrc, '= ', 2),
					'[\(\)]', '', 'g'
				)::integer
			END
	FROM pg_class c, pg_namespace n, pg_attribute a
		, (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
			FROM pg_constraint) AS s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%st_' || $4 || '(%= %';
	$$ LANGUAGE sql STABLE STRICT
  COST 100;
CREATE OR REPLACE FUNCTION _add_raster_constraint_blocksize(rastschema name, rasttable name, rastcolumn name, axis text)
	RETURNS boolean AS $$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attrset integer[];
		attr integer;
	BEGIN
		IF lower($4) != 'width' AND lower($4) != 'height' THEN
			RAISE EXCEPTION 'axis must be either "width" or "height"';
			RETURN FALSE;
		END IF;

		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_' || $4 || '_' || $3;

		sql := 'SELECT st_' || $4 || '('
			|| quote_ident($3)
			|| ') FROM ' || fqtn
			|| ' GROUP BY 1 ORDER BY count(*) DESC';
		BEGIN
			attrset := ARRAY[]::integer[];
			FOR attr IN EXECUTE sql LOOP
				attrset := attrset || attr;
			END LOOP;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the % of a sample raster: % (%)',
        $4, SQLERRM, SQLSTATE;
			RETURN FALSE;
		END;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (st_' || $4 || '('
			|| quote_ident($3)
			|| ') IN (' || array_to_string(attrset, ',') || '))';
		RETURN  @extschema@._add_raster_constraint(cn, sql);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _drop_raster_constraint_blocksize(rastschema name, rasttable name, rastcolumn name, axis text)
	RETURNS boolean AS $$
	BEGIN
		IF lower($4) != 'width' AND lower($4) != 'height' THEN
			RAISE EXCEPTION 'axis must be either "width" or "height"';
			RETURN FALSE;
		END IF;

		RETURN  @extschema@._drop_raster_constraint($1, $2, 'enforce_' || $4 || '_' || $3);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _raster_constraint_info_extent(rastschema name, rasttable name, rastcolumn name)
	RETURNS geometry AS $$
	SELECT
		trim(both '''' from split_part(trim(split_part(s.consrc, ' @ ', 2)), '::', 1))::@extschema@.geometry
	FROM pg_class c, pg_namespace n, pg_attribute a
		, (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
			FROM pg_constraint) AS s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%st_envelope(% @ %';
	$$ LANGUAGE sql STABLE STRICT
  COST 100;
CREATE OR REPLACE FUNCTION _add_raster_constraint_extent(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS $$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr text; srid integer;
	BEGIN
		fqtn := '';
		IF length(rastschema) > 0 THEN
			fqtn := quote_ident(rastschema) || '.';
		END IF;
		fqtn := fqtn || quote_ident(rasttable);

		sql := 'SELECT @extschema@.ST_SRID('
			|| quote_ident(rastcolumn)
			|| ') FROM '
			|| fqtn
			|| ' WHERE '
			|| quote_ident(rastcolumn)
			|| ' IS NOT NULL LIMIT 1;';
                EXECUTE sql INTO srid;

    IF srid IS NULL THEN
      RETURN false;
    END IF;

		cn := 'enforce_max_extent_' || rastcolumn;

		sql := 'SELECT @extschema@.st_ashexewkb( @extschema@.st_setsrid( @extschema@.st_extent( @extschema@.st_envelope('
			|| quote_ident(rastcolumn)
			|| ')), ' || srid || ')) FROM '
			|| fqtn;
		EXECUTE sql INTO attr;

		-- NOTE: I put NOT VALID to prevent the costly step of validating the constraint
		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK ( @extschema@.st_envelope('
			|| quote_ident(rastcolumn)
			|| ') @ ''' || attr || '''::geometry) NOT VALID';
		RETURN  @extschema@._add_raster_constraint(cn, sql);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT
	COST 9000;
CREATE OR REPLACE FUNCTION _drop_raster_constraint_extent(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS
	$$ SELECT  @extschema@._drop_raster_constraint($1, $2, 'enforce_max_extent_' || $3) $$
	LANGUAGE 'sql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _raster_constraint_info_alignment(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS $$
	SELECT
		TRUE
	FROM pg_class c, pg_namespace n, pg_attribute a
		, (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
			FROM pg_constraint) AS s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%st_samealignment(%';
	$$ LANGUAGE sql STABLE STRICT
  COST 100;
CREATE OR REPLACE FUNCTION _add_raster_constraint_alignment(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS $$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr text;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_same_alignment_' || $3;

		sql := 'SELECT @extschema@.st_makeemptyraster(1, 1, upperleftx, upperlefty, scalex, scaley, skewx, skewy, srid) FROM @extschema@.st_metadata((SELECT '
			|| quote_ident($3)
			|| ' FROM '
			|| fqtn
			|| ' WHERE '
			|| quote_ident($3)
			|| ' IS NOT NULL LIMIT 1))';
		BEGIN
			EXECUTE sql INTO attr;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the alignment of a sample raster: % (%)',
        SQLERRM, SQLSTATE;
			RETURN FALSE;
		END;

		sql := 'ALTER TABLE ' || fqtn ||
			' ADD CONSTRAINT ' || quote_ident(cn) ||
			' CHECK (@extschema@.st_samealignment(' || quote_ident($3) || ', ''' || attr || '''::raster))';
		RETURN  @extschema@._add_raster_constraint(cn, sql);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _drop_raster_constraint_alignment(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS
	$$ SELECT  @extschema@._drop_raster_constraint($1, $2, 'enforce_same_alignment_' || $3) $$
	LANGUAGE 'sql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _raster_constraint_info_spatially_unique(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS $$
	SELECT
		TRUE
	FROM pg_class c, pg_namespace n, pg_attribute a
		, (SELECT connamespace, conrelid, conindid, conkey, contype, conexclop, pg_get_constraintdef(oid) As consrc
			FROM pg_constraint) AS s
		, pg_index idx, pg_operator op
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND s.contype = 'x'
		AND 0::smallint = ANY (s.conkey)
		AND idx.indexrelid = s.conindid
		AND pg_get_indexdef(idx.indexrelid, 1, true) LIKE '(' || quote_ident($3) || '::%geometry)'
		AND s.conexclop[1] = op.oid
		AND op.oprname = '=';
	$$ LANGUAGE sql STABLE STRICT
  COST 100;
CREATE OR REPLACE FUNCTION _add_raster_constraint_spatially_unique(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS $$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr text;
		meta record;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_spatially_unique_' || quote_ident($2) || '_'|| $3;

		sql := 'ALTER TABLE ' || fqtn ||
			' ADD CONSTRAINT ' || quote_ident(cn) ||
			' EXCLUDE ((' || quote_ident($3) || '::@extschema@.geometry) WITH =)';
		RETURN  @extschema@._add_raster_constraint(cn, sql);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _drop_raster_constraint_spatially_unique(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS $$
	DECLARE
		cn text;
	BEGIN
		SELECT
			s.conname INTO cn
		FROM pg_class c, pg_namespace n, pg_attribute a
		, (SELECT connamespace, conname, conrelid, conkey, conindid, contype, conexclop, pg_get_constraintdef(oid) As consrc
			FROM pg_constraint) AS s
		, pg_index idx, pg_operator op
		WHERE n.nspname = $1
			AND c.relname = $2
			AND a.attname = $3
			AND a.attrelid = c.oid
			AND s.connamespace = n.oid
			AND s.conrelid = c.oid
			AND s.contype = 'x'
			AND 0::smallint = ANY (s.conkey)
			AND idx.indexrelid = s.conindid
			AND pg_get_indexdef(idx.indexrelid, 1, true) LIKE '(' || quote_ident($3) || '::%geometry)'
			AND s.conexclop[1] = op.oid
			AND op.oprname = '=';

		RETURN  @extschema@._drop_raster_constraint($1, $2, cn);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _raster_constraint_info_coverage_tile(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS $$
	SELECT
		TRUE
	FROM pg_class c, pg_namespace n, pg_attribute a
			, (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
			FROM pg_constraint) AS s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%st_iscoveragetile(%';
	$$ LANGUAGE sql STABLE STRICT
  COST 100;
CREATE OR REPLACE FUNCTION _add_raster_constraint_coverage_tile(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS $$
	DECLARE
		fqtn text;
		cn name;
		sql text;

		_scalex double precision;
		_scaley double precision;
		_skewx double precision;
		_skewy double precision;
		_tilewidth integer;
		_tileheight integer;
		_alignment boolean;

		_covextent @extschema@.geometry;
		_covrast @extschema@.raster;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_coverage_tile_' || quote_ident($3);

		-- metadata
		BEGIN
			sql := 'WITH foo AS (SELECT @extschema@.ST_Metadata(' || quote_ident($3) || ') AS meta, @extschema@.ST_ConvexHull(' || quote_ident($3) || ') AS hull FROM ' || fqtn || ') SELECT max((meta).scalex), max((meta).scaley), max((meta).skewx), max((meta).skewy), max((meta).width), max((meta).height), @extschema@.ST_Union(hull) FROM foo';
			EXECUTE sql INTO _scalex, _scaley, _skewx, _skewy, _tilewidth, _tileheight, _covextent;
		EXCEPTION WHEN OTHERS THEN
			RAISE DEBUG 'Unable to get coverage metadata for %.%: % (%)',
        fqtn, quote_ident($3), SQLERRM, SQLSTATE;
      -- TODO: Why not return false here ?
		END;

		-- rasterize extent
		BEGIN
			_covrast := @extschema@.ST_AsRaster(_covextent, _scalex, _scaley, '8BUI', 1, 0, NULL, NULL, _skewx, _skewy);
			IF _covrast IS NULL THEN
				RAISE NOTICE 'Unable to create coverage raster. Cannot add coverage tile constraint: % (%)',
          SQLERRM, SQLSTATE;
				RETURN FALSE;
			END IF;

			-- remove band
			_covrast := @extschema@.ST_MakeEmptyRaster(_covrast);
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to create coverage raster. Cannot add coverage tile constraint: % (%)',
        SQLERRM, SQLSTATE;
			RETURN FALSE;
		END;

		sql := 'ALTER TABLE ' || fqtn ||
			' ADD CONSTRAINT ' || quote_ident(cn) ||
			' CHECK (st_iscoveragetile(' || quote_ident($3) || ', ''' || _covrast || '''::raster, ' || _tilewidth || ', ' || _tileheight || '))';
		RETURN  @extschema@._add_raster_constraint(cn, sql);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _drop_raster_constraint_coverage_tile(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS
	$$ SELECT  @extschema@._drop_raster_constraint($1, $2, 'enforce_coverage_tile_' || $3) $$
	LANGUAGE 'sql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _raster_constraint_info_regular_blocking(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean
	AS $$
	DECLARE
		covtile boolean;
		spunique boolean;
	BEGIN
		-- check existance of constraints
		-- coverage tile constraint
		covtile := COALESCE( @extschema@._raster_constraint_info_coverage_tile($1, $2, $3), FALSE);

		-- spatially unique constraint
		spunique := COALESCE( @extschema@._raster_constraint_info_spatially_unique($1, $2, $3), FALSE);

		RETURN (covtile AND spunique);
	END;
	$$ LANGUAGE 'plpgsql' STABLE STRICT
  COST 100;
CREATE OR REPLACE FUNCTION _drop_raster_constraint_regular_blocking(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS
	$$ SELECT @extschema@._drop_raster_constraint($1, $2, 'enforce_regular_blocking_' || $3) $$
	LANGUAGE 'sql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _raster_constraint_info_num_bands(rastschema name, rasttable name, rastcolumn name)
	RETURNS integer AS $$
	SELECT
		regexp_replace(
			split_part(s.consrc, ' = ', 2),
			'[\(\)]', '', 'g'
		)::integer
	FROM pg_class c, pg_namespace n, pg_attribute a
		, (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
			FROM pg_constraint) AS s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%st_numbands(%';
	$$ LANGUAGE sql STABLE STRICT
  COST 100;
CREATE OR REPLACE FUNCTION _add_raster_constraint_num_bands(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS $$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr int;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_num_bands_' || $3;

		sql := 'SELECT @extschema@.st_numbands(' || quote_ident($3)
			|| ') FROM '
			|| fqtn
			|| ' WHERE '
			|| quote_ident($3)
			|| ' IS NOT NULL LIMIT 1;';
		BEGIN
			EXECUTE sql INTO attr;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the number of bands of a sample raster: % (%)',
        SQLERRM, SQLSTATE;
			RETURN FALSE;
		END;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (@extschema@.st_numbands(' || quote_ident($3)
			|| ') = ' || attr
			|| ')';
		RETURN  @extschema@._add_raster_constraint(cn, sql);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _drop_raster_constraint_num_bands(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS
	$$ SELECT  @extschema@._drop_raster_constraint($1, $2, 'enforce_num_bands_' || $3) $$
	LANGUAGE 'sql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _raster_constraint_info_pixel_types(rastschema name, rasttable name, rastcolumn name)
	RETURNS text[] AS $$
	SELECT
		trim(
			both ' ''' from split_part(
				regexp_replace(
					split_part(s.consrc, '=', 2),
					'[\(\)]', '', 'g'
				),
				'::', 1
			)
		)::text[]
	FROM pg_class c, pg_namespace n, pg_attribute a
		, (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
			FROM pg_constraint) AS s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%_raster_constraint_pixel_types(%';
	$$ LANGUAGE sql STABLE STRICT
  COST 100;
CREATE OR REPLACE FUNCTION _raster_constraint_pixel_types(rast raster)
	RETURNS text[] AS
	$$ SELECT array_agg(pixeltype)::text[] FROM  @extschema@.ST_BandMetaData($1, ARRAY[]::int[]); $$
	LANGUAGE 'sql' STABLE STRICT;
CREATE OR REPLACE FUNCTION _add_raster_constraint_pixel_types(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS $$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr text[];
		max int;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_pixel_types_' || $3;

		sql := 'SELECT @extschema@._raster_constraint_pixel_types(' || quote_ident($3)
			|| ') FROM ' || fqtn
			|| ' WHERE '
			|| quote_ident($3)
			|| ' IS NOT NULL LIMIT 1;';
		BEGIN
			EXECUTE sql INTO attr;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the pixel types of a sample raster: % (%)',
        SQLERRM, SQLSTATE;
			RETURN FALSE;
		END;
		max := array_length(attr, 1);
		IF max < 1 OR max IS NULL THEN
			RAISE NOTICE 'Unable to get the pixel types of a sample raster (max < 1 or null)';
			RETURN FALSE;
		END IF;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (@extschema@._raster_constraint_pixel_types(' || quote_ident($3)
			|| ') = ''{';
		FOR x in 1..max LOOP
			sql := sql || '"' || attr[x] || '"';
			IF x < max THEN
				sql := sql || ',';
			END IF;
		END LOOP;
		sql := sql || '}''::text[])';

		RETURN  @extschema@._add_raster_constraint(cn, sql);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION _drop_raster_constraint_pixel_types(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS
	$$ SELECT  @extschema@._drop_raster_constraint($1, $2, 'enforce_pixel_types_' || $3) $$
	LANGUAGE 'sql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION _raster_constraint_info_nodata_values(rastschema name, rasttable name, rastcolumn name)
	RETURNS double precision[] AS $$
	SELECT
		trim(both ' ''' from
			split_part(
				regexp_replace(
					split_part(s.consrc, '=', 2),
					'[\(\)]', '', 'g'
				),
				'::', 1
			)
		)::double precision[]
	FROM pg_class c, pg_namespace n, pg_attribute a
		, (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
			FROM pg_constraint) AS s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%_raster_constraint_nodata_values(%';
	$$ LANGUAGE sql STABLE STRICT;
CREATE OR REPLACE FUNCTION _raster_constraint_nodata_values(rast raster)
	RETURNS numeric[] AS
	$$ SELECT array_agg(round(nodatavalue::numeric, 10))::numeric[] FROM @extschema@.ST_BandMetaData($1, ARRAY[]::int[]); $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _add_raster_constraint_nodata_values(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS $$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr numeric[];
		max int;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_nodata_values_' || $3;

		sql := 'SELECT @extschema@._raster_constraint_nodata_values(' || quote_ident($3)
			|| ') FROM ' || fqtn
			|| ' WHERE '
			|| quote_ident($3)
			|| ' IS NOT NULL LIMIT 1;';
		BEGIN
			EXECUTE sql INTO attr;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the nodata values of a sample raster: % (%)',
        SQLERRM, SQLSTATE;
			RETURN FALSE;
		END;
		max := array_length(attr, 1);
		IF max < 1 OR max IS NULL THEN
			RAISE NOTICE 'Unable to get the nodata values of a sample raster (max < 1 or null)';
			RETURN FALSE;
		END IF;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK (_raster_constraint_nodata_values(' || quote_ident($3)
			|| ')::numeric[] = ''{';
		FOR x in 1..max LOOP
			IF attr[x] IS NULL THEN
				sql := sql || 'NULL';
			ELSE
				sql := sql || attr[x];
			END IF;
			IF x < max THEN
				sql := sql || ',';
			END IF;
		END LOOP;
		sql := sql || '}''::numeric[])';

		RETURN  @extschema@._add_raster_constraint(cn, sql);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION _drop_raster_constraint_nodata_values(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS
	$$ SELECT  @extschema@._drop_raster_constraint($1, $2, 'enforce_nodata_values_' || $3) $$
	LANGUAGE 'sql' VOLATILE STRICT
	COST 100;
CREATE OR REPLACE FUNCTION _raster_constraint_info_out_db(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean[] AS $$
--
-- Greenplum will replace operator '=' as 'OPERATOR(pg_catalog.=)', hence original method will fail.
--
	SELECT
		trim(
			both ' ''' from split_part(
				regexp_replace(
					split_part(s.consrc, '=', 2),
					'[\(\)]', '', 'g'
				),
				'::', 1
			)
		)::boolean[]
	FROM pg_class c, pg_namespace n, pg_attribute a
			, (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
			FROM pg_constraint) AS s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%_raster_constraint_out_db(%';
	$$ LANGUAGE sql STABLE STRICT;
CREATE OR REPLACE FUNCTION _raster_constraint_out_db(rast raster)
	RETURNS boolean[] AS
	$$ SELECT array_agg(isoutdb)::boolean[] FROM @extschema@.ST_BandMetaData($1, ARRAY[]::int[]); $$
	LANGUAGE 'sql' IMMUTABLE STRICT PARALLEL SAFE;
CREATE OR REPLACE FUNCTION _add_raster_constraint_out_db(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS $$
	DECLARE
		fqtn text;
		cn name;
		sql text;
		attr boolean[];
		max int;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_out_db_' || $3;

		sql := 'SELECT @extschema@._raster_constraint_out_db(' || quote_ident($3)
			|| ') FROM ' || fqtn
			|| ' WHERE '
			|| quote_ident($3)
			|| ' IS NOT NULL LIMIT 1;';
		BEGIN
			EXECUTE sql INTO attr;
		EXCEPTION WHEN OTHERS THEN
			RAISE NOTICE 'Unable to get the out-of-database bands of a sample raster: % (%)',
        SQLERRM, SQLSTATE;
			RETURN FALSE;
		END;
		max := array_length(attr, 1);
		IF max < 1 OR max IS NULL THEN
			RAISE NOTICE 'Unable to get the out-of-database bands of a sample raster (max < 1 or null)';
			RETURN FALSE;
		END IF;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK ( @extschema@._raster_constraint_out_db(' || quote_ident($3)
			|| ') = ''{';
		FOR x in 1..max LOOP
			IF attr[x] IS FALSE THEN
				sql := sql || 'FALSE';
			ELSE
				sql := sql || 'TRUE';
			END IF;
			IF x < max THEN
				sql := sql || ',';
			END IF;
		END LOOP;
		sql := sql || '}''::boolean[])';

		RETURN  @extschema@._add_raster_constraint(cn, sql);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION _drop_raster_constraint_out_db(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS
	$$ SELECT  @extschema@._drop_raster_constraint($1, $2, 'enforce_out_db_' || $3) $$
	LANGUAGE 'sql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION _raster_constraint_info_index(rastschema name, rasttable name, rastcolumn name)
	RETURNS boolean AS $$
		SELECT
			TRUE
		FROM pg_catalog.pg_class c
		JOIN pg_catalog.pg_index i
			ON i.indexrelid = c.oid
		JOIN pg_catalog.pg_class c2
			ON i.indrelid = c2.oid
		JOIN pg_catalog.pg_namespace n
			ON n.oid = c.relnamespace
		JOIN pg_am am
			ON c.relam = am.oid
		JOIN pg_attribute att
			ON att.attrelid = c2.oid
				AND pg_catalog.format_type(att.atttypid, att.atttypmod) = 'raster'
		WHERE c.relkind IN ('i')
			AND n.nspname = $1
			AND c2.relname = $2
			AND att.attname = $3
			AND am.amname = 'gist'
			AND strpos(pg_catalog.pg_get_expr(i.indexprs, i.indrelid), att.attname) > 0;
	$$ LANGUAGE sql STABLE STRICT;
CREATE OR REPLACE FUNCTION AddRasterConstraints (
	rastschema name,
	rasttable name,
	rastcolumn name,
	VARIADIC constraints text[]
)
	RETURNS boolean
	AS $$
	DECLARE
		max int;
		cnt int;
		sql text;
		schema name;
		x int;
		kw text;
		rtn boolean;
	BEGIN
		cnt := 0;
		max := array_length(constraints, 1);
		IF max < 1 THEN
			RAISE NOTICE 'No constraints indicated to be added.  Doing nothing';
			RETURN TRUE;
		END IF;

		-- validate schema
		schema := NULL;
		IF length($1) > 0 THEN
			sql := 'SELECT nspname FROM pg_namespace '
				|| 'WHERE nspname = ' || quote_literal($1)
				|| 'LIMIT 1';
			EXECUTE sql INTO schema;

			IF schema IS NULL THEN
				RAISE EXCEPTION 'The value provided for schema is invalid';
				RETURN FALSE;
			END IF;
		END IF;

		IF schema IS NULL THEN
			sql := 'SELECT n.nspname AS schemaname '
				|| 'FROM pg_catalog.pg_class c '
				|| 'JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace '
				|| 'WHERE c.relkind = ' || quote_literal('r')
				|| ' AND n.nspname NOT IN (' || quote_literal('pg_catalog')
				|| ', ' || quote_literal('pg_toast')
				|| ') AND pg_catalog.pg_table_is_visible(c.oid)'
				|| ' AND c.relname = ' || quote_literal($2);
			EXECUTE sql INTO schema;

			IF schema IS NULL THEN
				RAISE EXCEPTION 'The table % does not occur in the search_path', quote_literal($2);
				RETURN FALSE;
			END IF;
		END IF;

		<<kwloop>>
		FOR x in 1..max LOOP
			kw := trim(both from lower(constraints[x]));

			BEGIN
				CASE
					WHEN kw = 'srid' THEN
						RAISE NOTICE 'Adding SRID constraint';
						rtn :=  @extschema@._add_raster_constraint_srid(schema, $2, $3);
					WHEN kw IN ('scale_x', 'scalex') THEN
						RAISE NOTICE 'Adding scale-X constraint';
						rtn :=  @extschema@._add_raster_constraint_scale(schema, $2, $3, 'x');
					WHEN kw IN ('scale_y', 'scaley') THEN
						RAISE NOTICE 'Adding scale-Y constraint';
						rtn :=  @extschema@._add_raster_constraint_scale(schema, $2, $3, 'y');
					WHEN kw = 'scale' THEN
						RAISE NOTICE 'Adding scale-X constraint';
						rtn :=  @extschema@._add_raster_constraint_scale(schema, $2, $3, 'x');
						RAISE NOTICE 'Adding scale-Y constraint';
						rtn :=  @extschema@._add_raster_constraint_scale(schema, $2, $3, 'y');
					WHEN kw IN ('blocksize_x', 'blocksizex', 'width') THEN
						RAISE NOTICE 'Adding blocksize-X constraint';
						rtn :=  @extschema@._add_raster_constraint_blocksize(schema, $2, $3, 'width');
					WHEN kw IN ('blocksize_y', 'blocksizey', 'height') THEN
						RAISE NOTICE 'Adding blocksize-Y constraint';
						rtn :=  @extschema@._add_raster_constraint_blocksize(schema, $2, $3, 'height');
					WHEN kw = 'blocksize' THEN
						RAISE NOTICE 'Adding blocksize-X constraint';
						rtn :=  @extschema@._add_raster_constraint_blocksize(schema, $2, $3, 'width');
						RAISE NOTICE 'Adding blocksize-Y constraint';
						rtn :=  @extschema@._add_raster_constraint_blocksize(schema, $2, $3, 'height');
					WHEN kw IN ('same_alignment', 'samealignment', 'alignment') THEN
						RAISE NOTICE 'Adding alignment constraint';
						rtn :=  @extschema@._add_raster_constraint_alignment(schema, $2, $3);
					WHEN kw IN ('regular_blocking', 'regularblocking') THEN
                        -- Greenplum doesn't support EXCLUSION CONSTRAINT (exclude)
                        --  so spatially unique is not supportted up to now, 28 Jan 2015
                        RAISE EXCEPTION 'Unable to add constraint: %, because Greenplum does not support exclusion constraint (EXCLUDE), so spatially unique constraints will be ignored. Skipping', quote_literal(constraints[x]);
                        rtn := FLASE;
					WHEN kw IN ('num_bands', 'numbands') THEN
						RAISE NOTICE 'Adding number of bands constraint';
						rtn :=  @extschema@._add_raster_constraint_num_bands(schema, $2, $3);
					WHEN kw IN ('pixel_types', 'pixeltypes') THEN
						RAISE NOTICE 'Adding pixel type constraint';
						rtn :=  @extschema@._add_raster_constraint_pixel_types(schema, $2, $3);
					WHEN kw IN ('nodata_values', 'nodatavalues', 'nodata') THEN
						RAISE NOTICE 'Adding nodata value constraint';
						rtn :=  @extschema@._add_raster_constraint_nodata_values(schema, $2, $3);
					WHEN kw IN ('out_db', 'outdb') THEN
						RAISE NOTICE 'Adding out-of-database constraint';
						rtn :=  @extschema@._add_raster_constraint_out_db(schema, $2, $3);
					WHEN kw = 'extent' THEN
						RAISE NOTICE 'Adding maximum extent constraint';
						rtn :=  @extschema@._add_raster_constraint_extent(schema, $2, $3);
					ELSE
						RAISE NOTICE 'Unknown constraint: %.  Skipping', quote_literal(constraints[x]);
						CONTINUE kwloop;
				END CASE;
			END;

			IF rtn IS FALSE THEN
				cnt := cnt + 1;
				RAISE WARNING 'Unable to add constraint: %.  Skipping', quote_literal(constraints[x]);
			END IF;

		END LOOP kwloop;

		IF cnt = max THEN
			RAISE EXCEPTION 'None of the constraints specified could be added.  Is the schema name, table name or column name incorrect?';
			RETURN FALSE;
		END IF;

		RETURN TRUE;
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION AddRasterConstraints (
	rasttable name,
	rastcolumn name,
	VARIADIC constraints text[]
)
	RETURNS boolean AS
	$$ SELECT @extschema@.AddRasterConstraints('', $1, $2, VARIADIC $3) $$
	LANGUAGE 'sql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION AddRasterConstraints (
	rastschema name,
	rasttable name,
	rastcolumn name,
	srid boolean DEFAULT TRUE,
	scale_x boolean DEFAULT TRUE,
	scale_y boolean DEFAULT TRUE,
	blocksize_x boolean DEFAULT TRUE,
	blocksize_y boolean DEFAULT TRUE,
	same_alignment boolean DEFAULT TRUE,
	regular_blocking boolean DEFAULT FALSE, -- false as regular_blocking is an enhancement
	num_bands boolean DEFAULT TRUE,
	pixel_types boolean DEFAULT TRUE,
	nodata_values boolean DEFAULT TRUE,
	out_db boolean DEFAULT TRUE,
	extent boolean DEFAULT TRUE
)
	RETURNS boolean
	AS $$
	DECLARE
		constraints text[];
	BEGIN
		IF srid IS TRUE THEN
			constraints := constraints || 'srid'::text;
		END IF;

		IF scale_x IS TRUE THEN
			constraints := constraints || 'scale_x'::text;
		END IF;

		IF scale_y IS TRUE THEN
			constraints := constraints || 'scale_y'::text;
		END IF;

		IF blocksize_x IS TRUE THEN
			constraints := constraints || 'blocksize_x'::text;
		END IF;

		IF blocksize_y IS TRUE THEN
			constraints := constraints || 'blocksize_y'::text;
		END IF;

		IF same_alignment IS TRUE THEN
			constraints := constraints || 'same_alignment'::text;
		END IF;

		IF regular_blocking IS TRUE THEN
			constraints := constraints || 'regular_blocking'::text;
		END IF;

		IF num_bands IS TRUE THEN
			constraints := constraints || 'num_bands'::text;
		END IF;

		IF pixel_types IS TRUE THEN
			constraints := constraints || 'pixel_types'::text;
		END IF;

		IF nodata_values IS TRUE THEN
			constraints := constraints || 'nodata_values'::text;
		END IF;

		IF out_db IS TRUE THEN
			constraints := constraints || 'out_db'::text;
		END IF;

		IF extent IS TRUE THEN
			constraints := constraints || 'extent'::text;
		END IF;

		RETURN @extschema@.AddRasterConstraints($1, $2, $3, VARIADIC constraints);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION AddRasterConstraints (
	rasttable name,
	rastcolumn name,
	srid boolean DEFAULT TRUE,
	scale_x boolean DEFAULT TRUE,
	scale_y boolean DEFAULT TRUE,
	blocksize_x boolean DEFAULT TRUE,
	blocksize_y boolean DEFAULT TRUE,
	same_alignment boolean DEFAULT TRUE,
	regular_blocking boolean DEFAULT FALSE, -- false as regular_blocking is an enhancement
	num_bands boolean DEFAULT TRUE,
	pixel_types boolean DEFAULT TRUE,
	nodata_values boolean DEFAULT TRUE,
	out_db boolean DEFAULT TRUE,
	extent boolean DEFAULT TRUE
)
	RETURNS boolean AS
	$$ SELECT @extschema@.AddRasterConstraints('', $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14) $$
	LANGUAGE 'sql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION DropRasterConstraints (
	rastschema name,
	rasttable name,
	rastcolumn name,
	VARIADIC constraints text[]
)
	RETURNS boolean
	AS $$
	DECLARE
		max int;
		x int;
		schema name;
		sql text;
		kw text;
		rtn boolean;
		cnt int;
	BEGIN
		cnt := 0;
		max := array_length(constraints, 1);
		IF max < 1 THEN
			RAISE NOTICE 'No constraints indicated to be dropped.  Doing nothing';
			RETURN TRUE;
		END IF;

		-- validate schema
		schema := NULL;
		IF length($1) > 0 THEN
			sql := 'SELECT nspname FROM pg_namespace '
				|| 'WHERE nspname = ' || quote_literal($1)
				|| 'LIMIT 1';
			EXECUTE sql INTO schema;

			IF schema IS NULL THEN
				RAISE EXCEPTION 'The value provided for schema is invalid';
				RETURN FALSE;
			END IF;
		END IF;

		IF schema IS NULL THEN
			sql := 'SELECT n.nspname AS schemaname '
				|| 'FROM pg_catalog.pg_class c '
				|| 'JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace '
				|| 'WHERE c.relkind = ' || quote_literal('r')
				|| ' AND n.nspname NOT IN (' || quote_literal('pg_catalog')
				|| ', ' || quote_literal('pg_toast')
				|| ') AND pg_catalog.pg_table_is_visible(c.oid)'
				|| ' AND c.relname = ' || quote_literal($2);
			EXECUTE sql INTO schema;

			IF schema IS NULL THEN
				RAISE EXCEPTION 'The table % does not occur in the search_path', quote_literal($2);
				RETURN FALSE;
			END IF;
		END IF;

		<<kwloop>>
		FOR x in 1..max LOOP
			kw := trim(both from lower(constraints[x]));

			BEGIN
				CASE
					WHEN kw = 'srid' THEN
						RAISE NOTICE 'Dropping SRID constraint';
						rtn :=  @extschema@._drop_raster_constraint_srid(schema, $2, $3);
					WHEN kw IN ('scale_x', 'scalex') THEN
						RAISE NOTICE 'Dropping scale-X constraint';
						rtn :=  @extschema@._drop_raster_constraint_scale(schema, $2, $3, 'x');
					WHEN kw IN ('scale_y', 'scaley') THEN
						RAISE NOTICE 'Dropping scale-Y constraint';
						rtn :=  @extschema@._drop_raster_constraint_scale(schema, $2, $3, 'y');
					WHEN kw = 'scale' THEN
						RAISE NOTICE 'Dropping scale-X constraint';
						rtn :=  @extschema@._drop_raster_constraint_scale(schema, $2, $3, 'x');
						RAISE NOTICE 'Dropping scale-Y constraint';
						rtn :=  @extschema@._drop_raster_constraint_scale(schema, $2, $3, 'y');
					WHEN kw IN ('blocksize_x', 'blocksizex', 'width') THEN
						RAISE NOTICE 'Dropping blocksize-X constraint';
						rtn :=  @extschema@._drop_raster_constraint_blocksize(schema, $2, $3, 'width');
					WHEN kw IN ('blocksize_y', 'blocksizey', 'height') THEN
						RAISE NOTICE 'Dropping blocksize-Y constraint';
						rtn :=  @extschema@._drop_raster_constraint_blocksize(schema, $2, $3, 'height');
					WHEN kw = 'blocksize' THEN
						RAISE NOTICE 'Dropping blocksize-X constraint';
						rtn :=  @extschema@._drop_raster_constraint_blocksize(schema, $2, $3, 'width');
						RAISE NOTICE 'Dropping blocksize-Y constraint';
						rtn :=  @extschema@._drop_raster_constraint_blocksize(schema, $2, $3, 'height');
					WHEN kw IN ('same_alignment', 'samealignment', 'alignment') THEN
						RAISE NOTICE 'Dropping alignment constraint';
						rtn :=  @extschema@._drop_raster_constraint_alignment(schema, $2, $3);
					WHEN kw IN ('regular_blocking', 'regularblocking') THEN
						rtn :=  @extschema@._drop_raster_constraint_regular_blocking(schema, $2, $3);

						RAISE NOTICE 'Dropping coverage tile constraint required for regular blocking';
						rtn :=  @extschema@._drop_raster_constraint_coverage_tile(schema, $2, $3);

						IF rtn IS NOT FALSE THEN
							RAISE NOTICE 'Dropping spatially unique constraint required for regular blocking';
							rtn :=  @extschema@._drop_raster_constraint_spatially_unique(schema, $2, $3);
						END IF;
					WHEN kw IN ('num_bands', 'numbands') THEN
						RAISE NOTICE 'Dropping number of bands constraint';
						rtn :=  @extschema@._drop_raster_constraint_num_bands(schema, $2, $3);
					WHEN kw IN ('pixel_types', 'pixeltypes') THEN
						RAISE NOTICE 'Dropping pixel type constraint';
						rtn :=  @extschema@._drop_raster_constraint_pixel_types(schema, $2, $3);
					WHEN kw IN ('nodata_values', 'nodatavalues', 'nodata') THEN
						RAISE NOTICE 'Dropping nodata value constraint';
						rtn :=  @extschema@._drop_raster_constraint_nodata_values(schema, $2, $3);
					WHEN kw IN ('out_db', 'outdb') THEN
						RAISE NOTICE 'Dropping out-of-database constraint';
						rtn :=  @extschema@._drop_raster_constraint_out_db(schema, $2, $3);
					WHEN kw = 'extent' THEN
						RAISE NOTICE 'Dropping maximum extent constraint';
						rtn :=  @extschema@._drop_raster_constraint_extent(schema, $2, $3);
					ELSE
						RAISE NOTICE 'Unknown constraint: %.  Skipping', quote_literal(constraints[x]);
						CONTINUE kwloop;
				END CASE;
			END;

			IF rtn IS FALSE THEN
				cnt := cnt + 1;
				RAISE WARNING 'Unable to drop constraint: %.  Skipping', quote_literal(constraints[x]);
			END IF;

		END LOOP kwloop;

		IF cnt = max THEN
			RAISE EXCEPTION 'None of the constraints specified could be dropped.  Is the schema name, table name or column name incorrect?';
			RETURN FALSE;
		END IF;

		RETURN TRUE;
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION DropRasterConstraints (
	rasttable name,
	rastcolumn name,
	VARIADIC constraints text[]
)
	RETURNS boolean AS
	$$ SELECT  @extschema@.DropRasterConstraints('', $1, $2, VARIADIC $3) $$
	LANGUAGE 'sql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION DropRasterConstraints (
	rastschema name,
	rasttable name,
	rastcolumn name,
	srid boolean DEFAULT TRUE,
	scale_x boolean DEFAULT TRUE,
	scale_y boolean DEFAULT TRUE,
	blocksize_x boolean DEFAULT TRUE,
	blocksize_y boolean DEFAULT TRUE,
	same_alignment boolean DEFAULT TRUE,
	regular_blocking boolean DEFAULT TRUE,
	num_bands boolean DEFAULT TRUE,
	pixel_types boolean DEFAULT TRUE,
	nodata_values boolean DEFAULT TRUE,
	out_db boolean DEFAULT TRUE,
	extent boolean DEFAULT TRUE
)
	RETURNS boolean
	AS $$
	DECLARE
		constraints text[];
	BEGIN
		IF srid IS TRUE THEN
			constraints := constraints || 'srid'::text;
		END IF;

		IF scale_x IS TRUE THEN
			constraints := constraints || 'scale_x'::text;
		END IF;

		IF scale_y IS TRUE THEN
			constraints := constraints || 'scale_y'::text;
		END IF;

		IF blocksize_x IS TRUE THEN
			constraints := constraints || 'blocksize_x'::text;
		END IF;

		IF blocksize_y IS TRUE THEN
			constraints := constraints || 'blocksize_y'::text;
		END IF;

		IF same_alignment IS TRUE THEN
			constraints := constraints || 'same_alignment'::text;
		END IF;

		IF regular_blocking IS TRUE THEN
			constraints := constraints || 'regular_blocking'::text;
		END IF;

		IF num_bands IS TRUE THEN
			constraints := constraints || 'num_bands'::text;
		END IF;

		IF pixel_types IS TRUE THEN
			constraints := constraints || 'pixel_types'::text;
		END IF;

		IF nodata_values IS TRUE THEN
			constraints := constraints || 'nodata_values'::text;
		END IF;

		IF out_db IS TRUE THEN
			constraints := constraints || 'out_db'::text;
		END IF;

		IF extent IS TRUE THEN
			constraints := constraints || 'extent'::text;
		END IF;

		RETURN DropRasterConstraints($1, $2, $3, VARIADIC constraints);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION DropRasterConstraints (
	rasttable name,
	rastcolumn name,
	srid boolean DEFAULT TRUE,
	scale_x boolean DEFAULT TRUE,
	scale_y boolean DEFAULT TRUE,
	blocksize_x boolean DEFAULT TRUE,
	blocksize_y boolean DEFAULT TRUE,
	same_alignment boolean DEFAULT TRUE,
	regular_blocking boolean DEFAULT TRUE,
	num_bands boolean DEFAULT TRUE,
	pixel_types boolean DEFAULT TRUE,
	nodata_values boolean DEFAULT TRUE,
	out_db boolean DEFAULT TRUE,
	extent boolean DEFAULT TRUE
)
	RETURNS boolean AS
	$$ SELECT DropRasterConstraints('', $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14) $$
	LANGUAGE 'sql' VOLATILE STRICT;
CREATE OR REPLACE VIEW raster_columns AS
	SELECT
		current_database() AS r_table_catalog,
		n.nspname AS r_table_schema,
		c.relname AS r_table_name,
		a.attname AS r_raster_column,
		COALESCE(_raster_constraint_info_srid(n.nspname, c.relname, a.attname), (SELECT ST_SRID('POINT(0 0)'::@extschema@.geometry))) AS srid,
		_raster_constraint_info_scale(n.nspname, c.relname, a.attname, 'x') AS scale_x,
		_raster_constraint_info_scale(n.nspname, c.relname, a.attname, 'y') AS scale_y,
		_raster_constraint_info_blocksize(n.nspname, c.relname, a.attname, 'width') AS blocksize_x,
		_raster_constraint_info_blocksize(n.nspname, c.relname, a.attname, 'height') AS blocksize_y,
		COALESCE(_raster_constraint_info_alignment(n.nspname, c.relname, a.attname), FALSE) AS same_alignment,
		COALESCE(_raster_constraint_info_regular_blocking(n.nspname, c.relname, a.attname), FALSE) AS regular_blocking,
		_raster_constraint_info_num_bands(n.nspname, c.relname, a.attname) AS num_bands,
		_raster_constraint_info_pixel_types(n.nspname, c.relname, a.attname) AS pixel_types,
		_raster_constraint_info_nodata_values(n.nspname, c.relname, a.attname) AS nodata_values,
		_raster_constraint_info_out_db(n.nspname, c.relname, a.attname) AS out_db,
		_raster_constraint_info_extent(n.nspname, c.relname, a.attname) AS extent,
		COALESCE(_raster_constraint_info_index(n.nspname, c.relname, a.attname), FALSE) AS spatial_index
	FROM
		pg_class c,
		pg_attribute a,
		pg_type t,
		pg_namespace n
	WHERE t.typname = 'raster'::name
		AND a.attisdropped = false
		AND a.atttypid = t.oid
		AND a.attrelid = c.oid
		AND c.relnamespace = n.oid
		AND c.relkind = ANY (ARRAY['r'::"char", 'v'::"char", 'm'::"char", 'f'::"char", 'p'::"char"] )
		AND NOT pg_is_other_temp_schema(c.relnamespace)  AND has_table_privilege(c.oid, 'SELECT'::text);
CREATE OR REPLACE FUNCTION _overview_constraint(ov raster, factor integer, refschema name, reftable name, refcolumn name)
	RETURNS boolean AS
	$$ SELECT COALESCE((SELECT TRUE FROM @extschema@.raster_columns WHERE r_table_catalog = current_database() AND r_table_schema = $3 AND r_table_name = $4 AND r_raster_column = $5), FALSE) $$
	LANGUAGE 'sql' STABLE
	COST 100;
CREATE OR REPLACE FUNCTION _overview_constraint(ov raster, factor integer, refschema name, reftable name, refcolumn name)
    RETURNS boolean AS
    $$
    SELECT COALESCE((
    SELECT TRUE
    FROM
        pg_class c,
        pg_attribute a,
        pg_type t,
        pg_namespace n
    WHERE t.typname = 'raster'::name
        AND n.nspname = $3
        AND c.relname = $4
        AND a.attname = $5
        AND a.attisdropped = false
        AND a.atttypid = t.oid
        AND a.attrelid = c.oid
        AND c.relnamespace = n.oid
        AND c.relkind = ANY(ARRAY['r'::char, 'v'::char, 'm'::char, 'f'::char])
        AND NOT pg_is_other_temp_schema(c.relnamespace)
    ), FALSE)
    $$ LANGUAGE 'sql' STABLE
    COST 100;
CREATE OR REPLACE FUNCTION _overview_constraint_info(
	ovschema name, ovtable name, ovcolumn name,
	OUT refschema name, OUT reftable name, OUT refcolumn name, OUT factor integer
)
	AS $$
	SELECT
		split_part(split_part(s.consrc, '''::name', 1), '''', 2)::name,
		split_part(split_part(s.consrc, '''::name', 2), '''', 2)::name,
		split_part(split_part(s.consrc, '''::name', 3), '''', 2)::name,
		trim(both from split_part(s.consrc, ',', 2))::integer
	FROM pg_class c, pg_namespace n, pg_attribute a
		, (SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
			FROM pg_constraint) AS s
	WHERE n.nspname = $1
		AND c.relname = $2
		AND a.attname = $3
		AND a.attrelid = c.oid
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND a.attnum = ANY (s.conkey)
		AND s.consrc LIKE '%_overview_constraint(%'
	$$ LANGUAGE sql STABLE STRICT
  COST 100;
CREATE OR REPLACE FUNCTION _add_overview_constraint(
	ovschema name, ovtable name, ovcolumn name,
	refschema name, reftable name, refcolumn name,
	factor integer
)
	RETURNS boolean AS $$
	DECLARE
		fqtn text;
		cn name;
		sql text;
	BEGIN
		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		cn := 'enforce_overview_' || $3;

		sql := 'ALTER TABLE ' || fqtn
			|| ' ADD CONSTRAINT ' || quote_ident(cn)
			|| ' CHECK ( @extschema@._overview_constraint(' || quote_ident($3)
			|| ',' || $7
			|| ',' || quote_literal($4)
			|| ',' || quote_literal($5)
			|| ',' || quote_literal($6)
			|| '))';

		RETURN  @extschema@._add_raster_constraint(cn, sql);
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION _drop_overview_constraint(ovschema name, ovtable name, ovcolumn name)
	RETURNS boolean AS
	$$ SELECT  @extschema@._drop_raster_constraint($1, $2, 'enforce_overview_' || $3) $$
	LANGUAGE 'sql' VOLATILE STRICT;
CREATE OR REPLACE VIEW raster_overviews AS
	SELECT
		current_database() AS o_table_catalog,
		n.nspname AS o_table_schema,
		c.relname AS o_table_name,
		a.attname AS o_raster_column,
		current_database() AS r_table_catalog,
		split_part(split_part(s.consrc, '''::name', 1), '''', 2)::name AS r_table_schema,
		split_part(split_part(s.consrc, '''::name', 2), '''', 2)::name AS r_table_name,
		split_part(split_part(s.consrc, '''::name', 3), '''', 2)::name AS r_raster_column,
		trim(both from split_part(s.consrc, ',', 2))::integer AS overview_factor
	FROM
		pg_class c,
		pg_attribute a,
		pg_type t,
		pg_namespace n,
		(SELECT connamespace, conrelid, conkey, pg_get_constraintdef(oid) As consrc
			FROM pg_constraint) AS s
	WHERE t.typname = 'raster'::name
		AND a.attisdropped = false
		AND a.atttypid = t.oid
		AND a.attrelid = c.oid
		AND c.relnamespace = n.oid
		AND c.relkind = ANY(ARRAY['r'::char, 'v'::char, 'm'::char, 'f'::char])
		AND s.connamespace = n.oid
		AND s.conrelid = c.oid
		AND s.consrc LIKE '%_overview_constraint(%'
		AND NOT pg_is_other_temp_schema(c.relnamespace)  AND has_table_privilege(c.oid, 'SELECT'::text);
CREATE OR REPLACE FUNCTION AddOverviewConstraints (
	ovschema name, ovtable name, ovcolumn name,
	refschema name, reftable name, refcolumn name,
	ovfactor int
)
	RETURNS boolean
	AS $$
	DECLARE
		x int;
		s name;
		t name;
		oschema name;
		rschema name;
		sql text;
		rtn boolean;
	BEGIN
		FOR x IN 1..2 LOOP
			s := '';

			IF x = 1 THEN
				s := $1;
				t := $2;
			ELSE
				s := $4;
				t := $5;
			END IF;

			-- validate user-provided schema
			IF length(s) > 0 THEN
				sql := 'SELECT nspname FROM pg_namespace '
					|| 'WHERE nspname = ' || quote_literal(s)
					|| 'LIMIT 1';
				EXECUTE sql INTO s;

				IF s IS NULL THEN
					RAISE EXCEPTION 'The value % is not a valid schema', quote_literal(s);
					RETURN FALSE;
				END IF;
			END IF;

			-- no schema, determine what it could be using the table
			IF length(s) < 1 THEN
				sql := 'SELECT n.nspname AS schemaname '
					|| 'FROM pg_catalog.pg_class c '
					|| 'JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace '
					|| 'WHERE c.relkind = ' || quote_literal('r')
					|| ' AND n.nspname NOT IN (' || quote_literal('pg_catalog')
					|| ', ' || quote_literal('pg_toast')
					|| ') AND pg_catalog.pg_table_is_visible(c.oid)'
					|| ' AND c.relname = ' || quote_literal(t);
				EXECUTE sql INTO s;

				IF s IS NULL THEN
					RAISE EXCEPTION 'The table % does not occur in the search_path', quote_literal(t);
					RETURN FALSE;
				END IF;
			END IF;

			IF x = 1 THEN
				oschema := s;
			ELSE
				rschema := s;
			END IF;
		END LOOP;

		-- reference raster
		rtn :=  @extschema@._add_overview_constraint(oschema, $2, $3, rschema, $5, $6, $7);
		IF rtn IS FALSE THEN
			RAISE EXCEPTION 'Unable to add the overview constraint.  Is the schema name, table name or column name incorrect?';
			RETURN FALSE;
		END IF;

		RETURN TRUE;
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION AddOverviewConstraints (
	ovtable name, ovcolumn name,
	reftable name, refcolumn name,
	ovfactor int
)
	RETURNS boolean
	AS $$ SELECT  @extschema@.AddOverviewConstraints('', $1, $2, '', $3, $4, $5) $$
	LANGUAGE 'sql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION DropOverviewConstraints (
	ovschema name,
	ovtable name,
	ovcolumn name
)
	RETURNS boolean
	AS $$
	DECLARE
		schema name;
		sql text;
		rtn boolean;
	BEGIN
		-- validate schema
		schema := NULL;
		IF length($1) > 0 THEN
			sql := 'SELECT nspname FROM pg_namespace '
				|| 'WHERE nspname = ' || quote_literal($1)
				|| 'LIMIT 1';
			EXECUTE sql INTO schema;

			IF schema IS NULL THEN
				RAISE EXCEPTION 'The value provided for schema is invalid';
				RETURN FALSE;
			END IF;
		END IF;

		IF schema IS NULL THEN
			sql := 'SELECT n.nspname AS schemaname '
				|| 'FROM pg_catalog.pg_class c '
				|| 'JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace '
				|| 'WHERE c.relkind = ' || quote_literal('r')
				|| ' AND n.nspname NOT IN (' || quote_literal('pg_catalog')
				|| ', ' || quote_literal('pg_toast')
				|| ') AND pg_catalog.pg_table_is_visible(c.oid)'
				|| ' AND c.relname = ' || quote_literal($2);
			EXECUTE sql INTO schema;

			IF schema IS NULL THEN
				RAISE EXCEPTION 'The table % does not occur in the search_path', quote_literal($2);
				RETURN FALSE;
			END IF;
		END IF;

		rtn :=  @extschema@._drop_overview_constraint(schema, $2, $3);
		IF rtn IS FALSE THEN
			RAISE EXCEPTION 'Unable to drop the overview constraint .  Is the schema name, table name or column name incorrect?';
			RETURN FALSE;
		END IF;

		RETURN TRUE;
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION DropOverviewConstraints (
	ovtable name,
	ovcolumn name
)
	RETURNS boolean
	AS $$ SELECT  @extschema@.DropOverviewConstraints('', $1, $2) $$
	LANGUAGE 'sql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION _UpdateRasterSRID(
	schema_name name, table_name name, column_name name,
	new_srid integer
)
	RETURNS boolean
	AS $$
	DECLARE
		fqtn text;
		schema name;
		sql text;
		srid integer;
		ct boolean;
	BEGIN
		-- validate schema
		schema := NULL;
		IF length($1) > 0 THEN
			sql := 'SELECT nspname FROM pg_namespace '
				|| 'WHERE nspname = ' || quote_literal($1)
				|| 'LIMIT 1';
			EXECUTE sql INTO schema;

			IF schema IS NULL THEN
				RAISE EXCEPTION 'The value provided for schema is invalid';
				RETURN FALSE;
			END IF;
		END IF;

		IF schema IS NULL THEN
			sql := 'SELECT n.nspname AS schemaname '
				|| 'FROM pg_catalog.pg_class c '
				|| 'JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace '
				|| 'WHERE c.relkind = ' || quote_literal('r')
				|| ' AND n.nspname NOT IN (' || quote_literal('pg_catalog')
				|| ', ' || quote_literal('pg_toast')
				|| ') AND pg_catalog.pg_table_is_visible(c.oid)'
				|| ' AND c.relname = ' || quote_literal($2);
			EXECUTE sql INTO schema;

			IF schema IS NULL THEN
				RAISE EXCEPTION 'The table % does not occur in the search_path', quote_literal($2);
				RETURN FALSE;
			END IF;
		END IF;

		-- clamp SRID
		IF new_srid < 0 THEN
			srid :=  @extschema@.ST_SRID('POINT EMPTY'::@extschema@.geometry);
			RAISE NOTICE 'SRID % converted to the officially unknown SRID %', new_srid, srid;
		ELSE
			srid := new_srid;
		END IF;

		-- drop coverage tile constraint
		-- done separately just in case constraint doesn't exist
		ct := @extschema@._raster_constraint_info_coverage_tile(schema, $2, $3);
		IF ct IS TRUE THEN
			PERFORM  @extschema@._drop_raster_constraint_coverage_tile(schema, $2, $3);
		END IF;

		-- drop SRID, extent, alignment constraints
		PERFORM  @extschema@.DropRasterConstraints(schema, $2, $3, 'extent', 'alignment', 'srid');

		fqtn := '';
		IF length($1) > 0 THEN
			fqtn := quote_ident($1) || '.';
		END IF;
		fqtn := fqtn || quote_ident($2);

		-- update SRID
		sql := 'UPDATE ' || fqtn ||
			' SET ' || quote_ident($3) ||
			' =  @extschema@.ST_SetSRID(' || quote_ident($3) ||
			'::@extschema@.raster, ' || srid || ')';
		RAISE NOTICE 'sql = %', sql;
		EXECUTE sql;

		-- add SRID constraint
		PERFORM  @extschema@.AddRasterConstraints(schema, $2, $3, 'srid', 'extent', 'alignment');

		-- add coverage tile constraint if needed
		IF ct IS TRUE THEN
			PERFORM  @extschema@._add_raster_constraint_coverage_tile(schema, $2, $3);
		END IF;

		RETURN TRUE;
	END;
	$$ LANGUAGE 'plpgsql' VOLATILE;
CREATE OR REPLACE FUNCTION UpdateRasterSRID(
	schema_name name, table_name name, column_name name,
	new_srid integer
)
	RETURNS boolean
	AS $$ SELECT  @extschema@._UpdateRasterSRID($1, $2, $3, $4) $$
	LANGUAGE 'sql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION UpdateRasterSRID(
	table_name name, column_name name,
	new_srid integer
)
	RETURNS boolean
	AS $$ SELECT  @extschema@._UpdateRasterSRID('', $1, $2, $3) $$
	LANGUAGE 'sql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION ST_Retile(tab regclass, col name, ext geometry, sfx float8, sfy float8, tw int, th int, algo text DEFAULT 'NearestNeighbour')
RETURNS SETOF raster AS $$
DECLARE
  rec RECORD;
  ipx FLOAT8;
  ipy FLOAT8;
  tx int;
  ty int;
  te @extschema@.GEOMETRY; -- tile extent
  ncols int;
  nlins int;
  srid int;
  sql TEXT;
BEGIN

  RAISE DEBUG 'Target coverage will have sfx=%, sfy=%', sfx, sfy;

  -- 2. Loop over each target tile and build it from source tiles
  ipx := @extschema@.st_xmin(ext);
  ncols := ceil((st_xmax(ext)-ipx)/sfx/tw);
  IF sfy < 0 THEN
    ipy := @extschema@.st_ymax(ext);
    nlins := ceil((@extschema@.st_ymin(ext)-ipy)/sfy/th);
  ELSE
    ipy := @extschema@.st_ymin(ext);
    nlins := ceil((@extschema@.st_ymax(ext)-ipy)/sfy/th);
  END IF;

  srid := @extschema@.ST_Srid(ext);

  RAISE DEBUG 'Target coverage will have % x % tiles, each of approx size % x %', ncols, nlins, tw, th;
  RAISE DEBUG 'Target coverage will cover extent %', ext::box2d;

  FOR tx IN 0..ncols-1 LOOP
    FOR ty IN 0..nlins-1 LOOP
      te := @extschema@.ST_MakeEnvelope(ipx + tx     *  tw  * sfx,
                             ipy + ty     *  th  * sfy,
                             ipx + (tx+1) *  tw  * sfx,
                             ipy + (ty+1) *  th  * sfy,
                             srid);
      --RAISE DEBUG 'sfx/sfy: %, %', sfx, sfy;
      --RAISE DEBUG 'tile extent %', te;
      sql := 'SELECT count(*),  @extschema@.ST_Clip(  @extschema@.ST_Union(  @extschema@.ST_SnapToGrid(  @extschema@.ST_Rescale(  @extschema@.ST_Clip(' || quote_ident(col)
          || ',  @extschema@.ST_Expand($3, greatest($1,$2))),$1, $2, $6), $4, $5, $1, $2)), $3) g FROM ' || tab::text
          || ' WHERE  @extschema@.ST_Intersects(' || quote_ident(col) || ', $3)';
      --RAISE DEBUG 'SQL: %', sql;
      FOR rec IN EXECUTE sql USING sfx, sfy, te, ipx, ipy, algo LOOP
        --RAISE DEBUG '% source tiles intersect target tile %,% with extent %', rec.count, tx, ty, te::box2d;
        IF rec.g IS NULL THEN
          RAISE WARNING 'No source tiles cover target tile %,% with extent %',
            tx, ty, te::box2d;
        ELSE
          --RAISE DEBUG 'Tile for extent % has size % x %', te::box2d, st_width(rec.g), st_height(rec.g);
          RETURN NEXT rec.g;
        END IF;
      END LOOP;
    END LOOP;
  END LOOP;

  RETURN;
END;
$$ LANGUAGE 'plpgsql' STABLE STRICT;
CREATE OR REPLACE FUNCTION ST_CreateOverview(tab regclass, col name, factor int, algo text DEFAULT 'NearestNeighbour')
RETURNS regclass AS $$
DECLARE
  sinfo RECORD; -- source info
  sql TEXT;
  ttab TEXT;
BEGIN

  -- 0. Check arguments, we need to ensure:
  --    a. Source table has a raster column with given name
  --    b. Source table has a fixed scale (or "factor" would have no meaning)
  --    c. Source table has a known extent ? (we could actually compute it)
  --    d. Source table has a fixed tile size (or "factor" would have no meaning?)
  -- # all of the above can be checked with a query to raster_columns
  sql := 'SELECT r.r_table_schema sch, r.r_table_name tab, '
      || 'r.scale_x sfx, r.scale_y sfy, r.blocksize_x tw, '
      || 'r.blocksize_y th, r.extent ext, r.srid FROM @extschema@.raster_columns r, '
      || 'pg_class c, pg_namespace n WHERE r.r_table_schema = n.nspname '
      || 'AND r.r_table_name = c.relname AND r_raster_column = $2 AND '
      || ' c.relnamespace = n.oid AND c.oid = $1'
  ;
  EXECUTE sql INTO sinfo USING tab, col;
  IF sinfo IS NULL THEN
      RAISE EXCEPTION '%.% raster column does not exist', tab::text, col;
  END IF;
  IF sinfo.sfx IS NULL or sinfo.sfy IS NULL THEN
    RAISE EXCEPTION 'cannot create overview without scale constraint, try select AddRasterConstraints(''%'', ''%'');', tab::text, col;
  END IF;
  IF sinfo.tw IS NULL or sinfo.tw IS NULL THEN
    RAISE EXCEPTION 'cannot create overview without tilesize constraint, try select AddRasterConstraints(''%'', ''%'');', tab::text, col;
  END IF;
  IF sinfo.ext IS NULL THEN
    RAISE EXCEPTION 'cannot create overview without extent constraint, try select AddRasterConstraints(''%'', ''%'');', tab::text, col;
  END IF;

  -- TODO: lookup in raster_overviews to see if there's any
  --       lower-resolution table to start from

  ttab := 'o_' || factor || '_' || sinfo.tab;
  sql := 'CREATE TABLE ' || quote_ident(sinfo.sch)
      || '.' || quote_ident(ttab)
      || ' AS SELECT @extschema@.ST_Retile($1, $2, $3, $4, $5, $6, $7) '
      || quote_ident(col);
  EXECUTE sql USING tab, col, sinfo.ext,
                    sinfo.sfx * factor, sinfo.sfy * factor,
                    sinfo.tw, sinfo.th, algo;

  -- TODO: optimize this using knowledge we have about
  --       the characteristics of the target column ?
  PERFORM @extschema@.AddRasterConstraints(sinfo.sch, ttab, col);

  PERFORM  @extschema@.AddOverviewConstraints(sinfo.sch, ttab, col,
                                 sinfo.sch, sinfo.tab, col, factor);

    -- return the schema as well as the table
  RETURN sinfo.sch||'.'||ttab;
END;
$$ LANGUAGE 'plpgsql' VOLATILE STRICT;
CREATE OR REPLACE FUNCTION st_makeemptycoverage(tilewidth int, tileheight int, width int, height int, upperleftx float8, upperlefty float8, scalex float8, scaley float8, skewx float8, skewy float8, srid int4 DEFAULT 0)
    RETURNS SETOF RASTER AS $$
    DECLARE
        ulx double precision;  -- upper left x of raster
        uly double precision;  -- upper left y of raster
        rw int;                -- raster width (may change at edges)
        rh int;                -- raster height (may change at edges)
        x int;                 -- x index of coverage
        y int;                 -- y index of coverage
        template @extschema@.raster;       -- an empty template raster, where each cell
                               -- represents a tile in the coverage
        minY double precision;
        maxX double precision;
    BEGIN
        template := @extschema@.ST_MakeEmptyRaster(
            ceil(width::float8/tilewidth)::int,
            ceil(height::float8/tileheight)::int,
            upperleftx,
            upperlefty,
            tilewidth * scalex,
            tileheight * scaley,
            tileheight * skewx,
            tilewidth * skewy,
            srid
        );

        FOR y IN 1..st_height(template) LOOP
            maxX := @extschema@.ST_RasterToWorldCoordX(template, 1, y) + width * scalex;
            FOR x IN 1..st_width(template) LOOP
                minY := @extschema@.ST_RasterToWorldCoordY(template, x, 1) + height * scaley;
                uly := @extschema@.ST_RasterToWorldCoordY(template, x, y);
                IF uly + (tileheight * scaley) < minY THEN
                    --raise notice 'uly, minY: %, %', uly, minY;
                    rh := ceil((minY - uly)/scaleY)::int;
                ELSE
                    rh := tileheight;
                END IF;

                ulx := @extschema@.ST_RasterToWorldCoordX(template, x, y);
                IF ulx + (tilewidth * scalex) > maxX THEN
                    --raise notice 'ulx, maxX: %, %', ulx, maxX;
                    rw := ceil((maxX - ulx)/scaleX)::int;
                ELSE
                    rw := tilewidth;
                END IF;

                RETURN NEXT @extschema@.ST_MakeEmptyRaster(rw, rh, ulx, uly, scalex, scaley, skewx, skewy, srid);
            END LOOP;
        END LOOP;
    END;
    $$ LANGUAGE 'plpgsql' IMMUTABLE PARALLEL SAFE;
CREATE OR REPLACE FUNCTION postgis_noop(raster)
	RETURNS geometry
	AS '$libdir/rtpostgis-2.5', 'RASTER_noop'
	LANGUAGE 'c' STABLE STRICT;
GRANT SELECT ON TABLE raster_columns TO public;
GRANT SELECT ON TABLE raster_overviews TO public;
SELECT postgis_extension_drop_if_exists('postgis', 'DROP TABLE _postgis_upgrade_info');
DROP TABLE _postgis_upgrade_info;
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--
--
-- PostGIS Raster - Raster Type for PostGIS
-- http://trac.osgeo.org/postgis/wiki/WKTRaster
--
-- Copyright (C) 2011 Regina Obe <lr@pcorp.us>
-- Copyright (C) 2011-2012 Regents of the University of California
--   <bkpark@ucdavis.edu>
-- Modifications Copyright (c) 2017 - Present Pivotal Software, Inc. All Rights Reserved.
--
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software Foundation,
-- Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
--
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--
-- WARNING: Any change in this file must be evaluated for compatibility.
--
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--
-- This file will be used to drop obseleted objects.
-- It will be only used for upgrades.
-- It will be loaded _after_ the objects upgrade statements, so
-- that objects previously dependent on these objects have a chance
-- to get upgraded to remove the dependency.
--
-- Remember: only put _obsoleted_ signatures in this file.
--
-- TODO: tag each item with the version in which it was dropped
--
--

-- drop obsoleted aggregates
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS ST_Union(raster, text, text, text, double precision, text, text, text, double precision, text, text, text, double precision)');
DROP AGGREGATE IF EXISTS ST_Union(raster, text, text, text, double precision, text, text, text, double precision, text, text, text, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS ST_Union(raster, text, text, text)');
DROP AGGREGATE IF EXISTS ST_Union(raster, text, text, text);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS ST_Union(raster, text, text, text, double precision, text, text, text, double precision)');
DROP AGGREGATE IF EXISTS ST_Union(raster, text, text, text, double precision, text, text, text, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS ST_Union(raster, text, text)');
DROP AGGREGATE IF EXISTS ST_Union(raster, text, text);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS ST_Union(raster, text, text, text, double precision)');
DROP AGGREGATE IF EXISTS ST_Union(raster, text, text, text, double precision);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP AGGREGATE IF EXISTS ST_Union(raster, record[])');
DROP AGGREGATE IF EXISTS ST_Union(raster, record[]);

SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_Intersects(raster,boolean,geometry)');
DROP FUNCTION IF EXISTS ST_Intersects(raster,boolean,geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_Intersects(geometry,raster,boolean)');
DROP FUNCTION IF EXISTS ST_Intersects(geometry,raster,boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_Intersects(raster,geometry)');
DROP FUNCTION IF EXISTS ST_Intersects(raster,geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_Intersects(geometry,raster)');
DROP FUNCTION IF EXISTS ST_Intersects(geometry,raster);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_Intersects(raster, integer, boolean  , geometry)');
DROP FUNCTION IF EXISTS ST_Intersects(raster, integer, boolean  , geometry);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_Intersects(geometry , raster, integer , boolean)');
DROP FUNCTION IF EXISTS ST_Intersects(geometry , raster, integer , boolean);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_Intersection(raster,raster, integer, integer)');
DROP FUNCTION IF EXISTS ST_Intersection(raster,raster, integer, integer);
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS ST_Intersection(geometry,raster)');
DROP FUNCTION IF EXISTS ST_Intersection(geometry,raster);

-- Removed in 2.1.0
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_mapalgebra4unionfinal1(raster)');
DROP FUNCTION IF EXISTS _st_mapalgebra4unionfinal1(raster);
-- Removed in 2.1.0
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_mapalgebra4unionstate(raster, raster, int4)');
DROP FUNCTION IF EXISTS _st_mapalgebra4unionstate(raster, raster, int4);
-- Removed in 2.1.0
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_mapalgebra4unionstate(raster, raster)');
DROP FUNCTION IF EXISTS _st_mapalgebra4unionstate(raster, raster);
-- Removed in 2.1.0
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_mapalgebra4unionstate(raster, raster, text)');
DROP FUNCTION IF EXISTS _st_mapalgebra4unionstate(raster, raster, text);
-- Removed in 2.1.0
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_mapalgebra4unionstate(raster, raster, int4, text)');
DROP FUNCTION IF EXISTS _st_mapalgebra4unionstate(raster, raster, int4, text);
-- Removed in 2.1.0
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_mapalgebra4unionstate(raster, raster, text, text, text, float8, text, text, text, float8)');
DROP FUNCTION IF EXISTS _st_mapalgebra4unionstate(raster, raster, text, text, text, float8, text, text, text, float8);
-- Removed in 2.2.0
SELECT postgis_extension_drop_if_exists('postgis', 'DROP FUNCTION IF EXISTS _st_mapalgebra(rastbandarg[],regprocedure,text,integer,integer,text,raster,text[])');
DROP FUNCTION IF EXISTS _st_mapalgebra(rastbandarg[],regprocedure,text,integer,integer,text,raster,text[]);



COMMENT ON FUNCTION AddRasterConstraints(name , name , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean ) IS 'args: rasttable, rastcolumn, srid=true, scale_x=true, scale_y=true, blocksize_x=true, blocksize_y=true, same_alignment=true, regular_blocking=false, num_bands=true, pixel_types=true, nodata_values=true, out_db=true, extent=true - Adds raster constraints to a loaded raster table for a specific column that constrains spatial ref, scaling, blocksize, alignment, bands, band type and a flag to denote if raster column is regularly blocked. The table must be loaded with data for the constraints to be inferred. Returns true if the constraint setting was accomplished and issues a notice otherwise.';
			
COMMENT ON FUNCTION AddRasterConstraints(name , name , text[] ) IS 'args: rasttable, rastcolumn, VARIADIC constraints - Adds raster constraints to a loaded raster table for a specific column that constrains spatial ref, scaling, blocksize, alignment, bands, band type and a flag to denote if raster column is regularly blocked. The table must be loaded with data for the constraints to be inferred. Returns true if the constraint setting was accomplished and issues a notice otherwise.';
			
COMMENT ON FUNCTION AddRasterConstraints(name , name , name , text[] ) IS 'args: rastschema, rasttable, rastcolumn, VARIADIC constraints - Adds raster constraints to a loaded raster table for a specific column that constrains spatial ref, scaling, blocksize, alignment, bands, band type and a flag to denote if raster column is regularly blocked. The table must be loaded with data for the constraints to be inferred. Returns true if the constraint setting was accomplished and issues a notice otherwise.';
			
COMMENT ON FUNCTION AddRasterConstraints(name , name , name , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean ) IS 'args: rastschema, rasttable, rastcolumn, srid=true, scale_x=true, scale_y=true, blocksize_x=true, blocksize_y=true, same_alignment=true, regular_blocking=false, num_bands=true, pixel_types=true, nodata_values=true, out_db=true, extent=true - Adds raster constraints to a loaded raster table for a specific column that constrains spatial ref, scaling, blocksize, alignment, bands, band type and a flag to denote if raster column is regularly blocked. The table must be loaded with data for the constraints to be inferred. Returns true if the constraint setting was accomplished and issues a notice otherwise.';
			
COMMENT ON FUNCTION DropRasterConstraints(name , name , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean ) IS 'args: rasttable, rastcolumn, srid, scale_x, scale_y, blocksize_x, blocksize_y, same_alignment, regular_blocking, num_bands=true, pixel_types=true, nodata_values=true, out_db=true, extent=true - Drops PostGIS raster constraints that refer to a raster table column. Useful if you need to reload data or update your raster column data.';
			
COMMENT ON FUNCTION DropRasterConstraints(name , name , name , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean , boolean ) IS 'args: rastschema, rasttable, rastcolumn, srid=true, scale_x=true, scale_y=true, blocksize_x=true, blocksize_y=true, same_alignment=true, regular_blocking=false, num_bands=true, pixel_types=true, nodata_values=true, out_db=true, extent=true - Drops PostGIS raster constraints that refer to a raster table column. Useful if you need to reload data or update your raster column data.';
			
COMMENT ON FUNCTION DropRasterConstraints(name , name , name , text[] ) IS 'args: rastschema, rasttable, rastcolumn, constraints - Drops PostGIS raster constraints that refer to a raster table column. Useful if you need to reload data or update your raster column data.';
			
COMMENT ON FUNCTION AddOverviewConstraints(name , name , name , name , name , name , int ) IS 'args: ovschema, ovtable, ovcolumn, refschema, reftable, refcolumn, ovfactor - Tag a raster column as being an overview of another.';
			
COMMENT ON FUNCTION AddOverviewConstraints(name , name , name , name , int ) IS 'args: ovtable, ovcolumn, reftable, refcolumn, ovfactor - Tag a raster column as being an overview of another.';
			
COMMENT ON FUNCTION DropOverviewConstraints(name , name , name ) IS 'args: ovschema, ovtable, ovcolumn - Untag a raster column from being an overview of another.';
			
COMMENT ON FUNCTION DropOverviewConstraints(name , name ) IS 'args: ovtable, ovcolumn - Untag a raster column from being an overview of another.';
			
COMMENT ON FUNCTION PostGIS_GDAL_Version() IS 'Reports the version of the GDAL library in use by PostGIS.';
			
COMMENT ON FUNCTION PostGIS_Raster_Lib_Build_Date() IS 'Reports full raster library build date.';
			
COMMENT ON FUNCTION PostGIS_Raster_Lib_Version() IS 'Reports full raster version and build configuration infos.';
			
COMMENT ON FUNCTION ST_GDALDrivers() IS 'args: OUT idx, OUT short_name, OUT long_name, OUT can_read, OUT can_write, OUT create_options - Returns a list of raster formats supported by PostGIS through GDAL. Only those formats with can_write=True can be used by ST_AsGDALRaster';
			
COMMENT ON FUNCTION UpdateRasterSRID(name , name , name , integer ) IS 'args: schema_name, table_name, column_name, new_srid - Change the SRID of all rasters in the user-specified column and table.';
			
COMMENT ON FUNCTION UpdateRasterSRID(name , name , integer ) IS 'args: table_name, column_name, new_srid - Change the SRID of all rasters in the user-specified column and table.';
			
COMMENT ON FUNCTION ST_CreateOverview(regclass , name , int , text ) IS 'args: tab, col, factor, algo=''NearestNeighbor'' - Create an reduced resolution version of a given raster coverage.';
			
COMMENT ON FUNCTION ST_AddBand(raster , addbandarg[] ) IS 'args: rast, addbandargset - Returns a raster with the new band(s) of given type added with given initial value in the given index location. If no index is specified, the band is added to the end.';
			
COMMENT ON FUNCTION ST_AddBand(raster , integer , text , double precision , double precision ) IS 'args: rast, index, pixeltype, initialvalue=0, nodataval=NULL - Returns a raster with the new band(s) of given type added with given initial value in the given index location. If no index is specified, the band is added to the end.';
			
COMMENT ON FUNCTION ST_AddBand(raster , text , double precision , double precision ) IS 'args: rast, pixeltype, initialvalue=0, nodataval=NULL - Returns a raster with the new band(s) of given type added with given initial value in the given index location. If no index is specified, the band is added to the end.';
			
COMMENT ON FUNCTION ST_AddBand(raster , raster , integer , integer ) IS 'args: torast, fromrast, fromband=1, torastindex=at_end - Returns a raster with the new band(s) of given type added with given initial value in the given index location. If no index is specified, the band is added to the end.';
			
COMMENT ON FUNCTION ST_AddBand(raster , raster[] , integer , integer ) IS 'args: torast, fromrasts, fromband=1, torastindex=at_end - Returns a raster with the new band(s) of given type added with given initial value in the given index location. If no index is specified, the band is added to the end.';
			
COMMENT ON FUNCTION ST_AddBand(raster , integer , text , integer[] , double precision ) IS 'args: rast, index, outdbfile, outdbindex, nodataval=NULL - Returns a raster with the new band(s) of given type added with given initial value in the given index location. If no index is specified, the band is added to the end.';
			
COMMENT ON FUNCTION ST_AddBand(raster , text , integer[] , integer , double precision ) IS 'args: rast, outdbfile, outdbindex, index=at_end, nodataval=NULL - Returns a raster with the new band(s) of given type added with given initial value in the given index location. If no index is specified, the band is added to the end.';
			
COMMENT ON FUNCTION ST_AsRaster(geometry , raster , text , double precision , double precision , boolean ) IS 'args: geom, ref, pixeltype, value=1, nodataval=0, touched=false - Converts a PostGIS geometry to a PostGIS raster.';
			
COMMENT ON FUNCTION ST_AsRaster(geometry , raster , text[] , double precision[] , double precision[] , boolean ) IS 'args: geom, ref, pixeltype=ARRAY[''8BUI''], value=ARRAY[1], nodataval=ARRAY[0], touched=false - Converts a PostGIS geometry to a PostGIS raster.';
			
COMMENT ON FUNCTION ST_AsRaster(geometry , double precision , double precision , double precision , double precision , text , double precision , double precision , double precision , double precision , boolean ) IS 'args: geom, scalex, scaley, gridx, gridy, pixeltype, value=1, nodataval=0, skewx=0, skewy=0, touched=false - Converts a PostGIS geometry to a PostGIS raster.';
			
COMMENT ON FUNCTION ST_AsRaster(geometry , double precision , double precision , double precision , double precision , text[] , double precision[] , double precision[] , double precision , double precision , boolean ) IS 'args: geom, scalex, scaley, gridx=NULL, gridy=NULL, pixeltype=ARRAY[''8BUI''], value=ARRAY[1], nodataval=ARRAY[0], skewx=0, skewy=0, touched=false - Converts a PostGIS geometry to a PostGIS raster.';
			
COMMENT ON FUNCTION ST_AsRaster(geometry , double precision , double precision , text , double precision , double precision , double precision , double precision , double precision , double precision , boolean ) IS 'args: geom, scalex, scaley, pixeltype, value=1, nodataval=0, upperleftx=NULL, upperlefty=NULL, skewx=0, skewy=0, touched=false - Converts a PostGIS geometry to a PostGIS raster.';
			
COMMENT ON FUNCTION ST_AsRaster(geometry , double precision , double precision , text[] , double precision[] , double precision[] , double precision , double precision , double precision , double precision , boolean ) IS 'args: geom, scalex, scaley, pixeltype, value=ARRAY[1], nodataval=ARRAY[0], upperleftx=NULL, upperlefty=NULL, skewx=0, skewy=0, touched=false - Converts a PostGIS geometry to a PostGIS raster.';
			
COMMENT ON FUNCTION ST_AsRaster(geometry , integer , integer , double precision , double precision , text , double precision , double precision , double precision , double precision , boolean ) IS 'args: geom, width, height, gridx, gridy, pixeltype, value=1, nodataval=0, skewx=0, skewy=0, touched=false - Converts a PostGIS geometry to a PostGIS raster.';
			
COMMENT ON FUNCTION ST_AsRaster(geometry , integer , integer , double precision , double precision , text[] , double precision[] , double precision[] , double precision , double precision , boolean ) IS 'args: geom, width, height, gridx=NULL, gridy=NULL, pixeltype=ARRAY[''8BUI''], value=ARRAY[1], nodataval=ARRAY[0], skewx=0, skewy=0, touched=false - Converts a PostGIS geometry to a PostGIS raster.';
			
COMMENT ON FUNCTION ST_AsRaster(geometry , integer , integer , text , double precision , double precision , double precision , double precision , double precision , double precision , boolean ) IS 'args: geom, width, height, pixeltype, value=1, nodataval=0, upperleftx=NULL, upperlefty=NULL, skewx=0, skewy=0, touched=false - Converts a PostGIS geometry to a PostGIS raster.';
			
COMMENT ON FUNCTION ST_AsRaster(geometry , integer , integer , text[] , double precision[] , double precision[] , double precision , double precision , double precision , double precision , boolean ) IS 'args: geom, width, height, pixeltype, value=ARRAY[1], nodataval=ARRAY[0], upperleftx=NULL, upperlefty=NULL, skewx=0, skewy=0, touched=false - Converts a PostGIS geometry to a PostGIS raster.';
			
COMMENT ON FUNCTION ST_Band(raster , integer[] ) IS 'args: rast, nbands = ARRAY[1] - Returns one or more bands of an existing raster as a new raster. Useful for building new rasters from existing rasters.';
			
COMMENT ON FUNCTION ST_Band(raster , integer ) IS 'args: rast, nband - Returns one or more bands of an existing raster as a new raster. Useful for building new rasters from existing rasters.';
			
COMMENT ON FUNCTION ST_Band(raster , text , character ) IS 'args: rast, nbands, delimiter=, - Returns one or more bands of an existing raster as a new raster. Useful for building new rasters from existing rasters.';
			
COMMENT ON FUNCTION ST_MakeEmptyCoverage(integer , integer , integer , integer , double precision , double precision , double precision , double precision , double precision , double precision , integer ) IS 'args: tilewidth, tileheight, width, height, upperleftx, upperlefty, scalex, scaley, skewx, skewy, srid=unknown - Cover georeferenced area with a grid of empty raster tiles.';
			
COMMENT ON FUNCTION ST_MakeEmptyRaster(raster ) IS 'args: rast - Returns an empty raster (having no bands) of given dimensions (width & height), upperleft X and Y, pixel size and rotation (scalex, scaley, skewx & skewy) and reference system (srid). If a raster is passed in, returns a new raster with the same size, alignment and SRID. If srid is left out, the spatial ref is set to unknown (0).';
			
COMMENT ON FUNCTION ST_MakeEmptyRaster(integer , integer , float8 , float8 , float8 , float8 , float8 , float8 , integer ) IS 'args: width, height, upperleftx, upperlefty, scalex, scaley, skewx, skewy, srid=unknown - Returns an empty raster (having no bands) of given dimensions (width & height), upperleft X and Y, pixel size and rotation (scalex, scaley, skewx & skewy) and reference system (srid). If a raster is passed in, returns a new raster with the same size, alignment and SRID. If srid is left out, the spatial ref is set to unknown (0).';
			
COMMENT ON FUNCTION ST_MakeEmptyRaster(integer , integer , float8  , float8  , float8  ) IS 'args: width, height, upperleftx, upperlefty, pixelsize - Returns an empty raster (having no bands) of given dimensions (width & height), upperleft X and Y, pixel size and rotation (scalex, scaley, skewx & skewy) and reference system (srid). If a raster is passed in, returns a new raster with the same size, alignment and SRID. If srid is left out, the spatial ref is set to unknown (0).';
			
COMMENT ON FUNCTION ST_Tile(raster , int[] , integer , integer , boolean , double precision ) IS 'args: rast, nband, width, height, padwithnodata=FALSE, nodataval=NULL - Returns a set of rasters resulting from the split of the input raster based upon the desired dimensions of the output rasters.';
			
COMMENT ON FUNCTION ST_Tile(raster , integer , integer , integer , boolean , double precision ) IS 'args: rast, nband, width, height, padwithnodata=FALSE, nodataval=NULL - Returns a set of rasters resulting from the split of the input raster based upon the desired dimensions of the output rasters.';
			
COMMENT ON FUNCTION ST_Tile(raster , integer , integer , boolean , double precision ) IS 'args: rast, width, height, padwithnodata=FALSE, nodataval=NULL - Returns a set of rasters resulting from the split of the input raster based upon the desired dimensions of the output rasters.';
			
COMMENT ON FUNCTION ST_Retile(regclass , name , geometry , float8 , float8 , int , int , text ) IS 'args: tab, col, ext, sfx, sfy, tw, th, algo=''NearestNeighbor'' - Return a set of configured tiles from an arbitrarily tiled raster coverage.';
			
COMMENT ON FUNCTION ST_FromGDALRaster(bytea , integer ) IS 'args: gdaldata, srid=NULL - Returns a raster from a supported GDAL raster file.';
			
COMMENT ON FUNCTION ST_GeoReference(raster , text ) IS 'args: rast, format=GDAL - Returns the georeference meta data in GDAL or ESRI format as commonly seen in a world file. Default is GDAL.';
			
COMMENT ON FUNCTION ST_Height(raster ) IS 'args: rast - Returns the height of the raster in pixels.';
			
COMMENT ON FUNCTION ST_IsEmpty(raster ) IS 'args: rast - Returns true if the raster is empty (width = 0 and height = 0). Otherwise, returns false.';
			
COMMENT ON FUNCTION ST_MemSize(raster ) IS 'args: rast - Returns the amount of space (in bytes) the raster takes.';
			
COMMENT ON FUNCTION ST_MetaData(raster ) IS 'args: rast - Returns basic meta data about a raster object such as pixel size, rotation (skew), upper, lower left, etc.';
			
COMMENT ON FUNCTION ST_NumBands(raster ) IS 'args: rast - Returns the number of bands in the raster object.';
			
COMMENT ON FUNCTION ST_PixelHeight(raster ) IS 'args: rast - Returns the pixel height in geometric units of the spatial reference system.';
			
COMMENT ON FUNCTION ST_PixelWidth(raster ) IS 'args: rast - Returns the pixel width in geometric units of the spatial reference system.';
			
COMMENT ON FUNCTION ST_ScaleX(raster ) IS 'args: rast - Returns the X component of the pixel width in units of coordinate reference system.';
			
COMMENT ON FUNCTION ST_ScaleY(raster ) IS 'args: rast - Returns the Y component of the pixel height in units of coordinate reference system.';
			
COMMENT ON FUNCTION ST_RasterToWorldCoord(raster , integer , integer ) IS 'args: rast, xcolumn, yrow - Returns the rasters upper left corner as geometric X and Y (longitude and latitude) given a column and row. Column and row starts at 1.';
			
COMMENT ON FUNCTION ST_RasterToWorldCoordX(raster , integer ) IS 'args: rast, xcolumn - Returns the geometric X coordinate upper left of a raster, column and row. Numbering of columns and rows starts at 1.';
			
COMMENT ON FUNCTION ST_RasterToWorldCoordX(raster , integer , integer ) IS 'args: rast, xcolumn, yrow - Returns the geometric X coordinate upper left of a raster, column and row. Numbering of columns and rows starts at 1.';
			
COMMENT ON FUNCTION ST_RasterToWorldCoordY(raster , integer ) IS 'args: rast, yrow - Returns the geometric Y coordinate upper left corner of a raster, column and row. Numbering of columns and rows starts at 1.';
			
COMMENT ON FUNCTION ST_RasterToWorldCoordY(raster , integer , integer ) IS 'args: rast, xcolumn, yrow - Returns the geometric Y coordinate upper left corner of a raster, column and row. Numbering of columns and rows starts at 1.';
			
COMMENT ON FUNCTION ST_Rotation(raster) IS 'args: rast - Returns the rotation of the raster in radian.';
			
COMMENT ON FUNCTION ST_SkewX(raster ) IS 'args: rast - Returns the georeference X skew (or rotation parameter).';
			
COMMENT ON FUNCTION ST_SkewY(raster ) IS 'args: rast - Returns the georeference Y skew (or rotation parameter).';
			
COMMENT ON FUNCTION ST_SRID(raster ) IS 'args: rast - Returns the spatial reference identifier of the raster as defined in spatial_ref_sys table.';
			
COMMENT ON FUNCTION ST_Summary(raster ) IS 'args: rast - Returns a text summary of the contents of the raster.';
			
COMMENT ON FUNCTION ST_UpperLeftX(raster ) IS 'args: rast - Returns the upper left X coordinate of raster in projected spatial ref.';
			
COMMENT ON FUNCTION ST_UpperLeftY(raster ) IS 'args: rast - Returns the upper left Y coordinate of raster in projected spatial ref.';
			
COMMENT ON FUNCTION ST_Width(raster ) IS 'args: rast - Returns the width of the raster in pixels.';
			
COMMENT ON FUNCTION ST_WorldToRasterCoord(raster , geometry ) IS 'args: rast, pt - Returns the upper left corner as column and row given geometric X and Y (longitude and latitude) or a point geometry expressed in the spatial reference coordinate system of the raster.';
			
COMMENT ON FUNCTION ST_WorldToRasterCoord(raster , double precision , double precision ) IS 'args: rast, longitude, latitude - Returns the upper left corner as column and row given geometric X and Y (longitude and latitude) or a point geometry expressed in the spatial reference coordinate system of the raster.';
			
COMMENT ON FUNCTION ST_WorldToRasterCoordX(raster , geometry ) IS 'args: rast, pt - Returns the column in the raster of the point geometry (pt) or a X and Y world coordinate (xw, yw) represented in world spatial reference system of raster.';
			
COMMENT ON FUNCTION ST_WorldToRasterCoordX(raster , double precision ) IS 'args: rast, xw - Returns the column in the raster of the point geometry (pt) or a X and Y world coordinate (xw, yw) represented in world spatial reference system of raster.';
			
COMMENT ON FUNCTION ST_WorldToRasterCoordX(raster , double precision , double precision ) IS 'args: rast, xw, yw - Returns the column in the raster of the point geometry (pt) or a X and Y world coordinate (xw, yw) represented in world spatial reference system of raster.';
			
COMMENT ON FUNCTION ST_WorldToRasterCoordY(raster , geometry ) IS 'args: rast, pt - Returns the row in the raster of the point geometry (pt) or a X and Y world coordinate (xw, yw) represented in world spatial reference system of raster.';
			
COMMENT ON FUNCTION ST_WorldToRasterCoordY(raster , double precision ) IS 'args: rast, xw - Returns the row in the raster of the point geometry (pt) or a X and Y world coordinate (xw, yw) represented in world spatial reference system of raster.';
			
COMMENT ON FUNCTION ST_WorldToRasterCoordY(raster , double precision , double precision ) IS 'args: rast, xw, yw - Returns the row in the raster of the point geometry (pt) or a X and Y world coordinate (xw, yw) represented in world spatial reference system of raster.';
			
COMMENT ON FUNCTION ST_BandMetaData(raster , integer ) IS 'args: rast, band=1 - Returns basic meta data for a specific raster band. band num 1 is assumed if none-specified.';
			
COMMENT ON FUNCTION ST_BandMetaData(raster , integer[] ) IS 'args: rast, band - Returns basic meta data for a specific raster band. band num 1 is assumed if none-specified.';
			
COMMENT ON FUNCTION ST_BandNoDataValue(raster , integer ) IS 'args: rast, bandnum=1 - Returns the value in a given band that represents no data. If no band num 1 is assumed.';
			
COMMENT ON FUNCTION ST_BandIsNoData(raster , integer , boolean ) IS 'args: rast, band, forceChecking=true - Returns true if the band is filled with only nodata values.';
			
COMMENT ON FUNCTION ST_BandIsNoData(raster , boolean ) IS 'args: rast, forceChecking=true - Returns true if the band is filled with only nodata values.';
			
COMMENT ON FUNCTION ST_BandPath(raster , integer ) IS 'args: rast, bandnum=1 - Returns system file path to a band stored in file system. If no bandnum specified, 1 is assumed.';
			
COMMENT ON FUNCTION ST_BandFileSize(raster , integer ) IS 'args: rast, bandnum=1 - Returns the file size of a band stored in file system. If no bandnum specified, 1 is assumed.';
			
COMMENT ON FUNCTION ST_BandFileTimestamp(raster , integer ) IS 'args: rast, bandnum=1 - Returns the file timestamp of a band stored in file system. If no bandnum specified, 1 is assumed.';
			
COMMENT ON FUNCTION ST_BandPixelType(raster , integer ) IS 'args: rast, bandnum=1 - Returns the type of pixel for given band. If no bandnum specified, 1 is assumed.';
			
COMMENT ON FUNCTION ST_HasNoBand(raster , integer ) IS 'args: rast, bandnum=1 - Returns true if there is no band with given band number. If no band number is specified, then band number 1 is assumed.';
			
COMMENT ON FUNCTION ST_PixelAsPolygon(raster , integer , integer ) IS 'args: rast, columnx, rowy - Returns the polygon geometry that bounds the pixel for a particular row and column.';
			
COMMENT ON FUNCTION ST_PixelAsPolygons(raster , integer , boolean ) IS 'args: rast, band=1, exclude_nodata_value=TRUE - Returns the polygon geometry that bounds every pixel of a raster band along with the value, the X and the Y raster coordinates of each pixel.';
			
COMMENT ON FUNCTION ST_PixelAsPoint(raster , integer , integer ) IS 'args: rast, columnx, rowy - Returns a point geometry of the pixels upper-left corner.';
			
COMMENT ON FUNCTION ST_PixelAsPoints(raster , integer , boolean ) IS 'args: rast, band=1, exclude_nodata_value=TRUE - Returns a point geometry for each pixel of a raster band along with the value, the X and the Y raster coordinates of each pixel. The coordinates of the point geometry are of the pixels upper-left corner.';
			
COMMENT ON FUNCTION ST_PixelAsCentroid(raster , integer , integer ) IS 'args: rast, x, y - Returns the centroid (point geometry) of the area represented by a pixel.';
			
COMMENT ON FUNCTION ST_PixelAsCentroids(raster , integer , boolean ) IS 'args: rast, band=1, exclude_nodata_value=TRUE - Returns the centroid (point geometry) for each pixel of a raster band along with the value, the X and the Y raster coordinates of each pixel. The point geometry is the centroid of the area represented by a pixel.';
			
COMMENT ON FUNCTION ST_Value(raster , geometry , boolean ) IS 'args: rast, pt, exclude_nodata_value=true - Returns the value of a given band in a given columnx, rowy pixel or at a particular geometric point. Band numbers start at 1 and assumed to be 1 if not specified. If exclude_nodata_value is set to false, then all pixels include nodata pixels are considered to intersect and return value. If exclude_nodata_value is not passed in then reads it from metadata of raster.';
			
COMMENT ON FUNCTION ST_Value(raster , integer , geometry , boolean ) IS 'args: rast, band, pt, exclude_nodata_value=true - Returns the value of a given band in a given columnx, rowy pixel or at a particular geometric point. Band numbers start at 1 and assumed to be 1 if not specified. If exclude_nodata_value is set to false, then all pixels include nodata pixels are considered to intersect and return value. If exclude_nodata_value is not passed in then reads it from metadata of raster.';
			
COMMENT ON FUNCTION ST_Value(raster , integer , integer , boolean ) IS 'args: rast, x, y, exclude_nodata_value=true - Returns the value of a given band in a given columnx, rowy pixel or at a particular geometric point. Band numbers start at 1 and assumed to be 1 if not specified. If exclude_nodata_value is set to false, then all pixels include nodata pixels are considered to intersect and return value. If exclude_nodata_value is not passed in then reads it from metadata of raster.';
			
COMMENT ON FUNCTION ST_Value(raster , integer , integer , integer , boolean ) IS 'args: rast, band, x, y, exclude_nodata_value=true - Returns the value of a given band in a given columnx, rowy pixel or at a particular geometric point. Band numbers start at 1 and assumed to be 1 if not specified. If exclude_nodata_value is set to false, then all pixels include nodata pixels are considered to intersect and return value. If exclude_nodata_value is not passed in then reads it from metadata of raster.';
			
COMMENT ON FUNCTION ST_NearestValue(raster , integer , geometry , boolean ) IS 'args: rast, bandnum, pt, exclude_nodata_value=true - Returns the nearest non-NODATA value of a given bands pixel specified by a columnx and rowy or a geometric point expressed in the same spatial reference coordinate system as the raster.';
			
COMMENT ON FUNCTION ST_NearestValue(raster , geometry , boolean ) IS 'args: rast, pt, exclude_nodata_value=true - Returns the nearest non-NODATA value of a given bands pixel specified by a columnx and rowy or a geometric point expressed in the same spatial reference coordinate system as the raster.';
			
COMMENT ON FUNCTION ST_NearestValue(raster , integer , integer , integer , boolean ) IS 'args: rast, bandnum, columnx, rowy, exclude_nodata_value=true - Returns the nearest non-NODATA value of a given bands pixel specified by a columnx and rowy or a geometric point expressed in the same spatial reference coordinate system as the raster.';
			
COMMENT ON FUNCTION ST_NearestValue(raster , integer , integer , boolean ) IS 'args: rast, columnx, rowy, exclude_nodata_value=true - Returns the nearest non-NODATA value of a given bands pixel specified by a columnx and rowy or a geometric point expressed in the same spatial reference coordinate system as the raster.';
			
COMMENT ON FUNCTION ST_Neighborhood(raster , integer , integer , integer , integer , integer , boolean ) IS 'args: rast, bandnum, columnX, rowY, distanceX, distanceY, exclude_nodata_value=true - Returns a 2-D double precision array of the non-NODATA values around a given bands pixel specified by either a columnX and rowY or a geometric point expressed in the same spatial reference coordinate system as the raster.';
			
COMMENT ON FUNCTION ST_Neighborhood(raster , integer , integer , integer , integer , boolean ) IS 'args: rast, columnX, rowY, distanceX, distanceY, exclude_nodata_value=true - Returns a 2-D double precision array of the non-NODATA values around a given bands pixel specified by either a columnX and rowY or a geometric point expressed in the same spatial reference coordinate system as the raster.';
			
COMMENT ON FUNCTION ST_Neighborhood(raster , integer , geometry , integer , integer , boolean ) IS 'args: rast, bandnum, pt, distanceX, distanceY, exclude_nodata_value=true - Returns a 2-D double precision array of the non-NODATA values around a given bands pixel specified by either a columnX and rowY or a geometric point expressed in the same spatial reference coordinate system as the raster.';
			
COMMENT ON FUNCTION ST_Neighborhood(raster , geometry , integer , integer , boolean ) IS 'args: rast, pt, distanceX, distanceY, exclude_nodata_value=true - Returns a 2-D double precision array of the non-NODATA values around a given bands pixel specified by either a columnX and rowY or a geometric point expressed in the same spatial reference coordinate system as the raster.';
			
COMMENT ON FUNCTION ST_SetValue(raster , integer , geometry , double precision ) IS 'args: rast, bandnum, geom, newvalue - Returns modified raster resulting from setting the value of a given band in a given columnx, rowy pixel or the pixels that intersect a particular geometry. Band numbers start at 1 and assumed to be 1 if not specified.';
			
COMMENT ON FUNCTION ST_SetValue(raster , geometry , double precision ) IS 'args: rast, geom, newvalue - Returns modified raster resulting from setting the value of a given band in a given columnx, rowy pixel or the pixels that intersect a particular geometry. Band numbers start at 1 and assumed to be 1 if not specified.';
			
COMMENT ON FUNCTION ST_SetValue(raster , integer , integer , integer , double precision ) IS 'args: rast, bandnum, columnx, rowy, newvalue - Returns modified raster resulting from setting the value of a given band in a given columnx, rowy pixel or the pixels that intersect a particular geometry. Band numbers start at 1 and assumed to be 1 if not specified.';
			
COMMENT ON FUNCTION ST_SetValue(raster , integer , integer , double precision ) IS 'args: rast, columnx, rowy, newvalue - Returns modified raster resulting from setting the value of a given band in a given columnx, rowy pixel or the pixels that intersect a particular geometry. Band numbers start at 1 and assumed to be 1 if not specified.';
			
COMMENT ON FUNCTION ST_SetValues(raster , integer , integer , integer , double precision[][] , boolean[][] , boolean ) IS 'args: rast, nband, columnx, rowy, newvalueset, noset=NULL, keepnodata=FALSE - Returns modified raster resulting from setting the values of a given band.';
			
COMMENT ON FUNCTION ST_SetValues(raster , integer , integer , integer , double precision[][] , double precision , boolean ) IS 'args: rast, nband, columnx, rowy, newvalueset, nosetvalue, keepnodata=FALSE - Returns modified raster resulting from setting the values of a given band.';
			
COMMENT ON FUNCTION ST_SetValues(raster , integer , integer , integer , integer , integer , double precision , boolean ) IS 'args: rast, nband, columnx, rowy, width, height, newvalue, keepnodata=FALSE - Returns modified raster resulting from setting the values of a given band.';
			
COMMENT ON FUNCTION ST_SetValues(raster , integer , integer , integer , integer , double precision , boolean ) IS 'args: rast, columnx, rowy, width, height, newvalue, keepnodata=FALSE - Returns modified raster resulting from setting the values of a given band.';
			
COMMENT ON FUNCTION ST_SetValues(raster , integer , geomval[] , boolean ) IS 'args: rast, nband, geomvalset, keepnodata=FALSE - Returns modified raster resulting from setting the values of a given band.';
			
COMMENT ON FUNCTION ST_DumpValues(raster , integer[] , boolean ) IS 'args: rast, nband=NULL, exclude_nodata_value=true - Get the values of the specified band as a 2-dimension array.';
			
COMMENT ON FUNCTION ST_DumpValues(raster , integer , boolean ) IS 'args: rast, nband, exclude_nodata_value=true - Get the values of the specified band as a 2-dimension array.';
			
COMMENT ON FUNCTION ST_PixelOfValue(raster , integer , double precision[] , boolean ) IS 'args: rast, nband, search, exclude_nodata_value=true - Get the columnx, rowy coordinates of the pixel whose value equals the search value.';
			
COMMENT ON FUNCTION ST_PixelOfValue(raster , double precision[] , boolean ) IS 'args: rast, search, exclude_nodata_value=true - Get the columnx, rowy coordinates of the pixel whose value equals the search value.';
			
COMMENT ON FUNCTION ST_PixelOfValue(raster , integer , double precision , boolean ) IS 'args: rast, nband, search, exclude_nodata_value=true - Get the columnx, rowy coordinates of the pixel whose value equals the search value.';
			
COMMENT ON FUNCTION ST_PixelOfValue(raster , double precision , boolean ) IS 'args: rast, search, exclude_nodata_value=true - Get the columnx, rowy coordinates of the pixel whose value equals the search value.';
			
COMMENT ON FUNCTION ST_SetGeoReference(raster , text , text ) IS 'args: rast, georefcoords, format=GDAL - Set Georeference 6 georeference parameters in a single call. Numbers should be separated by white space. Accepts inputs in GDAL or ESRI format. Default is GDAL.';
			
COMMENT ON FUNCTION ST_SetGeoReference(raster , double precision , double precision , double precision , double precision , double precision , double precision ) IS 'args: rast, upperleftx, upperlefty, scalex, scaley, skewx, skewy - Set Georeference 6 georeference parameters in a single call. Numbers should be separated by white space. Accepts inputs in GDAL or ESRI format. Default is GDAL.';
			
COMMENT ON FUNCTION ST_SetRotation(raster, float8) IS 'args: rast, rotation - Set the rotation of the raster in radian.';
			
COMMENT ON FUNCTION ST_SetScale(raster , float8 ) IS 'args: rast, xy - Sets the X and Y size of pixels in units of coordinate reference system. Number units/pixel width/height.';
			
COMMENT ON FUNCTION ST_SetScale(raster , float8 , float8 ) IS 'args: rast, x, y - Sets the X and Y size of pixels in units of coordinate reference system. Number units/pixel width/height.';
			
COMMENT ON FUNCTION ST_SetSkew(raster , float8 ) IS 'args: rast, skewxy - Sets the georeference X and Y skew (or rotation parameter). If only one is passed in, sets X and Y to the same value.';
			
COMMENT ON FUNCTION ST_SetSkew(raster , float8 , float8 ) IS 'args: rast, skewx, skewy - Sets the georeference X and Y skew (or rotation parameter). If only one is passed in, sets X and Y to the same value.';
			
COMMENT ON FUNCTION ST_SetSRID(raster , integer ) IS 'args: rast, srid - Sets the SRID of a raster to a particular integer srid defined in the spatial_ref_sys table.';
			
COMMENT ON FUNCTION ST_SetUpperLeft(raster , double precision , double precision ) IS 'args: rast, x, y - Sets the value of the upper left corner of the pixel of the raster to projected X and Y coordinates.';
			
COMMENT ON FUNCTION ST_Resample(raster , integer , integer , double precision , double precision , double precision , double precision , text , double precision ) IS 'args: rast, width, height, gridx=NULL, gridy=NULL, skewx=0, skewy=0, algorithm=NearestNeighbour, maxerr=0.125 - Resample a raster using a specified resampling algorithm, new dimensions, an arbitrary grid corner and a set of raster georeferencing attributes defined or borrowed from another raster.';
			
COMMENT ON FUNCTION ST_Resample(raster , double precision , double precision , double precision , double precision , double precision , double precision , text , double precision ) IS 'args: rast, scalex=0, scaley=0, gridx=NULL, gridy=NULL, skewx=0, skewy=0, algorithm=NearestNeighbor, maxerr=0.125 - Resample a raster using a specified resampling algorithm, new dimensions, an arbitrary grid corner and a set of raster georeferencing attributes defined or borrowed from another raster.';
			
COMMENT ON FUNCTION ST_Resample(raster , raster , text , double precision , boolean ) IS 'args: rast, ref, algorithm=NearestNeighbour, maxerr=0.125, usescale=true - Resample a raster using a specified resampling algorithm, new dimensions, an arbitrary grid corner and a set of raster georeferencing attributes defined or borrowed from another raster.';
			
COMMENT ON FUNCTION ST_Resample(raster , raster , boolean , text , double precision ) IS 'args: rast, ref, usescale, algorithm=NearestNeighbour, maxerr=0.125 - Resample a raster using a specified resampling algorithm, new dimensions, an arbitrary grid corner and a set of raster georeferencing attributes defined or borrowed from another raster.';
			
COMMENT ON FUNCTION ST_Rescale(raster , double precision , text , double precision ) IS 'args: rast, scalexy, algorithm=NearestNeighbour, maxerr=0.125 - Resample a raster by adjusting only its scale (or pixel size). New pixel values are computed using the NearestNeighbor (english or american spelling), Bilinear, Cubic, CubicSpline or Lanczos resampling algorithm. Default is NearestNeighbor.';
			
COMMENT ON FUNCTION ST_Rescale(raster , double precision , double precision , text , double precision ) IS 'args: rast, scalex, scaley, algorithm=NearestNeighbour, maxerr=0.125 - Resample a raster by adjusting only its scale (or pixel size). New pixel values are computed using the NearestNeighbor (english or american spelling), Bilinear, Cubic, CubicSpline or Lanczos resampling algorithm. Default is NearestNeighbor.';
			
COMMENT ON FUNCTION ST_Reskew(raster , double precision , text , double precision ) IS 'args: rast, skewxy, algorithm=NearestNeighbour, maxerr=0.125 - Resample a raster by adjusting only its skew (or rotation parameters). New pixel values are computed using the NearestNeighbor (english or american spelling), Bilinear, Cubic, CubicSpline or Lanczos resampling algorithm. Default is NearestNeighbor.';
			
COMMENT ON FUNCTION ST_Reskew(raster , double precision , double precision , text , double precision ) IS 'args: rast, skewx, skewy, algorithm=NearestNeighbour, maxerr=0.125 - Resample a raster by adjusting only its skew (or rotation parameters). New pixel values are computed using the NearestNeighbor (english or american spelling), Bilinear, Cubic, CubicSpline or Lanczos resampling algorithm. Default is NearestNeighbor.';
			
COMMENT ON FUNCTION ST_SnapToGrid(raster , double precision , double precision , text , double precision , double precision , double precision ) IS 'args: rast, gridx, gridy, algorithm=NearestNeighbour, maxerr=0.125, scalex=DEFAULT 0, scaley=DEFAULT 0 - Resample a raster by snapping it to a grid. New pixel values are computed using the NearestNeighbor (english or american spelling), Bilinear, Cubic, CubicSpline or Lanczos resampling algorithm. Default is NearestNeighbor.';
			
COMMENT ON FUNCTION ST_SnapToGrid(raster , double precision , double precision , double precision , double precision , text , double precision ) IS 'args: rast, gridx, gridy, scalex, scaley, algorithm=NearestNeighbour, maxerr=0.125 - Resample a raster by snapping it to a grid. New pixel values are computed using the NearestNeighbor (english or american spelling), Bilinear, Cubic, CubicSpline or Lanczos resampling algorithm. Default is NearestNeighbor.';
			
COMMENT ON FUNCTION ST_SnapToGrid(raster , double precision , double precision , double precision , text , double precision ) IS 'args: rast, gridx, gridy, scalexy, algorithm=NearestNeighbour, maxerr=0.125 - Resample a raster by snapping it to a grid. New pixel values are computed using the NearestNeighbor (english or american spelling), Bilinear, Cubic, CubicSpline or Lanczos resampling algorithm. Default is NearestNeighbor.';
			
COMMENT ON FUNCTION ST_Resize(raster , integer , integer , text , double precision ) IS 'args: rast, width, height, algorithm=NearestNeighbor, maxerr=0.125 - Resize a raster to a new width/height';
			
COMMENT ON FUNCTION ST_Resize(raster , double precision , double precision , text , double precision ) IS 'args: rast, percentwidth, percentheight, algorithm=NearestNeighbor, maxerr=0.125 - Resize a raster to a new width/height';
			
COMMENT ON FUNCTION ST_Resize(raster , text , text , text , double precision ) IS 'args: rast, width, height, algorithm=NearestNeighbor, maxerr=0.125 - Resize a raster to a new width/height';
			
COMMENT ON FUNCTION ST_Transform(raster , integer , text , double precision , double precision , double precision ) IS 'args: rast, srid, algorithm=NearestNeighbor, maxerr=0.125, scalex, scaley - Reprojects a raster in a known spatial reference system to another known spatial reference system using specified resampling algorithm. Options are NearestNeighbor, Bilinear, Cubic, CubicSpline, Lanczos defaulting to NearestNeighbor.';
			
COMMENT ON FUNCTION ST_Transform(raster , integer , double precision , double precision , text , double precision ) IS 'args: rast, srid, scalex, scaley, algorithm=NearestNeighbor, maxerr=0.125 - Reprojects a raster in a known spatial reference system to another known spatial reference system using specified resampling algorithm. Options are NearestNeighbor, Bilinear, Cubic, CubicSpline, Lanczos defaulting to NearestNeighbor.';
			
COMMENT ON FUNCTION ST_Transform(raster , raster , text , double precision ) IS 'args: rast, alignto, algorithm=NearestNeighbor, maxerr=0.125 - Reprojects a raster in a known spatial reference system to another known spatial reference system using specified resampling algorithm. Options are NearestNeighbor, Bilinear, Cubic, CubicSpline, Lanczos defaulting to NearestNeighbor.';
			
COMMENT ON FUNCTION ST_SetBandNoDataValue(raster , double precision ) IS 'args: rast, nodatavalue - Sets the value for the given band that represents no data. Band 1 is assumed if no band is specified. To mark a band as having no nodata value, set the nodata value = NULL.';
			
COMMENT ON FUNCTION ST_SetBandNoDataValue(raster , integer , double precision , boolean ) IS 'args: rast, band, nodatavalue, forcechecking=false - Sets the value for the given band that represents no data. Band 1 is assumed if no band is specified. To mark a band as having no nodata value, set the nodata value = NULL.';
			
COMMENT ON FUNCTION ST_SetBandIsNoData(raster , integer ) IS 'args: rast, band=1 - Sets the isnodata flag of the band to TRUE.';
			
COMMENT ON FUNCTION ST_SetBandPath(raster , integer , text , integer , boolean ) IS 'args: rast, band, outdbpath, outdbindex, force=false - Update the external path and band number of an out-db band';
			
COMMENT ON FUNCTION ST_SetBandIndex(raster , integer , integer , boolean ) IS 'args: rast, band, outdbindex, force=false - Update the external band number of an out-db band';
			
COMMENT ON FUNCTION ST_Count(raster , integer , boolean ) IS 'args: rast, nband=1, exclude_nodata_value=true - Returns the number of pixels in a given band of a raster or raster coverage. If no band is specified defaults to band 1. If exclude_nodata_value is set to true, will only count pixels that are not equal to the nodata value.';
			
COMMENT ON FUNCTION ST_Count(raster , boolean ) IS 'args: rast, exclude_nodata_value - Returns the number of pixels in a given band of a raster or raster coverage. If no band is specified defaults to band 1. If exclude_nodata_value is set to true, will only count pixels that are not equal to the nodata value.';
			
COMMENT ON FUNCTION ST_Count(text , text , integer , boolean ) IS 'args: rastertable, rastercolumn, nband=1, exclude_nodata_value=true - Returns the number of pixels in a given band of a raster or raster coverage. If no band is specified defaults to band 1. If exclude_nodata_value is set to true, will only count pixels that are not equal to the nodata value.';
			
COMMENT ON FUNCTION ST_Count(text , text , boolean ) IS 'args: rastertable, rastercolumn, exclude_nodata_value - Returns the number of pixels in a given band of a raster or raster coverage. If no band is specified defaults to band 1. If exclude_nodata_value is set to true, will only count pixels that are not equal to the nodata value.';
			
COMMENT ON FUNCTION ST_CountAgg(raster , integer , boolean , double precision ) IS 'args: rast, nband, exclude_nodata_value, sample_percent - Aggregate. Returns the number of pixels in a given band of a set of rasters. If no band is specified defaults to band 1. If exclude_nodata_value is set to true, will only count pixels that are not equal to the NODATA value.';
			
COMMENT ON FUNCTION ST_CountAgg(raster , integer , boolean ) IS 'args: rast, nband, exclude_nodata_value - Aggregate. Returns the number of pixels in a given band of a set of rasters. If no band is specified defaults to band 1. If exclude_nodata_value is set to true, will only count pixels that are not equal to the NODATA value.';
			
COMMENT ON FUNCTION ST_CountAgg(raster , boolean ) IS 'args: rast, exclude_nodata_value - Aggregate. Returns the number of pixels in a given band of a set of rasters. If no band is specified defaults to band 1. If exclude_nodata_value is set to true, will only count pixels that are not equal to the NODATA value.';
			
COMMENT ON FUNCTION ST_Histogram(raster , integer , boolean , integer , double precision[] , boolean ) IS 'args: rast, nband=1, exclude_nodata_value=true, bins=autocomputed, width=NULL, right=false - Returns a set of record summarizing a raster or raster coverage data distribution separate bin ranges. Number of bins are autocomputed if not specified.';
			
COMMENT ON FUNCTION ST_Histogram(raster , integer , integer , double precision[] , boolean ) IS 'args: rast, nband, bins, width=NULL, right=false - Returns a set of record summarizing a raster or raster coverage data distribution separate bin ranges. Number of bins are autocomputed if not specified.';
			
COMMENT ON FUNCTION ST_Histogram(raster , integer , boolean , integer , boolean ) IS 'args: rast, nband, exclude_nodata_value, bins, right - Returns a set of record summarizing a raster or raster coverage data distribution separate bin ranges. Number of bins are autocomputed if not specified.';
			
COMMENT ON FUNCTION ST_Histogram(raster , integer , integer , boolean ) IS 'args: rast, nband, bins, right - Returns a set of record summarizing a raster or raster coverage data distribution separate bin ranges. Number of bins are autocomputed if not specified.';
			
COMMENT ON FUNCTION ST_Histogram(text , text , integer , integer , boolean ) IS 'args: rastertable, rastercolumn, nband, bins, right - Returns a set of record summarizing a raster or raster coverage data distribution separate bin ranges. Number of bins are autocomputed if not specified.';
			
COMMENT ON FUNCTION ST_Histogram(text , text , integer , boolean , integer , boolean ) IS 'args: rastertable, rastercolumn, nband, exclude_nodata_value, bins, right - Returns a set of record summarizing a raster or raster coverage data distribution separate bin ranges. Number of bins are autocomputed if not specified.';
			
COMMENT ON FUNCTION ST_Histogram(text , text , integer , boolean , integer , double precision[] , boolean ) IS 'args: rastertable, rastercolumn, nband=1, exclude_nodata_value=true, bins=autocomputed, width=NULL, right=false - Returns a set of record summarizing a raster or raster coverage data distribution separate bin ranges. Number of bins are autocomputed if not specified.';
			
COMMENT ON FUNCTION ST_Histogram(text , text , integer , integer , double precision[] , boolean ) IS 'args: rastertable, rastercolumn, nband=1, bins, width=NULL, right=false - Returns a set of record summarizing a raster or raster coverage data distribution separate bin ranges. Number of bins are autocomputed if not specified.';
			
COMMENT ON FUNCTION ST_Quantile(raster , integer , boolean , double precision[] ) IS 'args: rast, nband=1, exclude_nodata_value=true, quantiles=NULL - Compute quantiles for a raster or raster table coverage in the context of the sample or population. Thus, a value could be examined to be at the rasters 25%, 50%, 75% percentile.';
			
COMMENT ON FUNCTION ST_Quantile(raster , double precision[] ) IS 'args: rast, quantiles - Compute quantiles for a raster or raster table coverage in the context of the sample or population. Thus, a value could be examined to be at the rasters 25%, 50%, 75% percentile.';
			
COMMENT ON FUNCTION ST_Quantile(raster , integer , double precision[] ) IS 'args: rast, nband, quantiles - Compute quantiles for a raster or raster table coverage in the context of the sample or population. Thus, a value could be examined to be at the rasters 25%, 50%, 75% percentile.';
			
COMMENT ON FUNCTION ST_Quantile(raster , double precision ) IS 'args: rast, quantile - Compute quantiles for a raster or raster table coverage in the context of the sample or population. Thus, a value could be examined to be at the rasters 25%, 50%, 75% percentile.';
			
COMMENT ON FUNCTION ST_Quantile(raster , boolean , double precision ) IS 'args: rast, exclude_nodata_value, quantile=NULL - Compute quantiles for a raster or raster table coverage in the context of the sample or population. Thus, a value could be examined to be at the rasters 25%, 50%, 75% percentile.';
			
COMMENT ON FUNCTION ST_Quantile(raster , integer , double precision ) IS 'args: rast, nband, quantile - Compute quantiles for a raster or raster table coverage in the context of the sample or population. Thus, a value could be examined to be at the rasters 25%, 50%, 75% percentile.';
			
COMMENT ON FUNCTION ST_Quantile(raster , integer , boolean , double precision ) IS 'args: rast, nband, exclude_nodata_value, quantile - Compute quantiles for a raster or raster table coverage in the context of the sample or population. Thus, a value could be examined to be at the rasters 25%, 50%, 75% percentile.';
			
COMMENT ON FUNCTION ST_Quantile(raster , integer , double precision ) IS 'args: rast, nband, quantile - Compute quantiles for a raster or raster table coverage in the context of the sample or population. Thus, a value could be examined to be at the rasters 25%, 50%, 75% percentile.';
			
COMMENT ON FUNCTION ST_Quantile(text , text , integer , boolean , double precision[] ) IS 'args: rastertable, rastercolumn, nband=1, exclude_nodata_value=true, quantiles=NULL - Compute quantiles for a raster or raster table coverage in the context of the sample or population. Thus, a value could be examined to be at the rasters 25%, 50%, 75% percentile.';
			
COMMENT ON FUNCTION ST_Quantile(text , text , integer , double precision[] ) IS 'args: rastertable, rastercolumn, nband, quantiles - Compute quantiles for a raster or raster table coverage in the context of the sample or population. Thus, a value could be examined to be at the rasters 25%, 50%, 75% percentile.';
			
COMMENT ON FUNCTION ST_SummaryStats(raster , boolean ) IS 'args: rast, exclude_nodata_value - Returns summarystats consisting of count, sum, mean, stddev, min, max for a given raster band of a raster or raster coverage. Band 1 is assumed is no band is specified.';
			
COMMENT ON FUNCTION ST_SummaryStats(raster , integer , boolean ) IS 'args: rast, nband, exclude_nodata_value - Returns summarystats consisting of count, sum, mean, stddev, min, max for a given raster band of a raster or raster coverage. Band 1 is assumed is no band is specified.';
			
COMMENT ON FUNCTION ST_SummaryStats(text , text , boolean ) IS 'args: rastertable, rastercolumn, exclude_nodata_value - Returns summarystats consisting of count, sum, mean, stddev, min, max for a given raster band of a raster or raster coverage. Band 1 is assumed is no band is specified.';
			
COMMENT ON FUNCTION ST_SummaryStats(text , text , integer , boolean ) IS 'args: rastertable, rastercolumn, nband=1, exclude_nodata_value=true - Returns summarystats consisting of count, sum, mean, stddev, min, max for a given raster band of a raster or raster coverage. Band 1 is assumed is no band is specified.';
			
COMMENT ON FUNCTION ST_SummaryStatsAgg(raster , integer , boolean , double precision ) IS 'args: rast, nband, exclude_nodata_value, sample_percent - Aggregate. Returns summarystats consisting of count, sum, mean, stddev, min, max for a given raster band of a set of raster. Band 1 is assumed is no band is specified.';
			
COMMENT ON FUNCTION ST_SummaryStatsAgg(raster , boolean , double precision ) IS 'args: rast, exclude_nodata_value, sample_percent - Aggregate. Returns summarystats consisting of count, sum, mean, stddev, min, max for a given raster band of a set of raster. Band 1 is assumed is no band is specified.';
			
COMMENT ON FUNCTION ST_SummaryStatsAgg(raster , integer , boolean ) IS 'args: rast, nband, exclude_nodata_value - Aggregate. Returns summarystats consisting of count, sum, mean, stddev, min, max for a given raster band of a set of raster. Band 1 is assumed is no band is specified.';
			
COMMENT ON FUNCTION ST_ValueCount(raster , integer , boolean , double precision[] , double precision ) IS 'args: rast, nband=1, exclude_nodata_value=true, searchvalues=NULL, roundto=0, OUT value, OUT count - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';
			
COMMENT ON FUNCTION ST_ValueCount(raster , integer , double precision[] , double precision ) IS 'args: rast, nband, searchvalues, roundto=0, OUT value, OUT count - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';
			
COMMENT ON FUNCTION ST_ValueCount(raster , double precision[] , double precision ) IS 'args: rast, searchvalues, roundto=0, OUT value, OUT count - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';
			
COMMENT ON FUNCTION ST_ValueCount(raster , double precision , double precision ) IS 'args: rast, searchvalue, roundto=0 - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';
			
COMMENT ON FUNCTION ST_ValueCount(raster , integer , boolean , double precision , double precision ) IS 'args: rast, nband, exclude_nodata_value, searchvalue, roundto=0 - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';
			
COMMENT ON FUNCTION ST_ValueCount(raster , integer , double precision , double precision ) IS 'args: rast, nband, searchvalue, roundto=0 - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';
			
COMMENT ON FUNCTION ST_ValueCount(text , text , integer , boolean , double precision[] , double precision ) IS 'args: rastertable, rastercolumn, nband=1, exclude_nodata_value=true, searchvalues=NULL, roundto=0, OUT value, OUT count - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';
			
COMMENT ON FUNCTION ST_ValueCount(text , text , double precision[] , double precision ) IS 'args: rastertable, rastercolumn, searchvalues, roundto=0, OUT value, OUT count - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';
			
COMMENT ON FUNCTION ST_ValueCount(text , text , integer , double precision[] , double precision ) IS 'args: rastertable, rastercolumn, nband, searchvalues, roundto=0, OUT value, OUT count - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';
			
COMMENT ON FUNCTION ST_ValueCount(text , text , integer , boolean , double precision , double precision ) IS 'args: rastertable, rastercolumn, nband, exclude_nodata_value, searchvalue, roundto=0 - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';
			
COMMENT ON FUNCTION ST_ValueCount(text , text , double precision , double precision ) IS 'args: rastertable, rastercolumn, searchvalue, roundto=0 - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';
			
COMMENT ON FUNCTION ST_ValueCount(text , text , integer , double precision , double precision ) IS 'args: rastertable, rastercolumn, nband, searchvalue, roundto=0 - Returns a set of records containing a pixel band value and count of the number of pixels in a given band of a raster (or a raster coverage) that have a given set of values. If no band is specified defaults to band 1. By default nodata value pixels are not counted. and all other values in the pixel are output and pixel band values are rounded to the nearest integer.';
			
COMMENT ON FUNCTION ST_RastFromWKB(bytea ) IS 'args: wkb - Return a raster value from a Well-Known Binary (WKB) raster.';
			
COMMENT ON FUNCTION ST_RastFromHexWKB(text ) IS 'args: wkb - Return a raster value from a Hex representation of Well-Known Binary (WKB) raster.';
			
COMMENT ON FUNCTION ST_AsBinary(raster , boolean ) IS 'args: rast, outasin=FALSE - Return the Well-Known Binary (WKB) representation of the raster.';
			
COMMENT ON FUNCTION ST_AsWKB(raster , boolean ) IS 'args: rast, outasin=FALSE - Return the Well-Known Binary (WKB) representation of the raster.';
			
COMMENT ON FUNCTION ST_AsHexWKB(raster , boolean ) IS 'args: rast, outasin=FALSE - Return the Well-Known Binary (WKB) in Hex representation of the raster.';
			
COMMENT ON FUNCTION ST_AsGDALRaster(raster , text , text[] , integer ) IS 'args: rast, format, options=NULL, srid=sameassource - Return the raster tile in the designated GDAL Raster format. Raster formats are one of those supported by your compiled library. Use ST_GDALDrivers() to get a list of formats supported by your library.';
			
COMMENT ON FUNCTION ST_AsJPEG(raster , text[] ) IS 'args: rast, options=NULL - Return the raster tile selected bands as a single Joint Photographic Exports Group (JPEG) image (byte array). If no band is specified and 1 or more than 3 bands, then only the first band is used. If only 3 bands then all 3 bands are used and mapped to RGB.';
			
COMMENT ON FUNCTION ST_AsJPEG(raster , integer , integer ) IS 'args: rast, nband, quality - Return the raster tile selected bands as a single Joint Photographic Exports Group (JPEG) image (byte array). If no band is specified and 1 or more than 3 bands, then only the first band is used. If only 3 bands then all 3 bands are used and mapped to RGB.';
			
COMMENT ON FUNCTION ST_AsJPEG(raster , integer , text[] ) IS 'args: rast, nband, options=NULL - Return the raster tile selected bands as a single Joint Photographic Exports Group (JPEG) image (byte array). If no band is specified and 1 or more than 3 bands, then only the first band is used. If only 3 bands then all 3 bands are used and mapped to RGB.';
			
COMMENT ON FUNCTION ST_AsJPEG(raster , integer[] , text[] ) IS 'args: rast, nbands, options=NULL - Return the raster tile selected bands as a single Joint Photographic Exports Group (JPEG) image (byte array). If no band is specified and 1 or more than 3 bands, then only the first band is used. If only 3 bands then all 3 bands are used and mapped to RGB.';
			
COMMENT ON FUNCTION ST_AsJPEG(raster , integer[] , integer ) IS 'args: rast, nbands, quality - Return the raster tile selected bands as a single Joint Photographic Exports Group (JPEG) image (byte array). If no band is specified and 1 or more than 3 bands, then only the first band is used. If only 3 bands then all 3 bands are used and mapped to RGB.';
			
COMMENT ON FUNCTION ST_AsPNG(raster , text[] ) IS 'args: rast, options=NULL - Return the raster tile selected bands as a single portable network graphics (PNG) image (byte array). If 1, 3, or 4 bands in raster and no bands are specified, then all bands are used. If more 2 or more than 4 bands and no bands specified, then only band 1 is used. Bands are mapped to RGB or RGBA space.';
			
COMMENT ON FUNCTION ST_AsPNG(raster , integer , integer ) IS 'args: rast, nband, compression - Return the raster tile selected bands as a single portable network graphics (PNG) image (byte array). If 1, 3, or 4 bands in raster and no bands are specified, then all bands are used. If more 2 or more than 4 bands and no bands specified, then only band 1 is used. Bands are mapped to RGB or RGBA space.';
			
COMMENT ON FUNCTION ST_AsPNG(raster , integer , text[] ) IS 'args: rast, nband, options=NULL - Return the raster tile selected bands as a single portable network graphics (PNG) image (byte array). If 1, 3, or 4 bands in raster and no bands are specified, then all bands are used. If more 2 or more than 4 bands and no bands specified, then only band 1 is used. Bands are mapped to RGB or RGBA space.';
			
COMMENT ON FUNCTION ST_AsPNG(raster , integer[] , integer ) IS 'args: rast, nbands, compression - Return the raster tile selected bands as a single portable network graphics (PNG) image (byte array). If 1, 3, or 4 bands in raster and no bands are specified, then all bands are used. If more 2 or more than 4 bands and no bands specified, then only band 1 is used. Bands are mapped to RGB or RGBA space.';
			
COMMENT ON FUNCTION ST_AsPNG(raster , integer[] , text[] ) IS 'args: rast, nbands, options=NULL - Return the raster tile selected bands as a single portable network graphics (PNG) image (byte array). If 1, 3, or 4 bands in raster and no bands are specified, then all bands are used. If more 2 or more than 4 bands and no bands specified, then only band 1 is used. Bands are mapped to RGB or RGBA space.';
			
COMMENT ON FUNCTION ST_AsTIFF(raster , text[] , integer ) IS 'args: rast, options='', srid=sameassource - Return the raster selected bands as a single TIFF image (byte array). If no band is specified or any of specified bands does not exist in the raster, then will try to use all bands.';
			
COMMENT ON FUNCTION ST_AsTIFF(raster , text , integer ) IS 'args: rast, compression='', srid=sameassource - Return the raster selected bands as a single TIFF image (byte array). If no band is specified or any of specified bands does not exist in the raster, then will try to use all bands.';
			
COMMENT ON FUNCTION ST_AsTIFF(raster , integer[] , text , integer ) IS 'args: rast, nbands, compression='', srid=sameassource - Return the raster selected bands as a single TIFF image (byte array). If no band is specified or any of specified bands does not exist in the raster, then will try to use all bands.';
			
COMMENT ON FUNCTION ST_AsTIFF(raster , integer[] , text[] , integer ) IS 'args: rast, nbands, options, srid=sameassource - Return the raster selected bands as a single TIFF image (byte array). If no band is specified or any of specified bands does not exist in the raster, then will try to use all bands.';
			
COMMENT ON FUNCTION ST_Contains(raster , integer , raster , integer ) IS 'args: rastA, nbandA, rastB, nbandB - Return true if no points of raster rastB lie in the exterior of raster rastA and at least one point of the interior of rastB lies in the interior of rastA.';
			
COMMENT ON FUNCTION ST_Contains(raster , raster ) IS 'args: rastA, rastB - Return true if no points of raster rastB lie in the exterior of raster rastA and at least one point of the interior of rastB lies in the interior of rastA.';
			
COMMENT ON FUNCTION ST_ContainsProperly(raster , integer , raster , integer ) IS 'args: rastA, nbandA, rastB, nbandB - Return true if rastB intersects the interior of rastA but not the boundary or exterior of rastA.';
			
COMMENT ON FUNCTION ST_ContainsProperly(raster , raster ) IS 'args: rastA, rastB - Return true if rastB intersects the interior of rastA but not the boundary or exterior of rastA.';
			
COMMENT ON FUNCTION ST_Covers(raster , integer , raster , integer ) IS 'args: rastA, nbandA, rastB, nbandB - Return true if no points of raster rastB lie outside raster rastA.';
			
COMMENT ON FUNCTION ST_Covers(raster , raster ) IS 'args: rastA, rastB - Return true if no points of raster rastB lie outside raster rastA.';
			
COMMENT ON FUNCTION ST_CoveredBy(raster , integer , raster , integer ) IS 'args: rastA, nbandA, rastB, nbandB - Return true if no points of raster rastA lie outside raster rastB.';
			
COMMENT ON FUNCTION ST_CoveredBy(raster , raster ) IS 'args: rastA, rastB - Return true if no points of raster rastA lie outside raster rastB.';
			
COMMENT ON FUNCTION ST_Disjoint(raster , integer , raster , integer ) IS 'args: rastA, nbandA, rastB, nbandB - Return true if raster rastA does not spatially intersect rastB.';
			
COMMENT ON FUNCTION ST_Disjoint(raster , raster ) IS 'args: rastA, rastB - Return true if raster rastA does not spatially intersect rastB.';
			
COMMENT ON FUNCTION ST_Intersects(raster , integer , raster , integer ) IS 'args: rastA, nbandA, rastB, nbandB - Return true if raster rastA spatially intersects raster rastB.';
			
COMMENT ON FUNCTION ST_Intersects(raster , raster ) IS 'args: rastA, rastB - Return true if raster rastA spatially intersects raster rastB.';
			
COMMENT ON FUNCTION ST_Intersects(raster , integer , geometry ) IS 'args: rast, nband, geommin - Return true if raster rastA spatially intersects raster rastB.';
			
COMMENT ON FUNCTION ST_Intersects(raster , geometry , integer ) IS 'args: rast, geommin, nband=NULL - Return true if raster rastA spatially intersects raster rastB.';
			
COMMENT ON FUNCTION ST_Intersects(geometry , raster , integer ) IS 'args: geommin, rast, nband=NULL - Return true if raster rastA spatially intersects raster rastB.';
			
COMMENT ON FUNCTION ST_Overlaps(raster , integer , raster , integer ) IS 'args: rastA, nbandA, rastB, nbandB - Return true if raster rastA and rastB intersect but one does not completely contain the other.';
			
COMMENT ON FUNCTION ST_Overlaps(raster , raster ) IS 'args: rastA, rastB - Return true if raster rastA and rastB intersect but one does not completely contain the other.';
			
COMMENT ON FUNCTION ST_Touches(raster , integer , raster , integer ) IS 'args: rastA, nbandA, rastB, nbandB - Return true if raster rastA and rastB have at least one point in common but their interiors do not intersect.';
			
COMMENT ON FUNCTION ST_Touches(raster , raster ) IS 'args: rastA, rastB - Return true if raster rastA and rastB have at least one point in common but their interiors do not intersect.';
			
COMMENT ON FUNCTION ST_SameAlignment(raster , raster ) IS 'args: rastA, rastB - Returns true if rasters have same skew, scale, spatial ref, and offset (pixels can be put on same grid without cutting into pixels) and false if they dont with notice detailing issue.';
			
COMMENT ON FUNCTION ST_SameAlignment(double precision , double precision , double precision , double precision , double precision , double precision , double precision , double precision , double precision , double precision , double precision , double precision ) IS 'args: ulx1, uly1, scalex1, scaley1, skewx1, skewy1, ulx2, uly2, scalex2, scaley2, skewx2, skewy2 - Returns true if rasters have same skew, scale, spatial ref, and offset (pixels can be put on same grid without cutting into pixels) and false if they dont with notice detailing issue.';
			
COMMENT ON AGGREGATE ST_SameAlignment(raster) IS 'args: rastfield - Returns true if rasters have same skew, scale, spatial ref, and offset (pixels can be put on same grid without cutting into pixels) and false if they dont with notice detailing issue.';
			
COMMENT ON FUNCTION ST_NotSameAlignmentReason(raster , raster ) IS 'args: rastA, rastB - Returns text stating if rasters are aligned and if not aligned, a reason why.';
			
COMMENT ON FUNCTION ST_Within(raster , integer , raster , integer ) IS 'args: rastA, nbandA, rastB, nbandB - Return true if no points of raster rastA lie in the exterior of raster rastB and at least one point of the interior of rastA lies in the interior of rastB.';
			
COMMENT ON FUNCTION ST_Within(raster , raster ) IS 'args: rastA, rastB - Return true if no points of raster rastA lie in the exterior of raster rastB and at least one point of the interior of rastA lies in the interior of rastB.';
			
COMMENT ON FUNCTION ST_DWithin(raster , integer , raster , integer , double precision ) IS 'args: rastA, nbandA, rastB, nbandB, distance_of_srid - Return true if rasters rastA and rastB are within the specified distance of each other.';
			
COMMENT ON FUNCTION ST_DWithin(raster , raster , double precision ) IS 'args: rastA, rastB, distance_of_srid - Return true if rasters rastA and rastB are within the specified distance of each other.';
			
COMMENT ON FUNCTION ST_DFullyWithin(raster , integer , raster , integer , double precision ) IS 'args: rastA, nbandA, rastB, nbandB, distance_of_srid - Return true if rasters rastA and rastB are fully within the specified distance of each other.';
			
COMMENT ON FUNCTION ST_DFullyWithin(raster , raster , double precision ) IS 'args: rastA, rastB, distance_of_srid - Return true if rasters rastA and rastB are fully within the specified distance of each other.';
			
    COMMENT ON TYPE geomval IS 'postgis raster type: A spatial datatype with two fields - geom (holding a geometry object) and val (holding a double precision pixel value from a raster band).';
            
        
    COMMENT ON TYPE addbandarg IS 'postgis raster type: A composite type used as input into the ST_AddBand function defining the attributes and initial value of the new band.';
            
        
    COMMENT ON TYPE rastbandarg IS 'postgis raster type: A composite type for use when needing to express a raster and a band index of that raster.';
            
        
    COMMENT ON TYPE raster IS 'postgis raster type: raster spatial data type.';
            
        
    COMMENT ON TYPE reclassarg IS 'postgis raster type: A composite type used as input into the ST_Reclass function defining the behavior of reclassification.';
            
        
    COMMENT ON TYPE summarystats IS 'postgis raster type: A composite type returned by the ST_SummaryStats and ST_SummaryStatsAgg functions.';
            
        
    COMMENT ON TYPE unionarg IS 'postgis raster type: A composite type used as input into the ST_Union function defining the bands to be processed and behavior of the UNION operation.';
            
        
	COMMENT ON TYPE box2d IS 'postgis type: A box composed of x min, ymin, xmax, ymax. Often used to return the 2d enclosing box of a geometry.';

	COMMENT ON TYPE box3d IS 'postgis type: A box composed of x min, ymin, zmin, xmax, ymax, zmax. Often used to return the 3d extent of a geometry or collection of geometries.';

	COMMENT ON TYPE geometry IS 'postgis type: Planar spatial data type.';

	COMMENT ON TYPE geometry_dump IS 'postgis type: A spatial datatype with two fields - geom (holding a geometry object) and path[] (a 1-d array holding the position of the geometry within the dumped object.)';

	COMMENT ON TYPE geography IS 'postgis type: Ellipsoidal spatial data type.';

COMMENT ON FUNCTION AddGeometryColumn(varchar , varchar , integer , varchar , integer , boolean ) IS 'args: table_name, column_name, srid, type, dimension, use_typmod=true - Adds a geometry column to an existing table of attributes. By default uses type modifier to define rather than constraints. Pass in false for use_typmod to get old check constraint based behavior';
			
COMMENT ON FUNCTION AddGeometryColumn(varchar , varchar , varchar , integer , varchar , integer , boolean ) IS 'args: schema_name, table_name, column_name, srid, type, dimension, use_typmod=true - Adds a geometry column to an existing table of attributes. By default uses type modifier to define rather than constraints. Pass in false for use_typmod to get old check constraint based behavior';
			
COMMENT ON FUNCTION AddGeometryColumn(varchar , varchar , varchar , varchar , integer , varchar , integer , boolean ) IS 'args: catalog_name, schema_name, table_name, column_name, srid, type, dimension, use_typmod=true - Adds a geometry column to an existing table of attributes. By default uses type modifier to define rather than constraints. Pass in false for use_typmod to get old check constraint based behavior';
			
COMMENT ON FUNCTION DropGeometryColumn(varchar , varchar ) IS 'args: table_name, column_name - Removes a geometry column from a spatial table.';
			
COMMENT ON FUNCTION DropGeometryColumn(varchar , varchar , varchar ) IS 'args: schema_name, table_name, column_name - Removes a geometry column from a spatial table.';
			
COMMENT ON FUNCTION DropGeometryColumn(varchar , varchar , varchar , varchar ) IS 'args: catalog_name, schema_name, table_name, column_name - Removes a geometry column from a spatial table.';
			
COMMENT ON FUNCTION DropGeometryTable(varchar ) IS 'args: table_name - Drops a table and all its references in geometry_columns.';
			
COMMENT ON FUNCTION DropGeometryTable(varchar , varchar ) IS 'args: schema_name, table_name - Drops a table and all its references in geometry_columns.';
			
COMMENT ON FUNCTION DropGeometryTable(varchar , varchar , varchar ) IS 'args: catalog_name, schema_name, table_name - Drops a table and all its references in geometry_columns.';
			
COMMENT ON FUNCTION PostGIS_Extensions_Upgrade() IS 'Upgrades installed postgis packaged extensions (e.g. postgis_sfcgal, postgis_topology, postgis_sfcgal) to latest installed version. Reports full postgis version and build configuration infos after.';
			
COMMENT ON FUNCTION PostGIS_Full_Version() IS 'Reports full postgis version and build configuration infos.';
			
COMMENT ON FUNCTION PostGIS_GEOS_Version() IS 'Returns the version number of the GEOS library.';
			
COMMENT ON FUNCTION PostGIS_Liblwgeom_Version() IS 'Returns the version number of the liblwgeom library. This should match the version of PostGIS.';
			
COMMENT ON FUNCTION PostGIS_LibXML_Version() IS 'Returns the version number of the libxml2 library.';
			
COMMENT ON FUNCTION PostGIS_Lib_Build_Date() IS 'Returns build date of the PostGIS library.';
			
COMMENT ON FUNCTION PostGIS_Lib_Version() IS 'Returns the version number of the PostGIS library.';
			
COMMENT ON FUNCTION PostGIS_PROJ_Version() IS 'Returns the version number of the PROJ4 library.';
			
COMMENT ON FUNCTION PostGIS_Scripts_Build_Date() IS 'Returns build date of the PostGIS scripts.';
			
COMMENT ON FUNCTION PostGIS_Scripts_Installed() IS 'Returns version of the postgis scripts installed in this database.';
			
COMMENT ON FUNCTION PostGIS_Scripts_Released() IS 'Returns the version number of the postgis.sql script released with the installed postgis lib.';
			
COMMENT ON FUNCTION PostGIS_Version() IS 'Returns PostGIS version number and compile-time options.';
			
COMMENT ON FUNCTION Populate_Geometry_Columns(boolean ) IS 'args: use_typmod=true - Ensures geometry columns are defined with type modifiers or have appropriate spatial constraints This ensures they will be registered correctly in geometry_columns view. By default will convert all geometry columns with no type modifier to ones with type modifiers. To get old behavior set use_typmod=false';
			
COMMENT ON FUNCTION Populate_Geometry_Columns(oid, boolean ) IS 'args: relation_oid, use_typmod=true - Ensures geometry columns are defined with type modifiers or have appropriate spatial constraints This ensures they will be registered correctly in geometry_columns view. By default will convert all geometry columns with no type modifier to ones with type modifiers. To get old behavior set use_typmod=false';
			
COMMENT ON FUNCTION UpdateGeometrySRID(varchar , varchar , integer ) IS 'args: table_name, column_name, srid - Updates the SRID of all features in a geometry column, geometry_columns metadata and srid. If it was enforced with constraints, the constraints will be updated with new srid constraint. If the old was enforced by type definition, the type definition will be changed.';
			
COMMENT ON FUNCTION UpdateGeometrySRID(varchar , varchar , varchar , integer ) IS 'args: schema_name, table_name, column_name, srid - Updates the SRID of all features in a geometry column, geometry_columns metadata and srid. If it was enforced with constraints, the constraints will be updated with new srid constraint. If the old was enforced by type definition, the type definition will be changed.';
			
COMMENT ON FUNCTION UpdateGeometrySRID(varchar , varchar , varchar , varchar , integer ) IS 'args: catalog_name, schema_name, table_name, column_name, srid - Updates the SRID of all features in a geometry column, geometry_columns metadata and srid. If it was enforced with constraints, the constraints will be updated with new srid constraint. If the old was enforced by type definition, the type definition will be changed.';
			
COMMENT ON FUNCTION ST_BdPolyFromText(text , integer ) IS 'args: WKT, srid - Construct a Polygon given an arbitrary collection of closed linestrings as a MultiLineString Well-Known text representation.';
			
COMMENT ON FUNCTION ST_BdMPolyFromText(text , integer ) IS 'args: WKT, srid - Construct a MultiPolygon given an arbitrary collection of closed linestrings as a MultiLineString text representation Well-Known text representation.';
			
COMMENT ON FUNCTION ST_Box2dFromGeoHash(text , integer ) IS 'args: geohash, precision=full_precision_of_geohash - Return a BOX2D from a GeoHash string.';
			
COMMENT ON FUNCTION ST_GeogFromText(text ) IS 'args: EWKT - Return a specified geography value from Well-Known Text representation or extended (WKT).';
			
COMMENT ON FUNCTION ST_GeographyFromText(text ) IS 'args: EWKT - Return a specified geography value from Well-Known Text representation or extended (WKT).';
			
COMMENT ON FUNCTION ST_GeogFromWKB(bytea ) IS 'args: wkb - Creates a geography instance from a Well-Known Binary geometry representation (WKB) or extended Well Known Binary (EWKB).';
			
COMMENT ON FUNCTION ST_GeomFromTWKB(bytea ) IS 'args: twkb - Creates a geometry instance from a TWKB ("Tiny Well-Known Binary") geometry representation.';
			
COMMENT ON FUNCTION ST_GeomCollFromText(text , integer ) IS 'args: WKT, srid - Makes a collection Geometry from collection WKT with the given SRID. If SRID is not given, it defaults to 0.';
			
COMMENT ON FUNCTION ST_GeomCollFromText(text ) IS 'args: WKT - Makes a collection Geometry from collection WKT with the given SRID. If SRID is not given, it defaults to 0.';
			
COMMENT ON FUNCTION ST_GeomFromEWKB(bytea ) IS 'args: EWKB - Return a specified ST_Geometry value from Extended Well-Known Binary representation (EWKB).';
			
COMMENT ON FUNCTION ST_GeomFromEWKT(text ) IS 'args: EWKT - Return a specified ST_Geometry value from Extended Well-Known Text representation (EWKT).';
			
COMMENT ON FUNCTION ST_GeometryFromText(text ) IS 'args: WKT - Return a specified ST_Geometry value from Well-Known Text representation (WKT). This is an alias name for ST_GeomFromText';
			
COMMENT ON FUNCTION ST_GeometryFromText(text , integer ) IS 'args: WKT, srid - Return a specified ST_Geometry value from Well-Known Text representation (WKT). This is an alias name for ST_GeomFromText';
			
COMMENT ON FUNCTION ST_GeomFromGeoHash(text , integer ) IS 'args: geohash, precision=full_precision_of_geohash - Return a geometry from a GeoHash string.';
			
COMMENT ON FUNCTION ST_GeomFromGML(text ) IS 'args: geomgml - Takes as input GML representation of geometry and outputs a PostGIS geometry object';
			
COMMENT ON FUNCTION ST_GeomFromGML(text , integer ) IS 'args: geomgml, srid - Takes as input GML representation of geometry and outputs a PostGIS geometry object';
			
COMMENT ON FUNCTION ST_GeomFromGeoJSON(text ) IS 'args: geomjson - Takes as input a geojson representation of a geometry and outputs a PostGIS geometry object';
			
COMMENT ON FUNCTION ST_GeomFromGeoJSON(json ) IS 'args: geomjson - Takes as input a geojson representation of a geometry and outputs a PostGIS geometry object';
			
COMMENT ON FUNCTION ST_GeomFromGeoJSON(jsonb ) IS 'args: geomjson - Takes as input a geojson representation of a geometry and outputs a PostGIS geometry object';
			
COMMENT ON FUNCTION ST_GeomFromKML(text ) IS 'args: geomkml - Takes as input KML representation of geometry and outputs a PostGIS geometry object';
			
COMMENT ON FUNCTION ST_GMLToSQL(text ) IS 'args: geomgml - Return a specified ST_Geometry value from GML representation. This is an alias name for ST_GeomFromGML';
			
COMMENT ON FUNCTION ST_GMLToSQL(text , integer ) IS 'args: geomgml, srid - Return a specified ST_Geometry value from GML representation. This is an alias name for ST_GeomFromGML';
			
COMMENT ON FUNCTION ST_GeomFromText(text ) IS 'args: WKT - Return a specified ST_Geometry value from Well-Known Text representation (WKT).';
			
COMMENT ON FUNCTION ST_GeomFromText(text , integer ) IS 'args: WKT, srid - Return a specified ST_Geometry value from Well-Known Text representation (WKT).';
			
COMMENT ON FUNCTION ST_GeomFromWKB(bytea ) IS 'args: geom - Creates a geometry instance from a Well-Known Binary geometry representation (WKB) and optional SRID.';
			
COMMENT ON FUNCTION ST_GeomFromWKB(bytea , integer ) IS 'args: geom, srid - Creates a geometry instance from a Well-Known Binary geometry representation (WKB) and optional SRID.';
			
COMMENT ON FUNCTION ST_LineFromEncodedPolyline(text , integer ) IS 'args: polyline, precision=5 - Creates a LineString from an Encoded Polyline.';
			
COMMENT ON FUNCTION ST_LineFromMultiPoint(geometry ) IS 'args: aMultiPoint - Creates a LineString from a MultiPoint geometry.';
			
COMMENT ON FUNCTION ST_LineFromText(text ) IS 'args: WKT - Makes a Geometry from WKT representation with the given SRID. If SRID is not given, it defaults to 0.';
			
COMMENT ON FUNCTION ST_LineFromText(text , integer ) IS 'args: WKT, srid - Makes a Geometry from WKT representation with the given SRID. If SRID is not given, it defaults to 0.';
			
COMMENT ON FUNCTION ST_LineFromWKB(bytea ) IS 'args: WKB - Makes a LINESTRING from WKB with the given SRID';
			
COMMENT ON FUNCTION ST_LineFromWKB(bytea , integer ) IS 'args: WKB, srid - Makes a LINESTRING from WKB with the given SRID';
			
COMMENT ON FUNCTION ST_LinestringFromWKB(bytea ) IS 'args: WKB - Makes a geometry from WKB with the given SRID.';
			
COMMENT ON FUNCTION ST_LinestringFromWKB(bytea , integer ) IS 'args: WKB, srid - Makes a geometry from WKB with the given SRID.';
			
COMMENT ON FUNCTION ST_MakeBox2D(geometry , geometry ) IS 'args: pointLowLeft, pointUpRight - Creates a BOX2D defined by the given point geometries.';
			
COMMENT ON FUNCTION ST_3DMakeBox(geometry , geometry ) IS 'args: point3DLowLeftBottom, point3DUpRightTop - Creates a BOX3D defined by the given 3d point geometries.';
			
COMMENT ON AGGREGATE ST_MakeLine(geometry) IS 'args: geoms - Creates a Linestring from point, multipoint, or line geometries.';
			
COMMENT ON FUNCTION ST_MakeLine(geometry, geometry) IS 'args: geom1, geom2 - Creates a Linestring from point, multipoint, or line geometries.';
			
COMMENT ON FUNCTION ST_MakeLine(geometry[]) IS 'args: geoms_array - Creates a Linestring from point, multipoint, or line geometries.';
			
COMMENT ON FUNCTION ST_MakeEnvelope(double precision, double precision, double precision, double precision, integer ) IS 'args: xmin, ymin, xmax, ymax, srid=unknown - Creates a rectangular Polygon formed from the given minimums and maximums. Input values must be in SRS specified by the SRID.';
			
COMMENT ON FUNCTION ST_MakePolygon(geometry) IS 'args: linestring - Creates a Polygon formed by the given shell. Input geometries must be closed LINESTRINGS.';
			
COMMENT ON FUNCTION ST_MakePolygon(geometry, geometry[]) IS 'args: outerlinestring, interiorlinestrings - Creates a Polygon formed by the given shell. Input geometries must be closed LINESTRINGS.';
			
COMMENT ON FUNCTION ST_MakePoint(double precision, double precision) IS 'args: x, y - Creates a 2D, 3DZ or 4D point geometry.';
			
COMMENT ON FUNCTION ST_MakePoint(double precision, double precision, double precision) IS 'args: x, y, z - Creates a 2D, 3DZ or 4D point geometry.';
			
COMMENT ON FUNCTION ST_MakePoint(double precision, double precision, double precision, double precision) IS 'args: x, y, z, m - Creates a 2D, 3DZ or 4D point geometry.';
			
COMMENT ON FUNCTION ST_MakePointM(float, float, float) IS 'args: x, y, m - Creates a point geometry with an x y and m coordinate.';
			
COMMENT ON FUNCTION ST_MLineFromText(text , integer ) IS 'args: WKT, srid - Return a specified ST_MultiLineString value from WKT representation.';
			
COMMENT ON FUNCTION ST_MLineFromText(text ) IS 'args: WKT - Return a specified ST_MultiLineString value from WKT representation.';
			
COMMENT ON FUNCTION ST_MPointFromText(text , integer ) IS 'args: WKT, srid - Makes a Geometry from WKT with the given SRID. If SRID is not given, it defaults to 0.';
			
COMMENT ON FUNCTION ST_MPointFromText(text ) IS 'args: WKT - Makes a Geometry from WKT with the given SRID. If SRID is not given, it defaults to 0.';
			
COMMENT ON FUNCTION ST_MPolyFromText(text , integer ) IS 'args: WKT, srid - Makes a MultiPolygon Geometry from WKT with the given SRID. If SRID is not given, it defaults to 0.';
			
COMMENT ON FUNCTION ST_MPolyFromText(text ) IS 'args: WKT - Makes a MultiPolygon Geometry from WKT with the given SRID. If SRID is not given, it defaults to 0.';
			
COMMENT ON FUNCTION ST_Point(float , float ) IS 'args: x_lon, y_lat - Returns an ST_Point with the given coordinate values. OGC alias for ST_MakePoint.';
			
COMMENT ON FUNCTION ST_PointFromGeoHash(text , integer ) IS 'args: geohash, precision=full_precision_of_geohash - Return a point from a GeoHash string.';
			
COMMENT ON FUNCTION ST_PointFromText(text ) IS 'args: WKT - Makes a point Geometry from WKT with the given SRID. If SRID is not given, it defaults to unknown.';
			
COMMENT ON FUNCTION ST_PointFromText(text , integer ) IS 'args: WKT, srid - Makes a point Geometry from WKT with the given SRID. If SRID is not given, it defaults to unknown.';
			
COMMENT ON FUNCTION ST_GeomFromWKB(bytea ) IS 'args: geom - Makes a geometry from WKB with the given SRID';
			
COMMENT ON FUNCTION ST_GeomFromWKB(bytea , integer ) IS 'args: geom, srid - Makes a geometry from WKB with the given SRID';
			
COMMENT ON FUNCTION ST_Polygon(geometry , integer ) IS 'args: aLineString, srid - Returns a polygon built from the specified linestring and SRID.';
			
COMMENT ON FUNCTION ST_PolygonFromText(text ) IS 'args: WKT - Makes a Geometry from WKT with the given SRID. If SRID is not given, it defaults to 0.';
			
COMMENT ON FUNCTION ST_PolygonFromText(text , integer ) IS 'args: WKT, srid - Makes a Geometry from WKT with the given SRID. If SRID is not given, it defaults to 0.';
			
COMMENT ON FUNCTION ST_WKBToSQL(bytea ) IS 'args: WKB - Return a specified ST_Geometry value from Well-Known Binary representation (WKB). This is an alias name for ST_GeomFromWKB that takes no srid';
			
COMMENT ON FUNCTION ST_WKTToSQL(text ) IS 'args: WKT - Return a specified ST_Geometry value from Well-Known Text representation (WKT). This is an alias name for ST_GeomFromText';
			
COMMENT ON FUNCTION GeometryType(geometry ) IS 'args: geomA - Returns the type of the geometry as a string. Eg: LINESTRING, POLYGON, MULTIPOINT, etc.';
			
COMMENT ON FUNCTION ST_Boundary(geometry ) IS 'args: geomA - Returns the closure of the combinatorial boundary of this Geometry.';
			
COMMENT ON FUNCTION ST_CoordDim(geometry ) IS 'args: geomA - Return the coordinate dimension of the ST_Geometry value.';
			
COMMENT ON FUNCTION ST_Dimension(geometry ) IS 'args: g - The inherent dimension of this Geometry object, which must be less than or equal to the coordinate dimension.';
			
COMMENT ON FUNCTION ST_EndPoint(geometry ) IS 'args: g - Returns the last point of a LINESTRING or CIRCULARLINESTRING geometry as a POINT.';
			
COMMENT ON FUNCTION ST_Envelope(geometry ) IS 'args: g1 - Returns a geometry representing the double precision (float8) bounding box of the supplied geometry.';
			
COMMENT ON FUNCTION ST_BoundingDiagonal(geometry , boolean ) IS 'args: geom, fits=false - Returns the diagonal of the supplied geometrys bounding box.';
			
COMMENT ON FUNCTION ST_ExteriorRing(geometry ) IS 'args: a_polygon - Returns a line string representing the exterior ring of the POLYGON geometry. Return NULL if the geometry is not a polygon. Will not work with MULTIPOLYGON';
			
COMMENT ON FUNCTION ST_GeometryN(geometry , integer ) IS 'args: geomA, n - Return the 1-based Nth geometry if the geometry is a GEOMETRYCOLLECTION, (MULTI)POINT, (MULTI)LINESTRING, MULTICURVE or (MULTI)POLYGON, POLYHEDRALSURFACE Otherwise, return NULL.';
			
COMMENT ON FUNCTION ST_GeometryType(geometry ) IS 'args: g1 - Return the geometry type of the ST_Geometry value.';
			
COMMENT ON FUNCTION ST_InteriorRingN(geometry , integer ) IS 'args: a_polygon, n - Return the Nth interior linestring ring of the polygon geometry. Return NULL if the geometry is not a polygon or the given N is out of range.';
			
COMMENT ON FUNCTION ST_IsPolygonCCW(geometry) IS 'args: geom - Returns true if all exterior rings are oriented counter-clockwise and all interior rings are oriented clockwise.';
			
COMMENT ON FUNCTION ST_IsPolygonCW(geometry) IS 'args: geom - Returns true if all exterior rings are oriented clockwise and all interior rings are oriented counter-clockwise.';
			
COMMENT ON FUNCTION ST_IsClosed(geometry ) IS 'args: g - Returns TRUE if the LINESTRINGs start and end points are coincident. For Polyhedral surface is closed (volumetric).';
			
COMMENT ON FUNCTION ST_IsCollection(geometry ) IS 'args: g - Returns TRUE if the argument is a collection (MULTI*, GEOMETRYCOLLECTION, ...)';
			
COMMENT ON FUNCTION ST_IsEmpty(geometry ) IS 'args: geomA - Returns true if this Geometry is an empty geometrycollection, polygon, point etc.';
			
COMMENT ON FUNCTION ST_IsRing(geometry ) IS 'args: g - Returns TRUE if this LINESTRING is both closed and simple.';
			
COMMENT ON FUNCTION ST_IsSimple(geometry ) IS 'args: geomA - Returns (TRUE) if this Geometry has no anomalous geometric points, such as self intersection or self tangency.';
			
COMMENT ON FUNCTION ST_IsValid(geometry ) IS 'args: g - Returns true if the ST_Geometry is well formed.';
			
COMMENT ON FUNCTION ST_IsValid(geometry , integer ) IS 'args: g, flags - Returns true if the ST_Geometry is well formed.';
			
COMMENT ON FUNCTION ST_IsValidReason(geometry ) IS 'args: geomA - Returns text stating if a geometry is valid or not and if not valid, a reason why.';
			
COMMENT ON FUNCTION ST_IsValidReason(geometry , integer ) IS 'args: geomA, flags - Returns text stating if a geometry is valid or not and if not valid, a reason why.';
			
COMMENT ON FUNCTION ST_IsValidDetail(geometry ) IS 'args: geom - Returns a valid_detail (valid,reason,location) row stating if a geometry is valid or not and if not valid, a reason why and a location where.';
			
COMMENT ON FUNCTION ST_IsValidDetail(geometry , integer ) IS 'args: geom, flags - Returns a valid_detail (valid,reason,location) row stating if a geometry is valid or not and if not valid, a reason why and a location where.';
			
COMMENT ON FUNCTION ST_M(geometry ) IS 'args: a_point - Return the M coordinate of the point, or NULL if not available. Input must be a point.';
			
COMMENT ON FUNCTION ST_NDims(geometry ) IS 'args: g1 - Returns coordinate dimension of the geometry as a small int. Values are: 2,3 or 4.';
			
COMMENT ON FUNCTION ST_NPoints(geometry ) IS 'args: g1 - Return the number of points (vertexes) in a geometry.';
			
COMMENT ON FUNCTION ST_NRings(geometry ) IS 'args: geomA - If the geometry is a polygon or multi-polygon returns the number of rings.';
			
COMMENT ON FUNCTION ST_NumGeometries(geometry ) IS 'args: geom - If geometry is a GEOMETRYCOLLECTION (or MULTI*) return the number of geometries, for single geometries will return 1, otherwise return NULL.';
			
COMMENT ON FUNCTION ST_NumInteriorRings(geometry ) IS 'args: a_polygon - Return the number of interior rings of a polygon geometry.';
			
COMMENT ON FUNCTION ST_NumInteriorRing(geometry ) IS 'args: a_polygon - Return the number of interior rings of a polygon in the geometry. Synonym for ST_NumInteriorRings.';
			
COMMENT ON FUNCTION ST_NumPatches(geometry ) IS 'args: g1 - Return the number of faces on a Polyhedral Surface. Will return null for non-polyhedral geometries.';
			
COMMENT ON FUNCTION ST_NumPoints(geometry ) IS 'args: g1 - Return the number of points in an ST_LineString or ST_CircularString value.';
			
COMMENT ON FUNCTION ST_PatchN(geometry , integer ) IS 'args: geomA, n - Return the 1-based Nth geometry (face) if the geometry is a POLYHEDRALSURFACE, POLYHEDRALSURFACEM. Otherwise, return NULL.';
			
COMMENT ON FUNCTION ST_PointN(geometry , integer ) IS 'args: a_linestring, n - Return the Nth point in the first LineString or circular LineString in the geometry. Negative values are counted backwards from the end of the LineString. Returns NULL if there is no linestring in the geometry.';
			
COMMENT ON FUNCTION ST_Points(geometry) IS 'args: geom - Returns a MultiPoint containing all of the coordinates of a geometry.';
			
COMMENT ON FUNCTION ST_SRID(geometry ) IS 'args: g1 - Returns the spatial reference identifier for the ST_Geometry as defined in spatial_ref_sys table.';
			
COMMENT ON FUNCTION ST_StartPoint(geometry ) IS 'args: geomA - Returns the first point of a LINESTRING geometry as a POINT.';
			
COMMENT ON FUNCTION ST_Summary(geometry ) IS 'args: g - Returns a text summary of the contents of the geometry.';
			
COMMENT ON FUNCTION ST_Summary(geography ) IS 'args: g - Returns a text summary of the contents of the geometry.';
			
COMMENT ON FUNCTION ST_X(geometry ) IS 'args: a_point - Return the X coordinate of the point, or NULL if not available. Input must be a point.';
			
COMMENT ON FUNCTION ST_XMax(box3d ) IS 'args: aGeomorBox2DorBox3D - Returns X maxima of a bounding box 2d or 3d or a geometry.';
			
COMMENT ON FUNCTION ST_XMin(box3d ) IS 'args: aGeomorBox2DorBox3D - Returns X minima of a bounding box 2d or 3d or a geometry.';
			
COMMENT ON FUNCTION ST_Y(geometry ) IS 'args: a_point - Return the Y coordinate of the point, or NULL if not available. Input must be a point.';
			
COMMENT ON FUNCTION ST_YMax(box3d ) IS 'args: aGeomorBox2DorBox3D - Returns Y maxima of a bounding box 2d or 3d or a geometry.';
			
COMMENT ON FUNCTION ST_YMin(box3d ) IS 'args: aGeomorBox2DorBox3D - Returns Y minima of a bounding box 2d or 3d or a geometry.';
			
COMMENT ON FUNCTION ST_Z(geometry ) IS 'args: a_point - Return the Z coordinate of the point, or NULL if not available. Input must be a point.';
			
COMMENT ON FUNCTION ST_ZMax(box3d ) IS 'args: aGeomorBox2DorBox3D - Returns Z minima of a bounding box 2d or 3d or a geometry.';
			
COMMENT ON FUNCTION ST_Zmflag(geometry ) IS 'args: geomA - Returns ZM (dimension semantic) flag of the geometries as a small int. Values are: 0=2d, 1=3dm, 2=3dz, 3=4d.';
			
COMMENT ON FUNCTION ST_ZMin(box3d ) IS 'args: aGeomorBox2DorBox3D - Returns Z minima of a bounding box 2d or 3d or a geometry.';
			
COMMENT ON FUNCTION ST_AddPoint(geometry, geometry) IS 'args: linestring, point - Add a point to a LineString.';
			
COMMENT ON FUNCTION ST_AddPoint(geometry, geometry, integer) IS 'args: linestring, point, position - Add a point to a LineString.';
			
COMMENT ON FUNCTION ST_Affine(geometry , float , float , float , float , float , float , float , float , float , float , float , float ) IS 'args: geomA, a, b, c, d, e, f, g, h, i, xoff, yoff, zoff - Apply a 3d affine transformation to a geometry.';
			
COMMENT ON FUNCTION ST_Affine(geometry , float , float , float , float , float , float ) IS 'args: geomA, a, b, d, e, xoff, yoff - Apply a 3d affine transformation to a geometry.';
			
COMMENT ON FUNCTION ST_Force2D(geometry ) IS 'args: geomA - Force the geometries into a "2-dimensional mode".';
			
COMMENT ON FUNCTION ST_Force3D(geometry ) IS 'args: geomA - Force the geometries into XYZ mode. This is an alias for ST_Force3DZ.';
			
COMMENT ON FUNCTION ST_Force3DZ(geometry ) IS 'args: geomA - Force the geometries into XYZ mode.';
			
COMMENT ON FUNCTION ST_Force3DM(geometry ) IS 'args: geomA - Force the geometries into XYM mode.';
			
COMMENT ON FUNCTION ST_Force4D(geometry ) IS 'args: geomA - Force the geometries into XYZM mode.';
			
COMMENT ON FUNCTION ST_ForcePolygonCCW(geometry) IS 'args: geom - Orients all exterior rings counter-clockwise and all interior rings clockwise.';
			
COMMENT ON FUNCTION ST_ForceCollection(geometry ) IS 'args: geomA - Convert the geometry into a GEOMETRYCOLLECTION.';
			
COMMENT ON FUNCTION ST_ForcePolygonCW(geometry) IS 'args: geom - Orients all exterior rings clockwise and all interior rings counter-clockwise.';
			
COMMENT ON FUNCTION ST_ForceSFS(geometry ) IS 'args: geomA - Force the geometries to use SFS 1.1 geometry types only.';
			
COMMENT ON FUNCTION ST_ForceSFS(geometry , text ) IS 'args: geomA, version - Force the geometries to use SFS 1.1 geometry types only.';
			
COMMENT ON FUNCTION ST_ForceRHR(geometry) IS 'args: g - Force the orientation of the vertices in a polygon to follow the Right-Hand-Rule.';
			
COMMENT ON FUNCTION ST_ForceCurve(geometry) IS 'args: g - Upcast a geometry into its curved type, if applicable.';
			
COMMENT ON FUNCTION ST_LineMerge(geometry ) IS 'args: amultilinestring - Return a (set of) LineString(s) formed by sewing together a MULTILINESTRING.';
			
COMMENT ON FUNCTION ST_CollectionExtract(geometry , integer ) IS 'args: collection, type - Given a (multi)geometry, return a (multi)geometry consisting only of elements of the specified type.';
			
COMMENT ON FUNCTION ST_CollectionHomogenize(geometry ) IS 'args: collection - Given a geometry collection, return the "simplest" representation of the contents.';
			
COMMENT ON FUNCTION ST_Multi(geometry ) IS 'args: g1 - Return the geometry as a MULTI* geometry.';
			
COMMENT ON FUNCTION ST_Normalize(geometry ) IS 'args: geom - Return the geometry in its canonical form.';
			
COMMENT ON FUNCTION ST_QuantizeCoordinates(geometry, int, int, int, int) IS 'args: g, prec_x, prec_y, prec_z, prec_m - Sets least significant bits of coordinates to zero';
			
COMMENT ON FUNCTION ST_RemovePoint(geometry, integer) IS 'args: linestring, offset - Remove point from a linestring.';
			
COMMENT ON FUNCTION ST_Reverse(geometry ) IS 'args: g1 - Return the geometry with vertex order reversed.';
			
COMMENT ON FUNCTION ST_Rotate(geometry, float) IS 'args: geomA, rotRadians - Rotate a geometry rotRadians counter-clockwise about an origin.';
			
COMMENT ON FUNCTION ST_Rotate(geometry, float, float, float) IS 'args: geomA, rotRadians, x0, y0 - Rotate a geometry rotRadians counter-clockwise about an origin.';
			
COMMENT ON FUNCTION ST_Rotate(geometry, float, geometry) IS 'args: geomA, rotRadians, pointOrigin - Rotate a geometry rotRadians counter-clockwise about an origin.';
			
COMMENT ON FUNCTION ST_RotateX(geometry, float) IS 'args: geomA, rotRadians - Rotate a geometry rotRadians about the X axis.';
			
COMMENT ON FUNCTION ST_RotateY(geometry, float) IS 'args: geomA, rotRadians - Rotate a geometry rotRadians about the Y axis.';
			
COMMENT ON FUNCTION ST_RotateZ(geometry, float) IS 'args: geomA, rotRadians - Rotate a geometry rotRadians about the Z axis.';
			
COMMENT ON FUNCTION ST_Scale(geometry , float, float, float) IS 'args: geomA, XFactor, YFactor, ZFactor - Scale a geometry by given factors.';
			
COMMENT ON FUNCTION ST_Scale(geometry , float, float) IS 'args: geomA, XFactor, YFactor - Scale a geometry by given factors.';
			
COMMENT ON FUNCTION ST_Scale(geometry , geometry) IS 'args: geom, factor - Scale a geometry by given factors.';
			
COMMENT ON FUNCTION ST_Scale(geometry , geometry, geometry) IS 'args: geom, factor, origin - Scale a geometry by given factors.';
			
COMMENT ON FUNCTION ST_Segmentize(geometry , float ) IS 'args: geom, max_segment_length - Return a modified geometry/geography having no segment longer than the given distance.';
			
COMMENT ON FUNCTION ST_Segmentize(geography , float ) IS 'args: geog, max_segment_length - Return a modified geometry/geography having no segment longer than the given distance.';
			
COMMENT ON FUNCTION ST_SetPoint(geometry, integer, geometry) IS 'args: linestring, zerobasedposition, point - Replace point of a linestring with a given point.';
			
COMMENT ON FUNCTION ST_SetSRID(geometry , integer ) IS 'args: geom, srid - Set the SRID on a geometry to a particular integer value.';
			
COMMENT ON FUNCTION ST_SnapToGrid(geometry , float , float , float , float ) IS 'args: geomA, originX, originY, sizeX, sizeY - Snap all points of the input geometry to a regular grid.';
			
COMMENT ON FUNCTION ST_SnapToGrid(geometry , float , float ) IS 'args: geomA, sizeX, sizeY - Snap all points of the input geometry to a regular grid.';
			
COMMENT ON FUNCTION ST_SnapToGrid(geometry , float ) IS 'args: geomA, size - Snap all points of the input geometry to a regular grid.';
			
COMMENT ON FUNCTION ST_SnapToGrid(geometry , geometry , float , float , float , float ) IS 'args: geomA, pointOrigin, sizeX, sizeY, sizeZ, sizeM - Snap all points of the input geometry to a regular grid.';
			
COMMENT ON FUNCTION ST_Snap(geometry , geometry , float ) IS 'args: input, reference, tolerance - Snap segments and vertices of input geometry to vertices of a reference geometry.';
			
COMMENT ON FUNCTION ST_Transform(geometry , integer ) IS 'args: g1, srid - Return a new geometry with its coordinates transformed to a different spatial reference.';
			
COMMENT ON FUNCTION ST_Transform(geometry , text ) IS 'args: geom, to_proj - Return a new geometry with its coordinates transformed to a different spatial reference.';
			
COMMENT ON FUNCTION ST_Transform(geometry , text , text ) IS 'args: geom, from_proj, to_proj - Return a new geometry with its coordinates transformed to a different spatial reference.';
			
COMMENT ON FUNCTION ST_Transform(geometry , text , integer ) IS 'args: geom, from_proj, to_srid - Return a new geometry with its coordinates transformed to a different spatial reference.';
			
COMMENT ON FUNCTION ST_Translate(geometry , float , float ) IS 'args: g1, deltax, deltay - Translate a geometry by given offsets.';
			
COMMENT ON FUNCTION ST_Translate(geometry , float , float , float ) IS 'args: g1, deltax, deltay, deltaz - Translate a geometry by given offsets.';
			
COMMENT ON FUNCTION ST_TransScale(geometry , float, float, float, float) IS 'args: geomA, deltaX, deltaY, XFactor, YFactor - Translate a geometry by given factors and offsets.';
			
COMMENT ON FUNCTION ST_AsBinary(geometry ) IS 'args: g1 - Return the Well-Known Binary (WKB) representation of the geometry/geography without SRID meta data.';
			
COMMENT ON FUNCTION ST_AsBinary(geometry , text ) IS 'args: g1, NDR_or_XDR - Return the Well-Known Binary (WKB) representation of the geometry/geography without SRID meta data.';
			
COMMENT ON FUNCTION ST_AsBinary(geography ) IS 'args: g1 - Return the Well-Known Binary (WKB) representation of the geometry/geography without SRID meta data.';
			
COMMENT ON FUNCTION ST_AsBinary(geography , text ) IS 'args: g1, NDR_or_XDR - Return the Well-Known Binary (WKB) representation of the geometry/geography without SRID meta data.';
			
COMMENT ON FUNCTION ST_AsEncodedPolyline(geometry, integer ) IS 'args: geom, precision=5 - Returns an Encoded Polyline from a LineString geometry.';
			
COMMENT ON FUNCTION ST_AsEWKB(geometry ) IS 'args: g1 - Return the Well-Known Binary (WKB) representation of the geometry with SRID meta data.';
			
COMMENT ON FUNCTION ST_AsEWKB(geometry , text ) IS 'args: g1, NDR_or_XDR - Return the Well-Known Binary (WKB) representation of the geometry with SRID meta data.';
			
COMMENT ON FUNCTION ST_AsEWKT(geometry ) IS 'args: g1 - Return the Well-Known Text (WKT) representation of the geometry with SRID meta data.';
			
COMMENT ON FUNCTION ST_AsEWKT(geography ) IS 'args: g1 - Return the Well-Known Text (WKT) representation of the geometry with SRID meta data.';
			
COMMENT ON FUNCTION ST_AsGeoJSON(geometry , integer , integer ) IS 'args: geom, maxdecimaldigits=15, options=0 - Return the geometry as a GeoJSON element.';
			
COMMENT ON FUNCTION ST_AsGeoJSON(geography , integer , integer ) IS 'args: geog, maxdecimaldigits=15, options=0 - Return the geometry as a GeoJSON element.';
			
COMMENT ON FUNCTION ST_AsGeoJSON(integer , geometry , integer , integer ) IS 'args: gj_version, geom, maxdecimaldigits=15, options=0 - Return the geometry as a GeoJSON element.';
			
COMMENT ON FUNCTION ST_AsGeoJSON(integer , geography , integer , integer ) IS 'args: gj_version, geog, maxdecimaldigits=15, options=0 - Return the geometry as a GeoJSON element.';
			
COMMENT ON FUNCTION ST_AsGML(geometry , integer , integer ) IS 'args: geom, maxdecimaldigits=15, options=0 - Return the geometry as a GML version 2 or 3 element.';
			
COMMENT ON FUNCTION ST_AsGML(geography , integer , integer ) IS 'args: geog, maxdecimaldigits=15, options=0 - Return the geometry as a GML version 2 or 3 element.';
			
COMMENT ON FUNCTION ST_AsGML(integer , geometry , integer , integer , text , text ) IS 'args: version, geom, maxdecimaldigits=15, options=0, nprefix=null, id=null - Return the geometry as a GML version 2 or 3 element.';
			
COMMENT ON FUNCTION ST_AsGML(integer , geography , integer , integer , text , text ) IS 'args: version, geog, maxdecimaldigits=15, options=0, nprefix=null, id=null - Return the geometry as a GML version 2 or 3 element.';
			
COMMENT ON FUNCTION ST_AsHEXEWKB(geometry , text ) IS 'args: g1, NDRorXDR - Returns a Geometry in HEXEWKB format (as text) using either little-endian (NDR) or big-endian (XDR) encoding.';
			
COMMENT ON FUNCTION ST_AsHEXEWKB(geometry ) IS 'args: g1 - Returns a Geometry in HEXEWKB format (as text) using either little-endian (NDR) or big-endian (XDR) encoding.';
			
COMMENT ON FUNCTION ST_AsKML(geometry , integer ) IS 'args: geom, maxdecimaldigits=15 - Return the geometry as a KML element. Several variants. Default version=2, default maxdecimaldigits=15';
			
COMMENT ON FUNCTION ST_AsKML(geography , integer ) IS 'args: geog, maxdecimaldigits=15 - Return the geometry as a KML element. Several variants. Default version=2, default maxdecimaldigits=15';
			
COMMENT ON FUNCTION ST_AsKML(integer , geometry , integer , text ) IS 'args: version, geom, maxdecimaldigits=15, nprefix=NULL - Return the geometry as a KML element. Several variants. Default version=2, default maxdecimaldigits=15';
			
COMMENT ON FUNCTION ST_AsKML(integer , geography , integer , text ) IS 'args: version, geog, maxdecimaldigits=15, nprefix=NULL - Return the geometry as a KML element. Several variants. Default version=2, default maxdecimaldigits=15';
			
COMMENT ON FUNCTION ST_AsLatLonText(geometry , text ) IS 'args: pt, format='' - Return the Degrees, Minutes, Seconds representation of the given point.';
			
COMMENT ON FUNCTION ST_AsSVG(geometry , integer , integer ) IS 'args: geom, rel=0, maxdecimaldigits=15 - Returns a Geometry in SVG path data given a geometry or geography object.';
			
COMMENT ON FUNCTION ST_AsSVG(geography , integer , integer ) IS 'args: geog, rel=0, maxdecimaldigits=15 - Returns a Geometry in SVG path data given a geometry or geography object.';
			
COMMENT ON FUNCTION ST_AsText(geometry ) IS 'args: g1 - Return the Well-Known Text (WKT) representation of the geometry/geography without SRID metadata.';
			
COMMENT ON FUNCTION ST_AsText(geometry , integer ) IS 'args: g1, maxdecimaldigits=15 - Return the Well-Known Text (WKT) representation of the geometry/geography without SRID metadata.';
			
COMMENT ON FUNCTION ST_AsText(geography ) IS 'args: g1 - Return the Well-Known Text (WKT) representation of the geometry/geography without SRID metadata.';
			
COMMENT ON FUNCTION ST_AsText(geography , integer ) IS 'args: g1, maxdecimaldigits=15 - Return the Well-Known Text (WKT) representation of the geometry/geography without SRID metadata.';
			
COMMENT ON FUNCTION ST_AsTWKB(geometry , integer , integer , integer , boolean , boolean ) IS 'args: g1, decimaldigits_xy=0, decimaldigits_z=0, decimaldigits_m=0, include_sizes=false, include_bounding boxes=false - Returns the geometry as TWKB, aka "Tiny Well-Known Binary"';
			
COMMENT ON FUNCTION ST_AsTWKB(geometry[] , bigint[] , integer , integer , integer , boolean , boolean ) IS 'args: geometries, unique_ids, decimaldigits_xy=0, decimaldigits_z=0, decimaldigits_m=0, include_sizes=false, include_bounding_boxes=false - Returns the geometry as TWKB, aka "Tiny Well-Known Binary"';
			
COMMENT ON FUNCTION ST_AsX3D(geometry , integer , integer ) IS 'args: g1, maxdecimaldigits=15, options=0 - Returns a Geometry in X3D xml node element format: ISO-IEC-19776-1.2-X3DEncodings-XML';
			
COMMENT ON FUNCTION ST_GeoHash(geometry , integer ) IS 'args: geom, maxchars=full_precision_of_point - Return a GeoHash representation of the geometry.';
			
COMMENT ON AGGREGATE ST_AsGeobuf(anyelement) IS 'args: row - Return a Geobuf representation of a set of rows.';
			
COMMENT ON FUNCTION ST_AsGeobuf(anyelement , text ) IS 'args: row, geom_name - Return a Geobuf representation of a set of rows.';
			
COMMENT ON FUNCTION ST_AsMVTGeom(geometry , box2d , integer , integer , boolean ) IS 'args: geom, bounds, extent=4096, buffer=256, clip_geom=true - Transform a geometry into the coordinate space of a Mapbox Vector Tile.';
			
COMMENT ON AGGREGATE ST_AsMVT(anyelement) IS 'args: row - Return a Mapbox Vector Tile representation of a set of rows.';
			
COMMENT ON FUNCTION ST_AsMVT(anyelement , text ) IS 'args: row, name - Return a Mapbox Vector Tile representation of a set of rows.';
			
COMMENT ON FUNCTION ST_AsMVT(anyelement , text , integer ) IS 'args: row, name, extent - Return a Mapbox Vector Tile representation of a set of rows.';
			
COMMENT ON FUNCTION ST_AsMVT(anyelement , text , integer , text ) IS 'args: row, name, extent, geom_name - Return a Mapbox Vector Tile representation of a set of rows.';
			
COMMENT ON FUNCTION ST_3DClosestPoint(geometry , geometry ) IS 'args: g1, g2 - Returns the 3-dimensional point on g1 that is closest to g2. This is the first point of the 3D shortest line.';
			
COMMENT ON FUNCTION ST_3DDistance(geometry , geometry ) IS 'args: g1, g2 - For geometry type Returns the 3-dimensional cartesian minimum distance (based on spatial ref) between two geometries in projected units.';
			
COMMENT ON FUNCTION ST_3DDWithin(geometry , geometry , double precision ) IS 'args: g1, g2, distance_of_srid - For 3d (z) geometry type Returns true if two geometries 3d distance is within number of units.';
			
COMMENT ON FUNCTION ST_3DDFullyWithin(geometry , geometry , double precision ) IS 'args: g1, g2, distance - Returns true if all of the 3D geometries are within the specified distance of one another.';
			
COMMENT ON FUNCTION ST_3DIntersects(geometry, geometry) IS 'args: geomA, geomB - Returns TRUE if the Geometries "spatially intersect" in 3d - only for points, linestrings, polygons, polyhedral surface (area). With SFCGAL backend enabled also supports TINS';
			
COMMENT ON FUNCTION ST_3DLongestLine(geometry , geometry ) IS 'args: g1, g2 - Returns the 3-dimensional longest line between two geometries';
			
COMMENT ON FUNCTION ST_3DMaxDistance(geometry , geometry ) IS 'args: g1, g2 - For geometry type Returns the 3-dimensional cartesian maximum distance (based on spatial ref) between two geometries in projected units.';
			
COMMENT ON FUNCTION ST_3DShortestLine(geometry , geometry ) IS 'args: g1, g2 - Returns the 3-dimensional shortest line between two geometries';
			
COMMENT ON FUNCTION ST_Area(geometry ) IS 'args: g1 - Returns the area of the surface if it is a Polygon or MultiPolygon. For geometry, a 2D Cartesian area is determined with units specified by the SRID. For geography, area is determined on a curved surface with units in square meters.';
			
COMMENT ON FUNCTION ST_Area(geography , boolean ) IS 'args: geog, use_spheroid=true - Returns the area of the surface if it is a Polygon or MultiPolygon. For geometry, a 2D Cartesian area is determined with units specified by the SRID. For geography, area is determined on a curved surface with units in square meters.';
			
COMMENT ON FUNCTION ST_Azimuth(geometry , geometry ) IS 'args: pointA, pointB - Returns the north-based azimuth as the angle in radians measured clockwise from the vertical on pointA to pointB.';
			
COMMENT ON FUNCTION ST_Azimuth(geography , geography ) IS 'args: pointA, pointB - Returns the north-based azimuth as the angle in radians measured clockwise from the vertical on pointA to pointB.';
			
COMMENT ON FUNCTION ST_Angle(geometry , geometry , geometry , geometry ) IS 'args: point1, point2, point3, point4 - Returns the angle between 3 points, or between 2 vectors (4 points or 2 lines).';
			
COMMENT ON FUNCTION ST_Angle(geometry , geometry ) IS 'args: line1, line2 - Returns the angle between 3 points, or between 2 vectors (4 points or 2 lines).';
			
COMMENT ON FUNCTION ST_Centroid(geometry ) IS 'args: g1 - Returns the geometric center of a geometry.';
			
COMMENT ON FUNCTION ST_Centroid(geography , boolean ) IS 'args: g1, use_spheroid=true - Returns the geometric center of a geometry.';
			
COMMENT ON FUNCTION ST_ClosestPoint(geometry , geometry ) IS 'args: g1, g2 - Returns the 2-dimensional point on g1 that is closest to g2. This is the first point of the shortest line.';
			
COMMENT ON FUNCTION ST_ClusterDBSCAN(geometry, float8 , integer ) IS 'args: geom, eps, minpoints - Windowing function that returns integer id for the cluster each input geometry is in based on 2D implementation of Density-based spatial clustering of applications with noise (DBSCAN) algorithm.';
			
COMMENT ON AGGREGATE ST_ClusterIntersecting(geometry) IS 'args: g - Aggregate. Returns an array with the connected components of a set of geometries';
			
COMMENT ON FUNCTION ST_ClusterKMeans(geometry, integer ) IS 'args: geom, number_of_clusters - Windowing function that returns integer id for the cluster each input geometry is in.';
			
COMMENT ON AGGREGATE ST_ClusterWithin(geometry, float8 ) IS 'args: g, distance - Aggregate. Returns an array of GeometryCollections, where each GeometryCollection represents a set of geometries separated by no more than the specified distance.';
			
COMMENT ON FUNCTION ST_Contains(geometry , geometry ) IS 'args: geomA, geomB - Returns true if and only if no points of B lie in the exterior of A, and at least one point of the interior of B lies in the interior of A.';
			
COMMENT ON FUNCTION ST_ContainsProperly(geometry , geometry ) IS 'args: geomA, geomB - Returns true if B intersects the interior of A but not the boundary (or exterior). A does not contain properly itself, but does contain itself.';
			
COMMENT ON FUNCTION ST_Covers(geometry , geometry ) IS 'args: geomA, geomB - Returns 1 (TRUE) if no point in Geometry B is outside Geometry A';
			
COMMENT ON FUNCTION ST_Covers(geography , geography ) IS 'args: geogpolyA, geogpointB - Returns 1 (TRUE) if no point in Geometry B is outside Geometry A';
			
COMMENT ON FUNCTION ST_CoveredBy(geometry , geometry ) IS 'args: geomA, geomB - Returns 1 (TRUE) if no point in Geometry/Geography A is outside Geometry/Geography B';
			
COMMENT ON FUNCTION ST_CoveredBy(geography , geography ) IS 'args: geogA, geogB - Returns 1 (TRUE) if no point in Geometry/Geography A is outside Geometry/Geography B';
			
COMMENT ON FUNCTION ST_Crosses(geometry , geometry ) IS 'args: g1, g2 - Returns TRUE if the supplied geometries have some, but not all, interior points in common.';
			
COMMENT ON FUNCTION ST_LineCrossingDirection(geometry , geometry ) IS 'args: linestringA, linestringB - Given 2 linestrings, returns a number between -3 and 3 denoting what kind of crossing behavior. 0 is no crossing.';
			
COMMENT ON FUNCTION ST_Disjoint(geometry, geometry) IS 'args: A, B - Returns TRUE if the Geometries do not "spatially intersect" - if they do not share any space together.';
			
COMMENT ON FUNCTION ST_Distance(geometry , geometry ) IS 'args: g1, g2 - For geometry type returns the 2D Cartesian distance between two geometries in projected units (based on spatial reference system). For geography type defaults to return minimum geodesic distance between two geographies in meters.';
			
COMMENT ON FUNCTION ST_Distance(geography , geography ) IS 'args: gg1, gg2 - For geometry type returns the 2D Cartesian distance between two geometries in projected units (based on spatial reference system). For geography type defaults to return minimum geodesic distance between two geographies in meters.';
			
COMMENT ON FUNCTION ST_Distance(geography , geography , boolean ) IS 'args: gg1, gg2, use_spheroid - For geometry type returns the 2D Cartesian distance between two geometries in projected units (based on spatial reference system). For geography type defaults to return minimum geodesic distance between two geographies in meters.';
			
COMMENT ON FUNCTION ST_MinimumClearance(geometry ) IS 'args: g - Returns the minimum clearance of a geometry, a measure of a geometrys robustness.';
			
COMMENT ON FUNCTION ST_MinimumClearanceLine(geometry ) IS 'args: g - Returns the two-point LineString spanning a geometrys minimum clearance.';
			
COMMENT ON FUNCTION ST_HausdorffDistance(geometry , geometry ) IS 'args: g1, g2 - Returns the Hausdorff distance between two geometries. Basically a measure of how similar or dissimilar 2 geometries are. Units are in the units of the spatial reference system of the geometries.';
			
COMMENT ON FUNCTION ST_HausdorffDistance(geometry , geometry , float) IS 'args: g1, g2, densifyFrac - Returns the Hausdorff distance between two geometries. Basically a measure of how similar or dissimilar 2 geometries are. Units are in the units of the spatial reference system of the geometries.';
			
COMMENT ON FUNCTION ST_FrechetDistance(geometry , geometry , float) IS 'args: g1, g2, densifyFrac = -1 - Returns the Fréchet distance between two geometries. This is a measure of similarity between curves that takes into account the location and ordering of the points along the curves. Units are in the units of the spatial reference system of the geometries.';
			
COMMENT ON FUNCTION ST_MaxDistance(geometry , geometry ) IS 'args: g1, g2 - Returns the 2-dimensional largest distance between two geometries in projected units.';
			
COMMENT ON FUNCTION ST_DistanceSphere(geometry , geometry ) IS 'args: geomlonlatA, geomlonlatB - Returns minimum distance in meters between two lon/lat geometries. Uses a spherical earth and radius derived from the spheroid defined by the SRID. Faster than ST_DistanceSpheroid , but less accurate. PostGIS versions prior to 1.5 only implemented for points.';
			
COMMENT ON FUNCTION ST_DistanceSpheroid(geometry , geometry , spheroid ) IS 'args: geomlonlatA, geomlonlatB, measurement_spheroid - Returns the minimum distance between two lon/lat geometries given a particular spheroid. PostGIS versions prior to 1.5 only support points.';
			
COMMENT ON FUNCTION ST_DFullyWithin(geometry , geometry , double precision ) IS 'args: g1, g2, distance - Returns true if all of the geometries are within the specified distance of one another';
			
COMMENT ON FUNCTION ST_DWithin(geometry , geometry , double precision ) IS 'args: g1, g2, distance_of_srid - Returns true if the geometries are within the specified distance of one another. For geometry units are in those of spatial reference and for geography units are in meters and measurement is defaulted to use_spheroid=true (measure around spheroid), for faster check, use_spheroid=false to measure along sphere.';
			
COMMENT ON FUNCTION ST_DWithin(geography , geography , double precision ) IS 'args: gg1, gg2, distance_meters - Returns true if the geometries are within the specified distance of one another. For geometry units are in those of spatial reference and for geography units are in meters and measurement is defaulted to use_spheroid=true (measure around spheroid), for faster check, use_spheroid=false to measure along sphere.';
			
COMMENT ON FUNCTION ST_DWithin(geography , geography , double precision , boolean ) IS 'args: gg1, gg2, distance_meters, use_spheroid - Returns true if the geometries are within the specified distance of one another. For geometry units are in those of spatial reference and for geography units are in meters and measurement is defaulted to use_spheroid=true (measure around spheroid), for faster check, use_spheroid=false to measure along sphere.';
			
COMMENT ON FUNCTION ST_Equals(geometry , geometry ) IS 'args: A, B - Returns true if the given geometries represent the same geometry. Directionality is ignored.';
			
COMMENT ON FUNCTION 
					ST_GeometricMedian
				(
					geometry
				, 
					float8
				, 
					int
				, 
					boolean
				) IS 'args: 
					g
				, 
					tolerance
				, 
					max_iter
				, 
					fail_if_not_converged
				 - Returns the geometric median of a MultiPoint.';
			
COMMENT ON FUNCTION ST_HasArc(geometry ) IS 'args: geomA - Returns true if a geometry or geometry collection contains a circular string';
			
COMMENT ON FUNCTION ST_Intersects(geometry, geometry) IS 'args: geomA, geomB - Returns TRUE if the Geometries/Geography "spatially intersect in 2D" - (share any portion of space) and FALSE if they dont (they are Disjoint). For geography -- tolerance is 0.00001 meters (so any points that close are considered to intersect)';
			
COMMENT ON FUNCTION ST_Intersects(geography, geography) IS 'args: geogA, geogB - Returns TRUE if the Geometries/Geography "spatially intersect in 2D" - (share any portion of space) and FALSE if they dont (they are Disjoint). For geography -- tolerance is 0.00001 meters (so any points that close are considered to intersect)';
			
COMMENT ON FUNCTION ST_Length(geometry ) IS 'args: a_2dlinestring - Returns the 2D length of the geometry if it is a LineString or MultiLineString. geometry are in units of spatial reference and geography are in meters (default spheroid)';
			
COMMENT ON FUNCTION ST_Length(geography , boolean ) IS 'args: geog, use_spheroid=true - Returns the 2D length of the geometry if it is a LineString or MultiLineString. geometry are in units of spatial reference and geography are in meters (default spheroid)';
			
COMMENT ON FUNCTION ST_Length2D(geometry ) IS 'args: a_2dlinestring - Returns the 2-dimensional length of the geometry if it is a linestring or multi-linestring. This is an alias for ST_Length';
			
COMMENT ON FUNCTION ST_3DLength(geometry ) IS 'args: a_3dlinestring - Returns the 3-dimensional or 2-dimensional length of the geometry if it is a linestring or multi-linestring.';
			
COMMENT ON FUNCTION ST_LengthSpheroid(geometry , spheroid ) IS 'args: a_geometry, a_spheroid - Calculates the 2D or 3D length/perimeter of a geometry on an ellipsoid. This is useful if the coordinates of the geometry are in longitude/latitude and a length is desired without reprojection.';
			
COMMENT ON FUNCTION ST_Length2D_Spheroid(geometry , spheroid ) IS 'args: a_geometry, a_spheroid - Calculates the 2D length/perimeter of a geometry on an ellipsoid. This is useful if the coordinates of the geometry are in longitude/latitude and a length is desired without reprojection.';
			
COMMENT ON FUNCTION ST_LongestLine(geometry , geometry ) IS 'args: g1, g2 - Returns the 2-dimensional longest line points of two geometries. The function will only return the first longest line if more than one, that the function finds. The line returned will always start in g1 and end in g2. The length of the line this function returns will always be the same as st_maxdistance returns for g1 and g2.';
			
COMMENT ON FUNCTION ST_OrderingEquals(geometry , geometry ) IS 'args: A, B - Returns true if the given geometries represent the same geometry and points are in the same directional order.';
			
COMMENT ON FUNCTION ST_Overlaps(geometry , geometry ) IS 'args: A, B - Returns TRUE if the Geometries share space, are of the same dimension, but are not completely contained by each other.';
			
COMMENT ON FUNCTION ST_Perimeter(geometry ) IS 'args: g1 - Return the length measurement of the boundary of an ST_Surface or ST_MultiSurface geometry or geography. (Polygon, MultiPolygon). geometry measurement is in units of spatial reference and geography is in meters.';
			
COMMENT ON FUNCTION ST_Perimeter(geography , boolean ) IS 'args: geog, use_spheroid=true - Return the length measurement of the boundary of an ST_Surface or ST_MultiSurface geometry or geography. (Polygon, MultiPolygon). geometry measurement is in units of spatial reference and geography is in meters.';
			
COMMENT ON FUNCTION ST_Perimeter2D(geometry ) IS 'args: geomA - Returns the 2-dimensional perimeter of the geometry, if it is a polygon or multi-polygon. This is currently an alias for ST_Perimeter.';
			
COMMENT ON FUNCTION ST_3DPerimeter(geometry ) IS 'args: geomA - Returns the 3-dimensional perimeter of the geometry, if it is a polygon or multi-polygon.';
			
COMMENT ON FUNCTION ST_PointOnSurface(geometry ) IS 'args: g1 - Returns a POINT guaranteed to lie on the surface.';
			
COMMENT ON FUNCTION ST_Project(geography , float , float ) IS 'args: g1, distance, azimuth - Returns a POINT projected from a start point using a distance in meters and bearing (azimuth) in radians.';
			
COMMENT ON FUNCTION ST_Relate(geometry , geometry , text ) IS 'args: geomA, geomB, intersectionMatrixPattern - Returns true if this Geometry is spatially related to anotherGeometry, by testing for intersections between the Interior, Boundary and Exterior of the two geometries as specified by the values in the intersectionMatrixPattern. If no intersectionMatrixPattern is passed in, then returns the maximum intersectionMatrixPattern that relates the 2 geometries.';
			
COMMENT ON FUNCTION ST_Relate(geometry , geometry ) IS 'args: geomA, geomB - Returns true if this Geometry is spatially related to anotherGeometry, by testing for intersections between the Interior, Boundary and Exterior of the two geometries as specified by the values in the intersectionMatrixPattern. If no intersectionMatrixPattern is passed in, then returns the maximum intersectionMatrixPattern that relates the 2 geometries.';
			
COMMENT ON FUNCTION ST_Relate(geometry , geometry , integer ) IS 'args: geomA, geomB, BoundaryNodeRule - Returns true if this Geometry is spatially related to anotherGeometry, by testing for intersections between the Interior, Boundary and Exterior of the two geometries as specified by the values in the intersectionMatrixPattern. If no intersectionMatrixPattern is passed in, then returns the maximum intersectionMatrixPattern that relates the 2 geometries.';
			
COMMENT ON FUNCTION ST_RelateMatch(text , text ) IS 'args: intersectionMatrix, intersectionMatrixPattern - Returns true if intersectionMattrixPattern1 implies intersectionMatrixPattern2';
			
COMMENT ON FUNCTION ST_ShortestLine(geometry , geometry ) IS 'args: g1, g2 - Returns the 2-dimensional shortest line between two geometries';
			
COMMENT ON FUNCTION ST_Touches(geometry , geometry ) IS 'args: g1, g2 - Returns TRUE if the geometries have at least one point in common, but their interiors do not intersect.';
			
COMMENT ON FUNCTION ST_Within(geometry , geometry ) IS 'args: A, B - Returns true if the geometry A is completely inside geometry B';
			
COMMENT ON FUNCTION ST_Buffer(geometry , float ) IS 'args: g1, radius_of_buffer - (T)Returns a geometry covering all points within a given distancefrom the input geometry.';
			
COMMENT ON FUNCTION ST_Buffer(geometry , float , integer ) IS 'args: g1, radius_of_buffer, num_seg_quarter_circle - (T)Returns a geometry covering all points within a given distancefrom the input geometry.';
			
COMMENT ON FUNCTION ST_Buffer(geometry , float , text ) IS 'args: g1, radius_of_buffer, buffer_style_parameters - (T)Returns a geometry covering all points within a given distancefrom the input geometry.';
			
COMMENT ON FUNCTION ST_Buffer(geography , float ) IS 'args: g1, radius_of_buffer_in_meters - (T)Returns a geometry covering all points within a given distancefrom the input geometry.';
			
COMMENT ON FUNCTION ST_Buffer(geography , float , integer ) IS 'args: g1, radius_of_buffer, num_seg_quarter_circle - (T)Returns a geometry covering all points within a given distancefrom the input geometry.';
			
COMMENT ON FUNCTION ST_Buffer(geography , float , text ) IS 'args: g1, radius_of_buffer, buffer_style_parameters - (T)Returns a geometry covering all points within a given distancefrom the input geometry.';
			
COMMENT ON FUNCTION ST_BuildArea(geometry ) IS 'args: A - Creates an areal geometry formed by the constituent linework of given geometry';
			
COMMENT ON AGGREGATE ST_Collect(geometry) IS 'args: g1field - Return a specified ST_Geometry value from a collection of other geometries.';
			
COMMENT ON FUNCTION ST_Collect(geometry, geometry) IS 'args: g1, g2 - Return a specified ST_Geometry value from a collection of other geometries.';
			
COMMENT ON FUNCTION ST_Collect(geometry[]) IS 'args: g1_array - Return a specified ST_Geometry value from a collection of other geometries.';
			
COMMENT ON FUNCTION ST_ConcaveHull(geometry , float , boolean ) IS 'args: geomA, target_percent, allow_holes=false - The concave hull of a geometry represents a possibly concave geometry that encloses all geometries within the set. You can think of it as shrink wrapping.';
			
COMMENT ON FUNCTION ST_ConvexHull(geometry ) IS 'args: geomA - The convex hull of a geometry represents the minimum convex geometry that encloses all geometries within the set.';
			
COMMENT ON FUNCTION ST_CurveToLine(geometry, float, integer, integer) IS 'args: curveGeom, tolerance, tolerance_type, flags - Converts a CIRCULARSTRING/CURVEPOLYGON/MULTISURFACE to a LINESTRING/POLYGON/MULTIPOLYGON';
			
COMMENT ON FUNCTION ST_DelaunayTriangles(geometry , float , int4 ) IS 'args: g1, tolerance, flags - Return a Delaunay triangulation around the given input points.';
			
COMMENT ON FUNCTION ST_Difference(geometry , geometry ) IS 'args: geomA, geomB - Returns a geometry that represents that part of geometry A that does not intersect with geometry B.';
			
COMMENT ON FUNCTION ST_Dump(geometry ) IS 'args: g1 - Returns a set of geometry_dump (geom,path) rows, that make up a geometry g1.';
			
COMMENT ON FUNCTION ST_DumpPoints(geometry ) IS 'args: geom - Returns a set of geometry_dump (geom,path) rows of all points that make up a geometry.';
			
COMMENT ON FUNCTION ST_DumpRings(geometry ) IS 'args: a_polygon - Returns a set of geometry_dump rows, representing the exterior and interior rings of a polygon.';
			
COMMENT ON FUNCTION ST_FlipCoordinates(geometry) IS 'args: geom - Returns a version of the given geometry with X and Y axis flipped. Useful for people who have built latitude/longitude features and need to fix them.';
			
COMMENT ON FUNCTION ST_GeneratePoints(geometry, numeric) IS 'args: g, npoints - Converts a polygon or multi-polygon into a multi-point composed of randomly location points within the original areas.';
			
COMMENT ON FUNCTION ST_Intersection(geometry, geometry) IS 'args: geomA, geomB - (T)Returns a geometry that represents the shared portion of geomA and geomB.';
			
COMMENT ON FUNCTION ST_Intersection(geography, geography) IS 'args: geogA, geogB - (T)Returns a geometry that represents the shared portion of geomA and geomB.';
			
COMMENT ON FUNCTION ST_LineToCurve(geometry ) IS 'args: geomANoncircular - Converts a LINESTRING/POLYGON to a CIRCULARSTRING, CURVEPOLYGON';
			
COMMENT ON FUNCTION ST_MakeValid(geometry) IS 'args: input - Attempts to make an invalid geometry valid without losing vertices.';
			
COMMENT ON AGGREGATE ST_MemUnion(geometry) IS 'args: geomfield - Same as ST_Union, only memory-friendly (uses less memory and more processor time).';
			
COMMENT ON FUNCTION ST_MinimumBoundingCircle(geometry , integer ) IS 'args: geomA, num_segs_per_qt_circ=48 - Returns the smallest circle polygon that can fully contain a geometry. Default uses 48 segments per quarter circle.';
			
COMMENT ON FUNCTION ST_MinimumBoundingRadius(geometry) IS 'args: geom - Returns the center point and radius of the smallest circle that can fully contain a geometry.';
			
COMMENT ON FUNCTION ST_OrientedEnvelope(geometry) IS 'args: geom - Returns a minimum rotated rectangle enclosing a geometry.';
			
COMMENT ON AGGREGATE ST_Polygonize(geometry) IS 'args: geomfield - Aggregate. Creates a GeometryCollection containing possible polygons formed from the constituent linework of a set of geometries.';
			
COMMENT ON FUNCTION ST_Polygonize(geometry[]) IS 'args: geom_array - Aggregate. Creates a GeometryCollection containing possible polygons formed from the constituent linework of a set of geometries.';
			
COMMENT ON FUNCTION ST_Node(geometry ) IS 'args: geom - Node a set of linestrings.';
			
COMMENT ON FUNCTION ST_OffsetCurve(geometry , float , text ) IS 'args: line, signed_distance, style_parameters='' - Return an offset line at a given distance and side from an input line. Useful for computing parallel lines about a center line';
			
COMMENT ON FUNCTION ST_RemoveRepeatedPoints(geometry, float8) IS 'args: geom, tolerance - Returns a version of the given geometry with duplicated points removed.';
			
COMMENT ON FUNCTION ST_SharedPaths(geometry, geometry) IS 'args: lineal1, lineal2 - Returns a collection containing paths shared by the two input linestrings/multilinestrings.';
			
COMMENT ON FUNCTION ST_ShiftLongitude(geometry ) IS 'args: geomA - Toggle geometry coordinates between -180..180 and 0..360 ranges.';
			
COMMENT ON FUNCTION ST_WrapX(geometry , float8 , float8 ) IS 'args: geom, wrap, move - Wrap a geometry around an X value.';
			
COMMENT ON FUNCTION ST_Simplify(geometry, float, boolean) IS 'args: geomA, tolerance, preserveCollapsed - Returns a "simplified" version of the given geometry using the Douglas-Peucker algorithm.';
			
COMMENT ON FUNCTION ST_SimplifyPreserveTopology(geometry, float) IS 'args: geomA, tolerance - Returns a "simplified" version of the given geometry using the Douglas-Peucker algorithm. Will avoid creating derived geometries (polygons in particular) that are invalid.';
			
COMMENT ON FUNCTION ST_SimplifyVW(geometry, float) IS 'args: geomA, tolerance - Returns a "simplified" version of the given geometry using the Visvalingam-Whyatt algorithm';
			
COMMENT ON FUNCTION ST_ChaikinSmoothing(geometry, integer, boolean) IS 'args: geom, nIterations = 1, preserveEndPoints = false - Returns a "smoothed" version of the given geometry using the Chaikin algorithm';
			
COMMENT ON FUNCTION ST_FilterByM(geometry, double precision, double precision, boolean) IS 'args: geom, min, max = null, returnM = false - Filters vertex points based on their m-value';
			
COMMENT ON FUNCTION ST_SetEffectiveArea(geometry, float, integer) IS 'args: geomA, threshold = 0, set_area = 1 - Sets the effective area for each vertex, storing the value in the M ordinate. A simplified geometry can then be generated by filtering on the M ordinate.';
			
COMMENT ON FUNCTION ST_Split(geometry, geometry) IS 'args: input, blade - Returns a collection of geometries resulting by splitting a geometry.';
			
COMMENT ON FUNCTION ST_SymDifference(geometry , geometry ) IS 'args: geomA, geomB - Returns a geometry that represents the portions of A and B that do not intersect. It is called a symmetric difference because ST_SymDifference(A,B) = ST_SymDifference(B,A).';
			
COMMENT ON FUNCTION ST_SwapOrdinates(geometry, cstring) IS 'args: geom, ords - Returns a version of the given geometry with given ordinate values swapped.';
			
COMMENT ON AGGREGATE ST_Union(geometry) IS 'args: g1field - Returns a geometry that represents the point set union of the Geometries.';
			
COMMENT ON FUNCTION ST_Union(geometry, geometry) IS 'args: g1, g2 - Returns a geometry that represents the point set union of the Geometries.';
			
COMMENT ON FUNCTION ST_Union(geometry[]) IS 'args: g1_array - Returns a geometry that represents the point set union of the Geometries.';
			
COMMENT ON FUNCTION ST_UnaryUnion(geometry ) IS 'args: geom - Like ST_Union, but working at the geometry component level.';
			
COMMENT ON FUNCTION ST_LineInterpolatePoint(geometry , float8 ) IS 'args: a_linestring, a_fraction - Returns a point interpolated along a line. Second argument is a float8 between 0 and 1 representing fraction of total length of linestring the point has to be located.';
			
COMMENT ON FUNCTION ST_LineInterpolatePoints(geometry , float8 , boolean ) IS 'args: a_linestring, a_fraction, repeat - Returns one or more points interpolated along a line.';
			
COMMENT ON FUNCTION ST_LineLocatePoint(geometry , geometry ) IS 'args: a_linestring, a_point - Returns a float between 0 and 1 representing the location of the closest point on LineString to the given Point, as a fraction of total 2d line length.';
			
COMMENT ON FUNCTION ST_LineSubstring(geometry , float8 , float8 ) IS 'args: a_linestring, startfraction, endfraction - Return a linestring being a substring of the input one starting and ending at the given fractions of total 2d length. Second and third arguments are float8 values between 0 and 1.';
			
COMMENT ON FUNCTION ST_LocateAlong(geometry , float8 , float8 ) IS 'args: ageom_with_measure, a_measure, offset - Return a derived geometry collection value with elements that match the specified measure. Polygonal elements are not supported.';
			
COMMENT ON FUNCTION ST_LocateBetween(geometry , float8 , float8 , float8 ) IS 'args: geomA, measure_start, measure_end, offset - Return a derived geometry collection value with elements that match the specified range of measures inclusively. Polygonal elements are not supported.';
			
COMMENT ON FUNCTION ST_LocateBetweenElevations(geometry , float8 , float8 ) IS 'args: geom_mline, elevation_start, elevation_end - Return a derived geometry (collection) value with elements that intersect the specified range of elevations inclusively. Only 3D, 4D LINESTRINGS and MULTILINESTRINGS are supported.';
			
COMMENT ON FUNCTION ST_InterpolatePoint(geometry , geometry ) IS 'args: line, point - Return the value of the measure dimension of a geometry at the point closed to the provided point.';
			
COMMENT ON FUNCTION ST_AddMeasure(geometry , float8 , float8 ) IS 'args: geom_mline, measure_start, measure_end - Return a derived geometry with measure elements linearly interpolated between the start and end points.';
			
COMMENT ON FUNCTION ST_IsValidTrajectory(geometry ) IS 'args: line - Returns true if the geometry is a valid trajectory.';
			
COMMENT ON FUNCTION ST_ClosestPointOfApproach(geometry , geometry ) IS 'args: track1, track2 - Returns the measure at which points interpolated along two lines are closest.';
			
COMMENT ON FUNCTION ST_DistanceCPA(geometry , geometry ) IS 'args: track1, track2 - Returns the distance between closest points of approach in two trajectories.';
			
COMMENT ON FUNCTION ST_CPAWithin(geometry , geometry , float8 ) IS 'args: track1, track2, maxdist - Returns true if the trajectories closest points of approachare within the specified distance.';
			
COMMENT ON FUNCTION AddAuth(text ) IS 'args: auth_token - Add an authorization token to be used in current transaction.';
			
COMMENT ON FUNCTION CheckAuth(text , text , text ) IS 'args: a_schema_name, a_table_name, a_key_column_name - Creates trigger on a table to prevent/allow updates and deletes of rows based on authorization token.';
			
COMMENT ON FUNCTION CheckAuth(text , text ) IS 'args: a_table_name, a_key_column_name - Creates trigger on a table to prevent/allow updates and deletes of rows based on authorization token.';
			
COMMENT ON FUNCTION DisableLongTransactions() IS 'Disable long transaction support. This function removes the long transaction support metadata tables, and drops all triggers attached to lock-checked tables.';
			
COMMENT ON FUNCTION EnableLongTransactions() IS 'Enable long transaction support. This function creates the required metadata tables, needs to be called once before using the other functions in this section. Calling it twice is harmless.';
			
COMMENT ON FUNCTION LockRow(text , text , text , text, timestamp) IS 'args: a_schema_name, a_table_name, a_row_key, an_auth_token, expire_dt - Set lock/authorization for specific row in table';
			
COMMENT ON FUNCTION LockRow(text , text , text, timestamp) IS 'args: a_table_name, a_row_key, an_auth_token, expire_dt - Set lock/authorization for specific row in table';
			
COMMENT ON FUNCTION LockRow(text , text , text) IS 'args: a_table_name, a_row_key, an_auth_token - Set lock/authorization for specific row in table';
			
COMMENT ON FUNCTION UnlockRows(text ) IS 'args: auth_token - Remove all locks held by specified authorization id. Returns the number of locks released.';
			
COMMENT ON AGGREGATE ST_Accum(geometry) IS 'args: geomfield - Aggregate. Constructs an array of geometries.';
			
COMMENT ON FUNCTION Box2D(geometry ) IS 'args: geomA - Returns a BOX2D representing the maximum extents of the geometry.';
			
COMMENT ON FUNCTION Box3D(geometry ) IS 'args: geomA - Returns a BOX3D representing the maximum extents of the geometry.';
			
COMMENT ON FUNCTION ST_EstimatedExtent(text , text , text , boolean ) IS 'args: schema_name, table_name, geocolumn_name, parent_ony - Return the estimated extent of the given spatial table. The estimated is taken from the geometry columns statistics. The current schema will be used if not specified.';
			
COMMENT ON FUNCTION ST_EstimatedExtent(text , text , text ) IS 'args: schema_name, table_name, geocolumn_name - Return the estimated extent of the given spatial table. The estimated is taken from the geometry columns statistics. The current schema will be used if not specified.';
			
COMMENT ON FUNCTION ST_EstimatedExtent(text , text ) IS 'args: table_name, geocolumn_name - Return the estimated extent of the given spatial table. The estimated is taken from the geometry columns statistics. The current schema will be used if not specified.';
			
COMMENT ON FUNCTION ST_Expand(geometry , float) IS 'args: geom, units_to_expand - Returns bounding box expanded in all directions from the bounding box of the input geometry. Uses double-precision';
			
COMMENT ON FUNCTION ST_Expand(geometry , float, float, float, float) IS 'args: geom, dx, dy, dz=0, dm=0 - Returns bounding box expanded in all directions from the bounding box of the input geometry. Uses double-precision';
			
COMMENT ON FUNCTION ST_Expand(box2d , float) IS 'args: box, units_to_expand - Returns bounding box expanded in all directions from the bounding box of the input geometry. Uses double-precision';
			
COMMENT ON FUNCTION ST_Expand(box2d , float, float) IS 'args: box, dx, dy - Returns bounding box expanded in all directions from the bounding box of the input geometry. Uses double-precision';
			
COMMENT ON FUNCTION ST_Expand(box3d , float) IS 'args: box, units_to_expand - Returns bounding box expanded in all directions from the bounding box of the input geometry. Uses double-precision';
			
COMMENT ON FUNCTION ST_Expand(box3d , float, float, float) IS 'args: box, dx, dy, dz=0 - Returns bounding box expanded in all directions from the bounding box of the input geometry. Uses double-precision';
			
COMMENT ON AGGREGATE ST_Extent(geometry) IS 'args: geomfield - an aggregate function that returns the bounding box that bounds rows of geometries.';
			
COMMENT ON AGGREGATE ST_3DExtent(geometry) IS 'args: geomfield - an aggregate function that returns the box3D bounding box that bounds rows of geometries.';
			
COMMENT ON FUNCTION Find_SRID(varchar , varchar , varchar ) IS 'args: a_schema_name, a_table_name, a_geomfield_name - The syntax is find_srid(a_db_schema, a_table, a_column) and the function returns the integer SRID of the specified column by searching through the GEOMETRY_COLUMNS table.';
			
COMMENT ON FUNCTION ST_MemSize(geometry ) IS 'args: geomA - Returns the amount of space (in bytes) the geometry takes.';
			
COMMENT ON FUNCTION ST_PointInsideCircle(geometry , float , float , float ) IS 'args: a_point, center_x, center_y, radius - Is the point geometry inside the circle defined by center_x, center_y, radius';
			
COMMENT ON FUNCTION PostGIS_AddBBox(geometry ) IS 'args: geomA - Add bounding box to the geometry.';
			
COMMENT ON FUNCTION PostGIS_DropBBox(geometry ) IS 'args: geomA - Drop the bounding box cache from the geometry.';
			
COMMENT ON FUNCTION PostGIS_HasBBox(geometry ) IS 'args: geomA - Returns TRUE if the bbox of this geometry is cached, FALSE otherwise.';
			-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
--
----
-- PostGIS - Spatial Types for PostgreSQL
-- http://postgis.net
--
-- Copyright (C) 2011 Regina Obe <lr@pcorp.us>
-- Modifications Copyright (c) 2017 - Present Pivotal Software, Inc. All Rights Reserved.
--
-- This is free software; you can redistribute and/or modify it under
-- the terms of the GNU General Public Licence. See the COPYING file.
--
-- Author: Regina Obe <lr@pcorp.us>
--
-- This drops extension helper functions
-- and should be called at the end of the extension upgrade file
DROP FUNCTION postgis_extension_remove_objects(text, text);
DROP FUNCTION postgis_extension_drop_if_exists(text, text);
DROP FUNCTION postgis_extension_AddToSearchPath(varchar);
