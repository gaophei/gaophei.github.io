To configure Oracle 11g to automatically start on CentOS 7.2 boot, you'll need to set up both the database and listener to start automatically. Here's a comprehensive guide:

## Step 1: Enable Database Autostart in /etc/oratab

First, modify the `/etc/oratab` file to enable autostart:

```bash
sudo vi /etc/oratab
```

Find your database entry and change the last field from `N` to `Y`:

```
# Format: ORACLE_SID:ORACLE_HOME:AUTO_START
orcl:/u01/app/oracle/product/11.2.0/dbhome_1:Y
```

## Step 2: Create Startup/Shutdown Scripts

Create the Oracle startup script `/etc/init.d/oracle`:

```bash
sudo vi /etc/init.d/oracle
```

Add the following content (adjust paths as needed):

```bash
#!/bin/bash
# chkconfig: 345 99 10
# description: Oracle auto start-stop script

# Set Oracle environment
ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1
ORACLE_OWNER=oracle
PATH=$PATH:$ORACLE_HOME/bin

case "$1" in
'start')
    # Start Oracle Database
    echo "Starting Oracle Database..."
    su - $ORACLE_OWNER -c "$ORACLE_HOME/bin/dbstart $ORACLE_HOME"
    
    # Start Oracle Listener
    echo "Starting Oracle Listener..."
    su - $ORACLE_OWNER -c "$ORACLE_HOME/bin/lsnrctl start"
    
    # Start Oracle Enterprise Manager (optional)
    # echo "Starting Oracle EM..."
    #su - $ORACLE_OWNER -c "$ORACLE_HOME/bin/emctl start dbconsole"
    ;;
'stop')
    # Stop Oracle Enterprise Manager (optional)
    # echo "Stopping Oracle EM..."
    # su - $ORACLE_OWNER -c "$ORACLE_HOME/bin/emctl stop dbconsole"
    
    # Stop Oracle Listener
    echo "Stopping Oracle Listener..."
    su - $ORACLE_OWNER -c "$ORACLE_HOME/bin/lsnrctl stop"
    
    # Stop Oracle Database
    echo "Stopping Oracle Database..."
    su - $ORACLE_OWNER -c "$ORACLE_HOME/bin/dbshut $ORACLE_HOME"
    ;;
'restart')
    $0 stop
    $0 start
    ;;
*)
    echo "Usage: $0 {start|stop|restart}"
    exit 1
esac
exit 0
```

## Step 3: Set Permissions and Enable Service

Make the script executable:

```bash
sudo chmod 755 /etc/init.d/oracle
```

Add the service to startup:

```bash
sudo chkconfig --add oracle
sudo chkconfig oracle on
```

Verify it's enabled:

```bash
chkconfig --list oracle
```

## Step 4: Alternative - Using systemd (CentOS 7 native)

Since CentOS 7 uses systemd, you can alternatively create a systemd service file:

```bash
sudo vi /etc/systemd/system/oracle.service
```

Add this content:

```ini
[Unit]
Description=Oracle Database Service
After=network.target

[Service]
Type=forking
User=oracle
Group=oinstall
Environment="ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1"
Environment="ORACLE_SID=orcl"
ExecStart=/u01/app/oracle/product/11.2.0/dbhome_1/bin/dbstart /u01/app/oracle/product/11.2.0/dbhome_1
ExecStop=/u01/app/oracle/product/11.2.0/dbhome_1/bin/dbshut /u01/app/oracle/product/11.2.0/dbhome_1
TimeoutSec=300

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable oracle.service
sudo systemctl start oracle.service
```

## Step 5: Verify Configuration

Test the service:

```bash
# For init.d script
sudo service oracle stop
sudo service oracle start

# For systemd
sudo systemctl status oracle
```

Reboot and verify Oracle starts automatically:

```bash
sudo reboot
```

After reboot, check if Oracle is running:

```bash
ps -ef | grep pmon
lsnrctl status
sqlplus / as sysdba
SQL> select instance_name, status from v$instance;
```

## Important Notes:

1. **Environment Variables**: Ensure the oracle user's `.bash_profile` contains proper Oracle environment variables
2. **SELinux**: If SELinux is enabled, you may need to adjust policies
3. **Firewall**: Configure firewall rules if needed for remote access
4. **Resource Limits**: Verify `/etc/security/limits.conf` has proper settings for the oracle user

This setup ensures Oracle Database 11g will automatically start when your CentOS 7.2 server boots up.