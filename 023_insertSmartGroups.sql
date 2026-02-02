set @pYearMin = 2020;
set @pYearMax = 2025;
set @p_user = 'TPConversion - insertSmartGroups';

delete from smartGroupPropAssoc
where createdBy = @p_user;
delete from smartGroup
where createdBy = @p_user;



# insert ignore into codefile
#     (codeFileYear, codeFileType, codeFileName, codeName, codeDescription, codeDefinition, createdBy, createDt, active, isSystem)
# values  (0, 'Property', 'Smart Groups', 'EA', 'Effective Acres Group', '{}', @p_user, now(), true, false),
#         (0, 'Property', 'Smart Groups', 'CH313', 'Chapter 313', '{}', @p_user, now(), true, false),
#         (0, 'Property', 'Smart Groups', 'HS', 'Homestead SmartGroup', '{}', @p_user, now(), true, false);


# select distinct aa.PropertyKey as pid,
#        aa.TaxYear as pYear,
#        aa.OwnerName1,
#        aa.OwnerName2,
#        aa.GenHSExemptionPct,
#        aa.GenHSExemption
# from conversionDB.AppraisalAccount aa
# where aa.TaxYear between @pYearMin and @pYearMax
# and aa.JurisdictionCd = '01B'
# and aa.GenHSExemption = 'Y'
# and aa.GenHSExemptionPct < 1.0000
# and aa.GenHSExemptionPct <> .5
# order by aa.OwnerName1, aa.PropertyKey;

DROP TABLE IF EXISTS conversionDB.LinkedHSAccounts;
CREATE TABLE conversionDB.LinkedHSAccounts AS
SELECT
    a.PropertyKey AS pid,
    a.TaxYear AS pYear,
    a.OwnerName1,
    a.OwnerName2,
    a.GenHSExemptionPct,

    o.groupID,
    o.all_pids AS linkedPropertyKeys

FROM conversionDB.AppraisalAccount a
JOIN (
    SELECT
        OwnerName1,
        LPAD(
            MOD(
                CONV(SUBSTRING(MD5(OwnerName1), 1, 8), 16, 10),
                1000000
            ),
            6,
            '0'
        ) AS groupID,

        CONCAT('LEGACY HS: ', GROUP_CONCAT(DISTINCT PropertyKey ORDER BY PropertyKey SEPARATOR ',')) AS all_pids,
        COUNT(DISTINCT PropertyKey) AS cnt

    FROM conversionDB.AppraisalAccount
    WHERE TaxYear BETWEEN @pYearMin and @pYearMax
      AND JurisdictionCd = '01B'
      AND GenHSExemption = 'Y'
      AND GenHSExemptionPct < 1.0000
      AND GenHSExemptionPct <> 0.5
      AND TRIM(IFNULL(OwnerName1,'')) <> ''
    GROUP BY OwnerName1
    HAVING cnt >= 2
) o
  ON o.OwnerName1 = a.OwnerName1
WHERE a.TaxYear BETWEEN @pYearMin and @pYearMax
  AND a.JurisdictionCd = '01B'
  AND a.GenHSExemption = 'Y'
  AND a.GenHSExemptionPct < 1.0000
  AND a.GenHSExemptionPct <> 0.5
  AND TRIM(IFNULL(a.OwnerName1,'')) <> ''
ORDER BY pYear, OwnerName1, pid;


INSERT INTO smartGroup (
    groupYr,
    groupComment,
    groupName,
    fromGroupID,
    groupType,
    createdBy,
    createDt
)
SELECT
    s.pYear AS groupYr,
    'Legacy HS Group' AS groupComment,
    s.linkedPropertyKeys AS groupName,
    s.groupID AS fromGroupID,
    'HS' AS groupType,
    @p_user AS createdBy,
    NOW() AS createDt
FROM (
    -- one row per (pYear, groupID)
    SELECT
        pYear,
        groupID,
        MAX(linkedPropertyKeys) AS linkedPropertyKeys
    FROM conversionDB.LinkedHSAccounts
    WHERE pYear BETWEEN @pYearMin AND @pYearMax
    GROUP BY pYear, groupID
) s
WHERE NOT EXISTS (
    SELECT 1
    FROM smartGroup sg
    WHERE sg.groupYr = s.pYear
      AND sg.fromGroupID = s.groupID
      AND sg.groupType = 'HS'
);


select *
from smartGroup;


insert into smartGroupPropAssoc(
	groupID,
	pID,
	createdBy,
	createDt
)
select
	sg.groupID,
	pid,
	@p_user as createdBy,
	sg.createDt as createDt
from conversionDB.LinkedHSAccounts lha
	join smartGroup sg
	on lha.groupID = sg.fromGroupID
		and lha.pYear = sg.groupYr
		and groupType = 'HS'
where lha.pYear between @pYearMin and @pYearMax
and not exists (select * from smartGroupPropAssoc pa where pa.groupID = sg.groupID and pa.pID = lha.pid)
order by groupID;



select *
from smartGroupPropAssoc;


#################### list of accounts that were not grouped
SELECT
    a.PropertyKey AS pid,
    a.TaxYear     AS pYear,
    a.OwnerName1,
    a.OwnerName2,
    a.GenHSExemptionPct
FROM conversionDB.AppraisalAccount a
LEFT JOIN (
    SELECT
        OwnerName1
    FROM conversionDB.AppraisalAccount
    WHERE TaxYear BETWEEN @pYearMin and @pYearMax
      AND JurisdictionCd = '01B'
      AND GenHSExemption = 'Y'
      AND GenHSExemptionPct < 1.0000
      AND GenHSExemptionPct <> 0.5
      AND TRIM(IFNULL(OwnerName1,'')) <> ''
    GROUP BY OwnerName1
    HAVING COUNT(DISTINCT PropertyKey) >= 2
) g
  ON g.OwnerName1 = a.OwnerName1
WHERE a.TaxYear BETWEEN @pYearMin and @pYearMax
  AND a.JurisdictionCd = '01B'
  AND a.GenHSExemption = 'Y'
  AND a.GenHSExemptionPct < 1.0000
  AND a.GenHSExemptionPct <> 0.5
  AND TRIM(IFNULL(a.OwnerName1,'')) <> ''
  AND g.OwnerName1 IS NULL
ORDER BY a.TaxYear, a.OwnerName1, a.PropertyKey;