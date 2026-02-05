use bowie_appraisal;
set @p_user = 'TP Conversion';
set @pYearMin = 2021;
set @pYearMax = 2026;
set @createdBy = 'TPConversion - assessmentInsert';
set @createDt = now();
set @p_skipTrigger = 1;



set sql_safe_updates = 0;
set foreign_key_checks = 0;
truncate taxingUnit;
#truncate propertyTaxingUnit; -- This was being done in two places -- here, and in insertPropertyTaxingUnits.
set sql_safe_updates = 1;
set foreign_key_checks = 1;


INSERT INTO taxingUnit (
  taxingUnitName,
  taxingUnitNum,
  taxingUnitType,
  taxingUnitCode,
  mailingAddressLine1,
  mailingAddressLine2,
  mailingAddressLine3,
  mailingAddressCity,
  mailingAddressState,
  mailingAddressZip,
  email,
  phone,
  inactive,
  createdBy,
  createDt
)

with j as (
select
  if(row_number() over (partition by JurisdictionCode order by cast(AuditTaxYear as unsigned) desc) = 1, true, false) as latest,
       j.*
from conversionDB.Jurisdiction j
  )

select
j.JurisdictionName as taxingUnitName,
  j.PTDNo as taxingUnitNum,
  CASE TRIM(j.JurisdictionType)
    WHEN 'CITY' THEN 'City'
    WHEN 'SCHL' THEN 'School'
    WHEN 'CNTY' THEN 'County'
    WHEN 'ESD'  THEN 'Emergency Services District'
    WHEN 'WATR' THEN 'Water'
    WHEN 'JRCL' THEN 'Jr College District'
    WHEN 'MUD'  THEN 'Municipal Utility District'
    WHEN 'ERR'  THEN 'Error Jurisdiction-Unknown'
    WHEN 'CAD'  THEN 'Appraisal District'
  END as taxingUnitType,
  TRIM(j.JurisdictionCode) as taxingUnitCode,
  ad.AddressOne as mailingAddressLine1,
  ad.AddressTwo as mailingAddressLine2,
  ad.AddressThree as mailingAddressLine3,
  ad.City as mailingAddressCity,
  ad.State as mailingAddressState,
  CASE
    WHEN ad.PostalCode IS NULL OR ad.PostalCode = '' THEN NULL
    WHEN CHAR_LENGTH(TRIM(ad.PostalCode)) > 5
         AND TRIM(ad.PostalCode) NOT LIKE '%-%'
      THEN CONCAT(SUBSTRING(TRIM(ad.PostalCode), 1, 5), '-', SUBSTRING(TRIM(ad.PostalCode), 6))
    ELSE TRIM(ad.PostalCode)
  END as mailingAddressZip,
  TRIM(j.EmailAddress) as email,
  TRIM(j.PhoneNumberOne) as phone,
  if(cast(j.AuditTaxYear as unsigned) < @pYearMin, true, false) as inactive,
  @createdBy as createdBy,
  @createDt as createDt
  
from j
left join conversionDB.AddressDetail ad
  on ad.AddressKey = j.AddressKey
where latest
and not exists (select true from taxingUnit tu where tu.taxingUnitCode = j.JurisdictionCode)
;


select * from taxingUnit;


insert ignore into propertyTaxingUnit (
pid,
pYear,
pVersion,
pRollCorr,
taxingUnitID,
jurisdictionPct,
createDt,
createdBy
)
select DISTINCT
            aa.PropertyKey as pID
          ,aa.TaxYear
          , 0
          , 0
          , tu.taxingUnitID
          , CAST(aa.JurisdictionPct * 100 AS DECIMAL(13,10)) as jurisdictionPct
          , now()
          , @createdBy
     FROM
         conversionDB.Property p
             JOIN conversionDB.AppraisalAccount aa
                 ON aa.TaxYear = p.AuditTaxYear
             AND aa.PropertyKey = p.PropertyKey
             JOIN taxingUnit tu
                on tu.taxingUnitCode = aa.JurisdictionCd
     where p.AuditTaxYear between @pYearMin and @pYearMax

and not exists ( select * from propertyTaxingUnit ptu where ptu.pyear = aa.TaxYear and ptu.pid = aa.PropertyKey and ptu.pVersion = 0 and ptu.pRollCorr = 0 and ptu.taxingUnitID = tu.taxingUnitID )
;


insert into taxingUnitVersion (taxingUnitID,
                               taxingUnitYr,
                               active,
                               createDt,
                               createdBy)
select
#  JurisdictionCode,
  taxingUnitID
     , tj.AuditTaxYear as taxingUnitYr
     , 1 as active
     , @createDt
     , @createdBy
from
    conversionDB.Jurisdiction tj
        join taxingUnit tu
            on tu.taxingUnitCode = tj.JurisdictionCode
where tj.AuditTaxYear between @pYearMin and @pYearMax
and not exists ( select * from taxingUnitVersion tv where tv.taxingUnitID = tu.taxingUnitID and tv.taxingUnitYr = tj.AuditTaxYear and tv.active = 1)
;


insert into taxingUnitTaxRates (
	versionID,
	taxRates,
	totalTaxRate,
	createDt,
	createdBy,
  taxLimitation)
select versionID,
		#concat('{"I&S": ',MO_RATE,',"M&O" : ',IS_RATE, '"No New Revenue" :',0 , ' , "Voter Approval" :',0,'}')
        json_object('I&S', COALESCE(tj.JurisdictionISRate, null), 'M&O', COALESCE(tj.MORate,null),'MCR', 0, 'No New Revenue', 0, 'Voter Approval', 0),
	aj.TotalTaxRate,
	@createDt,
	@createdBy,
  case when FrozenTaxCeilingFlag = 'T' then 1 else 0 end
from taxingUnitVersion tv
	join taxingUnit tu using (taxingUnitID)
    join conversionDB.Jurisdiction tj
		on tu.taxingUnitCode = tj.JurisdictionCode
        and tj.AuditTaxYear = tv.taxingUnitYr
    join conversionDB.AppraisalJurisdiction aj
        on aj.JurisdictionCd = tu.taxingUnitCode
        and aj.TaxYear = tv.taxingUnitYr
    where tv.taxingUnitYr between @pYearMin and @pYearMax
and not exists ( select * from taxingUnitTaxRates tt where tt.versionID = tv.versionID)
;

select * from taxingUnitTaxRates;






insert into taxingUnitExemptions (
versionID,
	exemptionCode,
    exemptionLocalAmount,
	exemptionLocalPct,
    valueType,
	createDt,
	createdBy)
select
    tv.versionID
    ,em.dst_code as exemptionCode
    ,jeg.LocalExemptionValueGranted
    ,jeg.LocalExemptionPercentGranted
     ,case when jeg.LocalExemptionValueGranted > 0
         then 'Amount'
         Else 'Percent'
             end
    ,now()
    ,@createdBy
from taxingUnitVersion tv
join taxingUnit tu using (taxingUnitID)
join conversionDB.JurisExGrant jeg
    on jeg.JurisdictionCode = tu.taxingUnitCode
        and jeg.AuditTaxYear = tv.taxingUnitYr
join exemption_map em
    on  em.src_code = jeg.LocalExemptionCode
join conversionDB.AppraisalJurisdiction aj
        on aj.JurisdictionCd = tu.taxingUnitCode
        and aj.TaxYear = tv.taxingUnitYr
where tv.taxingUnitYr between @pYearMin and @pYearMax
and not exists ( select * from taxingUnitExemptions s where s.versionID = tv.versionID and s.exemptionCode = em.dst_code)
;

INSERT INTO taxingUnitExemptions (
    versionID,
    exemptionCode,
    exemptionLocalAmount,
    exemptionAmount,
    exemptionLocalPct,
    valueType,
    createDt,
    createdBy
)
SELECT
    tv.versionID,
    'HS' as exemptionCode,
    aj.LocalGenHSValGrnt as exemptionLocalAmount,
    aj.StateGenHSValGrnt as exemptionAmount,
    CASE WHEN aj.LocalGenHSPctGrnt > 0
        THEN aj.LocalGenHSPctGrnt
        ELSE 0
    END as exemptionLocalPct,
    CASE WHEN aj.StateGenHSValGrnt > 0
        THEN 'Amount'
        ELSE 'Percent'
    END as valueType,
    NOW() as createDt,
    @createdBy as createdBy
FROM taxingUnitVersion tv
JOIN taxingUnit tu USING (taxingUnitID)
JOIN conversionDB.JurisExGrant jeg
    ON jeg.JurisdictionCode = tu.taxingUnitCode
    AND jeg.AuditTaxYear = tv.taxingUnitYr
JOIN exemption_map em
    ON em.src_code = jeg.LocalExemptionCode
JOIN conversionDB.AppraisalJurisdiction aj
    ON aj.JurisdictionCd = tu.taxingUnitCode
    AND aj.TaxYear = tv.taxingUnitYr
WHERE tv.taxingUnitYr BETWEEN @pYearMin AND @pYearMax
    -- AND tu.taxingUnitName = 'Bowie County'
    AND aj.StateGenHSValGrnt > 0
    AND NOT EXISTS (
        SELECT 1
        FROM taxingUnitExemptions s
        WHERE s.versionID = tv.versionID
            AND s.exemptionCode = 'HS'
    )

UNION ALL

SELECT
    tv.versionID,
    'OV65' as exemptionCode,
    aj.LocalOV65ValGrnt as exemptionLocalAmount,
    aj.StateOV65ValGrnt as exemptionAmount,
    0 as exemptionLocalPct,
    CASE WHEN aj.StateOV65ValGrnt > 0
        THEN 'Amount'
        ELSE 'Percent'
    END as valueType,
    NOW() as createDt,
    @createdBy as createdBy
FROM taxingUnitVersion tv
JOIN taxingUnit tu USING (taxingUnitID)
JOIN conversionDB.JurisExGrant jeg
    ON jeg.JurisdictionCode = tu.taxingUnitCode
    AND jeg.AuditTaxYear = tv.taxingUnitYr
JOIN exemption_map em
    ON em.src_code = jeg.LocalExemptionCode
JOIN conversionDB.AppraisalJurisdiction aj
    ON aj.JurisdictionCd = tu.taxingUnitCode
    AND aj.TaxYear = tv.taxingUnitYr
WHERE tv.taxingUnitYr BETWEEN @pYearMin AND @pYearMax
    -- AND tu.taxingUnitName = 'Red Lick ISD'
    AND aj.StateOV65ValGrnt > 0
    AND NOT EXISTS (
        SELECT 1
        FROM taxingUnitExemptions s
        WHERE s.versionID = tv.versionID
            AND s.exemptionCode = 'OV65'
    )

UNION ALL

SELECT
    tv.versionID,
    'DP' as exemptionCode,
    aj.LocalDPValGrnt as exemptionLocalAmount,
    aj.StateDPValGrnt as exemptionAmount,
    0 as exemptionLocalPct,
    CASE WHEN aj.StateDPValGrnt > 0
        THEN 'Amount'
        ELSE 'Percent'
    END as valueType,
    NOW() as createDt,
    @createdBy as createdBy
FROM taxingUnitVersion tv
JOIN taxingUnit tu USING (taxingUnitID)
JOIN conversionDB.JurisExGrant jeg
    ON jeg.JurisdictionCode = tu.taxingUnitCode
    AND jeg.AuditTaxYear = tv.taxingUnitYr
JOIN exemption_map em
    ON em.src_code = jeg.LocalExemptionCode
JOIN conversionDB.AppraisalJurisdiction aj
    ON aj.JurisdictionCd = tu.taxingUnitCode
    AND aj.TaxYear = tv.taxingUnitYr
WHERE tv.taxingUnitYr BETWEEN @pYearMin AND @pYearMax
    -- AND tu.taxingUnitName = 'Red Lick ISD'
    AND aj.StateDPValGrnt > 0
    AND NOT EXISTS (
        SELECT 1
        FROM taxingUnitExemptions s
        WHERE s.versionID = tv.versionID
            AND s.exemptionCode = 'DP'
    )

UNION ALL

SELECT
    tv.versionID,
    'DPS' as exemptionCode,
    aj.LocalDPSValGrnt as exemptionLocalAmount,
    aj.StateDPSValGrnt as exemptionAmount,
    0 as exemptionLocalPct,
    CASE WHEN aj.StateDPSValGrnt > 0
        THEN 'Amount'
        ELSE 'Percent'
    END as valueType,
    NOW() as createDt,
    @createdBy as createdBy
FROM taxingUnitVersion tv
JOIN taxingUnit tu USING (taxingUnitID)
JOIN conversionDB.JurisExGrant jeg
    ON jeg.JurisdictionCode = tu.taxingUnitCode
    AND jeg.AuditTaxYear = tv.taxingUnitYr
JOIN exemption_map em
    ON em.src_code = jeg.LocalExemptionCode
JOIN conversionDB.AppraisalJurisdiction aj
    ON aj.JurisdictionCd = tu.taxingUnitCode
    AND aj.TaxYear = tv.taxingUnitYr
WHERE tv.taxingUnitYr BETWEEN @pYearMin AND @pYearMax
    -- AND tu.taxingUnitName = 'Red Lick ISD'
    AND aj.StateDPSValGrnt > 0
    AND NOT EXISTS (
        SELECT 1
        FROM taxingUnitExemptions s
        WHERE s.versionID = tv.versionID
            AND s.exemptionCode = 'DPS'
    )

UNION ALL

SELECT
    tv.versionID,
    'OV65S' as exemptionCode,
    aj.LocalSSValGrnt as exemptionLocalAmount,
    aj.StateSSValGrnt as exemptionAmount,
    0 as exemptionLocalPct,
    CASE WHEN aj.StateSSValGrnt > 0
        THEN 'Amount'
        ELSE 'Percent'
    END as valueType,
    NOW() as createDt,
    @createdBy as createdBy
FROM taxingUnitVersion tv
JOIN taxingUnit tu USING (taxingUnitID)
JOIN conversionDB.JurisExGrant jeg
    ON jeg.JurisdictionCode = tu.taxingUnitCode
    AND jeg.AuditTaxYear = tv.taxingUnitYr
JOIN exemption_map em
    ON em.src_code = jeg.LocalExemptionCode
JOIN conversionDB.AppraisalJurisdiction aj
    ON aj.JurisdictionCd = tu.taxingUnitCode
    AND aj.TaxYear = tv.taxingUnitYr
WHERE tv.taxingUnitYr BETWEEN @pYearMin AND @pYearMax
    -- AND tu.taxingUnitName = 'Pleasant Grove ISD'
    AND aj.StateSSValGrnt > 0
    AND NOT EXISTS (
        SELECT 1
        FROM taxingUnitExemptions s
        WHERE s.versionID = tv.versionID
            AND s.exemptionCode = 'OV65S'
    );



