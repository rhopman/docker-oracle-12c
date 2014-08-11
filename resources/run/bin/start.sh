#!/bin/bash
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/12.1.0.2/dbhome_1
export PATH=$PATH:$ORACLE_HOME/bin

echo "SPFILE='/mnt/database/dbs/spfile${ORACLE_SID}.ora'" > /opt/oracle/product/12.1.0.2/dbhome_1/dbs/init${ORACLE_SID}.ora

# Check if database already exists
if [ -d /mnt/database/oradata ]; then
  echo "Starting database found in /mnt/database"

  # Start the database
  sqlplus / as sysdba @/home/oracle/startup.sql

  # Start TNS listener
  lsnrctl start
  
  # Tail the alert log so the process will keep running
  tail -n 100 -f /mnt/database/diag/rdbms/${ORACLE_SID}/${ORACLE_SID}/alert/log.xml | grep --line-buffered "<txt>" | stdbuf -o0 sed 's/ <txt>//'
else
  echo "Creating database in /mnt/database"

  # Create the database
  /opt/oracle/product/12.1.0.2/dbhome_1/bin/dbca -silent -gdbname ${ORACLE_SID} -sid ${ORACLE_SID} -responseFile /home/oracle/dbca.rsp
  
  # Shutdown the database
  sqlplus / as sysdba @/home/oracle/shutdown.sql
fi