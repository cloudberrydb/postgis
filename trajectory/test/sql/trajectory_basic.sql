--
-- check_postgis_installed
--

\c trjregression

SET client_min_messages TO warning;

-----------------------------------------
--  add a new trajectory            -----
-----------------------------------------
-- add TAXI
SELECT trajectory.CreateTrajectory('taxi', 'T001',  4326, 0.00001);
SELECT trajectory.CreateTrajectory('taxi', 'T002',  4326, 0.00001);
SELECT trajectory.CreateTrajectory('taxi', 'T003',  4326, 0.00001);

-- add BUS
SELECT trajectory.CreateTrajectory('bus', 'B001',  4326, 0.00001);
SELECT trajectory.CreateTrajectory('bus', 'B002',  4326, 0.00001);
SELECT trajectory.CreateTrajectory('bus', 'B003',  4326, 0.00001);

-- add trajectories with conflict name but different pool
SELECT trajectory.CreateTrajectory('bus', 'T001',  4326, 0.00001);
SELECT trajectory.CreateTrajectory('taxi', 'B001',  4326, 0.00001);

-- ERROR: add trajectories with conflict <pool, name>, not unique
SELECT trajectory.CreateTrajectory('taxi', 'T001',  4326, 0.00001);
SELECT trajectory.CreateTrajectory('bus', 'B001',  4326, 0.00001);

-- query them
SELECT id, poolname, trjname from trajectory.trajectory ORDER BY id;

-----------------------------------------
--  delete a new trajectory         -----
-----------------------------------------
-- remove one TAXI trajectory
SELECT trajectory.DeleteTrajectory('taxi', 'T002');
SELECT id, poolname, trjname from trajectory.trajectory where poolname = 'taxi' ORDER BY id;

-- remove one BUS trajectory
SELECT trajectory.DeleteTrajectory('bus', 'B002');
SELECT id, poolname, trjname from trajectory.trajectory where poolname = 'bus' ORDER BY id;

-- remove one trajectory NOT exists
SELECT trajectory.DeleteTrajectory('taxi', 'T002');
SELECT trajectory.DeleteTrajectory('bus', 'B002');
SELECT trajectory.DeleteTrajectory('metro', 'M001');

-- query them
SELECT id, poolname, trjname from trajectory.trajectory ORDER BY id;


-- remove existings 
SELECT trajectory.DeleteTrajectory('taxi', 'B001');
SELECT trajectory.DeleteTrajectory('taxi', 'T001');
SELECT trajectory.DeleteTrajectory('taxi', 'T003');
SELECT trajectory.DeleteTrajectory('bus', 'T001');
SELECT trajectory.DeleteTrajectory('bus', 'B001');
SELECT trajectory.DeleteTrajectory('bus', 'B003');

---- trajectory.DeleteTrajectory() with temporal constraints ------
-------------------------------------------------------------------
-- create new one
SELECT trajectory.CreateTrajectory('taxi', 'T126',  4326, 0.00001);

-- add 5 samplings with same spatial column
SELECT trajectory.AppendTrajectory('taxi', 'T126', '2015-10-10 8:00:00', ST_Point(119.4, 39.4));
SELECT trajectory.AppendTrajectory('taxi', 'T126', '2015-10-10 8:05:00', ST_Point(119.4, 39.4));
SELECT trajectory.AppendTrajectory('taxi', 'T126', '2015-10-10 8:10:00', ST_Point(119.4, 39.4));
SELECT trajectory.AppendTrajectory('taxi', 'T126', '2015-10-10 8:15:00', ST_Point(119.4, 39.4));
SELECT trajectory.AppendTrajectory('taxi', 'T126', '2015-10-10 8:20:00', ST_Point(119.4, 39.4));
SELECT M.poolname, M.trjname, T.time FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;

-- delete 1st
SELECT trajectory.DeleteTrajectory('taxi', 'T126', '-infinity'::timestamp, '2015-10-10 8:03:00'::timestamp);
SELECT M.poolname, M.trjname, T.time FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;

-- delete last
SELECT trajectory.DeleteTrajectory('taxi', 'T126', '2015-10-10 8:18:00'::timestamp, 'infinity'::timestamp);
SELECT M.poolname, M.trjname, T.time FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;

-- delete middle
SELECT trajectory.DeleteTrajectory('taxi', 'T126', '2015-10-10 8:08:00'::timestamp, '2015-10-10 8:13:00'::timestamp);
SELECT M.poolname, M.trjname, T.time FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;

-- delete remaining
SELECT trajectory.DeleteTrajectory('taxi', 'T126');
SELECT M.poolname, M.trjname, T.time FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;


---- trajectory.DeleteTrajectory() with spatial constraints ------
-------------------------------------------------------------------
-- SET 1: NOT coveredby
-- add 8 samplings with different spatial column
--   they forms a shape looks like
--
--           o--------o      #            o--------o
--           |        |      #            |        |
--           |        |      #            |        |
--   o-------o--------o     ==>   o-------x--------x
--   |       |        |      #    |       |        |
--   |       |        |      #    |       |        |
--   o-------o--------o      #    o-------x--------x
--
SELECT trajectory.CreateTrajectory('taxi', 'B127',  4326, 0.00001);
SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:10:00', ST_Point(119.4, 39.4));
SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:15:00', ST_Point(119.4, 39.5));
SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:20:00', ST_Point(119.5, 39.4));
SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:25:00', ST_Point(119.5, 39.5));
SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:30:00', ST_Point(119.6, 39.4));
SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:35:00', ST_Point(119.6, 39.5));
SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:40:00', ST_Point(119.5, 39.6));
SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:45:00', ST_Point(119.6, 39.6));
SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;

-- delete centrial
SELECT trajectory.DeleteTrajectory('taxi', 'B127', ST_SetSRID(ST_MakeBox2D(ST_Point(119.5, 39.4),ST_Point(119.6, 39.5)),4326));
SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;

-- delete remaining
SELECT trajectory.DeleteTrajectory('taxi', 'B127');
SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;

-- SET 2: NOT coveredby
-- add 8 samplings with different spatial column
--   they forms a shape looks like
--
--           o--------o      #            x--------x
--           |        |      #            |        |
--           |        |      #            |        |
--   o-------o--------o     ==>   x-------o--------o
--   |       |        |      #    |       |        |
--   |       |        |      #    |       |        |
--   o-------o--------o      #    x-------o--------o
--
SELECT trajectory.CreateTrajectory('taxi', 'B127',  4326, 0.00001);
SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:10:00', ST_Point(119.4, 39.4));
SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:15:00', ST_Point(119.4, 39.5));
SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:20:00', ST_Point(119.5, 39.4));
SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:25:00', ST_Point(119.5, 39.5));
SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:30:00', ST_Point(119.6, 39.4));
SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:35:00', ST_Point(119.6, 39.5));
SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:40:00', ST_Point(119.5, 39.6));
SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:45:00', ST_Point(119.6, 39.6));
SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;

-- delete centrial
SELECT trajectory.DeleteTrajectory('taxi', 'B127', ST_SetSRID(ST_MakeBox2D(ST_Point(119.5, 39.4),ST_Point(119.6, 39.5)),4326));
SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;

-- delete remaining
SELECT trajectory.DeleteTrajectory('taxi', 'B127');
SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;

---- trajectory.DeleteTrajectory() with spatio-temporal constraints ------
-------------------------------------------------------------------
SELECT trajectory.CreateTrajectory('taxi', 'B128',  4326, 0.00001);
SELECT trajectory.AppendTrajectory('taxi', 'B128', '2015-10-10 8:10:00', ST_Point(119.4, 39.4));
SELECT trajectory.AppendTrajectory('taxi', 'B128', '2015-10-10 8:15:00', ST_Point(119.4, 39.5));
SELECT trajectory.AppendTrajectory('taxi', 'B128', '2015-10-10 8:20:00', ST_Point(119.5, 39.4));
SELECT trajectory.AppendTrajectory('taxi', 'B128', '2015-10-10 8:25:00', ST_Point(119.5, 39.5));
SELECT trajectory.AppendTrajectory('taxi', 'B128', '2015-10-10 8:30:00', ST_Point(119.6, 39.4));
SELECT trajectory.AppendTrajectory('taxi', 'B128', '2015-10-10 8:35:00', ST_Point(119.6, 39.5));
SELECT trajectory.AppendTrajectory('taxi', 'B128', '2015-10-10 8:40:00', ST_Point(119.5, 39.6));
SELECT trajectory.AppendTrajectory('taxi', 'B128', '2015-10-10 8:45:00', ST_Point(119.6, 39.6));
SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) 
	FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;

-- delete centrial
SELECT trajectory.DeleteTrajectory('taxi', 'B128', 
	TIMESTAMP '2015-10-10 8:22:00', TIMESTAMP '2015-10-10 8:27:00', 
	ST_SetSRID(ST_MakeBox2D(ST_Point(119.5, 39.4),ST_Point(119.6, 39.5)),4326));
SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) 
	FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;

-- delete remaining
SELECT trajectory.DeleteTrajectory('taxi', 'B128');
SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) 
	FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;
