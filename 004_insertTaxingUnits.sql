use bowie_appraisal;
set @p_user = 'TP Conversion';
set @pYearMin = 2020;
set @pYearMax = 2025;
set @createdBy = 'TPConversion - assessmentInsert';
set @createDt = now();
set @p_skipTrigger = 1;



# set sql_safe_updates = 0;
# set foreign_key_checks = 0;
# truncate taxingUnit;
# #truncate propertyTaxingUnit; -- This was being done in two places -- here, and in insertPropertyTaxingUnits.
# set sql_safe_updates = 1;
# set foreign_key_checks = 1;


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
  createdBy,
  createDt
)
SELECT
  j.JurisdictionName,
  j.PTDNo,
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
  END,
  TRIM(j.JurisdictionCode),
  ad.AddressOne,
  ad.AddressTwo,
  ad.AddressThree,
  ad.City,
  ad.State,
  CASE
    WHEN ad.PostalCode IS NULL OR ad.PostalCode = '' THEN NULL
    WHEN CHAR_LENGTH(TRIM(ad.PostalCode)) > 5
         AND TRIM(ad.PostalCode) NOT LIKE '%-%'
      THEN CONCAT(SUBSTRING(TRIM(ad.PostalCode), 1, 5), '-', SUBSTRING(TRIM(ad.PostalCode), 6))
    ELSE TRIM(ad.PostalCode)
  END,
  TRIM(j.EmailAddress),
  TRIM(j.PhoneNumberOne),
  @createdBy,
  @createDt
FROM conversionDB.Jurisdiction j
JOIN conversionDB.AddressDetail ad
  ON ad.AddressKey = j.AddressKey
WHERE j.JurisdictionName = 'TEXARKANA ISD'
  AND JurisdictionCode = '03T'
  AND NOT EXISTS (
  SELECT 1
  FROM conversionDB.Jurisdiction j2
  JOIN conversionDB.AddressDetail ad2
    ON ad2.AddressKey = j2.AddressKey
  WHERE j2.JurisdictionName = j.JurisdictionName
    AND (
      ((ad2.AddressOne IS NOT NULL AND ad2.AddressOne <> '') +
       (ad2.City       IS NOT NULL AND ad2.City       <> '') +
       (ad2.State      IS NOT NULL AND ad2.State      <> '') +
       (ad2.PostalCode IS NOT NULL AND ad2.PostalCode <> ''))
      >
      ((ad.AddressOne IS NOT NULL AND ad.AddressOne <> '') +
       (ad.City       IS NOT NULL AND ad.City       <> '') +
       (ad.State      IS NOT NULL AND ad.State      <> '') +
       (ad.PostalCode IS NOT NULL AND ad.PostalCode <> ''))
      OR (
        ((ad2.AddressOne IS NOT NULL AND ad2.AddressOne <> '') +
         (ad2.City       IS NOT NULL AND ad2.City       <> '') +
         (ad2.State      IS NOT NULL AND ad2.State      <> '') +
         (ad2.PostalCode IS NOT NULL AND ad2.PostalCode <> ''))
        =
        ((ad.AddressOne IS NOT NULL AND ad.AddressOne <> '') +
         (ad.City       IS NOT NULL AND ad.City       <> '') +
         (ad.State      IS NOT NULL AND ad.State      <> '') +
         (ad.PostalCode IS NOT NULL AND ad.PostalCode <> ''))
        AND j2.AddressKey < j.AddressKey
      )
    )
);

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
            aa.PropertyKey
          , aa.TaxYear
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
     where p.AuditTaxYear between @pYearMin and @pYearMax;


insert into taxingUnitVersion (taxingUnitID,
                               taxingUnitYr,
                               active,
                               createDt,
                               createdBy)
select taxingUnitID
     , tj.AuditTaxYear
     , 1
     , @createDt
     , @createdBy
from
    conversionDB.Jurisdiction tj
        join taxingUnit tu
            on tu.taxingUnitCode = tj.JurisdictionCode
where tj.AuditTaxYear between @pYearMin and @pYearMax;


insert into taxingUnitTaxRates (
	versionID,
	taxRates,
	totalTaxRate,
	createDt,
	createdBy)
select versionID,
		#concat('{"I&S": ',MO_RATE,',"M&O" : ',IS_RATE, '"No New Revenue" :',0 , ' , "Voter Approval" :',0,'}')
        json_object('I&S', COALESCE(tj.JurisdictionISRate, null), 'M&O', COALESCE(tj.MORate,null),'MCR', 0, 'No New Revenue', 0, 'Voter Approval', 0),
	aj.TotalTaxRate,
	@createDt,
	@createdBy
from taxingUnitVersion tv
	join taxingUnit tu using (taxingUnitID)
    join conversionDB.Jurisdiction tj
		on tu.taxingUnitCode = tj.JurisdictionCode
        and tj.AuditTaxYear = tv.taxingUnitYr
    join conversionDB.AppraisalJurisdiction aj
        on aj.JurisdictionCd = tu.taxingUnitCode
        and aj.TaxYear = tv.taxingUnitYr
    where tv.taxingUnitYr between @pYearMin and @pYearMax;

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
where tv.taxingUnitYr between @pYearMin and @pYearMax;

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



