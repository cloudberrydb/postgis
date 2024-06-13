 /***
 *
 * Copyright (C) 2012 Regina Obe and Leo Hsu (Paragon Corporation)
 * Modifications Copyright (c) 2017 - Present Pivotal Software, Inc. All Rights Reserved.
 **/
-- Adds a schema to  the front of search path so that functions, tables etc get installed by default in set schema
-- but if people have postgis and other things installed in non-public, it will still keep those in path
-- Example usage: SELECT tiger.SetSearchPathForInstall('tiger');
DROP FUNCTION IF EXISTS tiger.SetSearchPathForInstall(varchar);
CREATE OR REPLACE FUNCTION tiger.SetSearchPathForInstall(a_schema_name text)
RETURNS text
AS
$$
DECLARE
	var_result text;
	var_cur_search_path text;
BEGIN
	SELECT reset_val INTO var_cur_search_path FROM pg_catalog.pg_settings WHERE name = 'search_path';

	EXECUTE 'SET search_path = ' || pg_catalog.quote_ident(a_schema_name) || ', ' || var_cur_search_path;
	var_result := a_schema_name || ' has been made primary for install ';
  RETURN var_result;
END
$$
LANGUAGE 'plpgsql' VOLATILE STRICT;
