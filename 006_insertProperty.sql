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
p.AuditTaxYear as pYear
,p.PropertyKey as pID
,0
,0
,CASE
    WHEN left(p.PropertyType, 1) ='R' and p.AppraisalType <> 'MHOM' THEN left(p.PropertyType,1)
    WHEN left(p.PropertyType,1) ='R' and p.AppraisalType = 'MHOM' THEN 'MH'
    WHEN left(p.PropertyType,1) IN ('I','P') THEN 'P'
    WHEN left(p.PropertyType,1) ='M' THEN 'MN'
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
from conversionDB.Property p
# join pidMap pm
#     on pm.PropertyKey = p.PropertyKey
join conversionDB.AppraisalAccount aa
    on aa.PropertyKey = p.PropertyKey
        and aa.TaxYear = p.AuditTaxYear
        and aa.JurisdictionType = 'CAD'
left join conversionDB.AcctXREF axref
    on axref.AuditTaxYear = aa.TaxYear
           and axref.AcctXRefType = 'ACCT'
           and axref.PropertyKey = aa.PropertyKey
left join conversionDB.Account a
    on aa.TaxYear = a.AuditTaxYear
           and aa.PropertyKey = a.PropertyKey
where p.AuditTaxYear between @pYearMin and @pYearMax;


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
CASE WHEN MAX(a.LateRenditionPenaltyFlag <> 'N') = 1 THEN 1 ELSE 0 END
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
insert into propertyAccount
(
	pYear,
	pid,
	pVersion,
	pRollCorr,
	ownerID,
	ownerPct,
	createdBy,
	createDt)
select distinct
p.AuditTaxYear
,p.PropertyKey
,0
,0
,aa.OwnerKey
,CASE
    WHEN aa.UndividedIntFrac IS NULL THEN NULL
    WHEN TRIM(aa.UndividedIntFrac) = '' THEN NULL
    WHEN REPLACE(TRIM(aa.UndividedIntFrac), ',', '') REGEXP '^-?[0-9]+([.][0-9]+)?$'
      THEN CAST(REPLACE(TRIM(aa.UndividedIntFrac), ',', '') AS DECIMAL(9,6)) * 100
    ELSE NULL
  END AS ownerPct
,@createdBy
,NOW()
from conversionDB.Property p
join conversionDB.AppraisalAccount aa
    on aa.PropertyKey = p.PropertyKey
        and aa.TaxYear = p.AuditTaxYear
        and aa.OwnerKey IS NOT NULL
where p.AuditTaxYear between @pYearMin and @pYearMax;

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
  aa.ProductivityLossVal             AS suExclusionValue,
  COALESCE(aa.OtherNewPersonalVal, 0) + COALESCE(aa.HomesitePersonalVal, 0) AS bppNewValue,
  COALESCE(aa.HomesiteNewLandVal,0) + COALESCE(aa.HomesiteNewTaxableLandVal,0)         AS newLandValue,
  COALESCE(aa.HomesiteNewImprovementVal,0) + COALESCE(aa.OthNewTaxableImprovementVal,0) AS improvementNewValue,
  aa.OthNewTaxableLandVal            AS landNewNHSValue,
  aa.OtherNewImprovementVal          AS improvementNHSValue,
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

