After migrating from Oracle 11g RAC to a single instance, here's a comprehensive approach to verify the migration is complete:

## 1. **Compare Object Counts**

Run these queries on both source (RAC) and target (single instance) databases:

```sql
-- Count all objects by type and owner
SELECT owner, object_type, COUNT(*) as object_count
FROM dba_objects
WHERE owner NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN')
GROUP BY owner, object_type
ORDER BY owner, object_type;

-- Total object count
SELECT COUNT(*) FROM dba_objects
WHERE owner NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN');
```

## 2. **Verify Row Counts**

Create a script to compare row counts for all tables:

```sql
-- Generate row count queries for all tables
SELECT 'SELECT ''' || owner || '.' || table_name || 
       ''', COUNT(*) FROM ' || owner || '.' || table_name || ';'
FROM dba_tables
WHERE owner NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN')
ORDER BY owner, table_name;
```

## 3. **Check Data Integrity**

Verify constraints, indexes, and triggers:

```sql
-- Check constraint counts
SELECT owner, constraint_type, status, COUNT(*)
FROM dba_constraints
WHERE owner NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN')
GROUP BY owner, constraint_type, status;

-- Check index counts
SELECT owner, index_type, status, COUNT(*)
FROM dba_indexes
WHERE owner NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN')
GROUP BY owner, index_type, status;

-- Check trigger counts
SELECT owner, status, COUNT(*)
FROM dba_triggers
WHERE owner NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN')
GROUP BY owner, status;
```

## 4. **Validate Invalid Objects**

Check for any invalid objects that need recompilation:

```sql
-- Find invalid objects
SELECT owner, object_type, object_name
FROM dba_objects
WHERE status = 'INVALID'
ORDER BY owner, object_type, object_name;

-- Recompile invalid objects if needed
EXEC UTL_RECOMP.recomp_serial();
```

## 5. **Compare Database Size**

Verify the overall database size:

```sql
-- Check tablespace sizes
SELECT tablespace_name,
       ROUND(SUM(bytes)/1024/1024/1024, 2) as size_gb
FROM dba_segments
GROUP BY tablespace_name
ORDER BY tablespace_name;

-- Total database size
SELECT ROUND(SUM(bytes)/1024/1024/1024, 2) as total_size_gb
FROM dba_segments;
```

## 6. **Verify Sequences**

Check that sequence values are appropriate:

```sql
-- List sequences with current values
SELECT sequence_owner, sequence_name, last_number
FROM dba_sequences
WHERE sequence_owner NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN')
ORDER BY sequence_owner, sequence_name;
```

## 7. **Check Database Links**

Verify database links are working:

```sql
-- List database links
SELECT owner, db_link, host FROM dba_db_links;

-- Test each link
SELECT * FROM dual@db_link_name;
```

## 8. **Validate Jobs and Schedules**

Check scheduled jobs:

```sql
-- Check DBA_JOBS
SELECT job, what, next_date, broken FROM dba_jobs;

-- Check DBA_SCHEDULER_JOBS
SELECT owner, job_name, enabled, state
FROM dba_scheduler_jobs
WHERE owner NOT IN ('SYS','SYSTEM','ORACLE_OCM');
```

## 9. **Run Data Sampling Checks**

Perform spot checks on critical tables:

```sql
-- Sample data from important tables
-- Compare checksums or hash values for critical data
SELECT DBMS_CRYPTO.HASH(
    UTL_RAW.CAST_TO_RAW(column1 || column2 || column3),
    DBMS_CRYPTO.HASH_SH1
) as data_hash
FROM critical_table
WHERE ROWNUM <= 1000;
```

## 10. **Application Validation**

- Run application connectivity tests
- Execute critical business queries and compare results
- Perform application-specific validation scripts
- Check application logs for errors

## 11. **Performance Validation**

Compare key performance metrics:

```sql
-- Check optimizer statistics
SELECT owner, table_name, last_analyzed
FROM dba_tables
WHERE owner NOT IN ('SYS','SYSTEM','DBSNMP','SYSMAN')
AND last_analyzed IS NOT NULL
ORDER BY last_analyzed DESC;

-- Gather fresh statistics if needed
EXEC DBMS_STATS.gather_database_stats();
```

## 12. **Generate Migration Report**

Create a comprehensive comparison report documenting:

- Object count differences
- Row count variances
- Invalid objects
- Failed database links
- Disabled jobs or triggers
- Performance baseline comparisons

**Important Tips:**

- Keep detailed logs of all verification queries from both environments
- Use tools like Oracle Data Compare or custom scripts for automated comparison
- Pay special attention to sequences, as they might need adjustment after migration
- Verify that all RAC-specific features have been properly converted or removed
- Test backup and recovery procedures on the new single instance

If any discrepancies are found, investigate and resolve them before declaring the migration complete. Consider running parallel operations for a period to ensure data consistency before fully cutting over to the single instance.