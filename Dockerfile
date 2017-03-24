FROM centos
MAINTAINER Ralph Hopman <rhopman@bol.com>

# Groups
RUN groupadd oracle
RUN groupadd dba
RUN groupadd oinstall

# User oracle
RUN adduser -g oracle -G dba,oinstall oracle
RUN mkdir -p /opt/oracle/admin/orcl/adump
RUN mkdir -p /opt/oracle/fast_recovery_area
RUN chown -R oracle:oracle /opt/oracle

# Inventory directory
RUN mkdir /opt/oraInventory
RUN chown oracle:oinstall /opt/oraInventory

# Required packages
RUN yum install -y compat-libcap1 compat-libstdc++-33 libstdc++-devel gcc-c++ ksh make libaio-devel smartmontools net-tools
# This one gives errors
RUN yum install -y sysstat; true

# Add database software
ADD resources/database /home/oracle/database/

# Add install-time resources
ADD resources/install /home/oracle/
RUN chmod +x /home/oracle/bin/*

# Oracle uses /usr/bin/who -r to check runlevel. Because Docker doesn't have a runlevel,
# we need to fake it.
RUN mv /usr/bin/who /usr/bin/who.orig
RUN ln -s /home/oracle/bin/who /usr/bin/who

# Install Oracle database
USER oracle
RUN /home/oracle/bin/install.sh

# Abort build if installation was unsuccesful
RUN if [ ! -d /opt/oracle/product ]; then exit 1; fi

# Post-installation scripts
USER root
RUN /home/oracle/bin/postinstall.sh

# Add run-time resources
ADD resources/run /home/oracle/
RUN chmod +x /home/oracle/bin/*

USER oracle
VOLUME /mnt/database
EXPOSE 1521
CMD ["/home/oracle/bin/start.sh"]
