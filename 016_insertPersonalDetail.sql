set @createDt = now();
set @createdBy = 'TPConversion - insertPersonalDetail';

set @pYearMin = 2020;
set @pYearMax = 2025;

set @p_user = 'TP Conversion';

# delete from personalSubDetail;
# delete from personalDetailNotes;
# delete from personalDetail;


# insert into personalDetail (
# 	pBusinessPropID,
# 	pYear,
# 	pID,
# 	pVersion,
# 	pRollCorr,
# 	detailType,
# 	valueSource,
# 	detailValue,
#     subDetailValue,
#     useNewValue,
#     exemptFlag,
#     flatValue,
#     legacyValue,
#     indexAdjustmentFactor,
#     allocationPct,
#     calcAdjustmentFactor,
#     depreciationPct,
#     ownerEstimateOfValueAppliedEcon,
#     allocation_usageInCounty,
# 	calculatedValue,
# 	detailDescription,
#     physicalAdj,
#     economicAdj,
# 	stateCd,
#     segmentID,
#     depreciationCategory,
# 	createdBy,
#     createDt)
# SELECT
# vb.pBusinessPropID
# ,p.pYear
# ,p.pid
# ,p.pVersion
# ,p.pRollCorr
# ,'BPP LEGACY' as detailType
# # acquiredYr
# # originalCost
# # ownerEstimateofValue
# # previousYearValue
# , 'F' as valueSource
# # newValue
# , 0 as detailValue
# , 0 as subDetailValue
# , 0 -- useNewValue
# , 0 -- exemptFlag
# , ap.MarketValue as flatValue
# , ap.MarketValue as legacyValue
# , 100.00 as indexAdjustmentFactor
# , 100.00 as allocationPct
# , 100.00 as calcAdjustmentFactor
# , 100.00 as depreciationPct
# , 0 as ownerEstimateOfValueAppliedEcon
# , 0 as allocation_usageInCounty
# , 0.00 as calculatedValue
# # unitPrice
# ,pp.PersonalPropertyDescription as detailDescription
# , 100.00 as physicalAdj
# , 100.00 as economicAdj
# ,pp.ClientComptrollerCategoryCode as stateCd
# ,ap.DWPERSEQ
# ,CASE
#     WHEN pp.PersonalPropertyDescription LIKE 'INVENTORY%' OR pp.PersonalPropertyDescription LIKE '%INVENTORY%'
#     THEN 303
#     WHEN pp.PersonalPropertyDescription LIKE 'SUPPLIES%' OR pp.PersonalPropertyDescription LIKE '%SUPPLIES%'
#     THEN 303
#     WHEN pp.PersonalPropertyDescription LIKE 'VEHICLE%' OR pp.PersonalPropertyDescription LIKE '%VEHICLE%'
#     THEN 299
#     WHEN pp.PersonalPropertyDescription LIKE 'ASSETS%' OR pp.PersonalPropertyDescription LIKE '%ASSETS%'
#     THEN 305
#     END AS depreciationCategory
# ,@createdBy
# ,NOW()
# FROM property p
# JOIN valuationsPropAssoc vpa
#   ON vpa.pid       = p.pid
#  AND vpa.pYear     = p.pYear
#  AND vpa.pRollCorr = p.pRollCorr
#  AND vpa.pVersion  = p.pVersion
# JOIN valuations v
#   USING (pValuationID)
# JOIN valuationsBpp vb
#   USING (pValuationID)
# JOIN conversionDB.AppraisalPersonal ap
#   ON ap.TaxYear     = p.pYear
#  AND ap.PropertyKey = p.pid
# JOIN conversionDB.PersonalProperty pp
#   ON pp.AuditTaxYear = p.pYear
#  AND pp.PropertyKey  = p.pid
#  AND pp.PerPropSeq   = ap.DWPERSEQ
# where p.pYear = @pYearMax;


# ALTER TABLE `conversionDB`.`AssetListValues`
#   ADD INDEX `idx_alv_group_cover` (
#     `AuditTaxYear`, `PropertyKey`, `PerPropSeq`, `ALPSEQ`,
#     `AssetListKeyword`, `NumericValue`
#   );
#
# ALTER TABLE `conversionDB`.`AssetListPersonal`
#   ADD INDEX `idx_alp_join` (
#     `AuditTaxYear`, `PropertyKey`, `PerPropSeq`, `ALPSEQ`, `AssetType`
#   );

# ALTER TABLE `conversionDB`.`AppraisalPersonal`
#   ADD INDEX `idx_ap_join` (`TaxYear`, `PropertyKey`, `DWPERSEQ`);
#
# ALTER TABLE `conversionDB`.`DepreciationSchedule`
#   ADD INDEX `idx_ds_scheduleB` (
#     `AuditTaxYear`, `DepreciationScheduleCode`, `DSCLIF`, `DSCAGE`,
#     `DepreciationFactor`
#   );
#
# ALTER TABLE `conversionDB`.`AssetListValues`
#   ADD INDEX `idx_alv_group_no_keyword` (`AuditTaxYear`, `PropertyKey`, `PerPropSeq`, `ALPSEQ`);
#
# ALTER TABLE `conversionDB`.`PersonalProperty`
#   ADD INDEX `idx_pp_join` (`AuditTaxYear`, `PropertyKey`, `PerPropSeq`);

-- AssetListValues: used for the pivot/group
# ALTER TABLE conversionDB.AssetListValues
#   ADD INDEX idx_alv_group (AuditTaxYear, PropertyKey, PerPropSeq, ALPSEQ, AssetListKeyword);
#
# ANALYZE TABLE conversionDB.AssetListValues;
# ANALYZE TABLE conversionDB.AssetListPersonal;
# ANALYZE TABLE conversionDB.DepreciationSchedule;

DROP TABLE IF EXISTS tmp_pids;
CREATE TABLE tmp_pids (
  pid BIGINT NOT NULL
) ENGINE=MEMORY;
INSERT INTO tmp_pids (pid)
  SELECT DISTINCT pid
  FROM personalDetail
  WHERE pYear = @pYearMax;
ALTER TABLE tmp_pids ADD INDEX (pid);

-- tmp_alvv (pivoted AssetListValues filtered to the pids/year we care about)
DROP TABLE IF EXISTS tmp_alvv;
CREATE TABLE tmp_alvv (
  AuditTaxYear INT NOT NULL,
  PropertyKey BIGINT NOT NULL,
  PerPropSeq INT NOT NULL,
  ALPSEQ INT NOT NULL,
  HISTCOST DECIMAL(18,3) DEFAULT NULL,
  UNITCOST DECIMAL(18,3) DEFAULT NULL,
  YEARACQ INT DEFAULT NULL,
  QUANTITY DECIMAL(18,3) DEFAULT NULL,
  PRIMARY KEY (AuditTaxYear, PropertyKey, PerPropSeq, ALPSEQ)
) ENGINE=InnoDB;

INSERT INTO tmp_alvv (
  AuditTaxYear, PropertyKey, PerPropSeq, ALPSEQ,
  HISTCOST, UNITCOST, YEARACQ, QUANTITY
)
SELECT
  v.AuditTaxYear,
  v.PropertyKey,
  v.PerPropSeq,
  v.ALPSEQ,
  MAX(CASE WHEN v.AssetListKeyword = 'HISTCOST' THEN v.NumericValue END)  AS HISTCOST,
  MAX(CASE WHEN v.AssetListKeyword IN ('UNITCOST','UNITPRICE') THEN v.NumericValue END)  AS UNITCOST,
  MAX(CASE WHEN v.AssetListKeyword = 'YEARACQ' THEN v.NumericValue END) AS YEARACQ,
  MAX(CASE WHEN v.AssetListKeyword IN ('QUANTITY','QTY','UNITS') THEN v.NumericValue END) AS QUANTITY
FROM conversionDB.AssetListValues v
JOIN tmp_pids t ON t.pid = v.PropertyKey
WHERE v.AuditTaxYear = @pYearMax
GROUP BY v.AuditTaxYear, v.PropertyKey, v.PerPropSeq, v.ALPSEQ;

ALTER TABLE tmp_alvv ADD INDEX idx_year_key_seq (AuditTaxYear, PropertyKey, PerPropSeq);
ANALYZE TABLE tmp_alvv;

-- compute max DSCAGE per ALP
-- IMPORTANT: use alv.AuditTaxYear so Age = AuditTaxYear - YEARACQ (matches lateral's p.pYear - YEARACQ)
DROP TABLE IF EXISTS tmp_dsmax;
CREATE TABLE tmp_dsmax (
  AuditTaxYear INT NOT NULL,
  PropertyKey BIGINT NOT NULL,
  PerPropSeq INT NOT NULL,
  ALPSEQ INT NOT NULL,
  maxDSCAGE INT DEFAULT NULL,
  categoryYrLife INT DEFAULT NULL,
  PRIMARY KEY (AuditTaxYear, PropertyKey, PerPropSeq, ALPSEQ)
) ENGINE=InnoDB;

INSERT INTO tmp_dsmax (AuditTaxYear, PropertyKey, PerPropSeq, ALPSEQ, maxDSCAGE, categoryYrLife)
SELECT
  alv.AuditTaxYear,
  alv.PropertyKey,
  alv.PerPropSeq,
  alv.ALPSEQ,
  MAX(d.DSCAGE) AS maxDSCAGE,
  dc.categoryYrLife
FROM tmp_alvv alv
JOIN conversionDB.AssetListPersonal alp2
  ON alp2.AuditTaxYear = alv.AuditTaxYear
 AND alp2.PropertyKey  = alv.PropertyKey
 AND alp2.PerPropSeq   = alv.PerPropSeq
 AND alp2.ALPSEQ       = alv.ALPSEQ
LEFT JOIN personalDepreciationCategory dc
  ON dc.categoryYr = 2025
 AND dc.categoryCode = alp2.AssetType
JOIN conversionDB.DepreciationSchedule d
  ON d.AuditTaxYear = alv.AuditTaxYear
 AND d.DepreciationScheduleCode = 'B'
 AND d.DSCLIF = dc.categoryYrLife
 -- use actual Age computed from ALV.AuditTaxYear (matches lateral using p.pYear)
 AND d.DSCAGE <= GREATEST(alv.AuditTaxYear - COALESCE(alv.YEARACQ, alv.AuditTaxYear), 0)
GROUP BY alv.AuditTaxYear, alv.PropertyKey, alv.PerPropSeq, alv.ALPSEQ, dc.categoryYrLife;

ANALYZE TABLE tmp_dsmax;

-- now get the actual DepreciationFactor -> normalize into depAsRate here (store normalized rate)
DROP TABLE IF EXISTS tmp_dsc;
CREATE TABLE tmp_dsc (
  AuditTaxYear INT NOT NULL,
  PropertyKey BIGINT NOT NULL,
  PerPropSeq INT NOT NULL,
  ALPSEQ INT NOT NULL,
  depAsRate DECIMAL(10,6) DEFAULT NULL,
  PRIMARY KEY (AuditTaxYear, PropertyKey, PerPropSeq, ALPSEQ)
) ENGINE=InnoDB;

INSERT INTO tmp_dsc (AuditTaxYear, PropertyKey, PerPropSeq, ALPSEQ, depAsRate)
SELECT
  dm.AuditTaxYear,
  dm.PropertyKey,
  dm.PerPropSeq,
  dm.ALPSEQ,
  CASE
    WHEN d.DepreciationFactor IS NULL THEN NULL
    WHEN d.DepreciationFactor > 1 THEN d.DepreciationFactor / 100.0
    ELSE d.DepreciationFactor
  END AS depAsRate
FROM tmp_dsmax dm
JOIN conversionDB.DepreciationSchedule d
  ON d.AuditTaxYear = dm.AuditTaxYear
 AND d.DSCLIF = dm.categoryYrLife
 AND d.DSCAGE = dm.maxDSCAGE
 AND d.DepreciationScheduleCode = 'B';

ANALYZE TABLE tmp_dsc;

-- final INSERT that uses tmp_alvv and tmp_dsc and uses dsc.depAsRate (exactly like dsb.depAsRate)
INSERT INTO personalSubDetail(
  pDetailID, depreciationCategory, subDetailDescription, acquiredYr, segmentID,
  economicAdj, physicalAdj, pctGood, depreciationPct, subDetailValue,
  allocationPct, flatValue, valueSource, createDt, createdBy
)
SELECT
  p.pDetailID,
  dc.categoryID AS depreciationCategory,
  alp.AssetDescription,
  CAST(alv.YEARACQ AS DECIMAL(4,0)) AS acquiredYr,
  ap.DWPERSEQ AS segmentID,
  100.00 AS economicAdj,
  100.00 AS physicalAdj,
  100.00 AS pctGood,
  100.00 AS depreciationPct,
  -- per-unit depreciation (rounded to 2 decimals)
  ROUND(
    COALESCE(
      COALESCE(alv.UNITCOST, alv.HISTCOST / NULLIF(alv.QUANTITY,0), alv.HISTCOST, ap.MarketValue, 0)
    ,0)
    *
    COALESCE(dsc.depAsRate, 0.0)
  , 2) AS subDetailValue,
  100.00 AS allocationPct,
  -- flatValue: TOTAL depreciation = per-unit * quantity (rounded to whole)
  ROUND(
    COALESCE(
      COALESCE(alv.UNITCOST, alv.HISTCOST / NULLIF(alv.QUANTITY,0), alv.HISTCOST, ap.MarketValue, 0)
    ,0)
    *
    COALESCE(dsc.depAsRate, 0.0)
    * COALESCE(alv.QUANTITY, 1)
  , 0) AS flatValue,
  'F' AS valueSource,
  NOW() AS createDt,
  @createdBy AS createdBy
FROM tmp_alvv alv
JOIN conversionDB.AssetListPersonal alp
  ON alp.AuditTaxYear = alv.AuditTaxYear
 AND alp.PropertyKey  = alv.PropertyKey
 AND alp.PerPropSeq   = alv.PerPropSeq
 AND alp.ALPSEQ       = alv.ALPSEQ
LEFT JOIN personalDepreciationCategory dc
  ON dc.categoryYr = @pYearMax
 AND dc.categoryCode = alp.AssetType
-- join appraisal personal
JOIN conversionDB.AppraisalPersonal ap
  ON ap.TaxYear = alv.AuditTaxYear
 AND ap.PropertyKey = alv.PropertyKey
 AND ap.DWPERSEQ = alv.PerPropSeq
-- join personalDetail
JOIN personalDetail p
  ON p.pYear = ap.TaxYear
 AND p.pid = ap.PropertyKey
 AND p.segmentID = ap.DWPERSEQ
LEFT JOIN tmp_dsc dsc
  ON dsc.AuditTaxYear = alv.AuditTaxYear
 AND dsc.PropertyKey   = alv.PropertyKey
 AND dsc.PerPropSeq    = alv.PerPropSeq
 AND dsc.ALPSEQ        = alv.ALPSEQ;



UPDATE propertyProfile pc
JOIN property p
  ON p.pYear = pc.pYear
 AND p.pid   = pc.pid
 AND p.propType = 'P'
JOIN (
  SELECT
    pYear,
    pID,
    GROUP_CONCAT(DISTINCT stateCd ORDER BY stateCd SEPARATOR ',') AS stateCodes
  FROM personalDetail
  WHERE stateCd IS NOT NULL
    AND stateCd <> ''
  GROUP BY pYear, pID
) pd ON pd.pYear = pc.pYear
    AND pd.pID   = pc.pid
SET pc.stateCodes = pd.stateCodes
WHERE pc.pYear BETWEEN 2020 AND 2025;

select *
from conversionDB.AppraisalAccount
where TaxYear = 2025
and PropertyKey = 80264;

select pc.pid,
    pc.stateCd,
    pc.bppStateCd,
    pc.stateCodes
from propertyProfile pc
JOIN property p
  ON p.pYear = pc.pYear
 AND p.pid   = pc.pid
 AND p.propType = 'P'
where pc.pYear = 2025;

select *
from property
where pid = 104275



