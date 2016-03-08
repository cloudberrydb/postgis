--
-- check_postgis_installed
--

\c trjregression

SET client_min_messages TO warning;

-- add TAXI
SELECT trajectory.CreateTrajectory('taxi', 'B129',  4326, 0.00001);

-- append 5 points
SELECT trajectory.AppendTrajectory('taxi', 'B129', '2015-10-10 8:10:00', ST_GeomFromText('POINT(119.4 39.4)', 4326));
SELECT trajectory.AppendTrajectory('taxi', 'B129', '2015-10-10 8:15:00',  ST_Transform(ST_GeomFromText('POIN    T(119.4 39.4)', 4326),2249));
SELECT trajectory.AppendTrajectory('taxi', 'B129', '2015-10-10 8:20:00', row(LOCALTIMESTAMP(2), ST_Point(119.4, 39.4))::trajectory.TPoint);
SELECT trajectory.AppendTrajectory('taxi', 'B129', '2015-10-10 8:25:00', row(LOCALTIMESTAMP(2), '(119.4, 39.4)'::point)::trajectory.TPoint);
SELECT trajectory.AppendTrajectory('taxi', 'B129', '2015-10-10 8:30:00', row(LOCALTIMESTAMP(2), '(119.3, 39.3)'::point)::trajectory.TPoint);

-- query them
SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position)
    FROM trajectory M, taxi T WHERE M.id = T. id AND M.poolname = 'taxi' AND trjname = 'B129' ORDER BY T.time;

-- drop it
SELECT trajectory.DeleteTrajectory('taxi', 'B129');
