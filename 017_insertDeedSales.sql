set @createDt = now();
set @createdBy = 'TPConversion - insertPersonalDetail';

set @pYearMin = 2020;
set @pYearMax = 2025;

set @p_user = 'TPConversion - insertDeedSales';
SET @seq = 0;



# delete from sales;
# delete from deeds;

# set @p_user = 'TP Conversion';
# INSERT INTO codefile (codeFileType, codeFileName, codeName, codeDescription,createdBy, createDt, active, codeFileYear)
# SELECT
#   'Deed' AS codeFileType,
#   'Deed Type' AS codeFileName,
#   dtype.CCD_Code      AS codeName,
#   UPPER(dtype.CCD_Description) AS codeDescription,
#   @p_user,
#   now(),
#   1,
#   0
# FROM conversionDB.CommonCodeH dtype
# WHERE dtype.CCD_Type = 'SALRIT'
#   AND NOT EXISTS (
#     SELECT 1
#     FROM codefile cf
#     WHERE cf.codeFileType = 'Deed'
#       AND cf.codeFileName = 'Deed Type'
#       AND cf.codeName = dtype.CCD_Code
#   );


# insert into deeds (
# deedType,
# deedDt,
# page,
# volume,
# instrumentNum,
# sellerLine,
# buyerLine,
# createdBy,
# createDt)
# select
# TRIM(asale.DWINSTYPE) as deedType
# ,DATE_FORMAT(STR_TO_DATE(asale.DeedDate,'%Y%m%d'), '%Y-%m-%d 00:00:00') as deedDt
# ,asale.RecordingPage as page
# ,asale.DWVOLUME as volume
# ,COALESCE(asale.DWINSTNUM,'') as instrumentNum
# ,TRIM(asale.DWSELLER1) as sellerLine
# ,TRIM(asale.DWBUYER1) as buyerLine
# ,@p_user
# ,NOW()
# FROM conversionDB.AppraisalSale AS asale
# WHERE NOT EXISTS (
#   SELECT 1
#   FROM deeds d
#   WHERE d.volume = asale.DWVOLUME
#     AND d.page = asale.RecordingPage
#     AND (
#          (d.instrumentNum IS NULL AND asale.DWINSTNUM IS NULL)
#       OR (d.instrumentNum = asale.DWINSTNUM)
#     )
#     AND LOWER(TRIM(d.sellerLine)) = LOWER(TRIM(asale.DWSELLER1))
#     AND LOWER(TRIM(d.buyerLine))  = LOWER(TRIM(asale.DWBUYER1))
#     AND DATE(d.deedDt) = STR_TO_DATE(asale.DeedDate, '%Y%m%d')
# );


# INSERT INTO deedsProperty (
#   deedID,
#   pID,
#   deedOrder,
#   createdBy,
#   createDt
# )
# SELECT
#   t.deedID,
#   t.PropertyKey AS pID,
#   @seq := @seq + 1 AS deedOrder,
#   @p_user        AS createdBy,
#   NOW()          AS createDt
# FROM (
#   SELECT
#     d.deedID,
#     asale.PropertyKey
# FROM conversionDB.AppraisalSale AS asale
# JOIN (
#   SELECT MIN(deedID) AS deedID, volume, page, DATE(deedDt) AS deedDate, sellerLine, buyerLine
#   FROM deeds
#   GROUP BY volume, page, DATE(deedDt), sellerLine, buyerLine
# ) d
#   ON d.volume   = asale.DWVOLUME
#  AND d.page     = asale.RecordingPage
#  AND d.deedDate = STR_TO_DATE(asale.DeedDate, '%Y%m%d')
#  AND d.sellerLine = asale.DWSELLER1
#  AND d.buyerLine  = asale.DWBUYER1
# ORDER BY STR_TO_DATE(CAST(asale.SaleDate AS CHAR), '%Y%m%d') DESC
# ) AS t;



# DROP TEMPORARY TABLE IF EXISTS tmp_matches;
# CREATE TEMPORARY TABLE tmp_matches ENGINE=InnoDB AS
# SELECT
#   d.deedID,
#   CAST(STR_TO_DATE(asale.SaleDate, '%Y%m%d') AS DATETIME) AS saleDt,
#   CASE WHEN asale.DWCONFSAL = 'Y' THEN 1 ELSE 0 END AS confidentialSale,
#   asale.DWPRICE AS salePrice,
#   COALESCE(TRIM(asale.SalesSource), '') AS sourceOfSale,
#   CASE WHEN asale.DWMULTACC = 'Y' THEN 1 ELSE 0 END AS multiProperty,
#   TRIM(asale.DWSELLER1) AS sellerLine,
#   TRIM(asale.DWBUYER1)  AS buyerLine,
#   TRIM(LOWER(asale.DWSELLER1)) AS sellerNorm,
#   TRIM(LOWER(asale.DWBUYER1))  AS buyerNorm
# FROM conversionDB.AppraisalSale AS asale
# JOIN (
#   -- representative deed rows keyed by normalized seller/buyer and date
#   SELECT
#     MIN(deedID) AS deedID,
#     volume,
#     page,
#     CAST(DATE(deedDt) AS DATETIME) AS deedDtTrunc,
#     TRIM(LOWER(sellerLine)) AS sellerNorm,
#     TRIM(LOWER(buyerLine))  AS buyerNorm
#   FROM deeds
#   GROUP BY volume, page, CAST(DATE(deedDt) AS DATETIME),
#            TRIM(LOWER(sellerLine)), TRIM(LOWER(buyerLine))
# ) d
#   ON d.volume      = asale.DWVOLUME
#  AND d.page        = asale.RecordingPage
#  AND d.deedDtTrunc = CAST(STR_TO_DATE(asale.DeedDate, '%Y%m%d') AS DATETIME)
#  AND d.sellerNorm  = TRIM(LOWER(asale.DWSELLER1))
#  AND d.buyerNorm   = TRIM(LOWER(asale.DWBUYER1))
# ;  -- tmp_matches now contains all source matches
#
# -- add indexes for the next step
# ALTER TABLE tmp_matches ADD INDEX idx_match_keys (deedID, saleDt, sellerNorm, buyerNorm, salePrice);
#
# -- 2) deduplicate: one row per deedID+saleDt+sellerNorm+buyerNorm
# DROP TEMPORARY TABLE IF EXISTS tmp_best;
# CREATE TEMPORARY TABLE tmp_best ENGINE=InnoDB AS
# SELECT
#   deedID,
#   saleDt,
#   -- pick the highest price as the representative value
#   MAX(salePrice) AS salePrice,
#   -- pick an arbitrary but stable value for the other columns
#   ANY_VALUE(sourceOfSale)     AS sourceOfSale,
#   ANY_VALUE(confidentialSale) AS confidentialSale,
#   ANY_VALUE(multiProperty)    AS multiProperty,
#   ANY_VALUE(sellerLine)       AS sellerLine,
#   ANY_VALUE(buyerLine)        AS buyerLine,
#   sellerNorm,
#   buyerNorm
# FROM tmp_matches
# GROUP BY deedID, saleDt, sellerNorm, buyerNorm
# ;
#
# ALTER TABLE tmp_best ADD INDEX idx_best_keys (deedID, saleDt, sellerNorm, buyerNorm);
#
# -- 3) insert the deduped rows into sales, skipping any that already exist
# INSERT INTO sales (
#   deedID, saleDt, confidentialSale, salePrice, sourceOfSale, multiProperty,
#   sellerLine, buyerLine, createdBy, createDt
# )
# SELECT
#   b.deedID,
#   b.saleDt,
#   COALESCE(b.confidentialSale, 0),
#   b.salePrice,
#   b.sourceOfSale,
#   COALESCE(b.multiProperty, 0),
#   b.sellerLine,
#   b.buyerLine,
#   @p_user,
#   NOW()
# FROM tmp_best b
# WHERE NOT EXISTS (
#   SELECT 1 FROM sales s
#   WHERE s.deedID = b.deedID
#     AND s.saleDt = b.saleDt
#     AND TRIM(LOWER(s.sellerLine)) = b.sellerNorm
#     AND TRIM(LOWER(s.buyerLine))  = b.buyerNorm
# );


INSERT INTO salesProperty (
  saleID,
  pID,
  createdBy,
  createDt
)
SELECT
  s.saleID,
  asale.PropertyKey,
  @createdBy,
  @createDt
FROM sales s
JOIN conversionDB.AppraisalSale asale
  ON s.saleDt = CAST(STR_TO_DATE(asale.SaleDate, '%Y%m%d') AS DATETIME)
 AND s.sellerLine = TRIM(asale.DWSELLER1)
 AND s.buyerLine  = TRIM(asale.DWBUYER1);




set @p_user = 'TP Conversion';
update deeds d
set instrumentNum = null
where instrumentNum = 0;