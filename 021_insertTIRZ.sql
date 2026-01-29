set @pYearMin = 2020;
set @pYearMax = 2025;


set @createdBy = 'TPConversion - insertTIRZ';
set @p_user = 'TPConversion - insertTIRZ';
set @createDt = date(now());
set @p_skipTrigger = 1;


# set foreign_key_checks = 0;
# truncate propertyTirzTaxingUnits;
# # truncate tirzTaxingUnits;
# # truncate tirz;
# set foreign_key_checks = 1;


#TIRZ base year mapping (values are obtain from pdf submitted by client
DROP TEMPORARY TABLE IF EXISTS temp_tirz_values;
-- Create temporary table
CREATE TEMPORARY TABLE temp_tirz_values (
    TIRZ VARCHAR(10),
    tirzDesc VARCHAR(50),
    JurisdictionCd VARCHAR(10),
    BaseYear INT,
    EndDate DATE,
    TaxYear INT,
    BaseValues BIGINT
);

-- Insert data
INSERT INTO temp_tirz_values
    (TIRZ,tirzDesc,JurisdictionCd, BaseYear, EndDate, TaxYear, BaseValues)
VALUES
    ('T1', 'TIRZ 1 (North)', '01B1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2020, 251433805),
    ('T1', 'TIRZ 1 (North)', '01B1',2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2021, 251433805),
    ('T1', 'TIRZ 1 (North)','01B1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2022, 251433805),
    ('T1', 'TIRZ 1 (North)', '01B1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2023, 251433805),
    ('T1', 'TIRZ 1 (North)', '01B1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2024, 251433805),
    ('T1', 'TIRZ 1 (North)', '01B1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2025, 251433805),

    ('t2a', 'TIRZ 2 (Downtown)', '01B2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2020, 65568769),
    ('t2a', 'TIRZ 2 (Downtown)', '01B2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2021, 65568769),
    ('t2a', 'TIRZ 2 (Downtown)', '01B2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2022, 65568769),
    ('t2a', 'TIRZ 2 (Downtown)', '01B2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2023, 65568769),
    ('t2a', 'TIRZ 2 (Downtown)', '01B2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2024, 65568769),
    ('t2a', 'TIRZ 2 (Downtown)', '01B2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2025, 65568769),

    ('T3', 'TIRZ 3', '01B3', 2011, STR_TO_DATE('1/28/26','%m/%d/%y'), 2020, 11006727),
    ('T3', 'TIRZ 3', '01B3', 2011, STR_TO_DATE('1/28/26','%m/%d/%y'), 2021, 11006727),
    ('T3', 'TIRZ 3', '01B3', 2011, STR_TO_DATE('1/28/26','%m/%d/%y'), 2022, 11606727),
    ('T3', 'TIRZ 3', '01B3', 2011, STR_TO_DATE('1/28/26','%m/%d/%y'), 2023, 11006727),
    ('T3', 'TIRZ 3', '01B3', 2011, STR_TO_DATE('1/28/26','%m/%d/%y'), 2024, 11006727),
    ('T3', 'TIRZ 3', '01B3', 2011, STR_TO_DATE('1/28/26','%m/%d/%y'), 2025, 14006727),

    ('T1', 'TIRZ 1 (North)', '02N1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2020, 11216540),
    ('T1', 'TIRZ 1 (North)', '02N1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2021, 11216540),
    ('T1', 'TIRZ 1 (North)', '02N1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2022, 11216540),
    ('T1', 'TIRZ 1 (North)', '02N1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2023, 11216540),
    ('T1', 'TIRZ 1 (North)', '02N1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2024, 11216540),
    ('T1', 'TIRZ 1 (North)', '02N1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2025, 11216540),

    ('T1', 'TIRZ 1 (North)', '02T1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2020, 250924138),
    ('T1', 'TIRZ 1 (North)', '02T1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2021, 250924138),
    ('T1', 'TIRZ 1 (North)', '02T1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2022, 250924138),
    ('T1', 'TIRZ 1 (North)', '02T1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2023, 250924138),
    ('T1', 'TIRZ 1 (North)', '02T1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2024, 250924138),
    ('T1', 'TIRZ 1 (North)', '02T1', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2025, 250924138),

    ('t2a', 'TIRZ 2 (Downtown)', '02T2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2020, 65799167),
    ('t2a', 'TIRZ 2 (Downtown)', '02T2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2021, 65799167),
    ('t2a', 'TIRZ 2 (Downtown)', '02T2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2022, 65799167),
    ('t2a', 'TIRZ 2 (Downtown)', '02T2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2023, 65799167),
    ('t2a', 'TIRZ 2 (Downtown)', '02T2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2024, 65799167),
    ('t2a', 'TIRZ 2 (Downtown)', '02T2', 2010, STR_TO_DATE('1/28/26','%m/%d/%y'), 2025, 65799167);


SELECT * FROM temp_tirz_values;


#
#
# # Create Base TIRZ records
# insert into tirz (
# 	tirzCd,
# 	tirzDescription,
# 	tirzBaseYear,
#     tirzBaseValue,
# 	createdBy,
# 	createDt,
# 	legacyJSON)
# SELECT
#     d.TIRZ AS tirzCd,
#     d.tirzDesc AS tirzDescription,
#     d.BaseYear AS tirzBaseYear,
#     SUM(d.BaseValues) AS BaseValues,
#     @createdBy AS createdBy,
#     @createDt AS createDt,
#     JSON_OBJECT(
#         'tif_zone', JSON_OBJECT(
#             'tirzCd', d.TIRZ,
#             'tirzDesc', d.tirzDesc,
#             'BaseYear', d.BaseYear,
#             'JurisdictionCd', JSON_ARRAYAGG(d.JurisdictionCd),
#             'JurisdictionName', JSON_ARRAYAGG(d.JurisdictionName)
#         )
#     ) AS legacyJSON
# FROM (
#     SELECT
#         tv.TIRZ,
#         tv.tirzDesc,
#         tv.BaseYear,
#         tv.BaseValues,
#         aj.JurisdictionCd,
#         aj.JurisdictionName
#     FROM conversionDB.AppraisalJurisdiction aj
#     JOIN temp_tirz_values tv
#         ON tv.JurisdictionCd = aj.JurisdictionCd
#        AND tv.TaxYear = aj.TaxYear
#     WHERE aj.TaxYear BETWEEN @pYearMin AND @pYearMax
#     GROUP BY
#         tv.TIRZ,
#         tv.tirzDesc,
#         tv.BaseYear,
#         aj.JurisdictionCd,
#         aj.JurisdictionName
# ) d
# WHERE NOT EXISTS (
#     SELECT 1
#     FROM tirz t
#     WHERE t.tirzCd = d.TIRZ
# )
# GROUP BY
#     d.TIRZ,
#     d.tirzDesc,
#     d.BaseYear;
#
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
# 	tv.TIRZ as tirzCd,
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
# order by aj.TaxYear;
#
select *
from taxingUnit;


drop temporary table if exists propertiesWithTIRZ;
create temporary table propertiesWithTIRZ
select
	pj.AuditTaxYear,
	pj.PropertyKey,
	ttu.tirzCd,
	tu.taxingUnitCode
from conversionDB.PropertyJurisdiction pj
join taxingUnit tu
    on tu.taxingUnitCode = pj.JurisdictionCode
join tirzTaxingUnits ttu
    on ttu.taxingUnitID = tu.taxingUnitID
where  pj.AuditTaxYear in (select pYear from appraisalYr)
and pj.AuditTaxYear between 2020 and 2025;


create index locator on propertiesWithTIRZ (AuditTaxYear, PropertyKey);

select *
from propertiesWithTIRZ;

update propertiesWithTIRZ tirz
	join property p
	on p.pyear = tirz.AuditTaxYear
		and p.pid = tirz.PropertyKey
		and p.pversion = 0
set
	p.tirzCd = tirz.tirzCd
where not tirz.tirzCd <=> p.tirzCd;

# Import property-specific TIRZ data
insert into propertyTirzTaxingUnits (pYear, pID, pVersion, pRollCorr, pTaxingUnitID, improvementValue, landValue)
select
	pv.AuditTaxYear as pYear,
	pv.PropertyKey as pID,
	0 as pVersion,
	p.prollcorr as pRollCorr,
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
					and pv.taxingUnitCode = aa.JurisdictionCd
		) aa
where not exists(select tirztu.propertyTirzTaxingUnitID from propertyTirzTaxingUnits tirztu where tirztu.pTaxingUnitID = ptu.ptaxingUnitID)
group by pTaxingUnitID;


select * from propertyTirzTaxingUnits
where pYear = 2025
and pID = 5078;



