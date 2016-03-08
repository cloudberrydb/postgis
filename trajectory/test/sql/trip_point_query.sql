--
-- check_postgis_installed
--

\c trjregression

SET client_min_messages TO warning;

-- create a trajectory
SELECT trajectory.CreateTrajectory('taxi', 'B134',  4326, 0.00001);

-- insert 11 samplings
SELECT trajectory.AppendTrajectory('taxi', 'B134', '2015-10-20 8:00:00', ST_SetSRID(ST_Point(119.6, 39.2),4326)); --Point 0
SELECT trajectory.AppendTrajectory('taxi', 'B134', '2015-10-20 8:05:00', ST_SetSRID(ST_Point(119.5, 39.2),4326)); --Point 1
SELECT trajectory.AppendTrajectory('taxi', 'B134', '2015-10-20 8:10:00', ST_SetSRID(ST_Point(119.4, 39.2),4326)); --Point 2
SELECT trajectory.AppendTrajectory('taxi', 'B134', '2015-10-20 8:15:00', ST_SetSRID(ST_Point(119.3, 39.2),4326)); --Point 3
SELECT trajectory.AppendTrajectory('taxi', 'B134', '2015-10-20 8:20:00', ST_SetSRID(ST_Point(119.3, 39.3),4326)); --Point 4
SELECT trajectory.AppendTrajectory('taxi', 'B134', '2015-10-20 8:25:00', ST_SetSRID(ST_Point(119.4, 39.3),4326)); --Point 5
SELECT trajectory.AppendTrajectory('taxi', 'B134', '2015-10-20 8:30:00', ST_SetSRID(ST_Point(119.5, 39.3),4326)); --Point 6
SELECT trajectory.AppendTrajectory('taxi', 'B134', '2015-10-20 8:35:00', ST_SetSRID(ST_Point(119.6, 39.3),4326)); --Point 7
SELECT trajectory.AppendTrajectory('taxi', 'B134', '2015-10-20 8:40:00', ST_SetSRID(ST_Point(119.6, 39.4),4326)); --Point 8
SELECT trajectory.AppendTrajectory('taxi', 'B134', '2015-10-20 8:45:00', ST_SetSRID(ST_Point(119.5, 39.4),4326)); --Point 9
SELECT trajectory.AppendTrajectory('taxi', 'B134', '2015-10-20 8:50:00', ST_SetSRID(ST_Point(119.4, 39.4),4326)); --Point 10

-- query them
SELECT 'taxi' as pool, 'B134' as taxi, time, ST_AsText(position) as position 
FROM taxi 
WHERE id = name2id('taxi', 'B134') ORDER BY time;

-- Point query functions for Trip
---------------------------------------------------------------
-- atInstant(time)
---------------------------------------------------------------
-- trip case #1 from gettrip.sql
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
SELECT trajectory.GetTrip('taxi', 'B134', ST_SetSRID(ST_MakeBox2D(ST_Point(119.25, 39.15),ST_Point(119.65, 39.35)),4326));

-- inner range (given exact time point)
SELECT trip, time, row((atInstant).time, ST_AsText((atInstant).position)) atInstant
    FROM
    (SELECT trip, time, trajectory.atInstant(trip, time) as atInstant
        FROM
        (SELECT trajectory.GetTrip('taxi', 'B134',
            ST_SetSRID(ST_MakeBox2D(ST_Point(119.25, 39.15),
                                    ST_Point(119.65, 39.35)),4326)) as trip
        ) trip,
        (SELECT TIMESTAMP '2015-10-20 08:35:00' as time) time
    ) foo;

-- inner range (given intermedia time point)
SELECT trip, time, row((atInstant).time, ST_AsText((atInstant).position)) atInstant
    FROM
    (SELECT trip, time, trajectory.atInstant(trip, time) as atInstant
        FROM
        (SELECT trajectory.GetTrip('taxi', 'B134',
            ST_SetSRID(ST_MakeBox2D(ST_Point(119.25, 39.15),
                                    ST_Point(119.65, 39.35)),4326)) as trip
        ) trip,
        (SELECT TIMESTAMP '2015-10-20 08:03:00' as time) time
    ) foo;



-- trip query wth spatial constraints
-- CASE #2 from gettrip.sql
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
SELECT * FROM trajectory.GetTrip('taxi', 'B134', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.65, 39.35)),4326));

-- inner range (given exact time point of one trip)
SELECT trip, time, row((atInstant).time, ST_AsText((atInstant).position)) atInstant
    FROM
    (SELECT trip, time, trajectory.atInstant(trip, time) as atInstant
        FROM
        (SELECT trajectory.GetTrip('taxi', 'B134',
            ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),
                                    ST_Point(119.65, 39.35)),4326)) as trip
        ) trip,
        (SELECT TIMESTAMP '2015-10-20 08:35:00' as time) time
    ) foo;

-- inner range (given intermedia time point of one trip)
SELECT trip, time, row((atInstant).time, ST_AsText((atInstant).position)) atInstant
    FROM
    (SELECT trip, time, trajectory.atInstant(trip, time) as atInstant
        FROM
        (SELECT trajectory.GetTrip('taxi', 'B134',
            ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),
                                    ST_Point(119.65, 39.35)),4326)) as trip
        ) trip,
        (SELECT TIMESTAMP '2015-10-20 08:03:00' as time) time
    ) foo;

-- out of range (given time point between trips)
SELECT trip, time, row((atInstant).time, ST_AsText((atInstant).position)) atInstant
    FROM
    (SELECT trip, time, trajectory.atInstant(trip, time) as atInstant
        FROM
        (SELECT trajectory.GetTrip('taxi', 'B134',
            ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),
                                    ST_Point(119.65, 39.35)),4326)) as trip
        ) trip,
        (SELECT TIMESTAMP '2015-10-20 08:20:00' as time) time
    ) foo;

---------------------------------------------------------------
-- atInstant(spatial)
---------------------------------------------------------------
-- trip case #1 from gettrip.sql
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
SELECT trajectory.GetTrip('taxi', 'B134', ST_SetSRID(ST_MakeBox2D(ST_Point(119.25, 39.15),ST_Point(119.65, 39.35)),4326));

-- trip case #1 and query point #5 and default precision
SELECT trip, ST_AsText(position) position, row((atInstant).time, ST_AsText((atInstant).position)) atInstant
    FROM
    (SELECT trip, position, trajectory.atInstant(trip, position) as atInstant
        FROM
        (SELECT trajectory.GetTrip('taxi', 'B134',
            ST_SetSRID(ST_MakeBox2D(ST_Point(119.25, 39.15),
                                    ST_Point(119.65, 39.35)),4326)) as trip
        ) trip,
        (SELECT ST_SetSRID(ST_Point(119.4, 39.3),4326) as position) position 
    ) foo;

-- trip case #1 and query point near #5 and default precision
SELECT trip, ST_AsText(position) position, row((atInstant).time, ST_AsText((atInstant).position)) atInstant
    FROM
    (SELECT trip, position, trajectory.atInstant(trip, position) as atInstant
        FROM
        (SELECT trajectory.GetTrip('taxi', 'B134',
            ST_SetSRID(ST_MakeBox2D(ST_Point(119.25, 39.15),
                                    ST_Point(119.65, 39.35)),4326)) as trip
        ) trip,
        (SELECT ST_SetSRID(ST_Point(119.42, 39.3),4326) as position) position
    ) foo;

-- trip case #1 and query point near #5 and given precision 0.03
SELECT trip, ST_AsText(position) position, row((atInstant).time, ST_AsText((atInstant).position)) atInstant
    FROM
    (SELECT trip, position, trajectory.atInstant(trip, position, 0.03) as atInstant
        FROM
        (SELECT trajectory.GetTrip('taxi', 'B134',
            ST_SetSRID(ST_MakeBox2D(ST_Point(119.25, 39.15),
                                    ST_Point(119.65, 39.35)),4326)) as trip
        ) trip,
        (SELECT ST_SetSRID(ST_Point(119.42, 39.3),4326) as position) position
    ) foo;


-- trip query wth spatial constraints
-- CASE #2 from gettrip.sql
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
SELECT * FROM trajectory.GetTrip('taxi', 'B134', ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),ST_Point(119.65, 39.35)),4326));

-- trip case #1 and query point #5 and default precision
SELECT trip, ST_AsText(position) position, row((atInstant).time, ST_AsText((atInstant).position)) atInstant
    FROM
    (SELECT trip, position, trajectory.atInstant(trip, position) as atInstant
        FROM
        (SELECT trajectory.GetTrip('taxi', 'B134',
            ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),
                                    ST_Point(119.65, 39.35)),4326)) as trip
        ) trip,
        (SELECT ST_SetSRID(ST_Point(119.4, 39.3),4326) as position) position
    ) foo;

-- trip case #1 and query point #5 and given precision 0.1
SELECT trip, ST_AsText(position) position, row((atInstant).time, ST_AsText((atInstant).position)) atInstant
    FROM
    (SELECT trip, position, trajectory.atInstant(trip, position, 0.1) as atInstant
        FROM
        (SELECT trajectory.GetTrip('taxi', 'B134',
            ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),
                                    ST_Point(119.65, 39.35)),4326)) as trip
        ) trip,
        (SELECT ST_SetSRID(ST_Point(119.4, 39.3),4326) as position) position
    ) foo;

-- trip case #1 and query point near #5 and given precision 0.03
SELECT trip, ST_AsText(position) position, row((atInstant).time, ST_AsText((atInstant).position)) atInstant
    FROM
    (SELECT trip, position, trajectory.atInstant(trip, position, 0.03) as atInstant
        FROM
        (SELECT trajectory.GetTrip('taxi', 'B134',
            ST_SetSRID(ST_MakeBox2D(ST_Point(119.35, 39.15),
                                    ST_Point(119.65, 39.35)),4326)) as trip
        ) trip,
        (SELECT ST_SetSRID(ST_Point(119.41, 39.3),4326) as position) position
    ) foo;


-- drop it
SELECT trajectory.DeleteTrajectory('taxi', 'B134');
