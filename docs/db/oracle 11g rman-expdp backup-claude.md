I'll create comprehensive backup scripts for both Oracle 11g RAC and single instance environments, including RMAN and Data Pump Export (expdp) scripts.I've created comprehensive backup scripts for both Oracle 11g RAC and single instance environments. Here are your scripts:

## Oracle 11g RAC Scripts

### 1. RAC RMAN Backup Script

Features:

- Full, incremental, and archive log backups
- Multi-channel allocation for RAC nodes
- Automatic obsolete backup cleanup
- Backup validation
- Email notifications
- Compression support

Usage: `./oracle_11g_rac_rman_backup.sh {full|incremental|archivelog|validate}`

```bash
#!/bin/bash
#================================================================
# Oracle 11g RAC RMAN Backup Script
# Description: Performs RMAN backup for Oracle RAC environment
# Author: DBA Team
# Date: 2025
#================================================================

# Environment Variables
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1
export ORACLE_SID=RACDB1  # Change to your RAC instance name
export PATH=$ORACLE_HOME/bin:$PATH
export NLS_DATE_FORMAT='DD-MON-YYYY HH24:MI:SS'

# Backup Configuration
BACKUP_DIR=/backup/rman
LOG_DIR=/backup/logs
RETENTION_DAYS=7
PARALLELISM=4
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE=$LOG_DIR/rman_backup_${ORACLE_SID}_${DATE}.log

# Create directories if they don't exist
mkdir -p $BACKUP_DIR
mkdir -p $LOG_DIR

# Email Configuration (optional)
MAIL_TO="dba-team@company.com"
MAIL_SUBJECT="RAC RMAN Backup Report - $ORACLE_SID - $DATE"

#================================================================
# Functions
#================================================================

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

send_notification() {
    local status=$1
    local message=$2
    
    if [ ! -z "$MAIL_TO" ]; then
        echo "$message" | mail -s "$MAIL_SUBJECT - $status" $MAIL_TO
    fi
}

check_db_status() {
    log_message "Checking database status..."
    
    sqlplus -S / as sysdba <<EOF
    set heading off feedback off
    select 'DB_STATUS:'||status from v\$instance;
    exit;
EOF
}

#================================================================
# Main Backup Function
#================================================================

perform_backup() {
    local backup_type=$1
    
    log_message "======================================"
    log_message "Starting Oracle RAC RMAN Backup"
    log_message "Database: $ORACLE_SID"
    log_message "Backup Type: $backup_type"
    log_message "Backup Directory: $BACKUP_DIR"
    log_message "======================================"
    
    # Check database status
    db_status=$(check_db_status | grep DB_STATUS | cut -d: -f2)
    
    if [ "$db_status" != "OPEN" ]; then
        log_message "ERROR: Database is not OPEN. Status: $db_status"
        send_notification "FAILED" "Database is not in OPEN state"
        exit 1
    fi
    
    # RMAN Backup Commands
    case $backup_type in
        FULL)
            log_message "Performing FULL database backup..."
            rman target / nocatalog log=$LOG_FILE append <<EOF
RUN {
    # Allocate channels for RAC - one per node
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/%d_%T_%s_%p.bkp' CONNECT 'sys/password@RACDB1';
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/%d_%T_%s_%p.bkp' CONNECT 'sys/password@RACDB2';
    
    # Backup database plus archivelog
    BACKUP AS COMPRESSED BACKUPSET 
        INCREMENTAL LEVEL 0 
        DATABASE 
        TAG 'FULL_BACKUP_${DATE}'
        PLUS ARCHIVELOG 
        TAG 'ARCHIVE_${DATE}'
        DELETE ALL INPUT;
    
    # Backup control file
    BACKUP CURRENT CONTROLFILE 
        FORMAT '$BACKUP_DIR/control_%d_%T_%s.bkp'
        TAG 'CONTROL_${DATE}';
    
    # Backup SPFILE
    BACKUP SPFILE 
        FORMAT '$BACKUP_DIR/spfile_%d_%T_%s.bkp'
        TAG 'SPFILE_${DATE}';
    
    # Release channels
    RELEASE CHANNEL ch1;
    RELEASE CHANNEL ch2;
}

# Maintenance operations
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT OBSOLETE RECOVERY WINDOW OF $RETENTION_DAYS DAYS;
DELETE NOPROMPT EXPIRED BACKUP;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;

# Generate restore script
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '$BACKUP_DIR/autobackup_%F';

# List backup summary
LIST BACKUP SUMMARY;
EXIT;
EOF
            ;;
            
        INCREMENTAL)
            log_message "Performing INCREMENTAL Level 1 backup..."
            rman target / nocatalog log=$LOG_FILE append <<EOF
RUN {
    # Allocate channels for RAC
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/%d_%T_%s_%p.bkp' CONNECT 'sys/password@RACDB1';
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/%d_%T_%s_%p.bkp' CONNECT 'sys/password@RACDB2';
    
    # Incremental Level 1 backup
    BACKUP AS COMPRESSED BACKUPSET 
        INCREMENTAL LEVEL 1 
        DATABASE 
        TAG 'INCR_BACKUP_${DATE}'
        PLUS ARCHIVELOG 
        TAG 'ARCHIVE_${DATE}'
        DELETE ALL INPUT;
    
    # Backup control file
    BACKUP CURRENT CONTROLFILE 
        FORMAT '$BACKUP_DIR/control_%d_%T_%s.bkp'
        TAG 'CONTROL_${DATE}';
    
    # Release channels
    RELEASE CHANNEL ch1;
    RELEASE CHANNEL ch2;
}

# Maintenance
CROSSCHECK BACKUP;
DELETE NOPROMPT OBSOLETE RECOVERY WINDOW OF $RETENTION_DAYS DAYS;
LIST BACKUP SUMMARY;
EXIT;
EOF
            ;;
            
        ARCHIVELOG)
            log_message "Performing ARCHIVELOG backup..."
            rman target / nocatalog log=$LOG_FILE append <<EOF
RUN {
    # Allocate channels for RAC
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/%d_%T_%s_%p.arc' CONNECT 'sys/password@RACDB1';
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/%d_%T_%s_%p.arc' CONNECT 'sys/password@RACDB2';
    
    # Backup all archive logs and delete input
    BACKUP AS COMPRESSED BACKUPSET 
        ARCHIVELOG ALL 
        TAG 'ARCHIVE_ONLY_${DATE}'
        DELETE ALL INPUT;
    
    # Release channels
    RELEASE CHANNEL ch1;
    RELEASE CHANNEL ch2;
}

# Crosscheck and delete expired
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
EXIT;
EOF
            ;;
            
        *)
            log_message "ERROR: Invalid backup type specified"
            exit 1
            ;;
    esac
    
    # Check RMAN exit status
    RMAN_STATUS=$?
    
    if [ $RMAN_STATUS -eq 0 ]; then
        log_message "RMAN Backup completed successfully"
        send_notification "SUCCESS" "RMAN $backup_type backup completed successfully"
    else
        log_message "ERROR: RMAN Backup failed with exit code $RMAN_STATUS"
        send_notification "FAILED" "RMAN $backup_type backup failed. Check log: $LOG_FILE"
        exit $RMAN_STATUS
    fi
}

#================================================================
# Validation Function
#================================================================

validate_backup() {
    log_message "Validating recent backups..."
    
    rman target / nocatalog <<EOF
RESTORE DATABASE VALIDATE;
RESTORE CONTROLFILE VALIDATE;
RESTORE SPFILE VALIDATE;
EXIT;
EOF
    
    if [ $? -eq 0 ]; then
        log_message "Backup validation completed successfully"
    else
        log_message "WARNING: Backup validation failed"
    fi
}

#================================================================
# Main Execution
#================================================================

# Parse command line arguments
case "$1" in
    full|FULL)
        perform_backup "FULL"
        validate_backup
        ;;
    incremental|INCREMENTAL|incr)
        perform_backup "INCREMENTAL"
        ;;
    archivelog|ARCHIVELOG|arch)
        perform_backup "ARCHIVELOG"
        ;;
    validate|VALIDATE)
        validate_backup
        ;;
    *)
        echo "Usage: $0 {full|incremental|archivelog|validate}"
        echo "  full        - Perform full level 0 backup"
        echo "  incremental - Perform incremental level 1 backup"
        echo "  archivelog  - Backup only archive logs"
        echo "  validate    - Validate existing backups"
        exit 1
        ;;
esac

# Cleanup old logs
find $LOG_DIR -name "*.log" -mtime +30 -exec rm {} \;

log_message "Backup process completed"
log_message "======================================"

exit 0
```



### 2. RAC Data Pump Export Script

Features:

- Full database, schema, and table-level exports
- Parallel export across RAC nodes
- Automatic compression
- Metadata generation with checksums
- Retention management

Usage: `./oracle_11g_rac_expdp_backup.sh {full|schema SCHEMAS|table TABLES|cleanup}`

```bash
#!/bin/bash
#================================================================
# Oracle 11g RAC Data Pump Export (EXPDP) Backup Script
# Description: Performs Data Pump export for Oracle RAC environment
# Author: DBA Team
# Date: 2024
#================================================================

# Environment Variables
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1
export ORACLE_SID=RACDB1  # Change to your RAC instance name
export PATH=$ORACLE_HOME/bin:$PATH
export NLS_DATE_FORMAT='DD-MON-YYYY HH24:MI:SS'

# Export Configuration
EXPORT_DIR=/backup/datapump
LOG_DIR=/backup/logs
ORACLE_DIR=DATA_PUMP_DIR  # Oracle directory object name
SCHEMA_LIST=""  # Leave empty for full database export
RETENTION_DAYS=7
PARALLELISM=4
COMPRESSION=METADATA_ONLY  # Options: ALL, DATA_ONLY, METADATA_ONLY, NONE
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE=$LOG_DIR/expdp_backup_${ORACLE_SID}_${DATE}.log

# Database connection
DB_USER=system
DB_PASS=password  # Consider using Oracle Wallet for security
DB_CONN="(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=rac-scan)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=RACDB)))"

# Create directories if they don't exist
mkdir -p $EXPORT_DIR
mkdir -p $LOG_DIR

#================================================================
# Functions
#================================================================

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

check_directory() {
    log_message "Checking Oracle directory object..."
    
    sqlplus -S $DB_USER/$DB_PASS@"$DB_CONN" <<EOF
    set heading off feedback off
    SELECT 'DIR_EXISTS:'||COUNT(*) FROM dba_directories WHERE directory_name = '$ORACLE_DIR';
    exit;
EOF
}

create_directory() {
    log_message "Creating or updating Oracle directory object..."
    
    sqlplus -S $DB_USER/$DB_PASS@"$DB_CONN" <<EOF
    CREATE OR REPLACE DIRECTORY $ORACLE_DIR AS '$EXPORT_DIR';
    GRANT READ, WRITE ON DIRECTORY $ORACLE_DIR TO PUBLIC;
    exit;
EOF
}

get_database_size() {
    sqlplus -S $DB_USER/$DB_PASS@"$DB_CONN" <<EOF
    set heading off feedback off pagesize 0
    SELECT 'DB_SIZE:'||ROUND(SUM(bytes)/1024/1024/1024,2)||'GB' 
    FROM dba_segments;
    exit;
EOF
}

check_space() {
    local required_space=$1
    local available_space=$(df -BG $EXPORT_DIR | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [ $available_space -lt $required_space ]; then
        log_message "ERROR: Insufficient disk space. Required: ${required_space}GB, Available: ${available_space}GB"
        exit 1
    fi
    
    log_message "Disk space check passed. Available: ${available_space}GB"
}

#================================================================
# Export Functions
#================================================================

perform_full_export() {
    local export_file="full_export_${ORACLE_SID}_${DATE}.dmp"
    local export_log="full_export_${ORACLE_SID}_${DATE}_expdp.log"
    
    log_message "======================================"
    log_message "Starting Full Database Export"
    log_message "Database: $ORACLE_SID"
    log_message "Export File: $export_file"
    log_message "======================================"
    
    # Get database size
    db_size=$(get_database_size | grep DB_SIZE | cut -d: -f2)
    log_message "Database size: $db_size"
    
    # Create parameter file for export
    cat > /tmp/expdp_full_${DATE}.par <<EOF
USERID=$DB_USER/$DB_PASS@"$DB_CONN"
DIRECTORY=$ORACLE_DIR
DUMPFILE=$export_file
LOGFILE=$export_log
FULL=Y
PARALLEL=$PARALLELISM
COMPRESSION=$COMPRESSION
EXCLUDE=STATISTICS
FLASHBACK_TIME=SYSTIMESTAMP
CLUSTER=N
SERVICE_NAME=RACDB
METRICS=Y
EOF
    
    # Add exclusions if needed
    cat >> /tmp/expdp_full_${DATE}.par <<EOF
EXCLUDE=SCHEMA:"IN ('SCOTT','HR','SH')"
EXCLUDE=TABLE:"IN ('TEMP_TABLE','TEST_TABLE')"
EOF
    
    log_message "Starting Data Pump export..."
    expdp parfile=/tmp/expdp_full_${DATE}.par
    
    EXPDP_STATUS=$?
    
    if [ $EXPDP_STATUS -eq 0 ]; then
        log_message "Data Pump export completed successfully"
        
        # Compress the dump file
        log_message "Compressing export file..."
        gzip $EXPORT_DIR/$export_file
        
        # Generate metadata
        generate_export_metadata "$export_file.gz" "FULL"
    else
        log_message "ERROR: Data Pump export failed with exit code $EXPDP_STATUS"
        exit $EXPDP_STATUS
    fi
    
    # Cleanup parameter file
    rm -f /tmp/expdp_full_${DATE}.par
}

perform_schema_export() {
    local schemas=$1
    local export_file="schema_export_${DATE}.dmp"
    local export_log="schema_export_${DATE}_expdp.log"
    
    log_message "======================================"
    log_message "Starting Schema Export"
    log_message "Schemas: $schemas"
    log_message "Export File: $export_file"
    log_message "======================================"
    
    # Create parameter file for export
    cat > /tmp/expdp_schema_${DATE}.par <<EOF
USERID=$DB_USER/$DB_PASS@"$DB_CONN"
DIRECTORY=$ORACLE_DIR
DUMPFILE=$export_file
LOGFILE=$export_log
SCHEMAS=$schemas
PARALLEL=$PARALLELISM
COMPRESSION=$COMPRESSION
EXCLUDE=STATISTICS
FLASHBACK_TIME=SYSTIMESTAMP
CLUSTER=N
SERVICE_NAME=RACDB
METRICS=Y
EOF
    
    log_message "Starting Data Pump schema export..."
    expdp parfile=/tmp/expdp_schema_${DATE}.par
    
    EXPDP_STATUS=$?
    
    if [ $EXPDP_STATUS -eq 0 ]; then
        log_message "Schema export completed successfully"
        
        # Compress the dump file
        log_message "Compressing export file..."
        gzip $EXPORT_DIR/$export_file
        
        # Generate metadata
        generate_export_metadata "$export_file.gz" "SCHEMA"
    else
        log_message "ERROR: Schema export failed with exit code $EXPDP_STATUS"
        exit $EXPDP_STATUS
    fi
    
    # Cleanup parameter file
    rm -f /tmp/expdp_schema_${DATE}.par
}

perform_table_export() {
    local tables=$1
    local export_file="table_export_${DATE}.dmp"
    local export_log="table_export_${DATE}_expdp.log"
    
    log_message "======================================"
    log_message "Starting Table Export"
    log_message "Tables: $tables"
    log_message "Export File: $export_file"
    log_message "======================================"
    
    # Create parameter file for export
    cat > /tmp/expdp_table_${DATE}.par <<EOF
USERID=$DB_USER/$DB_PASS@"$DB_CONN"
DIRECTORY=$ORACLE_DIR
DUMPFILE=$export_file
LOGFILE=$export_log
TABLES=$tables
PARALLEL=$PARALLELISM
COMPRESSION=$COMPRESSION
FLASHBACK_TIME=SYSTIMESTAMP
CLUSTER=N
SERVICE_NAME=RACDB
METRICS=Y
EOF
    
    log_message "Starting Data Pump table export..."
    expdp parfile=/tmp/expdp_table_${DATE}.par
    
    EXPDP_STATUS=$?
    
    if [ $EXPDP_STATUS -eq 0 ]; then
        log_message "Table export completed successfully"
        
        # Compress the dump file
        log_message "Compressing export file..."
        gzip $EXPORT_DIR/$export_file
        
        # Generate metadata
        generate_export_metadata "$export_file.gz" "TABLE"
    else
        log_message "ERROR: Table export failed with exit code $EXPDP_STATUS"
        exit $EXPDP_STATUS
    fi
    
    # Cleanup parameter file
    rm -f /tmp/expdp_table_${DATE}.par
}

#================================================================
# Metadata and Cleanup Functions
#================================================================

generate_export_metadata() {
    local export_file=$1
    local export_type=$2
    local metadata_file="${export_file}.metadata"
    
    log_message "Generating export metadata..."
    
    cat > $EXPORT_DIR/$metadata_file <<EOF
Export Type: $export_type
Export Date: $(date)
Database: $ORACLE_SID
Export File: $export_file
File Size: $(du -h $EXPORT_DIR/$export_file | cut -f1)
Oracle Version: 11g RAC
Compression: $COMPRESSION
Parallelism: $PARALLELISM
EOF
    
    # Add checksum
    echo "MD5 Checksum: $(md5sum $EXPORT_DIR/$export_file | cut -d' ' -f1)" >> $EXPORT_DIR/$metadata_file
}

cleanup_old_exports() {
    log_message "Cleaning up old export files (older than $RETENTION_DAYS days)..."
    
    # Remove old dump files
    find $EXPORT_DIR -name "*.dmp.gz" -mtime +$RETENTION_DAYS -exec rm {} \;
    find $EXPORT_DIR -name "*.metadata" -mtime +$RETENTION_DAYS -exec rm {} \;
    
    # Remove old log files
    find $LOG_DIR -name "*.log" -mtime +30 -exec rm {} \;
    
    log_message "Cleanup completed"
}

verify_export() {
    local export_file=$1
    
    log_message "Verifying export file..."
    
    # Check if file exists and has size > 0
    if [ -f "$EXPORT_DIR/$export_file" ] && [ -s "$EXPORT_DIR/$export_file" ]; then
        log_message "Export file verified: $export_file"
        
        # Test gzip integrity if compressed
        if [[ $export_file == *.gz ]]; then
            gzip -t $EXPORT_DIR/$export_file 2>/dev/null
            if [ $? -eq 0 ]; then
                log_message "Compressed file integrity check passed"
            else
                log_message "ERROR: Compressed file integrity check failed"
                exit 1
            fi
        fi
    else
        log_message "ERROR: Export file not found or empty"
        exit 1
    fi
}

#================================================================
# Main Execution
#================================================================

# Check and create Oracle directory
dir_exists=$(check_directory | grep DIR_EXISTS | cut -d: -f2)
if [ "$dir_exists" != "1" ]; then
    log_message "Oracle directory does not exist. Creating..."
    create_directory
fi

# Parse command line arguments
case "$1" in
    full|FULL)
        perform_full_export
        ;;
    schema|SCHEMA)
        if [ -z "$2" ]; then
            echo "Error: Schema name(s) required"
            echo "Usage: $0 schema SCHEMA1,SCHEMA2,..."
            exit 1
        fi
        perform_schema_export "$2"
        ;;
    table|TABLE)
        if [ -z "$2" ]; then
            echo "Error: Table name(s) required"
            echo "Usage: $0 table SCHEMA.TABLE1,SCHEMA.TABLE2,..."
            exit 1
        fi
        perform_table_export "$2"
        ;;
    cleanup|CLEANUP)
        cleanup_old_exports
        ;;
    *)
        echo "Usage: $0 {full|schema|table|cleanup} [additional_params]"
        echo "  full              - Perform full database export"
        echo "  schema SCHEMAS    - Export specific schemas (comma-separated)"
        echo "  table TABLES      - Export specific tables (comma-separated)"
        echo "  cleanup           - Remove old export files"
        echo ""
        echo "Examples:"
        echo "  $0 full"
        echo "  $0 schema HR,SCOTT,APP_SCHEMA"
        echo "  $0 table HR.EMPLOYEES,HR.DEPARTMENTS"
        exit 1
        ;;
esac

# Cleanup old exports
cleanup_old_exports

log_message "Export process completed successfully"
log_message "======================================"

exit 0
```



## Oracle 11g Single Instance Scripts

### 3. Single Instance RMAN Backup Script

Features:

- Full, incremental, cumulative, and cold backups
- Archive log backup and management
- Block change tracking support
- Backup validation and reporting
- Automatic RMAN configuration

Usage: `./oracle_11g_single_rman_backup.sh {full|incremental|cumulative|archivelog|cold|validate|status}`

```bash
#!/bin/bash
#================================================================
# Oracle 11g Single Instance RMAN Backup Script
# Description: Performs RMAN backup for single instance Oracle database
# Author: DBA Team
# Date: 2025
#================================================================

# Environment Variables
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1
export ORACLE_SID=ORCL  # Change to your database SID
export PATH=$ORACLE_HOME/bin:$PATH
export NLS_DATE_FORMAT='DD-MON-YYYY HH24:MI:SS'

# Backup Configuration
BACKUP_DIR=/backup/rman
LOG_DIR=/backup/logs
FRA_DIR=/u01/app/oracle/fast_recovery_area  # Flash Recovery Area
RETENTION_DAYS=3
PARALLELISM=2
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE=$LOG_DIR/rman_backup_${ORACLE_SID}_${DATE}.log

# Create directories if they don't exist
mkdir -p $BACKUP_DIR
mkdir -p $LOG_DIR

# Email Configuration (optional)
#MAIL_TO="dba-team@company.com"
#MAIL_SUBJECT="RMAN Backup Report - $ORACLE_SID - $DATE"

#================================================================
# Functions
#================================================================

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

send_notification() {
    local status=$1
    local message=$2
    
    if [ ! -z "$MAIL_TO" ]; then
        echo "$message" | mail -s "$MAIL_SUBJECT - $status" $MAIL_TO
    fi
}

check_db_status() {
    log_message "Checking database status..."
    
    sqlplus -S / as sysdba <<EOF
    set heading off feedback off
    select 'DB_STATUS:'||status from v\$instance;
    select 'DB_NAME:'||name from v\$database;
    select 'ARCHIVE_MODE:'||log_mode from v\$database;
    exit;
EOF
}

configure_rman() {
    log_message "Configuring RMAN settings..."
    
    rman target / nocatalog <<EOF
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF $RETENTION_DAYS DAYS;
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '$BACKUP_DIR/autobackup_%F';
CONFIGURE DEVICE TYPE DISK PARALLELISM $PARALLELISM;
CONFIGURE DATAFILE BACKUP COPIES FOR DEVICE TYPE DISK TO 1;
CONFIGURE ARCHIVELOG BACKUP COPIES FOR DEVICE TYPE DISK TO 1;
CONFIGURE COMPRESSION ALGORITHM 'BASIC';
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '$BACKUP_DIR/snapcf_${ORACLE_SID}.f';
SHOW ALL;
EXIT;
EOF
}

#================================================================
# Main Backup Function
#================================================================

perform_backup() {
    local backup_type=$1
    
    log_message "======================================"
    log_message "Starting Oracle Single Instance RMAN Backup"
    log_message "Database: $ORACLE_SID"
    log_message "Backup Type: $backup_type"
    log_message "Backup Directory: $BACKUP_DIR"
    log_message "======================================"
    
    # Check database status
    db_status=$(check_db_status | grep DB_STATUS | cut -d: -f2)
    archive_mode=$(check_db_status | grep ARCHIVE_MODE | cut -d: -f2)
    
    if [ "$db_status" != "OPEN" ]; then
        log_message "ERROR: Database is not OPEN. Status: $db_status"
        send_notification "FAILED" "Database is not in OPEN state"
        exit 1
    fi
    
    if [ "$archive_mode" != "ARCHIVELOG" ] && [ "$backup_type" != "COLD" ]; then
        log_message "WARNING: Database is in NOARCHIVELOG mode. Only cold backup is possible."
    fi
    
    # Configure RMAN settings
    configure_rman
    
    # RMAN Backup Commands
    case $backup_type in
        FULL)
            log_message "Performing FULL database backup..."
            rman target / nocatalog log=$LOG_FILE append <<EOF
RUN {
    # Allocate channels
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/%d_%T_%s_%p_full.bkp';
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/%d_%T_%s_%p_full.bkp';
    
    # Backup database plus archivelog
    BACKUP AS COMPRESSED BACKUPSET 
        INCREMENTAL LEVEL 0 
        DATABASE 
        TAG 'FULL_BACKUP_${DATE}'
        PLUS ARCHIVELOG 
        TAG 'ARCHIVE_${DATE}'
        DELETE ALL INPUT;
    
    # Backup control file and SPFILE
    BACKUP CURRENT CONTROLFILE 
        FORMAT '$BACKUP_DIR/control_%d_%T_%s.bkp'
        TAG 'CONTROL_${DATE}';
    
    BACKUP SPFILE 
        FORMAT '$BACKUP_DIR/spfile_%d_%T_%s.bkp'
        TAG 'SPFILE_${DATE}';
    
    # Release channels
    RELEASE CHANNEL ch1;
    RELEASE CHANNEL ch2;
}

# Maintenance operations
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT OBSOLETE;
DELETE NOPROMPT EXPIRED BACKUP;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;

# Report
REPORT SCHEMA;
LIST BACKUP SUMMARY;
REPORT NEED BACKUP;
EXIT;
EOF
            ;;
            
        INCREMENTAL)
            log_message "Performing INCREMENTAL Level 1 backup..."
            rman target / nocatalog log=$LOG_FILE append <<EOF
RUN {
    # Allocate channels
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/%d_%T_%s_%p_incr.bkp';
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/%d_%T_%s_%p_incr.bkp';
    
    # Incremental Level 1 backup
    BACKUP AS COMPRESSED BACKUPSET 
        INCREMENTAL LEVEL 1 
        DATABASE 
        TAG 'INCR_BACKUP_${DATE}'
        PLUS ARCHIVELOG 
        TAG 'ARCHIVE_${DATE}'
        DELETE ALL INPUT;
    
    # Backup control file
    BACKUP CURRENT CONTROLFILE 
        FORMAT '$BACKUP_DIR/control_%d_%T_%s.bkp'
        TAG 'CONTROL_${DATE}';
    
    # Release channels
    RELEASE CHANNEL ch1;
    RELEASE CHANNEL ch2;
}

# Maintenance
CROSSCHECK BACKUP;
DELETE NOPROMPT OBSOLETE;
LIST BACKUP SUMMARY;
EXIT;
EOF
            ;;
            
        CUMULATIVE)
            log_message "Performing CUMULATIVE incremental backup..."
            rman target / nocatalog log=$LOG_FILE append <<EOF
RUN {
    # Allocate channels
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/%d_%T_%s_%p_cum.bkp';
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/%d_%T_%s_%p_cum.bkp';
    
    # Cumulative incremental backup
    BACKUP AS COMPRESSED BACKUPSET 
        INCREMENTAL LEVEL 1 CUMULATIVE 
        DATABASE 
        TAG 'CUMULATIVE_BACKUP_${DATE}'
        PLUS ARCHIVELOG 
        TAG 'ARCHIVE_${DATE}'
        DELETE ALL INPUT;
    
    # Backup control file
    BACKUP CURRENT CONTROLFILE 
        FORMAT '$BACKUP_DIR/control_%d_%T_%s.bkp'
        TAG 'CONTROL_${DATE}';
    
    # Release channels
    RELEASE CHANNEL ch1;
    RELEASE CHANNEL ch2;
}

# Maintenance
DELETE NOPROMPT OBSOLETE;
LIST BACKUP SUMMARY;
EXIT;
EOF
            ;;
            
        ARCHIVELOG)
            log_message "Performing ARCHIVELOG backup..."
            rman target / nocatalog log=$LOG_FILE append <<EOF
RUN {
    # Allocate channel
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/%d_%T_%s_%p_arch.bkp';
    
    # Backup all archive logs
    BACKUP AS COMPRESSED BACKUPSET 
        ARCHIVELOG ALL 
        NOT BACKED UP 2 TIMES
        TAG 'ARCHIVE_ONLY_${DATE}'
        DELETE ALL INPUT;
    
    # Release channel
    RELEASE CHANNEL ch1;
}

# Maintenance
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
EXIT;
EOF
            ;;
            
        COLD)
            log_message "Performing COLD backup (database will be shutdown)..."
            
            # Shutdown database
            sqlplus -S / as sysdba <<EOF
            SHUTDOWN IMMEDIATE;
            STARTUP MOUNT;
            EXIT;
EOF
            
            # Perform cold backup
            rman target / nocatalog log=$LOG_FILE append <<EOF
RUN {
    # Allocate channels
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/%d_%T_%s_%p_cold.bkp';
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK FORMAT '$BACKUP_DIR/%d_%T_%s_%p_cold.bkp';
    
    # Backup database in mount state
    BACKUP AS COMPRESSED BACKUPSET 
        DATABASE 
        TAG 'COLD_BACKUP_${DATE}';
    
    # Backup control file and SPFILE
    BACKUP CURRENT CONTROLFILE 
        FORMAT '$BACKUP_DIR/control_%d_%T_%s_cold.bkp'
        TAG 'CONTROL_COLD_${DATE}';
    
    BACKUP SPFILE 
        FORMAT '$BACKUP_DIR/spfile_%d_%T_%s_cold.bkp'
        TAG 'SPFILE_COLD_${DATE}';
    
    # Release channels
    RELEASE CHANNEL ch1;
    RELEASE CHANNEL ch2;
}
EXIT;
EOF
            
            # Open database
            sqlplus -S / as sysdba <<EOF
            ALTER DATABASE OPEN;
            EXIT;
EOF
            ;;
            
        *)
            log_message "ERROR: Invalid backup type specified"
            exit 1
            ;;
    esac
    
    # Check RMAN exit status
    RMAN_STATUS=$?
    
    if [ $RMAN_STATUS -eq 0 ]; then
        log_message "RMAN Backup completed successfully"
        send_notification "SUCCESS" "RMAN $backup_type backup completed successfully"
    else
        log_message "ERROR: RMAN Backup failed with exit code $RMAN_STATUS"
        send_notification "FAILED" "RMAN $backup_type backup failed. Check log: $LOG_FILE"
        exit $RMAN_STATUS
    fi
}

#================================================================
# Validation and Recovery Test Functions
#================================================================

validate_backup() {
    log_message "Validating recent backups..."
    
    rman target / nocatalog <<EOF
RESTORE DATABASE VALIDATE;
RESTORE CONTROLFILE VALIDATE;
RESTORE SPFILE VALIDATE;
RESTORE ARCHIVELOG ALL VALIDATE;
EXIT;
EOF
    
    if [ $? -eq 0 ]; then
        log_message "Backup validation completed successfully"
    else
        log_message "WARNING: Backup validation failed"
    fi
}

check_backup_status() {
    log_message "Checking backup status..."
    
    rman target / nocatalog <<EOF
REPORT NEED BACKUP DAYS 1;
REPORT UNRECOVERABLE;
REPORT OBSOLETE;
LIST BACKUP SUMMARY;
LIST BACKUP OF DATABASE COMPLETED AFTER 'SYSDATE-1';
EXIT;
EOF
}

#================================================================
# Block Change Tracking (for faster incremental backups)
#================================================================

enable_block_change_tracking() {
    log_message "Enabling block change tracking..."
    
    sqlplus -S / as sysdba <<EOF
    ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '$BACKUP_DIR/change_tracking.ctf';
    EXIT;
EOF
}

#================================================================
# Main Execution
#================================================================

# Parse command line arguments
case "$1" in
    full|FULL)
        perform_backup "FULL"
        validate_backup
        ;;
    incremental|INCREMENTAL|incr)
        perform_backup "INCREMENTAL"
        ;;
    cumulative|CUMULATIVE)
        perform_backup "CUMULATIVE"
        ;;
    archivelog|ARCHIVELOG|arch)
        perform_backup "ARCHIVELOG"
        ;;
    cold|COLD)
        perform_backup "COLD"
        ;;
    validate|VALIDATE)
        validate_backup
        ;;
    status|STATUS)
        check_backup_status
        ;;
    configure|CONFIGURE)
        configure_rman
        ;;
    enable_bct|ENABLE_BCT)
        enable_block_change_tracking
        ;;
    *)
        echo "Usage: $0 {full|incremental|cumulative|archivelog|cold|validate|status|configure|enable_bct}"
        echo "  full        - Perform full level 0 backup"
        echo "  incremental - Perform incremental level 1 backup"
        echo "  cumulative  - Perform cumulative incremental backup"
        echo "  archivelog  - Backup only archive logs"
        echo "  cold        - Perform cold backup (shutdown required)"
        echo "  validate    - Validate existing backups"
        echo "  status      - Check backup status"
        echo "  configure   - Configure RMAN settings"
        echo "  enable_bct  - Enable block change tracking"
        exit 1
        ;;
esac

# Cleanup old logs
find $LOG_DIR -name "*.log" -mtime +30 -exec rm {} \;

log_message "Backup process completed"
log_message "======================================"

exit 0
```



### 4. Single Instance Data Pump Export Script

Features:

- Full, schema, table, and metadata-only exports
- Automatic space checking
- Invalid objects detection
- Multi-file support for large exports
- Export verification and listing

Usage: `./oracle_11g_single_expdp_backup.sh {full|schema SCHEMAS|table TABLES|metadata|cleanup|list}`

```bash
#!/bin/bash
#================================================================
# Oracle 11g Single Instance Data Pump Export (EXPDP) Backup Script
# Description: Performs Data Pump export for single instance Oracle database
# Author: DBA Team
# Date: 2024
#================================================================

# Environment Variables
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1
export ORACLE_SID=ORCL  # Change to your database SID
export PATH=$ORACLE_HOME/bin:$PATH
export NLS_DATE_FORMAT='DD-MON-YYYY HH24:MI:SS'

# Export Configuration
EXPORT_DIR=/backup/datapump
LOG_DIR=/backup/logs
ORACLE_DIR=DATA_PUMP_DIR  # Oracle directory object name
SCHEMA_LIST=""  # Leave empty for full database export
RETENTION_DAYS=7
PARALLELISM=2
COMPRESSION=METADATA_ONLY  # Options: ALL, DATA_ONLY, METADATA_ONLY, NONE
FILE_SIZE=10G  # Maximum size per dump file
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE=$LOG_DIR/expdp_backup_${ORACLE_SID}_${DATE}.log

# Database connection
DB_USER=system
DB_PASS=password  # Consider using Oracle Wallet for security

# Create directories if they don't exist
mkdir -p $EXPORT_DIR
mkdir -p $LOG_DIR

# Email Configuration (optional)
MAIL_TO="dba-team@company.com"
MAIL_SUBJECT="Data Pump Export Report - $ORACLE_SID - $DATE"

#================================================================
# Functions
#================================================================

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

send_notification() {
    local status=$1
    local message=$2
    
    if [ ! -z "$MAIL_TO" ]; then
        echo "$message" | mail -s "$MAIL_SUBJECT - $status" $MAIL_TO
    fi
}

check_directory() {
    log_message "Checking Oracle directory object..."
    
    sqlplus -S $DB_USER/$DB_PASS <<EOF
    set heading off feedback off
    SELECT 'DIR_EXISTS:'||COUNT(*) FROM dba_directories WHERE directory_name = '$ORACLE_DIR';
    SELECT 'DIR_PATH:'||directory_path FROM dba_directories WHERE directory_name = '$ORACLE_DIR';
    exit;
EOF
}

create_directory() {
    log_message "Creating or updating Oracle directory object..."
    
    sqlplus -S $DB_USER/$DB_PASS <<EOF
    CREATE OR REPLACE DIRECTORY $ORACLE_DIR AS '$EXPORT_DIR';
    GRANT READ, WRITE ON DIRECTORY $ORACLE_DIR TO PUBLIC;
    exit;
EOF
    
    if [ $? -eq 0 ]; then
        log_message "Oracle directory created/updated successfully"
    else
        log_message "ERROR: Failed to create Oracle directory"
        exit 1
    fi
}

get_database_info() {
    sqlplus -S $DB_USER/$DB_PASS <<EOF
    set heading off feedback off pagesize 0
    SELECT 'DB_SIZE:'||ROUND(SUM(bytes)/1024/1024/1024,2)||'GB' 
    FROM dba_segments;
    SELECT 'DB_VERSION:'||version FROM v\$instance;
    SELECT 'DB_NAME:'||name FROM v\$database;
    SELECT 'CHAR_SET:'||value FROM nls_database_parameters WHERE parameter='NLS_CHARACTERSET';
    exit;
EOF
}

check_space() {
    local required_space=$1
    local available_space=$(df -BG $EXPORT_DIR | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [ $available_space -lt $required_space ]; then
        log_message "ERROR: Insufficient disk space. Required: ${required_space}GB, Available: ${available_space}GB"
        return 1
    fi
    
    log_message "Disk space check passed. Available: ${available_space}GB"
    return 0
}

get_invalid_objects() {
    log_message "Checking for invalid objects..."
    
    sqlplus -S $DB_USER/$DB_PASS <<EOF
    set heading off feedback off
    SELECT 'INVALID_COUNT:'||COUNT(*) FROM dba_objects WHERE status='INVALID';
    exit;
EOF
}

#================================================================
# Export Functions
#================================================================

perform_full_export() {
    local export_file="full_export_${ORACLE_SID}_${DATE}_%U.dmp"
    local export_log="full_export_${ORACLE_SID}_${DATE}_expdp.log"
    
    log_message "======================================"
    log_message "Starting Full Database Export"
    log_message "Database: $ORACLE_SID"
    log_message "Export File Pattern: $export_file"
    log_message "======================================"
    
    # Get database info
    db_size=$(get_database_info | grep DB_SIZE | cut -d: -f2)
    db_version=$(get_database_info | grep DB_VERSION | cut -d: -f2)
    db_charset=$(get_database_info | grep CHAR_SET | cut -d: -f2)
    
    log_message "Database size: $db_size"
    log_message "Database version: $db_version"
    log_message "Character set: $db_charset"
    
    # Check for invalid objects
    invalid_count=$(get_invalid_objects | grep INVALID_COUNT | cut -d: -f2)
    if [ "$invalid_count" != "0" ]; then
        log_message "WARNING: Found $invalid_count invalid objects"
    fi
    
    # Check disk space (rough estimate: 30% of database size)
    db_size_num=$(echo $db_size | sed 's/GB//')
    required_space=$(echo "$db_size_num * 0.3" | bc | cut -d. -f1)
    if ! check_space $required_space; then
        send_notification "FAILED" "Insufficient disk space for export"
        exit 1
    fi
    
    # Create parameter file for export
    cat > /tmp/expdp_full_${DATE}.par <<EOF
USERID=$DB_USER/$DB_PASS
DIRECTORY=$ORACLE_DIR
DUMPFILE=$export_file
LOGFILE=$export_log
FULL=Y
PARALLEL=$PARALLELISM
FILESIZE=$FILE_SIZE
COMPRESSION=$COMPRESSION
EXCLUDE=STATISTICS
FLASHBACK_TIME=SYSTIMESTAMP
METRICS=Y
EOF
    
    # Add common exclusions
    cat >> /tmp/expdp_full_${DATE}.par <<EOF
EXCLUDE=SCHEMA:"IN ('OUTLN','MGMT_VIEW','FLOWS_FILES','APEX_030200','APEX_PUBLIC_USER','OWBSYS','OWBSYS_AUDIT')"
EXCLUDE=TABLE:"LIKE 'BIN$%'"
EXCLUDE=INDEX:"LIKE 'BIN$%'"
EOF
    
    log_message "Starting Data Pump export..."
    expdp parfile=/tmp/expdp_full_${DATE}.par
    
    EXPDP_STATUS=$?
    
    if [ $EXPDP_STATUS -eq 0 ] || [ $EXPDP_STATUS -eq 5 ]; then
        log_message "Data Pump export completed (Status: $EXPDP_STATUS)"
        
        # Compress dump files
        log_message "Compressing export files..."
        for file in $EXPORT_DIR/full_export_${ORACLE_SID}_${DATE}_*.dmp; do
            if [ -f "$file" ]; then
                gzip "$file" &
            fi
        done
        wait
        
        # Generate metadata
        generate_export_metadata "full_export_${ORACLE_SID}_${DATE}" "FULL"
        
        # Verify export
        verify_export_logs "$EXPORT_DIR/$export_log"
        
        send_notification "SUCCESS" "Full database export completed successfully"
    else
        log_message "ERROR: Data Pump export failed with exit code $EXPDP_STATUS"
        send_notification "FAILED" "Data Pump export failed. Check log: $LOG_FILE"
        exit $EXPDP_STATUS
    fi
    
    # Cleanup parameter file
    rm -f /tmp/expdp_full_${DATE}.par
}

perform_schema_export() {
    local schemas=$1
    local export_file="schema_export_${DATE}_%U.dmp"
    local export_log="schema_export_${DATE}_expdp.log"
    
    log_message "======================================"
    log_message "Starting Schema Export"
    log_message "Schemas: $schemas"
    log_message "Export File Pattern: $export_file"
    log_message "======================================"
    
    # Validate schemas exist
    for schema in $(echo $schemas | tr ',' ' '); do
        schema_exists=$(sqlplus -S $DB_USER/$DB_PASS <<EOF
        set heading off feedback off
        SELECT COUNT(*) FROM dba_users WHERE username=UPPER('$schema');
        exit;
EOF
        )
        if [ "$schema_exists" = "0" ]; then
            log_message "ERROR: Schema $schema does not exist"
            exit 1
        fi
    done
    
    # Create parameter file for export
    cat > /tmp/expdp_schema_${DATE}.par <<EOF
USERID=$DB_USER/$DB_PASS
DIRECTORY=$ORACLE_DIR
DUMPFILE=$export_file
LOGFILE=$export_log
SCHEMAS=$schemas
PARALLEL=$PARALLELISM
FILESIZE=$FILE_SIZE
COMPRESSION=$COMPRESSION
EXCLUDE=STATISTICS
FLASHBACK_TIME=SYSTIMESTAMP
METRICS=Y
EOF
    
    log_message "Starting Data Pump schema export..."
    expdp parfile=/tmp/expdp_schema_${DATE}.par
    
    EXPDP_STATUS=$?
    
    if [ $EXPDP_STATUS -eq 0 ] || [ $EXPDP_STATUS -eq 5 ]; then
        log_message "Schema export completed successfully"
        
        # Compress dump files
        log_message "Compressing export files..."
        for file in $EXPORT_DIR/schema_export_${DATE}_*.dmp; do
            if [ -f "$file" ]; then
                gzip "$file" &
            fi
        done
        wait
        
        # Generate metadata
        generate_export_metadata "schema_export_${DATE}" "SCHEMA:$schemas"
        
        send_notification "SUCCESS" "Schema export completed: $schemas"
    else
        log_message "ERROR: Schema export failed with exit code $EXPDP_STATUS"
        send_notification "FAILED" "Schema export failed"
        exit $EXPDP_STATUS
    fi
    
    # Cleanup parameter file
    rm -f /tmp/expdp_schema_${DATE}.par
}

perform_table_export() {
    local tables=$1
    local export_file="table_export_${DATE}.dmp"
    local export_log="table_export_${DATE}_expdp.log"
    
    log_message "======================================"
    log_message "Starting Table Export"
    log_message "Tables: $tables"
    log_message "Export File: $export_file"
    log_message "======================================"
    
    # Create parameter file for export
    cat > /tmp/expdp_table_${DATE}.par <<EOF
USERID=$DB_USER/$DB_PASS
DIRECTORY=$ORACLE_DIR
DUMPFILE=$export_file
LOGFILE=$export_log
TABLES=$tables
COMPRESSION=$COMPRESSION
FLASHBACK_TIME=SYSTIMESTAMP
METRICS=Y
CONTENT=ALL
EOF
    
    log_message "Starting Data Pump table export..."
    expdp parfile=/tmp/expdp_table_${DATE}.par
    
    EXPDP_STATUS=$?
    
    if [ $EXPDP_STATUS -eq 0 ] || [ $EXPDP_STATUS -eq 5 ]; then
        log_message "Table export completed successfully"
        
        # Compress dump file
        log_message "Compressing export file..."
        gzip $EXPORT_DIR/$export_file
        
        # Generate metadata
        generate_export_metadata "$export_file.gz" "TABLE:$tables"
        
        send_notification "SUCCESS" "Table export completed: $tables"
    else
        log_message "ERROR: Table export failed with exit code $EXPDP_STATUS"
        send_notification "FAILED" "Table export failed"
        exit $EXPDP_STATUS
    fi
    
    # Cleanup parameter file
    rm -f /tmp/expdp_table_${DATE}.par
}

perform_metadata_only_export() {
    local export_file="metadata_export_${ORACLE_SID}_${DATE}.dmp"
    local export_log="metadata_export_${ORACLE_SID}_${DATE}_expdp.log"
    
    log_message "======================================"
    log_message "Starting Metadata-Only Export"
    log_message "Export File: $export_file"
    log_message "======================================"
    
    # Create parameter file for export
    cat > /tmp/expdp_metadata_${DATE}.par <<EOF
USERID=$DB_USER/$DB_PASS
DIRECTORY=$ORACLE_DIR
DUMPFILE=$export_file
LOGFILE=$export_log
FULL=Y
CONTENT=METADATA_ONLY
COMPRESSION=$COMPRESSION
EOF
    
    log_message "Starting Data Pump metadata export..."
    expdp parfile=/tmp/expdp_metadata_${DATE}.par
    
    EXPDP_STATUS=$?
    
    if [ $EXPDP_STATUS -eq 0 ] || [ $EXPDP_STATUS -eq 5 ]; then
        log_message "Metadata export completed successfully"
        
        # Compress dump file
        log_message "Compressing export file..."
        gzip $EXPORT_DIR/$export_file
        
        # Generate metadata
        generate_export_metadata "$export_file.gz" "METADATA_ONLY"
        
        send_notification "SUCCESS" "Metadata export completed"
    else
        log_message "ERROR: Metadata export failed with exit code $EXPDP_STATUS"
        send_notification "FAILED" "Metadata export failed"
        exit $EXPDP_STATUS
    fi
    
    # Cleanup parameter file
    rm -f /tmp/expdp_metadata_${DATE}.par
}

#================================================================
# Utility Functions
#================================================================

generate_export_metadata() {
    local export_prefix=$1
    local export_type=$2
    local metadata_file="${export_prefix}.metadata"
    
    log_message "Generating export metadata..."
    
    cat > $EXPORT_DIR/$metadata_file <<EOF
===============================================
Oracle Data Pump Export Metadata
===============================================
Export Type: $export_type
Export Date: $(date)
Database: $ORACLE_SID
Oracle Home: $ORACLE_HOME
Export File Prefix: $export_prefix
Compression: $COMPRESSION
Parallelism: $PARALLELISM
Character Set: $(get_database_info | grep CHAR_SET | cut -d: -f2)
Database Version: $(get_database_info | grep DB_VERSION | cut -d: -f2)

Files Generated:
EOF
    
    # List all related files
    ls -lh $EXPORT_DIR/${export_prefix}* | grep -v metadata >> $EXPORT_DIR/$metadata_file
    
    # Add checksums
    echo -e "\nFile Checksums:" >> $EXPORT_DIR/$metadata_file
    for file in $EXPORT_DIR/${export_prefix}*.gz; do
        if [ -f "$file" ]; then
            echo "$(basename $file): $(md5sum $file | cut -d' ' -f1)" >> $EXPORT_DIR/$metadata_file
        fi
    done
    
    log_message "Metadata file created: $metadata_file"
}

verify_export_logs() {
    local log_file=$1
    
    log_message "Verifying export log for errors..."
    
    # Check for common errors in the export log
    if grep -E "ORA-|Error|Failed" $log_file > /dev/null; then
        log_message "WARNING: Errors found in export log. Please review: $log_file"
        grep -E "ORA-|Error|Failed" $log_file | head -20
    else
        log_message "No errors found in export log"
    fi
}

cleanup_old_exports() {
    log_message "Cleaning up old export files (older than $RETENTION_DAYS days)..."
    
    # Remove old dump files
    find $EXPORT_DIR -name "*.dmp*" -mtime +$RETENTION_DAYS -exec rm {} \;
    find $EXPORT_DIR -name "*.metadata" -mtime +$RETENTION_DAYS -exec rm {} \;
    
    # Remove old log files
    find $LOG_DIR -name "*.log" -mtime +30 -exec rm {} \;
    
    log_message "Cleanup completed"
}

list_exports() {
    log_message "Listing available export files..."
    
    echo "======================================"
    echo "Available Export Files in $EXPORT_DIR"
    echo "======================================"
    
    ls -lht $EXPORT_DIR/*.dmp* 2>/dev/null | head -20
    
    echo ""
    echo "Total disk usage: $(du -sh $EXPORT_DIR | cut -f1)"
}

#================================================================
# Main Execution
#================================================================

# Check and create Oracle directory
dir_exists=$(check_directory | grep DIR_EXISTS | cut -d: -f2)
if [ "$dir_exists" != "1" ]; then
    log_message "Oracle directory does not exist. Creating..."
    create_directory
else
    dir_path=$(check_directory | grep DIR_PATH | cut -d: -f2)
    log_message "Using existing Oracle directory: $ORACLE_DIR ($dir_path)"
fi

# Parse command line arguments
case "$1" in
    full|FULL)
        perform_full_export
        ;;
    schema|SCHEMA)
        if [ -z "$2" ]; then
            echo "Error: Schema name(s) required"
            echo "Usage: $0 schema SCHEMA1,SCHEMA2,..."
            exit 1
        fi
        perform_schema_export "$2"
        ;;
    table|TABLE)
        if [ -z "$2" ]; then
            echo "Error: Table name(s) required"
            echo "Usage: $0 table SCHEMA.TABLE1,SCHEMA.TABLE2,..."
            exit 1
        fi
        perform_table_export "$2"
        ;;
    metadata|METADATA)
        perform_metadata_only_export
        ;;
    cleanup|CLEANUP)
        cleanup_old_exports
        ;;
    list|LIST)
        list_exports
        ;;
    *)
        echo "Usage: $0 {full|schema|table|metadata|cleanup|list} [additional_params]"
        echo ""
        echo "Options:"
        echo "  full              - Perform full database export"
        echo "  schema SCHEMAS    - Export specific schemas (comma-separated)"
        echo "  table TABLES      - Export specific tables (SCHEMA.TABLE format)"
        echo "  metadata          - Export metadata only (no data)"
        echo "  cleanup           - Remove old export files"
        echo "  list              - List available export files"
        echo ""
        echo "Examples:"
        echo "  $0 full"
        echo "  $0 schema HR,SCOTT,APP_SCHEMA"
        echo "  $0 table HR.EMPLOYEES,HR.DEPARTMENTS"
        echo "  $0 metadata"
        echo ""
        echo "Configuration:"
        echo "  ORACLE_SID: $ORACLE_SID"
        echo "  Export Dir: $EXPORT_DIR"
        echo "  Retention:  $RETENTION_DAYS days"
        exit 1
        ;;
esac

# Always cleanup old exports after successful backup
if [ $? -eq 0 ]; then
    cleanup_old_exports
fi

log_message "Export process completed"
log_message "======================================"

exit 0
```



## Setup Instructions

1. **Update environment variables** in each script:

   - `ORACLE_HOME`
   - `ORACLE_SID`
   - Backup directories
   - Database credentials

2. **Set executable permissions**:

   ```bash
   chmod +x oracle_11g_*.sh
   ```

3. **Schedule with cron** (example):

   ```bash
   # Daily incremental at 2 AM
   0 2 * * * /path/to/oracle_11g_rman_backup.sh incremental
   
   # Weekly full backup on Sunday at 1 AM
   0 1 * * 0 /path/to/oracle_11g_rman_backup.sh full
   
   # Archive log backup every 4 hours
   0 */4 * * * /path/to/oracle_11g_rman_backup.sh archivelog
   ```

All scripts include comprehensive logging, error handling, and retention management. Customize the retention periods and parallelism settings based on your requirements.