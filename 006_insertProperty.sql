# create table bowie_appraisal.pidMap
# select distinct PropertyKey, right(PropertyKey,7) as pid from conversionDB.Property;
#
# alter table bowie_appraisal.pidMap add index (PropertyKey), add index(pid);
# alter table bowie_appraisal.pidMap force;

set @pYearMin = 2020;
set @pYearMax = 2025;

set @createdBy = 'TPConversion - insertProperty';
set @createDt = now();
set @p_user = 'TP Conversion';

# create table pidMap
# select distinct PropertyKey, right(PropertyKey,7) as pid from conversionDB.Property;
#
# alter table pidMap add index (PropertyKey), add index(pid);
# alter table pidMap force;


# property
insert into property
(
	pYear,
	pid,
	pRollCorr,
    pVersion,
	propType,
# 	massCreatedFrom,
# 	templateProperty,
# 	templateDesc,
# 	mortgageCoID,
# 	mortgageCoAcctID,
# 	inactiveDt,
# 	inactive,
	#propCreateDt,
    lateRenditionPenaltyStatus,
	createdBy,
	createDt,
# 	exemptionReset,
# 	exemptionResetReason,
    taxDeferralStartDt,
 	underappeal,
    inactive
    )
 select DISTINCT
aa.TaxYear as pYear
,aa.PropertyKey as pID
,0
,0
,CASE
    WHEN LEFT(aa.PropType, 1) = 'R'
         AND COALESCE(aa.PropUsage,'') <> 'M3'
    THEN 'R'

    WHEN LEFT(aa.PropType, 1) = 'R'
         AND aa.PropUsage = 'M3'
    THEN 'MH'

    WHEN LEFT(aa.PropType, 1) IN ('I','P') THEN 'P'
    WHEN LEFT(aa.PropType, 1) = 'M' THEN 'MN'
END AS propertyType
# ,aa.MortgageCoCd
# ,aa.MortgageCoKey
,Case
    when aa.LateRendition = 'N'
        THEN 0
    ELSE 1
        END as lateRenditionPenaltyStatus
,@createdBy
,@createDt
,CASE
    WHEN aa.TaxDeferralDt REGEXP '^[0-9]{8}$'
      THEN DATE_FORMAT(STR_TO_DATE(aa.TaxDeferralDt,'%Y%m%d'), '%Y-%m-%d 00:00:00')
    ELSE NULL
  END                                                   AS taxDeferralStartDt
,CASE WHEN a.ACCSTS = 'PROT' THEN 1 ELSE 0 END         AS underappeal,
 0
from  conversionDB.AppraisalAccount aa
left join conversionDB.AppraisalImprovement ai
    on ai.PropertyKey = aa.PropertyKey
       and ai.TaxYear = aa.TaxYear
left join conversionDB.AcctXREF axref
    on axref.AuditTaxYear = aa.TaxYear
           and axref.AcctXRefType = 'ACCT'
           and axref.PropertyKey = aa.PropertyKey
left join conversionDB.Account a
    on aa.TaxYear = a.AuditTaxYear
           and aa.PropertyKey = a.PropertyKey
where aa.TaxYear between @pYearMin and @pYearMax
 and JurisdictionCd = 'CAD';


insert into propertyCurrent(pid,pYear,pVersion,pRollCorr)
select pid,pYear,pVersion,pRollCorr
from property
where pYear  between @pYearMin and @pYearMax;

# prop profile
insert into propertyProfile(
pid
,pYear
,pVersion
,pRollCorr
,stateCd
,stateCodes
,createdBy
,createDt)
select
p.PropertyKey
,p.AuditTaxYear
,0
,0
,p.StateCd
,p.StateCd
,@createdBy
,@createDt
from conversionDB.Property p
join conversionDB.AppraisalAccount aa
    ON aa.PropertyKey = p.PropertyKey
   and aa.TaxYear     = p.AuditTaxYear
   AND aa.JurisdictionCd = 'CAD'
where p.AuditTaxYear between @pYearMin and @pYearMax;

-- -- check stateCd
-- select p.propType, cp.StateCd ,pp.stateCd, pp.stateCodes
-- from propertyProfile pp
-- join property p using (pID, pYear, pVersion, pRollCorr)
-- join conversionDB.Property cp
--     on cp.PropertyKey = pp.pID
--     and cp.AuditTaxYear = pp.pYear
-- where pp.stateCd = '' or pp.stateCd is null
-- and pp.pYear between @pYearMin and @pYearMax;
--
-- set @p_user = 'TP Conversion - stateCdFix';
-- UPDATE propertyProfile pp
-- JOIN property p USING (pID, pYear, pVersion, pRollCorr)
-- JOIN conversionDB.Property cp
--   ON cp.PropertyKey = pp.pID
--  AND cp.AuditTaxYear = pp.pYear
-- SET
--   pp.stateCd    = cp.StateCd,
--   pp.stateCodes = cp.StateCd,
--   pp.updatedBy = @p_user,
--   pp.updateDt = NOW()
-- WHERE (pp.stateCd IS NULL OR TRIM(pp.stateCd) = '')
--   AND cp.StateCd IS NOT NULL
--   AND TRIM(cp.StateCd) <> ''
--   AND pp.pYear BETWEEN 2020 AND 2025;

# prop char
insert into propertyCharacteristics
(
pyear,
pid,
pVersion,
pRollCorr,
stateCd,
sicCd,
utilities,
zoning,
createDt,
createdBy,
bppLateFilingPenaltyFlag
)
select distinct
p.AuditTaxYear,
p.PropertyKey,
0,
0,
p.stateCd,
MAX(dq.DqBusinessType)         AS sicCd,
MAX(util.ImprovementFeatureCode) AS utilities,   -- util.ImprovementFeatureType='UTIL' already filtered
MAX(zone.LandCharCode)         AS zoning,
NOW(),
@createdBy,
CASE WHEN MAX(a.LateRenditionPenaltyFlag = 'T') = 1 THEN 1 ELSE 0 END
      AS bppLateFilingPenaltyFlag
  from conversionDB.Property p
  join conversionDB.AppraisalAccount aa
    ON aa.PropertyKey = p.PropertyKey
   and aa.TaxYear     = p.AuditTaxYear
   AND aa.JurisdictionCd = 'CAD'
  left join conversionDB.Account a
    ON a.AuditTaxYear = aa.TaxYear
   and a.PropertyKey  = aa.PropertyKey
  left join conversionDB.DQ_Personal dq
    ON dq.AuditTaxYear = p.AuditTaxYear
   and dq.PropertyKey  = p.PropertyKey
  left join conversionDB.AppraisalImprovementFeature util
    ON util.TaxYear = p.AuditTaxYear
   and util.PropertyKey = p.PropertyKey
   and util.ImprovementFeatureType = 'UTIL'
  left join conversionDB.AppraisalLandCharacteristic zone
    ON zone.TaxYear = p.AuditTaxYear
   and zone.PropertyKey = p.PropertyKey
   and zone.LandCharType = 'ZONE'
where p.AuditTaxYear between @pYearMin and @pYearMax
GROUP BY
  p.AuditTaxYear, p.PropertyKey, p.stateCd;


# prop account
INSERT INTO propertyAccount
(
    pYear,
    pID,
    pVersion,
    pRollCorr,
    ownerID,
    ownerPct,

    ownerNetAppraisedValue,
    ownerMarketValue,
    ownerAppraisedValue,
    ownerImprovementValue,
    ownerLandValue,
    ownerImprovementNHSValue,
    ownerAgValue,
    ownerAgExclusionValue,
    ownerLandHSValue,
    ownerLandNHSValue,
    ownerImprovementHSValue,
    ownerNewValue,
    ownerTimberValue,
    ownerTimberLandMktValue,
    ownerAgLandMktValue,
    ownerNewBppValue,

    createdBy,
    createDt,
    updatedBy,
    updateDt
)
SELECT DISTINCT
    p.AuditTaxYear                      AS pYear,
    p.PropertyKey                       AS pID,
    0                                   AS pVersion,
    0                                   AS pRollCorr,
    aa.OwnerKey                         AS ownerID,
    CASE
        WHEN NULLIF(TRIM(aa.UndividedIntFrac), '') IS NULL THEN NULL
        WHEN REPLACE(TRIM(aa.UndividedIntFrac), ',', '') REGEXP '^-?[0-9]+([.][0-9]+)?$'
            THEN CAST(REPLACE(TRIM(aa.UndividedIntFrac), ',', '') AS DECIMAL(9,6)) * 100
        ELSE NULL
    END                                 AS ownerPct,
    CASE
        WHEN aa.LimitedAppraisedVal > 0 THEN aa.LimitedAppraisedVal
        ELSE aa.TotalTaxableVal
    END                                 AS ownerNetAppraisedValue,
    aa.TotalMarketVal                   AS ownerMarketValue,
    aa.TotalMarketVal - 
        aa.ProductivityLossVal          AS ownerAppraisedValue,
    aa.TotalImprovementVal              AS ownerImprovementValue,
    aa.TotalLandVal                     AS ownerLandValue,
    aa.OtherImprovementVal              AS ownerImprovementNHSValue,
    aa.AgLandProdVal                    AS ownerAgValue,
    COALESCE(aa.AgLandMarketVal, 0)
        - COALESCE(aa.AgLandProdVal, 0)  AS ownerAgExclusionValue,
    aa.HomesiteLandVal                  AS ownerLandHSValue,
      COALESCE(aa.OtherLandVal,0) + COALESCE(aa.UnqualAgTimberLandVal,0) AS ownerLandNHSValue,
    aa.HomesiteImprovementVal           AS ownerImprovementHSValue,
    aa.TotalNewTaxableVal               AS ownerNewValue,
    aa.TimberLandProdVal                AS ownerTimberValue,
    aa.TimberLandMarketVal              AS ownerTimberLandMktValue,
    aa.AgLandMarketVal                  AS ownerAgLandMktValue,
    COALESCE(aa.OtherNewPersonalVal, 0)
        + COALESCE(aa.HomesitePersonalVal, 0)
                                        AS ownerNewBppValue,

    @createdBy                          AS createdBy,
    NOW()                               AS createDt,
    @createdBy                          AS updatedBy,
    NOW()                               AS updateDt
FROM conversionDB.Property p
JOIN conversionDB.AppraisalAccount aa
    ON aa.PropertyKey = p.PropertyKey
   AND aa.TaxYear      = p.AuditTaxYear
   AND aa.OwnerKey IS NOT NULL
WHERE p.AuditTaxYear BETWEEN @pYearMin AND @pYearMax;




-- Chris: This isn't the "right" way to do this, but I was writing an update for inplace data, not wanting to disrupt things down stream.  This will work, for now, but really, the update below should be the basis for the propertyAccount insert above.
-- There are still CB concerns with the following update.  https://trueprodigyteam.slack.com/archives/C097WHAJ4TE/p1769526132382179?thread_ts=1769463429.763769&cid=C097WHAJ4TE

drop temporary table if exists newPropertyAccount;
create temporary table newPropertyAccount as
select
p.pYear,
    p.pID,
    p.pVersion,
    p.pRollCorr,
    p.propType,

 row_number() over (partition by pYear, pID, pVersion, pRollCorr, ownerID order by ownerPct desc) - 1 as ownerSequence,
    aa.*,

    @createdBy                          AS createdBy,
    NOW()                               AS createDt
from property p
join lateral (
  select
         aa.OwnerKey as ownerID,
         if(p.propType = 'MN', 100, undividedIntFrac * 100) as ownerPct,


         aa.TotalLandVal as ownerLandValue,
         aa.HomesiteLandVal as ownerLandHSValue,
         aa.OtherLandVal + aa.UnqualAgTimberLandVal as ownerLandNHSValue,
         (aa.agLandMarketVal + aa.TimberLandMarketVal + aa.RestrictedUseTimberMarketVal) as ownerSULandMktValue,
         aa.AgLandProdVal + TimberLandProdVal + RestrictedUseTimberProdVal as ownerSUValue,

  aa.TotalImprovementVal as ownerImprovementValue,
  aa.HomesiteImprovementVal as ownerImprovementHSValue,
  aa.OtherImprovementVal ownerImprovementNHSValue,


  aa.TotalMarketVal as ownerMarketValue,
  aa.TotalMarketVal - aa.ProductivityLossVal as ownerAppraisedValue,


    if(aa.LimitedAppraisedVal > 0, aa.TotalMarketVal - aa.limitedAppraisedVal, 0) as ownerTaxLimitationValue,

    aa.TotalAppraisedVal as ownerNetAppraisedValue,


    ifnull(limitationLastYearHSValue,0) as limitationLastYearHSValue,
    ifnull(limitationLastYearHSValue,0) * .1 as limitationAllowedIncrease,
    ifnull(limitationLastYearHSValue,0) + (ifnull(limitationLastYearHSValue,0) * .1) as limitationMaxAllowedIncrease,


    /*
  limitationBaseYear,
limitationBaseYearOverride,
limitationBaseYearOverrideReason,
limitationBaseYearDate,
limitationLastYearHSValueOverride,
limitationLastYearHSValueOverrideReason,
limitationNewValue,
limitationNewValueOverride,
limitationNewValueOverrideReason,*/



    HomesiteNewLandVal + OtherNewLandVal +HomesiteNewImprovementVal + OtherNewImprovementVal +HomesiteNewPersonalVal +OtherNewPersonalVal as ownerNewValue,

    HomesiteNewPersonalVal +OtherNewPersonalVal as ownerNewBppValue,

   (HomesiteNewImprovementVal + OtherNewImprovementVal) as ownerNewImprovementValue,
   HomesiteNewImprovementVal as ownerNewImprovementHSValue,
OtherNewImprovementVal as ownerNewImprovementNHSValue,
(HomesiteNewLandVal + OtherNewLandVal) as ownerNewLandValue,
HomesiteNewLandVal as ownerNewLandHSValue,
OtherNewLandVal as ownerNewLandNHSValue,

   ifnull(aa.HomesiteLandVal,0) / (ifnull(aa.HomesiteLandVal,0) + ifnull(aa.HomesiteImprovementVal,0)) as ownerHSLandPct,
   ifnull(aa.HomesiteImprovementVal,0) / (ifnull(aa.HomesiteLandVal,0) + ifnull(aa.HomesiteImprovementVal,0)) as ownerHSImprovementPct,

#applyPctExemptions,
#hsGroupPct,
#hsGroupPctBeforeCap,
#hsGroupValue,
#hsGroupValueBeforeCap,

null as taxOfficeRefID,
null as taxOfficeRefID1,
# null as taxOfficeUniqueID, -- This is a calculated field



#createdBy,
#createDt,
#updatedBy,
#updateDt,


aa.cID as fromPAccountID,

#ownerOmittedImprovementHSValue,
#ownerOmittedImprovementNHSValue,
#reestablishLimitationBase,
#useCustomStartYearCompressCalc,
#startYearCompressCalc,

  aa.TimberLandMarketVal as ownerTimberLandMktValue,
  aa.TimberLandProdVal as ownerTimberValue,
  aa.TimberLandMarketVal - TimberLandProdVal as ownerTimberExclusionValue,

  aa.AgLandMarketVal as ownerAgLandMktValue,
  aa.AgLandProdVal as ownerAgValue,
  aa.AgLandMarketVal - AgLandProdVal as ownerAgExclusionValue,



  aa.RestrictedUseTimberMarketVal as ownerTimber78LandMktValue,
  aa.RestrictedUseTimberProdVal as ownerTimber78Value,
  aa.RestrictedUseTimberMarketVal - RestrictedUseTimberProdVal as ownerTimber78ExclusionValue,

  caps.cbTaxLimitationValue as ownerCBTaxLimitationValue,
  caps.hsTaxLimitationValue as ownerHSTaxLimitationValue


  /*
  cbLimitationLastYearValue,
cbLimitationAllowedIncrease,
cbLimitationMaxAllowedIncrease
*/





#cbLimitationBaseYear,
#cbLimitationBaseYearOverride,
#cbLimitationBaseYearOverrideReason,
#cbLimitationBaseYearDate,





#cbLimitationLastYearValueOverride,
#cbLimitationLastYearValueOverrideReason,

#cbLimitationNewValue,
#cbLimitationNewValueOverride,
#cbLimitationNewValueOverrideReason,

#cbRestablishLimitationBase,
#cbLimitationExcludeFromEvaluation,



#cbLimitationOverride,
#cbLimitationOverrideReason,
#cbLimitationIgnoreQualifyYr,



from conversionDB.AppraisalAccount aa
  join lateral (
  select
    aa.OtherLandVal + aa.UnqualAgTimberLandVal as landNHSValue,
    aa.TotalMarketVal - ProductivityLossVal as appraisedValue,
    aa.AgLandMarketVal - aa.aglandProdVal as agLoss,
    aa.TimberLandMarketVal - aa.timberLandProdVal as timberLoss,
    if(LimitedAppraisedVal > 0, aa.TotalMarketVal - aa.limitedAppraisedVal, 0) as limitationValue,
    LocalGenHomesteadVal + StateGenHomesteadVal +
        LocalOver65Val + StateOver65Val + LocalOver65SurvivingSpouseVal + StateOver65SurvivingSpouseVal +
        LocalDPVal + StateDPVal + LocalDisabledSurvivingSpouseVal + StateDisabledSurvivingSpouseVal +
        DVVal +
        AbsVal +
        FreeportVal +
        GoodsInTransitVal +
        SolarWindVal +
        HistVal +
        Hb1200Val +
        FTZVal +
        Min500Val +
        PollutionControlVal +
        AbatementVal + SpecAbatementVal +
        MiscVal + SpecMiscExemptionVal +
        WaterConVal as legacyExemptionValue,
    aa.TotalAppraisedVal as netAppraisedValue
  ) calcs

  join lateral (
    select
      calcs.limitationValue - HomesiteCapLossVal as cbTaxLimitationValue,
      HomesiteCapLossVal as hsTaxLimitationValue
  ) caps
join lateral (
  select
    case
      when 'CAD' in (JurisdictionType, JurisdictionCd) then 1
      when 'CNTY' in (JurisdictionType) then 2
      else 3
  end as r
  ) r

  left join lateral (
    select
      prev.HomesiteCapVal as limitationLastYearHSValue
    from conversionDB.AppraisalAccount prev
    where prev.PropertyKey = aa.PropertyKey
    and prev.pyear = aa.pyear - 1
    and prev.jurisdictionCd = aa.jurisdictionCd
    limit 1

  ) prev on true

    where aa.PropertyKey = p.pID
   and aa.pyear      = p.pyear
   and aa.OwnerKey is not null
  order by r
  limit 1
  ) aa
#where p.pid = 20
;








#Preview
select npa.*
from newPropertyAccount npa
join propertyAccount pa using (pYear, pID, pVersion, pRollCorr, ownerID)
;

set @p_skipTrigger = 1;

update newPropertyAccount npa
join propertyAccount pa using (pYear, pID, pVersion, pRollCorr, ownerID)
set pa.pYear = npa.pYear,
pa.pID = npa.pID,
pa.pVersion = npa.pVersion,
pa.pRollCorr = npa.pRollCorr,
# pa.propType = npa.propType,
pa.ownerID = npa.ownerID,
pa.ownerPct = npa.ownerPct,
pa.ownerLandValue = npa.ownerLandValue,
pa.ownerLandHSValue = npa.ownerLandHSValue,
pa.ownerLandNHSValue = npa.ownerLandNHSValue,
pa.ownerSULandMktValue = npa.ownerSULandMktValue,
pa.ownerSUValue = npa.ownerSUValue,
pa.ownerImprovementValue = npa.ownerImprovementValue,
pa.ownerImprovementNHSValue = npa.ownerImprovementNHSValue,
pa.ownerImprovementHSValue = npa.ownerImprovementHSValue,
pa.ownerMarketValue = npa.ownerMarketValue,
pa.ownerAppraisedValue = npa.ownerAppraisedValue,
pa.ownerTaxLimitationValue = npa.ownerTaxLimitationValue,
pa.ownerNetAppraisedValue = npa.ownerNetAppraisedValue,
pa.limitationLastYearHSValue = npa.limitationLastYearHSValue,
pa.limitationAllowedIncrease = npa.limitationAllowedIncrease,
pa.limitationMaxAllowedIncrease = npa.limitationMaxAllowedIncrease,
pa.ownerNewValue = npa.ownerNewValue,
pa.ownerNewBppValue = npa.ownerNewBppValue,
pa.ownerNewImprovementValue = npa.ownerNewImprovementValue,
pa.ownerNewImprovementHSValue = npa.ownerNewImprovementHSValue,
pa.ownerNewImprovementNHSValue = npa.ownerNewImprovementNHSValue,
pa.ownerNewLandValue = npa.ownerNewLandValue,
pa.ownerNewLandHSValue = npa.ownerNewLandHSValue,
pa.ownerNewLandNHSValue = npa.ownerNewLandNHSValue,
pa.ownerHSLandPct = npa.ownerHSLandPct,
pa.ownerHSImprovementPct = npa.ownerHSImprovementPct,
pa.taxOfficeRefID = npa.taxOfficeRefID,
pa.taxOfficeRefID1 = npa.taxOfficeRefID1,
# pa.taxOfficeUniqueID = npa.taxOfficeUniqueID,
pa.ownerSequence = npa.ownerSequence,
pa.fromPAccountID = npa.fromPAccountID,
pa.ownerTimberLandMktValue = npa.ownerTimberLandMktValue,
pa.ownerTimberValue = npa.ownerTimberValue,
pa.ownerTimberExclusionValue = npa.ownerTimberExclusionValue,
pa.ownerAgLandMktValue = npa.ownerAgLandMktValue,
pa.ownerAgValue = npa.ownerAgValue,
pa.ownerAgExclusionValue = npa.ownerAgExclusionValue,
pa.ownerTimber78LandMktValue = npa.ownerTimber78LandMktValue,
pa.ownerTimber78Value = npa.ownerTimber78Value,
pa.ownerTimber78ExclusionValue = npa.ownerTimber78ExclusionValue,
pa.ownerCBTaxLimitationValue = npa.ownerCBTaxLimitationValue,
pa.ownerHSTaxLimitationValue = npa.ownerHSTaxLimitationValue,
pa.createdBy = npa.createdBy,
pa.createDt = npa.createDt
where pa.pAccountID > 0;
;









# prop legal description
INSERT INTO propertyLegalDescription
(
  pid,
  pYear,
  pVersion,
  pRollCorr,
  asCode,
  block,
  lot,
  legalDescription,
  legalAcreage,
  createdBy,
  createDt
)
SELECT
  p.PropertyKey                                  AS pid,
  p.AuditTaxYear                                 AS pYear,
  0                                              AS pVersion,
  0                                              AS pRollCorr,
  LEFT(CAST(MAX(axref.AcctXRef) AS CHAR), 5)     AS asCode,
  NULLIF(TRIM(MAX(blk.LegalComponent)), '')      AS block,
  CASE WHEN COUNT(l.lot_token) > 0
       THEN CONCAT('LOT ',
                   GROUP_CONCAT(DISTINCT l.lot_token
                                ORDER BY l.lot_num
                                SEPARATOR ', '))
       ELSE NULL
  END                                            AS lot,

  NULLIF(TRIM(MAX(aa.CompressedLegalDesc)), '')  AS legalDescription,
  MAX(aa.Acreage)                                AS legalAcreage,
  @createdBy                                     AS createdBy,
  NOW()                                          AS createDt

FROM conversionDB.Property p
JOIN conversionDB.AppraisalAccount aa
  ON aa.TaxYear     = p.AuditTaxYear
 AND aa.PropertyKey = p.PropertyKey
 and aa.JurisdictionCd = 'CAD'

LEFT JOIN conversionDB.AcctXREF axref
  ON axref.AuditTaxYear = p.AuditTaxYear
 AND axref.PropertyKey  = p.PropertyKey
 AND axref.AcctXRefType = 'ACCT'

LEFT JOIN conversionDB.PropertyLegalDescriptions blk
  ON blk.AuditTaxYear = p.AuditTaxYear
 AND blk.PropertyKey  = p.PropertyKey
 AND blk.LegalType    = 'BLOCK'

LEFT JOIN (
  SELECT
    y.AuditTaxYear,
    y.PropertyKey,
    y.lot_token,
    CASE
      WHEN SUBSTRING_INDEX(REPLACE(y.lot_token, ',', ''), '-', 1) REGEXP '^[0-9]+$'
        THEN CAST(SUBSTRING_INDEX(REPLACE(y.lot_token, ',', ''), '-', 1) AS UNSIGNED)
      ELSE NULL
    END AS lot_num
  FROM (
    SELECT
      pl.AuditTaxYear,
      pl.PropertyKey,
      /* first token after "LOT " -> e.g. '2', '15', '1-5', '3,' */
      TRIM(SUBSTRING_INDEX(
            TRIM(SUBSTRING(pl.LegalComponent,
                           INSTR(UPPER(pl.LegalComponent), 'LOT ') + 4)),
            ' ', 1)) AS lot_token
    FROM conversionDB.PropertyLegalDescriptions pl
    WHERE INSTR(UPPER(pl.LegalComponent), 'LOT ') > 0
  ) AS y
) AS l
  ON l.AuditTaxYear = p.AuditTaxYear
 AND l.PropertyKey  = p.PropertyKey
WHERE p.AuditTaxYear between @pYearMin and @pYearMax
GROUP BY p.AuditTaxYear, p.PropertyKey;

# prop market value
insert ignore into propertyMarketValue (
	pYear,
	pid,
	pVersion,
	pRollCorr,
    appraisedValue,
    marketValue,
    suValue,
    suLandMktValue,
    renderedValue,
    renderedYear,
    lastAppraisalDt,
    inspectionYr,
    legacyMarketValue,
    legacyNetAppraisedValue,
    improvementNewHSValue,
    improvementHSValue,
    landNewHSValue,
    improvementValue,
    landValue,
    landHSValue,
    landNHSValue,

    suExclusionValue,
    bppNewValue,
    landNewValue,
    improvementNewValue,
    landNewNHSValue,
    improvementNHSValue,
    timberLandMktValue,
    timberValue,
    timberExclusionValue,
    agLandMktValue,
    agValue,
    agExclusionValue,
    newValue,
    createDt,
    createdBy
	)
SELECT
  p.AuditTaxYear AS pYear,
  p.PropertyKey  AS pid,
  0              AS pVersion,
  0              AS pRollCorr,
  aa.TotalAppraisedVal                              AS appraisedValue,
  aa.TotalMarketVal                               AS marketValue,
  COALESCE(aa.TimberLandProdVal,0) + COALESCE(aa.AgLandProdVal,0)         AS suValue,
  COALESCE(aa.TimberLandMarketVal,0) + COALESCE(aa.AgLandMarketVal,0)     AS suLandMktValue,
  pp.renderedValue,
  CASE
    WHEN aa.RenditionRcvdDt REGEXP '^[0-9]{8}$'
      THEN YEAR(STR_TO_DATE(aa.RenditionRcvdDt, '%Y%m%d'))
    ELSE NULL
  END AS renderedYear,

  CASE
    WHEN aa.AppraisalDt REGEXP '^[0-9]{8}$'
      THEN DATE_FORMAT(STR_TO_DATE(aa.AppraisalDt, '%Y%m%d'), '%Y-%m-%d 00:00:00')
    ELSE NULL
  END AS lastAppraisalDt,
    CASE
    WHEN aa.AppraisalDt REGEXP '^[0-9]{8}$'
      THEN YEAR(STR_TO_DATE(aa.AppraisalDt, '%Y%m%d'))
    ELSE NULL
  END AS inspectionYr,
  aa.TotalMarketVal                  AS legacyMarketValue,
  aa.TotalTaxableVal                 AS legacyNetAppraisedValue,
  aa.HomesiteNewImprovementVal       AS improvementNewHSValue,
  aa.HomesiteImprovementVal          AS improvementHSValue,
  aa.HomesiteNewLandVal              AS landNewHSValue,
  aa.TotalImprovementVal             AS improvementValue,
  
  aa.TotalLandVal                    AS landValue,
  aa.HomesiteLandVal                 AS landHSValue,
  COALESCE(aa.OtherLandVal,0) + COALESCE(aa.UnqualAgTimberLandVal,0) AS landNHSValue,

  aa.ProductivityLossVal             AS suExclusionValue,
  COALESCE(aa.OtherNewPersonalVal, 0) + COALESCE(aa.HomesitePersonalVal, 0) AS bppNewValue,
  COALESCE(aa.HomesiteNewLandVal,0) + COALESCE(aa.HomesiteNewTaxableLandVal,0)         AS newLandValue,
  COALESCE(aa.HomesiteNewImprovementVal,0) + COALESCE(aa.OthNewTaxableImprovementVal,0) AS improvementNewValue,
  aa.OthNewTaxableLandVal            AS landNewNHSValue,
  aa.OtherImprovementVal          AS improvementNHSValue,
  aa.TimberLandMarketVal             AS timberLandMktValue,
  aa.TimberLandProdVal               AS timberValue,
  COALESCE(aa.TimberLandMarketVal,0) - COALESCE(aa.TimberLandProdVal,0) AS timberExclusionValue,
  aa.AgLandMarketVal                 AS agLandMktValue,
  aa.AgLandProdVal                   AS agValue,
  COALESCE(aa.AgLandMarketVal,0) - COALESCE(aa.AgLandProdVal,0) AS agExclusionValue,
  aa.TotalNewTaxableVal              AS newValue,
  NOW(),
  @createdBy

FROM conversionDB.Property p
JOIN conversionDB.AppraisalAccount aa
  ON aa.TaxYear     = p.AuditTaxYear
 AND aa.PropertyKey = p.PropertyKey
 AND aa.JurisdictionCd = 'CAD'

LEFT JOIN (
  SELECT
      AuditTaxYear,
      PropertyKey,
      MAX(RenderedValue) AS renderedValue
  FROM conversionDB.PersonalProperty
  GROUP BY AuditTaxYear, PropertyKey
) pp
  ON pp.AuditTaxYear = p.AuditTaxYear
 AND pp.PropertyKey  = p.PropertyKey

WHERE p.AuditTaxYear BETWEEN @pYearMin and @pYearMax;



# situs
insert into situsAddress
(
	pid,
	pYear,
	pVersion,
	pRollCorr,
	primarySitus,
	streetNum,
	streetPrefix,
	streetName,
	streetSuffix,
	#streetSecondary,
	city,
	state,
	zip,
	createdBy,
	createDt)
select distinct
p.PropertyKey
,p.AuditTaxYear
,0
,0
,1
,trim(aa.SitusStNum) as streetNum
,trim(aa.SitusStDir) as streetPrefix
,trim(aa.SitusStName) as streetName
,trim(aa.SitusStType) as streetSuffix
,trim(aa.SitusCity) as city
,trim(aa.SitusState) as state
,trim(aa.SitusPostalCode) as zip
,@createdBy
,NOW()
FROM conversionDB.Property p
JOIN conversionDB.AppraisalAccount aa
  ON aa.TaxYear     = p.AuditTaxYear
 AND aa.PropertyKey = p.PropertyKey
 AND aa.JurisdictionCd = 'CAD'
WHERE p.AuditTaxYear BETWEEN @pYearMin and @pYearMax;

# prop identification
insert into propertyIdentification(
	pid,
	pYear,
	pRollCorr,
	mapID,
    dba,
    geoID,
	createdBy,
    createDt
    )
SELECT
  p.PropertyKey        AS pid,
  p.AuditTaxYear       AS pYear,
  0                    AS pVersion,
  MAX(mi.MapIdCode)    AS mapID,
  aa.Dba,
  axref.AcctXRef,
  @createdBy,
  NOW()
FROM conversionDB.Property p
JOIN conversionDB.AppraisalAccount aa
  ON aa.TaxYear     = p.AuditTaxYear
 AND aa.PropertyKey = p.PropertyKey
 AND aa.JurisdictionType = 'CAD'
JOIN conversionDB.AcctXREF axref
    on axref.AuditTaxYear = p.AuditTaxYear
    and axref.PropertyKey = p.PropertyKey
    and axref.AcctXRefType = 'ACCT'
LEFT JOIN conversionDB.MapIdentification mi
  ON mi.AuditTaxYear = p.AuditTaxYear
 AND mi.PropertyKey  = p.PropertyKey
WHERE p.AuditTaxYear BETWEEN @pYearMin and @pYearMax;

# add remarks from field cards
insert ignore into propertyNotes (
pid,
content,
createdBy,
createDt)
SELECT
  p.PropertyKey,
  n.NoteRemark AS NoteText,
  @createdBy,
  @createDt
FROM conversionDB.Property p
JOIN conversionDB.Note n
  ON n.NotesKey = p.NotesKey
WHERE p.AuditTaxYear = @pYearMax -- need to constrained by most current year
  AND n.NoteRemark IS NOT NULL
  AND TRIM(n.NoteRemark) <> ''

UNION ALL

SELECT
  p.PropertyKey,
  n.NOTRM2 AS NoteText,
   @createdBy,
  @createDt
FROM conversionDB.Property p
JOIN conversionDB.Note n
  ON n.NotesKey = p.NotesKey
WHERE p.AuditTaxYear = @pYearMax -- need to constrained by most current year
  AND n.NOTRM2 IS NOT NULL
  AND TRIM(n.NOTRM2) <> '';


update propertyProfile pp
join conversionDB.AppraisalAccount aa
    on aa.PropertyKey = pp.pID
    and aa.TaxYear = pp.pYear
    and aa.JurisdictionType = 'CITY'
join taxingUnit tu
    on tu.taxingUnitCode = aa.JurisdictionCd
set pp.cityTaxingUnitID = tu.taxingUnitID,
    pp.cityTaxingUnitCode = tu.taxingUnitCode,
    pp.cityTaxingUnitName = tu.taxingUnitName
where pp.pYear between @pYearMin and @pYearMax;


update propertyProfile pp
join conversionDB.AppraisalAccount aa
    on aa.PropertyKey = pp.pID
    and aa.TaxYear = pp.pYear
    and aa.JurisdictionType = 'SCHL'
join taxingUnit tu
    on tu.taxingUnitCode = aa.JurisdictionCd
set pp.schoolTaxingUnitID = tu.taxingUnitID,
    pp.schoolTaxingUnitCode = tu.taxingUnitCode,
    pp.schoolTaxingUnitName = tu.taxingUnitName
where pp.pYear between @pYearMin and @pYearMax;


#insert legacy property appraisers last appraisal
insert ignore into propertyAppraisers
(pid, pYear, pVersion, pRollCorr, appraiserType, appraiser, appraiserReviewDt, createdBy, createDt)
SELECT
p.pid
,p.pYear
,p.pVersion
,pRollCorr
,'Legacy Appraiser'
-- ,SUBSTRING_INDEX(app.AppraiserName, '- ', -1) AS appraiser
,app.AppraiserName
,CASE
    WHEN aa.AppraisalDt REGEXP '^[0-9]{8}$'
      THEN DATE_FORMAT(STR_TO_DATE(aa.AppraisalDt, '%Y%m%d'), '%Y-%m-%d 00:00:00')
    ELSE NULL
  END AS lastAppraisalDt
,@createdBy
,NOW()
from property p
join conversionDB.AppraisalAccount aa
on aa.PropertyKey = p.pid
and aa.TaxYear = p.pYear
and aa.JurisdictionType = 'CAD'
join conversionDB.AppraiserID app
    on app.AuditTaxYear = aa.TaxYear
    and app.AppraiserIdCode = aa.AppraiserId
where p.pYear between @pYearMin and @pYearMax;

