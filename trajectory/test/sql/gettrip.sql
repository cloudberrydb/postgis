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

-- query all the samplings
SELECT 'taxi' as pool, 'B131' as taxi, time, ST_AsText(position) as position
FROM trajectory.taxi
WHERE id = name2id('taxi', 'B131') ORDER BY time;

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
SELECT trajectory.CreateTrajectory('taxi', 'B132',  4326, 0.00001);
SELECT trajectory.AppendTrajectory('taxi', 'B132', '2015-10-20 8:00:00', ST_SetSRID(ST_Point(119.6, 39.2),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B132', '2015-10-20 8:05:00', ST_SetSRID(ST_Point(119.5, 39.2),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B132', '2015-10-20 8:10:00', ST_SetSRID(ST_Point(119.4, 39.2),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B132', '2015-10-20 8:15:00', ST_SetSRID(ST_Point(119.3, 39.2),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B132', '2015-10-20 8:20:00', ST_SetSRID(ST_Point(119.3, 39.3),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B132', '2015-10-20 8:25:00', ST_SetSRID(ST_Point(119.4, 39.3),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B132', '2015-10-20 8:30:00', ST_SetSRID(ST_Point(119.5, 39.3),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B132', '2015-10-20 8:35:00', ST_SetSRID(ST_Point(119.6, 39.3),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B132', '2015-10-20 8:40:00', ST_SetSRID(ST_Point(119.6, 39.4),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B132', '2015-10-20 8:45:00', ST_SetSRID(ST_Point(119.5, 39.4),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B132', '2015-10-20 8:50:00', ST_SetSRID(ST_Point(119.4, 39.4),4326));

-- query all the samplings
SELECT 'taxi' as pool, 'B132' as taxi, time, ST_AsText(position) as position
FROM trajectory.taxi
WHERE id = name2id('taxi', 'B132') ORDER BY time;

-- case 1:
--
--           10------9------8      #             x-------x------x
--                          |      #                            |
--                          |      #  ***********************
--   4-------5-------6------7     ==> *  4-------5-------6--*---x
--   |                             #  *  |                  *
--   |                             #  *  |                  *
--   3-------2-------1------0      #  *  3-------2-------1--*---x
--                                    ***********************
--
SELECT trajectory.GetTrip('taxi', 'B132', ST_SetSRID(ST_MakeBox2D(ST_Point(119.25, 39.15),ST_Point(119.65, 39.35)),4326));

-- case 2:
--
--           10------9------8      #             x-------x------x
--                          |      #                            |
--                          |      #         ****************
--   4-------5-------6------7     ==>    x---*---5-------6--*---x
--   |                             #     |   *              *
--   |                             #     |   *              *
--   3-------2-------1------0      #     x---*---2-------1--*---x
--                                           ****************
SELECT trajectory.GetTrip('taxi', 'B132', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.65, 39.35)),4326));


-- case 3:
--                                           *********
--           10------9------8      #         *   10--*---x------x
--                          |      #         *       *          |
--                          |      #         *       *          |
--   4-------5-------6------7     ==>    x---*---5---*---x------x
--   |                             #     |   *       *
--   |                             #     |   *       *
--   3-------2-------1------0      #     x---*---2---*---x------x
--                                           *********
--
SELECT trajectory.GetTrip('taxi', 'B132', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.45, 39.45)),4326));

-- add 2 redundant samplings
SELECT trajectory.AppendTrajectory('taxi', 'B132', '2015-10-20 8:50:00', ST_SetSRID(ST_Point(119.3, 39.4),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B132', '2015-10-20 8:50:00', ST_SetSRID(ST_Point(119.3, 39.4),4326));
SELECT trajectory.GetTrip('taxi', 'B132', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.45, 39.45)),4326));

--query all
SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;

-----------------------------------------------------------
---  spatio-temporal constraints
-----------------------------------------------------------
-- trip query wth temporal constraints
SELECT * FROM trajectory.GetTrip('taxi', 'B132', '2015-10-20 8:13:00', '2015-10-20 8:33:00');

-- trip query wth spatial constraints
--
--          10------9------8      #             x-------x------x
--                         |      #                            |
--                         |      #         ****************
--  4-------5-------6------7     ==>    x---*---5-------6--*---x
--  |                             #     |   *              *
--  |                             #     |   *              *
--  3-------2-------1------0      #     x---*---2-------1--*---x
--                                          ****************
--
SELECT * FROM trajectory.GetTrip('taxi', 'B132', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.65, 39.35)),4326));

-- trip query wth both temporal and spatial constraints
SELECT * FROM trajectory.GetTrip('taxi', 'B132', 
	TIMESTAMP '2015-10-20 8:13:00', TIMESTAMP '2015-10-20 8:33:00', 
	ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.65, 39.35)),4326));


-- drop it
SELECT trajectory.DeleteTrajectory('taxi', 'B131');
SELECT trajectory.DeleteTrajectory('taxi', 'B132');
