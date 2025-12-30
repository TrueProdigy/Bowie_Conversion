use bowie_appraisal;

set @pYearMin = 2020;
set @pYearMax = 2025;

set @createdBy = 'TP Conversion - Freeze';
set @createDt = now();
set @p_skipTrigger = 1;
set @p_user = 'TP Conversion';

# SET FOREIGN_KEY_CHECKS = 0;
# TRUNCATE TABLE codefile;
# SET FOREIGN_KEY_CHECKS = 1;


insert into propertyAccountExemptionTaxLimitation
(
pExemptionID,
pTaxingUnitID,
pID,
pYear,
pVersion,
pRollCorr,
limitationAmt,
limitationYr,
limitationTransfer,
limitationTransferPct,
createdBy,
createDt)
select
pax.pExemptionID,
  ptu.pTaxingUnitID,
  pa.pid                           AS pid,
  aa.TaxYear                       AS pYear,
  0,
  0,
  aa.FrozenTaxCeiling              AS limitationAmt,
  CASE
    WHEN aa.FrozenTaxCeiling > 0
         AND TRIM(REPLACE(aa.FrozenTaxYear, CHAR(194,160), ' ')) REGEXP '^[0-9]+$'
      THEN CAST(TRIM(REPLACE(aa.FrozenTaxYear, CHAR(194,160), ' ')) AS UNSIGNED)
    ELSE NULL
  END                              AS limitationYr,
  CASE WHEN aa.FrozenTaxStatus = 'FTXP' THEN 1 ELSE 0 END AS limitationTransfer,
  /* defensively cast pct too, in case of blanks */
  CASE
    WHEN TRIM(REPLACE(aa.FrozenTaxTransferPct, CHAR(194,160), ' ')) REGEXP '^[0-9]+(\\.[0-9]+)?$'
      THEN CAST(TRIM(REPLACE(aa.FrozenTaxTransferPct, CHAR(194,160), ' ')) AS DECIMAL(10,4))
    ELSE NULL
  END                              AS limitationTransferPct,
  @createdBy,
  NOW()
FROM propertyAccount pa
JOIN propertyTaxingUnit ptu USING (pid, pYear, pVersion, pRollCorr)
JOIN propertyAccountExemptions pax USING (pAccountID)
JOIN taxingUnit tu USING (taxingUnitID)
JOIN conversionDB.AppraisalAccount aa
  ON aa.TaxYear        = pa.pYear
 AND aa.PropertyKey    = pa.pid
 AND aa.JurisdictionCd = tu.taxingUnitCode
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax;