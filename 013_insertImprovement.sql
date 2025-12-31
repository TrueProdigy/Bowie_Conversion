set @createDt = now();
set @createdBy = 'TPConversion - insertImprovement';

set @pYearMin = 2020;
set @pYearMax = 2025;

set @p_user = 'TP Conversion';

set @p_skipTrigger = 0;

-- truncate improvementDetailFeature;
-- delete from improvementDetail;


UPDATE bowie_appraisal.improvementDetail id
JOIN bowie_appraisal.improvement i
    ON id.pYear            = i.pYear
   AND id.pID              = i.pID
   AND id.pImprovementID   = i.pImprovementID
JOIN conversionDB.AppraisalImprovement imp
  ON imp.TaxYear           = i.pYear
 AND imp.PropertyKey       = i.pID
 AND imp.ImprovementSeq    = i.sequence
JOIN conversionDB.Segment iseg
  ON iseg.AuditTaxYear     = i.pYear
 AND iseg.PropertyKey      = i.pID
 AND iseg.ImprovementSeq   = imp.ImprovementSeq
SET
    id.area      = CASE
                     WHEN COALESCE(iseg.CalculatedSize, 0) <= 0 THEN iseg.OverrideSize
                     ELSE iseg.CalculatedSize
                   END,
    id.updatedBy = 'TP Conversion - ImpDetail'
WHERE id.pYear = 2025
  AND id.area <= 0;



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

# delete from improvement i
# where i.createdBy = 'TPConversion - ImprovementAdditive'
# and i.imprvType = 'I';

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
CREATE TABLE IF NOT EXISTS imp_type_map (
  src_code VARCHAR(20) NOT NULL,
  dst_code VARCHAR(20) NOT NULL,
  PRIMARY KEY (src_code, dst_code)
);

-- Refresh mappings (safe to re-run)
REPLACE INTO imp_type_map (src_code, dst_code) VALUES
('A1','R'),
('A2','M'),
('A3','R'),
('A4','R'),
('A5','R'),
('A6','R'),
('A7','R'),
('A8','R'),
('B1','R'),
('B2','R'),
('D2','R'),
('E1','R'),
('E2','M'),
('E3','R'),
('F1','C'),
('F2','C'),
('F3','C'),
('F4','C'),
('M1','M'),
('M2','M'),
('M3','M');


INSERT INTO improvement (
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
  m.dst_code                                AS imprvType,
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
          'PropertyKey',   imp.PropertyKey,
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
JOIN valuationsPropAssoc vpa
  ON vpa.pid       = p.pid
 AND vpa.pYear     = p.pYear
 AND vpa.pRollCorr = p.pRollCorr
 AND vpa.pVersion  = p.pVersion
JOIN valuationsCostApproach vca USING (pValuationID)
JOIN conversionDB.AppraisalAccount aa
  ON aa.TaxYear         = p.pYear
 AND aa.PropertyKey     = p.pid
 AND aa.JurisdictionType = 'CAD'
JOIN conversionDB.AppraisalImprovement imp
  ON imp.TaxYear     = p.pYear
 AND imp.PropertyKey = p.pid
JOIN conversionDB.Improvement i
  ON i.AuditTaxYear  = p.pYear
 AND i.PropertyKey    = p.pid
 AND i.ImprovementSeq = imp.ImprovementSeq
LEFT JOIN conversionDB.ImpClass ic
  ON ic.AuditTaxYear     = p.pYear
 AND ic.ImprovementClass = imp.Class
JOIN imp_type_map m
  ON m.src_code = i.ClientComptrollerCategoryCode
LEFT JOIN conversionDB.PropertyModDetail pmd
  ON pmd.AuditTaxYear = p.pYear
 AND pmd.PMFKey       = i.ImprovementPmfkey
 AND pmd.PMFType      = 'IMPIMP'
 AND pmd.PropertyModFactorType = 'MKTF'
WHERE p.pYear BETWEEN @pYearMin AND @pYearMax;



set @createDt = now();
set @createdBy = 'TPConversion - ImprovementAdditive';

set @pYearMin = 2020;
set @pYearMax = 2025;

set @p_user = 'TP Conversion';

-- had to insert one year at a time for this to work
INSERT INTO improvement (
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
    createdBy,
    createDt
)
SELECT
    p.pYear,
    p.pid,
    p.pVersion,
    p.pRollCorr,
    ap.pCostID,

    (SELECT COALESCE(MAX(ap2.sequence), 0) FROM improvement ap2 WHERE ap2.pID = p.pid AND ap2.pYear = p.pYear AND ap2.sequence = imp.ImprovementSeq) +
       ROW_NUMBER() OVER (ORDER BY ia.PropertyKey) AS sequence,

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

    @createdBy                                                     AS createdBy,
    NOW()                                                          AS createdDate

FROM
    property p
JOIN valuationsPropAssoc vpa
  ON vpa.pid       = p.pid
 AND vpa.pYear     = p.pYear
 AND vpa.pRollCorr = p.pRollCorr
 AND vpa.pVersion  = p.pVersion
JOIN valuationsCostApproach vca USING (pValuationID)
JOIN conversionDB.AppraisalAccount aa
  ON aa.TaxYear         = p.pYear
 AND aa.PropertyKey     = p.pid
 AND aa.JurisdictionType = 'CAD'
JOIN conversionDB.AppraisalImprovement imp
  ON imp.TaxYear     = p.pYear
 AND imp.PropertyKey = p.pid
JOIN conversionDB.Improvement i
  ON i.AuditTaxYear  = p.pYear
 AND i.PropertyKey    = p.pid
 AND i.ImprovementSeq = imp.ImprovementSeq
LEFT JOIN conversionDB.ImpClass ic
  ON ic.AuditTaxYear     = p.pYear
 AND ic.ImprovementClass = imp.Class
JOIN imp_type_map m
  ON m.src_code = i.ClientComptrollerCategoryCode
LEFT JOIN conversionDB.PropertyModDetail pmd
  ON pmd.AuditTaxYear = p.pYear
 AND pmd.PMFKey       = i.ImprovementPmfkey
 AND pmd.PMFType      = 'IMPIMP'
 AND pmd.PropertyModFactorType = 'MKTF'
       join conversionDB.ImprovementAdditive ia
            on ia.AuditTaxYear = p.pYear and ia.PropertyKey = p.pid
            and ia.ImprovementSeq = imp.ImprovementSeq
join improvement ap
    on ap.pYear = p.pYear
    and ap.pID = p.pid
   and ap.sequence = imp.ImprovementSeq
WHERE p.pYear = 2020;


# SET FOREIGN_KEY_CHECKS = 0;
# truncate improvementDetailAdjustments;
# truncate improvementDetailFeature;
# truncate improvementDetail;
#
# SET FOREIGN_KEY_CHECKS = 1;

# UPDATE improvementDetail i
# JOIN bowie_appraisal.codefile c
#     ON c.codeFileYear = i.pYear
#     AND c.codeFileType = 'Property'
#     AND c.codeFileName = 'State Code'
# set i.class = c.codeName
# where i.pYear between 2020 and 2025;

set @createDt = now();
set @createdBy = 'TPConversion - insertImprovement';

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
    s.CalculatedSize as area,
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
WHERE p.pYear = 2020
 AND imp.TaxYear = 2020
  AND i.AuditTaxYear = 2020
  AND seg.TaxYear = 2020
  AND s.AuditTaxYear = 2020;

#
# select *
# from improvementDetail
# where pid = 48681
# and pYear = 2025

set @p_user = 'TP Conversion';
update improvement
set stateCd = SUBSTRING(TRIM(stateCd), 1, 2)
where stateCd is not null;




# Set legacy sketch commands using legacy `Drawing` table -- `AppraisalImprovementSegmentDrawing` looked viable too, but I was already kind of deep into this when I noticed that.  If validation fails, we may need to shift our approach to using that table - especially since we use a related table, `AppraisalImprovementSegment`, to determine the origin point for each polygon.
set @p_skipTrigger = true;
set group_concat_max_len = 10000; -- Some polygons require us to stitch multiple strings together since they exceed the legacy varchar(60) limit.  This ensures that our stitched command doesn't get truncated.

/*
 -- Without this index, this query will probably stall and die.
 create index DetailIdentifier
  on Drawing (AuditTaxYear, PropertyKey, ImprovementSeq, SegSeq);
 */
 
# Preview
select
  p.pYear,
  p.pID,
  p.pVersion,
  p.pRollCorr,
  p.propType,
  i.pImprovementID,
  i.sequence,
  i.imprvType,
  id.pDetailID,
  id.sequence,
  id.imprvDetailType,
#  origin.*,
#  id.legacySketchCommands,
  final.legacySketchCommands
  from property p
    join propertyCurrent
    using (pyear, pid, pversion, prollcorr)
    join valuationsPropAssoc vpa
    using (pyear, pid, pversion, prollcorr)
    join valuations v
    using (pValuationID)
    join valuationsCostApproach vca
    using (pValuationID)
    join improvement i using (pCostID)
    join improvementDetail id using (pImprovementID)
    
    join lateral (
    select
      concat(nullif(regexp_replace(regexp_replace(trim(DWORIGIN), '([UDLR])', ',M$1'), '^,', ''), ''), ',') as origin
      from conversionDB.AppraisalImprovementSegment s
      where
        s.TaxYear = p.pyear
        and s.propertyKey = p.pid
        and s.ImprovementSeq = i.sequence
        and s.DWSEGSEQ = id.sequence
    ) as origin -- This determines if there is an off-set from the (0,0) origin. If there is an offset, this returns the prefix to for the polygon to make sure that it is drawn in the correct place.
    
    join lateral (
    select
      group_concat(ImprovementDrawingString order by DRWSEQ separator '') as originalLegacySketchCommands
      from conversionDB.Drawing d
      where
        d.AuditTaxYear = p.pYear
        and d.PropertyKey = p.pID
        and d.ImprovementSeq = i.sequence
        and d.SegSeq = id.sequence) d -- Drawing.ImprovementDrawingString is a varchar(60) datatype, which is too short for some polygons - so, on more-complicated polygons, commands flow into additional records (indicated by DRWSEQ).  This lateral consolidates those records.
    
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

  
  where
    p.pYear = 2025
    and p.pversion = 0
    and p.pRollCorr = 0
    and p.pid in (33673, 98018)
#    and not id.legacySketchCommands <=> final.legacySketchCommands
;



update
  property p
    join propertyCurrent
    using (pyear, pid, pversion, prollcorr)
    join valuationsPropAssoc vpa
    using (pyear, pid, pversion, prollcorr)
    join valuations v
    using (pValuationID)
    join valuationsCostApproach vca
    using (pValuationID)
    join improvement i using (pCostID)
    join improvementDetail id using (pImprovementID)
    
    join lateral (
    select
      concat(nullif(regexp_replace(regexp_replace(trim(DWORIGIN), '([UDLR])', ',M$1'), '^,', ''), ''), ',') as origin
      from conversionDB.AppraisalImprovementSegment s
      where
        s.TaxYear = p.pyear
        and s.propertyKey = p.pid
        and s.ImprovementSeq = i.sequence
        and s.DWSEGSEQ = id.sequence
    ) as origin -- This determines if there is an off-set from the (0,0) origin. If there is an offset, this returns the prefix to for the polygon to make sure that it is drawn in the correct place.
    
    join lateral (
    select
      group_concat(ImprovementDrawingString order by DRWSEQ separator '') as originalLegacySketchCommands
      from conversionDB.Drawing d
      where
        d.AuditTaxYear = p.pYear
        and d.PropertyKey = p.pID
        and d.ImprovementSeq = i.sequence
        and d.SegSeq = id.sequence) d -- Drawing.ImprovementDrawingString is a varchar(60) datatype, which is too short for some polygons - so, on more-complicated polygons, commands flow into additional records (indicated by DRWSEQ).  This lateral consolidates those records.
    
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

set
  id.legacySketchCommands = final.legacySketchCommands
  
  where
#    p.pYear = 2025 -- This is a heavy update, so it may be necessary to update these commands by year.
    p.pversion = 0
    and p.pRollCorr = 0
#    and p.pid in (33673, 98018)
    and not id.legacySketchCommands <=> final.legacySketchCommands; -- Only update where necessary