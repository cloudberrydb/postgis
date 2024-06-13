
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

create table tbl_geomcollection (
	k serial,
	g geometry
);

\copy tbl_geomcollection from 'regress_spgist_index_2d.data' ;

-------------------------------------------------------------------------------

set enable_indexscan = off;
set enable_bitmapscan = off;
set enable_seqscan = on;

select '<<', count(*), qnodes('select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g << t2.g') from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g << t2.g;
select '&<', count(*), qnodes('select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g &< t2.g') from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g &< t2.g;
select '&&', count(*), qnodes('select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g && t2.g') from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g && t2.g;
select '&>', count(*), qnodes('select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g &> t2.g') from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g &> t2.g;
select '>>', count(*), qnodes('select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g >> t2.g') from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g >> t2.g;
select '~=', count(*), qnodes('select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g ~= t2.g') from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g ~= t2.g;
select '~', count(*), qnodes('select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g ~ t2.g') from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g ~ t2.g;
select '@', count(*), qnodes('select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g @ t2.g') from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g @ t2.g;
select '&<|', count(*), qnodes('select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g &<| t2.g') from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g &<| t2.g;
select '<<|', count(*), qnodes('select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g <<| t2.g') from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g <<| t2.g;
select '|>>', count(*), qnodes('select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g |>> t2.g') from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g |>> t2.g;
select '|&>', count(*), qnodes('select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g |&> t2.g') from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g |&> t2.g;

------------------------------------------------------------------------------

create index tbl_geomcollection_spgist_2d_idx on tbl_geomcollection using spgist(g);

set enable_indexscan = on;
set enable_bitmapscan = off;
set enable_seqscan = off;

select ( select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g << t2.g ) as spgistidx,
qnodes(' select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g << t2.g ') as spgidxscan;
select ( select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g &< t2.g ) as spgistidx,
qnodes(' select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g &< t2.g ') as spgidxscan;
select ( select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g && t2.g ) as spgistidx,
qnodes(' select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g && t2.g ') as spgidxscan;
select ( select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g &> t2.g ) as spgistidx,
qnodes(' select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g &> t2.g ') as spgidxscan;
select ( select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g >> t2.g ) as spgistidx,
qnodes(' select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g >> t2.g ') as spgidxscan;
select ( select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g ~= t2.g ) as spgistidx,
qnodes(' select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g ~= t2.g ') as spgidxscan;
select ( select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g ~ t2.g ) as spgistidx,
qnodes(' select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g ~ t2.g ') as spgidxscan;
select ( select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g @ t2.g ) as spgistidx,
qnodes(' select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g @ t2.g ') as spgidxscan;
select ( select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g &<| t2.g ) as spgistidx,
qnodes(' select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g &<| t2.g ') as spgidxscan;
select ( select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g <<| t2.g ) as spgistidx,
qnodes(' select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g <<| t2.g ') as spgidxscan;
select ( select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g |>> t2.g ) as spgistidx,
qnodes(' select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g |>> t2.g ') as spgidxscan;
select ( select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g |&> t2.g ) as spgistidx,
qnodes(' select count(*) from tbl_geomcollection t1, tbl_geomcollection t2 where t1.g |&> t2.g ') as spgidxscan;

-------------------------------------------------------------------------------

DROP TABLE tbl_geomcollection CASCADE;
DROP FUNCTION qnodes;

reset optimizer;
