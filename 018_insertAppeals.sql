set @pYearMin = 2020;
set @pYearMax = 2025;

set @p_user = 'TPConversion - insertAppeals';
set @createDt = now();
set @p_skipTrigger = 0;
set sql_safe_updates = 0;
# set @legacyProtesterFormName = 'Legacy Protester';
set @legacyFormName = 'Appeals';
set @formName = 'Legacy Appeal Events';
delete from bowie_events.pEventObjects;
delete from bowie_events.pEventTags;
delete from bowie_events.pEvent;



# insert into codefile (codeFileYear, codeFileType, codeFileName, codeName, codeDescription, createdBy, createDt, active)
# SELECT DISTINCT
#        0                 as codeFileYear
#      , 'Appeals'         as codeFileType
#      , 'Decision Reason' as codeFileName
#      , a.DWDISCODE       as codeName
#      , c.CCD_Description as codeDescription
#      , @p_user           as createdBy
#      , NOW()             as createdDt
#      , 1
# FROM
#     conversionDB.AppraisalAccount_ARB a
#         JOIN conversionDB.CommonCodeH c
#             ON c.CCD_Code = a.DWDISCODE
#         AND c.CCD_Type = 'ARCDCD'
# WHERE a.DWDISCODE IS NOT NULL
#   AND TRIM(a.DWDISCODE) <> ''
#   AND c.CCD_Description IS NOT NULL
#   AND TRIM(c.CCD_Description) <> '';

# insert into codefile (codeFileYear, codeFileType, codeFileName, codeName, codeDescription, createdBy, createDt, active)
# VALUES (0, 'Appeals', 'Reasons', '01', 'Value Over Market', @p_user, now(), 1),
#        (0, 'Appeals', 'Reasons', '02', 'Value Unequal', @p_user, now(), 1),
#        (0, 'Appeals', 'Reasons', '03', 'Not in Jurisdiction', @p_user, now(), 1),
#        (0, 'Appeals', 'Reasons', '04', 'No Notice', @p_user, now(), 1),
#        (0, 'Appeals', 'Reasons', '05', 'Other Reason', @p_user, now(), 1),
#        (0, 'Appeals', 'Reasons', '06', 'Exemption Denied', @p_user, now(), 1),
#        (0, 'Appeals', 'Reasons', '07', 'Property Usage Change', @p_user, now(), 1),
#        (0, 'Appeals', 'Reasons', '08', 'Property Usage Denied', @p_user, now(), 1),
#        (0, 'Appeals', 'Reasons', '09', 'Incorrect Owner', @p_user, now(), 1),
#        (0, 'Appeals', 'Reasons', '10', 'Not in CAD', @p_user, now(), 1),
#        (0, 'Appeals', 'Reasons', '11', 'Incorrect Property Description', @p_user, now(), 1);

# insert into codefile (codeFileYear, codeFileType, codeFileName, codeName, codeDescription, createdBy, createDt, active)
# SELECT DISTINCT
#        0                 as codeFileYear
#      , 'Appeals'         as codeFileType
#      , 'Status'          as codeFileName
#      , a.DWDISCODE       as codeName
#      , c.CCD_Description as codeDescription
#      , @p_user           as createdBy
#      , NOW()             as createdDt
#      , 1
# FROM
#     conversionDB.AppraisalAccount_ARB a
#         JOIN conversionDB.CommonCodeH c
#             ON c.CCD_Code = a.DWDISCODE
#         AND c.CCD_Type = 'ARCDCD'
# WHERE a.DWDISCODE IS NOT NULL
#   AND TRIM(a.DWDISCODE) <> ''
#   AND c.CCD_Description IS NOT NULL
#   AND TRIM(c.CCD_Description) <> '';

# insert into appealStatusConfig (appealStatus, appealStatusDescription, appealStatusState, generateLetter, letter,
#                                 emailNotify, active, createdBy, createDt, arbDecision)
# SELECT DISTINCT a.DWDISCODE       as appealStatus
#      , c.CCD_Description as appealStatusDescription
#      , 'Open'            as appealStatusState
#      , 0                 as generateLetter
#      , null
#      , 0
#      , 1
#      , @p_user
#      , NOW()
#      , null
# FROM
#     conversionDB.AppraisalAccount_ARB a
#         JOIN conversionDB.CommonCodeH c
#             ON c.CCD_Code = a.DWDISCODE
#         AND c.CCD_Type = 'ARCDCD'
# WHERE a.DWDISCODE IS NOT NULL
#   AND TRIM(a.DWDISCODE) <> ''
#   AND c.CCD_Description IS NOT NULL
#   AND TRIM(c.CCD_Description) <> '';

##################### insert into appeals #####################
# insert into appeals (
# 	pID,
# 	pYear,
#     docketDt,
# 	formalStartMeeting,
#     formalEndMeeting,
#     appealStatus,
#     finalizedDt,
#     finalized,
# 	initialMarketValue,
#     appealAssignedTo,
#     claimantOpinionOfValue,
#     decisionReason,
# 	finalMarketValue,
# 	createDt,
# 	createdBy
# )
# select
# a.PropertyKey as pid
# ,a.TaxYear as pYear
# ,IF(
#   arb.ScheduledDate = 0,
#   NULL,
#   DATE_FORMAT(STR_TO_DATE(arb.ScheduledDate, '%Y%m%d'), '%Y-%m-%d 00:00:00')
# ) AS docketDt
# ,CASE
#     WHEN arb.ScheduledDate IS NULL
#       OR TRIM(CAST(arb.ScheduledDate AS CHAR)) = ''
#       OR arb.ScheduledDate = 0
#     THEN NULL
#     WHEN arb.HearingStartTime IS NULL
#       OR TRIM(CAST(arb.HearingStartTime AS CHAR)) = ''
#     THEN DATE_FORMAT(STR_TO_DATE(arb.ScheduledDate, '%Y%m%d'), '%Y-%m-%d 00:00:00')
#     ELSE DATE_FORMAT(
#            STR_TO_DATE(
#              CONCAT(
#                arb.ScheduledDate,
#                LPAD(CAST(arb.HearingStartTime AS CHAR), 4, '0')
#              ),
#              '%Y%m%d%H%i'
#            ),
#            '%Y-%m-%d %H:%i:00'
#          )
#   END AS formalStartMeeting
# ,CASE
#     WHEN arb.ScheduledDate IS NULL
#       OR TRIM(CAST(arb.ScheduledDate AS CHAR)) = ''
#       OR arb.ScheduledDate = 0
#     THEN NULL
#     WHEN arb.HearingEndTime IS NULL
#       OR TRIM(CAST(arb.HearingEndTime AS CHAR)) = ''
#     THEN DATE_FORMAT(STR_TO_DATE(arb.ScheduledDate, '%Y%m%d'), '%Y-%m-%d 00:00:00')
#     ELSE DATE_FORMAT(
#            STR_TO_DATE(
#              CONCAT(
#                arb.ScheduledDate,
#                LPAD(CAST(arb.HearingEndTime AS CHAR), 4, '0')
#              ),
#              '%Y%m%d%H%i'
#            ),
#            '%Y-%m-%d %H:%i:00'
#          )
#   END AS formalEndMeeting
# ,trim(a.DWDISCODE) as appealStatus
# ,IF(
#   arb.ArbDispositionDate = 0,
#   NULL,
#   DATE_FORMAT(STR_TO_DATE(arb.ArbDispositionDate, '%Y%m%d'), '%Y-%m-%d 00:00:00')
# ) AS finalizedDt
# ,IF(
#   arb.ArbDispositionDate = 0,
#   0,
#   1
# ) AS finalizedDt
# ,a.DWNOTCVAL as initialMarketValue
# ,trim(app.AppraiserName) as appealAssignedTo
# ,a.DWOWNVAL as claimantOpinionOfValue
# ,a.DWDISCODE as decisionReason
# ,CASE
#     WHEN COALESCE(arb.ArbDispositionDate, 0) <> 0
#       THEN COALESCE(pv_sum.sumValue, 0)
#     ELSE NULL
#   END AS finalMarketValue
# ,NOW()
# ,@p_user
# from conversionDB.AppraisalAccount_ARB a
# join property p
# on p.pYear = a.TaxYear
# and p.pid = a.PropertyKey
# join conversionDB.ARB_Case arb
# on arb.AuditTaxYear = a.TaxYear
# and arb.PropertyKey = a.PropertyKey
# and arb.ARBKEY = a.ARB_CaseKey
# left join conversionDB.AppraiserID app
#     on app.AuditTaxYear = a.TaxYear
#     and app.AppraiserIdCode = arb.AppraiserIdCode
# LEFT JOIN (
#   SELECT
#     AuditTaxYear,
#     PropertyKey,
#     SUM(COALESCE(SelectedValue, 0)) AS sumValue
#   FROM conversionDB.PropertyValue
#   WHERE AuditTaxYear BETWEEN @pYearMin AND @pYearMax
#   GROUP BY AuditTaxYear, PropertyKey
# ) pv_sum
#   ON pv_sum.AuditTaxYear = a.TaxYear
#  AND pv_sum.PropertyKey   = a.PropertyKey
# WHERE a.TaxYear BETWEEN @pYearMin AND @pYearMax;

##################### insert into appealReasons #####################

# DROP TABLE IF EXISTS tmp_base;
#
# CREATE TABLE tmp_base AS
#     SELECT a.*, apl.appealID
#     FROM
#         conversionDB.AppraisalAccount_ARB a
#             JOIN appeals apl
#                 ON apl.pYear = a.TaxYear
#             AND apl.pID = a.PropertyKey
#     WHERE a.TaxYear BETWEEN @pYearMin AND @pYearMax
# ;
#
# ALTER TABLE tmp_base
#     ADD INDEX idx_tmp_appealID (appealID);
#
# INSERT INTO appealReasons (appealID,
#                            appealReason,
#                            createdBy,
#                            createDt)
# -- 01
# SELECT b.appealID, '01', @p_user, now()
# FROM
#     tmp_base b
# WHERE b.DWOVERMKT = 'Y'
#   AND NOT EXISTS (SELECT 1
#                   FROM
#                       appealReasons ar
#                   WHERE ar.appealID = b.appealID
#                     AND ar.appealReason = '01')
#
# UNION ALL
#
# -- 02
# SELECT b.appealID, '02', @p_user, now()
# FROM
#     tmp_base b
# WHERE b.DWUNEQUAL = 'Y'
#   AND NOT EXISTS (SELECT 1
#                   FROM
#                       appealReasons ar
#                   WHERE ar.appealID = b.appealID
#                     AND ar.appealReason = '02')
#
# UNION ALL
#
# -- 03
# SELECT b.appealID, '03', @p_user, now()
# FROM
#     tmp_base b
# WHERE b.DWNOTINJ = 'Y'
#   AND NOT EXISTS (SELECT 1
#                   FROM
#                       appealReasons ar
#                   WHERE ar.appealID = b.appealID
#                     AND ar.appealReason = '03')
#
# UNION ALL
#
# -- 04
# SELECT b.appealID, '04', @p_user, now()
# FROM
#     tmp_base b
# WHERE b.DWNONOTC = 'Y'
#   AND NOT EXISTS (SELECT 1
#                   FROM
#                       appealReasons ar
#                   WHERE ar.appealID = b.appealID
#                     AND ar.appealReason = '04')
#
# UNION ALL
#
# -- 05
# SELECT b.appealID, '05', @p_user, now()
# FROM
#     tmp_base b
# WHERE b.DWOTHERR = 'Y'
#   AND NOT EXISTS (SELECT 1
#                   FROM
#                       appealReasons ar
#                   WHERE ar.appealID = b.appealID
#                     AND ar.appealReason = '05')
#
# UNION ALL
#
# -- 06
# SELECT b.appealID, '06', @p_user, now()
# FROM
#     tmp_base b
# WHERE b.DWEXMDEN = 'Y'
#   AND NOT EXISTS (SELECT 1
#                   FROM
#                       appealReasons ar
#                   WHERE ar.appealID = b.appealID
#                     AND ar.appealReason = '06')
#
# UNION ALL
#
# -- 07
# SELECT b.appealID, '07', @p_user, now()
# FROM
#     tmp_base b
# WHERE b.DWUSECHG = 'Y'
#   AND NOT EXISTS (SELECT 1
#                   FROM
#                       appealReasons ar
#                   WHERE ar.appealID = b.appealID
#                     AND ar.appealReason = '07')
#
# UNION ALL
#
# -- 08
# SELECT b.appealID, '08', @p_user, now()
# FROM
#     tmp_base b
# WHERE b.DWUSEDEN = 'Y'
#   AND NOT EXISTS (SELECT 1
#                   FROM
#                       appealReasons ar
#                   WHERE ar.appealID = b.appealID
#                     AND ar.appealReason = '08')
#
# UNION ALL
#
# -- 09
# SELECT b.appealID, '09', @p_user, now()
# FROM
#     tmp_base b
# WHERE b.DWINCOWN = 'Y'
#   AND NOT EXISTS (SELECT 1
#                   FROM
#                       appealReasons ar
#                   WHERE ar.appealID = b.appealID
#                     AND ar.appealReason = '09')
#
# UNION ALL
#
# -- 10
# SELECT b.appealID, '10', @p_user, now()
# FROM
#     tmp_base b
# WHERE b.DWNOTINC = 'Y'
#   AND NOT EXISTS (SELECT 1
#                   FROM
#                       appealReasons ar
#                   WHERE ar.appealID = b.appealID
#                     AND ar.appealReason = '10')
#
# UNION ALL
#
# -- 11
# SELECT b.appealID, '11', @p_user, now()
# FROM
#     tmp_base b
# WHERE b.DWINCDESC = 'Y'
#   AND NOT EXISTS (SELECT 1
#                   FROM
#                       appealReasons ar
#                   WHERE ar.appealID = b.appealID
#                     AND ar.appealReason = '11')
# ;
#
# DROP TABLE IF EXISTS tmp_base;

##################### setting up events #####################
# insert ignore into codefileConfig (
# 	codeFileType,
# 	codeFileName,
# 	byYear)
# values
# (
# 	'event',
# 	'group',
# 	false);

##################### add legacy appeal form #####################
# insert ignore into bowie_events.codefile (
# 	codeFileType,
# 	codeFileName,
# 	codeName,
# 	description,
# 	definition,
# 	createdBy,
# 	createDt,
# 	updatedBy,
# 	updateDt,
# 	active,
# 	isSystem)
# values
# (
# 	'event',
# 	'group',
# 	'group',
# 	'group',
# 	null,
# 	null,
# 	now(),
# 	null,
# 	null,
# 	true,
# 	false),
# (
# 	'event',
# 	'group',
# 	'Legacy',
# 	'Data Converted from a Legacy CAMA system',
# 	null,
# 	@createdBy,
# 	now(),
# 	null,
# 	null,
# 	true,
# 	false);

##################### setting up event form #####################
# INSERT INTO bowie_events.pEventForm (
#   formName,
#   formGroup,
#   description,
#   dataObject,
#   eventTypes,
#   formFields,
#   createdBy,
#   createDt
# )
# SELECT
#   @formName AS formName,
#   'Legacy'  AS formGroup,
#   'Legacy Appeal Events' AS description,
#   'appeals' AS dataObject,
#   '[]'      AS eventTypes,
#   JSON_PRETTY('[
#     {"name":"ARB_CaseKey","type":"integer","display":null,"options":null,"purpose":null,"helpText":null,"isRequired":0,"defaultValue":"","summaryField":0},
#     {"name":"PropertyKey","type":"integer","display":null,"options":null,"purpose":null,"helpText":null,"isRequired":0,"defaultValue":null,"summaryField":0},
#     {"name":"TaxYear","type":"number","display":null,"options":null,"purpose":null,"helpText":null,"isRequired":0,"defaultValue":null,"summaryField":0},
#     {"name":"DWDISCODE","type":"text","display":null,"options":null,"purpose":null,"helpText":null,"isRequired":0,"defaultValue":null,"summaryField":0},
#     {"name":"DWPROTEST","type":"text","display":null,"options":null,"purpose":null,"helpText":null,"isRequired":0,"defaultValue":null,"summaryField":0},
#     {"name":"DWDISDATE","type":"datetime","display":null,"options":null,"purpose":null,"helpText":null,"isRequired":0,"defaultValue":" ","summaryField":0},
#     {"name":"DWOTHERRD","type":"text","display":null,"options":null,"purpose":null,"helpText":null,"isRequired":0,"defaultValue":null,"summaryField":0},
#     {"name":"DWAPRID","type":"text","display":null,"options":null,"purpose":null,"helpText":null,"isRequired":0,"defaultValue":null,"summaryField":0},
#     {"name":"DWINCDESC","type":"text","display":null,"options":null,"purpose":null,"helpText":null,"isRequired":0,"defaultValue":null,"summaryField":0},
#     {"name":"DWNOTINJD","type":"text","display":null,"options":null,"purpose":null,"helpText":null,"isRequired":0,"defaultValue":null,"summaryField":0},
#     {"name":"DWNONOTCD","type":"text","display":null,"options":null,"purpose":null,"helpText":null,"isRequired":0,"defaultValue":null,"summaryField":0},
#     {"name":"DWDISRSN","type":"text","display":null,"options":null,"purpose":null,"helpText":null,"isRequired":0,"defaultValue":null,"summaryField":0}
#   ]') AS formFields,
#   @createdBy AS createdBy,
#   @createDt  AS createDt
# FROM DUAL
# WHERE NOT EXISTS (
#   SELECT 1
#   FROM bowie_events.pEventForm f
#   WHERE f.formName = @formName
# );

##################### inserting appeal events #####################
set @formID = (select formID from bowie_events.pEventForm f where f.formName = @formName);



select @formID, @formName, @pYearMin, @pYearMax;

INSERT INTO bowie_events.pEvent (
  formID,
  eventData,
  eventType,
  eventDescription,
  fileAttachments,
  createDt,
  createdBy,
  updateDt,
  updatedBy,
  fromID
)
-- 1) ARB Disposition Reason
SELECT
  @formID AS formID,
  JSON_OBJECT(
    'ARB_CaseKey', a.ARB_CaseKey,
    'PropertyKey', a.PropertyKey,
    'TaxYear',     a.TaxYear,
    'DWDISCODE',   a.DWDISCODE,
    'DWAPRID',     a.DWAPRID,
    'DWDISDATE',   CAST(finalizedDt AS DATE),
    'DWDISRSN',    LEFT(
                     CONCAT_WS(' ',
                       NULLIF(TRIM(a.DWDISRSN1), ''),
                       NULLIF(TRIM(a.DWDISRSN2), ''),
                       NULLIF(TRIM(a.DWDISRSN3), '')
                     ), 500)
  ) AS eventData,
  'ARB Disposition Reason' AS eventType,
  LEFT(
    CONCAT_WS(' ',
      NULLIF(TRIM(a.DWDISRSN1), ''),
      NULLIF(TRIM(a.DWDISRSN2), ''),
      NULLIF(TRIM(a.DWDISRSN3), '')
    ), 500
  ) AS eventDescription,
  '[]' AS fileAttachments,
  DATE(apl.finalizedDt) AS createDt,
  apl.appealAssignedTo AS createdBy,
  @createDt AS updateDt,
  @createdBy AS updatedBy,
  apl.appealID AS fromID
FROM conversionDB.AppraisalAccount_ARB a
JOIN appeals apl
  ON apl.pYear = a.TaxYear
 AND apl.pid   = a.PropertyKey
WHERE
  -- only when any of the 3 disposition reason parts has content
  TRIM(
    CONCAT_WS(' ',
      NULLIF(TRIM(a.DWDISRSN1), ''),
      NULLIF(TRIM(a.DWDISRSN2), ''),
      NULLIF(TRIM(a.DWDISRSN3), '')
    )
  ) <> ''
  AND NOT EXISTS (
    SELECT 1
    FROM bowie_events.pEvent e
    WHERE e.formID = @formID
      AND e.eventType = 'ARB Disposition Reason'
      AND e.eventDescription = LEFT(
        CONCAT_WS(' ',
          NULLIF(TRIM(a.DWDISRSN1), ''),
          NULLIF(TRIM(a.DWDISRSN2), ''),
          NULLIF(TRIM(a.DWDISRSN3), '')
        ), 500
      )
      AND e.fromID = apl.appealID
  )

UNION ALL

-- 2) Protest Reason Comment
SELECT
  @formID AS formID,
  JSON_OBJECT(
    'ARB_CaseKey', a.ARB_CaseKey,
    'PropertyKey', a.PropertyKey,
    'TaxYear',     a.TaxYear,
    'DWDISCODE',   a.DWDISCODE,
    'DWAPRID',     a.DWAPRID,
    'DWDISDATE',   CAST(finalizedDt AS DATE),
    'DWDISRSN',    LEFT(TRIM(a.DWPROTEST), 500)
  ) AS eventData,
  'Protest Reason Comment' AS eventType,
  LEFT(TRIM(a.DWPROTEST), 500) AS eventDescription,
  '[]' AS fileAttachments,
  DATE(finalizedDt) AS createDt,
  apl.appealAssignedTo AS createdBy,
  @createDt AS updateDt,
  @createdBy AS updatedBy,
  apl.appealID AS fromID
FROM conversionDB.AppraisalAccount_ARB a
JOIN appeals apl
  ON apl.pYear = a.TaxYear
 AND apl.pid   = a.PropertyKey
WHERE
  TRIM(COALESCE(a.DWPROTEST, '')) <> ''
  AND NOT EXISTS (
    SELECT 1
    FROM bowie_events.pEvent e
    WHERE e.formID = @formID
      AND e.eventType = 'Protest Reason Comment'
      AND e.eventDescription = LEFT(TRIM(a.DWPROTEST), 500)
      AND e.fromID = apl.appealID
  )

UNION ALL

-- 3) Not in Jurisdiction Desc
SELECT
  @formID AS formID,
  JSON_OBJECT(
    'ARB_CaseKey', a.ARB_CaseKey,
    'PropertyKey', a.PropertyKey,
    'TaxYear',     a.TaxYear,
    'DWDISCODE',   a.DWDISCODE,
    'DWAPRID',     a.DWAPRID,
    'DWDISDATE',   CAST(finalizedDt AS DATE),
    'DWNOTINJD',    LEFT(TRIM(a.DWNOTINJD), 500)
  ) AS eventData,
  'Not in Jurisdiction Desc' AS eventType,
  LEFT(TRIM(a.DWNOTINJD), 500) AS eventDescription,
  '[]' AS fileAttachments,
  DATE(finalizedDt) AS createDt,
  apl.appealAssignedTo AS createdBy,
  @createDt AS updateDt,
  @createdBy AS updatedBy,
  apl.appealID AS fromID
FROM conversionDB.AppraisalAccount_ARB a
JOIN appeals apl
  ON apl.pYear = a.TaxYear
 AND apl.pid   = a.PropertyKey
WHERE
  TRIM(COALESCE(a.DWNOTINJD, '')) <> ''
  AND NOT EXISTS (
    SELECT 1
    FROM bowie_events.pEvent e
    WHERE e.formID = @formID
      AND e.eventType = 'Not in Jurisdiction Desc'
      AND e.eventDescription = LEFT(TRIM(a.DWNOTINJD), 500)
      AND e.fromID = apl.appealID
  )

UNION ALL

-- 4) No Notice Desc
SELECT
  @formID AS formID,
  JSON_OBJECT(
    'ARB_CaseKey', a.ARB_CaseKey,
    'PropertyKey', a.PropertyKey,
    'TaxYear',     a.TaxYear,
    'DWDISCODE',   a.DWDISCODE,
    'DWAPRID',     a.DWAPRID,
    'DWDISDATE',   CAST(finalizedDt AS DATE),
    'DWNONOTCD',   LEFT(TRIM(a.DWNONOTCD), 500)
  ) AS eventData,
  'No Notice Desc' AS eventType,
  LEFT(TRIM(a.DWNONOTCD), 500) AS eventDescription,
  '[]' AS fileAttachments,
  DATE(finalizedDt) AS createDt,
  apl.appealAssignedTo AS createdBy,
  @createDt AS updateDt,
  @createdBy AS updatedBy,
  apl.appealID AS fromID
FROM conversionDB.AppraisalAccount_ARB a
JOIN appeals apl
  ON apl.pYear = a.TaxYear
 AND apl.pid   = a.PropertyKey
WHERE
  TRIM(COALESCE(a.DWNONOTCD, '')) <> ''
  AND NOT EXISTS (
    SELECT 1
    FROM bowie_events.pEvent e
    WHERE e.formID = @formID
      AND e.eventType = 'No Notice Desc'
      AND e.eventDescription = LEFT(TRIM(a.DWNONOTCD), 500)
      AND e.fromID = apl.appealID
  )

UNION ALL

-- 5) Other Reason Desc
SELECT
  @formID AS formID,
  JSON_OBJECT(
    'ARB_CaseKey', a.ARB_CaseKey,
    'PropertyKey', a.PropertyKey,
    'TaxYear',     a.TaxYear,
    'DWDISCODE',   a.DWDISCODE,
    'DWAPRID',     a.DWAPRID,
    'DWDISDATE',   CAST(finalizedDt AS DATE),
    'DWOTHERRD',   LEFT(TRIM(a.DWOTHERRD), 500)
  ) AS eventData,
  'Other Reason Desc' AS eventType,
  LEFT(TRIM(a.DWOTHERRD), 500) AS eventDescription,
  '[]' AS fileAttachments,
  DATE(finalizedDt) AS createDt,
  apl.appealAssignedTo AS createdBy,
  @createDt AS updateDt,
  @createdBy AS updatedBy,
  apl.appealID AS fromID
FROM conversionDB.AppraisalAccount_ARB a
JOIN appeals apl
  ON apl.pYear = a.TaxYear
 AND apl.pid   = a.PropertyKey
WHERE
  TRIM(COALESCE(a.DWOTHERRD, '')) <> ''
  AND NOT EXISTS (
    SELECT 1
    FROM bowie_events.pEvent e
    WHERE e.formID = @formID
      AND e.eventType = 'Other Reason Desc'
      AND e.eventDescription = LEFT(TRIM(a.DWOTHERRD), 500)
      AND e.fromID = apl.appealID
  )

UNION ALL

-- 6) Incorrect Property Desc
SELECT
  @formID AS formID,
  JSON_OBJECT(
    'ARB_CaseKey', a.ARB_CaseKey,
    'PropertyKey', a.PropertyKey,
    'TaxYear',     a.TaxYear,
    'DWDISCODE',   a.DWDISCODE,
    'DWAPRID',     a.DWAPRID,
    'DWDISDATE',   CAST(finalizedDt AS DATE),
    'DWINCDESC',   LEFT(TRIM(a.DWINCDESC), 500)
  ) AS eventData,
  'Incorrect Property Desc' AS eventType,
  LEFT(TRIM(a.DWINCDESC), 500) AS eventDescription,
  '[]' AS fileAttachments,
  DATE(finalizedDt) AS createDt,
  apl.appealAssignedTo AS createdBy,
  @createDt AS updateDt,
  @createdBy AS updatedBy,
  apl.appealID AS fromID
FROM conversionDB.AppraisalAccount_ARB a
JOIN appeals apl
  ON apl.pYear = a.TaxYear
 AND apl.pid   = a.PropertyKey
WHERE
  TRIM(COALESCE(a.DWINCDESC, '')) <> ''
  AND NOT EXISTS (
    SELECT 1
    FROM bowie_events.pEvent e
    WHERE e.formID = @formID
      AND e.eventType = 'Incorrect Property Desc'
      AND e.eventDescription = LEFT(TRIM(a.DWINCDESC), 500)
      AND e.fromID = apl.appealID
  );

##################### connecting events to "appeal events" #####################

# Build an Xref table that relates eventIDs to the legacy, compound Case ID.
drop table if exists appealsXref;
create table appealsXref
select
	eventID,
	fromID as fromCaseID
from
	bowie_events.pEvent
where formID = @formID;
create index eventID on appealsXref (eventID);

##################### inserting to pEventObjects (main connecting table) #####################

# Associate Appeal Events with Appeals IDs
insert into bowie_events.pEventObjects (
	eventID,
	objectID,
	createdBy,
	createDt)
select
	eventID,
	a.appealid as objectID,
	@createdBy as createdBy,
	@createDt as createDt
from
	bowie_events.pEvent e
	join appealsXref xRef
	using (eventID)
	join bowie_appraisal.appeals a
	on a.appealID = xRef.fromCaseID
where e.formID = @formID
and not exists (select * from bowie_events.pEventObjects eo where eo.eventID = e.eventID and eo.objectID = a.appealID)
;

drop table if exists appealsXref;

select *
from bowie_events.pEvent e
join appeals a
on a.appealID = e.fromID
where a.pID = 1733




