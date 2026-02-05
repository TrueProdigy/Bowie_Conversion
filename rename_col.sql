DELIMITER $$

CREATE PROCEDURE rename_columns()
BEGIN
    DECLARE done_tables INT DEFAULT 0;
    DECLARE v_table_name VARCHAR(128);

    -- Cursor to loop through all tables in finalDB that exist in conversionDB
    DECLARE table_cursor CURSOR FOR
        SELECT t.TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES t
        JOIN INFORMATION_SCHEMA.TABLES c
          ON t.TABLE_NAME = c.TABLE_NAME
        WHERE t.TABLE_SCHEMA = 'finalDB'
          AND c.TABLE_SCHEMA = 'conversionDB'
          AND t.TABLE_TYPE = 'BASE TABLE';

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_tables = 1;

    OPEN table_cursor;

    table_loop: LOOP
        FETCH table_cursor INTO v_table_name;
        IF done_tables THEN
            LEAVE table_loop;
        END IF;

        BEGIN
            DECLARE done_columns INT DEFAULT 0;
            DECLARE v_sql LONGTEXT;

            -- Cursor to loop through columns that need renaming
            DECLARE col_cursor CURSOR FOR
                SELECT CONCAT(
                    'ALTER TABLE finalDB.`', ny.TABLE_NAME,
                    '` CHANGE `', ny.COLUMN_NAME, '` `',
                    cdb.COLUMN_NAME, '` ',
                    ny.COLUMN_TYPE,
                    IF(ny.IS_NULLABLE = 'NO', ' NOT NULL', ''),
                    IF(ny.COLUMN_DEFAULT IS NOT NULL,
                       CONCAT(' DEFAULT ', QUOTE(ny.COLUMN_DEFAULT)), ''),
                    ';'
                )
                FROM INFORMATION_SCHEMA.COLUMNS ny
                JOIN INFORMATION_SCHEMA.COLUMNS cdb
                  ON ny.ORDINAL_POSITION = cdb.ORDINAL_POSITION
                  AND ny.TABLE_NAME = cdb.TABLE_NAME
                WHERE ny.TABLE_SCHEMA = 'finalDB'
                  AND cdb.TABLE_SCHEMA = 'conversionDB'
                  AND ny.TABLE_NAME = v_table_name
                  -- Only rename if names differ
                  AND ny.COLUMN_NAME <> cdb.COLUMN_NAME
                  -- Skip if target column already exists in finalDB
                  AND cdb.COLUMN_NAME NOT IN (
                      SELECT COLUMN_NAME
                      FROM INFORMATION_SCHEMA.COLUMNS
                      WHERE TABLE_SCHEMA = 'finalDB'
                        AND TABLE_NAME = ny.TABLE_NAME
                  )
                ORDER BY ny.ORDINAL_POSITION;

            DECLARE CONTINUE HANDLER FOR NOT FOUND SET done_columns = 1;

            OPEN col_cursor;

            col_loop: LOOP
                FETCH col_cursor INTO v_sql;
                IF done_columns THEN
                    LEAVE col_loop;
                END IF;

                -- Use user variable for dynamic SQL
                SET @sql = v_sql;
                PREPARE stmt FROM @sql;
                EXECUTE stmt;
                DEALLOCATE PREPARE stmt;

            END LOOP;

            CLOSE col_cursor;
        END;

    END LOOP;

    CLOSE table_cursor;
END$$

DELIMITER ;

