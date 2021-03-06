Oracle 12c in Docker
====================

Use this software to run Oracle 12c within a Docker container, while the
database files are on a mounted volume. This allows you to mount multiple
snapshots of the same volume and mount them in different containers
simultaneously.

I would recommend running this on a dedicated server (cluster) or VM,
since you will need to set some specific kernel parameters and use a
modified version of Docker. This README walks you through all the steps
to get it running.

I've only tried this with 12c so far, but I don't see any reason why it
wouldn't work with older versions of Oracle.

## Note: Increase shared memory (shm) and stack size limit

Oracle requires a shared memory (shm) of at least 256 MB, and a stack size soft
limit of at least 10240 kB (10485760 bytes), during installation and running.
Be sure to _build_ and _run_ with these parameters:

`--shm-size=256m --ulimit stack=10485760`

## Step 1: Host prerequisites

I used Ubuntu 14.04 as a host, so it doesn't have to be an Oracle-approved
OS. You need at least 3 GB of swap space on the host. Don't think you know
better, Oracle will check during installation and just stop if you don't
have enough swap space.

You also need to set some kernel parameters and security limits. Check
[this guide](http://gemsofprogramming.wordpress.com/2013/09/19/installing-oracle-12c-on-ubuntu-12-04-64-bit-a-hard-journey-but-its-worth-it/)
and follow the parts about editing `sysctl.conf` and `limits.conf`.

## Step 3: Download

Download or clone this repository, if you haven't done so already. Then
download Oracle 12c (12.2.0.1.0)
[from OTN](http://www.oracle.com/technetwork/database/enterprise-edition/downloads/index.html).
Extract the zip file in the `resources` directory, so the installer will
be at `resources/database/runInstaller`.

## Step 4: Build the image

Run

```
$ docker build --shm-size=256m --ulimit stack=10485760 -t oracle12c .
```

to build the image and tag it as `oracle12c`.
It may take a while. Make sure you see the text `Successfully Setup Software.`
somewhere in the output.

The resulting image can do two things: create an empty database and run an
existing database. The idea is that you create a database first, make a snapshot
and run it in multiple containers.

## Step 5: Create the database

Make a directory where you can store the database, e.g.

```
$ mkdir /tmp/database
```

Start the container, passing the Oracle SID that you want to use. In this example,
I'll use `FOO` as the SID:

```
$ docker run --shm-size=256m --ulimit stack=10485760 -e COMMAND=initdb -e ORACLE_SID=FOO -v /tmp/db-FOO:/mnt/database oracle12c
```

## Step 6: Run the database server

Start the container again, using the same SID and pointing to (a snapshot of) the
same volume:

```
$ docker run --shm-size=256m --ulimit stack=10485760 -e COMMAND=rundb -e ORACLE_SID=FOO -v /tmp/db-FOO:/mnt/database -P --name db1 oracle12c
```

This will start the server and show the alert log. If you want to run it in the
background, add a -d switch:

```
$ docker run --shm-size=256m --ulimit stack=10485760 -d -e COMMAND=rundb -e ORACLE_SID=FOO -v /tmp/db-FOO:/mnt/database -P --name db1 oracle12c
```

When the container is running, port 1521 is exposed. You can user `docker ps` to
see the running Docker processes and find out which port is used on the host.

## More

To start sqlplus as sys in the database, and shut it down afterwards:

```
docker run --shm-size=256m --ulimit stack=10485760 -i -t -e COMMAND=sqlpluslocal -e ORACLE_SID=FOO -v /tmp/db-FOO:/mnt/database oracle12c
```

To run all `*.sql` scripts in `/tmp/sql` in the database, and shut it down afterwards:

```
docker run --shm-size=256m --ulimit stack=10485760 -e COMMAND=runsqllocal -e ORACLE_SID=FOO -v /tmp/db-FOO:/mnt/database -v /tmp/sql:/mnt/sql oracle12c
```

To connect to the database FOO running in container db1 with sqlplus:

```
docker run --shm-size=256m --ulimit stack=10485760 -i -t -e COMMAND=sqlplusremote -e ORACLE_SID=FOO -e ORACLE_USER=system -e ORACLE_PASSWORD=password --link db1:remotedb -P oracle12c
```

To run all `*.sql` scripts in `/tmp/sql` in the database FOO running in container db1:

```
docker run --shm-size=256m --ulimit stack=10485760 -e COMMAND=runsqlremote -e ORACLE_SID=FOO -e ORACLE_USER=system -e ORACLE_PASSWORD=password --link db1:remotedb -v /tmp/sql:/mnt/sql oracle12c
```
