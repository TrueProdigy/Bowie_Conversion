# Bowie_Conversion

Conversion Steps

1. Download bak from sharepoint 
2. Upload to s3 
3. Load MSSQL DB using s3 data 
4. Drop empty tables using these by executing these steps: 
        a) 
DECLARE @SchemaName sysname = 'dbo';

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

        b) Copy and paste drop table sql sql statements and execute
5. Change table names using python script rename_bowie_tbls.py
        a) Would need to run this for any left overs that didn't change correctly: 
        EXEC sp_rename N'dbo.DWSAL' -- old name , N'AppraisalSale' -- new name;
        -- need to ref ERD and current db 
        -- casing and _ is hard to match 1 for 1 and lots of it have to be done manually 
6. Reformat table names using python script reformat_bowie_tbls.py
        -- need to ref ERD and current db 
        -- casing and _ is hard to match 1 for 1 and lots of it have to be done manually
7. Run and create the rename column stored procedure to rename columns. And then execute. 