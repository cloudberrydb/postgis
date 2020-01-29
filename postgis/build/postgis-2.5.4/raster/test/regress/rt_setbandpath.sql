SET postgis.gdal_enabled_drivers = 'GTiff';
SET postgis.enable_outdb_rasters = true;

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
