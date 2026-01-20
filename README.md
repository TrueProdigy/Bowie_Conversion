# Bowie Conversion

## Conversion Steps

1. **Download the `.bak` file** file from SharePoint.

2. **Upload the backup file to S3.**

3. **Restore the MSSQL database** using the data from S3.

4. **Drop empty tables** by following these steps:
   
   **a. Generate** `DROP TABLE` **statements**
   
   ```DECLARE @SchemaName sysname = 'dbo';

   SELECT
       'DROP TABLE '
       + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) + ';' AS DropStatement
   FROM sys.tables t
   JOIN sys.schemas s
       ON t.schema_id = s.schema_id
   LEFT JOIN sys.partitions p
       ON t.object_id = p.object_id
      AND p.index_id IN (0,1)
   WHERE s.name = @SchemaName
   GROUP BY s.name, t.name
   HAVING SUM(p.rows) = 0;

b. **Execute the generated** DROP TABLE statements.

5. **Rename tables** using the Python script:
   
`rename_bowie_tbls.py`

a. **Manually rename any remaining tables that were not updated correctly:**

`EXEC sp_rename N'dbo.DWSAL', N'AppraisalSale';`

**Notes:**     
- Reference the ERD and the current database.
- Naming mismatches (casing and underscores) often require manual intervention.
6. **Reformat table names using the Python script:**

`reformat_bowie_tbls.py`

**Notes:**
- Reference the ERD and the current database.
- Due to naming inconsistencies, some changes may still need to be handled manually.

7. **Create and run the column-renaming stored procedure to align column names with the target schema.**
