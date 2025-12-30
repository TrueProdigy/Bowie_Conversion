set @createDt = now();
set @createdBy = 'TPConversion - insertFeature';

set @pYearMin = 2020;
set @pYearMax = 2025;

set @p_user = 'TP Conversion';


# CREATE INDEX idx_id
# ON conversionDB.AppraisalImprovementFeature (TaxYear, PropertyKey, ImprovementSeq);
truncate improvementDetailFeature;

insert into improvementDetailFeature (
pDetailID,
pid,
pYear,
pVersion,
pRollCorr,
modelFeatureCodeID,
featurePresent,
#imprvDescription,
createdBy,
createDt
)
SELECT
     dt.pDetailID,
     p.pid,
     p.pYear,
     p.pVersion,
     p.pRollCorr,
     fc.modelFeatureCodeID,
     1,
     @createdBy,
     NOW()
FROM conversionDB.AppraisalImprovement ai
STRAIGHT_JOIN property p
    ON p.pYear = ai.TaxYear
   AND p.pid   = ai.PropertyKey
STRAIGHT_JOIN valuationsPropAssoc vpa
    ON vpa.pid       = p.pid
   AND vpa.pYear     = p.pYear
   AND vpa.pRollCorr = p.pRollCorr
   AND vpa.pVersion  = p.pVersion
JOIN valuationsCostApproach vca
    USING (pValuationID)
JOIN improvement i
    USING (pCostID)

-- LATERAL to pick ONE improvement detail row
JOIN LATERAL (
        SELECT d.pDetailID
        FROM improvementDetail d
        WHERE TRIM(d.imprvDetailType) in ('LA')
          AND d.pImprovementID = i.pImprovementID
        LIMIT 1
    ) dt
JOIN conversionDB.AppraisalImprovementFeature aif
    ON aif.TaxYear        = ai.TaxYear
   AND aif.PropertyKey    = ai.PropertyKey
   AND aif.ImprovementSeq = ai.ImprovementSeq
-- LEFT LATERAL JOIN for featureCodes (select exactly 1 match)
LEFT JOIN LATERAL (
        SELECT fc.featureCodeID AS modelFeatureCodeID
        FROM bowie_appraisal.featureCodes fc
        WHERE fc.featureCode = aif.ImprovementFeatureCode
        LIMIT 1
    ) fc ON TRUE
where ai.TaxYear between @pYearMin and @pYearMax;



select *
from improvementDetailFeature
where pYear = 2025
and pID = 48681;