--
-- check_postgis_installed
--

\c trjregression

SET client_min_messages TO warning;

-- create a trajectory
SELECT trajectory.CreateTrajectory('taxi', 'B133',  4326, 0.00001);

-- insert 11 samplings
SELECT trajectory.AppendTrajectory('taxi', 'B133', '2015-10-20 8:00:00', ST_SetSRID(ST_Point(119.6, 39.2),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B133', '2015-10-20 8:05:00', ST_SetSRID(ST_Point(119.5, 39.2),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B133', '2015-10-20 8:10:00', ST_SetSRID(ST_Point(119.4, 39.2),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B133', '2015-10-20 8:15:00', ST_SetSRID(ST_Point(119.3, 39.2),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B133', '2015-10-20 8:20:00', ST_SetSRID(ST_Point(119.3, 39.3),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B133', '2015-10-20 8:25:00', ST_SetSRID(ST_Point(119.4, 39.3),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B133', '2015-10-20 8:30:00', ST_SetSRID(ST_Point(119.5, 39.3),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B133', '2015-10-20 8:35:00', ST_SetSRID(ST_Point(119.6, 39.3),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B133', '2015-10-20 8:40:00', ST_SetSRID(ST_Point(119.6, 39.4),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B133', '2015-10-20 8:45:00', ST_SetSRID(ST_Point(119.5, 39.4),4326));
SELECT trajectory.AppendTrajectory('taxi', 'B133', '2015-10-20 8:50:00', ST_SetSRID(ST_Point(119.4, 39.4),4326));
SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;

-- trip query wth temporal constraints
SELECT * FROM trajectory.GetTrip('taxi', 'B133', '2015-10-20 8:13:00', '2015-10-20 8:33:00');

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
SELECT trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.65, 39.35)),4326));

-- query all 
SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time;



-- I/O functions for Trip
-- trip head/tail
SELECT * FROM trajectory.gettrip('taxi', 'B133', TIMESTAMP '2015-10-20 08:00:00', TIMESTAMP '2015-10-20 08:20:00');
SELECT trajectory.head(trip) FROM trajectory.gettrip('taxi', 'B133', TIMESTAMP '2015-10-20 08:00:00', TIMESTAMP '2015-10-20 08:20:00') AS trip;
SELECT trajectory.tail(trip) FROM trajectory.gettrip('taxi', 'B133', TIMESTAMP '2015-10-20 08:00:00', TIMESTAMP '2015-10-20 08:20:00') AS trip;

-- multiple trips
SELECT trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.65, 39.35)),4326));
SELECT trajectory.head(trip) FROM trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.65, 39.35)),4326)) AS trip;
SELECT trajectory.tail(trip) FROM trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.65, 39.35)),4326)) AS trip;

-- GetID, ID2Name, Name2ID
SELECT trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.45, 39.45)),4326));
	--3 heads
SELECT trajectory.HEAD(trip) FROM trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.45, 39.45)),4326)) AS trip;

	--group by id
SELECT trajectory.GetID(trip) as id FROM trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.45, 39.45)),4326)) AS trip group by id;

	--transfer between ID and Name
SELECT trajectory.ID2Name(id) FROM (SELECT GetID(trip) as id FROM trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.45, 39.45)),4326)) as trip group by id ) foo;
SELECT trajectory.ID2Name(trip.tid) FROM trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.45, 39.45)),4326)) AS trip GROUP BY tid;
SELECT trajectory.Name2ID('taxi','B133');
	--no exists
SELECT trajectory.ID2Name(trip.tid) FROM trajectory.GetTrip('taxi', 'B134', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.45, 39.45)),4326)) AS trip GROUP BY tid;
SELECT trajectory.Name2ID('taxi','B134');

-- Count, MakeLine
SELECT * FROM trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.55, 39.45)),4326)) as trip;
	-- public.count()
SELECT count(*) FROM trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.55, 39.45)),4326)) as trip;

	-- trajectory.count()
SELECT trip, trajectory.Count(trip) FROM trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.55, 39.45)),4326)) as trip;

	-- 3 trips, each of which has 2 point2
SELECT trip.tid AS ID, ST_AsText(MakeLine(trip)) AS Line FROM trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.55, 39.45)),4326)) as trip;
SELECT trajectory.ID2Name(trip.tid) AS Name, trajectory.Count(trip) Points FROM trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.55, 39.45)),4326)) as trip;

	-- 3 trips, each of which has 1 point
SELECT trip.tid AS ID, ST_AsText(MakeLine(trip)) AS Line FROM trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.45, 39.45)),4326)) as trip;
SELECT trajectory.ID2Name(trip.tid) AS Name, trajectory.Count(trip) Points FROM trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.45, 39.45)),4326)) as trip;

	-- 3 trips, each of which has 2 points
SELECT trajectory.ID2Name(trip.tid) AS Name, ST_AsText(MakeLine(trip)) AS Line FROM trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.45, 39.45)),4326)) as trip;
SELECT trajectory.ID2Name(trip.tid) AS Name, MakeGeoJSON(trip) AS JSON FROM trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.55, 39.45)),4326)) as trip;

	-- 2 trips, each of which has 3 point
SELECT trajectory.ID2Name(trip.tid) AS Name, MakeGeoJSON(trip) AS JSON FROM trajectory.GetTrip('taxi', 'B133', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.65, 39.35)),4326)) as trip;


-- drop it
SELECT trajectory.DeleteTrajectory('taxi', 'B133');
