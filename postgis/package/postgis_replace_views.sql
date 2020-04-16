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

CREATE OR REPLACE VIEW raster_columns AS
    SELECT
        current_database() AS r_table_catalog,
        n.nspname AS r_table_schema,
        c.relname AS r_table_name,
        a.attname AS r_raster_column,
        COALESCE(_raster_constraint_info_srid(n.nspname, c.relname, a.attname), (SELECT ST_SRID('POINT(0 0)'::geometry))) AS srid,
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
