/*
 * A novel geospatial type in Pivotal GPDB: trajectory
 *
 * Copyright (c) 2015 Pivotal Inc.
 *
 * Implemented by Kuien Liu <kliu.pivotal.io>
 */


SET client_min_messages TO warning;

CREATE SCHEMA trajectory;

BEGIN;

CREATE OR REPLACE FUNCTION trajectory_version() RETURNS text
	AS $$ SELECT text('1.0') $$
	LANGUAGE 'sql' IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION trajectory_full_version() RETURNS text
    AS $$ SELECT text('Trajectory=1.0 PostGIS=') || postgis_version() $$
    LANGUAGE 'sql' IMMUTABLE STRICT;

-----------------------------------------------------------------------
-- generic intermedia types for trajectory
-----------------------------------------------------------------------
CREATE TYPE trajectory.TPeriod AS (
	tstart timestamp,
	tend timestamp
);

-- we don't use geometry because Point is lightweight
CREATE TYPE trajectory.TPoint AS (
	time timestamp,
	position point
);

-- consideration:
-- 1. we don't use geometry because Point is lightweight
-- 2. TODO we need to use JSON instead of XML after 5.0
CREATE TYPE trajectory.TPointAttr AS (
	time timestamp,
	position point,
	attributes jsonb 
);

-- similar to Box type
CREATE TYPE trajectory.TRegion AS (
	xmin double precision,
	ymin double precision,
	xmax double precision,
	ymax double precision
);

-- similar to Circle type
CREATE TYPE trajectory.TCircle AS (
	center point,
	radius double precision
);

CREATE TYPE trajectory.TCube AS (
	period trajectory.TPeriod,
	region trajectory.TRegion
);

CREATE TYPE trajectory.TPillar AS (
	period trajectory.TPeriod,
	circle trajectory.TCircle
);


------------------------------------------------------------------------------
-- Functions to  create trajectory pool which is composed with a BIG 
--    spatio-temporal sequence, so that we could retrival it.
------------------------------------------------------------------------------

-- check Postgis is installed
CREATE OR REPLACE FUNCTION trajectory.postgis_is_installed() 
RETURNS boolean
AS
$$
	SELECT CASE WHEN count(*) != 0 THEN true ELSE false END FROM pg_proc WHERE proname = 'postgis_version'
$$ LANGUAGE 'sql' IMMUTABLE;

--
-- Trajectory Pool table.
--   Stores id,name,precision and SRID of trajectory.
--
-- TODO 1: (poolname,trjname) should be unique
-- TODO 2: we consider to make it a replicated table in future.
--
CREATE TABLE trajectory.trajectory(
  id SERIAL NOT NULL,
  poolname VARCHAR NOT NULL,
  trjname VARCHAR NOT NULL,
  SRID INTEGER NOT NULL DEFAULT 0,
  precision FLOAT8 NOT NULL DEFAULT 0.000001,
  tableid OID NOT NULL DEFAULT 0,
  attrcount INTEGER NOT NULL DEFAULT 0, 
  CONSTRAINT unique_object UNIQUE(poolname, trjname)
);

--{
--  AddToSearchPath(schema_name)
--
-- Adds the specified schema to the database search path
-- if it is not already in the database search path
-- This is a helper function for upgrade/install
-- We may want to move this function as a generic helper
CREATE OR REPLACE FUNCTION trajectory.AddToSearchPath(a_schema_name varchar)
RETURNS text
AS
$$
DECLARE
    var_result text;
    var_cur_search_path text;
BEGIN
    SELECT setting INTO var_cur_search_path FROM pg_settings WHERE name = 'search_path';
    IF var_cur_search_path LIKE '%' || quote_ident(a_schema_name) || '%' THEN
        var_result := a_schema_name || ' already in database search_path';
    ELSE
        EXECUTE 'ALTER DATABASE ' || quote_ident(current_database()) || ' SET search_path = ' || var_cur_search_path || ', ' || quote_ident(a_schema_name);
		IF FOUND THEN
	        var_result := a_schema_name || ' has been added to end of database search_path ';
		ELSE
	        var_result := a_schema_name || ' failed to add to end of database search_path ';
		END IF;
    END IF;

  RETURN var_result;
END
$$
LANGUAGE 'plpgsql' VOLATILE STRICT;
--} AddToSearchPath

-- Make sure trajectory is in database search path --
SELECT trajectory.AddToSearchPath('trajectory');


--{ 
--  Create a trajectory, obtain an unique id
--    pool_name, name of trajectory set, e.g, 'taxi', 'bus', 'ferry' etc
--    trj_name, name of a trajectory, e.g., 'B123', 'B245', 'C123' etc
--    srid, spatial reference coordination of trajectory, e.g., 4326 for GPS 
--    prec, precision of spatial location data, e.g., 0.0000001 is good enough for GPS
--
CREATE OR REPLACE FUNCTION trajectory.CreateTrajectory(pool_name varchar, trj_name varchar, srid integer, prec float8)
RETURNS integer AS $$
DECLARE
	trajectory_id integer;
	rec RECORD;
	new_srid integer;
	SRID_USR_MAX integer;
	pool_name_count integer;
	trj_name_count integer;
	pool_table_id oid;
BEGIN
	-- Verify pool name and trajectory name
	IF ( (pool_name IS NULL OR pool_name = '') OR (trj_name IS NULL OR trj_name = '') ) THEN
		RAISE EXCEPTION 'trajectory.CreateTrajectory() - either pool name or trajectory name should NOT be NULL';
		return -1;
	END IF;

	-- Verify SIRD
	--   SRID_USR_MAX is defined at line 30 of file sqldefines.h in PostGIS.
	SRID_USR_MAX = 998999;
	IF ( srid > 0 ) THEN
		IF srid > SRID_USR_MAX THEN
			RAISE EXCEPTION 'trajectory.CreateTrajectory() - SRID must be <= %', SRID_USR_MAX;
		ELSE
			new_srid = srid;
		END IF;
	ELSE
		new_srid = ST_SRID('POINT EMPTY'::geometry);
        IF ( srid != new_srid) THEN
            RAISE NOTICE 'trajectory.CreateTrajectory() - SRID value % converted to the officially unknown SRID value %', srid, new_srid;
        END IF;
	END IF;


	-- Create a BIG table for this pool is it's the 1st time
	pool_name_count := 0;
	SELECT count(*) INTO pool_name_count
		FROM trajectory.trajectory WHERE poolname = pool_name;

    IF pool_name_count = 0 THEN
	------{ table creation
		EXECUTE
		'CREATE TABLE trajectory.' || quote_ident(pool_name) || '('
		|| 'id bigserial NOT NULL,'
		|| 'time timestamp NOT NULL,'
		|| 'position geometry(point,' || srid || ') NOT NULL '
		|| ') '
		|| 'WITH (APPENDONLY=TRUE) ' 
		|| 'DISTRIBUTED BY (id);';

	---- GiST index on (position)
		EXECUTE 'CREATE INDEX pool_' || quote_ident(pool_name) || '_gist ON '
		|| 'trajectory.' || quote_ident(pool_name) || ' '
    	|| 'using gist(position);';
	------}

	ELSE
		-- Make sure this trajectory is the 1st time being created.
		trj_name_count := 0;
		SELECT count(*) INTO trj_name_count
			FROM trajectory.trajectory WHERE poolname = pool_name AND trjname = trj_name;

		-- Check if duplicated table is created
		--   we verify this without using the UNIQUE constrain attached is because
		--   we want to avoid the 'nextval('trajectory.trajectory_id_seq')' be
		--   invoked multiple times, then the trajectory ID will be continuous naturely.
		IF trj_name_count != 0 THEN
			RAISE EXCEPTION 'trajectory.CreateTrajectory() - Trajectory % (%) exists!', pool_name, trj_name;
		END IF;

	END IF;

	-- Store the relation ID of the trajectory table being created
	--   I'm thinking to store the 'trajectory.pool_name' directly as
	--   both 'pg_class.oid' and 'pg_class.{relname,relnamespace} are 
	--   indexed with BTREE and claimed as UNIQUE
	pool_table_id = 0;
	SELECT c.oid INTO pool_table_id
		FROM pg_class c, pg_namespace n
		WHERE n.nspname = 'trajectory' 
			AND c.relnamespace = n.oid
			AND c.relname = pool_name;

	-- Fetch next id for the new trajectory 
	FOR rec IN SELECT nextval('trajectory.trajectory_id_seq')
	LOOP
		trajectory_id = rec.nextval;
	END LOOP;

	-- Insert a new row in pool
	EXECUTE
	'INSERT INTO trajectory.trajectory VALUES ('
	|| trajectory_id || ', ' 
	|| quote_literal(pool_name) || ', ' 
	|| quote_literal(trj_name) || ', '
	|| srid || ', '
	|| prec || ', '
	|| pool_table_id
	|| ', 0' --default is zero, no extra attributes
	|| ');';

	-- return the trajectory ID
	return trajectory_id;
END;
$$ LANGUAGE 'plpgsql' VOLATILE STRICT;
--} trajectory.CreateTrajectory


--{
--	Delete a trajectory, with given name and temporal constraints, return a result in text.
--    pool_name, name of trajectory set, e.g, 'taxi', 'bus', 'ferry' etc
--    trj_name, name of a trajectory, e.g., 'B123', 'B245', 'C123' etc
--	  tstart, timestamp of the start to remove, can be NULL, means from initial point
--	  tend, timestamp of the end to remove, can be NULL, means to final point
--	  tregin, geometrical region
--	  coveredby, a flag indicates deleting the trajectory inside (or outside) tregin.
--		it's useful, because sometime we focus on urban rather than county area.
--
CREATE OR REPLACE FUNCTION trajectory.DeleteTrajectory(
	pool_name varchar, trj_name varchar, 
	tstart timestamp  DEFAULT NULL,
	tend timestamp DEFAULT NULL,
	tregion geometry DEFAULT NULL,
	coveredby boolean DEFAULT TRUE)
RETURNS text AS $$
DECLARE
	ok boolean;
    rec RECORD;
	result text;
	tid OID;
	trj_samplings_count integer;
	sql text;
BEGIN
	result = 'trajectory.DeleteTrajectory() - you can never see this line';

    -- Verify pool name and trajectory name
    IF pool_name = '' OR trj_name = '' THEN
        RAISE EXCEPTION 'trajectory.DeleteTrajectory() - Either pool name or trajectory name should NOT be NULL';
    END IF;

    -- Fetch the table id from trajectory.trajectory
	ok = false;
    FOR rec IN SELECT id FROM trajectory.trajectory 
		WHERE poolname = pool_name AND trjname = trj_name
    LOOP
	---- Generate SQL string according to temporal constraints
		sql := 'DELETE FROM trajectory.' || quote_ident(pool_name) 
			|| ' WHERE id = ' || rec.id;

		IF tstart IS NOT NULL THEN
			sql := sql || ' AND time >= TIMESTAMP ' || quote_literal(tstart);
		END IF;

		IF tend IS NOT NULL THEN
			sql := sql || ' AND time <= TIMESTAMP ' || quote_literal(tend);
		END IF;

		IF tregion IS NOT NULL THEN
			IF coveredby IS TRUE THEN
				sql := sql || ' AND ST_CoveredBy(position,' || quote_literal(tregion) || '::geometry)';
			ELSE
				sql := sql || ' AND NOT ST_CoveredBy(position,' || quote_literal(tregion) || '::geometry)';
			END IF;
		END IF;

    ---- Delete the sampling data firstly
        EXECUTE sql;

    ---- Delete the metadata secondly if all its samplings are removed
		trj_samplings_count := 0;
		sql := 'SELECT count(*) FROM trajectory.' || quote_ident(pool_name)
			|| ' WHERE id = ' || rec.id; 
        EXECUTE sql INTO trj_samplings_count;

		IF FOUND AND trj_samplings_count = 0 THEN
	        EXECUTE 'DELETE FROM trajectory.trajectory WHERE poolname = ' 
				|| quote_literal(pool_name) || ' AND trjname = ' 
				|| quote_literal(trj_name);
		END IF;

    ---- Remove the pool table if the table is empty
        SELECT id INTO tid FROM trajectory.trajectory WHERE poolname = pool_name;
        IF NOT FOUND THEN
			EXECUTE 'DROP TABLE trajectory.' || quote_ident(pool_name);
			RAISE DEBUG 'trajectory.DeleteTrajectory() - Table % is removed as it is empty.', pool_name;
		END IF;

	---- we have touched something
		ok = true;
    END LOOP;

	-- the trajectory pool not found
	IF NOT ok THEN
		RAISE EXCEPTION 'trajectory.DeleteTrajectory() - Trajectory % (%) not found', pool_name, trj_name;
	ELSE
		IF trj_samplings_count = 0 THEN
		result = 'Trajectory ' || pool_name || ' (' || trj_name 
				|| ') (with id = ' || rec.id || ') is removed successfully.';
		ELSE
		result = 'Trajectory ' || pool_name || ' (' || trj_name 
				|| ') (with id = ' || rec.id || ') remains ' 
				|| trj_samplings_count || ' samplings.';
		END IF;
	END IF;

    -- return the trajectory ID
    return result;
END;
$$ LANGUAGE 'plpgsql' VOLATILE;
--} trajectory.DeleteTrajectory(with temporal constraints)


--{
--  Delete a trajectory, with given name, return a result in text.
--    pool_name, name of trajectory set, e.g, 'taxi', 'bus', 'ferry' etc
--    trj_name, name of a trajectory, e.g., 'B123', 'B245', 'C123' etc
--
--  TODO We do not consider to remove multiple trajectories once a time
--
--CREATE OR REPLACE FUNCTION trajectory.DeleteTrajectory(pool_name varchar, trj_name varchar)
--RETURNS text AS $$
--	SELECT trajectory.DeleteTrajectory($1, $2,NULL,NULL,NULL); 
--			TIMESTAMP '-infinity', TIMESTAMP 'infinity');
--$$ LANGUAGE 'sql' VOLATILE STRICT;
--} trajectory.DeleteTrajectory


--{
--  Delete a trajectory, with given name, return a result in text.
--    pool_name, name of trajectory set, e.g, 'taxi', 'bus', 'ferry' etc
--    trj_name, name of a trajectory, e.g., 'B123', 'B245', 'C123' etc
--
--  TODO We do not consider to remove multiple trajectories once a time
--
CREATE OR REPLACE FUNCTION trajectory.DeleteTrajectory(pool_name varchar, trj_name varchar,tregion geometry, coveredby boolean DEFAULT TRUE)
RETURNS text AS $$
    SELECT trajectory.DeleteTrajectory($1, $2, NULL, NULL, $3, $4);
--    SELECT trajectory.DeleteTrajectory($1, $2, TIMESTAMP '-infinity', TIMESTAMP 'infinity', $3);
$$ LANGUAGE 'sql' VOLATILE STRICT;
--} trajectory.DeleteTrajectory


--{ 
--  Append a GPS sampling onto a trajectory
--    pool_name, name of trajectory set, e.g, 'taxi', 'bus', 'ferry' etc
--    trj_name, name of a trajectory, e.g., 'B123', 'B245', 'C123' etc
--    t timestamp, e.g., '2015-10-28 14:58:00'
--    pos geometry, e.g.,ST_GeomFromText('POINT(119.4 39.4)', 4326)
--
CREATE OR REPLACE FUNCTION trajectory.AppendTrajectory(pool_name varchar, trj_name varchar, t timestamp, pos geometry)
RETURNS boolean AS $$
DECLARE
    ok boolean;
    trajectory_id OID;
	tsrid integer;
	csrid integer;
	cpos geometry; -- the parameter is not editable sometime
BEGIN
    -- Verify pool name and trajectory name
    IF pool_name = '' OR trj_name = '' THEN
        RAISE EXCEPTION 'trajectory.AppendTrajectory() - Either pool name or trajectory name should NOT be NULL';
    END IF;

    -- Fetch the table id from trajectory.trajectory
	BEGIN
    SELECT id, srid INTO STRICT trajectory_id, tsrid FROM trajectory.trajectory 
		WHERE poolname = pool_name AND trjname = trj_name;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
			RAISE EXCEPTION 'trajectory % (%) not found.', pool_name, trj_name;
		WHEN TOO_MANY_ROWS THEN
			RAISE EXCEPTION 'trajectory % (%) not unique, it''s impossible.', pool_name, trj_name;
	END;

	-- Check the srid, if not match, set to column SRID (unset, default is 0) or transform it
	csrid = ST_SRID(pos);
	IF tsrid != csrid THEN
		RAISE WARNING 'Geometry SRID (%) does not match column SRID (%)', csrid, tsrid;
		IF csrid = 0 THEN
			cpos = ST_SetSRID(pos, tsrid);
			RAISE WARNING 'We update the position''s Geometry SRID to %', tsrid;
		ELSE
			cpos = ST_Transform(pos, tsrid);
			RAISE WARNING 'We transform the position''s Geometry SRID to %', tsrid;
		END IF;
	ELSE
		cpos = pos;
	END IF;

	-- Append this sampling to the real storage table
	EXECUTE 'INSERT INTO trajectory.' || quote_ident(pool_name) 
		|| '(id, time, position) VALUES ('
		|| trajectory_id || ','
		|| quote_literal(t) || ','
		|| quote_literal(cpos)
		|| ')';

	IF NOT FOUND THEN
		RAISE EXCEPTION 'trajectory.AppendTrajectory() - append failed';
		RETURN false;
	END IF;

	RETURN true;
END;
$$ LANGUAGE 'plpgsql' VOLATILE STRICT;
--} trajectory.AppendTrajectory

--{
--  Append a GPS sampling onto a trajectory
--    pool_name, name of trajectory set, e.g, 'taxi', 'bus', 'ferry' etc
--    trj_name, name of a trajectory, e.g., 'B123', 'B245', 'C123' etc
--    tpoint, TPoint type, e.g.,
--      row('2015-10-28 14:58:00'::timestamp, 'ST_Point(119.4, 39.4)'::point)::trajectory.TPoint;
--
CREATE OR REPLACE FUNCTION trajectory.AppendTrajectory(pool_name varchar, trj_name varchar, tp trajectory.TPoint)
RETURNS boolean AS 
	'SELECT trajectory.AppendTrajectory($1, $2, $3.time, geometry($3.position))'
	LANGUAGE 'sql' IMMUTABLE STRICT;
--} trajectory.AppendTrajectory



--  Extend the trajectory pool with a new column
--    pool_name, name of trajectory set, e.g, 'taxi', 'bus', 'ferry' etc
--    column_info , e.g., 'speed real DEFAULT 0.0', 
--				or 'direction real DEFAULT 0.0 CHECK (direction <= 360.0)' 
--
CREATE OR REPLACE FUNCTION trajectory.AddTrajectoryColumns(pool_name varchar, column_info varchar)
RETURNS text AS $$
DECLARE
	attr_count integer;
	sql text;
BEGIN
    -- Verify pool name and column name
    IF pool_name = '' OR column_info = '' THEN
        RAISE EXCEPTION 'trajectory.AddTrajectoryColumns() - Either trajectory pool or new column ''s names should NOT be NULL';
    END IF;

    -- Fetch the attribute number from trajectory.trajectory
    SELECT attrcount INTO attr_count 
		FROM trajectory.trajectory 
		WHERE poolname = pool_name LIMIT 1;
    IF NOT FOUND THEN
		RAISE EXCEPTION 'trajectory pool % not found.', pool_name;
	END IF;

	-- Add one extra column
	sql := 'ALTER TABLE trajectory.' || quote_ident(pool_name)
		|| ' ADD COLUMN ' || column_info; 
	RAISE DEBUG ' ---> %', sql;
	EXECUTE sql;

	-- update the attribute number
	attr_count = attr_count + 1;
	sql := 'UPDATE trajectory.trajectory'
		|| ' SET attrcount = ' || attr_count 
		|| ' WHERE poolname = ' || quote_literal(pool_name);
	RAISE DEBUG ' ---> %', sql;
	EXECUTE sql;

	RETURN 'trajectory.' || pool_name || '.' || split_part(column_info, ' ', 1) || ' added.'; 
END;
$$ LANGUAGE 'plpgsql' VOLATILE STRICT;
--} trajectory.AddTrajectoryColumns



--  Drop a column from the trajectory pool
--    pool_name, name of trajectory set, e.g, 'taxi', 'bus', 'ferry' etc
--    column_info , e.g., 'speed'
--
CREATE OR REPLACE FUNCTION trajectory.DropTrajectoryColumns(pool_name varchar, column_info varchar)
RETURNS text AS $$
DECLARE
    attr_count integer;
    sql text;
BEGIN
    -- Verify pool name and column name
    IF pool_name = '' OR column_info = '' THEN
        RAISE EXCEPTION 'trajectory.DropTrajectoryColumns() - Either trajectory pool or new column ''s names should NOT be NULL';
    END IF;

    -- Fetch the attribute number from trajectory.trajectory
    SELECT attrcount INTO attr_count FROM trajectory.trajectory WHERE poolname = pool_name LIMIT 1;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'trajectory pool % not found.', pool_name;
    END IF;

    -- Drop one extra column
    sql := 'ALTER TABLE trajectory.' || quote_ident(pool_name)
        || ' DROP COLUMN ' || column_info;
    RAISE DEBUG ' ---> %', sql;
    EXECUTE sql;

    -- update the attribute number
    attr_count = attr_count - 1;
    sql := 'UPDATE trajectory.trajectory'
        || ' SET attrcount = ' || attr_count
        || ' WHERE poolname = ' || quote_literal(pool_name);
    RAISE DEBUG ' ---> %', sql;
    EXECUTE sql;

    RETURN 'trajectory.' || pool_name || '.' || split_part(column_info, ' ', 1) || ' removed.';
END;
$$ LANGUAGE 'plpgsql' VOLATILE STRICT;
--} trajectory.DropTrajectoryColumns




--{
--  Append a GPS sampling onto a trajectory
--    pool_name, name of trajectory set, e.g, 'taxi', 'bus', 'ferry' etc
--    trj_name, name of a trajectory, e.g., 'B123', 'B245', 'C123' etc
--    t timestamp, e.g., '2015-10-28 14:58:00'
--    pos geometry, e.g.,ST_GeomFromText('POINT(119.4 39.4)', 4326)
--
CREATE OR REPLACE FUNCTION trajectory.AppendTrajectoryWithAttr(
	pool_name varchar, trj_name varchar,
	t timestamp, pos geometry, 
	VARIADIC attributes varchar[])
RETURNS boolean AS $$
DECLARE
    trajectory_id OID;
    _srid integer;
	_attrcount integer;
	in_attrcount integer;
    col_srid integer;
    col_pos geometry; -- the parameter is not editable sometime
	sql text;
BEGIN
    -- Verify pool name and trajectory name
    IF pool_name = '' OR trj_name = '' THEN
        RAISE EXCEPTION 'trajectory.AppendTrajectory() - Either pool name or trajectory name should NOT be NULL';
    END IF;

    -- Fetch the table id from trajectory.trajectory
    BEGIN
    SELECT id, srid, attrcount INTO STRICT trajectory_id, _srid, _attrcount
		FROM trajectory.trajectory
        WHERE poolname = pool_name AND trjname = trj_name;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE EXCEPTION 'trajectory % (%) not found.', pool_name, trj_name;
        WHEN TOO_MANY_ROWS THEN
            RAISE EXCEPTION 'trajectory % (%) not unique, it''s impossible.', pool_name, trj_name;
    END;

    -- Check the srid, if not match, set to column SRID (unset, default is 0) or transform it
    col_srid := ST_SRID(pos);
    IF _srid != col_srid THEN
        RAISE WARNING 'Geometry SRID (%) does not match column SRID (%)', col_srid, _srid;
        IF col_srid = 0 THEN
            col_pos := ST_SetSRID(pos, _srid);
            RAISE WARNING 'We update the position''s Geometry SRID to %', _srid;
        ELSE
            col_pos := ST_Transform(pos, _srid);
            RAISE WARNING 'We transform the position''s Geometry SRID to %', _srid;
        END IF;
    ELSE
        col_pos := pos;
    END IF;

	-- Check the number of attributes
	in_attrcount := array_length(attributes,1);
	IF _attrcount != in_attrcount THEN
		RAISE WARNING 'trajectory.AppendTrajectoryWithAttr() - Input attributes #% != attribute columns #%.', in_attrcount, _attrcount;
	END IF;

    -- Append this sampling to the real storage table
    sql := 'INSERT INTO trajectory.' || quote_ident(pool_name)
        || ' VALUES ('
        || trajectory_id || ','
        || quote_literal(t) || ','
        || quote_literal(col_pos);
	FOR i in 1..in_attrcount LOOP
		sql := sql || ',' || quote_literal(attributes[i]); 
	END LOOP;
	sql := sql || ')';
    RAISE DEBUG ' ---> %', sql;
	EXECUTE sql;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'trajectory.AppendTrajectoryWithAttr() - append failed';
        RETURN false;
    END IF;

    RETURN true;
END;
$$ LANGUAGE 'plpgsql' VOLATILE STRICT;
--} trajectory.AppendTrajectoryWithAttr


-----------------------------------------------------------------------
-- TRIP is the basic type for understanding the trajectories, e.g,
--    we wanna 
-----------------------------------------------------------------------
-- Composite Types used in SQL as 
--    the argument or return type of UDFs
CREATE TYPE trajectory.TripHead AS (
	name varchar,
	lifespan trajectory.TPeriod,
	extent trajectory.TRegion,
	npoint integer
);

CREATE TYPE trajectory.TripBody AS (
	head trajectory.TripHead,
	trace trajectory.TPoint []
);

-- Expend it to flat
CREATE TYPE trajectory.Trip AS (
	tid OID,
    tstart timestamp,
    tend timestamp
);


------------------------------------------------------------------------------
-- Trip
--	We treat a subsegment truncted by temporal and/or spatial constraints
--  An illustration on trajectory concepts is:
--		Routes 1-->n Trajectories 1-->n Trips
--			where '1-->n' is a one-to-many relationship
--
--	In this version we focus on trip-related operations. A trajectory can
--		be treated as one trip. 
------------------------------------------------------------------------------


-- Trip in/out functions
-- Example of GetTrip():
-- SELECT intgeom
-- FROM (
--   SELECT ST_Intersection(t1, t2) AS intgeom
--   FROM GetTrip('taxi','b1234', period) t1,
--		  GetTrip('taxi','b4567', period) t2
--   WHERE ST_Intersects(t1, t2);
-- ) foo
-- WHERE NOT ST_IsEmpty(intgeom);


------------------------------------------------------------------------------
-- Point Query
------------------------------------------------------------------------------

--{
--  Retrive a trajectory with a 'point' constrain
--    Here 'point' may be a time point, or a spatial point
--    Usecases:
--		Select atinstant(Trip, time)
--		FROM GetTrip('taxi','b1234') t1;
--    e.g, 'taxi', 'bus', 'ferry' etc
--CREATE OR REPLACE FUNCTION trajectory.atInstant()


-- Range Query
--{
--  Retrive a trajectory with a 'range' constrain
--    e.g, 'taxi', 'bus', 'ferry' etc


------------------------------------------------------------------------------
-- Trajectory Type as base types used in table definition
------------------------------------------------------------------------------
-- Head (meta-data) of trajectory
CREATE OR REPLACE FUNCTION trajectory_head_in(cstring)
    RETURNS trajectoryHead
    AS '$libdir/trajectory-1.0','trajectory_head_in'
    LANGUAGE 'c' IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION trajectory_head_out(trajectoryHead)
    RETURNS cstring
    AS '$libdir/trajectory-1.0','trajectory_head_out'
    LANGUAGE 'c' IMMUTABLE STRICT;

CREATE TYPE trajectoryHead (
    input = trajectory_head_in,
    output = trajectory_head_out
);

-- Body of trajectory
CREATE OR REPLACE FUNCTION trajectory_in(cstring)
    RETURNS trajectory
    AS '$libdir/trajectory-1.0','trajectory_in'
    LANGUAGE 'c' IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION trajectory_out(trajectory)
    RETURNS cstring
    AS '$libdir/trajectory-1.0','trajectory_out'
    LANGUAGE 'c' IMMUTABLE STRICT;

CREATE TYPE trajectory (
    internallength = variable,
    input = trajectory_in,
    output = trajectory_out,
    storage = extended
);

------------------------------------------------------------------------------
-- FUNCTIONS
-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- Raster Accessors
-----------------------------------------------------------------------

------------------------------------------------------------------------------
-- trajectory_columns
--
------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION _trajectory_info_extent(trjschema name, trjtable name, trjcolumn name)
	RETURNS BOX AS $$
	SELECT '((0,0),(0,0))'::Box
	$$ LANGUAGE 'sql' STABLE STRICT;

--	SELECT ST_Extent('position'::name) FROM 'trajectory.pool_' || quote_ident(pool_name) WHERE

CREATE OR REPLACE VIEW trajectory_columns AS
    SELECT
		current_database() AS trj_table_catalog,
		n.nspname AS trj_table_schema,
		c.relname AS trj_table_name,
		a.attname AS trj_trajectory_column,
		_trajectory_info_extent(n.nspname, c.relname, a.attname) AS trj_extent
	FROM
		pg_class c,
		pg_attribute a,
		pg_type t,
		pg_namespace n
	WHERE t.typname = 'trajectory'::name
		AND a.attisdropped = false
		AND a.atttypid = t.oid
		AND a.attrelid = c.oid
		AND c.relnamespace = n.oid
		AND c.relkind = ANY(ARRAY['r'::char, 'v'::char, 'm'::char, 'f'::char])
		AND NOT pg_is_other_temp_schema(c.relnamespace);

-------------------------------------------------------------------
--  END
-------------------------------------------------------------------
-- make views public viewable --
GRANT SELECT ON TABLE trajectory_columns TO public;
--GRANT SELECT ON TABLE trajectory_overviews TO public;

COMMIT;
