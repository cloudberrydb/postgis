--
-- check_postgis_installed
--

\c trjregression

SET client_min_messages TO warning;

-- create a trajectory
SELECT trajectory.CreateTrajectory('taxi', 'B131',  4326, 0.00001);

-- insert 8 samplings
SELECT trajectory.AppendTrajectory('taxi', 'B131', '2015-10-10 8:10:00', ST_Point(119.4, 39.4));
SELECT trajectory.AppendTrajectory('taxi', 'B131', '2015-10-10 8:15:00', ST_Point(119.4, 39.5));
SELECT trajectory.AppendTrajectory('taxi', 'B131', '2015-10-10 8:20:00', ST_Point(119.5, 39.4));
SELECT trajectory.AppendTrajectory('taxi', 'B131', '2015-10-10 8:25:00', ST_Point(119.5, 39.5));
SELECT trajectory.AppendTrajectory('taxi', 'B131', '2015-10-10 8:30:00', ST_Point(119.6, 39.4));
SELECT trajectory.AppendTrajectory('taxi', 'B131', '2015-10-10 8:35:00', ST_Point(119.6, 39.5));
SELECT trajectory.AppendTrajectory('taxi', 'B131', '2015-10-10 8:40:00', ST_Point(119.5, 39.6));
SELECT trajectory.AppendTrajectory('taxi', 'B131', '2015-10-10 8:45:00', ST_Point(119.6, 39.6));

-- query it
SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;

-----------------------------------------------------------
---  temporal constraints only
-----------------------------------------------------------
-- default (without specify temporal comstrants
SELECT * FROM trajectory.GetTrip('taxi', 'B131');
SELECT * FROM trajectory.GetTrip('taxi', 'B131', NULL, NULL);

-- query time period is older than existing
SELECT * FROM trajectory.GetTrip('taxi', 'B131', '2015-10-10 8:00:00', '2015-10-10 8:05:00');

-- query time period is newer than existing
SELECT * FROM trajectory.GetTrip('taxi', 'B131', '2015-10-10 9:00:00', '2015-10-10 9:05:00');

-- query time period covers tha start timestamp of a trajectory
SELECT * FROM trajectory.GetTrip('taxi', 'B131', '2015-10-10 8:00:00', '2015-10-10 8:20:00');

-- query time period is contained by [start~end] timestamps of a trajectory
SELECT * FROM trajectory.GetTrip('taxi', 'B131', '2015-10-10 8:20:00', '2015-10-10 8:40:00');

-- query time period covers tha end timestamp of a trajectory
SELECT * FROM trajectory.GetTrip('taxi', 'B131', '2015-10-10 8:20:00', '2015-10-10 9:40:00');

-- one side of query time period is NULL
SELECT * FROM trajectory.GetTrip('taxi', 'B131', NULL, '2015-10-10 9:40:00');
SELECT * FROM trajectory.GetTrip('taxi', 'B131', '2015-10-10 8:20:00', NULL);

-- ERROR: end time < start time for query
SELECT * FROM trajectory.GetTrip('taxi', 'B131', '2015-10-10 8:10:00', '2015-10-10 8:05:00');


-----------------------------------------------------------
---  spatial constraints only
-----------------------------------------------------------

-----------------------------------------------------------
---  spatio-temporal constraints
-----------------------------------------------------------


-- drop it
SELECT trajectory.DeleteTrajectory('taxi', 'B131');
