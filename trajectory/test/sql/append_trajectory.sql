--
-- check_postgis_installed
--

\c trjregression

SET client_min_messages TO warning;

-----------------------------------------
--  add a new trajectory            -----
-----------------------------------------
-- add TAXI
SELECT trajectory.AppendTrajectory('taxi', 'B124', LOCALTIMESTAMP(2), ST_GeomFromText('POINT(119.4 39.4)', 4326));
SELECT trajectory.AppendTrajectory('taxi', 'B124', LOCALTIMESTAMP(2), ST_Transform(ST_GeomFromText('POINT(119.4 39.4)', 4326),2249));
SELECT trajectory.AppendTrajectory('taxi', 'B124', row(LOCALTIMESTAMP(2), ST_Point(119.4, 39.4))::trajectory.TPoint);
SELECT trajectory.AppendTrajectory('taxi', 'B124', row(LOCALTIMESTAMP(2), '(119.4, 39.4)'::point)::trajectory.TPoint);
SELECT trajectory.AppendTrajectory('taxi', 'B246', row(LOCALTIMESTAMP(2), '(119.3, 39.3)'::point)::trajectory.TPoint);
SELECT id, time, ST_AsText(position) as position FROM trajectory.taxi ORDER BY id;
