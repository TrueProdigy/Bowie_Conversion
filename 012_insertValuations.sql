set @createDt = now();
set @createdBy = 'TPConversion - insertValuations';

set @p_user = 'TP Conversion';


# set sql_safe_updates = 0;
# delete from valuations;
# set sql_safe_updates = 1;



set @pYearMin = 2020;
set @pYearMax = 2025;

# cost local real properties
insert into valuations (
	temp_pYear,
	temp_pid,
	temp_pVersion,
	temp_pRollCorr,
	valueType,
	isPrimary,
	value,
    structureValue,
	improvementHSValue,
	improvementNHSValue,
    improvementNewHSValue,
	improvementNewNHSValue,
    improvementNewValue,
    newValue,
	landValue,
	landHSValue,
	landNHSValue,
    landNewValue,
    landNewHSValue,
    landNewNHSValue,
    suValue,
    suLandMktValue,
    suExclusionValue,
    flatValueSource,
	createdBy,
	createDt
	)
select
p.pYear as temp_pYear
,p.pid as temp_pid
,p.pVersion as temp_pVersion
,p.pRollCorr as temp_pRollCorr
,'cost-local' as valueType
,false as isPrimary
,aa.TotalMarketVal as value
,aa.TotalImprovementVal as structureValue
,aa.HomesiteImprovementVal as improvementHSValue
,aa.OtherImprovementVal as improvementNHSValue
,aa.HomesiteNewImprovementVal as improvementNewHSValue
,aa.OtherNewImprovementVal as improvementNewNHSValue
,COALESCE(aa.HomesiteNewImprovementVal,0) + COALESCE(aa.OtherNewImprovementVal,0) AS improvementNewValue
,COALESCE(aa.HomesiteNewImprovementVal,0) + COALESCE(aa.OtherNewImprovementVal,0) + COALESCE(aa.HomesiteNewLandVal,0) + COALESCE(aa.OtherNewLandVal,0) as newValue
,aa.TotalLandVal as landValue
,aa.HomesiteLandVal as landHSValue
,(OtherLandVal + UnqualAgTimberLandVal) as landNHSValue
,COALESCE(aa.HomesiteNewLandVal,0) + COALESCE(aa.OtherNewLandVal,0) AS landNewValue
,aa.HomesiteNewLandVal as landNewHSValue
,aa.OtherNewLandVal as landNewNHSValue
,COALESCE(aa.TimberLandProdVal,0) + COALESCE(aa.AgLandProdVal,0)         AS suValue
,(aa.agLandMarketVal + aa.TimberLandMarketVal + aa.RestrictedUseTimberMarketVal)    AS suLandMktValue
,aa.ProductivityLossVal                                                  AS suExclusionValue
,'Legacy' as flatValueSource
,@createdBy
,NOW()
from property p
join conversionDB.AppraisalAccount aa
    on aa.TaxYear = p.pYear
    and aa.PropertyKey = p.pid
    and aa.JurisdictionType = 'CAD'
where p.pYear between @pYearMin and @pYearMax
and p.propType in ('R', 'MH');

# flat values for real properties
insert into valuations (
	temp_pYear,
	temp_pid,
	temp_pVersion,
	temp_pRollCorr,
	valueType,
	isPrimary,
	value,
    structureValue,
	improvementHSValue,
	improvementNHSValue,
    improvementNewHSValue,
	improvementNewNHSValue,
    improvementNewValue,
    newValue,
	landValue,
	landHSValue,
	landNHSValue,
    landNewValue,
    landNewHSValue,
    landNewNHSValue,
    suValue,
    suLandMktValue,
    suExclusionValue,
    flatValueSource,
	createdBy,
	createDt
	)
select distinct
p.pYear as temp_pYear
,p.pid as temp_pid
,p.pVersion as temp_pVersion
,p.pRollCorr as temp_pRollCorr
,'flat' as valueType
,true as isPrimary
,aa.TotalMarketVal as value
,aa.TotalImprovementVal as structureValue
,aa.HomesiteImprovementVal as improvementHSValue
,aa.OtherImprovementVal as improvementNHSValue
,aa.HomesiteNewImprovementVal as improvementNewHSValue
,aa.OtherNewImprovementVal as improvementNewNHSValue
,COALESCE(aa.HomesiteNewImprovementVal,0) + COALESCE(aa.OtherNewImprovementVal,0) AS improvementNewValue
,COALESCE(aa.HomesiteNewImprovementVal,0) + COALESCE(aa.OtherNewImprovementVal,0) + COALESCE(aa.HomesiteNewLandVal,0) + COALESCE(aa.OtherNewLandVal,0) as newValue
,aa.TotalLandVal as landValue
,aa.HomesiteLandVal as landHSValue
,(OtherLandVal + UnqualAgTimberLandVal) as landNHSValue
,COALESCE(aa.HomesiteNewLandVal,0) + COALESCE(aa.OtherNewLandVal,0) AS landNewValue
,aa.HomesiteNewLandVal as landNewHSValue
,aa.OtherNewLandVal as landNewNHSValue
,COALESCE(aa.TimberLandProdVal,0) + COALESCE(aa.AgLandProdVal,0)         AS suValue
,(aa.agLandMarketVal + aa.TimberLandMarketVal + aa.RestrictedUseTimberMarketVal)    AS suLandMktValue
,aa.ProductivityLossVal                                                  AS suExclusionValue
,'Legacy' as flatValueSource
,@createdBy
,NOW()
from property p
join conversionDB.AppraisalAccount aa
    on aa.TaxYear = p.pYear
    and aa.PropertyKey = p.pid
    and aa.JurisdictionType = 'CAD'
where p.pYear between @pYearMin and @pYearMax
and p.propType in ('R', 'MH');

# flat for minerals
insert into valuations (
	temp_pYear,
	temp_pid,
	temp_pVersion,
	temp_pRollCorr,
	valueType,
	isPrimary,
	value,
    structureValue,
	improvementHSValue,
	improvementNHSValue,
    improvementNewHSValue,
	improvementNewNHSValue,
    improvementNewValue,
    newValue,
	landValue,
	landHSValue,
	landNHSValue,
    landNewValue,
    landNewHSValue,
    landNewNHSValue,
    suValue,
    suLandMktValue,
    suExclusionValue,
    flatValueSource,
	createdBy,
	createDt
	)
select
p.pYear as temp_pYear
,p.pid as temp_pid
,p.pVersion as temp_pVersion
,p.pRollCorr as temp_pRollCorr
,'flat' as valueType
,true as isPrimary
,aa.TotalMarketVal as value
,aa.TotalImprovementVal as structureValue
,aa.HomesiteImprovementVal as improvementHSValue
,aa.OtherImprovementVal as improvementNHSValue
,aa.HomesiteNewImprovementVal as improvementNewHSValue
,aa.OtherNewImprovementVal as improvementNewNHSValue
,COALESCE(aa.HomesiteNewImprovementVal,0) + COALESCE(aa.OtherNewImprovementVal,0) AS improvementNewValue
,COALESCE(aa.HomesiteNewImprovementVal,0) + COALESCE(aa.OtherNewImprovementVal,0) + COALESCE(aa.HomesiteNewLandVal,0) + COALESCE(aa.OtherNewLandVal,0) as newValue
,aa.TotalLandVal as landValue
,aa.HomesiteLandVal as landHSValue
,aa.OtherLandVal as landNHSValue
,COALESCE(aa.HomesiteNewLandVal,0) + COALESCE(aa.OtherNewLandVal,0) AS landNewValue
,aa.HomesiteNewLandVal as landNewHSValue
,aa.OtherNewLandVal as landNewNHSValue
,COALESCE(aa.TimberLandProdVal,0) + COALESCE(aa.AgLandProdVal,0)         AS suValue
,COALESCE(aa.TimberLandMarketVal,0) + COALESCE(aa.AgLandMarketVal,0)     AS suLandMktValue
,aa.ProductivityLossVal                                                  AS suExclusionValue
,'Legacy' as flatValueSource
,@createdBy
,NOW()
from property p
join conversionDB.AppraisalAccount aa
    on aa.TaxYear = p.pYear
    and aa.PropertyKey = p.pid
    and aa.JurisdictionType = 'CAD'
where p.pYear between @pYearMin and @pYearMax
and p.propType in ('MN');



# Create vca records
insert into valuationsCostApproach (
	pValuationID,
	createdBy,
	createDt)
select
	pValuationID,
	createdBy,
	createDt
from
	valuations v
where valueType like 'cost-local'
and temp_pYear  between @pYearMin and @pYearMax;


insert into valuationsPropAssoc (
	pYear,
	pID,
	pVersion,
	pRollCorr,
	pValuationID,
	createdBy,
	createDt)
select
	temp_pYear as pYear,
	temp_pid as pID,
	temp_pVersion as pVersion,
	temp_pRollCorr as pRollCorr,
	pValuationID,
	createdBy,
	createDt
from
	valuations v
	where temp_pYear  between @pYearMin and @pYearMax
	and valueType in ('flat', 'cost-local');

insert ignore into codefile (
	codefileYear,
	codefileType,
	codefileName,
	codeName,
	codeDescription,
	createdBy,
	createDt)
select distinct
	0 as codefileYear,
	'Property' as codefileType,
	'Flat Value Source' as codefileName,
	flatValueSource as codeName,
	flatValueSource as codeDescription,
	@createdBy as createdBy,
	@createDt as createDt
from
	valuations
where valueType like 'Flat';



INSERT INTO valuations (
  temp_pYear,
  temp_pid,
  temp_pVersion,
  temp_pRollCorr,
  valueType,
  isPrimary,
  value,
  newValue,
  bppNewValue,
  flatValueSource,
  flatValueReason,
  createdBy,
  createDt
)
SELECT
  p.pYear                          AS temp_pYear,
  p.pid                            AS temp_pid,
  p.pVersion                       AS temp_pVersion,
  p.pRollCorr                      AS temp_pRollCorr,
  'bpp'                            AS valueType,
  0                                AS isPrimary,
  aa.TotalMarketVal                AS value,
  COALESCE(aa.HomesiteNewImprovementVal,0)
    + COALESCE(aa.OtherNewImprovementVal,0)
    + COALESCE(aa.HomesiteNewLandVal,0)
    + COALESCE(aa.OtherNewLandVal,0)              AS newValue,
  COALESCE(aa.HomesiteNewPersonalVal,0)
    + COALESCE(aa.OtherNewPersonalVal,0)          AS bppNewValue,
  'LEGACY'                         AS flatValueSource,
  'Conversion'                     AS flatValueReason,
  @createdBy                       AS createdBy,   -- <-- use the session vars you set
  @createDt                        AS createDt
FROM property p
JOIN conversionDB.AppraisalAccount aa
  ON aa.TaxYear     = p.pYear
 AND aa.PropertyKey = p.pid
 AND aa.JurisdictionCd = 'CAD'                      -- <-- fixed
WHERE p.pYear BETWEEN @pYearMin AND @pYearMax
  AND p.propType = 'P';

set @pYearMin = 2020;
set @pYearMax = 2025;

set @createDt = now();
set @createdBy = 'TPConversion - insertValuations';

set @p_user = 'TP Conversion';

insert into valuationsPropAssoc (
	pYear,
	pID,
	pVersion,
	pRollCorr,
	pValuationID,
	createdBy,
	createDt)
select
	temp_pYear as pYear,
	temp_pid as pID,
	temp_pVersion as pVersion,
	temp_pRollCorr as pRollCorr,
	pValuationID,
	createdBy,
	createDt
from
	valuations v
	where temp_pYear  between @pYearMin and @pYearMax

	and valueType in ('bpp')
	and createdBy = @createdBy
	and not exists (select * from valuationsPropAssoc where pValuationID = v.pValuationID);

set @pYearMin = 2020;
set @pYearMax = 2025;

set @createDt = now();
set @createdBy = 'TPConversion - insertValuations';

set @p_user = 'TP Conversion';

insert into valuationsBpp (

	pValuationID,
	createdBy,
	createDt,
	flatValue,
	detailValue,
	personalValue,
	valueSource,
	valueType
	)
select
	pValuationID,
	createdBy,
	createDt,
	value,
	value,
	value,
	'F',
	'bpp'
from
	valuations v
	where temp_pYear  between @pYearMin and @pYearMax
	and valueType in ('bpp')
	and createdBy = @createdBy
	and not exists (select * from valuationsBpp where pValuationID = v.pValuationID);
;