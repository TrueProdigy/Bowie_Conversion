set @pYearMin = 2020;
set @pYearMax = 2025;
set @p_user = 'TPConversion - insertPropertyInspections';
set @createDt = now();

# set SQL_SAFE_UPDATES = 0;
# set foreign_key_checks = 0;
# delete from propertyInspections;
# delete from propertyInspectionsTags;
# set SQL_SAFE_UPDATES = 1;
# set foreign_key_checks = 1;
set @p_skipTrigger = 1;


# insert ignore into codefile (codeFileYear, codeFileType, codeFileName, codeName, codeDescription, createdBy, createDt)
# select distinct
#   0 as codeFileYear,
#   'Property' as codeFileType,
#   'Inspections' as codeFileName,
#   pi.inspectionReason as codeName,
#   pi.inspectionReason as codeDescription,
#   @createdBy as createdBy,
#   @createDt as createDt
# from propertyInspections pi;

INSERT INTO propertyInspections (
    pID,
    inspectionActiveDt,
    inspectionReason,
    inspectionNotes,
    inspectionCompleted,
    createdBy,
    createDt
)
WITH LatestAppraisal AS (
    SELECT
        PropertyKey,
        MAX(CAST(STR_TO_DATE(AppraisalDt, '%Y%m%d') AS DATETIME)) AS MaxAppraisalDt
    FROM conversionDB.AppraisalAccount
    WHERE JurisdictionType = 'CAD'
    GROUP BY PropertyKey
),
RankedAppraisals AS (
    SELECT
        aaf.PropertyKey AS pID,
        CAST(STR_TO_DATE(CONCAT(aaf.TaxYear, '-01-01'), '%Y-%m-%d') AS DATETIME) AS inspectionActiveDt,
        'Legacy' AS inspectionReason,
        ftc.FlagDescription AS inspectionNotes,

        IF(
            la.MaxAppraisalDt >= CAST(STR_TO_DATE(CONCAT(aaf.TaxYear, '-01-01'), '%Y-%m-%d') AS DATETIME),
            1,
            0
        ) AS inspectionCompleted,

        @p_user AS createdBy,
        NOW() AS createDt,

        ROW_NUMBER() OVER (
            PARTITION BY aaf.PropertyKey, ftc.FlagDescription
            ORDER BY aaf.TaxYear ASC   -- 🔑 MIN TaxYear
        ) AS rn
    FROM conversionDB.AppraisalAccountFlag aaf
    JOIN LatestAppraisal la
        ON la.PropertyKey = aaf.PropertyKey
    LEFT JOIN conversionDB.FlagTypesAndCodes ftc
        ON ftc.FlagCategoryType = aaf.FlagType
       AND ftc.FlagCode = aaf.FlagCode
    WHERE aaf.TaxYear BETWEEN @pYearMin AND @pYearMax
      AND (
          ftc.FlagDescription LIKE '% RECHECK'
          OR ftc.FlagDescription LIKE '% Reappraisal'
      )
)
SELECT
    pID,
    inspectionActiveDt,
    inspectionReason,
    inspectionNotes,
    inspectionCompleted,
    createdBy,
    createDt
FROM RankedAppraisals
WHERE rn = 1;

insert into propertyInspectionsTags (
	inspectionID,
	tag,
	createdBy,
	createDt)
select
	propertyInspections.inspectionID,
	'Legacy',
	@p_user,
	@createDt
from propertyInspections
where createdBy = @p_user
;


