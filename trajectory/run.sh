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



