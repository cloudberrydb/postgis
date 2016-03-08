make install
dropdb test
createdb test -T gis
psql -d test -f /home/gpadmin/greenplum-db-devel/share/postgresql/contrib/trajectory.sql

# regressing
# make check

# test: prepare datasets
psql -d test -c "SELECT trajectory.CreateTrajectory('taxi', 'B123',  4326, 0.00001)"
psql -d test -c "SELECT trajectory.CreateTrajectory('taxi', 'B124',  4326, 0.00001)"
psql -d test -c "SELECT trajectory.CreateTrajectory('taxi', 'B125',  4326, 0.00001)"
psql -d test -c "SELECT trajectory.DeleteTrajectory('taxi', 'B123')"
psql -d test -c "SELECT * from trajectory.trajectory where poolname = 'taxi'"

# test: Append a trajectory
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B124', LOCALTIMESTAMP(2), ST_GeomFromText('POINT(119.4 39.4)', 4326))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B124', LOCALTIMESTAMP(2), ST_Transform(ST_GeomFromText('POINT(119.4 39.4)', 4326),2249))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B124', row(LOCALTIMESTAMP(2), ST_Point(119.4, 39.4))::trajectory.TPoint)"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B124', row(LOCALTIMESTAMP(2), '(119.4, 39.4)'::point)::trajectory.TPoint)"
psql -d test -c "SELECT id, time, ST_AsText(position) as position from trajectory.taxi"

# test: Add a column
psql -d test -c "SELECT trajectory.AddTrajectoryColumns('taxi', 'speed real DEFAULT 0.0')"
psql -d test -c "SELECT trajectory.AddTrajectoryColumns('taxi', 'direction real DEFAULT 0.0 CHECK (direction <= 360)')"
psql -d test -c "\d trajectory.taxi"

# 	Append with old function
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B124', LOCALTIMESTAMP(2), ST_GeomFromText('POINT(119.4 39.4)', 4326))"

# 	Append with new function
psql -d test -c "SELECT trajectory.AppendTrajectoryWithAttr('taxi', 'B124', LOCALTIMESTAMP(2), ST_GeomFromText('POINT(119.4 39.4)', 4326), '1.1' )"
psql -d test -c "SELECT trajectory.AppendTrajectoryWithAttr('taxi', 'B124', LOCALTIMESTAMP(2), ST_GeomFromText('POINT(119.4 39.4)', 4326), '2.2', '20' )"
psql -d test -c "SELECT trajectory.AppendTrajectoryWithAttr('taxi', 'B124', LOCALTIMESTAMP(2), ST_GeomFromText('POINT(119.4 39.4)', 4326), '3.3', '30', '30' )"

psql -d test -c "SELECT id,time,speed,direction FROM trajectory.taxi ORDER BY id"

# test: Drop a column
psql -d test -c "SELECT trajectory.DropTrajectoryColumns('taxi', 'speed')"
psql -d test -c "\d trajectory.taxi"

psql -d test -c "SELECT trajectory.AppendTrajectoryWithAttr('taxi', 'B124', LOCALTIMESTAMP(2), ST_GeomFromText('POINT(119.4 39.4)', 4326), '40' )"
# error test
psql -d test -c "SELECT trajectory.AppendTrajectoryWithAttr('taxi', 'B124', LOCALTIMESTAMP(2), ST_GeomFromText('POINT(119.4 39.4)', 4326), '500' )"

psql -d test -c "SELECT id,time,direction FROM trajectory.taxi ORDER BY id"


echo "---- trajectory.DeleteTrajectory() with temporal constraints ------"
echo "-------------------------------------------------------------------"
# remove others
psql -d test -c "SELECT M.poolname, M.trjname, T.time FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time"
psql -d test -c "SELECT trajectory.DeleteTrajectory('taxi', 'B124')"
psql -d test -c "SELECT trajectory.DeleteTrajectory('taxi', 'B125')"

# create new one
psql -d test -c "SELECT M.poolname, M.trjname, T.time FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time"
psql -d test -c "SELECT trajectory.CreateTrajectory('taxi', 'B126',  4326, 0.00001)"

# add 5 samplings with same spatial column
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B126', '2015-10-10 8:00:00', ST_Point(119.4, 39.4))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B126', '2015-10-10 8:05:00', ST_Point(119.4, 39.4))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B126', '2015-10-10 8:10:00', ST_Point(119.4, 39.4))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B126', '2015-10-10 8:15:00', ST_Point(119.4, 39.4))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B126', '2015-10-10 8:20:00', ST_Point(119.4, 39.4))"
psql -d test -c "SELECT M.poolname, M.trjname, T.time FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time"

# delete 1st
psql -d test -c "SELECT trajectory.DeleteTrajectory('taxi', 'B126', '-infinity'::timestamp, '2015-10-10 8:03:00'::timestamp)"
psql -d test -c "SELECT M.poolname, M.trjname, T.time FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time"

# delete last
psql -d test -c "SELECT trajectory.DeleteTrajectory('taxi', 'B126', '2015-10-10 8:18:00'::timestamp, 'infinity'::timestamp)"
psql -d test -c "SELECT M.poolname, M.trjname, T.time FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time"

# delete middle 
psql -d test -c "SELECT trajectory.DeleteTrajectory('taxi', 'B126', '2015-10-10 8:08:00'::timestamp, '2015-10-10 8:13:00'::timestamp)"
psql -d test -c "SELECT M.poolname, M.trjname, T.time FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time"

# delete remaining 
psql -d test -c "SELECT trajectory.DeleteTrajectory('taxi', 'B126')"
psql -d test -c "SELECT M.poolname, M.trjname, T.time FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time"


echo "-------------------------------------------------------------------"
echo "---- trajectory.DeleteTrajectory() with spatial constraints ------"

# add 8 samplings with different spatial column
#   they forms a shape looks like
#               
#           o--------o		#            o--------o
#           |        |		#            |        |
#           |        |		#            |        |
#   o-------o--------o	   ==>   o-------x--------x
#   |       |        |		#    |       |        |
#   |       |        |		#    |       |        |
#   o-------o--------o		#    o-------x--------x
#
psql -d test -c "SELECT trajectory.CreateTrajectory('taxi', 'B127',  4326, 0.00001)"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:10:00', ST_Point(119.4, 39.4))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:15:00', ST_Point(119.4, 39.5))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:20:00', ST_Point(119.5, 39.4))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:25:00', ST_Point(119.5, 39.5))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:30:00', ST_Point(119.6, 39.4))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:35:00', ST_Point(119.6, 39.5))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:40:00', ST_Point(119.5, 39.6))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:45:00', ST_Point(119.6, 39.6))"
psql -d test -c "SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time"

# delete centrial
psql -d test -c "SELECT trajectory.DeleteTrajectory('taxi', 'B127', ST_SetSRID(ST_MakeBox2D(ST_Point(119.5, 39.4),ST_Point(119.6, 39.5)),4326))"
psql -d test -c "SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time"

# delete remaining 
psql -d test -c "SELECT trajectory.DeleteTrajectory('taxi', 'B127')"
psql -d test -c "SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time"


# add 8 samplings with different spatial column
#   they forms a shape looks like
#
#           o--------o      #            x--------x
#           |        |      #            |        |
#           |        |      #            |        |
#   o-------o--------o     ==>   x-------o--------o
#   |       |        |      #    |       |        |
#   |       |        |      #    |       |        |
#   o-------o--------o      #    x-------o--------o
#
psql -d test -c "SELECT trajectory.CreateTrajectory('taxi', 'B127',  4326, 0.00001)"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:10:00', ST_Point(119.4, 39.4))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:15:00', ST_Point(119.4, 39.5))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:20:00', ST_Point(119.5, 39.4))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:25:00', ST_Point(119.5, 39.5))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:30:00', ST_Point(119.6, 39.4))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:35:00', ST_Point(119.6, 39.5))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:40:00', ST_Point(119.5, 39.6))"
psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', 'B127', '2015-10-10 8:45:00', ST_Point(119.6, 39.6))"
psql -d test -c "SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time"

# delete centrial
psql -d test -c "SELECT trajectory.DeleteTrajectory('taxi', 'B127', ST_SetSRID(ST_MakeBox2D(ST_Point(119.5, 39.4),ST_Point(119.6, 39.5)),4326), false)"
psql -d test -c "SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time"

# delete remaining
psql -d test -c "SELECT trajectory.DeleteTrajectory('taxi', 'B127')"
psql -d test -c "SELECT M.poolname, M.trjname, T.time, ST_AsText(T.position) FROM trajectory M, taxi T WHERE M.id = T. id ORDER BY T.time"

echo "-------------------------------------------------------------------"
echo "---- trajectory.DeleteTrajectory() with temporal/spatial constraints ------"
