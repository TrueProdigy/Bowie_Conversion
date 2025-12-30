use bowie_appraisal;
set @pYearMin = 2020;
set @pYearMax = 2025;


set @createdBy = 'TPConversion - insertAbsSub';
set @createDt = now();
set @p_skipTrigger = 1;
set sql_safe_updates = 0;

-- query to check
# SELECT
#   LEFT(CAST(axref.AcctXRef AS CHAR), 5) AS asCode,
#   l.AuditTaxYear AS year,
#   COUNT(DISTINCT l.LegalComponent)       AS component_count,
#   GROUP_CONCAT(DISTINCT l.LegalComponent ORDER BY l.LegalComponent) AS components
# FROM conversionDB.PropertyLegalDescriptions l
# JOIN conversionDB.AcctXREF axref
#   ON l.PropertyKey  = axref.PropertyKey
#  AND l.AuditTaxYear = axref.AuditTaxYear
# WHERE l.LegalType = 'LINE1'
#   AND l.LegalComponent IN (
#       'OAK FOREST SUBD #2',
#       'SUBD  SILVER OAKS #2',
#       'TEXARKANA SHOPPING CENTER 2ND',
#       'TEXARKANA SHOPPING CENTER 2ND ADDN',
#       'JAMES FROST ADDN (NB)',
#       'W F THOMPSON A-565'
#   )
#   AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '%-%'
#   AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '8%'
#   AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '5%'
#   AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '4%'
#   AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '7%'
#   AND CAST(axref.AcctXRef AS CHAR) REGEXP '^[0-9]{5}'
#   AND l.AuditTaxYear    = 2024
#   AND axref.AcctXRefType = 'ACCT'
# GROUP BY asCode, year
# HAVING COUNT(DISTINCT l.LegalComponent) > 1
# ORDER BY asCode, year;
#
#
# SELECT
#   LEFT(CAST(axref.AcctXRef AS CHAR), 5) AS asCode,
#   l.AuditTaxYear                         AS year,
#   COUNT(DISTINCT l.LegalComponent)       AS component_count,
#   GROUP_CONCAT(DISTINCT l.LegalComponent ORDER BY l.LegalComponent SEPARATOR ', ') AS components
# FROM conversionDB.PropertyLegalDescriptions l
# JOIN conversionDB.AcctXREF axref
#   ON l.PropertyKey  = axref.PropertyKey
#  AND l.AuditTaxYear = axref.AuditTaxYear
# WHERE l.LegalType = 'LINE1'
#   AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '%-%'
#   AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '8%'
#   AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '5%'
#   AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '4%'
#   AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '7%'
#   AND CAST(axref.AcctXRef AS CHAR) REGEXP '^[0-9]{5}'
#   AND l.AuditTaxYear = 2024            -- or BETWEEN @pYearMin AND @pYearMax
#   AND axref.AcctXRefType = 'ACCT'
# GROUP BY asCode, year
# HAVING COUNT(DISTINCT l.LegalComponent) > 1
# ORDER BY asCode, year;



insert ignore into abstractSubdivision (
	abstractSubdivisionDescription,
    abstractSubdivision,
# 	abstractSubdivisionIndicator,
	createdBy,
	createDt)
SELECT
    DISTINCT l.LegalComponent AS Subdivision,
    GROUP_CONCAT(DISTINCT LEFT(CAST(axref.AcctXRef AS CHAR), 5)
                 ORDER BY LEFT(CAST(axref.AcctXRef AS CHAR), 5)
                 SEPARATOR ', ') AS asCODE,
    @createdBy,
    NOW()
FROM conversionDB.PropertyLegalDescriptions l
JOIN conversionDB.AcctXREF axref
  ON l.PropertyKey   = axref.PropertyKey
 AND l.AuditTaxYear  = axref.AuditTaxYear
WHERE l.LegalType = 'LINE1'
  AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '%-%'
  AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '8%'
  AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '5%'
  AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '4%'
  AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '7%'
  AND CAST(axref.AcctXRef AS CHAR) REGEXP '^[0-9]{5}'
  AND l.AuditTaxYear between @pYearMin and @pYearMax
  AND axref.AcctXRefType = 'ACCT'
GROUP BY l.LegalComponent
ORDER BY l.LegalComponent ASC;

use bowie_appraisal;
set @pYearMin = 2020;
set @pYearMax = 2025;


set @createdBy = 'TPConversion - insertAbsSub';
set @createDt = now();
set @p_skipTrigger = 1;
set sql_safe_updates = 0;


insert into abstractSubdivisionDetail (
	abstractSubdivision,
	abstractSubdivisionYear,
	improvementPct,
	landPct,
	createdBy,
	createDt)
SELECT DISTINCT
  LEFT(CAST(axref.AcctXRef AS CHAR), 5)             AS abstractSubdivision,
  l.AuditTaxYear                                    AS abstractSubdivisionYear,
  100,
  100,
  @createdBy,
  NOW()
FROM conversionDB.PropertyLegalDescriptions l
JOIN conversionDB.AcctXREF axref
  ON l.PropertyKey  = axref.PropertyKey
 AND l.AuditTaxYear = axref.AuditTaxYear
WHERE l.LegalType = 'LINE1'
  AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '%-%'
  AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '8%'
  AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '5%'
  AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '4%'
  AND CAST(axref.AcctXRef AS CHAR) NOT LIKE '7%'
  AND CAST(axref.AcctXRef AS CHAR) REGEXP '^[0-9]{5}'
  AND l.AuditTaxYear BETWEEN @pYearMin AND @pYearMax
  AND axref.AcctXRefType = 'ACCT';

