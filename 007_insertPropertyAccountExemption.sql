set @pYearMin = 2020;
set @pYearMax = 2025;

set @createdBy = 'TPConversion - insertPropertyAccountExemptions';
set @createDt = now();
set @p_user = 'TP Conversion';


INSERT IGNORE INTO exemptions (
exemptionCode,
exemptionYr,
exemptionDesc,
externalMapping,
exemptionType,
ptdTotalExemption,
ptdStateCodeIfTotalExemption,
valueType,
applyExemptionTo,
taxLimitation,
exemptionAmount,
exemptionPct,
useMaximumValue,
maximumValue,
additionalAmount,
additionalIfPresent,
absent,
absentDt,
comment,
offersDeferral,
displayWebsite,
createdBy,
createDt,
updateDt,
updatedBy,
segmentCalcRule
)
SELECT
exemptionCode,
exemptionYr + 1,
exemptionDesc,
externalMapping,
exemptionType,
ptdTotalExemption,
ptdStateCodeIfTotalExemption,
valueType,
applyExemptionTo,
taxLimitation,
exemptionAmount,
exemptionPct,
useMaximumValue,
maximumValue,
additionalAmount,
additionalIfPresent,
absent,
absentDt,
comment,
offersDeferral,
displayWebsite,
 @p_user,
NOW(),
null,
null,
segmentCalcRule
FROM exemptions
WHERE exemptionYr = 2025;



CREATE TABLE IF NOT EXISTS exemption_map (
  src_code VARCHAR(20) NOT NULL,
  dst_code VARCHAR(20) NOT NULL,
  PRIMARY KEY (src_code, dst_code)
);

-- Refresh mappings (safe to re-run)
REPLACE INTO exemption_map (src_code, dst_code) VALUES
('XGHS','HS'),
('XO65','OV65'),
('XSPO','OV65S'),
('DV01','DV1'),
('XHDV','DVHS'),
('ABSO','EX-AB'),

-- DV31 → HS, OV65, DPS
('DV31','HS'),
('DV31','OV65'),
('DV31','DPS'),

('DV03','DV2'),
('DV07','DV4'),
('XDIS','DP'),

-- XHSV → DPS (only)
('XHSV','DPS'),

('DV05','DV3'),

-- DV11 → HS, OV65, DV
('DV11','HS'),
('DV11','OV65'),
('DV11','DVHS'),

('DV00','DV0-UD'),
('HIST','HT'),
('DV27','DV4S'),
('DV23','DV2S'),
('POLL','PC'),
('M500','EX366'),
('XDSP','DPS'),
('DV21','DV1S'),

-- DV41 → DVHSS (replaces old XHSV→DVHSS)
('DV41','DVHSS'),

('DV25','DV3S'),
('ABAT','AB'),
('XHSD','DVCHS'),
('XHSF','FRSS'),
('SOLR','SO'),
('GINT','GIT'),
('XHDD','DVCH'),
('HB12','HB12');

-- check to see which exemption is not missing
# SELECT DISTINCT TRIM(m.dst_code) AS missing_code
# FROM conversionDB.Property p
# JOIN conversionDB.AppraisalAccount aa
#   ON aa.TaxYear = p.AuditTaxYear AND aa.PropertyKey = p.PropertyKey
# LEFT JOIN conversionDB.AccountJurisdictionExQualify ex
#   ON ex.AuditTaxYear = aa.TaxYear AND ex.PropertyKey = aa.PropertyKey
# JOIN exemption_map m
#   ON m.src_code = ex.ExemptionCode
# LEFT JOIN exemptions e
#   ON e.exemptionCode = TRIM(m.dst_code)
# WHERE p.AuditTaxYear BETWEEN @pYearMin AND @pYearMax
#   AND aa.JurisdictionCd = 'CAD'
#   AND e.exemptionCode IS NULL;

INSERT INTO propertyAccountExemptions (
  pAccountID,
  pid,
  pYear,
  pVersion,
  pRollCorr,
  createDt,
  createdBy,
  exemptionCode
)
SELECT
  pa.pAccountID,
  p.PropertyKey,
  p.AuditTaxYear,
  0,
  0,
  NOW(),
  @createdBy,
  m.dst_code AS exemptionCode
FROM conversionDB.Property p
JOIN conversionDB.AppraisalAccount aa
  ON aa.TaxYear     = p.AuditTaxYear
 AND aa.PropertyKey = p.PropertyKey
JOIN propertyAccount pa
  ON pa.pid       = p.PropertyKey
 AND pa.pYear     = p.AuditTaxYear
 AND pa.pVersion  = 0
 AND pa.pRollCorr = 0
LEFT JOIN conversionDB.AccountJurisdictionExQualify ex
  ON ex.AuditTaxYear = aa.TaxYear
 AND ex.PropertyKey  = aa.PropertyKey
JOIN exemption_map m
  ON m.src_code = ex.ExemptionCode
WHERE p.AuditTaxYear BETWEEN @pYearMin AND @pYearMax
  AND aa.JurisdictionCd = 'CAD'
  -- avoid dupes already in target table
  AND NOT EXISTS (
      SELECT 1
      FROM propertyAccountExemptions e
      WHERE e.pAccountID   = pa.pAccountID
        AND e.pid          = p.PropertyKey
        AND e.pYear        = p.AuditTaxYear
        AND e.pVersion     = 0
        AND e.pRollCorr    = 0
        AND e.exemptionCode= m.dst_code
  )
GROUP BY
  pa.pAccountID, p.PropertyKey, p.AuditTaxYear, m.dst_code;





UPDATE propertyAccountExemptions AS pae
JOIN conversionDB.AppraisalAccount AS aa
  ON aa.TaxYear     = pae.pYear
 AND aa.PropertyKey = pae.pid
SET
  pae.qualifyYr = CASE
    WHEN aa.GenHSExemptionBegDt REGEXP '^[0-9]{8}$' AND aa.GenHSExemptionBegDt <> 0
      THEN CAST(LEFT(aa.GenHSExemptionBegDt, 4) AS UNSIGNED)
    ELSE NULL
  END,
  pae.expirationDt = CASE
    WHEN aa.GenHomesteadExmEndDt REGEXP '^[0-9]{8}$' AND aa.GenHomesteadExmEndDt <> 0
      THEN STR_TO_DATE(CONCAT(LEFT(aa.GenHomesteadExmEndDt, 4), '-12-31 00:00:00'), '%Y-%m-%d 00:00:00')
    ELSE NULL
  END
WHERE pae.pYear BETWEEN @pYearMin AND @pYearMax
  AND aa.JurisdictionCd = 'CAD'
  AND aa.GenHSExemption = 'Y'
  AND pae.exemptionCode = 'HS';


UPDATE propertyAccountExemptions AS pae
JOIN conversionDB.AppraisalAccount AS aa
  ON aa.TaxYear     = pae.pYear
 AND aa.PropertyKey = pae.pid
SET
  pae.qualifyYr = CASE
    WHEN aa.Ov65ExemptionBegDt REGEXP '^[0-9]{8}$' AND aa.Ov65ExemptionBegDt <> 0
      THEN CAST(LEFT(aa.Ov65ExemptionBegDt, 4) AS UNSIGNED)
    ELSE NULL
  END,
  pae.expirationDt = CASE
    WHEN aa.Over65ExmEndDt REGEXP '^[0-9]{8}$' AND aa.Over65ExmEndDt <> 0
      THEN STR_TO_DATE(CONCAT(LEFT(aa.Over65ExmEndDt, 4), '-12-31 00:00:00'), '%Y-%m-%d 00:00:00')
    ELSE NULL
  END
WHERE pae.pYear BETWEEN @pYearMin AND @pYearMax
  AND aa.JurisdictionCd = 'CAD'
  AND aa.Ov65Exemption = 'Y'
  AND pae.exemptionCode = 'OV65';


UPDATE propertyAccountExemptions AS pae
JOIN conversionDB.AppraisalAccount AS aa
  ON aa.TaxYear     = pae.pYear
 AND aa.PropertyKey = pae.pid
SET
  pae.qualifyYr = CASE
    WHEN aa.DPExemptionBegDt REGEXP '^[0-9]{8}$' AND aa.DPExemptionBegDt <> 0
      THEN CAST(LEFT(aa.DPExemptionBegDt, 4) AS UNSIGNED)
    ELSE NULL
  END,
  pae.expirationDt = CASE
    WHEN aa.DPExemptionEndDt REGEXP '^[0-9]{8}$' AND aa.DPExemptionEndDt <> 0
      THEN STR_TO_DATE(CONCAT(LEFT(aa.DPExemptionEndDt, 4), '-12-31 00:00:00'), '%Y-%m-%d 00:00:00')
    ELSE NULL
  END
WHERE pae.pYear BETWEEN @pYearMin AND @pYearMax
  AND aa.JurisdictionCd = 'CAD'
  AND aa.Ov65Exemption = 'Y'
  AND pae.exemptionCode = 'DPS';


UPDATE propertyAccountExemptions AS pae
JOIN conversionDB.AppraisalAccount AS aa
  ON aa.TaxYear     = pae.pYear
 AND aa.PropertyKey = pae.pid
SET
  pae.qualifyYr = CASE
    WHEN aa.Ov65SSExemptionBegDt REGEXP '^[0-9]{8}$' AND aa.Ov65SSExemptionBegDt <> 0
      THEN CAST(LEFT(aa.Ov65SSExemptionBegDt, 4) AS UNSIGNED)
    ELSE NULL
  END,
  pae.expirationDt = CASE
    WHEN aa.Over65SSDPExemptionEndDt REGEXP '^[0-9]{8}$' AND aa.Over65SSDPExemptionEndDt <> 0
      THEN STR_TO_DATE(CONCAT(LEFT(aa.Over65SSDPExemptionEndDt, 4), '-12-31 00:00:00'), '%Y-%m-%d 00:00:00')
    ELSE NULL
  END
WHERE pae.pYear BETWEEN @pYearMin AND @pYearMax
  AND aa.JurisdictionCd = 'CAD'
  AND aa.Ov65Exemption = 'Y'
  AND pae.exemptionCode = 'OV65S';


UPDATE propertyAccountExemptions AS pae
JOIN conversionDB.AppraisalAccount AS aa
  ON aa.TaxYear     = pae.pYear
 AND aa.PropertyKey = pae.pid
SET
  pae.qualifyYr = CASE
    WHEN aa.DPExemptionBegDt REGEXP '^[0-9]{8}$' AND aa.DPExemptionBegDt <> 0
      THEN CAST(LEFT(aa.DPExemptionBegDt, 4) AS UNSIGNED)
    ELSE NULL
  END,
  pae.expirationDt = CASE
    WHEN aa.DPExemptionEndDt REGEXP '^[0-9]{8}$' AND aa.DPExemptionEndDt <> 0
      THEN STR_TO_DATE(CONCAT(LEFT(aa.DPExemptionEndDt, 4), '-12-31 00:00:00'), '%Y-%m-%d 00:00:00')
    ELSE NULL
  END
WHERE pae.pYear BETWEEN @pYearMin AND @pYearMax
  AND aa.JurisdictionCd = 'CAD'
  AND aa.Ov65Exemption = 'Y'
  AND pae.exemptionCode = 'DP';


UPDATE propertyAccountExemptions AS pae
JOIN conversionDB.AppraisalAccount AS aa
  ON aa.TaxYear     = pae.pYear
 AND aa.PropertyKey = pae.pid
SET
  pae.qualifyYr = CASE
    WHEN aa.DVExemptionBegDt REGEXP '^[0-9]{8}$' AND aa.DVExemptionBegDt <> 0
      THEN CAST(LEFT(aa.DVExemptionBegDt, 4) AS UNSIGNED)
    ELSE NULL
  END,
  pae.expirationDt = CASE
    WHEN aa.DisabledVetExmEndDt REGEXP '^[0-9]{8}$' AND aa.DisabledVetExmEndDt <> 0
      THEN STR_TO_DATE(CONCAT(LEFT(aa.DisabledVetExmEndDt, 4), '-12-31 00:00:00'), '%Y-%m-%d 00:00:00')
    ELSE NULL
  END
WHERE pae.pYear BETWEEN @pYearMin AND @pYearMax
  AND aa.JurisdictionCd = 'CAD'
  AND aa.Ov65Exemption = 'Y'
  AND pae.exemptionCode = 'DP';

UPDATE bowie_appraisal.propertyAccountExemptions AS pae
JOIN conversionDB.AccountJurisdictionExQualify AS ex
  ON ex.AuditTaxYear = pae.pYear
 AND ex.PropertyKey  = pae.pid
JOIN exemption_map AS m
  ON m.src_code = ex.ExemptionCode
 AND m.dst_code = pae.exemptionCode
SET
  pae.qualifyYr = CASE
    WHEN ex.ExQualBeginDate REGEXP '^[0-9]{8}$' AND ex.ExQualBeginDate <> 0
      THEN CAST(LEFT(ex.ExQualBeginDate, 4) AS UNSIGNED)
    ELSE NULL
  END,
  pae.expirationDt = CASE
    WHEN ex.ExQualEndDate REGEXP '^[0-9]{8}$' AND ex.ExQualEndDate <> 0
      THEN STR_TO_DATE(CONCAT(LEFT(ex.ExQualEndDate, 4), '-12-31 00:00:00'), '%Y-%m-%d 00:00:00')
    ELSE NULL
  END
WHERE pae.pYear BETWEEN @pYearMin AND @pYearMax;






