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
