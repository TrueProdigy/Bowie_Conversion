set @pYearMin = 2020;
set @pYearMax = 2025;
set @p_user = 'TPConversion - importPropertyEvents';

# SET FOREIGN_KEY_CHECKS = 0;
# delete from bowie_events.pEvent
# where eventType = 'Legacy Notes'
# and formID = 212;
#
# delete from bowie_events.pEventObjects
# where updatedBy = @p_user;
# SET FOREIGN_KEY_CHECKS = 1;
#
# select *
# from bowie_events.pEventObjects
# where eventType = 'Legacy Notes';

##################### find "Property Journal" formID  #####################
# select distinct formID, formName
# from bowie_events.pEventForm
# where formName = 'Property Journal';

set @formID = 212; -- set ID from query result above

##################### added eventType "Legacy Event" #####################
# update bowie_events.pEventForm ef
# set ef.eventTypes = JSON_PRETTY('["06_CONCERN", "07_CONCERN", "08_CONCERN", "08_CON_MIN", "09_CONCERN", "10_CONCERN", "11_CONCERN", "12_AG REAPPLY", "12_AG_RA_WLM", "12_CONCERN", "12_NEW OW_RQTAG_APPL", "12_WLM_RQT", "13_AG REAPPLY", "13_CONCERN", "13_NEW OW_RQTAG_APPL", "13_WLM_RQT", "14_AG REAPPLY", "14_AG_NR", "14_CONCERN", "14_NEW OW_RQTAG_APPL", "14_RESEND_AG APPLIC", "14_RQT_WLMP", "14_WLM REPORT RCVD", "14_WLM_ANNL RPT RCVD", "14_WLM_ANNUAL RPT", "14_WLM_RQT", "15_AG REAPPLY", "15_AGR_REMOVAL NOTI", "15_AGR_SURVEY RQT", "15_CONCERN", "15_NEW OW_RQTAG_APPL", "15_RQT_WLMP PLAN", "15_WLM REPORT RCVD", "15_WLM_ANNL RPT RCVD", "15_WLM_ANNUAL RPT", "16_CONCERN", "17_CONCERN", "18_CONCERN", "19_CONCERN", "2010_ARB_PACKET", "2012_ATTNY_RET_MAIL", "2012_HS_AUDIT.", "2013_EXEMP_AUDIT_REV", "2016_AG SURVEY", "20_CONCERN", "ABST_DEATH_CERT", "AC", "ACCT INFO", "ACCURINT_RESEARCH", "ADDR", "ADDR_CHGE", "ADDR_ISSUE", "ADDR_ISSUE_MINERAL", "ADM_RVW", "AG", "AGC", "AGD", "AGENT_EXP", "AGENT_REVOCATION", "AGE_65_APPLIC", "AGE_65_SS_APPLIC", "AGR_APPL_INCOMPLETE", "AGR_USE_CHGE", "AGUSE_ISSU", "AG_09_NA BATCH #2", "AG_12_NA", "AG_15_AG_CAN", "AG_15_AG_DEN", "AG_15_AG_GRANT", "AG_15_AG_REC", "AG_15_AG_RSEND", "AG_15_APPLIC_INC", "AG_15_ISSUE", "AG_15_NA_2ND BATCH", "AG_15_PAR", "AG_15_RA", "AG_15_RA_R", "AG_15_RM", "AG_15_ROLLB", "AG_15_WLM_PLR", "AG_15_WLM_RPT", "AG_15_WLM_RR", "AG_APPL_REM", "AG_AR", "AG_AR_LATE", "AG_DA", "AG_GA", "AG_NA", "AG_PAR", "AG_RA", "AG_REM", "AG_RM", "AG_ROLL", "AG_SVY", "AN", "APPR CARD(S)", "APPRDISPUT", "APPRNOTICE", "APPR_ISSUE", "APPT AGT", "APPT_AGENT", "ARB", "ARBITR_COM", "ARB_H", "ATTNY_RET_MAIL", "AUDIT REV", "AUDIT REVIEW_2014", "AUDIT REVIEW_2015", "AUDIT REVIEW_2016", "BPP FRPT REMOVAL", "BPP REAP", "BPPPF", "BR-04", "BR_05", "BR_E15", "BR_E30", "CAPTURED_VAL", "CHGE_JURIS", "CLER_ERR", "CLOSING_DISCLOSURES", "CMNT", "CS_2016_RET_A_NOTICE", "CS_2017_RET_AN_MIN", "CS_2017_RET_A_NOTICE", "CS_2018_RET_AN_MIN", "CS_2018_RET_A_NOTICE", "CS_2018_RET_CD_N_OWN", "CS_2019_RET_AN_MIN", "CS_2019_RET_A_NOTICE", "CS_2019_RET_CD_N_OWN", "CS_2020_RET_AN_MIN", "CS_2020_RET_A_NOTICE", "CS_2020_RET_LTR_NEW", "CS_20_AUDIT_APT_EXS", "CS_20_AUDIT_CORP", "CS_20_AUDIT_DECD", "CS_20_AUDIT_DECEASED", "CS_20_AUDIT_DP", "CS_20_AUDIT_DUP_EXS", "CS_20_AUDIT_ET AL", "CS_20_AUDIT_EXS", "CS_20_AUDIT_INC", "CS_20_AUDIT_LTD", "CS_20_AUDIT_MAIL_OUT", "CS_20_AUDIT_MAIL_PO", "CS_LEAVE_EX (S)", "CS_NOTICE_DC", "CS_NOTICE_DENIAL", "CS_NOTICE_DOB", "CS_NOTICE_EXS", "CS_NOTICE_MODIFY", "CS_NOTICE_REMOVAL", "CS_NOTICE_SOC_SEC", "CS_NO_ACTION", "CS_OV65_30DD", "CS_OV65_60DD", "DBLE_ASSES", "DEFF_VALID", "DELPROP", "DHE", "DMS_CHG_PROC", "DMS_CMNT", "DMS_EXEMPT_STATUS", "DMS_SPLIT_PROC", "DMS_SUPP_CHG_PROC", "DP", "DPA", "DPC", "DPD", "DT-06", "DT-10", "DTS", "DUPL_ISSUE", "DV", "DVC", "DVHS EX APPLIC", "DVHSS", "DVHSTD", "DVS", "DVSD", "EX", "EXC", "EXD", "EXEM-VALID", "EXEMPT_RQT", "EXEMP_AUDIT_REV", "EXMP-ISSUE", "EXMPTAPPL", "EXP", "FMK NOTES", "FREEPORT", "FRPT_14", "FRPT_15", "FRPT_16", "FRPT_18", "FRPT_19", "FRPT_20", "FRSS", "HC", "HD", "HOMEVISIT", "HS", "HSGRP_ISSUE", "HSTD17", "HSTD_15 RQT", "HSTD_16 RQT", "IMP ONLY NO RESPONSE", "IMP ONLY PROJ", "IMP ONLY RESPONSE", "IMP_ISSUES", "INFOR_MTG", "INFRMEET", "INQC", "INQUIRY", "JUD_APPEAL", "LAND_ISSUE", "LATEPROT05", "LATE_REND", "LEGAL DESC", "LITIGATION", "MH", "MH CREATE", "MHM", "MH_OWN_ISSUE", "MH_PA", "MH_RNF", "MIN COMM", "MIN_CHGS", "MIN_OWN_ISSUE", "MIN_PROT", "MOB_HM_DCR", "MOD_NAME", "NEZ_1", "NO ACTION", "NOAP", "NOT REQT ADDL INFO", "NOTARIZE_DOC", "NOT_OF DENIAL OF EXS", "NOT_OF INTENT REM", "NOT_OF REMOVAL OF EX", "NOT_QUESTIONING EXS", "OMIT_PROP", "ONLINE_RESEARCH", "OPEN RECS RQT", "OV55", "OVER65_14_AUDIT REV", "OVER65_15_AUDIT REV", "OVER65_17_AUDIT REV", "OVER65_18_AUDIT REV", "OVER65_19_AUDIT REV", "OVER65_20_AUDIT_REV", "OWNDISPUTE", "OWNERCHNG", "OWNERISSUE", "OWNER_CHG", "PERS PROP", "PINCHANGEOWN", "PINCREATEAGT", "PINCREATEOWN", "PL_BPP LETTER", "PROPDISPUT", "PROTC", "PROTEST", "PROTEST_OV65", "PRV_YR_CMMT", "RECDELPROP", "REFILE FOR EX (S)", "REINSTATE EXEMP", "REMOVAL OF CONF", "REMOVAL_EXEMP", "REMOVAL_TD", "REN PENAL", "RENDITION", "REND_EXTEN", "REND_MIN", "REND_PEN", "RENPENFILE", "RET MAIL MINERALS", "RETURN ML", "RET_APPRL_NOTICE", "RET_MIN_APPRL_NOTICE", "RQT_RA", "SALES PRIC", "SEE NOTES", "SETTLEMENT", "SETTLEMENT STATEMENT", "SITUS ADD ISSUE", "SL", "SPLIT_MIN", "STMNTMAIL", "SURVEY", "SURVEY RQTED", "SURVEY-RECD", "SURV_SPOUSE_MASSS", "SYSTEM", "T", "T-03", "T-06", "T-10", "TAX CEILING CERT", "TAX PYMT", "TAX UNIT", "TAX UNIT_RETURN MAIL", "TCCPRINT", "TNT_INQUIRY", "UDIREMSTAT", "UNDER CONST", "VALUECERT", "VAL_ISSUE", "WAIVE_30", "WD_MIN", "WLM_RAP", "WLM_RPT", "X25.19A", "Ownership Transfer", "Ownership Transfer - Just Appraised", "Property Delete", "Property Activate", "Property Inactivate", "Property Reactivate", "BPP Rendition", "Property Split", "Roll Correction", "Property Merge", "Legacy Notes", "Legacy Event"]');

##################### insert Legacy Notes eventType into pEvent #####################
# SET SESSION group_concat_max_len = 1000000; -- need to increase limit to insert notes
#
# insert into bowie_events.pEvent
# (
# formID, eventData , eventType, eventDescription , createDt , updateDt, createdBy, updatedBy, fromID
# )
# SELECT
#     @formID as formID, JSON_OBJECT('NotesKey', nh.NotesKey,
#                                    'NoteSeq', ndt.NoteSeq,
#                                    'EventDate', DATE_FORMAT(now(),'%Y-%m-%d'),
#                                    'Data_Entry_Date', DATE_FORMAT(STR_TO_DATE(nh.CreatedOn, '%Y%m%d'), '%Y-%m-%d'),
#                                    'Data_Entry_Staff', trim(nh.CreatedBy),
#                                    'Data_Entry_Comment', LEFT(TRIM(BOTH '"' FROM CONCAT_WS(' ',NULLIF(TRIM(n.NoteRemark), ''),NULLIF(TRIM(n.NOTRM2), ''))),200),
#                                    'PropertyKey', aa.PropertyKey),
#     'Legacy Notes',
#     LEFT(
#       TRIM(
#         CONCAT_WS(' - ', nh.Subject, COALESCE(ndt.note_text, ''))
#       ), 500
#     ) AS eventDescription,
#     DATE_FORMAT(STR_TO_DATE(nh.CreatedOn, '%Y%m%d'), '%Y-%m-%d 00:00:00') as createDt,
#     now(),
#     trim(nh.CreatedBy) as createdBy,
#     @p_user,
#     aa.PropertyKey
# FROM conversionDB.AppraisalAccount aa
# JOIN (
#     SELECT AuditTaxYear, PropertyKey, MIN(AcctXRef) AS AcctXRef
#     FROM conversionDB.AcctXREF
#     WHERE AcctXRefType = 'ACCT'
#     GROUP BY AuditTaxYear, PropertyKey
# ) axref
#   ON axref.AuditTaxYear = aa.TaxYear
#  AND axref.PropertyKey  = aa.PropertyKey
#  AND axref.AcctXRef     = aa.AcctXref1
# JOIN conversionDB.Property p
#   ON p.AuditTaxYear = aa.TaxYear
#  AND p.PropertyKey = aa.PropertyKey
# JOIN conversionDB.Note n
#   ON n.NotesKey = p.NotesKey
#  AND n.NoteSource = 'PRPC'
# JOIN conversionDB.NoteHeader nh
#   ON nh.NotesKey = n.NotesKey
# LEFT JOIN (
#     SELECT
#       NotesKey,
#       NoteSeq,
#       GROUP_CONCAT(NoteText ORDER BY NDTSEQ SEPARATOR '') AS note_text
#     FROM conversionDB.NoteDetail
#     GROUP BY NotesKey, NoteSeq
# ) ndt
#   ON ndt.NotesKey = nh.NotesKey
#  AND ndt.NoteSeq  = nh.NoteSeq
# WHERE aa.TaxYear BETWEEN @pYearMin and @pYearMax
#   AND aa.JurisdictionType = 'CAD'
# GROUP BY
#     aa.PropertyKey,
#     nh.NotesKey,
#     nh.NoteSeq,
#     nh.Subject,
#     nh.CreatedBy,
#     nh.CreatedOn,
#     nh.NoteClass
# ORDER BY
#     nh.NotesKey,
#     nh.NoteSeq;
#
# select *
# from bowie_events.pEvent
# where eventType = 'Legacy Notes';

##################### connecting events to "property events" - inserting to pEventObjects (main connecting table) #####################

# insert into bowie_events.pEventObjects (
# 	eventID,
# 	objectID,
# 	createdBy,
# 	createDt,
#     updateDt,
#     updatedBy)
# select distinct
# 	e.eventID,
# 	e.fromID as objectID,
# 	e.createdBy as createdBy,
# 	e.createDt as createDt,
# 	now(),
# 	@p_user
# from
# 	bowie_events.pEvent e
# where e.formID = @formID
# and not exists (select * from bowie_events.pEventObjects eo where eo.eventID = e.eventID and eo.objectID = e.fromID)
# ;
#
# select *
# from bowie_events.pEventObjects
# where updatedBy = @p_user;

#################### insert Legacy Event eventType into pEvent #####################
# insert into bowie_events.pEvent
# (
# formID, eventData , eventType, eventDescription , createDt , updateDt, createdBy, updatedBy, fromID
# )
# SELECT @formID                                                             as formID
#      , JSON_OBJECT('cid', ae.cid,
#                    'EventDate', DATE_FORMAT(now(), '%Y-%m-%d'),
#                    'EventDesc', LEFT(TRIM(BOTH '"' FROM NULLIF(TRIM(cc.CCD_Description), '')), 200),
#                    'Data_Entry_Date', COALESCE(
#                            CASE
#                                WHEN TRIM(ae.AccountEventOverrideDesc) REGEXP '^[0-9]{8}$'
#                                    THEN DATE_FORMAT(
#                                        STR_TO_DATE(TRIM(ae.AccountEventOverrideDesc), '%Y%m%d'),
#                                        '%Y-%m-%d')
#                                ELSE NULL
#                            END,
#                            DATE_FORMAT(
#                                    STR_TO_DATE(TRIM(CAST(ae.BeginningTs AS CHAR)), '%Y%m%d%H%i%s'),
#                                    '%Y-%m-%d'
#                            )
#                                       ),
#                    'RefYear', CAST(ae.AuditTaxYear AS UNSIGNED),
#                    'Data_Entry_Staff', trim(ae.UserCd),
#                    'PropertyKey', ae.PropertyKey)
#      , 'Legacy Event'
#      , LEFT(TRIM(BOTH '"' FROM NULLIF(TRIM(cc.CCD_Description), '')), 500) AS eventDescription
#      , COALESCE(
#         CASE
#             WHEN TRIM(ae.AccountEventOverrideDesc) REGEXP '^[0-9]{8}$'
#                 THEN DATE_FORMAT(
#                     STR_TO_DATE(TRIM(ae.AccountEventOverrideDesc), '%Y%m%d'),
#                     '%Y-%m-%d')
#             ELSE NULL
#         END,
#         DATE_FORMAT(
#                 STR_TO_DATE(TRIM(CAST(ae.BeginningTs AS CHAR)), '%Y%m%d%H%i%s'),
#                 '%Y-%m-%d'
#         )
#        )                                                                   as createDt
#      , now()
#      , trim(ae.UserCd)                                                     as createdBy
#      , @p_user
#      , ae.PropertyKey
# from conversionDB.AccountEvent ae
# left join conversionDB.CommonCodeH cc
# on cc.CCD_Type = 'AEVCOD'
# and cc.CCD_Code = ae.AccountEventCode
# where ae.AuditTaxYear between @pYearMin and @pYearMax
# group by ae.cid
# order by ae.AuditTaxYear, ae.PropertyKey, ae.AccountEventSeq;
#
# select *
# from bowie_events.pEvent
# where eventType = 'Legacy Event';

##################### connecting events to "property events" - inserting to pEventObjects (main connecting table) #####################
set @createdBy = 'TPConversion - insertLegacyEvent';
insert into bowie_events.pEventObjects (
	eventID,
	objectID,
	createdBy,
	createDt,
    updateDt,
    updatedBy)
select distinct
	e.eventID,
	e.fromID as objectID,
	e.createdBy as createdBy,
	e.createDt as createDt,
	now(),
	@createdBy
from
	bowie_events.pEvent e
where e.formID = @formID
and not exists (select * from bowie_events.pEventObjects eo where eo.eventID = e.eventID and eo.objectID = e.fromID)
;

select *
from bowie_events.pEventObjects
where updatedBy = @createdBy;
