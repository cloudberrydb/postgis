
-- ORCA does not support index scans
set optimizer = off;

CREATE OR REPLACE FUNCTION qnodes(q text) RETURNS text
LANGUAGE 'plpgsql' AS
$$
DECLARE
  exp TEXT;
  mat TEXT[];
  ret TEXT;
BEGIN
  FOR exp IN EXECUTE 'EXPLAIN ' || q
  LOOP
    --RAISE NOTICE 'EXP: %', exp;
    mat := regexp_matches(exp, ' *(?:-> *)?(.*Scan)');
    --RAISE NOTICE 'MAT: %', mat;
    IF mat IS NOT NULL THEN
      ret := mat[1];
    END IF;
    --RAISE NOTICE 'RET: %', ret;
  END LOOP;
  RETURN ret;
END;
$$;

-------------------------------------------------------------------------------

create table tbl_geomcollection_nd (
	k serial,
	g geometry
);

\copy tbl_geomcollection_nd from 'regress_gist_index_nd.data';

-------------------------------------------------------------------------------

set enable_indexscan = off;
set enable_bitmapscan = off;
set enable_seqscan = on;

select '&&&', count(*), qnodes('select count(*) from tbl_geomcollection_nd t1, tbl_geomcollection_nd t2 where t1.g &&& t2.g') from tbl_geomcollection_nd t1, tbl_geomcollection_nd t2 where t1.g &&& t2.g;
select '~~', count(*), qnodes('select count(*) from tbl_geomcollection_nd t1, tbl_geomcollection_nd t2 where t1.g ~~ t2.g') from tbl_geomcollection_nd t1, tbl_geomcollection_nd t2 where t1.g ~~ t2.g;
select '@@', count(*), qnodes('select count(*) from tbl_geomcollection_nd t1, tbl_geomcollection_nd t2 where t1.g @@ t2.g') from tbl_geomcollection_nd t1, tbl_geomcollection_nd t2 where t1.g @@ t2.g;
select '~~=', count(*), qnodes('select count(*) from tbl_geomcollection_nd t1, tbl_geomcollection_nd t2 where t1.g ~~= t2.g') from tbl_geomcollection_nd t1, tbl_geomcollection_nd t2 where t1.g ~~= t2.g;

------------------------------------------------------------------------------

create index tbl_geomcollection_nd_spgist_nd_idx on tbl_geomcollection_nd using spgist(g spgist_geometry_ops_nd);

set enable_indexscan = on;
set enable_bitmapscan = off;
set enable_seqscan = off;

select ( select count(*) from tbl_geomcollection_nd t1, tbl_geomcollection_nd t2 where t1.g &&& t2.g ) as spgistidx,
qnodes(' select count(*) from tbl_geomcollection_nd t1, tbl_geomcollection_nd t2 where t1.g &&& t2.g ') as spgidxscan;
select ( select count(*) from tbl_geomcollection_nd t1, tbl_geomcollection_nd t2 where t1.g ~~ t2.g ) as spgistidx,
qnodes(' select count(*) from tbl_geomcollection_nd t1, tbl_geomcollection_nd t2 where t1.g ~~ t2.g ') as spgidxscan;
select ( select count(*) from tbl_geomcollection_nd t1, tbl_geomcollection_nd t2 where t1.g @@ t2.g ) as spgistidx,
qnodes(' select count(*) from tbl_geomcollection_nd t1, tbl_geomcollection_nd t2 where t1.g @@ t2.g ') as spgidxscan;
select ( select count(*) from tbl_geomcollection_nd t1, tbl_geomcollection_nd t2 where t1.g ~~= t2.g ) as spgistidx,
qnodes(' select count(*) from tbl_geomcollection_nd t1, tbl_geomcollection_nd t2 where t1.g ~~= t2.g ') as spgidxscan;

-------------------------------------------------------------------------------

DROP TABLE tbl_geomcollection_nd CASCADE;
DROP FUNCTION qnodes;

reset optimizer;
