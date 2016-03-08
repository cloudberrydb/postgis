--
-- check_postgis_installed
--

\c trjregression

SET client_min_messages TO warning;


-----------------------------------------------------------
---  create trajectories
-----------------------------------------------------------
-- 1st taxi and 11 samplings
SELECT trajectory.CreateTrajectory('taxi', 'B136',  4326, 0.00001);
SELECT trajectory.AppendTrajectory('taxi', 'B136', '2015-10-20 8:00:00', ST_SetSRID(ST_Point(119.6, 39.2),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B136', '2015-10-20 8:05:00', ST_SetSRID(ST_Point(119.5, 39.2),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B136', '2015-10-20 8:10:00', ST_SetSRID(ST_Point(119.4, 39.2),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B136', '2015-10-20 8:15:00', ST_SetSRID(ST_Point(119.3, 39.2),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B136', '2015-10-20 8:20:00', ST_SetSRID(ST_Point(119.3, 39.3),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B136', '2015-10-20 8:25:00', ST_SetSRID(ST_Point(119.4, 39.3),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B136', '2015-10-20 8:30:00', ST_SetSRID(ST_Point(119.5, 39.3),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B136', '2015-10-20 8:35:00', ST_SetSRID(ST_Point(119.6, 39.3),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B136', '2015-10-20 8:40:00', ST_SetSRID(ST_Point(119.6, 39.4),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B136', '2015-10-20 8:45:00', ST_SetSRID(ST_Point(119.5, 39.4),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B136', '2015-10-20 8:50:00', ST_SetSRID(ST_Point(119.4, 39.4),4326));

-- 2nd taxi and 5 samplings
SELECT trajectory.CreateTrajectory('taxi', 'B137',  4326, 0.00001);
SELECT trajectory.AppendTrajectory('taxi', 'B137', '2015-10-20 8:00:00', ST_SetSRID(ST_Point(119.6, 39.2),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B137', '2015-10-20 8:05:00', ST_SetSRID(ST_Point(119.5, 39.2),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B137', '2015-10-20 8:10:00', ST_SetSRID(ST_Point(119.4, 39.2),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B137', '2015-10-20 8:15:00', ST_SetSRID(ST_Point(119.3, 39.2),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B137', '2015-10-20 8:20:00', ST_SetSRID(ST_Point(119.3, 39.3),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B137', '2015-10-20 8:25:00', ST_SetSRID(ST_Point(119.4, 39.3),4326));

-- 1st bus with 6 samplings
SELECT trajectory.CreateTrajectory('bus', 'A101',  4326, 0.00001);
SELECT trajectory.AppendTrajectory('bus', 'A101', '2015-10-20 8:25:00', ST_SetSRID(ST_Point(119.4, 39.3),4326));
SELECT trajectory.AppendTrajectory('bus', 'A101', '2015-10-20 8:30:00', ST_SetSRID(ST_Point(119.5, 39.3),4326));
SELECT trajectory.AppendTrajectory('bus', 'A101', '2015-10-20 8:35:00', ST_SetSRID(ST_Point(119.6, 39.3),4326));
SELECT trajectory.AppendTrajectory('bus', 'A101', '2015-10-20 8:40:00', ST_SetSRID(ST_Point(119.6, 39.4),4326));
SELECT trajectory.AppendTrajectory('bus', 'A101', '2015-10-20 8:45:00', ST_SetSRID(ST_Point(119.5, 39.4),4326));
SELECT trajectory.AppendTrajectory('bus', 'A101', '2015-10-20 8:50:00', ST_SetSRID(ST_Point(119.4, 39.4),4326));


-----------------------------------------------------------
---  query the trips with temproal and/or spatial constraints
-----------------------------------------------------------
-- minimized parameters
SELECT id2name(trip.tid), trip.* FROM trajectory.GetTrips('taxi') as trip;

-- temporal only 
SELECT id2name(trip.tid), trip.* FROM trajectory.GetTrips('taxi', 
									TIMESTAMP '2015-10-20 8:10:00', 
									TIMESTAMP '2015-10-20 8:20:00') as trip;

-- spatial only 
SELECT id2name(trip.tid), trip.* FROM trajectory.GetTrips('taxi', 
										ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),
											ST_Point(119.65, 39.35)),4326)
									) as trip;

SELECT id2name(trip.tid), trip.* FROM trajectory.GetTrips('taxi', NULL, NULL, 
										ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),
											ST_Point(119.45, 39.45)),4326)
									) as trip;

SELECT id2name(trip.tid), trip.* FROM trajectory.GetTrips('bus', 
										ST_SetSRID(ST_MakeBox2D(ST_Point(119.25, 39.15),
										ST_Point(119.65, 39.35)),4326)) as trip;

-- both spatial and temproal constraints
SELECT id2name(trip.tid), trip.* FROM trajectory.GetTrips('taxi', 
										TIMESTAMP '2015-10-20 8:10:00',
										TIMESTAMP '2015-10-20 8:15:00',
										ST_SetSRID(ST_MakeBox2D(ST_Point(119.25, 39.15),
											ST_Point(119.65, 39.35)),4326)
									) as trip;

-----------------------------------------------------------
---  drop trajectories
-----------------------------------------------------------
SELECT trajectory.DeleteTrajectory('taxi', 'B136');
SELECT trajectory.DeleteTrajectory('taxi', 'B137');
SELECT trajectory.DeleteTrajectory('bus', 'A101');
