set @pYearMin = 2020;
set @pYearMax = 2025;


set @createdBy = 'TPConversion - insertTIRZ';
set @createDt = date(now());
set @p_skipTrigger = 1;

/*
set foreign_key_checks = 0;
truncate propertyTirzTaxingUnits;
truncate tirzTaxingUnits;
truncate tirz;
set foreign_key_checks = 1;
*/

# Create Base TIRZ records
insert into tirz (
	tirzCd,
	tirzDescription,
	tirzBaseYear,
	tirzEndDt,
	createdBy,
	createDt,
	legacyJSON)
select
	tif_zone_code as tirzCd,
	tif_zone_description as tirzDescription,
	tif_zone_base_year as tirzBaseYear,
	tif_zone_end_date as tirzEndDt,
	@createdBy as createdBy,
	@createDt as createDt,
	json_object(
		'tif_zone', json_object(
		'tif_zone_code', tif_zone_code,
		'tif_zone_description', tif_zone_description,
		'tif_zone_base_year', tif_zone_base_year,
		'tif_zone_end_date', date(tif_zone_end_date),
		'tif_zone_year', json_arrayagg(tif_zone_year),
		'collections_only', if(collections_only, true, false)
		)
		) as legacyJSON
from
	conversionDB.tif_zone
where not exists(select * from tirz where tirzCd = tif_zone_code)
and tif_zone_year between @pYearMin and @pYearMax
group by tif_zone_code;



select *
from conversionDB.AppraisalJurisdiction aj
where aj.TaxYear = 2025
    and aj.JurisdictionName like '% T%'

