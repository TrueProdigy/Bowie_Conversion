
DELIMITER $$
DROP PROCEDURE IF EXISTS `conversionDB`.`CreateIndex` $$
CREATE PROCEDURE `conversionDB`.`CreateIndex`
(
    given_database VARCHAR(64),
    given_table    VARCHAR(64),
    given_index    VARCHAR(64),
    given_columns  VARCHAR(1024)
)
BEGIN

    DECLARE IndexIsThere INTEGER;

    SELECT COUNT(1) INTO IndexIsThere
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE table_schema = given_database
    AND   table_name   = given_table
    AND   index_name   = given_index;

    IF IndexIsThere = 0 THEN
        SET @sqlstmt = CONCAT('CREATE INDEX ',given_index,' ON ',
        given_database,'.',given_table,' (',given_columns,')');
        PREPARE st FROM @sqlstmt;
        EXECUTE st;
        DEALLOCATE PREPARE st;
    ELSE
        SELECT CONCAT('Index ',given_index,' already exists on Table ',
        given_database,'.',given_table) CreateindexErrorMessage;
    END IF;

END $$

DELIMITER ;



DELIMITER $$

DROP PROCEDURE IF EXISTS `conversionDB`.`CreateColumn` $$
CREATE PROCEDURE `conversionDB`.`CreateColumn`
(
    given_database VARCHAR(64),
    given_table    VARCHAR(64),
    given_column  VARCHAR(64),
    given_datatype  VARCHAR(200)
)
BEGIN

    DECLARE ColumnIsThere INTEGER;

    select count(1) into ColumnIsThere
from information_schema.tables t
join information_schema.columns c using (table_schema, table_name)
where t.table_schema = given_database
and t.TABLE_NAME = given_table
and c.COLUMN_NAME = given_column;

    
    IF ColumnIsThere = 0 THEN
        SET @sqlstmt = CONCAT('alter table ', given_database, '.' ,given_table,' add ', given_column, ' ', given_datatype, ';');
        PREPARE st FROM @sqlstmt;
        EXECUTE st;
        DEALLOCATE PREPARE st;
    ELSE
        SELECT CONCAT('Column ',given_column,' already exists on Table ',
        given_database,'.',given_table) as CreateindexErrorMessage;
    END IF;

END $$

DELIMITER ;