use bowie_appraisal;
set @createdBy = 'TP - Create Market Area';
set @p_user = 'TP Conversion';

insert into marketArea (marketArea,marketAreaDescription,createdBy)
select NeighborhoodDescription, NeighborhoodDescription, @createdBy from conversionDB.Neighborhood group by NeighborhoodDescription;


insert into marketAreaDetail (marketArea,marketAreaYear,createdBy,landPct,improvementPct)
select marketArea, pYear, @createdBy,100,100
 from appraisalYr
 join marketArea; 