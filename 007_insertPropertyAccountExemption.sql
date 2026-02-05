set @pYearMin = 2020;
set @pYearMax = 2025;

set @createdBy = 'TPConversion - insertPropertyAccountExemptions';
set @createDt = now();
set @p_user = 'TP Conversion';


alter table finalDB.AccountJurisdictionExQualify
  add pYear int as (cast(AuditTaxYear as unsigned)) stored;
call finalDB.CreateIndex('finalDB', 'AccountJurisdictionExQualify', 'PropertyKey', 'pYear, PropertyKey');


-- List of legacy codes
select distinct
  CCD_Code,
  CCD_Description
  from finalDB.CommonCodeL
  where
    CCD_Type = 'EXEMPT'
  order by
    CCD_Code
;

-- Checking to see if there's any weird stuff going on here.
select
  *
  from finalDB.AccountJurisdictionExQualify
  where
    ClientCd <> 'A019';

select
  JurisdictionCode,
  count(*)
  from finalDB.AccountJurisdictionExQualify
  group by
    JurisdictionCode;



select
  pYear,
  propertyKey,
  exemptionCode,
  count(*),
  group_concat(jurisdictionCode order by jurisdictionCode separator ', ')
  from finalDB.AccountJurisdictionExQualify
  where
    pyear >= 2020
  group by
    pYear, propertyKey, exemptionCode
  having
    count(*) > 1
;



set @p_skipTrigger = true;
-- Won't be able to use these in the Current Year or later, but we've got some user defined DVs to retain in prior years, so we'll need a code for these.
insert into exemptions
  (
  exemptionYr,
  exemptionCode,
  externalMapping,
  createdBy,
  createDt
  )
select
  y.pYear as exemptionYear,
  'DV-UD' as exemptionCode,
  'PTD-DV' as externalMapping,
  'TP - Conversion' as createdBy,
  NOW() as createDt
  from appraisalYr y
  where
    not exists
      (
        select *
          from exemptions e
          where e.exemptionYr = y.pYear and e.exemptionCode = 'DV-UD'
      )
;

set @p_skipTrigger = true;

insert into propertyAccountExemptions
  (
  pAccountID,
  pYear,
  pID,
  pVersion,
  pRollCorr,
  createDt,
  createdBy,
  ExemptionCode,
  qualifyYr,
  grantedDt,
  beginDt,
  expirationDt,
  exemptionComment,
  pctExemption,
  legacyJSON
  )

select
  pAccountID,
  pYear,
  pID,
  pVersion,
  pRollCorr,
  NOW() as createDt,
  'TP - Conversion' as createdBy,
  ExemptionCode,
  qualifyYr,
  grantedDt,
  beginDt,
  expirationDt,
  exemptionComment,
  pctExemption,
  legacyJSON

#definitionCount,
#jurisdictionCount

  from property p
  join propertyAccount pa
    using (pYear, pID, pVersion, pRollCorr)
  join lateral ( select p.pid as propertyKey
    #p.pYear as AuditTaxYear, pa.ownerID as OwnerKey
    ) as deduper
  join lateral (
    select

      case
        when lex.ExemptionCode in ('ABAT')
          then 'AB' /* Abatement */
-- when lex.ExemptionCode in ('CHCF')  then ''	/* Childcare Facility */
        when lex.ExemptionCode in ('DV00')
          then 'DV-UD' /* Explicit Value Disabled Veteran */
        when lex.ExemptionCode in ('DV01')
          then 'DV1' /* 10% - 30% Disability */
        when lex.ExemptionCode in ('DV03')
          then 'DV2' /* 31% - 50% Disability */
        when lex.ExemptionCode in ('DV05')
          then 'DV3' /* 51% - 70% Disability */
        when lex.ExemptionCode in ('DV07')
          then 'DV4' /* 71% and greater Disability */
        when lex.ExemptionCode in ('DV11')
          then 'DV-UD' /* 65 Years of Age/At Least 10% Disability */
-- when lex.ExemptionCode in ('DV12')  then 'DV-UD'	/* Blind in One or Both Eyes */
-- when lex.ExemptionCode in ('DV13')  then 'DV-UD'	/* Loss of the Use of One or More Limbs */
        when lex.ExemptionCode in ('DV21')
          then 'DV1S' /* 10% - 30% Disability/Surviving Spouse */
        when lex.ExemptionCode in ('DV23')
          then 'DV2S' /* 31% - 50% Disability/Surviving Spouse */
        when lex.ExemptionCode in ('DV25')
          then 'DV3S' /* 51% - 70% Disability/Surviving Spouse */
        when lex.ExemptionCode in ('DV27')
          then 'DV4S' /* 71% and greater/Surviving Spouse */
        when lex.ExemptionCode in ('DV31')
          then 'DV-UD' /* 65 Years/At Least 10%/Surviving Spouse */
-- when lex.ExemptionCode in ('DV32')  then 'DV-UD'	/* Blind in One/Both Eyes/Surviving Spouse */
-- when lex.ExemptionCode in ('DV33')  then 'DV-UD'	/* Loss of One/More Limbs/Surviving Spouse */
        when lex.ExemptionCode in ('DV41')
          then 'DVHSS' /* Deceased Veteran Surviving Spouse */
        when lex.ExemptionCode in ('DV42')
          then 'DVHSS' /* Deceased Veteran Surviving Child */
        when lex.ExemptionCode in ('FRPT')
          then 'FR' /* Freeport */
        when lex.ExemptionCode in ('FTZN')
          then 'FTZ' /* Foreign Trade Zone */
        when lex.ExemptionCode in ('GINT')
          then 'GIT' /* Goods in Transit */
-- when lex.ExemptionCode in ('HB12')  then '-'	/* House Bill 1200 */
        when lex.ExemptionCode in ('HIST')
          then 'HT' /* Historical */
-- when lex.ExemptionCode in ('JETI')  then 'JETI'	/* Jobs Energy Technology Innovation */
-- when lex.ExemptionCode in ('M')  then ''	/* M type */
        when lex.ExemptionCode in ('M500')
          then 'EX366' /* Minimum $500 */
-- when lex.ExemptionCode in ('MEDF')  then ''	/* Medical Biomedical Facility */
-- when lex.ExemptionCode in ('MISC')  then ''	/* Miscellaneous */
-- when lex.ExemptionCode in ('P')  then ''	/* P type */
        when lex.ExemptionCode in ('POLL')
          then 'PC' /* TECQ Pollution Control */
        when lex.ExemptionCode in ('SOLR')
          then 'SO' /* Solar / Wind Powered */
-- when lex.ExemptionCode in ('TNRC')  then ''	/* TECQ Pollution Control */
-- when lex.ExemptionCode in ('WATR')  then ''	/* Water Conservation */
        when lex.ExemptionCode in ('XDIS')
          then 'DP' /* Disabled Person */
        when lex.ExemptionCode in ('XDSP')
          then 'DPS' /* Disabled Person Surviving Spouse */
        when lex.ExemptionCode in ('XGHS')
          then 'HS' /* General Homestead */
        when lex.ExemptionCode in ('XHDD')
          then 'DVHS' /* Disabled Veteran Donated Homestead */
        when lex.ExemptionCode in ('XHDV')
          then 'DVHS' /* Disabled Veteran Homestead */
        when lex.ExemptionCode in ('XHSD')
          then 'DVHSS' /* Disabled Vet Donated HS Surviving Spouse */
        when lex.ExemptionCode in ('XHSF')
          then 'FRSS' /* First Responder Surviving Spouse */
-- when lex.ExemptionCode in ('XHSS')  then ''	/* Service Member Surviving Spouse */
        when lex.ExemptionCode in ('XHSV')
          then 'DVHSS' /* Disabled Veteran Surviving Spouse */
        when lex.ExemptionCode in ('XO65')
          then 'OV65' /* Over 65 */
        when lex.ExemptionCode in ('XSPO')
          then 'OV65S' /* Surviving Spouse */
        when ExemptionCode = 'ABSO'
          then
          case ExemptionClass
            when 'XXXXXX'
              then 'Placeholder'
            /*
          when 'A' -- Associations
          then ''

        when 'B' -- Cemetary (Burial Sites)
          then ''

        when 'C' -- County
          then ''

        when 'E' -- Emergency
          then ''

        when 'F' -- Federal
          then ''

        when 'I' -- Institutions
          then ''

        when 'M' -- Municipal (City)
          then ''

        when 'P' -- Personal Property
          then ''

        when 'R' -- Religious Exempt Property
          then ''

        when 'S' -- School Exempt Property
          then ''

        when 'T' -- State Texas
          then ''

        when 'V' -- Personal Property Vehicle
          then ''

        when 'W' -- Water District
          then ''

        when 'X' -- Road
          then ''

        when 'Y' -- Code Y
          then '' */

            else 'EX-XV'
          end -- AB Exemptions
      end as ExemptionCode,

      year(min(str_to_date(nullif(ExemptionApplicationDate, 0), '%Y%m%d'))) as qualifyYr,

      min(str_to_date(nullif(ExQualBeginDate, 0), '%Y%m%d')) as grantedDt,
      min(str_to_date(nullif(ExQualBeginDate, 0), '%Y%m%d')) as beginDt,
      max(str_to_date(nullif(ExQualEndDate, 0), '%Y%m%d')) as expirationDt,

      concat('Legacy Exemption Code: ', lex.ExemptionCode, if(nullif(ExemptionClass, '') is not null, concat('-', exemptionclass), '')) as exemptionComment,

      ifnull(group_concat(if(JurisdictionCode = '$ALL', ExemptionQualifiedPercent * 100, null)), 100) as pctExemption,

      count(*) as definitionCount,
      count(distinct jurisdictionCode) as jurisdictionCount,


      json_object(
        'ClientCd', lex.ClientCd,
        'AuditTaxYear', lex.AuditTaxYear,
        'PropertyKey', lex.PropertyKey,
        'pYear', lex.pyear,
        'ExemptionCode', lex.ExemptionCode,
        'ExemptionClass', lex.ExemptionClass,
        'ExQualBeginDate', lex.ExQualBeginDate,
        'ExQualEndDate', lex.ExQualEndDate,
        'Jurisdictions',
        json_arrayagg(
          json_object(
            'BeginningTs', lex.BeginningTs,
            'EndingTs', lex.EndingTs,
            'UserCd', lex.UserCd,
            'WorkstationCd', lex.WorkstationCd,
            'DeletedFlag', lex.DeletedFlag,
            'AuditCategoryCd', lex.AuditCategoryCd,
            'Account', lex.Account,
            'JurisdictionCode', lex.JurisdictionCode,
            'ExemptionQualifiedValue', lex.ExemptionQualifiedValue,
            'ExemptionQualifiedPercent', lex.ExemptionQualifiedPercent,
            'ExemptionApplicationDate', lex.ExemptionApplicationDate,
            'X_UPID', lex.X_UPID,
            'X_RRNO', lex.X_RRNO,
            'cID', lex.cID)
        )) as legacyJSON

      from finalDB.AccountJurisdictionExQualify lex

      where
        lex.pYear = p.pyear
        and lex.propertykey = p.pid
      group by p.pYear, lex.PropertyKey, lex.exemptionCode, lex.ExemptionClass, lex.ExQualBeginDate, lex.ExQualEndDate
#  and lex.ExemptionCode = 'ABSO'
    ) lex
    on lex.ExemptionCode is not null

  where
    not exists
      (
        select *
          from propertyAccountExemptions pae
          where pae.pAccountID = pa.paccountID and pae.exemptionCode = lex.exemptioncode
      )
;


insert into propertyAccountExemptionTaxingUnits
  (
  pExemptionID,
  pTaxingUnitID,
  valueType,
  userSpecifiedAmt,
  userSpecifiedPct,
  applyTo,
  createdBy,
  createDt
  )
select
#   pae.pYear,
#   pae.pID,
#   pae.pVersion,
#   pae.pRollCorr,
#   ownerID,
#   tu.taxingUnitCode,
#   tu.taxingUnitName,
#   exemptionCode,

  pae.pExemptionID,
  ptu.pTaxingUnitID,
  if(ExemptionQualifiedValue > 0, 'Value', 'Percent') as valueType,
  ExemptionQualifiedValue as userSpecifiedAmt,
  ifnull(ExemptionQualifiedPercent, 1) * 100 as userSpecifiedPct,
  'All Value' as applyTo,
  pae.createdBy,
  pae.createDt
  from propertyAccount pa
  join propertyAccountExemptions pae
    using (paccountID)
  join json_table(legacyJSON, '$.Jurisdictions[*]' columns (
    JurisdictionCode varchar(20) path '$."JurisdictionCode"',
    ExemptionQualifiedValue decimal(10, 2) path '$."ExemptionQualifiedValue"',
    ExemptionQualifiedPercent decimal(10, 2) path '$."ExemptionQualifiedPercent"')) j
    on JurisdictionCode not in ('$ALL')
  left join taxingUnit tu
    on tu.taxingUnitCode = j.JurisdictionCode
  left join propertyTaxingUnit ptu
    on pae.pyear = ptu.pyear
    and pae.pID = ptu.pID
    and pae.pVersion = ptu.pVersion
    and pae.pRollCorr = ptu.pRollCorr
    and tu.taxingUnitID = ptu.taxingUnitID
  where
    not exists
      (
        select *
          from propertyAccountExemptionTaxingUnits paeu
          where paeu.pExemptionID = pae.pExemptionID and paeu.pTaxingUnitID = ptu.pTaxingUnitID
      )
;

truncate propertyTags;

-- Cleanup previous Conversion Cleanup Tags
select
  *
  from propertyTags
  where
    createdBy = 'TP - Conversion Cleanup'
    and tag like '% -> DV-UD';
delete
  from propertyTags
  where
    createdBy = 'TP - Conversion Cleanup'
    and tag like '% -> DV-UD';
select
  *
  from codefile
  where
    codefileType = 'Property'
    and codefileName = 'Tags'
    and createdBy = 'TP - Conversion Cleanup';
delete
  from codefile
  where
    codefileType = 'Property'
    and codefileName = 'Tags'
    and createdBy = 'TP - Conversion Cleanup';



insert into propertyTags
  (
  pyear,
  pid,
  tag,
  createdBy,
  createDt
  )
select distinct
  p.pYear,
  p.pID,
#  p.pVersion,
#  p.pRollCorr,
#  pa.ownerID,
#       exemptionCode,
#   legacyJSON->>'$.ExemptionCode' as legacyExemptionCode,

  tag,
  'TP - Conversion Cleanup' as createdBy,
  date(now()) as createDt
  from property p
  join propertyAccount pa
    using (pYear, pID, pVersion, pRollCorr)
  join propertyAccountExemptions pae
    using (pAccountID)
  join lateral (
    select convert(concat('CVCU: ', convert(legacyJSON ->> '$.ExemptionCode' using utf8mb4), ' -> ', convert(exemptionCode using utf8mb4)) using latin1) as tag
    ) tag

  where
    exemptionCode = 'DV-UD'
    and p.pyear = (
      select currYear
        from currentYear
    )
    and not inactive
    and not exists
      (
        select *
          from propertyTags pt
          where pt.pyear = p.pyear and pt.pid = p.pid and pt.tag = tag.tag
      )
;



insert into codefile
  (
  codefileYear,
  codefileType,
  codefileName,
  codeName,
  codeDescription,
  codeDefinition,
  createdBy,
  createDt
  )
select distinct
  pyear as codefileYear,
  'Property' as codefileType,
  'Tags' as codefileName,
  tag as codeName,
  concat(legacyCode,
         ' exemptions did not have a direct Prodigy equivalent; they were converted as generic DV-UD exemptions, which are only valid for years certified in the legacy system. To calculate properly, properties with this tag should be reviewed on a property-by-property basis and the DV-UD should be replaced with the most-applicable DV exemption.') as codeDescription,
  json_object('Notification', 1) as codeDefinition,
  createdBy,
  date(now()) as createDt
  from propertyTags pt
  join lateral (
    select
      regexp_replace(tag, 'CVCU: (DV[^ ]*) -> (DV[^ ]*)', '$1') as legacyCode
    ) lc
  where
    pt.createdBy = 'TP - Conversion Cleanup'
  order by
    tag;



select
  if(pYear = 0, 'All Years', pYear) as pYear,
  pID,
  tag as codeName,
  cf.codeDescription as moreInfo
  from propertyTags pt
  left join codefile cf
    on cf.codeFileYear = pt.pYear
    and cf.codeFileType = 'Property'
    and cf.codefileName = 'Tags'

  where
    pt.createdBy = 'TP - Conversion Cleanup'
    and tag like 'CVCU: %'
    and pt.pyear in (0, 2025)
  order by
    tag;
