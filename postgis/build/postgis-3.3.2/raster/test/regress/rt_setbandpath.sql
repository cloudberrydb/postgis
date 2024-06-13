DROP EVENT TRIGGER IF EXISTS trg_autovac_disable;

SET postgis.gdal_enabled_drivers = 'GTiff';
SET postgis.enable_outdb_rasters = true;
SET client_min_messages = ERROR;
DROP TABLE IF EXISTS t1;
CREATE TABLE t1 AS
SELECT
	1,
	bandnum,
	isoutdb,
	CASE
		WHEN isoutdb IS TRUE
			THEN strpos(path, 'testraster.tif') > 0
		ELSE NULL
	END,
	outdbbandnum
FROM ST_BandMetadata((SELECT rast FROM raster_outdb_template WHERE rid = 1), ARRAY[]::int[]);

SET postgis.gdal_enabled_drivers = 'GTiff';
SET postgis.enable_outdb_rasters = true;
INSERT INTO t1 SELECT
    2,
    bandnum,
    isoutdb,
    CASE
        WHEN isoutdb IS TRUE
            THEN strpos(path, 'testraster.tif') > 0
        ELSE NULL
    END,
    outdbbandnum
FROM ST_BandMetadata((SELECT ST_SetBandIndex(rast, 1, 2) FROM raster_outdb_template WHERE rid = 1), ARRAY[]::int[]);
SELECT * FROM t1 ORDER BY 1, 2;
RESET client_min_messages;

CREATE EVENT TRIGGER trg_autovac_disable ON ddl_command_end
WHEN TAG IN ('CREATE TABLE','CREATE TABLE AS')
EXECUTE PROCEDURE trg_test_disable_table_autovacuum();
