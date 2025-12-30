use bowie_appraisal;

set @pYearMin = 2020;
set @pYearMax = 2025;
set @currentYear = 2025;
set @createdBy = 'TP Conversion';
set @createDt = date(now());
set @p_skipTrigger = 1;


truncate currentYear;

insert into currentYear (currYear)
select @currentYear;

select * from currentYear;


drop temporary table if exists pyears;
create temporary table pyears
with recursive pyearsCTE as (
	select
		@pYearMin as pyear
	union all
	select
		pyear + 1 as pyear
	from
		pyearsCTE
	where pyearsCTE.pyear < @pYearMax
							)
select *
from
	pyearsCTE;



set foreign_key_checks = 0;
truncate appraisalYr;
insert into appraisalYr (pYear, yrStatus, certifiedDt)
select pyear, if(pyear = @currentYear,'Open','Certified') as yrStatus,  if(pyear <> @currentYear,date(concat(pyear,'-01-01')) ,null) as certifiedDt  from pyears;
set foreign_key_checks = 1;

select * from appraisalYr;


select 'system' as configurationType, 'currentAppraisalYear' as configurationName, json_object('currentAppraisalYear',@currentYear) as configurationDefinition, @createdBy, @createDt
where not exists (select configurationID from configuration where configurationName like 'currentAppraisalYear');

update configuration
set configurationDefinition = JSON_REPLACE(configurationDefinition, '$.currentAppraisalYear', @currentYear)
where configurationName like 'currentAppraisalYear';

select * from configuration where configurationName like 'currentAppraisalYear';


set @p_skipTrigger = 1;
set @createdBy = 'TP Conversion';
set @createDt = date(now());
#set foreign_key_checks = 0;  -- This is temporary since codefileConfig is not populated yet.

drop temporary table if exists codes;
create temporary table codes
(
	codeFileYear int not null,
	codeFileType varchar(45) not null,
	codeFileName varchar(45) not null,
	codeName varchar(45) not null,
	codeDescription text null,
	primary key (codeFileType, codeFileName, codeName, codeFileYear)
);

create index codefile_codeFileType_codeFileName_idx
	on codes (codeFileType, codeFileName);



INSERT IGNORE INTO codes (codefileType, codefileName, codeName, codeDescription)
Select Distinct
    'Property'                          AS codefileType,
    'Property Type'                     AS codefileName,
    CASE PropertyType
        WHEN 'REAL' THEN 'R'
        WHEN 'MINR' THEN 'MN'
        WHEN 'PERS' THEN 'P'
        WHEN 'INDS' THEN 'P'
        ELSE PropertyType
    END                                 AS codeName,
    CASE PropertyType
        WHEN 'REAL' THEN 'REAL PROPERTY'
        WHEN 'MINR' THEN 'MINERAL'
        WHEN 'PERS' THEN 'PERSONAL PROPERTY (INDUSTRIAL & UTILITIES)'
        WHEN 'INDS' THEN 'PERSONAL PROPERTY (INDUSTRIAL & UTILITIES)'
        ELSE PropertyType
    END                                 AS codeDescription
FROM conversionDB.Property;



insert into codes
select distinct AuditTaxYear,
       'Improvement',
       'Class',
       ImprovementClass,
       if(nullif(ImprovementDescescription,'') is null,
          if(nullif(ImprovementClass,'')
              is null,'(Empty)',
             ImprovementClass),
          ImprovementDescescription) as description
from conversionDB.ImpClass
where AuditTaxYear between @pYearMin and @pYearMax
order by AuditTaxYear desc, ImprovementClass;





#
insert ignore into codefile (codeFileYear,
codeFileType,
codeFileName,
codeName,
codeDescription,
createdBy,
createDt)
select codes.*,
    @createdBy as createdBy,
    @createDt as createDt
from codes;

# Cost Components require this for some reason...
insert ignore into codefile (
	codeFileYear,
	codeFileType,
	codeFileName,
	codeName,
	codeDescription,
	createdBy,
	createDt,
	active)
select
	0,
	'Improvement',
	'Type',
	'R',
	'R (Required by Prodigy)',
	@createdBy,
	now(),
	true
from
	pyears;

drop table codes;

-- sic code
insert into codefile (
                      codeFileYear,
                      codeFileType,
                      codeFileName,
                      codeName,
                      codeDescription,
                      createdBy,
                      createDt,
                      active)
select bc.AuditTaxYear,
                    'Property',
                    'SIC',
                    bc.DqBusinessType,
                    bc.DqBusinessClassDescription,
                    @p_user,
                    NOW(),
                    1
from conversionDB.DQ_BusinessClass bc
where bc.AuditTaxYear between @pYearMin and @pYearMax;

-- utilities
INSERT INTO codefile (
  codeFileYear, codeFileType, codeFileName,
  codeName, codeDescription, createdBy, createDt, active
)
SELECT
  aif.TaxYear,
  'Property',
  'Utilities',
  aif.ImprovementFeatureCode,
  MAX(aif.ImprovementFeatureDesc) AS codeDescription,   -- aggregate for ONLY_FULL_GROUP_BY safety
  @p_user,
  NOW(),
  1
FROM conversionDB.AppraisalImprovementFeature aif
WHERE aif.TaxYear BETWEEN @pYearMin AND @pYearMax
  AND aif.ImprovementFeatureType = 'UTIL'
  AND NOT EXISTS (
        SELECT 1
        FROM codefile cf
        WHERE cf.codeFileType = 'Property'
          AND cf.codeFileName = 'Utilities'
          AND cf.codeFileYear = aif.TaxYear
          AND cf.codeName     = aif.ImprovementFeatureCode
  )
GROUP BY aif.TaxYear, aif.ImprovementFeatureCode;

-- zoning
INSERT INTO codefile (
  codeFileYear, codeFileType, codeFileName,
  codeName, codeDescription, createdBy, createDt, active
)
SELECT
  alc.TaxYear,
  'Property',
  'Zoning',
  alc.LandCharCode,
  MAX(alc.LandCharDesc) AS codeDescription,   -- aggregate for ONLY_FULL_GROUP_BY safety
  @p_user,
  NOW(),
  1
FROM conversionDB.AppraisalLandCharacteristic alc
WHERE alc.TaxYear BETWEEN @pYearMin AND @pYearMax
  AND alc.LandCharType = 'ZONE'
  AND NOT EXISTS (
        SELECT 1
        FROM codefile cf
        WHERE cf.codeFileType = 'Property'
          AND cf.codeFileName = 'Zoning'
          AND cf.codeFileYear = alc.TaxYear
          AND cf.codeName     = alc.LandCharCode
  )
GROUP BY alc.TaxYear, alc.LandCharCode;

