use bowie_appraisal;
set @pYearMin = 2020;
set @pYearMax = 2025;


set @p_skipTrigger = 1;
set @p_user = 'TP Conversion';
set @createdBy = 'TP Conversion - insertTaxable';
set @createDt = now();
set sql_safe_updates = 1;

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
                                                     netAppraisedValue,
                                                     newBppValue,
                                                     agLandMktValue,
                                                     agValue,
                                                     agExclusionValue,
                                                     suExclusionValue,
                                                     marketValue,
                                                     totalTaxRate,
                                                     createDt)
select pid
     , pYear
     , pVersion
     , pRollCorr
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
     , aa.TotalNewTaxableVal                                                     AS newAppraisedValue
     , COALESCE(aa.OtherNewPersonalVal, 0) + COALESCE(aa.HomesitePersonalVal, 0) AS newBppValue
     , aa.AgLandMarketVal                                                        AS agLandMktValue
     , aa.AgLandProdVal                                                          AS agValue
     , COALESCE(aa.AgLandMarketVal, 0) - COALESCE(aa.AgLandProdVal, 0)           AS agExclusionValue
     , aa.ProductivityLossVal                                                    AS suExclusionValue
     , aa.TotalMarketVal                                                         AS marketValue
     ,CAST(aj.TotalTaxRate AS DECIMAL(9,6))                                      AS totalTaxRate
     , @createDt
from
    propertyAccount pa
        join propertyTaxingUnit ptu
            using (pid, pYear, pVersion, pRollCorr)
        join taxingUnit tu
            using (taxingUnitID)
        join conversionDB.AppraisalAccount aa
            on aa.TaxYear = pa.pYear
        and aa.PropertyKey = pa.pid
        and aa.JurisdictionCd = tu.taxingUnitCode
        join conversionDB.AppraisalJurisdiction aj
            on aj.TaxYear = pa.pYear
        and aj.JurisdictionCd = aa.JurisdictionCd

where pa.pYear between @pYearMin and @pYearMax;



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
  AND (DSSExemption = 'Y' OR aa.DVExemptionCd = '31')

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