set @createDt = now();
set @createdBy = 'TPConversion - insertLand';

set @pYearMin = 2020;
set @pYearMax = 2020;

set @p_user = 'TP Conversion';

# set foreign_key_checks = 0;
#     truncate land;
#     truncate landAdjustments;
# set foreign_key_checks = 1;

## do one year at a time. change pYearMax. consider updating sequence and segment id after load.
DROP TABLE IF EXISTS modelLand;
CREATE TABLE modelLand AS
(
    SELECT
        modelYr,
        modelACID,
        mktClass as class,
        'AC' AS modelType
    FROM modelLandAC

    UNION ALL

    SELECT
        modelYr,
        modelLotID AS modelACID,   -- adjust if the ID name differs
        mktClass as class,
        'LOT' AS modelType
    FROM modelLandLot

    UNION ALL

    SELECT
        modelYr,
        modelAgID AS modelACID,
        agClass as class,
        'AG' AS modelType
    FROM modelLandAG

    UNION ALL

    SELECT
        modelYr,
        modelFFID AS modelACID,
        mktClass,
        'FF' AS modelType
    FROM modelLandFF

    UNION ALL

    SELECT
        modelYr,
        modelTimID AS modelACID,
        timClass as class,
        'TIM' AS modelType
    FROM modelLandTIM
);

INSERT INTO land (
    pCostID,
    pID,
    pYear,
    pVersion,
    pRollCorr,
    landType,
    sequence,
    stateCd,
    class,
    homesite,
#     homesiteOverride,
#     homesitePct,
#     influence,
#     landDescription,
#     sizeSqft,
#     sizeUseableSqft,
    sizeAcres,
#     sizeUseableAcres,
    sizeLot,
#     sizeEffectiveFront,
#     sizeWidthFront,
#     sizeWidthBack,
#     sizeEffectiveDepth,
#     sizeDepthRight,
#     sizeDepthLeft,
    effectiveGroupAcresOverride,
    sizeEffectiveGroupAcresOverride,
#     effectiveGroupSqftOverride,
#     sizeEffectiveGroupSqftOverride,
    mktMethod,
    mktModel,
    mktUnitPriceSelection,
    mktModelUnitPrice,
    mktSpecialUnitPrice,
#     mktEconomicAdj,
#     mktEconomicNote,
#     mktFunctionalAdj,
#     mktFunctionalNote,
#     mktPhysicalAdj,
#     mktPhysicalNote,
    mktLandModifier,
    applyLandAreaModifier,
    mktLandAreaModifier,
    mktCalculatedValue,
    mktAdjValue,
    mktFlatValue,
    mktFlatValueNote,
    mktValueMethod,
    mktValue,
#     mktNewValueIndicator,
#     mktNewValue,
#     mktNewValueOverride,
#     mktNewValueYear,
#     mktNewHSValue,
#     mktNewNHSValue,
    suApply,
    suUseCd,
#     suApplyYr,
#     suLate,
    suType,
#     suSoilType,
    suModel,
#     suMethod,
    suUnitPriceSelection,
    suModelUnitPrice,
    suSpecialUnitPrice,
    suValueMethod,
    suCalculatedValue,
    suFlatValue,
    suValue,
#     suExclusionValue,
#     suNewValueIndicator,
#     suNewValue,
#     suNewValueOverride,
#     suNewValueYear,
#     suConvertDt,
#     su78Value,
#     su78ValuePct,
    suRestrictedUse,
    suRestrictedUseValue,
    suPreRestrictedUseValue,
    suHarvestDt,
    suPrevType,
    createdBy,
    createDt,
    updatedBy,
    updateDt,
    recalcDt,
    recalcBy,
    fromLandID,
    -- calcAdjustmentFactor,
    calcAdjustmentAmount,
    calcLandHSValue,
    calcLandNHSValue,
    calcSULandMktValue,
    legacyValue,
#     historyID,
#     legacyJSON,
#     timberLandMktValue,
#     timberValue,
#     timberExclusionValue,
#     agLandMktValue,
#     agValue,
#     agExclusionValue,
#     timberNewValue,
#     agNewValue,
#     timber78LandMktValue,
#     timber78Value,
#     timber78ExclusionValue,
#     timber78NewValue,
    segmentID
)
SELECT
    vca.pCostID as pCostID,
    p.pid as pID,
    p.pYear as pYear,
    p.pVersion as pVersion,
    p.pRollCorr as pRollCorr,
    NULL as landType,
    al.DWLNDSEQ as sequence,
    al.PropUse as stateCd,
    cf.codeName as class,
    CASE WHEN al.DWHOMSITE = 'N' THEN 0 ELSE 1 END as homesite,
#     NULL as homesiteOverride,
#     NULL as homesitePct,
#     NULL as influence,
#     NULL as landDescription,
#     ld.LandSize * 43560 as sizeSqft,
#     NULL as sizeUseableSqft,
    CASE WHEN ml.modelType = 'AC' then ld.LandSize
    else null end as sizeAcres,
    CASE WHEN ml.modelType = 'LOT' then 1 else null end as sizeLot,
#     NULL as sizeEffectiveFront,
#     NULL as sizeWidthFront,
#     NULL as sizeWidthBack,
#     NULL as sizeEffectiveDepth,
#     NULL as sizeDepthRight,
#     NULL as sizeDepthLeft,
    CASE WHEN cp.TotalAcresForPricing > 0.000 THEN 1 ELSE 0 END as effectiveGroupAcresOverride,
    cp.TotalAcresForPricing as sizeEffectiveGroupAcresOverride,
#     NULL as effectiveGroupSqftOverride,
#     NULL as sizeEffectiveGroupSqftOverride,
    ml.modelType as mktMethod,
    ml.modelACID as mktModel,
    'T' mktUnitPriceSelection,
    al.DWMUNIT as mktModelUnitPrice,
    NULL as mktSpecialUnitPrice,
#     NULL as mktEconomicAdj,
#     NULL as mktEconomicNote,
#     NULL as mktFunctionalAdj,
#     NULL as mktFunctionalNote,
#     NULL as mktPhysicalAdj,
#     NULL as mktPhysicalNote,
    DWMFACTOR as mktLandModifier,
    1  applyLandAreaModifier,
    1.00 as mktLandAreaModifier,
    al.DWMCALC as mktCalculatedValue,
    al.DWMCALC as mktAdjValue,
    al.MarketFlatValue as mktFlatValue,
    NULL as mktFlatValueNote,
    CASE WHEN al.MarketFlatValue > 0 THEN 'F' ELSE 'A' END as mktValueMethod,
    al.DWMVALUE as mktValue,
#     NULL as mktNewValueIndicator,
#     NULL as mktNewValue,
#     NULL as mktNewValueOverride,
#     NULL as mktNewValueYear,
#     NULL as mktNewHSValue,
#     NULL as mktNewNHSValue,
    CASE WHEN al.DWACALC > 0.00 THEN 1 ELSE 0 END as suApply,
    CASE
        WHEN sut.codeFileName = 'Timber Class' THEN 'TIM'
        WHEN sua.codeFileName = 'Ag Class' THEN '1D'
        ELSE NULL
    END as suUseCd,
#     NULL as suApplyYr,
#     NULL as suLate,
    am.class as suType,
#     NULL as suSoilType,
    am.modelACID as suModel,
#     am.class as suMethod,
    CASE WHEN al.DWAUNIT > 0 THEN 'T' ELSE NULL END as suUnitPriceSelection,
    al.DWAUNIT as suModelUnitPrice,
    NULL as suSpecialUnitPrice,
    Case when al.DWACALC > 0.00 then 'C'
         when al.DWAFLAT > 0.00 then 'F'
        else null  end as suValueMethod,
    al.DWACALC as suCalculatedValue,
    al.DWAFLAT as suFlatValue,
    al.DWAVALUE as suValue,
#     NULL as suExclusionValue,
#     NULL as suNewValueIndicator,
#     NULL as suNewValue,
#     NULL as suNewValueOverride,
#     NULL as suNewValueYear,
#     NULL as suConvertDt,
#     NULL as su78Value,
#     NULL as su78ValuePct,
    CASE WHEN al.DWRTIMBER = 'T' THEN 1 ELSE 0 END as suRestrictedUse,
    CASE WHEN al.DWRTIMBER = 'T' THEN ld.RestrictedUseTimberUnitValue ELSE 0 END as suRestrictedUseValue,
    NULL as suPreRestrictedUseValue,
    NULL as suHarvestDt,
    am.class as suPrevType,
    @createdBy as createdBy,
    @createDt as createDt,
    NULL as updatedBy,
    NULL as updateDt,
    NULL as recalcDt,
    NULL as recalcBy,
    NULL as fromLandID,
-- 1.00 + al.DWMFACTOR as calcAdjustmentFactor,
    null as calcAdjustmentAmount,
    case  WHEN al.DWHOMSITE = 'N' THEN 0 else al.DWMCALC end as calcLandHSValue,
    case  WHEN al.DWHOMSITE = 'Y' THEN 0 else al.DWMCALC end as calcLandNHSValue,
    NULL as calcSULandMktValue,
    CASE
        WHEN al.DWMSOURCE = 'C' THEN al.DWMCALC
        WHEN al.DWMSOURCE = 'O' THEN al.DWMOVER
        ELSE NULL
    END as legacyValue,
#     NULL as historyID,
#     NULL as legacyJSON,
#     NULL as timberLandMktValue,
#     NULL as timberValue,
#     NULL as timberExclusionValue,
#     NULL as agLandMktValue,
#     NULL as agValue,
#     NULL as agExclusionValue,
#     NULL as timberNewValue,
#     NULL as agNewValue,
#     NULL as timber78LandMktValue,
#     NULL as timber78Value,
#     NULL as timber78ExclusionValue,
#     NULL as timber78NewValue,
    NULL as segmentID
#     NULL as suNewPriorYearMarketOverride,
#     NULL as suNewPriorYearMarketOverrideValue
FROM conversionDB.AppraisalLand al
STRAIGHT_JOIN property p
 ON al.TaxYear    = p.pYear
 AND al.PropertyKey = p.pid
STRAIGHT_JOIN valuationsPropAssoc vpa
  ON vpa.pid = p.pid
 AND vpa.pYear     = p.pYear
 AND vpa.pRollCorr = p.pRollCorr
 AND vpa.pVersion  = p.pVersion
STRAIGHT_JOIN valuationsCostApproach vca USING (pValuationID)
STRAIGHT_JOIN conversionDB.LandDetail ld FORCE INDEX (idx_landdetail_year_prop_seq)
  ON ld.AuditTaxYear = al.TaxYear
 AND ld.PropertyKey  = al.PropertyKey
 AND ld.LNDSEQ       = al.DWLNDSEQ
STRAIGHT_JOIN conversionDB.Property cp
 ON cp.AuditTaxYear = al.TaxYear
 AND cp.PropertyKey = al.PropertyKey
STRAIGHT_JOIN codefile cf
  ON cf.codeFileYear = al.TaxYear
 AND cf.codeFileType = 'Land'
 AND cf.codeFileName = 'Market Class'
 AND cf.codeName     = al.MarketClass
LEFT JOIN codefile sut
  ON sut.codeFileYear = al.TaxYear
 AND sut.codeFileType = 'Land'
 AND TRIM(sut.codeName) = TRIM(al.DWACLASS)
 AND sut.codeFileName = 'Timber Class'
LEFT JOIN codefile sua
  ON sua.codeFileYear = al.TaxYear
 AND sua.codeFileType = 'Land'
 AND TRIM(sua.codeName) = TRIM(al.DWACLASS)
 AND sua.codeFileName = 'Ag Class'
LEFT JOIN codefile sum
  ON sum.codeFileYear = al.TaxYear
 AND sum.codeFileType = 'Land'
 AND sum.codeFileName = 'Ag Type'
 AND TRIM(sum.codeName) = TRIM(al.DWACLASS)
LEFT JOIN modelLand am
 on TRIM(am.class) = TRIM(al.DWACLASS)  -- TRIM both
   AND am.modelYr = al.TaxYear
LEFT JOIN modelLand ml
 ON ml.class = al.MarketClass
 AND ml.modelYr = al.TaxYear
WHERE
    al.TaxYear = @pYearMax;
    -- and al.PropertyKey = 25707;

# set @createDt = now();
# set @createdBy = 'TPConversion - insertLand';
#
# set @pYearMin = 2020;
# set @pYearMax = 2025;
#
# set @p_user = 'TPConversion - insertLand';
insert into landAdjustments (
        pLandID,
        modelAdjustID,
        adjustPct,
        createdBy,
        pid,
        pYear,
        pVersion,
        pRollCorr
        )
select
l.pLandID
,2760
,100 * al.DWMFACTOR
 ,@p_user
,pid
,pYear
,pVersion
,pRollCorr
from conversionDB.AppraisalLand al
join land l
on l.pYear = al.TaxYear
and l.pID = al.PropertyKey
  and l.sequence = al.DWLNDSEQ
where al.TaxYear = @pYearMax
and al.DWMFACTOR < 1.00
;


#
# set @createDt = now();
# set @createdBy = 'TPConversion - insertLand';
#
# set @pYearMin = 2020;
# set @pYearMax = 2025;
#
# set @p_user = 'TP Conversion';
# update land
# set mktPhysicalAdj = null
# where segmentID = 32848;
# SET @current_pid := NULL;
# SET @seq := 0;
#
#
# UPDATE land l
# join modelLand ml
# on ml.class = l.class
# and ml.modelYr = l.pYear
# set l.mktModel = ml.modelACID
# where l.pYear = 2025;
#
# select *
# from modelAdjustments
# where pid = 25707
#
# select *
# from land
# where pID = 25707;
#
# select al.*
# from conversionDB.AppraisalLand al
# where al.TaxYear = 2025
# -- and al.DWMFACTOR < 1.00
# and al.PropertyKey = 25707;
#
# select l.pLandID
#    ,l.segmentID
#    ,al.*
# from conversionDB.AppraisalLand al
# join land l
# on l.pYear = al.TaxYear
# and l.pID = al.PropertyKey
# and l.sequence = al.DWLNDSEQ
# where al.TaxYear = 2025
# and l.calcAdjustmentFactor > 0
# and al.DWMFACTOR < 1.00
# and al.PropertyKey = 25707

#update suType and suPrevType
# set @p_user = 'TP Conversion';
# UPDATE land l
# left join codefile st
# on st.codeName = l.suType
# and st.codeFileYear = l.pYear
# and st.codeFileType = 'Land'
# left join codefile pt
# on pt.codeName = l.suPrevType
# and pt.codeFileYear = l.pYear
# and pt.codeFileType = 'Land'
# SET l.suType = TRIM(st.codeName),
#     l.suPrevType = TRIM(pt.codeName),
#     l.updatedBy  = @p_user
# WHERE (l.suPrevType IS NOT NULL AND l.suPrevType <> TRIM(l.suPrevType))
#    OR (l.suType     IS NOT NULL AND l.suType     <> TRIM(l.suType));
#
# SELECT
#     al.DWACLASS
# ,ml.*
# FROM land l
# JOIN conversionDB.AppraisalLand al
#     ON al.TaxYear    = l.pYear
#    AND al.PropertyKey = l.pID
#    AND al.DWLNDSEQ    = l.sequence
# left join modelLand ml
# ON TRIM(ml.class) = TRIM(al.DWACLASS)  -- TRIM both
#    AND ml.modelYr = l.pYear
# WHERE l.pYear = 2025
#   AND l.pID   = 25703
#   AND al.DWACLASS = 'A*R1';

# select *
# from land
# where pYear = 2025
# and pID = 25703

# describe modelLandLot;


# set @p_user = 'TP Conversion';
# INSERT INTO modelLandLot (
# modelYr,
# mktClass,
# unitPrice,
# createdBy,
# createDt,
# fromModelLotID
# )
# SELECT
# modelYr - 1        AS modelYr,
# mktClass,
# unitPrice,
# @p_user,
# NOW(),
# fromModelLotID
# FROM modelLandLot
# WHERE modelYr = 2021;
#
# select *
# from modelLandLot;



