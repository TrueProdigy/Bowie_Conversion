set @createDt = now();
set @createdBy = 'TPConversion - insertRendition';

set @pYearMin = 2020;
set @pYearMax = 2025;

set @p_user = 'TP Conversion';
# SET FOREIGN_KEY_CHECKS = 0;
# delete from personalRendition;
# SET FOREIGN_KEY_CHECKS = 1;

##### insert personalRendition
# insert into personalRendition (
# pID,
# pYear,
# receivedDt,
# renderedValue,
# granted,
# lateRendition,
# lateRenditionDt,
# verified, -- rendition Accepted
# addExtension,
# extensionDt,
# filingParty,
# filingPartyPhone,
# filingPartyEmail,
# ownerName,
# createdBy,
# createDt
# )
# SELECT
#   aa.PropertyKey AS pID,
#   cast(aa.TaxYear as UNSIGNED ),
#   DATE_FORMAT(STR_TO_DATE(aa.RenditionRcvdDt, '%Y%m%d'), '%Y-%m-%d 00:00:00') AS receivedDt,
#   pp.RenderedValue AS renderedValue,
#
#   CASE
#     WHEN aa.RenditionAccp = 'Y' THEN 1
#     WHEN aa.RenditionAccp = 'N' THEN 0
#     ELSE NULL
#   END AS granted,
#
#   CASE
#     WHEN aa.LateRendition = 'Y' THEN 1
#     WHEN aa.LateRendition = 'N' THEN 0
#     ELSE NULL
#   END AS lateRendition,
#
#   CASE
#     WHEN aa.LateRendition = 'Y'
#      AND aa.RenditionRcvdDt REGEXP '^[0-9]{8}$'
#     THEN DATE_FORMAT(STR_TO_DATE(aa.RenditionRcvdDt, '%Y%m%d'), '%Y-%m-%d 00:00:00')
#     ELSE NULL
#   END AS lateRenditionDt,
#
#   CASE
#     WHEN aa.RenditionAccp = 'Y' THEN 1
#     WHEN aa.RenditionAccp = 'N' THEN 0
#     ELSE NULL
#   END AS verified,
#
#   CASE
#     WHEN aa.Renditiont1 = 'Y' OR aa.Renditiont2 = 'Y' THEN 1
#     WHEN aa.Renditiont1 = 'N' AND aa.Renditiont2 = 'N' THEN 0
#     ELSE NULL
#   END AS addExtension,
#
#   CASE
#     WHEN aa.Renditiont1 = 'Y' AND aa.Renditiont2 = 'N'
#      AND aa.Renditiont1Dt REGEXP '^[0-9]{8}$'
#     THEN DATE_FORMAT(STR_TO_DATE(aa.Renditiont1Dt, '%Y%m%d'), '%Y-%m-%d 00:00:00')
#
#     WHEN aa.Renditiont2 = 'Y'
#      AND aa.Renditiont2Dt REGEXP '^[0-9]{8}$'
#     THEN DATE_FORMAT(STR_TO_DATE(aa.Renditiont2Dt, '%Y%m%d'), '%Y-%m-%d 00:00:00')
#
#     ELSE NULL
#   END AS extensionDt,
#   LEFT(TRIM(COALESCE(pp.ContactName, '')), 45) as filingParty,
#   LEFT(TRIM(COALESCE(pp.PhoneNumberOne, '')), 45) as filingPartyPhone,
#   LEFT(TRIM(COALESCE(pp.EmailAddress, '')), 45) as filingPartyEmail,
#   LEFT(TRIM(COALESCE(aa.OwnerName1, '')), 45) as ownerName,
#   @createdBy,
#   NOW()
# FROM conversionDB.AppraisalAccount aa
# JOIN conversionDB.AcctXREF axref
#   ON axref.AuditTaxYear = aa.TaxYear
#  AND axref.PropertyKey  = aa.PropertyKey
#  AND axref.AcctXRefType = 'ACCT'
# JOIN conversionDB.Account a
#   ON a.AuditTaxYear = aa.TaxYear
#  AND a.PropertyKey  = aa.PropertyKey
# JOIN conversionDB.PersonalProperty pp
#   ON pp.AuditTaxYear = aa.TaxYear
#  AND pp.PropertyKey  = aa.PropertyKey
#  AND pp.RenderedValue > 0
# WHERE aa.pYear between @pYearMin and @pYearMax
#   AND aa.JurisdictionType = 'CAD';


##### insert propertyBppRenditionExtensionRequests
DROP TEMPORARY TABLE IF EXISTS tmp_pp;

CREATE TEMPORARY TABLE tmp_pp
ENGINE=InnoDB
AS
SELECT
  CAST(AuditTaxYear AS UNSIGNED) AS pYear,
  CAST(PropertyKey  AS UNSIGNED) AS pID,
  MAX(RenderedValue) AS maxRenderedValue
FROM conversionDB.PersonalProperty
WHERE AuditTaxYear between @pYearMin and @pYearMax
GROUP BY CAST(AuditTaxYear AS UNSIGNED), CAST(PropertyKey AS UNSIGNED)
HAVING MAX(RenderedValue) > 0;

ALTER TABLE tmp_pp
  ADD PRIMARY KEY (pYear, pID);


DROP TEMPORARY TABLE IF EXISTS tmp_aa;

CREATE TEMPORARY TABLE tmp_aa
ENGINE=InnoDB
AS
SELECT
  CAST(a.TaxYear AS UNSIGNED)     AS pYear,
  CAST(a.PropertyKey AS UNSIGNED) AS pID,
  a.Renditiont1,
  a.Renditiont1Dt,
  a.Renditiont2,
  a.Renditiont2Dt
FROM conversionDB.AppraisalAccount a
JOIN (
    SELECT
      CAST(TaxYear AS UNSIGNED) AS pYear,
      PropertyKey,
      MAX(cID) AS maxCID
    FROM conversionDB.AppraisalAccount
    WHERE AppraisalAccount.TaxYear between @pYearMin and @pYearMax
      AND JurisdictionType = 'CAD'
    GROUP BY CAST(TaxYear AS UNSIGNED), PropertyKey
) mx
  ON CAST(a.TaxYear AS UNSIGNED) = mx.pYear
 AND a.PropertyKey = mx.PropertyKey
 AND a.cID         = mx.maxCID
WHERE a.TaxYear between @pYearMin and @pYearMax
  AND a.JurisdictionType = 'CAD';

ALTER TABLE tmp_aa
  ADD PRIMARY KEY (pYear, pID);

DROP TEMPORARY TABLE IF EXISTS tmp_axref;

CREATE TEMPORARY TABLE tmp_axref
ENGINE=InnoDB
AS
SELECT DISTINCT
  CAST(AuditTaxYear AS UNSIGNED) AS pYear,
  CAST(PropertyKey  AS UNSIGNED) AS pID
FROM conversionDB.AcctXREF
WHERE AuditTaxYear between @pYearMin and @pYearMax
  AND AcctXRefType = 'ACCT';

ALTER TABLE tmp_axref
  ADD PRIMARY KEY (pYear, pID);


DROP TEMPORARY TABLE IF EXISTS tmp_a;

CREATE TEMPORARY TABLE tmp_a
ENGINE=InnoDB
AS
SELECT
  CAST(a.AuditTaxYear AS UNSIGNED) AS pYear,
  CAST(a.PropertyKey  AS UNSIGNED) AS pID,
  a.LateRenditionPenaltyFlag,
  a.ACCSTS
FROM conversionDB.Account a
JOIN (
  SELECT AuditTaxYear, PropertyKey, MAX(cID) AS maxCID
  FROM conversionDB.Account
  WHERE AuditTaxYear between @pYearMin and @pYearMax
  GROUP BY AuditTaxYear, PropertyKey
) mx
  ON mx.AuditTaxYear = a.AuditTaxYear
 AND mx.PropertyKey  = a.PropertyKey
 AND mx.maxCID       = a.cID;

ALTER TABLE tmp_a
  ADD PRIMARY KEY (pYear, pID);

INSERT IGNORE INTO propertyBppRenditionExtensionRequests (
  pYear,
  pid,
  pVersion,
  pRollCorr,
  ext30dayRequestStatus,
  ext30dayRequestDt,
  ext45dayRequestStatus,
  ext45dayRequestDt,
  createDt,
  createdBy
)
SELECT
  pr.pYear,
  pr.pID,
  0 AS pVersion,
  0 AS pRollCorr,

  CASE WHEN aa.Renditiont1 = 'Y' THEN 1 ELSE 0 END AS ext30dayRequestStatus,
  CASE
    WHEN aa.Renditiont1 = 'Y'
     AND aa.Renditiont1Dt REGEXP '^[0-9]{8}$'
    THEN DATE_FORMAT(STR_TO_DATE(aa.Renditiont1Dt, '%Y%m%d'), '%Y-%m-%d 00:00:00')
    ELSE NULL
  END AS ext30dayRequestDt,

  CASE WHEN aa.Renditiont2 = 'Y' THEN 1 ELSE 0 END AS ext45dayRequestStatus,
  CASE
    WHEN aa.Renditiont2 = 'Y'
     AND aa.Renditiont2Dt REGEXP '^[0-9]{8}$'
    THEN DATE_FORMAT(STR_TO_DATE(aa.Renditiont2Dt, '%Y%m%d'), '%Y-%m-%d 00:00:00')
    ELSE NULL
  END AS ext45dayRequestDt,

  @createDt,
  @createdBy
FROM personalRendition pr
JOIN tmp_pp pp
  ON pp.pYear = pr.pYear
 AND pp.pID   = pr.pID
JOIN tmp_aa aa
  ON aa.pYear = pr.pYear
 AND aa.pID   = pr.pID
JOIN tmp_axref axref
  ON axref.pYear = pr.pYear
 AND axref.pID   = pr.pID
JOIN tmp_a a
  ON a.pYear = pr.pYear
 AND a.pID   = pr.pID
WHERE pr.pYear between @pYearMin and @pYearMax;

select *
from personalRendition
where pYear = 2025
and pid = 58257


