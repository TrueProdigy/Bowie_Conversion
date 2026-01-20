use bowie_appraisal;
set @pYearMin = 2020;
set @pYearMax = 2025;


set @p_skipTrigger = 1;
set @p_user = 'TP Conversion';
set @createdBy = 'TP Conversion - insertTaxable';
set @createDt = now();
set sql_safe_updates = 1;


-- The TaxYear column is a varchar - making it an indexed int speeds things up A LOT!
alter table conversionDB.AppraisalAccount
    add pYear int as (cast(TaxYear as unsigned)) stored;
call conversionDB.CreateIndex('conversionDB', 'AppraisalAccount', 'PropertyKey', 'pYear, PropertyKey');


/*
set foreign_key_checks = false;
# set sql_safe_updates = 0;
truncate propertyAccountTaxingUnitTaxable;
truncate propertyAccountTaxingUnitExemptions;
truncate propertyAccountTaxingUnitStateAgBreakdown;
truncate propertyAccountTaxingUnitStateCodeValue;
set foreign_key_checks = true;
*/

insert into propertyAccountTaxingUnitTaxable (
                                                pAccountID,
pTaxingUnitID,
pYear,
pID,
pVersion,
pRollCorr,
isUDI,
ownerID,
ownerPct,
taxingUnitID,
taxingUnitPct,
marketValue,
improvementHSValue,
improvementNHSValue,
landHSValue,
landNHSValue,
suLandMktValue,
suValue,
suExclusionValue,
agLandMktValue,
agValue,
agExclusionValue,
timberLandMktValue,
timberValue,
timberExclusionValue,
timber78LandMktValue,
timber78Value,
timber78ExclusionValue,
appraisedValue,
cbTaxLimitationValue,
hsTaxLimitationValue,
limitationValue,
netAppraisedValue,
# legacyExemptionValue,
taxableValue,
legacyTaxableValue,
totalTaxRate,
actualTax,
newImprovementHSValue,
newImprovementNHSValue,
newLandHSValue,
newLandNHSValue,
newBppValue
)

select
  pAccountID,
  pTaxingUnitID,
  
  pYear,
  PropertyKey as pID,
  0 as pVersion,
  0 as pRollCorr,
  
  
  if(ownerPct <> 100, true, false) as isUDI,
  ownerKey as ownerID,
  ownerPct,
  
  taxingUnitID,
  taxingUnitPct,
  
  
  aa.TotalMarketVal as marketValue,

  
  aa.HomesiteImprovementVal as improvementHSValue,
  aa.OtherImprovementVal improvementNHSValue,

  aa.HomesiteLandVal as landHSValue,
  calcs.landNHSValue,

  aa.agLandMarketVal + TimberLandMarketVal + RestrictedUseTimberMarketVal as suLandMktValue,
  aa.AgLandProdVal + TimberLandProdVal + RestrictedUseTimberProdVal as suValue,
  aa.ProductivityLossVal as suExclusionValue,

  aa.AgLandMarketVal as agLandMktValue,
  aa.AgLandProdVal as agValue,
  aa.AgLandMarketVal - AgLandProdVal as agExclusionValue,

  aa.TimberLandMarketVal as timberLandMktValue,
  aa.TimberLandProdVal as timberValue,
  aa.TimberLandMarketVal - TimberLandProdVal as timberExclusionValue,

  aa.RestrictedUseTimberMarketVal as timber78LandMktValue,
  aa.RestrictedUseTimberProdVal as timber78Value,
  aa.RestrictedUseTimberMarketVal - RestrictedUseTimberProdVal as timber78ExclusionValue,

  calcs.appraisedValue as appraisedValue,

  caps.cbTaxLimitationValue,
  caps.hsTaxLimitationValue,
  calcs.limitationValue,
  
  aa.TotalAppraisedVal as netAppraisedValue,
  
#  calcs.legacyExemptionValue,
  
   aa.TotalTaxableVal as taxableValue,
  aa.TotalTaxableVal as legacyTaxableValue,

  ptu.totalTaxRate,
  aa.TotalTaxLevy as actualTax,
  
  aa.HomesiteNewImprovementVal as newImprovementHSValue,
  aa.OtherNewImprovementVal as newImprovementNHSValue,
  
  aa.HomesiteNewLandVal as newLandHSValue,
  aa.OtherNewLandVal as newLandNHSValue,
  
  aa.HomesiteNewPersonalVal + aa.OtherNewPersonalVal as newBppValue

FROM conversionDB.AppraisalAccount aa
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
  select pa.pAccountID, pa.ownerPct
  from propertyAccount pa
  where pa.pyear = aa.pyear
  and pa.pID = aa.PropertyKey
  and pa.pVersion = 0
  and pa.pRollCorr = 0
  and pa.ownerID = aa.ownerKey
  ) pa

  
join lateral (
  select ptu.pTaxingUnitID, ptu.jurisdictionPct as taxingUnitPct, ptu.taxingUnitID, ifnull(rates.totalTaxRate,0) as totalTaxRate

  from propertyTaxingUnit ptu
  join taxingUnit tu using (taxingUnitID)
  left join lateral (
    select totalTaxRate
    from taxingUnitVersion tuv
    join taxingUnitTaxRates rates using (versionID)
    where tuv.taxingUnitID = ptu.taxingUnitID
    and tuv.taxingUnitYr = aa.pyear
    order by active desc
    limit 1
    ) rates on true
  where ptu.pyear = aa.pyear
  and ptu.pID = aa.PropertyKey
  and ptu.pVersion = 0
  and ptu.pRollCorr = 0
  and tu.taxingUnitCode = aa.JurisdictionCd
  ) ptu



  where
    not exists ( select * from propertyAccountTaxingUnitTaxable tax where tax.pTaxingUnitID = ptu.pTaxingUnitID and tax.pAccountID = pa.pAccountID);

  
  
  
  
  

/*
truncate propertyAccountTaxingUnitExemptions;
 */
 





set @p_skipTrigger = true;
 
# HS - Local
insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)


select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
 left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('HS')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'HS') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', 'Local') as calculationType,
      LocalGenHomesteadVal as localExemptionAmount,
      0 as exemptionAmount, -- State Amount
      LocalGenHomesteadVal as totalExemptionAmount,
      ifnull(GenHSExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(GenHSExemptionBegDt <> '0' and left(GenHSExemptionBegDt, 4) = laa.TaxYear and GenHSExemptionBegDt <> concat(TaxYear, '0101'), true, false) or(if(GenHomesteadExmEndDt <> '0', true, false)) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and GenHSExemption = 'Y'
        /* and LocalGenHomesteadVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;


# HS-State
insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)


select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('HS')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'HS') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', 'State') as calculationType,
      0 as localExemptionAmount,
      StateGenHomesteadVal as exemptionAmount, -- State Amount
      StateGenHomesteadVal as totalExemptionAmount,
      ifnull(GenHSExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(GenHSExemptionBegDt <> '0' and left(GenHSExemptionBegDt, 4) = laa.TaxYear and GenHSExemptionBegDt <> concat(TaxYear, '0101'), true, false) or(if(GenHomesteadExmEndDt <> '0', true, false)) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and GenHSExemption = 'Y'
        /* and StateGenHomesteadVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;



select Ov65Exemption, count(*) from conversionDB.AppraisalAccount group by Ov65Exemption;
select TaxYear, PropertyKey, JurisdictionCd,Ov65Exemption, LocalOver65Val From conversionDB.AppraisalAccount aa where aa.Ov65Exemption = 'Y' /* and LocalOver65Val > 0 */; -- OV65-Local
select TaxYear, PropertyKey, JurisdictionCd,Ov65Exemption, StateOver65Val From conversionDB.AppraisalAccount aa where aa.Ov65Exemption = 'Y' /* and StateOver65Val > 0 */; -- OV65-State


# OV65 - Local
insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)


select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('OV65')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'OV65') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', 'Local') as calculationType,
      LocalOver65Val as localExemptionAmount,
      0 as exemptionAmount, -- State Amount
      LocalOver65Val as totalExemptionAmount,
      ifnull(Ov65ExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(Ov65ExemptionBegDt <> '0' and left(Ov65ExemptionBegDt, 4) = laa.TaxYear and Ov65ExemptionBegDt <> concat(TaxYear, '0101'), true, false) or if(Over65ExmEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and Ov65Exemption = 'Y'
        /* and LocalOver65Val > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;


# OV65-State
insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)


select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('OV65')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'OV65') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', 'State') as calculationType,
      0 as localExemptionAmount,
      StateOver65Val as exemptionAmount, -- State Amount
      StateOver65Val as totalExemptionAmount,
      ifnull(Ov65ExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(Ov65ExemptionBegDt <> '0' and left(Ov65ExemptionBegDt, 4) = laa.TaxYear and Ov65ExemptionBegDt <> concat(TaxYear, '0101'), true, false) or if(Over65ExmEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and Ov65Exemption = 'Y'
        /* and StateOver65Val > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;





select Ov65SSExemption, count(*) from conversionDB.AppraisalAccount group by Ov65SSExemption;
select TaxYear, PropertyKey, JurisdictionCd,Ov65SSExemption, LocalOver65SurvivingSpouseVal From conversionDB.AppraisalAccount aa where aa.Ov65SSExemption = 'Y' /* and LocalOver65SurvivingSpouseVal > 0 */; -- OV65S-Local
select TaxYear, PropertyKey, JurisdictionCd,Ov65SSExemption, StateOver65SurvivingSpouseVal From conversionDB.AppraisalAccount aa where aa.Ov65SSExemption = 'Y' /* and StateOver65SurvivingSpouseVal > 0 */; -- OV65S-State


# OV65S - Local
insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)


select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('OV65S')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'OV65S') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', 'Local') as calculationType,
      LocalOver65SurvivingSpouseVal as localExemptionAmount,
      0 as exemptionAmount, -- State Amount
      LocalOver65SurvivingSpouseVal as totalExemptionAmount,
      ifnull(Ov65SSExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(Ov65SSExemptionBegDt <> '0' and left(Ov65SSExemptionBegDt, 4) = laa.TaxYear and Ov65SSExemptionBegDt <> concat(TaxYear, '0101'), true, false) or if(Over65SSDPExemptionEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and Ov65SSExemption = 'Y'
        /* and LocalOver65SurvivingSpouseVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;


# OV65S-State
insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)


select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('OV65S')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'OV65S') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', 'State') as calculationType,
      0 as localExemptionAmount,
      StateOver65SurvivingSpouseVal as exemptionAmount, -- State Amount
      StateOver65SurvivingSpouseVal as totalExemptionAmount,
      ifnull(Ov65SSExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(Ov65SSExemptionBegDt <> '0' and left(Ov65SSExemptionBegDt, 4) = laa.TaxYear and Ov65SSExemptionBegDt <> concat(TaxYear, '0101'), true, false) or if(Over65SSDPExemptionEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and Ov65SSExemption = 'Y'
        /* and StateOver65SurvivingSpouseVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;




select DPExemption, count(*) from conversionDB.AppraisalAccount group by DPExemption;
select TaxYear, PropertyKey, JurisdictionCd,DPExemption, LocalDPVal From conversionDB.AppraisalAccount aa where aa.DPExemption = 'Y' /* and LocalDPVal > 0 */; -- DP-Local
select TaxYear, PropertyKey, JurisdictionCd,DPExemption, StateDPVal From conversionDB.AppraisalAccount aa where aa.DPExemption = 'Y' /* and StateDPVal > 0 */; -- DP-State

# DP - Local
insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)


select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('DP')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'DP') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', 'Local') as calculationType,
      LocalDPVal as localExemptionAmount,
      0 as exemptionAmount, -- State Amount
      LocalDPVal as totalExemptionAmount,
      ifnull(DPExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(DPExemptionBegDt <> '0' and left(DPExemptionBegDt, 4) = laa.TaxYear and DPExemptionBegDt <> concat(TaxYear, '0101'), true, false) or if(DPExemptionEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and DPExemption = 'Y'
        /* and LocalDPVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;


select TaxYear, propertykey, DPExemptionEndDt from conversionDB.AppraisalAccount where DPExemption = 'Y' and dpexemptionenddt <> '0';


# DP-State
insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)


select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('DP')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'DP') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', 'State') as calculationType,
      0 as localExemptionAmount,
      StateDPVal as exemptionAmount, -- State Amount
      StateDPVal as totalExemptionAmount,
      ifnull(DPExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(DPExemptionBegDt <> '0' and left(DPExemptionBegDt, 4) = laa.TaxYear and DPExemptionBegDt <> concat(TaxYear, '0101'), true, false) or if(DPExemptionEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and DPExemption = 'Y'
        /* and StateDPVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;




select DSSExemption, count(*) from conversionDB.AppraisalAccount group by DSSExemption;
select TaxYear, PropertyKey, JurisdictionCd,DSSExemption, LocalDisabledSurvivingSpouseVal From conversionDB.AppraisalAccount aa where aa.DSSExemption = 'Y' /* and LocalDisabledSurvivingSpouseVal > 0 */; -- DPS-Local
select TaxYear, PropertyKey, JurisdictionCd,DSSExemption, StateDisabledSurvivingSpouseVal From conversionDB.AppraisalAccount aa where aa.DSSExemption = 'Y' /* and StateDisabledSurvivingSpouseVal > 0 */; -- DPS-State

# DPS - Local
insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)


select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('DPS')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'DPS') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', 'Local') as calculationType,
      LocalDisabledSurvivingSpouseVal as localExemptionAmount,
      0 as exemptionAmount, -- State Amount
      LocalDisabledSurvivingSpouseVal as totalExemptionAmount,
      ifnull(DSSExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(DSSExemptionBegDt <> '0' and left(DSSExemptionBegDt, 4) = laa.TaxYear and DSSExemptionBegDt <> concat(TaxYear, '0101'), true, false) or if(DSSExmEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and DSSExemption = 'Y'
        /* and LocalDisabledSurvivingSpouseVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;




# DPS-State
insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)


select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('DPS')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'DPS') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', 'State') as calculationType,
      0 as localExemptionAmount,
      StateDisabledSurvivingSpouseVal as exemptionAmount, -- State Amount
      StateDisabledSurvivingSpouseVal as totalExemptionAmount,
      ifnull(DSSExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(DSSExemptionBegDt <> '0' and left(DSSExemptionBegDt, 4) = laa.TaxYear and DSSExemptionBegDt <> concat(TaxYear, '0101'), true, false) or if(DSSExmEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and DSSExemption = 'Y'
        /* and StateDisabledSurvivingSpouseVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;







select DVExemptionCd, count(*) from conversionDB.AppraisalAccount group by DVExemptionCd;
select TaxYear, PropertyKey, JurisdictionCd,DPExemption, DVExemptionCd, DVVal From conversionDB.AppraisalAccount aa  where /* DVVal > 0 and */  DVExemptionCd in ('HS', 'XHDV'); -- DVHS

insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)


select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('DVHS')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'DVHS') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', null) as calculationType,
      0 as localExemptionAmount,
      DVVal as exemptionAmount, -- State Amount
      DVVal as totalExemptionAmount,
      ifnull(DVExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(DVExemptionBegDt <> '0' and left(DVExemptionBegDt, 4) = laa.TaxYear and DVExemptionBegDt <> concat(TaxYear, '0101'), true, false) or if(DisabledVetExmEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and DVExemptionCd in ('HS', 'XHDV')
        /* and DVVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;


# Assess DV situation.  We don't have Prodigy equivalents for all of these, and some may be at the Chief Appraiser's discretion, so we'll apply "DV-UD" to those. BUT for the current year, anything with a DV-UD will need to be assessed by the client and, post Go Live, the code should be replaced with the most-appropriate code on a property-by-property basis.
select DVExemptionCd as legacyCode,
       case
         when DVExemptionCd in ('00') then 'DV-UD' -- More than one DV-eligible owner
         when DVExemptionCd in ('HS') then 'DVHS'
         when DVExemptionCd in ('01') then 'DV1'
         when DVExemptionCd in ('03') then 'DV2'
         when DVExemptionCd in ('05') then 'DV3'
         when DVExemptionCd in ('07') then 'DV4'
         when DVExemptionCd in ('11') then 'DV-UD' -- 65 Years of Age/At Least 10% Disability
         when DVExemptionCd in ('12') then 'DV-UD' -- Blind in One or Both Eyes
         when DVExemptionCd in ('13') then 'DV-UD' -- oss of the Use of One or More Limbs
         when DVExemptionCd in ('21') then 'DV1S'
         when DVExemptionCd in ('23') then 'DV2S'
         when DVExemptionCd in ('25') then 'DV3S'
         when DVExemptionCd in ('27') then 'DV4S'
         when DVExemptionCd in ('31') then 'DV-UD' -- 65 Years/At Least 10%/Surviving Spouse
         when DVExemptionCd in ('32') then 'DV-UD' -- Blind in One/Both Eyes/Surviving Spouse
         when DVExemptionCd in ('33') then 'DV-UD' -- Loss of One/More Limbs/Surviving Spouse
         when DVExemptionCd in ('41') then 'DVHSS' -- Deceased Veteran Surviving Spouse
         when DVExemptionCd in ('42') then 'DVHSS' -- Deceased Veteran Surviving Child
           end as prodigyEquivalent,
       count(*) From conversionDB.AppraisalAccount aa
                /* where DVVal > 0 */
                                                      group by DVExemptionCd
order by DVExemptionCd
;




insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)

select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
#  legacyCode,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode like 'DV%'
      limit 1
    ) as pae on true
    
  join lateral (
    select
      DVExemptionCd as legacyCode,
             case
         when DVExemptionCd in ('00') then 'DV-UD'
         when DVExemptionCd in ('HS') then 'DVHS'
         when DVExemptionCd in ('01') then 'DV1'
         when DVExemptionCd in ('03') then 'DV2'
         when DVExemptionCd in ('05') then 'DV3'
         when DVExemptionCd in ('07') then 'DV4'
         when DVExemptionCd in ('11') then 'DV-UD' -- 65 Years of Age/At Least 10% Disability
         when DVExemptionCd in ('12') then 'DV-UD' -- Blind in One or Both Eyes
         when DVExemptionCd in ('13') then 'DV-UD' -- oss of the Use of One or More Limbs
         when DVExemptionCd in ('21') then 'DV1S'
         when DVExemptionCd in ('23') then 'DV2S'
         when DVExemptionCd in ('25') then 'DV3S'
         when DVExemptionCd in ('27') then 'DV4S'
         when DVExemptionCd in ('31') then 'DV-UD' -- 65 Years/At Least 10%/Surviving Spouse
         when DVExemptionCd in ('32') then 'DV-UD' -- Blind in One/Both Eyes/Surviving Spouse
         when DVExemptionCd in ('33') then 'DV-UD' -- Loss of One/More Limbs/Surviving Spouse
         when DVExemptionCd in ('41') then 'DVHSS' -- Deceased Veteran Surviving Spouse
         when DVExemptionCd in ('42') then 'DVHSS' -- Deceased Veteran Surviving Child
  else laa.DVExemptionCd end as exemptionCode,
      
      prorated,
      
      if(prorated, 'Prorated', null) as calculationType,
      0 as localExemptionAmount,
      DVVal as exemptionAmount, -- State Amount
      DVVal as totalExemptionAmount,
      ifnull(DVExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(DVExemptionBegDt <> '0' and left(DVExemptionBegDt, 4) = laa.TaxYear and DVExemptionBegDt <> concat(TaxYear, '0101'), true, false) or if(DisabledVetExmEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        /* and DVVal > 0 */
        and nullif(trim(DVExemptionCd), '') is not null
      limit 1
    ) as laa
    
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), laa.exemptionCode) exemptionCode ) ec
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;











# Absolute Exemptions
select AbsExemption, count(*) from conversionDB.AppraisalAccount group by AbsExemption;
select TaxYear, PropertyKey, JurisdictionCd,AbsExemption, AbsVal, TotalTaxableVal From conversionDB.AppraisalAccount aa where AbsExemption = 'Y' /* and AbsVal > 0 */;

insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)

select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode like 'EX%' and pae.exemptionCode <> 'EX366'
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'EX') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', null) as calculationType,
      0 as localExemptionAmount,
      AbsVal as exemptionAmount, -- State Amount
      AbsVal as totalExemptionAmount,
      ifnull(AbsExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(AbsExemptionBegDt <> '0' and left(AbsExemptionBegDt, 4) = laa.TaxYear and AbsExemptionBegDt <> concat(TaxYear, '0101'), true, false) or if(AbsExmEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and AbsExemption = 'Y'
        /* and AbsVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;



select FreeportExemption, count(*) from conversionDB.AppraisalAccount group by FreeportExemption;
select TaxYear, PropertyKey, JurisdictionCd,FreeportExemption, FreeportVal From conversionDB.AppraisalAccount aa where FreeportExemption = 'Y' /* and FreeportVal > 0 */;


insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)

select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('FR')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'FR') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', null) as calculationType,
      0 as localExemptionAmount,
      FreeportVal as exemptionAmount, -- State Amount
      FreeportVal as totalExemptionAmount,
      ifnull(FreeportExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(FreeportExemptionBegDt <> '0' and left(FreeportExemptionBegDt, 4) = laa.TaxYear and FreeportExemptionBegDt <> concat(TaxYear, '0101'), true, false) or if(FreeportExmEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and FreeportExemption = 'Y'
        /* and FreeportVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;




select GoodsInTranExemption, count(*) from conversionDB.AppraisalAccount group by GoodsInTranExemption;
select TaxYear, PropertyKey, JurisdictionCd,GoodsInTranExemption, GoodsInTransitVal From conversionDB.AppraisalAccount aa where GoodsInTranExemption = 'Y' /* and GoodsInTransitVal > 0 */;



insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)

select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('GIT')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'GIT') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', null) as calculationType,
      0 as localExemptionAmount,
      GoodsInTransitVal as exemptionAmount, -- State Amount
      GoodsInTransitVal as totalExemptionAmount,
      ifnull(GoodsInTranExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(GoodsInTranExemptionBegDt <> '0' and left(GoodsInTranExemptionBegDt, 4) = laa.TaxYear and GoodsInTranExemptionBegDt <> concat(TaxYear, '0101'), true, false) or if(GoodsInTranExmEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and GoodsInTranExemption = 'Y'
        /* and GoodsInTransitVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;



select SolarWindExemption, count(*) from conversionDB.AppraisalAccount group by SolarWindExemption;
select TaxYear, PropertyKey, JurisdictionCd,SolarWindExemption, SolarWindVal From conversionDB.AppraisalAccount aa where SolarWindExemption = 'Y' /* and SolarWindVal > 0 */;


insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)

select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('SO')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'SO') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', null) as calculationType,
      0 as localExemptionAmount,
      SolarWindVal as exemptionAmount, -- State Amount
      SolarWindVal as totalExemptionAmount,
      ifnull(SolarWindExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(SolarWindExmBegDt <> '0' and left(SolarWindExmBegDt, 4) = laa.TaxYear and SolarWindExmBegDt <> concat(TaxYear, '0101'), true, false) or if(SolarWindExmEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and SolarWindExemption = 'Y'
        /* and SolarWindVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;







select HistExemption, count(*) from conversionDB.AppraisalAccount group by HistExemption;
select TaxYear, PropertyKey, JurisdictionCd,HistExemption, HistVal From conversionDB.AppraisalAccount aa where HistExemption = 'Y' /* and HistVal > 0 */;


insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)

select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('HT')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'HT') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', null) as calculationType,
      0 as localExemptionAmount,
      HistVal as exemptionAmount, -- State Amount
      HistVal as totalExemptionAmount,
      ifnull(HistExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(HistoricalExmBegDt <> '0' and left(HistoricalExmBegDt, 4) = laa.TaxYear and HistoricalExmBegDt <> concat(TaxYear, '0101'), true, false) or if(HistoricalExmEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and HistExemption = 'Y'
        /* and HistVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;


# This is exemption is *not* a true exemption, even though it reduces the taxable value.  This is a Chapter 313 Abatement.
select Hb1200Exemption, count(*) from conversionDB.AppraisalAccount group by Hb1200Exemption;
select TaxYear, PropertyKey, JurisdictionCd,Hb1200Exemption, Hb1200Val From conversionDB.AppraisalAccount aa where Hb1200Exemption = 'Y' /* and Hb1200Val > 0 */;





select FTZExemption, count(*) from conversionDB.AppraisalAccount group by FTZExemption;
select TaxYear, PropertyKey, JurisdictionCd,FTZExemption, FTZVal From conversionDB.AppraisalAccount aa where FTZExemption = 'Y' /* and FTZVal > 0 */;



insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)

select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('FTZ')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'FTZ') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', null) as calculationType,
      0 as localExemptionAmount,
      FTZVal as exemptionAmount, -- State Amount
      FTZVal as totalExemptionAmount,
      ifnull(FTZExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(FTZExmBegDt <> '0' and left(FTZExmBegDt, 4) = laa.TaxYear and FTZExmBegDt <> concat(TaxYear, '0101'), true, false) or if(FTZEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and FTZExemption = 'Y'
        /* and FTZVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;




select * from propertyAccountTaxingUnitExemptions order by pPropertyAccountTaxingUnitExemptionID desc;



select Min500Exemption, count(*) from conversionDB.AppraisalAccount group by Min500Exemption;
select TaxYear, PropertyKey, JurisdictionCd,Min500Exemption, Min500ExemptionPct, Min500Val From conversionDB.AppraisalAccount aa where Min500Exemption = 'Y' /* and Min500Val > 0 */; -- EX366



insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)

select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('EX366')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'EX366') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', null) as calculationType,
      0 as localExemptionAmount,
      Min500Val as exemptionAmount, -- State Amount
      Min500Val as totalExemptionAmount,
      ifnull(Min500ExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(Min500ExmBegDt <> '0' and left(Min500ExmBegDt, 4) = laa.TaxYear and Min500ExmBegDt <> concat(TaxYear, '0101'), true, false) or if(Min500EndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and Min500Exemption = 'Y'
        /* and Min500Val > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;




select PollutionConExemption, count(*) from conversionDB.AppraisalAccount group by PollutionConExemption;
select TaxYear, PropertyKey, JurisdictionCd,PollutionConExemption, PollutionConExemptionPct, PollutionControlVal From conversionDB.AppraisalAccount aa where PollutionConExemption = 'Y' /* and PollutionControlVal > 0 */; -- PC


insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)

select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('PC')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'PC') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', null) as calculationType,
      0 as localExemptionAmount,
      PollutionControlVal as exemptionAmount, -- State Amount
      PollutionControlVal as totalExemptionAmount,
      ifnull(PollutionConExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(PollutionConExmBegDt <> '0' and left(PollutionConExmBegDt, 4) = laa.TaxYear and PollutionConExmBegDt <> concat(TaxYear, '0101'), true, false) or if(PollutionControlExmEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and PollutionConExemption = 'Y'
        /* and PollutionControlVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;






select AbatementExemption, count(*) from conversionDB.AppraisalAccount group by AbatementExemption;
select TaxYear, PropertyKey, JurisdictionCd,AbatementExemption, AbatementExemptionPct, AbatementVal, SpecAbatementVal From conversionDB.AppraisalAccount aa where AbatementExemption = 'Y' /* and (AbatementVal > 0 or SpecAbatementVal > 0)*/; -- AB
-- Keep an eye out for records with SpecialAbatementVal!  If we run into one with a value there, we'll need to seek clarity from the client on what's different about that abatement!



insert into propertyAccountTaxingUnitExemptions (pPropertyAccountTaxingUnitID,
exemptionCode,
calculationType,
localExemptionAmount,
exemptionAmount,
totalExemptionAmount,
allocationFactor)

select
#   pYear,
#   pID,
#   pVersion,
#   pRollCorr,
#   taxingUnitID,
  pPropertyAccountTaxingUnitID,
  ec.exemptionCode,
  ct.calculationType,
  
  localExemptionAmount,
  exemptionAmount,
  totalExemptionAmount,
  allocationFactor

  
  
  from propertyAccountTaxingUnitTaxable tax
  join taxingUnit tu
    using (taxingUnitID)
  
  left join lateral (
    select
      exemptionCode
      from propertyAccountExemptions pae
      where
        pae.paccountID = tax.pAccountID
        and pae.exemptionCode in ('AB')
      limit 1
    ) as pae on true
    
      join lateral (
    select coalesce(convert(pae.exemptionCode using utf8mb4), 'AB') exemptionCode ) ec
    
  join lateral (
    select
      
      if(prorated, 'Prorated', null) as calculationType,
      0 as localExemptionAmount,
      AbatementVal as exemptionAmount, -- State Amount
      AbatementVal as totalExemptionAmount,
      ifnull(AbatementExemptionPct,1) * 100 as allocationFactor
      from conversionDB.AppraisalAccount laa
      
      join lateral ( select if(AbatementBegDt <> '0' and left(AbatementBegDt, 4) = laa.TaxYear and AbatementBegDt <> concat(TaxYear, '0101'), true, false) or if(AbatementEndDt <> '0', true, false) as prorated) prorated
      where
        laa.pYear = tax.pYear
        and laa.PropertyKey = tax.pID
        and laa.JurisdictionCd = tu.taxingUnitCode
        and AbatementExemption = 'Y'
        /* and AbatementVal > 0 */
      limit 1
    ) as laa
  
  join lateral (
    select concat_ws('-', ec.exemptionCode, calculationType) as calculationType
    ) ct

where not exists (
  select pPropertyAccountTaxingUnitExemptionID
  from propertyAccountTaxingUnitExemptions ex
  where ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
  and ex.exemptionCode = ec.exemptionCode
  and ex.calculationType = ct.calculationType
  and ex.localExemptionAmount = laa.localExemptionAmount
  and ex.exemptionAmount = laa.exemptionAmount
  and ex.totalExemptionAmount = laa.totalExemptionAmount
)
;





select MiscExemption, count(*) from conversionDB.AppraisalAccount group by MiscExemption;
select TaxYear, PropertyKey, JurisdictionCd,MiscExemption, MiscVal, SpecMiscExemptionVal From conversionDB.AppraisalAccount aa where MiscExemption = 'Y';
-- Keep an eye out for records with a MISC exemption!  If we run into one, we'll need to seek clarity from the client on what it represents!



select WaterConExemption, count(*) from conversionDB.AppraisalAccount group by WaterConExemption;
select TaxYear, PropertyKey, JurisdictionCd,WaterConExemption, WaterConExemptionPct, WaterConVal From conversionDB.AppraisalAccount aa where WaterConExemption = 'Y' /* and waterConVal > 0 */;
-- Keep an eye out for records with a WaterConExemption exemption!  If we run into one, we'll need to seek clarity from the client on what it represents!




-- Properties can have more than one DV, but the legacy system doesn't separate their exempt value by DV type - so we have to attribute the DV exemption value to the "best fit".
# Preview -- anything with an exemptionRank > 1 is going to have its value zero'd-out
with DVs as (
select
  pYear,
  pID,
  pVersion,
  pRollCorr,
  exemptionCode,
  count(*) over (partition by pPropertyAccountTaxingUnitID) as DVCount,
  rank() over (partition by pPropertyAccountTaxingUnitID order by exemptionRank, exemptionCode desc) as exemptionRank,
  totalExemptionAmount
from propertyAccountTaxingUnitExemptions ex
join propertyAccountTaxingUnitTaxable tax using (pPropertyAccountTaxingUnitID)
join lateral (
  select case exemptionCode
  when 'DV-UD' then 1
  when 'DVHS' then 2
  when 'DVHSS' then 3
  else 100
  end as exemptionRank
  ) er
where exemptionCode like 'DV%'
order by pPropertyAccountTaxingUnitID)

select *
  from DVs where DVcount > 1 and totalExemptionAmount > 0;
;


with DVs as (
select pPropertyAccountTaxingUnitExemptionID, exemptionCode,
       count(*) over (partition by pPropertyAccountTaxingUnitID) as DVCount,
  rank() over (partition by pPropertyAccountTaxingUnitID order by exemptionRank, exemptionCode desc) as exemptionRank,
  totalExemptionAmount
from propertyAccountTaxingUnitExemptions paetu
join lateral (
  select case exemptionCode
  when 'DV-UD' then 1
  when 'DVHS' then 2
  when 'DVHSS' then 3
  else 100
  end as exemptionRank
  ) er
where exemptionCode like 'DV%'
order by pPropertyAccountTaxingUnitID)

update
  propertyAccountTaxingUnitExemptions ex
join DVs
  using (pPropertyAccountTaxingUnitExemptionID)
set
  ex.localExemptionAmount = 0,
  ex.exemptionAmount = 0,
  ex.totalExemptionAmount = 0
where DVs.exemptionRank > 1;







drop temporary table if exists rankExemptions;

create temporary table rankExemptions
select
  pPropertyAccountTaxingUnitExemptionID,
  pPropertyAccountTaxingUnitID, exemptionCode, if(row_number() over ( partition by pPropertyAccountTaxingUnitID, exemptionCode order by totalExemptionAmount desc) = 1, true, false) as includeExemptionCount
from propertyAccountTaxingUnitExemptions ex
;

create index rankExemptions_idx on rankExemptions (pPropertyAccountTaxingUnitExemptionID);

# Preview
select *
from rankExemptions re
join propertyAccountTaxingUnitExemptions ex using (ppropertyAccountTaxingUnitExemptionID)
where re.includeExemptionCount <> ex.includeExemptionCount;


set sql_safe_updates = false;
update rankExemptions re
join propertyAccountTaxingUnitExemptions ex using (ppropertyAccountTaxingUnitExemptionID)
set ex.includeExemptionCount = re.includeExemptionCount
where re.includeExemptionCount <> ex.includeExemptionCount;
set sql_safe_updates = true;

drop temporary table if exists rankExemptions;

select includeExemptionCount, count(*)
from propertyAccountTaxingUnitExemptions
  group by includeExemptionCount;






-- Look for Exemption Discrepancies
with exemptionsInTaxables as (
select
  pa.pAccountID,
  p.pYear,
  p.pID,
  p.pVersion,
  p.pRollCorr,
  pa.ownerID,
  ex.exemptionCode
from property p
join propertyCurrent using (pYear, pID, pVersion, pRollCorr)
join propertyAccount pa using (pYear, pID, pVersion, pRollCorr)
join propertyTaxingUnit ptu using (pYear, pID, pVersion, pRollCorr)
join propertyAccountTaxingUnitTaxable tax using (pAccountID, pTaxingUnitID)
join propertyAccountTaxingUnitExemptions ex using (pPropertyAccountTaxingUnitID)
where not p.inactive
group by pAccountID, exemptionCode),

  exemptionsInPAE as (
                   select pa.pAccountID,
    p.pYear,
  p.pID,
  p.pVersion,
  p.pRollCorr,
  pa.ownerID,
  ex.exemptionCode
from property p
join propertyCurrent using (pYear, pID, pVersion, pRollCorr)
join propertyAccount pa using (pYear, pID, pVersion, pRollCorr)
join propertyAccountExemptions ex using (paccountID)
where not p.inactive

), allExemptions as (
  select * from exemptionsInPAE
union
select * from exemptionsInTaxables)


select *
from allExemptions a
left join lateral (
  select true as inTaxables
  from exemptionsInTaxables t
  where t.pAccountID = a.pAccountID and t.exemptionCode = a.exemptionCode
  ) t on true

left join lateral (
  select true as inPAE
  from exemptionsInPAE pae
  where pae.pAccountID = a.pAccountID and pae.exemptionCode = a.exemptionCode
  ) pae on true

where not t.inTaxables <=> pae.inPAE;



# Validate.  The only thing that should pop up here is a property in a jurisdiction with a Chapter 313 Abatement (since we aren't carrying that as an exemption)
select
  p.inactive,
  p.pYear,
  p.pID,
  p.pVersion,
  p.pRollCorr,
  p.propType,
  pa.ownerID,
  pa.ownerPct,
  tu.taxingUnitCode,
  tax.marketValue,
  tax.appraisedValue,
  tax.hsTaxLimitationValue,
  tax.cbTaxLimitationValue,
  tax.netAppraisedValue,
  ex.*,

  e.expectedExemptionValue,
  tax.taxableValue,
  e.expectedTaxableValue,
  legacy.*
  from property p
  join propertyAccount pa
    using (pYear, pID, pVersion, pRollCorr)
  join propertyTaxingUnit ptu
    using (pYear, pID, pVersion, pRollCorr)
  join taxingUnit tu
    using (taxingUnitID)
  join propertyAccountTaxingUnitTaxable tax
    using (pTaxingUnitID, pAccountID)
  join lateral (
    select
      count(*) as exemptionRecords,
      group_concat(distinct exemptionCode order by exemptionCode) as exemptionCodes,
      ifnull(sum(ex.localExemptionAmount),0) as localExemptionAmount,
      ifnull(sum(ex.exemptionAmount),0) as stateExemptionAmount,
      ifnull(sum(ex.totalExemptionAmount),0) as totalExemptionAmount,
      json_arrayagg(
      json_object(
        'exemptionCode', ex.exemptionCode,
        'calculationType',ex.calculationType,
        'localExemptionAmount', ex.localExemptionAmount,
        'exemptionAmount', ex.exemptionAmount,
        'totalExemptionAmount', ex.totalExemptionAmount
      )
      ) as exemptionDetails
      from propertyAccountTaxingUnitExemptions ex
      where
        ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
    ) ex
    join lateral (
    select netAppraisedValue - tax.taxableValue as expectedExemptionValue,
           netAppraisedValue - ex.totalExemptionAmount as expectedTaxableValue
    ) e
    join lateral (
      select
        exq.*,
        DVExemptionCd,
        LocalGenHomesteadVal, StateGenHomesteadVal,
        LocalOver65Val, StateOver65Val, LocalOver65SurvivingSpouseVal, StateOver65SurvivingSpouseVal,
        LocalDPVal,StateDPVal , LocalDisabledSurvivingSpouseVal , StateDisabledSurvivingSpouseVal ,
        DVVal,
        AbsVal,
        FreeportVal,
        GoodsInTransitVal,
        SolarWindVal,
        HistVal ,
        Hb1200Val ,
        FTZVal ,
        Min500Val,
        PollutionControlVal ,
        AbatementVal , SpecAbatementVal ,
        MiscVal , SpecMiscExemptionVal ,
        WaterConVal
      from conversionDB.AppraisalAccount aa
      join lateral (
        select group_concat(exq.exemptionCode order by exq.exemptionCode) as exemptionCodes
        from conversionDB.AccountJurisdictionExQualify exq
        where exq.pYear = tax.pyear and exq.PropertyKey = tax.pID
        ) exq
      where aa.pYear = tax.pYear and aa.PropertyKey = tax.pID and aa.JurisdictionCd = tu.taxingUnitCode
    ) legacy
  where
    not p.inactive
    and e.expectedTaxableValue <> tax.taxableValue

# and aa.pYear > 2020
#  and PropertyKey = 1518 -- great sample!  Ag, Timber, and an HS Cap!
#  and PropertyKey in (16796,13081,93377) -- Ronnie says these properties have CBs
# and limitationValue <> HomesiteCapLossVal and HomesiteCapLossVal > 0 -- Potentially, CB and HB Caps
# and TotalAppraisedVal <> calcs.appraisedValue - calcs.limitationValue -- Look for bad calcs
# and calcs.netAppraisedValue - legacyExemptionValue <> totaltaxableVal -- Look for more bad calcs
# and RestrictedUseTimberProdVal > 0  -- Probably Timber 78, but there are no matches.  Woohoo!

  order by marketValue desc
;












# Look for instances where we have a missing owner and/or missing taxing unit association
select
  pAccountID,
  pTaxingUnitID,
  
  pYear,
  PropertyKey as pID,
  0 as pVersion,
  0 as pRollCorr,
 
  if(ownerPct <> 100, true, false) as isUDI,
  ownerKey as ownerID,
  
  ownerPct,
  
  taxingUnitID,
  taxingUnitPct,
  JurisdictionCd,
  
  aa.TotalMarketVal as marketValue
FROM conversionDB.AppraisalAccount aa


left join lateral (
  select pa.pAccountID, pa.ownerPct
  from propertyAccount pa
  where pa.pyear = aa.pyear
  and pa.pID = aa.PropertyKey
  and pa.pVersion = 0
  and pa.pRollCorr = 0
  and pa.ownerID = aa.ownerKey
  ) pa on true

  
left join lateral (
  select ptu.pTaxingUnitID, ptu.jurisdictionPct as taxingUnitPct, ptu.taxingUnitID, ifnull(rates.totalTaxRate,0) as totalTaxRate

  from propertyTaxingUnit ptu
  join taxingUnit tu using (taxingUnitID)
  left join lateral (
    select totalTaxRate
    from taxingUnitVersion tuv
    join taxingUnitTaxRates rates using (versionID)
    where tuv.taxingUnitID = ptu.taxingUnitID
    and tuv.taxingUnitYr = aa.pyear
    order by active desc
    limit 1
    ) rates on true
  where ptu.pyear = aa.pyear
  and ptu.pID = aa.PropertyKey
  and ptu.pVersion = 0
  and ptu.pRollCorr = 0
  and tu.taxingUnitCode = aa.JurisdictionCd
  ) ptu on true

where ptu.ptaxingUnitID is null or pa.paccountID is null;