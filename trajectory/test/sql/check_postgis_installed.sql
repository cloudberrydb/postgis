--
-- check_postgis_installed
--

\c trjregression

SET client_min_messages TO notice;

CREATE OR REPLACE FUNCTION check_postgis_trajectory() RETURNS text AS $$
DECLARE
  rec RECORD;
  ok1 boolean;
  ok2 boolean;
BEGIN
  ok1 = false;
  ok2 = false;

  FOR rec IN
    (SELECT n.nspname, p.proname FROM pg_proc p, pg_namespace n
    WHERE p.proname = 'postgis_version'
    AND p.pronamespace = n.oid)
  LOOP
    ok1 = true;
--    RAISE NOTICE 'PostGIS is already installed in schema ''%''', rec.nspname;
  END LOOP;

  FOR rec IN
    SELECT nspname FROM pg_namespace WHERE nspname = 'trajectory'
  LOOP
    ok2 = true;
--    RAISE NOTICE 'Trajectory is already installed in schema ''%''', rec.nspname;
  END LOOP;

  IF ( ok1 AND ok2 ) THEN
    RETURN 'Both PostGIS and Trajectory are already installed';
  ELSE
    RETURN 'We need to install both PostGIS and Trajectory';
  END IF;
END;
$$ LANGUAGE 'plpgsql';
SELECT check_postgis_trajectory();
