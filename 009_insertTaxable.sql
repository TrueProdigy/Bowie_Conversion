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



# set sql_safe_updates = 0;
# set @p_skipTrigger = 0;
# truncate propertyAccountTaxingUnitStateAgBreakdown;
# truncate propertyAccountTaxingUnitStateCodeValue;
# delete from propertyAccountTaxingUnitTaxable;

insert ignore into propertyAccountTaxingUnitTaxable (pid,
                                                     pYear,
                                                     pVersion,
                                                     pRollCorr,
                                                     ownerID,
                                                     ownerPct,
                                                     pAccountID,
                                                     pTaxingUnitID,
                                                     taxingUnitID,
                                                     taxableValue,
                                                     actualTax,
                                                     legacyTaxableValue,
                                                     appraisedValue,
                                                     isUDI,
                                                     taxingUnitPct,
                                                     suValue,
                                                     suLandMktValue,
                                                     timberLandMktValue,
                                                     timberValue,
                                                     timberExclusionValue,
                                                     improvementHSValue,
                                                     improvementNHSValue,
                                                     newImprovementHSValue,
                                                     newImprovementNHSValue,
                                                     landHSValue,
                                                     landNHSValue,
                                                     newLandHSValue,
                                                     newLandNHSValue,
                                                     newBppValue,
                                                     agLandMktValue,
                                                     agValue,
                                                     agExclusionValue,
                                                     suExclusionValue,
                                                     marketValue,
                                                     totalTaxRate,
                                                     netAppraisedValue,
                                                     createDt)
select pa.pid
     , pa.pYear
     , pa.pVersion
     , pa.pRollCorr
     , ownerID
     , ownerPct
     , pAccountID
     , pTaxingUnitID
     , taxingUnitID
     , aa.TotalTaxableVal                                                        AS taxableValue
     , aa.TotalTaxLevy                                                           AS actualTax
     , aa.TotalTaxableVal                                                        AS legacyTaxableValue
     , aa.TotalAppraisedVal                                                      AS appraisedValue
     , case
           when aa.UndividedIntFrac < 1.0000
               then 1
           else 0
       end                                                                       as isUDI
     , ptu.jurisdictionPct                                                       AS taxingUnitPct
     , COALESCE(aa.TimberLandProdVal, 0) + COALESCE(aa.AgLandProdVal, 0)         AS suValue
     , COALESCE(aa.TimberLandMarketVal, 0) + COALESCE(aa.AgLandMarketVal, 0)     AS suLandMktValue
     , aa.TimberLandMarketVal                                                    AS timberLandMktValue
     , aa.TimberLandProdVal                                                      AS timberValue
     , COALESCE(aa.TimberLandMarketVal, 0) - COALESCE(aa.TimberLandProdVal, 0)   AS timberExclusionValue
     , aa.HomesiteImprovementVal                                                 AS improvementHSValue
     , aa.OtherImprovementVal                                                    AS improvementNHSValue
     , aa.HomesiteNewImprovementVal                                              AS newImprovementHSValue
     , aa.OtherNewImprovementVal                                                 AS newImprovementNHSValue
     , aa.HomesiteLandVal                                                        AS landHSValue
     , aa.OtherLandVal                                                           AS landNHSValue
     , aa.HomesiteNewLandVal                                                     AS newLandHSValue
     , aa.OthNewTaxableLandVal                                                   AS newLandNHSValue
     , COALESCE(aa.OtherNewPersonalVal, 0) + COALESCE(aa.HomesitePersonalVal, 0) AS newBppValue
     , aa.AgLandMarketVal                                                        AS agLandMktValue
     , aa.AgLandProdVal                                                          AS agValue
     , COALESCE(aa.AgLandMarketVal, 0) - COALESCE(aa.AgLandProdVal, 0)           AS agExclusionValue
     , aa.ProductivityLossVal                                                    AS suExclusionValue
     , aa.TotalMarketVal                                                         AS marketValue
     ,CAST(aj.TotalTaxRate AS DECIMAL(9,6))                                      AS totalTaxRate
     ,CASE when aa.LimitedAppraisedVal > 0
         then aa.LimitedAppraisedVal
        else aa.TotalTaxableVal end                                              AS netAppraisedValue
     , @createDt
from
    propertyAccount pa
        join propertyTaxingUnit ptu
            on pa.pYear = ptu.pYear
            and pa.pid = ptu.pid
            and pa.pRollCorr = ptu.pRollCorr
            and pa.pVersion = ptu.pVersion
        join taxingUnit tu
            using (taxingUnitID)
        join conversionDB.AppraisalAccount aa
            on aa.pYear = pa.pYear -- Added an indexed, int pYear column to AppraisalAccount to speed this up! -- CCM
        and aa.PropertyKey = pa.pid
        and aa.JurisdictionCd = tu.taxingUnitCode
        join conversionDB.AppraisalJurisdiction aj
            on aj.TaxYear = pa.pYear
        and aj.JurisdictionCd = aa.JurisdictionCd

where pa.pYear between @pYearMin and @pYearMax;



/*
# The original (commented) approach here worked, but building the table via unions, pre-insert, meant redoing *everything* if any snags were hit.  I opted to split it up by exemption type to allow for easier troubleshooting/debugging.
# The approach that follows (under the commented bit) also includes logic for specifying calculationType and for proration.
-- Chris, 2026-01-13


CREATE TABLE IF NOT EXISTS join_tu_u8 (
  taxingUnitID INT PRIMARY KEY,
  code_u8 VARCHAR(10)
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci,
  KEY idx_code_u8 (code_u8)
) ENGINE=InnoDB;

-- refresh (safe to re-run)
REPLACE INTO join_tu_u8 (taxingUnitID, code_u8)
SELECT t.taxingUnitID,
       CONVERT(t.taxingUnitCode USING utf8mb4) COLLATE utf8mb4_0900_ai_ci
FROM taxingUnit AS t;


insert into propertyAccountTaxingUnitExemptions (
	pPropertyAccountTaxingUnitID,
	exemptionCode,
	allocationFactor,
    exemptionAmount,
	localExemptionAmount,
	totalExemptionAmount,
	includeExemptionCount)
-- HS
SELECT patt.pPropertyAccountTaxingUnitID
     , 'HS'                                        as exemptionCode
     , GenHSExemptionPct                           as allocationFactor
     , StateGenHomesteadVal                        as exemptionAmount
     , LocalGenHomesteadVal                        as localExemptionAmount
     , StateGenHomesteadVal + LocalGenHomesteadVal as totalExemptionAmount
     , true                                        as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  AND GenHSExemption = 'Y'

UNION ALL
-- EX-AB
SELECT patt.pPropertyAccountTaxingUnitID
     , 'EX-AB'            as exemptionCode
     , aa.AbsExemptionPct as allocationFactor
     , aa.AbsVal          as exemptionAmount
     , null               as localExemptionAmount
     , aa.AbsVal          as totalExemptionAmount
     , true               as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.AbsExemption = 'Y'

UNION ALL
-- OV65
SELECT patt.pPropertyAccountTaxingUnitID
     , 'OV65'                          as exemptionCode
     , Ov65ExemptionPct                as allocationFactor
     , StateOver65Val                  as exemptionAmount
     , LocalOver65Val                  as localExemptionAmount
     , StateOver65Val + LocalOver65Val as totalExemptionAmount
     , true                            as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  AND aa.Ov65Exemption = 'Y'

UNION ALL
-- OV65S
SELECT patt.pPropertyAccountTaxingUnitID
     , 'OV65S'                                                       as exemptionCode
     , Ov65SSExemptionPct                                            as allocationFactor
     , StateOver65SurvivingSpouseVal                                 as exemptionAmount
     , LocalOver65SurvivingSpouseVal                                 as localExemptionAmount
     , StateOver65SurvivingSpouseVal + LocalOver65SurvivingSpouseVal as totalExemptionAmount
     , true                                                          as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  AND Ov65SSExemption = 'Y'

UNION ALL
-- DP
SELECT patt.pPropertyAccountTaxingUnitID
     , 'DP'                    as exemptionCode
     , DPExemptionPct          as allocationFactor
     , StateDPVal              as exemptionAmount
     , LocalDPVal              as localExemptionAmount
     , StateDPVal + LocalDPVal as totalExemptionAmount
     , true                    as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  AND DPExemption = 'Y'

UNION ALL
-- DPS
SELECT patt.pPropertyAccountTaxingUnitID
     , 'DPS'                                                             as exemptionCode
     , DSSExemptionPct                                                   as allocationFactor
     , StateDisabledSurvivingSpouseVal                                   as exemptionAmount
     , LocalDisabledSurvivingSpouseVal                                   as localExemptionAmount
     , StateDisabledSurvivingSpouseVal + LocalDisabledSurvivingSpouseVal as totalExemptionAmount
     , true                                                              as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  AND (DSSExemption = 'Y')

UNION ALL
-- DV-UD
SELECT patt.pPropertyAccountTaxingUnitID
     , 'DV-UD'         as exemptionCode
     , DVExemptionPct as allocationFactor
     , DVVal          as exemptionAmount
     , null           as localExemptionAmount
     , DVVal          as totalExemptionAmount
     , true           as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.DVExemptionCd = '31'

UNION ALL
-- DVHS
SELECT patt.pPropertyAccountTaxingUnitID
     , 'DVHS'         as exemptionCode
     , DVExemptionPct as allocationFactor
     , DVVal          as exemptionAmount
     , null           as localExemptionAmount
     , DVVal          as totalExemptionAmount
     , true           as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.DVExemptionCd in ('HS', '11', 'XHDV')

UNION ALL
-- DV1
SELECT patt.pPropertyAccountTaxingUnitID
     , 'DV1'          as exemptionCode
     , DVExemptionPct as allocationFactor
     , DVVal          as exemptionAmount
     , null           as localExemptionAmount
     , DVVal          as totalExemptionAmount
     , true           as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.DVExemptionCd in ('01')

UNION ALL
-- DV3
SELECT patt.pPropertyAccountTaxingUnitID
     , 'DV3'          as exemptionCode
     , DVExemptionPct as allocationFactor
     , DVVal          as exemptionAmount
     , null           as localExemptionAmount
     , DVVal          as totalExemptionAmount
     , true           as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.DVExemptionCd in ('05')

UNION ALL
-- DV4
SELECT patt.pPropertyAccountTaxingUnitID
     , 'DV4'          as exemptionCode
     , DVExemptionPct as allocationFactor
     , DVVal          as exemptionAmount
     , null           as localExemptionAmount
     , DVVal          as totalExemptionAmount
     , true           as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.DVExemptionCd in ('07')

UNION ALL
-- DVHSS
SELECT patt.pPropertyAccountTaxingUnitID
     , 'DVHSS'        as exemptionCode
     , DVExemptionPct as allocationFactor
     , DVVal          as exemptionAmount
     , null           as localExemptionAmount
     , DVVal          as totalExemptionAmount
     , true           as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.DVExemptionCd in ('41')

UNION ALL
-- DV0-UD
SELECT patt.pPropertyAccountTaxingUnitID
     , 'DV0-UD'       as exemptionCode
     , DVExemptionPct as allocationFactor
     , DVVal          as exemptionAmount
     , null           as localExemptionAmount
     , DVVal          as totalExemptionAmount
     , true           as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.DVExemptionCd in ('00')

UNION ALL
-- DV2
SELECT patt.pPropertyAccountTaxingUnitID
     , 'DV2'          as exemptionCode
     , DVExemptionPct as allocationFactor
     , DVVal          as exemptionAmount
     , null           as localExemptionAmount
     , DVVal          as totalExemptionAmount
     , true           as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.DVExemptionCd in ('03')

UNION ALL
-- DV1S
SELECT patt.pPropertyAccountTaxingUnitID
     , 'DV1S'         as exemptionCode
     , DVExemptionPct as allocationFactor
     , DVVal          as exemptionAmount
     , null           as localExemptionAmount
     , DVVal          as totalExemptionAmount
     , true           as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.DVExemptionCd in ('21')

UNION ALL
-- DV2S
SELECT patt.pPropertyAccountTaxingUnitID
     , 'DV2S'         as exemptionCode
     , DVExemptionPct as allocationFactor
     , DVVal          as exemptionAmount
     , null           as localExemptionAmount
     , DVVal          as totalExemptionAmount
     , true           as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.DVExemptionCd in ('23')

UNION ALL
-- DV3S
SELECT patt.pPropertyAccountTaxingUnitID
     , 'DV3S'         as exemptionCode
     , DVExemptionPct as allocationFactor
     , DVVal          as exemptionAmount
     , null           as localExemptionAmount
     , DVVal          as totalExemptionAmount
     , true           as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.DVExemptionCd in ('25')

UNION ALL
-- DV4S
SELECT patt.pPropertyAccountTaxingUnitID
     , 'DV4S'         as exemptionCode
     , DVExemptionPct as allocationFactor
     , DVVal          as exemptionAmount
     , null           as localExemptionAmount
     , DVVal          as totalExemptionAmount
     , true           as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.DVExemptionCd in ('27')

UNION ALL
-- FR
SELECT patt.pPropertyAccountTaxingUnitID
     , 'FR'                 as exemptionCode
     , FreeportExemptionPct as allocationFactor
     , FreeportVal          as exemptionAmount
     , null                 as localExemptionAmount
     , FreeportVal          as totalExemptionAmount
     , true                 as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.FreeportExemption = 'Y'

UNION ALL
-- GIT
SELECT patt.pPropertyAccountTaxingUnitID
     , 'GIT'                   as exemptionCode
     , GoodsInTranExemptionPct as allocationFactor
     , GoodsInTransitVal       as exemptionAmount
     , null                    as localExemptionAmount
     , GoodsInTransitVal       as totalExemptionAmount
     , true                    as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.GoodsInTranExemption = 'Y'

UNION ALL
-- SO
SELECT patt.pPropertyAccountTaxingUnitID
     , 'SO'                  as exemptionCode
     , SolarWindExemptionPct as allocationFactor
     , SolarWindVal          as exemptionAmount
     , null                  as localExemptionAmount
     , SolarWindVal          as totalExemptionAmount
     , true                  as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.SolarWindExemption = 'Y'

UNION ALL
-- HT
SELECT patt.pPropertyAccountTaxingUnitID
     , 'HT'             as exemptionCode
     , HistExemptionPct as allocationFactor
     , HistVal          as exemptionAmount
     , null             as localExemptionAmount
     , HistVal          as totalExemptionAmount
     , true             as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.HistExemption = 'Y'

UNION ALL
-- HB12
SELECT patt.pPropertyAccountTaxingUnitID
     , 'HB12'             as exemptionCode
     , Hb1200ExemptionPct as allocationFactor
     , Hb1200Val          as exemptionAmount
     , null               as localExemptionAmount
     , Hb1200Val          as totalExemptionAmount
     , true               as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.Hb1200Exemption = 'Y'

UNION ALL
-- FTZ
SELECT patt.pPropertyAccountTaxingUnitID
     , 'FTZ'           as exemptionCode
     , FTZExemptionPct as allocationFactor
     , FTZVal          as exemptionAmount
     , null            as localExemptionAmount
     , FTZVal          as totalExemptionAmount
     , true            as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.FTZExemption = 'Y'

UNION ALL
-- EX366
SELECT patt.pPropertyAccountTaxingUnitID
     , 'EX366'            as exemptionCode
     , Min500ExemptionPct as allocationFactor
     , Min500Val          as exemptionAmount
     , null               as localExemptionAmount
     , Min500Val          as totalExemptionAmount
     , true               as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.Min500Exemption = 'Y'

UNION ALL
-- AB
SELECT patt.pPropertyAccountTaxingUnitID
     , 'AB'                  as exemptionCode
     , AbatementExemptionPct as allocationFactor
     , AbatementVal          as exemptionAmount
     , null                  as localExemptionAmount
     , AbatementVal          as totalExemptionAmount
     , true                  as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.AbatementExemption = 'Y'

UNION ALL
-- PC
SELECT patt.pPropertyAccountTaxingUnitID
     , 'PC'                     as exemptionCode
     , PollutionConExemptionPct as allocationFactor
     , PollutionControlVal      as exemptionAmount
     , null                     as localExemptionAmount
     , PollutionControlVal      as totalExemptionAmount
     , true                     as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.PollutionConExemption = 'Y'

UNION ALL
-- MISC
SELECT patt.pPropertyAccountTaxingUnitID
     , 'MISC'           as exemptionCode
     , MiscExemptionPct as allocationFactor
     , MiscVal          as exemptionAmount
     , null             as localExemptionAmount
     , MiscVal          as totalExemptionAmount
     , true             as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.MiscExemption = 'Y'

UNION ALL
-- WATR
SELECT patt.pPropertyAccountTaxingUnitID
     , 'WATR'               as exemptionCode
     , WaterConExemptionPct as allocationFactor
     , WaterConVal          as exemptionAmount
     , null                 as localExemptionAmount
     , WaterConVal          as totalExemptionAmount
     , true                 as includeExemptionCount
from
    propertyAccountTaxingUnitTaxable patt
        join propertyAccount pa
            using (pAccountID)
        join propertyTaxingUnit ptu
            using (pTaxingUnitID)
        join propertyAccountExemptions pae
            on pae.pID = pa.pid
        and pae.pYear = pa.pYear
        and pae.pAccountID = pa.pAccountID
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.propertyKey = pa.pid
        JOIN join_tu_u8 jtu
            ON aa.JurisdictionCd = jtu.code_u8
        JOIN taxingUnit tu
            ON tu.taxingUnitID = jtu.taxingUnitID
WHERE pa.pYear BETWEEN @pYearMin AND @pYearMax
  and aa.WaterConExemption = 'Y'
;

 */
 
 
 
 
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
        and LocalGenHomesteadVal > 0
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
        and StateGenHomesteadVal > 0
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
select TaxYear, PropertyKey, JurisdictionCd,Ov65Exemption, LocalOver65Val From conversionDB.AppraisalAccount aa where aa.Ov65Exemption = 'Y' and LocalOver65Val > 0; -- OV65-Local
select TaxYear, PropertyKey, JurisdictionCd,Ov65Exemption, StateOver65Val From conversionDB.AppraisalAccount aa where aa.Ov65Exemption = 'Y' and StateOver65Val > 0; -- OV65-State


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
        and LocalOver65Val > 0
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
        and StateOver65Val > 0
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
select TaxYear, PropertyKey, JurisdictionCd,Ov65SSExemption, LocalOver65SurvivingSpouseVal From conversionDB.AppraisalAccount aa where aa.Ov65SSExemption = 'Y' and LocalOver65SurvivingSpouseVal > 0; -- OV65S-Local
select TaxYear, PropertyKey, JurisdictionCd,Ov65SSExemption, StateOver65SurvivingSpouseVal From conversionDB.AppraisalAccount aa where aa.Ov65SSExemption = 'Y' and StateOver65SurvivingSpouseVal > 0; -- OV65S-State


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
        and LocalOver65SurvivingSpouseVal > 0
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
        and StateOver65SurvivingSpouseVal > 0
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
select TaxYear, PropertyKey, JurisdictionCd,DPExemption, LocalDPVal From conversionDB.AppraisalAccount aa where aa.DPExemption = 'Y' and LocalDPVal > 0; -- DP-Local
select TaxYear, PropertyKey, JurisdictionCd,DPExemption, StateDPVal From conversionDB.AppraisalAccount aa where aa.DPExemption = 'Y' and StateDPVal > 0; -- DP-State

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
        and LocalDPVal > 0
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
        and StateDPVal > 0
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
select TaxYear, PropertyKey, JurisdictionCd,DSSExemption, LocalDisabledSurvivingSpouseVal From conversionDB.AppraisalAccount aa where aa.DSSExemption = 'Y' and LocalDisabledSurvivingSpouseVal > 0; -- DPS-Local
select TaxYear, PropertyKey, JurisdictionCd,DSSExemption, StateDisabledSurvivingSpouseVal From conversionDB.AppraisalAccount aa where aa.DSSExemption = 'Y' and StateDisabledSurvivingSpouseVal > 0; -- DPS-State

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
        and LocalDisabledSurvivingSpouseVal > 0
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
        and StateDisabledSurvivingSpouseVal > 0
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
select TaxYear, PropertyKey, JurisdictionCd,DPExemption, DVExemptionCd, DVVal From conversionDB.AppraisalAccount aa where DVVal > 0 and DVExemptionCd in ('HS', '11', 'XHDV'); -- DVHS

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
        and DVExemptionCd in ('HS', '11', 'XHDV')
        and DVVal > 0
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
                where DVVal > 0
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
        and DVVal > 0
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
select TaxYear, PropertyKey, JurisdictionCd,AbsExemption, AbsVal, TotalTaxableVal From conversionDB.AppraisalAccount aa where AbsExemption = 'Y' and AbsVal > 0;

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
        and AbsVal > 0
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
select TaxYear, PropertyKey, JurisdictionCd,FreeportExemption, FreeportVal From conversionDB.AppraisalAccount aa where FreeportExemption = 'Y' and FreeportVal > 0;


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
        and FreeportVal > 0
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
select TaxYear, PropertyKey, JurisdictionCd,GoodsInTranExemption, GoodsInTransitVal From conversionDB.AppraisalAccount aa where GoodsInTranExemption = 'Y' and GoodsInTransitVal > 0;



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
        and GoodsInTransitVal > 0
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
select TaxYear, PropertyKey, JurisdictionCd,SolarWindExemption, SolarWindVal From conversionDB.AppraisalAccount aa where SolarWindExemption = 'Y' and SolarWindVal > 0;


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
        and SolarWindVal > 0
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
select TaxYear, PropertyKey, JurisdictionCd,HistExemption, HistVal From conversionDB.AppraisalAccount aa where HistExemption = 'Y' and HistVal > 0;


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
        and HistVal > 0
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
select TaxYear, PropertyKey, JurisdictionCd,Hb1200Exemption, Hb1200Val From conversionDB.AppraisalAccount aa where Hb1200Exemption = 'Y' and Hb1200Val > 0;





select FTZExemption, count(*) from conversionDB.AppraisalAccount group by FTZExemption;
select TaxYear, PropertyKey, JurisdictionCd,FTZExemption, FTZVal From conversionDB.AppraisalAccount aa where FTZExemption = 'Y' and FTZVal > 0;



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
        and FTZVal > 0
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
select TaxYear, PropertyKey, JurisdictionCd,Min500Exemption, Min500ExemptionPct, Min500Val From conversionDB.AppraisalAccount aa where Min500Exemption = 'Y' and Min500Val > 0; -- EX366



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
        and Min500Val > 0
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
select TaxYear, PropertyKey, JurisdictionCd,PollutionConExemption, PollutionConExemptionPct, PollutionControlVal From conversionDB.AppraisalAccount aa where PollutionConExemption = 'Y' and PollutionControlVal > 0; -- PC


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
        and PollutionControlVal > 0
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
select TaxYear, PropertyKey, JurisdictionCd,AbatementExemption, AbatementExemptionPct, AbatementVal, SpecAbatementVal From conversionDB.AppraisalAccount aa where AbatementExemption = 'Y' and (AbatementVal > 0 or SpecAbatementVal > 0); -- AB
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
        and AbatementVal > 0
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
select TaxYear, PropertyKey, JurisdictionCd,WaterConExemption, WaterConExemptionPct, WaterConVal From conversionDB.AppraisalAccount aa where WaterConExemption = 'Y' and waterConVal > 0;
-- Keep an eye out for records with a WaterConExemption exemption!  If we run into one, we'll need to seek clarity from the client on what it represents!








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


update rankExemptions re
join propertyAccountTaxingUnitExemptions ex using (ppropertyAccountTaxingUnitExemptionID)
set ex.includeExemptionCount = re.includeExemptionCount
where re.includeExemptionCount <> ex.includeExemptionCount;


drop temporary table if exists rankExemptions;







# Validate.
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
  tax.taxableValue
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
    select netAppraisedValue - tax.taxableValue as expectedTaxableValue
    ) e
  join lateral (
    select
      count(*) as exemptionRecords,
      group_concat(distinct exemptionCode order by exemptionCode) as exemptionCodes,
      ifnull(sum(ex.localExemptionAmount),0) as localExemptionAmount,
      ifnull(sum(ex.exemptionAmount),0) as stateExemptionAmount,
      ifnull(sum(ex.totalExemptionAmount),0) as totalExemptionAmount
      from propertyAccountTaxingUnitExemptions ex
      where
        ex.pPropertyAccountTaxingUnitID = tax.pPropertyAccountTaxingUnitID
    ) ex
  where
    not p.inactive
    and e.expectedTaxableValue <> tax.taxableValue;