--- build a larger database
\i regress_lots_of_points.sql

--- test some of the searching capabilities

-- GiST index

CREATE INDEX quick_gist on test using gist (the_geom);

set enable_seqscan = on;
set enable_bitmapscan = off;
set enable_indexscan = off;

 select 'test 1: Seq Scan on test';
 select num,ST_astext(the_geom) from test where the_geom && 'BOX3D(125 125,135 135)'::box3d order by num;

--JIRA: MPP-24904, because Bitmap Index Scan is also supported in GPDB
set enable_seqscan = off;
set enable_bitmapscan = on;
set enable_indexscan = on;

 select 'test 2: Bitmap Heap Scan on test + Bitmap Index Scan on quick_gist';
 select num,ST_astext(the_geom) from test where the_geom && 'BOX3D(125 125,135 135)'::box3d  order by num;

--GiST index only
set enable_seqscan = off;
set enable_bitmapscan = off;
set enable_indexscan = on;

 select 'test 3: Index Scan using quick_gist on test';
 select num,ST_astext(the_geom) from test where the_geom && 'BOX3D(125 125,135 135)'::box3d  order by num;

DROP TABLE test;
