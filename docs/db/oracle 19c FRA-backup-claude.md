I'll help you configure a comprehensive backup strategy and enable archivelog mode for your Oracle 19c database.

## 1. **Enable Archivelog Mode**

### Step 1.1: Check Current Archive Mode Status

```bash
# As oracle user
su - oracle
sqlplus / as sysdba << EOF
-- Check current archive mode
ARCHIVE LOG LIST;

-- Check database log mode
SELECT name, log_mode FROM v\$database;

-- Check recovery file dest
SHOW PARAMETER db_recovery_file_dest;
EXIT;
EOF
```

### Step 1.2: Configure Fast Recovery Area (FRA)

```bash
# Create FRA directory structure
mkdir -p /u01/app/oracle/fast_recovery_area
mkdir -p /u01/app/oracle/archive_logs
chown -R oracle:oinstall /u01/app/oracle/fast_recovery_area
chown -R oracle:oinstall /u01/app/oracle/archive_logs

# Set FRA parameters
su - oracle
sqlplus / as sysdba << EOF
-- Set recovery file destination (FRA)
ALTER SYSTEM SET db_recovery_file_dest='/u01/app/oracle/fast_recovery_area' SCOPE=BOTH;

-- Set FRA size (adjust based on your disk space - using 100GB here)
ALTER SYSTEM SET db_recovery_file_dest_size=100G SCOPE=BOTH;

-- Set archive log destinations
ALTER SYSTEM SET log_archive_dest_1='LOCATION=/u01/app/oracle/archive_logs MANDATORY' SCOPE=SPFILE;
ALTER SYSTEM SET log_archive_dest_2='LOCATION=USE_DB_RECOVERY_FILE_DEST' SCOPE=SPFILE;

-- Set archive log format
ALTER SYSTEM SET log_archive_format='arch_%t_%s_%r.arc' SCOPE=SPFILE;

-- Enable automatic archival
ALTER SYSTEM SET log_archive_start=TRUE SCOPE=SPFILE;

EXIT;
EOF
```

### Step 1.3: Enable Archivelog Mode

```bash
# As oracle user
sqlplus / as sysdba << EOF
-- Shutdown database
SHUTDOWN IMMEDIATE;

-- Start in mount mode
STARTUP MOUNT;

-- Enable archive log mode
ALTER DATABASE ARCHIVELOG;

-- Open database
ALTER DATABASE OPEN;

-- Verify archivelog mode is enabled
ARCHIVE LOG LIST;
SELECT name, log_mode FROM v\$database;

-- Force a log switch to test
ALTER SYSTEM SWITCH LOGFILE;

EXIT;
EOF
```

## 2. **Configure RMAN Backup Strategy**

### Step 2.1: Create Backup Directories

```bash
# As root
mkdir -p /u01/backup/rman/{full,incremental,archivelog,scripts,logs}
chown -R oracle:oinstall /u01/backup
chmod -R 750 /u01/backup
```

### Step 2.2: Configure RMAN Settings

```bash
# As oracle user
su - oracle
rman target / << EOF
# Show current configuration
SHOW ALL;

# Configure retention policy (keep 7 days of backups)
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;

# Configure control file autobackup
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/u01/backup/rman/full/controlfile_%F';

# Configure device type parallelism
CONFIGURE DEVICE TYPE DISK PARALLELISM 4;

# Configure compression
CONFIGURE COMPRESSION ALGORITHM 'MEDIUM';

# Configure backup optimization
CONFIGURE BACKUP OPTIMIZATION ON;

# Configure archive log deletion policy
CONFIGURE ARCHIVELOG DELETION POLICY TO BACKED UP 2 TIMES TO DISK;

# Show new configuration
SHOW ALL;
EXIT;
EOF
```

## 3. **Create Backup Scripts**

### Step 3.1: Full Database Backup Script

```bash
# Create full backup script
cat > /u01/backup/rman/scripts/full_backup.sh << 'EOF'
#!/bin/bash
#################################################
# Full Database Backup Script
# Schedule: Weekly (Sundays)
#################################################

# Set environment
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=ORCL
export PATH=$ORACLE_HOME/bin:$PATH
export NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS'

# Variables
BACKUP_DIR="/u01/backup/rman"
LOG_FILE="$BACKUP_DIR/logs/full_backup_$(date +%Y%m%d_%H%M%S).log"
RETENTION_DAYS=30

# Create log directory if not exists
mkdir -p $BACKUP_DIR/logs

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Start backup
log_message "Starting full database backup..."

# Run RMAN backup
rman target / nocatalog log=$LOG_FILE append << RMAN_CMD
RUN {
    # Allocate channels
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/full/full_db_%d_%T_%s_%p.bkp';
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/full/full_db_%d_%T_%s_%p.bkp';
    
    # Backup database plus archivelog
    BACKUP AS COMPRESSED BACKUPSET 
        DATABASE PLUS ARCHIVELOG
        TAG 'FULL_BACKUP_$(date +%Y%m%d)';
    
    # Backup current controlfile
    BACKUP CURRENT CONTROLFILE 
        FORMAT '$BACKUP_DIR/full/controlfile_%d_%T_%s.bkp'
        TAG 'CONTROL_BACKUP_$(date +%Y%m%d)';
    
    # Backup spfile
    BACKUP SPFILE 
        FORMAT '$BACKUP_DIR/full/spfile_%d_%T_%s.bkp'
        TAG 'SPFILE_BACKUP_$(date +%Y%m%d)';
    
    # Release channels
    RELEASE CHANNEL ch1;
    RELEASE CHANNEL ch2;
    
    # Delete obsolete backups
    DELETE NOPROMPT OBSOLETE;
    
    # Delete expired backups
    CROSSCHECK BACKUP;
    DELETE NOPROMPT EXPIRED BACKUP;
    
    # Maintenance commands
    CROSSCHECK ARCHIVELOG ALL;
    DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
}
EXIT;
RMAN_CMD

# Check backup status
if [ $? -eq 0 ]; then
    log_message "Full backup completed successfully"
    
    # Report backup
    rman target / nocatalog << RMAN_REPORT >> $LOG_FILE 2>&1
    LIST BACKUP SUMMARY;
    REPORT NEED BACKUP;
    EXIT;
RMAN_REPORT
else
    log_message "ERROR: Full backup failed!"
    exit 1
fi

# Clean old logs
find $BACKUP_DIR/logs -name "*.log" -mtime +$RETENTION_DAYS -delete
log_message "Backup script completed"
EOF

chmod +x /u01/backup/rman/scripts/full_backup.sh
chown oracle:oinstall /u01/backup/rman/scripts/full_backup.sh
```

### Step 3.2: Incremental Backup Script

```bash
# Create incremental backup script
cat > /u01/backup/rman/scripts/incremental_backup.sh << 'EOF'
#!/bin/bash
#################################################
# Incremental Database Backup Script
# Schedule: Daily (except Sundays)
#################################################

# Set environment
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=ORCL
export PATH=$ORACLE_HOME/bin:$PATH
export NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS'

# Variables
BACKUP_DIR="/u01/backup/rman"
LOG_FILE="$BACKUP_DIR/logs/incremental_backup_$(date +%Y%m%d_%H%M%S).log"
DAY_OF_WEEK=$(date +%u)

# Create log directory
mkdir -p $BACKUP_DIR/logs

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Determine incremental level
if [ $DAY_OF_WEEK -eq 1 ]; then
    LEVEL=0  # Monday - Level 0
    BACKUP_TYPE="INCREMENTAL_LEVEL_0"
else
    LEVEL=1  # Other days - Level 1
    BACKUP_TYPE="INCREMENTAL_LEVEL_1"
fi

log_message "Starting $BACKUP_TYPE backup..."

# Run RMAN backup
rman target / nocatalog log=$LOG_FILE append << RMAN_CMD
RUN {
    # Allocate channels
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK;
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK;
    
    # Incremental backup
    BACKUP INCREMENTAL LEVEL $LEVEL AS COMPRESSED BACKUPSET
        DATABASE
        FORMAT '$BACKUP_DIR/incremental/incr_${LEVEL}_%d_%T_%s_%p.bkp'
        TAG '${BACKUP_TYPE}_$(date +%Y%m%d)';
    
    # Backup archive logs
    BACKUP AS COMPRESSED BACKUPSET
        ARCHIVELOG ALL NOT BACKED UP 2 TIMES
        FORMAT '$BACKUP_DIR/archivelog/arch_%d_%T_%s_%p.bkp'
        TAG 'ARCHIVE_$(date +%Y%m%d)'
        DELETE INPUT;
    
    # Backup control file
    BACKUP CURRENT CONTROLFILE
        FORMAT '$BACKUP_DIR/incremental/control_%d_%T_%s.bkp'
        TAG 'CONTROL_${BACKUP_TYPE}_$(date +%Y%m%d)';
    
    # Release channels
    RELEASE CHANNEL ch1;
    RELEASE CHANNEL ch2;
    
    # Maintenance
    CROSSCHECK BACKUP;
    DELETE NOPROMPT OBSOLETE;
}
EXIT;
RMAN_CMD

if [ $? -eq 0 ]; then
    log_message "$BACKUP_TYPE backup completed successfully"
else
    log_message "ERROR: $BACKUP_TYPE backup failed!"
    exit 1
fi

log_message "Incremental backup script completed"
EOF

chmod +x /u01/backup/rman/scripts/incremental_backup.sh
chown oracle:oinstall /u01/backup/rman/scripts/incremental_backup.sh
```

### Step 3.3: Archive Log Backup Script

```bash
# Create archive log backup script (runs every 4 hours)
cat > /u01/backup/rman/scripts/archivelog_backup.sh << 'EOF'
#!/bin/bash
#################################################
# Archive Log Backup Script
# Schedule: Every 4 hours
#################################################

# Set environment
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=ORCL
export PATH=$ORACLE_HOME/bin:$PATH

# Variables
BACKUP_DIR="/u01/backup/rman"
LOG_FILE="$BACKUP_DIR/logs/archivelog_backup_$(date +%Y%m%d_%H%M%S).log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log_message "Starting archive log backup..."

# Run RMAN backup
rman target / nocatalog log=$LOG_FILE append << RMAN_CMD
RUN {
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK;
    
    # Backup archive logs
    BACKUP AS COMPRESSED BACKUPSET
        ARCHIVELOG ALL NOT BACKED UP 1 TIMES
        FORMAT '$BACKUP_DIR/archivelog/arch_%d_%T_%s_%p.bkp'
        TAG 'ARCHIVELOG_$(date +%Y%m%d_%H%M%S)';
    
    # Delete archived logs backed up 2 times and older than 2 days
    DELETE NOPROMPT ARCHIVELOG ALL 
        BACKED UP 2 TIMES TO DISK 
        COMPLETED BEFORE 'SYSDATE-2';
    
    RELEASE CHANNEL ch1;
    
    # Crosscheck
    CROSSCHECK ARCHIVELOG ALL;
    DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
}
EXIT;
RMAN_CMD

if [ $? -eq 0 ]; then
    log_message "Archive log backup completed successfully"
else
    log_message "ERROR: Archive log backup failed!"
fi
EOF

chmod +x /u01/backup/rman/scripts/archivelog_backup.sh
chown oracle:oinstall /u01/backup/rman/scripts/archivelog_backup.sh
```

## 4. **Schedule Automated Backups**

### Step 4.1: Create Crontab Entries

```bash
# As oracle user
su - oracle

# Edit crontab
crontab -e

# Add the following entries:
# Full backup - Every Sunday at 1:00 AM
0 1 * * 0 /u01/backup/rman/scripts/full_backup.sh > /dev/null 2>&1

# Incremental backup - Monday to Saturday at 1:00 AM  
0 1 * * 1-6 /u01/backup/rman/scripts/incremental_backup.sh > /dev/null 2>&1

# Archive log backup - Every 4 hours
0 */4 * * * /u01/backup/rman/scripts/archivelog_backup.sh > /dev/null 2>&1

# Verify crontab
crontab -l
```

## 5. **Create Recovery Scripts**

### Step 5.1: Database Recovery Script

```bash
cat > /u01/backup/rman/scripts/restore_database.sh << 'EOF'
#!/bin/bash
#################################################
# Database Restore Script
#################################################

# Set environment
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=ORCL
export PATH=$ORACLE_HOME/bin:$PATH

echo "WARNING: This will restore the entire database!"
read -p "Are you sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled"
    exit 1
fi

# Restore type
echo "Select restore type:"
echo "1. Complete restore to latest"
echo "2. Point-in-time restore"
read -p "Enter choice (1 or 2): " choice

if [ "$choice" == "2" ]; then
    read -p "Enter target time (YYYY-MM-DD HH24:MI:SS): " target_time
    UNTIL_TIME="SET UNTIL TIME '${target_time}';"
else
    UNTIL_TIME=""
fi

# Shutdown database
sqlplus / as sysdba << EOF
SHUTDOWN ABORT;
STARTUP MOUNT;
EXIT;
EOF

# Run restore
rman target / << RMAN_CMD
RUN {
    ${UNTIL_TIME}
    
    RESTORE DATABASE;
    RECOVER DATABASE;
    
    ALTER DATABASE OPEN RESETLOGS;
}
EXIT;
RMAN_CMD

echo "Restore completed"
EOF

chmod +x /u01/backup/rman/scripts/restore_database.sh
chown oracle:oinstall /u01/backup/rman/scripts/restore_database.sh
```

## 6. **Test and Verify Backup Configuration**

### Step 6.1: Test Backup

```bash
# As oracle user
su - oracle

# Run a test backup
/u01/backup/rman/scripts/archivelog_backup.sh

# Check backup pieces
rman target / << EOF
LIST BACKUP SUMMARY;
LIST BACKUP OF DATABASE;
LIST BACKUP OF ARCHIVELOG ALL;
REPORT SCHEMA;
EXIT;
EOF
```

### Step 6.2: Validate Backups

```bash
# Create validation script
cat > /u01/backup/rman/scripts/validate_backup.sh << 'EOF'
#!/bin/bash

export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=ORCL
export PATH=$ORACLE_HOME/bin:$PATH

LOG_FILE="/u01/backup/rman/logs/validate_$(date +%Y%m%d_%H%M%S).log"

rman target / log=$LOG_FILE << RMAN_CMD
# Validate all backups
VALIDATE BACKUP;

# Check for corruption
BACKUP VALIDATE CHECK LOGICAL DATABASE;

# Report any failures
REPORT UNRECOVERABLE;
LIST FAILURE;

EXIT;
RMAN_CMD

echo "Validation complete. Check log: $LOG_FILE"
EOF

chmod +x /u01/backup/rman/scripts/validate_backup.sh
chown oracle:oinstall /u01/backup/rman/scripts/validate_backup.sh
```

## 7. **Monitor Backup Space and FRA**

### Step 7.1: Create Monitoring Script

```bash
cat > /u01/backup/rman/scripts/monitor_backup.sh << 'EOF'
#!/bin/bash

export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=ORCL
export PATH=$ORACLE_HOME/bin:$PATH

echo "=== Backup Monitoring Report ==="
echo "Date: $(date)"
echo ""

# Check FRA usage
sqlplus -S / as sysdba << EOF
SET PAGESIZE 100
SET LINESIZE 200
COL name FORMAT A20

PROMPT === Fast Recovery Area Usage ===
SELECT name, 
       ROUND(space_limit/1024/1024/1024,2) "Size_GB",
       ROUND(space_used/1024/1024/1024,2) "Used_GB",
       ROUND((space_used/space_limit)*100,2) "Used_%"
FROM v\$recovery_file_dest;

PROMPT 
PROMPT === FRA File Types ===
COL file_type FORMAT A20
SELECT file_type, 
       ROUND(percent_space_used,2) percent_used,
       ROUND(percent_space_reclaimable,2) percent_reclaimable,
       number_of_files
FROM v\$recovery_area_usage;

PROMPT
PROMPT === Archive Log Generation (Last 7 Days) ===
COL day FORMAT A10
SELECT TO_CHAR(completion_time,'YYYY-MM-DD') day,
       COUNT(*) log_switches,
       ROUND(SUM(blocks*block_size)/1024/1024/1024,2) size_gb
FROM v\$archived_log
WHERE completion_time > SYSDATE - 7
GROUP BY TO_CHAR(completion_time,'YYYY-MM-DD')
ORDER BY 1;
EXIT;
EOF

# Check backup directory space
echo ""
echo "=== Backup Directory Space ==="
df -h /u01/backup

# Recent backups
echo ""
echo "=== Recent Backup Files (Last 24 Hours) ==="
find /u01/backup/rman -name "*.bkp" -mtime -1 -ls | tail -10

# Check for backup errors in logs
echo ""
echo "=== Recent Backup Errors ==="
grep -i error /u01/backup/rman/logs/*.log 2>/dev/null | tail -5
EOF

chmod +x /u01/backup/rman/scripts/monitor_backup.sh
chown oracle:oinstall /u01/backup/rman/scripts/monitor_backup.sh
```

## Summary

Your Oracle 19c database now has:

✅ **Archivelog Mode**: Enabled for point-in-time recovery ✅ **Fast Recovery Area**: Configured with 20GB space ✅ **RMAN Configuration**: Optimized settings with retention policy ✅ **Automated Backups**:

- Weekly full backups (Sundays)
- Daily incremental backups (Level 0 on Monday, Level 1 other days)
- Archive log backups every 4 hours ✅ **Recovery Scripts**: Ready for database restoration ✅ **Monitoring**: Scripts to check backup status and space usage

### Quick Verification Commands:

```bash
# Check archive mode
sqlplus / as sysdba -S << EOF
ARCHIVE LOG LIST;
EOF

# Check recent backups
rman target / << EOF
LIST BACKUP SUMMARY;
EOF

# Monitor backup space
/u01/backup/rman/scripts/monitor_backup.sh
```

The backup strategy provides complete protection with the ability to recover to any point in time within your retention window.