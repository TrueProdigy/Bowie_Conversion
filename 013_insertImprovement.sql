set @createDt = now();
set @createdBy = 'TPConversion - insertImprovement';

set @pYearMin = 2020;
set @pYearMax = 2025;

set @p_user = 'TP Conversion';

set @p_skipTrigger = 0;

SET FOREIGN_KEY_CHECKS = 0;
truncate improvementDetailAdjustments;
truncate improvementDetailFeature;
truncate improvementDetail;
truncate improvement;
SET FOREIGN_KEY_CHECKS = 1;


# UPDATE bowie_appraisal.improvementDetail id
# JOIN bowie_appraisal.improvement i
#     ON id.pYear            = i.pYear
#    AND id.pID              = i.pID
#    AND id.pImprovementID   = i.pImprovementID
# JOIN conversionDB.AppraisalImprovement imp
#   ON imp.TaxYear           = i.pYear
#  AND imp.PropertyKey       = i.pID
#  AND imp.ImprovementSeq    = i.sequence
# JOIN conversionDB.Segment iseg
#   ON iseg.AuditTaxYear     = i.pYear
#  AND iseg.PropertyKey      = i.pID
#  AND iseg.ImprovementSeq   = imp.ImprovementSeq
# SET
#     id.area      = CASE
#                      WHEN COALESCE(iseg.CalculatedSize, 0) <= 0 THEN iseg.OverrideSize
#                      ELSE iseg.CalculatedSize
#                    END,
#     id.updatedBy = 'TP Conversion - ImpDetail'
# WHERE id.pYear = 2025
#   AND id.area <= 0;



# UPDATE improvement i
# set valueSource = 'F'
# where imprvType = 'I';
# UPDATE improvement i
# JOIN (
#     SELECT
#         pImprovementID,  -- <- replace with your real PK column name
#         ROW_NUMBER() OVER (
#             PARTITION BY pID, pYear
#             ORDER BY sequence  -- or ORDER BY improvementID, or whatever order you want
#         ) AS new_seq
#     FROM improvement
#     WHERE pYear = 2020
# ) x
#   ON x.pImprovementID = i.pImprovementID
# SET i.sequence = x.new_seq
# WHERE  i.pYear = 2020;


# UPDATE bowie_appraisal.improvement i
# JOIN bowie_appraisal.codefile c
#     ON c.codeFileYear = i.pYear
# --     AND c.codeFileType = 'Property'
# --     AND c.codeFileName = 'State Code'
#     AND c.codeName = SUBSTRING(TRIM(i.stateCd), 1, 20)
# SET i.stateCd = c.codeName
# WHERE i.pYear = 2025;

# update bowie_appraisal.improvement i
# join conversionDB.AppraisalImprovement imp
# on i.pYear = imp.TaxYear
# and i.pID = imp.PropertyKey
# and i.sequence = imp.ImprovementSeq
# set i.flatValue = imp.OtherCalcVal + imp.HomesiteCalcVal - imp.OtherAdditives - imp.HomesiteAdditives - imp.OtherExtra - imp.HomesiteExtra
# where i.pYear between 2020 and 2025;


# insert ignore into codefile (
# codeFileYear,
# codeFileType,
# codeFileName,
# codeName,
# codeDescription,
# createdBy,
# createDt)
# select
# CASE
#     WHEN imp.AuditTaxYear REGEXP '^[0-9]{8}$'
#       THEN YEAR(STR_TO_DATE(imp.AuditTaxYear, '%Y%m%d'))
#     ELSE NULL end as codeFileYear
# ,'Property'
# ,'Class'
# ,imp.ImprovementClass
# ,imp.ImprovementDescescription
# ,@createdBy
# ,@createDt
# from conversionDB.ImpClass imp
# where imp.AuditTaxYear between @pYearMin and @pYearMax;


-- improvement type mapping
# CREATE TABLE IF NOT EXISTS imp_type_map (
#   src_code VARCHAR(20) NOT NULL,
#   dst_code VARCHAR(20) NOT NULL,
#   PRIMARY KEY (src_code, dst_code)
# );

-- Refresh mappings (safe to re-run) convert these post-go live
# REPLACE INTO imp_type_map (src_code, dst_code) VALUES
# ('A1','R'),
# ('A2','M'),
# ('A3','R'),
# ('A4','R'),
# ('A5','R'),
# ('A6','R'),
# ('A7','R'),
# ('A8','R'),
# ('B1','R'),
# ('B2','R'),
# ('D2','R'),
# ('E1','R'),
# ('E2','M'),
# ('E3','R'),
# ('F1','C'),
# ('F2','C'),
# ('F3','C'),
# ('F4','C'),
# ('M1','M'),
# ('M2','M'),
# ('M3','M');

##### create indexes for faster inserts
# CREATE INDEX idx_ai_year_prop_seq
# ON conversionDB.AppraisalImprovement (TaxYear, PropertyKey, ImprovementSeq);
# CREATE INDEX idx_imp_year_prop_seq
# ON conversionDB.Improvement (AuditTaxYear, PropertyKey, ImprovementSeq);
# CREATE INDEX idx_aa_year_prop_juris
# ON conversionDB.AppraisalAccount (TaxYear, PropertyKey, JurisdictionType);
# CREATE INDEX idx_ic_year_class
# ON conversionDB.ImpClass (AuditTaxYear, ImprovementClass);
# CREATE INDEX idx_pmd_year_key_types
# ON conversionDB.PropertyModDetail (AuditTaxYear, PMFKey, PMFType, PropertyModFactorType);

##### insert improvement NEED TO DO IT ONE YEAR AT A TIME
DROP TEMPORARY TABLE IF EXISTS tmp_aa;

CREATE TEMPORARY TABLE tmp_aa
ENGINE=InnoDB
AS
SELECT
  CAST(a.TaxYear AS UNSIGNED) AS TaxYear,
  CAST(a.PropertyKey AS UNSIGNED) AS PropertyKeyInt,
  a.HomesiteNewImprovementVal,
  a.OtherNewImprovementVal
FROM conversionDB.AppraisalAccount a
JOIN (
    SELECT
      CAST(TaxYear AS UNSIGNED) AS TaxYear,
      PropertyKey,
      MAX(cID) AS maxCID
    FROM conversionDB.AppraisalAccount
    WHERE TaxYear = @pYearMax
      AND JurisdictionType = 'CAD'
    GROUP BY CAST(TaxYear AS UNSIGNED), PropertyKey
) mx
  ON CAST(a.TaxYear AS UNSIGNED) = mx.TaxYear
 AND a.PropertyKey = mx.PropertyKey
 AND a.cID = mx.maxCID;

ALTER TABLE tmp_aa
  ADD PRIMARY KEY (TaxYear, PropertyKeyInt);


DROP TEMPORARY TABLE IF EXISTS tmp_imp;

CREATE TEMPORARY TABLE tmp_imp
ENGINE=InnoDB
AS
SELECT
  CAST(TaxYear AS UNSIGNED) AS TaxYear,
  CAST(PropertyKey AS UNSIGNED) AS PropertyKeyInt,
  ImprovementSeq,
  PropUse,
  Class,
  YearBuilt,
  DWFACTOR,
  HomesiteCalcVal,
  OtherCalcVal,
  EconDepreFact,
  FunctDepreFact,
  PhyDepreFact,
  MarketValue,
  HomesiteAdjustedValue,
  OtherAdjusted,
  SquareFootage,
  OtherAdditives,
  HomesiteAdditives,
  OtherExtra,
  HomesiteExtra
FROM conversionDB.AppraisalImprovement
WHERE TaxYear = @pYearMax;

ALTER TABLE tmp_imp
  ADD INDEX idx_tmp_imp_join (TaxYear, PropertyKeyInt, ImprovementSeq);


DROP TEMPORARY TABLE IF EXISTS tmp_i;

CREATE TEMPORARY TABLE tmp_i
ENGINE=InnoDB
AS
SELECT
  CAST(AuditTaxYear AS UNSIGNED) AS AuditTaxYear,
  CAST(PropertyKey AS UNSIGNED) AS PropertyKeyInt,
  ImprovementSeq,
  HomesiteFlag,
  OverrideHomesiteImprovementFlag,
  ImprovementEffectiveAge,
  ImprovementCondition,
  ImprovementDescription,
  ImprovementPmfkey
FROM conversionDB.Improvement
WHERE AuditTaxYear = @pYearMax;

ALTER TABLE tmp_i
  ADD INDEX idx_tmp_i_join (AuditTaxYear, PropertyKeyInt, ImprovementSeq);

DROP TEMPORARY TABLE IF EXISTS tmp_ic;

CREATE TEMPORARY TABLE tmp_ic
ENGINE=InnoDB
AS
SELECT
  CAST(AuditTaxYear AS UNSIGNED) AS AuditTaxYear,
  TRIM(ImprovementClass) AS ImprovementClass,
  ImprovementDescescription
FROM conversionDB.ImpClass
WHERE AuditTaxYear = @pYearMax;

ALTER TABLE tmp_ic
  ADD INDEX idx_tmp_ic (AuditTaxYear, ImprovementClass);


INSERT IGNORE INTO improvement (
  pyear,
  pid,
  pVersion,
  pRollCorr,
  pCostID,
  sequence,
  stateCd,
  homesite,
  homesiteOverride,
  class,
  imprvDescription,
  actualYearBuilt,
  effYearBuilt,
  age,
  deprec,
  useImprvDeprec,
  costLocalValue,
  economicAdj,
  functionalAdj,
  physicalAdj,
  pctComplete,
  improvementValue,
  legacyValue,
  temp_pID,
  temp_pYear,
  calcHSValue,
  calcNHSValue,
  newHSValue,
  newNHSValue,
  newValueIndicator,
  newValue,
  adjustedValue,
  valueSource,
  imprvCondition,
  imprvComment,
  imprvType,
  imprvAreaModifier,
  applyImprvAreaModifier,
  imprvModifier,
  legacyJSON,
  flatValue,
  createdBy,
  createDt
)
SELECT
  p.pYear,
  p.pid,
  p.pVersion,
  p.pRollCorr,
  vca.pCostID,
  imp.ImprovementSeq                       AS sequence,
  imp.PropUse                              AS stateCd,
  CASE WHEN i.HomesiteFlag = 'T' THEN 1 ELSE 0 END                     AS homesite,
  CASE WHEN i.OverrideHomesiteImprovementFlag = 'T' THEN 1 ELSE 0 END  AS homesiteOverride,
  imp.Class                                 AS class,
  ic.ImprovementDescescription              AS imprvDescription,
  imp.YearBuilt                             AS actualYearBuilt,
  IF(i.ImprovementEffectiveAge = 0 OR i.ImprovementEffectiveAge IS NULL,
     imp.YearBuilt, i.ImprovementEffectiveAge)                          AS effYearBuilt,
  YEAR(CURDATE()) - YEAR(STR_TO_DATE(imp.YearBuilt, '%Y%m%d'))         AS age,
  imp.DWFACTOR * 100                       AS deprec,
  IF(imp.DWFACTOR <> 1.0000 AND imp.DWFACTOR IS NOT NULL, 1, 0)        AS useImprvDeprec,
  imp.HomesiteCalcVal + imp.OtherCalcVal    AS costLocalValue,
  IF(imp.EconDepreFact   IS NULL, 100, imp.EconDepreFact   * 100)      AS economicAdj,
  IF(imp.FunctDepreFact  IS NULL, 100, imp.FunctDepreFact  * 100)      AS functionalAdj,
  IF(imp.PhyDepreFact    IS NULL, 100, imp.PhyDepreFact    * 100)      AS physicalAdj,
  IF(imp.DWFACTOR        IS NULL, 100, imp.DWFACTOR        * 100)      AS pctComplete,
  imp.MarketValue                           AS improvementValue,
  imp.MarketValue                           AS legacyValue,
  p.pid                                     AS temp_pID,
  p.pYear                                   AS temp_pYear,
  imp.HomesiteCalcVal                       AS calcHSValue,
  imp.OtherCalcVal                          AS calcNHSValue,
  aa.HomesiteNewImprovementVal              AS newHSValue,
  aa.OtherNewImprovementVal                 AS newNHSValue,
  IF(COALESCE(aa.HomesiteNewImprovementVal,0) + COALESCE(aa.OtherNewImprovementVal,0) > 0, 1, 0)
                                            AS newValueIndicator,
  COALESCE(aa.HomesiteNewImprovementVal,0) + COALESCE(aa.OtherNewImprovementVal,0)
                                            AS newValue,
  COALESCE(imp.HomesiteAdjustedValue,0) + COALESCE(imp.OtherAdjusted,0)
                                            AS adjustedValue,
  'F'                                       AS valueSource,
  i.ImprovementCondition                    AS imprvCondition,
  i.ImprovementDescription                  AS imprvComment,
  imp.PropUse                               AS imprvType,
  IF(imp.PhyDepreFact IS NULL, 1.00, imp.PhyDepreFact) AS imprvAreaModifier,
  1 AS applyImprvAreaModifier,
  CAST(
    COALESCE(imp.DWFACTOR,1) *
    COALESCE(imp.EconDepreFact,1) *
    COALESCE(imp.PhyDepreFact,1) *
    COALESCE(imp.FunctDepreFact,1)
    AS DECIMAL(5,2)
  ) AS imprvModifier,
  JSON_OBJECT(
      'improvement', JSON_OBJECT(
          'PropertyKey',   imp.PropertyKeyInt,
          'Tax Year',      imp.TaxYear,
          'Year Built',    imp.YearBuilt,
          'SquareFootage', imp.SquareFootage,
          'Class',         imp.Class,
          'Improvement Sequence', imp.ImprovementSeq,
          'Market Value',  imp.MarketValue
      )
  ) AS legacyJSON,
    imp.OtherCalcVal + imp.HomesiteCalcVal - imp.OtherAdditives - imp.HomesiteAdditives - imp.OtherExtra - imp.HomesiteExtra as flatValue,
  @createdBy,
  NOW()
FROM property p
STRAIGHT_JOIN valuationsPropAssoc vpa
  ON vpa.pid       = p.pid
 AND vpa.pYear     = p.pYear
 AND vpa.pRollCorr = p.pRollCorr
 AND vpa.pVersion  = p.pVersion
STRAIGHT_JOIN valuationsCostApproach vca
  ON vca.pValuationID = vpa.pValuationID
STRAIGHT_JOIN tmp_aa aa
  ON aa.TaxYear = p.pYear
 AND aa.PropertyKeyInt = p.pid
STRAIGHT_JOIN tmp_i i
  ON i.AuditTaxYear = p.pYear
 AND i.PropertyKeyInt = p.pid
STRAIGHT_JOIN tmp_imp imp
  ON imp.TaxYear = p.pYear
 AND imp.PropertyKeyInt = p.pid
 AND imp.ImprovementSeq = i.ImprovementSeq
LEFT JOIN tmp_ic ic
  ON ic.AuditTaxYear = p.pYear
 AND ic.ImprovementClass = TRIM(imp.Class)
# JOIN imp_type_map m
#   ON m.src_code = i.ClientComptrollerCategoryCode
# LEFT JOIN conversionDB.PropertyModDetail pmd
#   ON pmd.AuditTaxYear = p.pYear
#  AND pmd.PMFKey       = i.ImprovementPmfkey
#  AND pmd.PMFType      = 'IMPIMP'
#  AND pmd.PropertyModFactorType = 'MKTF'
WHERE p.pYear = @pYearMax;


##### insert improvement additive (these are converted from "addictive")
set @createDt = now();
set @createdBy = 'TPConversion - ImprovementAdditive';

set @pYearMin = 2020;
set @pYearMax = 2025;

set @p_user = 'TP Conversion';

-- had to insert one year at a time for this to work
DROP TEMPORARY TABLE IF EXISTS tmp_aa;

CREATE TEMPORARY TABLE tmp_aa
ENGINE=InnoDB
AS
SELECT
  CAST(a.TaxYear AS UNSIGNED) AS TaxYear,
  CAST(a.PropertyKey AS UNSIGNED) AS PropertyKeyInt,
  a.HomesiteNewImprovementVal,
  a.OtherNewImprovementVal
FROM conversionDB.AppraisalAccount a
JOIN (
    SELECT
      CAST(TaxYear AS UNSIGNED) AS TaxYear,
      PropertyKey,
      MAX(cID) AS maxCID
    FROM conversionDB.AppraisalAccount
    WHERE TaxYear = @pYearMax
      AND JurisdictionType = 'CAD'
    GROUP BY CAST(TaxYear AS UNSIGNED), PropertyKey
) mx
  ON CAST(a.TaxYear AS UNSIGNED) = mx.TaxYear
 AND a.PropertyKey = mx.PropertyKey
 AND a.cID = mx.maxCID;

ALTER TABLE tmp_aa
  ADD PRIMARY KEY (TaxYear, PropertyKeyInt);


DROP TEMPORARY TABLE IF EXISTS tmp_imp;

CREATE TEMPORARY TABLE tmp_imp
ENGINE=InnoDB
AS
SELECT
  CAST(TaxYear AS UNSIGNED) AS TaxYear,
  CAST(PropertyKey AS UNSIGNED) AS PropertyKeyInt,
  ImprovementSeq,
  PropUse,
  Class,
  YearBuilt,
  DWFACTOR,
  HomesiteCalcVal,
  OtherCalcVal,
  EconDepreFact,
  FunctDepreFact,
  PhyDepreFact,
  MarketValue,
  HomesiteAdjustedValue,
  OtherAdjusted,
  SquareFootage,
  OtherAdditives,
  HomesiteAdditives,
  OtherExtra,
  HomesiteExtra
FROM conversionDB.AppraisalImprovement
WHERE TaxYear = @pYearMax;

ALTER TABLE tmp_imp
  ADD INDEX idx_tmp_imp_join (TaxYear, PropertyKeyInt, ImprovementSeq);


DROP TEMPORARY TABLE IF EXISTS tmp_i;

CREATE TEMPORARY TABLE tmp_i
ENGINE=InnoDB
AS
SELECT
  CAST(AuditTaxYear AS UNSIGNED) AS AuditTaxYear,
  CAST(PropertyKey AS UNSIGNED) AS PropertyKeyInt,
  ImprovementSeq,
  HomesiteFlag,
  OverrideHomesiteImprovementFlag,
  ImprovementEffectiveAge,
  ImprovementCondition,
  ImprovementDescription,
  ImprovementPmfkey
FROM conversionDB.Improvement
WHERE AuditTaxYear = @pYearMax;

ALTER TABLE tmp_i
  ADD INDEX idx_tmp_i_join (AuditTaxYear, PropertyKeyInt, ImprovementSeq);


DROP TEMPORARY TABLE IF EXISTS tmp_ia;

CREATE TEMPORARY TABLE tmp_ia
ENGINE=InnoDB
AS
SELECT
  CAST(AuditTaxYear AS UNSIGNED) AS AuditTaxYear,
  CAST(PropertyKey  AS UNSIGNED) AS PropertyKeyInt,
  ImprovementSeq,
  cID,
  TRIM(ImprovementAdditiveDescription) AS ImprovementAdditiveDescription,
  ImprovementAdditiveValue
FROM conversionDB.ImprovementAdditive
WHERE AuditTaxYear = @pYearMax;

ALTER TABLE tmp_ia
  ADD INDEX idx_tmp_ia_join (AuditTaxYear, PropertyKeyInt, ImprovementSeq);

DROP TEMPORARY TABLE IF EXISTS tmp_ap;

CREATE TEMPORARY TABLE tmp_ap
ENGINE=InnoDB
AS
SELECT
  pYear, pID, pVersion, pRollCorr, pCostID, sequence,
  stateCd, homesite, homesiteOverride, homesitePct,
  units, stories, deprec, deprecGood, costSource,
  imprvModifier, applyImprvAreaModifier, imprvAreaModifier,
  calcAdjustmentFactor, calcAdjustmentPctWoutDeprec, newValueSource
FROM improvement
WHERE pYear = @pYearMax;


ALTER TABLE tmp_ap
  ADD INDEX idx_tmp_ap_join (pYear, pID, sequence),
  ADD INDEX idx_tmp_ap_key  (pYear, pID, pVersion, pRollCorr);

DROP TEMPORARY TABLE IF EXISTS tmp_ap_max;

CREATE TEMPORARY TABLE tmp_ap_max
ENGINE=InnoDB
AS
SELECT
  pYear,
  pID,
  MAX(sequence) AS max_seq
FROM tmp_ap
GROUP BY pYear, pID;

ALTER TABLE tmp_ap_max
  ADD PRIMARY KEY (pYear, pID);

DROP TEMPORARY TABLE IF EXISTS tmp_ic;

CREATE TEMPORARY TABLE tmp_ic
ENGINE=InnoDB
AS
SELECT
  CAST(AuditTaxYear AS UNSIGNED) AS AuditTaxYear,
  TRIM(ImprovementClass)         AS ImprovementClass,
  ImprovementDescescription
FROM conversionDB.ImpClass
WHERE AuditTaxYear = @pYearMax;

ALTER TABLE tmp_ic
  ADD INDEX idx_tmp_ic (AuditTaxYear, ImprovementClass);

INSERT IGNORE INTO improvement (
    pYear,
    pID,
    pVersion,
    pRollCorr,
    pCostID,
    sequence,
    stateCd,
    homesite,
    homesiteOverride,
    homesitePct,
    imprvDescription,
    imprvComment,
    finishoutPct,
    units,
    stories,
    deprec,
    deprecGood,
    economicAdj,
    physicalAdj,
    functionalAdj,
    pctComplete,
    costSource,
    selectedCostValue,
    imprvModifier,
    applyImprvAreaModifier,
    imprvAreaModifier,
    flatValue,
    improvementValue,
    calcAdjustmentFactor,
    calcAdjustmentPctWoutDeprec,
    calcNHSValue,
    sketchStatus,
    newValueSource,
    newValueType,
    imprvType,
    valueSource,
    createdBy,
    createDt
)
SELECT
    p.pYear,
    p.pid,
    p.pVersion,
    p.pRollCorr,
    ap.pCostID,
    apm.max_seq
  + ROW_NUMBER() OVER (
      PARTITION BY p.pYear, p.pid
      ORDER BY ia.PropertyKeyInt, ia.ImprovementSeq, ia.cID
    ) AS sequence,
    ap.stateCd,
    ap.homesite,
    ap.homesiteOverride,
    ap.homesitePct,
    TRIM(ia.ImprovementAdditiveDescription)                        AS imprvDescription,
    TRIM(ia.ImprovementAdditiveDescription)                        AS imprvComment,
    100.00                                                         AS finishoutPct,
    ap.units,
    ap.stories,
    ap.deprec,
    ap.deprecGood,
    100.00                                                         AS economicAdj,
    100.00                                                         AS physicalAdj,
    100.00                                                         AS functionalAdj,
    100.00                                                         AS pctComplete,
    ap.costSource,
    0                                                               AS selectedCostValue,
    ap.imprvModifier,
    ap.applyImprvAreaModifier,
    ap.imprvAreaModifier,
    ia.ImprovementAdditiveValue                                     AS flatValue,
    ia.ImprovementAdditiveValue                                     AS improvementValue,
    ap.calcAdjustmentFactor,
    ap.calcAdjustmentPctWoutDeprec,
    ia.ImprovementAdditiveValue                                     AS calcNHSValue,
    'prodigy'                                                      AS sketchStatus,
    ap.newValueSource,
    'Full'                                                         AS newValueType,
    'I'                                                            AS imprvType,
    'F'                                                            AS valueSource,
    @createdBy                                                     AS createdBy,
    NOW()                                                          AS createdDate
FROM property p
STRAIGHT_JOIN valuationsPropAssoc vpa
  ON vpa.pid       = p.pid
 AND vpa.pYear     = p.pYear
 AND vpa.pRollCorr = p.pRollCorr
 AND vpa.pVersion  = p.pVersion
STRAIGHT_JOIN valuationsCostApproach vca
  ON vca.pValuationID = vpa.pValuationID

STRAIGHT_JOIN tmp_aa aa
  ON aa.TaxYear        = p.pYear
 AND aa.PropertyKeyInt = p.pid

STRAIGHT_JOIN tmp_i i
  ON i.AuditTaxYear    = p.pYear
 AND i.PropertyKeyInt  = p.pid

STRAIGHT_JOIN tmp_imp imp
  ON imp.TaxYear        = p.pYear
 AND imp.PropertyKeyInt = p.pid
 AND imp.ImprovementSeq = i.ImprovementSeq

/* additive rows */
STRAIGHT_JOIN tmp_ia ia
  ON ia.AuditTaxYear    = p.pYear
 AND ia.PropertyKeyInt  = p.pid
 AND ia.ImprovementSeq  = imp.ImprovementSeq

STRAIGHT_JOIN tmp_ap ap
  ON ap.pYear     = p.pYear
 AND ap.pID       = p.pid
 AND ap.sequence  = imp.ImprovementSeq

STRAIGHT_JOIN tmp_ap_max apm
  ON apm.pYear = p.pYear
 AND apm.pID   = p.pid

LEFT JOIN tmp_ic ic
  ON ic.AuditTaxYear      = p.pYear
 AND ic.ImprovementClass  = TRIM(imp.Class)

WHERE p.pYear = @pYearMax;




# UPDATE improvementDetail i
# JOIN bowie_appraisal.codefile c
#     ON c.codeFileYear = i.pYear
#     AND c.codeFileType = 'Property'
#     AND c.codeFileName = 'State Code'
# set i.class = c.codeName
# where i.pYear between 2020 and 2025;

set @createDt = now();
set @createdBy = 'TPConversion - insertImpDetail';

set @pYearMin = 2020;
set @pYearMax = 2025;

set @p_user = 'TP Conversion';



insert into improvementDetail (
    pYear,
    pID,
    pVersion,
    pRollCorr,
    pImprovementID,
    sequence,
    class,
    units,
    imprvDetailType,
    actualYearBuilt,
    effYearBuilt,
    age,
    deprec,
    economicAdj,
    functionalAdj,
    physicalAdj,
    pctComplete,
    area,
    manualArea,
    areaSource,
    flatValue,
    improvementDetailValue,
    replacementCostNew,
    -- calcValueWoutFeatureAmount,
    segmentID,
    imprvCondition,
    improvementDetailComment,
    -- pricingUnitPrice,
    imprvDetailModifier,
    legacyJSON,
    createdBy,
    createDt
)
select
    p.pYear,
    p.pid,
    p.pVersion,
    p.pRollCorr,
    impr.pImprovementID,
    seg.DWSEGSEQ                       AS sequence,
    c.codeName                      AS class,
    impr.units                         AS units,
    SUBSTRING(TRIM(seg.DWSTRCODE), 1,20)                     AS imprvDescription,
    seg.YearBuilt                      AS actualYearBuilt,
    IF(s.SegmentEffectiveAge = 0 OR s.SegmentEffectiveAge IS NULL,
       seg.YearBuilt, s.SegmentEffectiveAge)                          AS effYearBuilt,
    YEAR(CURDATE()) - YEAR(STR_TO_DATE(seg.YearBuilt, '%Y%m%d'))         AS age,
    seg.DWFACTOR * 100                       AS deprec,
    IF(seg.EconDepreFact   IS NULL, 100, seg.EconDepreFact   * 100)      AS economicAdj,
    IF(seg.FunctDepreFact  IS NULL, 100, seg.FunctDepreFact  * 100)      AS functionalAdj,
    IF(seg.PhyDepreFact    IS NULL, 100, seg.PhyDepreFact    * 100)      AS physicalAdj,
    IF(seg.DWFACTOR        IS NULL, 100, seg.DWFACTOR        * 100)      AS pctComplete,
    CASE
                     WHEN COALESCE(s.CalculatedSize, 0) <= 0 THEN s.OverrideSize
                     ELSE s.CalculatedSize
                   END as area,
    seg.SquareFootage as manualArea,
    'M' as areaSource,
    seg.CalculatedValue as flatValue,
    seg.MarketValue                           AS improvementDetailValue,
    seg.DWRCN as replacementCostNew,
    -- seg.CalculatedValue as calcValueWoutFeatureAmount,
    seg.cid as segmentID,
    s.SegmentCondition                        AS imprvCondition,
    s.SegmentDescription                      AS imprvComment,
    -- seg.UnitValue as pricingUnitPrice,
    IF(seg.PhyDepreFact IS NULL, 1.00, seg.PhyDepreFact) AS imprvDetailModifier,
    JSON_OBJECT(
        'improvement segment', JSON_OBJECT(
            'PropertyKey',   imp.PropertyKey,
            'Tax Year',      imp.TaxYear,
            'Year Built',    seg.YearBuilt,
            'SquareFootage', seg.SquareFootage,
            'Class',         imp.Class,
            'Segment Sequence', seg.ImprovementSeq,
            'Market Value',  seg.MarketValue
        )
    ) AS legacyJSON,
    @createdBy,
    NOW()
FROM property p
JOIN valuationsPropAssoc vpa
  ON vpa.pid       = p.pid
 AND vpa.pYear     = p.pYear
 AND vpa.pRollCorr = p.pRollCorr
 AND vpa.pVersion  = p.pVersion
JOIN valuationsCostApproach vca USING (pValuationID)
JOIN conversionDB.AppraisalImprovement imp
USE INDEX (idx_AppraisalImprovement_main)
  ON imp.TaxYear     = p.pYear
 AND imp.PropertyKey = p.pid
JOIN conversionDB.Improvement i
  USE INDEX (idx_Improvement_AuditPropSeq)
  ON i.AuditTaxYear  = p.pYear
 AND i.PropertyKey    = p.pid
 AND i.ImprovementSeq = imp.ImprovementSeq
JOIN conversionDB.AppraisalImprovementSegment seg
USE INDEX (idx_AppraisalImprovementSegment_main)
  ON seg.TaxYear     = p.pYear
 AND seg.PropertyKey = p.pid
 AND seg.ImprovementSeq = imp.ImprovementSeq
JOIN conversionDB.Segment s
USE INDEX (idx_Segment_AuditPropSeg)
  ON s.AuditTaxYear  = p.pYear
 AND s.PropertyKey    = p.pid
 AND s.SegSeq = seg.DWSEGSEQ
JOIN improvement impr
  ON impr.pYear = p.pYear
  AND impr.pID = p.pid
  AND impr.sequence = imp.ImprovementSeq
left join codefile c
    ON c.codeFileYear = p.pYear
    AND c.codeFileType = 'Improvement Detail'
    AND c.codeFileName = 'Type'
    AND c.codeName = SUBSTRING(TRIM(seg.DWSTRCODE), 1,20)
WHERE p.pYear = @pYearMax
 AND imp.TaxYear = @pYearMax
  AND i.AuditTaxYear = @pYearMax
  AND seg.TaxYear = @pYearMax
  AND s.AuditTaxYear = @pYearMax;

# setting stateCd
set @p_user = 'TP Conversion';
update improvement
set stateCd = SUBSTRING(TRIM(stateCd), 1, 2)
where stateCd is not null;




# Set legacy sketch commands using legacy `Drawing` table -- `AppraisalImprovementSegmentDrawing` looked viable too, but I was already kind of deep into this when I noticed that.  If validation fails, we may need to shift our approach to using that table - especially since we use a related table, `AppraisalImprovementSegment`, to determine the origin point for each polygon.
/*
 -- Without this index, this query will probably stall and die.
 create index DetailIdentifier
  on Drawing (AuditTaxYear, PropertyKey, ImprovementSeq, SegSeq);
 */


set group_concat_max_len = 10000; -- Some polygons require us to stitch multiple strings together since they exceed the legacy varchar(60) limit.  This ensures that our stitched command doesn't get truncated.

drop table if exists conversionDB.conversion_sketches;
create table conversionDB.conversion_sketches
with drawing as ( -- Drawing.ImprovementDrawingString is a varchar(60) datatype, which is too short for some polygons - so, on more-complicated polygons, commands flow into additional records (indicated by DRWSEQ).  This lateral consolidates those records.
    select
      AuditTaxYear, PropertyKey, ImprovementSeq, SegSeq,
      group_concat(ImprovementDrawingString order by DRWSEQ separator '') as originalLegacySketchCommands
      from conversionDB.Drawing d
      where
        d.AuditTaxYear between @pYearMin and @pYearMax
#      and AuditTaxYear = 2025 and PropertyKey in (33673, 98018)
      group by AuditTaxYear, PropertyKey, ImprovementSeq, SegSeq)

select
  d.AuditTaxYear as pYear,
  d.PropertyKey as pID,
  0 as pVersion,
  0 as pRollCorr,
  ImprovementSeq as iSequence,
  SegSeq as idSequence,
  final.legacySketchCommands
  from drawing d
join lateral (
           select
      concat(nullif(regexp_replace(regexp_replace(trim(DWORIGIN), '([UDLR])', ',M$1'), '^,', ''), ''), ',') as origin
      from conversionDB.AppraisalImprovementSegment s
  where s.TaxYear = d.AuditTaxYear and s.PropertyKey = d.PropertyKey and s.ImprovementSeq = d.ImprovementSeq
  and s.DWSEGSEQ = d.SegSeq) origin

    join lateral (
    select
      regexp_replace(regexp_replace(d.originalLegacySketchCommands, '([UDLRA]+)(\\d|\\.)', ',$1$2'), '^,', '') as withCommas
    ) commas -- Every vector needs to be separated by a comma.
    
    join lateral (
    select
      regexp_replace(commas.withCommas, 'A([UDLR]\\d*(\\.\\d+)?),([UDLR]\\d*(\\.\\d+)?)', '$1X$3') as legacySketchCommands
    ) diagonals -- 'A' indicates that the next two commands are moving the next point of the polygon.  We have to translate that into our diagonal format: U10XR10 instead of AU10R10
    
    join lateral (
    select
      concat_ws('', origin.origin, diagonals.legacySketchCommands) as legacySketchCommands
    ) as final -- Put it all together
;

create index conversion_sketches_idx on conversionDB.conversion_sketches(pYear, pID, pversion, prollcorr, iSequence, idSequence);
#Preview Commands
select * from  conversionDB.conversion_sketches;

#Preview Updates
select
  pYear,
  pID,
  pVersion,
  pRollCorr,
  pImprovementID,
  pDetailID,
  id.legacySketchCommands,
  s.legacySketchCommands
from improvement i
join improvementDetail id using (pYear, pID, pVersion, pRollCorr, pImprovementID)
join lateral (
  select legacySketchCommands
    from conversionDB.conversion_sketches s
          where
            s.pYear = i.pyear
  and s.pid = i.pID
          and s.pVersion = i.pversion
  and s.pRollCorr = i.pRollCorr
  and s.iSequence = i.sequence
  and s.idSequence = id.sequence) s
where not s.legacySketchCommands <=> id.legacySketchCommands;

set @pYearMin = 2020;
set @pYearMax = 2025;
set @p_user = 'TP Conversion - insertSketches';
set @p_skipTrigger = true;

update improvement i
join improvementDetail id using (pYear, pID, pVersion, pRollCorr, pImprovementID)
join lateral (
  select legacySketchCommands
    from conversionDB.conversion_sketches s
          where
            s.pYear = i.pyear
  and s.pid = i.pID
          and s.pVersion = i.pversion
  and s.pRollCorr = i.pRollCorr
  and s.iSequence = i.sequence
  and s.idSequence = id.sequence) s
set   id.legacySketchCommands = s.legacySketchCommands
where not s.legacySketchCommands <=> id.legacySketchCommands;