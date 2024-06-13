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
