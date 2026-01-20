use bowie_appraisal;

set @pYearMin = 2020;
set @pYearMax = 2025;

set @createdBy = 'TP Conversion - Freeze';
set @createDt = now();
set @p_skipTrigger = 1;
set @p_user = 'TP Conversion';



set FOREIGN_KEY_CHECKS = 0;
truncate propertyAccountExemptionTaxLimitation;
set FOREIGN_KEY_CHECKS = 1;



# Research.  Available fields seem to contain the keyword: "froze".
select
  *
  from information_schema.columns
  where
    TABLE_SCHEMA = 'conversionDB'
    and locate('froze', column_name) > 0;



# Look for situations where there is an OV65 and a DP.  If these exist, and there is a freeze in play, we'll need to come up with a way to determine whether the freeze is associated with the DP or the OV65.
select
  *
  from propertyAccountExemptions pae
  where
    exists
      (
        select *
          from propertyAccountExemptions pae2
          where pae2.paccountid = pae.paccountid and pae2.exemptionCode in ('OV65', 'OV65S')
      )
    and exists
      (
        select *
          from propertyAccountExemptions pae2
          where pae2.paccountid = pae.paccountid and pae2.exemptionCode in ('DP', 'DPS')
      );


insert into propertyAccountExemptionTaxLimitation
  (
  pExemptionID,
  pTaxingUnitID,
  pID,
  pYear,
  pVersion,
  pRollCorr,
  limitationAmt,
  limitationAmtPriorCompression,
  limitationYr,
  limitationTransfer,
  limitationTransferPct,
  createdBy,
  createDt
  )

select
  pExemptionID,
  pTaxingUnitID,
  pID,
  pYear,
  pVersion,
  pRollCorr,
  limitationAmt,
  limitationAmtPriorCompression,
  limitationYr,
  limitationTransfer,
  limitationTransferPct,
  @createdBy as createdBy,
  date(now()) as createDt
  from conversionDB.AppraisalAccount aa
  join lateral (
    select
      aa.FrozenTaxCeiling as limitationAmt,
      aa.FrozenTaxCeiling as limitationAmtPriorCompression,
      
      case
        when aa.FrozenTaxCeiling > 0
          and TRIM(REPLACE(aa.FrozenTaxYear, CHAR(194, 160), ' ')) regexp '^[0-9]+$'
          then CAST(TRIM(REPLACE(aa.FrozenTaxYear, CHAR(194, 160), ' ')) as UNSIGNED)
        else null
      end as limitationYr,
      
      case when aa.FrozenTaxStatus = 'FTXP' then 1 else 0 end as limitationTransfer,
      
      case
        when TRIM(REPLACE(aa.FrozenTaxTransferPct, CHAR(194, 160), ' ')) regexp '^[0-9]+(\\.[0-9]+)?$'
          then CAST(TRIM(REPLACE(aa.FrozenTaxTransferPct, CHAR(194, 160), ' ')) as DECIMAL(10, 4))
        else null
      end as limitationTransferPct
    ) as transforms
    on FrozenTaxCeiling > 0
  
  
  join lateral (
    select
      pa.pid,
      pa.pversion,
      pa.prollcorr,
      pa.ownerID,
      tu.taxingUnitCode,
      exemptionCode,
      ptu.pTaxingUnitID,
      pax.pexemptionID
      from propertyAccount pa
      join propertyTaxingUnit ptu
        using (pid, pYear, pVersion, pRollCorr)
      join propertyAccountExemptions pax
        using (pAccountID)
      join lateral (
        select
          case
            when exemptionCode in ('OV65')
              then 1
            when exemptionCode in ('OV65S')
              then 2
            when exemptionCode in ('DP')
              then 3
            when exemptionCode in ('DPS')
              then 4
          end as freezeRank
        ) fr
      join taxingUnit tu
        using (taxingUnitID)
      where
        aa.pYear = pa.pYear
        and aa.PropertyKey = pa.pid
        and aa.JurisdictionCd = tu.taxingUnitCode
        and aa.OwnerKey = pa.ownerID
        and pax.exemptionCode in ('DP', 'DPS', 'OV65', 'OV65S')
      group by pAccountID, ptaxingunitid, tu.taxingUnitCode
      order by freezeRank
      limit 1
    ) as e
  
  where
    not exists
      (
        select true
          from propertyAccountExemptionTaxLimitation limits
          where limits.pExemptionID = e.pexemptionID and limits.pTaxingUnitID = e.ptaxingunitid
      )
;

