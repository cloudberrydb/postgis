
TRAJECTORY_VERSION = 1.0
#MODULES = trajectory
MODULE_big = trajectory-$(TRAJECTORY_VERSION)
MODULEDIR = contrib/geospatial
EXTENSION = trajectory
DATA = trajectory.sql
DOCS = README.trj
OBJS = trajectory.o trajectory_functions.o trajectory_model.o

PGXS := $(shell pg_config --pgxs)
include $(PGXS)

#%.o : %.c
#    $(CC) $(CFLAGS) -c -o $@ $< 

test:
	dropdb test
	createdb test -T gis
	make uninstall install
	psql -d test -f $(GPHOME)/share/postgresql/contrib/trajectory.sql
	psql -d test -c "SELECT trajectory.CreateTrajectory('taxi', '1',  4326, 0.00001)"
	psql -d test -c "SELECT trajectory.CreateTrajectory('taxi', '2',  4326, 0.00001)"
#	psql -d test -c "SELECT trajectory.CreateTrajectory('taxi', 'B1234',  4326, 0.00001)"
	psql -d test -c "SELECT trajectory.CreateTrajectory('bus', '1',  4326, 0.00001)"
	psql -d test -c "SELECT trajectory.CreateTrajectory('bus', '2',  4326, 0.00001)"
#	psql -d test -c "SELECT trajectory.DeleteTrajectory('bus', '4')"
	psql -d test -c "SELECT trajectory.DeleteTrajectory('bus', '1')"
	psql -d test -c "SELECT * from trajectory.trajectory where poolname = 'bus'"
	psql -d test -c "SELECT * from trajectory.bus"
	psql -d test -c "SELECT trajectory.DeleteTrajectory('bus', '2')"
	psql -d test -c "SELECT * from trajectory.trajectory where poolname = 'bus'"
	psql -d test -c "SELECT * from trajectory.bus"
	psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', '1', '2015-10-28 14:58:00'::timestamp, ST_GeomFromText('POINT(119.4 39.4)', 4326))"
	psql -d test -c "SELECT trajectory.AppendTrajectory('taxi', '1', '2015-10-28 14:58:00'::timestamp, ST_Transform(ST_GeomFromText('POINT(119.4 39.4)', 4326),2249))"
	psql -d test -c "SELECT id, time, ST_AsText(position) as position from trajectory.taxi"
