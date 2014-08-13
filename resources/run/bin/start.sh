#!/bin/bash
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/12.1.0.2/dbhome_1
export PATH=$PATH:$ORACLE_HOME/bin

echo "SPFILE='/mnt/database/dbs/spfile${ORACLE_SID}.ora'" > /opt/oracle/product/12.1.0.2/dbhome_1/dbs/init${ORACLE_SID}.ora

function startupdb {
  echo "*** Starting database ${ORACLE_SID}"
  sqlplus / as sysdba @/home/oracle/startup.sql
}

function shutdowndb {
  echo "*** Shutting down database ${ORACLE_SID}"
  sqlplus / as sysdba @/home/oracle/shutdown.sql
}

function initdb {
  # Check if database already exists
  if [ -d /mnt/database/oradata ]; then
    echo "Database already exists"
    exit 1
  else
    echo "Creating database in /mnt/database"

    # Create the database
    /opt/oracle/product/12.1.0.2/dbhome_1/bin/dbca -silent -gdbname ${ORACLE_SID} -sid ${ORACLE_SID} -responseFile /home/oracle/dbca.rsp
 
    shutdowndb
 fi
}

function sqlpluslocal {
  startupdb
  sqlplus / as sysdba
  shutdowndb
}

function runsqllocal {
  startupdb
  
  find /mnt/sql -maxdepth 1 -type f -name *.sql | sort | while read script; do
    echo
    echo "*** Running script $script"
    echo exit | sqlplus -S / as sysdba @$(printf %q "$script");
  done
  
  shutdowndb
}

function rundb {
  if [ -d /mnt/database/oradata ]; then
    startupdb

    # Start TNS listener
    lsnrctl start
  
    # Tail the alert log so the process will keep running
    tail -n 1000 -f /mnt/database/diag/rdbms/${ORACLE_SID,,}/${ORACLE_SID}/alert/log.xml | grep --line-buffered "<txt>" | stdbuf -o0 sed 's/ <txt>//'
  else
    echo "Database not found"
    exit 1
  fi
}

function sqlplusremote {
  sqlplus ${ORACLE_USER}/${ORACLE_PASSWORD}@${REMOTEDB_PORT_1521_TCP_ADDR}:${REMOTEDB_PORT_1521_TCP_PORT}/${ORACLE_SID}
}

function runsqlremote {
  find /mnt/sql -maxdepth 1 -type f -name *.sql | sort | while read script; do
    echo
    echo "*** Running script $script in database ${ORACLE_USER}@${REMOTEDB_PORT_1521_TCP_ADDR}:${REMOTEDB_PORT_1521_TCP_PORT}/${ORACLE_SID}"
    echo exit | sqlplus -S ${ORACLE_USER}/${ORACLE_PASSWORD}@${REMOTEDB_PORT_1521_TCP_ADDR}:${REMOTEDB_PORT_1521_TCP_PORT}/${ORACLE_SID} @$(printf %q "$script");
  done
}

case "$COMMAND" in
  initdb)
    initdb
    ;;
  sqlpluslocal)
    sqlpluslocal
    ;;
  runsqllocal)
    runsqllocal
    ;;
  rundb)
    rundb
    ;;
  sqlplusremote)
    sqlplusremote
    ;;
  runsqlremote)
    runsqlremote
    ;;
  *)
    echo "Environment variable COMMAND must be {initdb|sqlpluslocal|runsqllocal|rundb|sqlplusremote|runsqlremote}, e.g.:"
    echo "  To initialize a database FOO in /tmp/db-FOO:"
    echo "  docker run -e COMMAND=initdb -e ORACLE_SID=FOO -v /tmp/db-FOO:/mnt/database oracle12c"
    echo ""
    echo "  To start sqlplus as sys in the database, and shut it down afterwards:"
    echo "  docker run -i -t -e COMMAND=sqlpluslocal -e ORACLE_SID=FOO -v /tmp/db-FOO:/mnt/database oracle12c"
    echo ""
    echo "  To run all *.sql scripts in /tmp/sql in the database, and shut it down afterwards:"
    echo "  docker run -e COMMAND=runsqllocal -e ORACLE_SID=FOO -v /tmp/db-FOO:/mnt/database -v /tmp/sql:/mnt/sql oracle12c"
    echo ""
    echo "  To start the database:"
    echo "  docker run -d -e COMMAND=rundb -e ORACLE_SID=FOO -v /tmp/db-FOO:/mnt/database -P --name db1 oracle12c"
    echo ""
    echo "  To connect to the database FOO running in container db1 with sqlplus:"
    echo "  docker run -i -t -e COMMAND=sqlplusremote -e ORACLE_SID=FOO -e ORACLE_USER=system -e ORACLE_PASSWORD=password --link db1:remotedb -P oracle12c"
    echo ""
    echo "  To run all *.sql scripts in /tmp/sql in the database FOO running in container db1:"
    echo "  docker run -e COMMAND=runsqlremote -e ORACLE_SID=FOO -e ORACLE_USER=system -e ORACLE_PASSWORD=password --link db1:remotedb -v /tmp/sql:/mnt/sql oracle12c"
    exit 1
    ;;
esac

