set @pYearMin = 2020;
set @pYearMax = 2025;


set @createdBy = 'TPConversion - insertTIRZ';
set @p_user = 'TPConversion - insertTIRZ';
set @createDt = date(now());
set @p_skipTrigger = 1;


# set foreign_key_checks = 0;
# truncate propertyTirzTaxingUnits;
# truncate tirzTaxingUnits;
# truncate tirz;
# set foreign_key_checks = 1;


#TIRZ base year mapping (values are obtain from pdf submitted by client
DROP TEMPORARY TABLE IF EXISTS temp_tirz_values;
-- Create temporary table
CREATE TEMPORARY TABLE temp_tirz_values (
    JurisdictionCd VARCHAR(10),
    BaseYear INT,
    EndDate DATE,
    TaxYear INT,
    BaseValues BIGINT
);

-- Insert data
INSERT INTO temp_tirz_values
    (JurisdictionCd, BaseYear, EndDate, TaxYear, BaseValues)
VALUES
    ('01B1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2020, 251433805),
    ('01B1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2021, 251433805),
    ('01B1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2022, 251433805),
    ('01B1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2023, 251433805),
    ('01B1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2024, 251433805),
    ('01B1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2025, 251433805),

    ('01B2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2020, 65568769),
    ('01B2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2021, 65568769),
    ('01B2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2022, 65568769),
    ('01B2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2023, 65568769),
    ('01B2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2024, 65568769),
    ('01B2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2025, 65568769),

    ('01B3', 2011, STR_TO_DATE('1/28/26','%m/%d/%y'), 2020, 11006727),
    ('01B3', 2011, STR_TO_DATE('1/28/26','%m/%d/%y'), 2021, 11006727),
    ('01B3', 2011, STR_TO_DATE('1/28/26','%m/%d/%y'), 2022, 11606727),
    ('01B3', 2011, STR_TO_DATE('1/28/26','%m/%d/%y'), 2023, 11006727),
    ('01B3', 2011, STR_TO_DATE('1/28/26','%m/%d/%y'), 2024, 11006727),
    ('01B3', 2011, STR_TO_DATE('1/28/26','%m/%d/%y'), 2025, 14006727),

    ('02N1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2020, 11216540),
    ('02N1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2021, 11216540),
    ('02N1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2022, 11216540),
    ('02N1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2023, 11216540),
    ('02N1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2024, 11216540),
    ('02N1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2025, 11216540),

    ('02T1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2020, 250924138),
    ('02T1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2021, 250924138),
    ('02T1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2022, 250924138),
    ('02T1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2023, 250924138),
    ('02T1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2024, 250924138),
    ('02T1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2025, 250924138),

    ('02T2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2020, 65799167),
    ('02T2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2021, 65799167),
    ('02T2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2022, 65799167),
    ('02T2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2023, 65799167),
    ('02T2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2024, 65799167),
    ('02T2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2025, 65799167);


SELECT * FROM temp_tirz_values;




# Create Base TIRZ records
# insert into tirz (
# 	tirzCd,
# 	tirzDescription,
# 	tirzBaseYear,
#     tirzBaseValue,
# 	createdBy,
# 	createDt,
# 	legacyJSON)
# select
# 	aj.JurisdictionCd as tirzCd,
# 	aj.JurisdictionName as tirzDescription,
# 	tv.BaseYear as tirzBaseYear,
# 	tv.BaseValues,
# 	@createdBy as createdBy,
# 	@createDt as createDt,
# 	json_object(
# 		'tif_zone', json_object(
# 		'JurisdictionCd', aj.JurisdictionCd,
# 		'JurisdictionName', aj.JurisdictionName,
# 		'BaseYear', tv.BaseYear
# 		)
# 		) as legacyJSON
# from conversionDB.AppraisalJurisdiction aj
# join temp_tirz_values tv
#     on tv.JurisdictionCd = aj.JurisdictionCd
#     and tv.TaxYear = aj.TaxYear
# where not exists(select * from tirz where tirzCd = aj.JurisdictionCd)
# and aj.TaxYear between @pYearMin and @pYearMax
# group by aj.JurisdictionCd;
#
# select *
# from tirz;

# Link TIRZ to Taxing Units
# insert into tirzTaxingUnits (
# 	tirzCd,
# 	taxingUnitID,
# 	createdBy,
# 	createDt,
# 	legacyJSON)
# select
# 	aj.JurisdictionCd as tirzCd,
# 	tu.taxingUnitID as taxingUnitID,
# 	@createdBy as createdBy,
# 	@createDt as createDt,
# 	json_object('taxing unit link',
# 				json_object(
# 					'tif_taxyear', json_arrayagg(tv.TaxYear),
# 					'JurisdictionCd', aj.JurisdictionCd,
# 					'entity_id', tu.taxingUnitID
# 					)) as legacyJSON
# from conversionDB.AppraisalJurisdiction aj
# join temp_tirz_values tv
#     on tv.JurisdictionCd = aj.JurisdictionCd
#     and tv.TaxYear = aj.TaxYear
# join taxingUnit tu
#     on tu.taxingUnitCode = aj.JurisdictionCd
# where not exists(select * from tirzTaxingUnits ttu where ttu.tirzCd = aj.JurisdictionCd)
# and aj.TaxYear between @pYearMin and @pYearMax
# group by aj.JurisdictionCd
# order by tv.TaxYear;

# select *
# from tirzTaxingUnits;


drop temporary table if exists propertiesWithTIRZ;
create temporary table propertiesWithTIRZ
select
	pj.AuditTaxYear,
	pj.PropertyKey,
	ttu.tirzCd
from conversionDB.PropertyJurisdiction pj
join tirzTaxingUnits ttu
    on ttu.tirzCd = pj.JurisdictionCode
where  pj.AuditTaxYear in (select pYear from appraisalYr)
and pj.AuditTaxYear between 2020 and 2025;


create index locator on propertiesWithTIRZ (AuditTaxYear, PropertyKey);

select *
from propertiesWithTIRZ;

# Import property-specific TIRZ data
insert into propertyTirzTaxingUnits (pYear, pID, pVersion, pRollCorr, pTaxingUnitID, improvementValue, landValue)
select
	pv.AuditTaxYear as pYear,
	pv.PropertyKey as pID,
	0 as pVersion,
	p.prollcorr as pRollCorr,
#    tif_zone_code,
	pTaxingUnitID,
	improvementValue,
	landValue
from
	propertiesWithTIRZ pv
	join property p
	on p.pyear = pv.AuditTaxYear
		and p.pid = pv.PropertyKey
		and p.pversion = 0
	join tirzTaxingUnits tirz
		on pv.tirzCd = tirz.tirzCd
	join propertyTaxingUnit ptu
		using (pYear, pID, pVersion, pRollCorr, taxingUnitID)
	join lateral (select
					  aa.TotalImprovementVal as improvementValue,
					  aa.TotalLandVal as landValue,
					  count(*) as aaMatches
				  from
					  conversionDB.AppraisalAccount aa
				  where pv.AuditTaxYear = aa.TaxYear
					and pv.PropertyKey = aa.PropertyKey
					and pv.tirzCd = aa.JurisdictionCd
		) aa
where not exists(select tirztu.propertyTirzTaxingUnitID from propertyTirzTaxingUnits tirztu where tirztu.pTaxingUnitID = ptu.ptaxingUnitID);


select * from propertyTirzTaxingUnits;



