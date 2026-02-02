use bowie_appraisal;

set @pYearMin = 2020;
set @pYearMax = 2025;
set @createdBy = 'TP  - Insert Owners';
set @createDt = date(now());
set @nullDt = '1900-01-01 00:00:00';
set @confidential = 'CONFIDENTIAL OWNER';
set @p_user = 'TP - CONVERSION';

set FOREIGN_KEY_CHECKS = 0;
truncate owner;
set FOREIGN_KEY_CHECKS = 1;

drop temporary table if exists ownerTemp;

create temporary table ownerTemp
select
       o.OwnerKey
       ,o.OwnerNameOne
       ,o.BeginningTs
       ,o.ConfidentialOwner
       ,case WHEN o.ConfidentialOwner = 'T'
           THEN ad.AddressOne ELSE NULL END as oAddr
       ,case WHEN o.ConfidentialOwner = 'T'
           THEN ad.City ELSE NULL END as oCity
       ,case WHEN o.ConfidentialOwner = 'T'
           THEN ad.State ELSE NULL END as oState
       ,case WHEN o.ConfidentialOwner = 'T'
           THEN ad.PostalCode ELSE NULL END as oPostalCode
       ,case WHEN o.ConfidentialOwner = 'T'
           THEN ad.Country ELSE NULL END as oCountry
       ,ao.*
from conversionDB.Owner o
join conversionDB.AppraisalOwner ao on ao.OwnerKey = o.OwnerKey
left join conversionDB.AddressDetail ad on ad.AddressKey = o.AddressKey
where  o.DeletedFlag = 'F'
group by o.OwnerKey;

ALTER TABLE ownerTemp ADD COLUMN createdBy DATETIME;


UPDATE ownerTemp
SET createdBy = STR_TO_DATE(SUBSTRING(BeginningTs, 1, 8), '%Y%m%d')
WHERE BeginningTs IS NOT NULL AND LENGTH(BeginningTs) >= 8;

UPDATE ownerTemp
SET oPostalCode = CONCAT(SUBSTRING(oPostalCode, 1, 5), '-', SUBSTRING(oPostalCode, 6))
WHERE CHAR_LENGTH(oPostalCode) > 5 AND oPostalCode NOT LIKE '%-%';

alter table ownerTemp add index(OwnerKey);


INSERT INTO owner (
    ownerID,
    name,
    nameSecondary,
    lastName,
    firstName,
    spouseFirstName,
    spouseLastName,
    addrDeliveryLine,
    addrCity,
    addrZip,
    addrState,
    addrCountry,
    addrInternational,
    createdBy,
    createDt,
    updatedBy,
    updateDt,
    confidential,
    birthDt
)
SELECT
    OwnerKey as ownerID,
    IF(TRIM(ConfidentialOwner) IN ('T'), @confidential, TRIM(OwnerNameOne)) as name,
    NULLIF(TRIM(DWOWNER2), '') as nameSecondary,
    NULLIF(TRIM(SUBSTRING_INDEX(OwnerNameOne, ',', 1)), '') AS lastName,

NULLIF(TRIM(
  CASE
    WHEN OwnerNameOne LIKE '%&%' THEN
      TRIM(SUBSTRING_INDEX(TRIM(SUBSTRING_INDEX(OwnerNameOne, ',', -1)), '&', 1))
    ELSE
      TRIM(SUBSTRING_INDEX(OwnerNameOne, ',', -1))
  END
), '') AS firstName,

NULLIF(TRIM(
  CASE
    WHEN OwnerNameOne LIKE '%&%' THEN
      SUBSTRING_INDEX(TRIM(SUBSTRING_INDEX(OwnerNameOne, '&', -1)), ' ', 1)
  END
), '') AS spouseFirstName,

-- spouse last name = same as lastName when an ampersand exists; otherwise NULL
NULLIF(TRIM(
  CASE
    WHEN OwnerNameOne LIKE '%&%' THEN
      SUBSTRING_INDEX(OwnerNameOne, ',', 1)
  END
), '') AS spouseLastName,
    IF(TRIM(ConfidentialOwner) IN ('T'), oAddr,NULLIF(TRIM(DWADDR1), '')) as addrDeliveryLine,
    IF(TRIM(ConfidentialOwner) IN ('T'), oCity,NULLIF(TRIM(City), '')) as addrCity,
    IF(TRIM(ConfidentialOwner) IN ('T'), oPostalCode,NULLIF(TRIM(DWPOSTAL), '')) as addrZip,
    IF(TRIM(ConfidentialOwner) IN ('T'), oState,NULLIF(TRIM(DWSTATE), '')) as addrState,
    IF(NULLIF(TRIM(DWCOUNTRY), '') IS NULL OR TRIM(DWCOUNTRY) IN ('USA', 'US'), 'USA', TRIM(DWCOUNTRY)) as addrCountry,
    IF(NULLIF(TRIM(DWCOUNTRY), '') IS NULL OR TRIM(DWCOUNTRY) IN ('USA', 'US'), FALSE, TRUE) as addrInternational,
    @createdBy as createdBy,
    NULLIF(createdBy, @nullDt) as createDt,
    @createdBy as updatedBy,
    @createDt as updateDt,
    IF(TRIM(ConfidentialOwner) IN ('T'), TRUE, FALSE) as confidential,
    NULLIF(TRIM(DWBRTHDAT), @nullDt) as birthDt
#spouseDriversLicense,
#spouseDriversLicenseState,
#spouseExpirationDt,
# owner_id as referenceID -- This field needs to be extended to support 25 characters before this will work.
#regTag, -- I don't even know what this field's purpose is
#source,
#cassValidationDt,
#cassValidationBy,
#cassValidationService,
#plus4Code,
#deliveryPoint,
#deliveryPointCheckDigit,
#latitude,
#longitude,
#carrierRoute,
#autoCass,
#encryptedLicense,
#encryptedBirthDt,
#mineralVendorOwnerID
from ownerTemp b;

drop table ownerTemp;



update owner o
    join conversionDB.AppraisalOwner oname
    on oname.OwnerKey = o.ownerID
set o.nameSecondary    = CASE
                             WHEN TRIM(IFNULL(oname.Attention, '')) <> ''
                                 THEN TRIM(oname.Attention)

    -- if Address1 is a CO/%, keep it as secondary
                             WHEN TRIM(IFNULL(oname.Address1, '')) LIKE '\%%'
                                 THEN TRIM(oname.Address1)

    -- if Address1 looks like a personal/business name (not an address), use it
                             WHEN TRIM(IFNULL(oname.Address1, '')) <> ''
                                 AND TRIM(oname.Address1) NOT REGEXP '^(PO BOX|P\.?O\.?\s*BOX|BOX|#|\d)'
                                 THEN TRIM(oname.Address1)
                             ELSE ''
                         END,
    o.addrDeliveryLine = CASE
        -- co line in Address1: ignore it for delivery address
                             WHEN TRIM(IFNULL(oname.Address1, '')) LIKE '\%%'
                                 THEN
                                 CONCAT_WS(' ',
                                     -- choose the field that looks like a real street first
                                           CASE
                                               WHEN TRIM(IFNULL(oname.Address2, '')) REGEXP '^[#]'
                                                   AND TRIM(IFNULL(oname.DWADDR3, '')) <> ''
                                                   THEN TRIM(oname.DWADDR3)
                                               ELSE TRIM(oname.Address2)
                                           END,
                                     -- append the other line(s) if present and not dup
                                           CASE
                                               WHEN TRIM(IFNULL(oname.Address2, '')) REGEXP '^[#]'
                                                   THEN NULLIF(TRIM(oname.Address2), '')
                                               ELSE NULLIF(TRIM(oname.DWADDR3), '')
                                           END
                                 )

        -- PMB logic unchanged
                             WHEN TRIM(IFNULL(oname.Address1, '')) LIKE 'PMB%'
                                 THEN
                                 CONCAT_WS(' ',
                                           NULLIF(TRIM(oname.Address1), ''),
                                           NULLIF(TRIM(oname.Address2), ''),
                                           NULLIF(TRIM(oname.DWADDR3), '')
                                 )

        -- default: Address2 then DWADDR3, else fall back to Address1
                             ELSE
                                 CONCAT_WS(' ',
                                           COALESCE(NULLIF(TRIM(oname.Address2), ''), NULLIF(TRIM(oname.Address1), '')),
                                           NULLIF(TRIM(oname.DWADDR3), '')
                                 )
                         END,
    o.updateDt         = now(),
    o.updatedBy        = @p_user
where (
    TRIM(IFNULL(oname.Attention, '')) <> ''
        OR oname.Address1 LIKE '%\%%'
        OR oname.Address1 LIKE 'C\%%0%'
        OR TRIM(IFNULL(oname.Address2, '')) <> ''
    )
  AND (
    TRIM(IFNULL(oname.Attention, '')) <> ''
        OR TRIM(oname.Address1) REGEXP '^[A-Za-z]'
        OR oname.Address1 LIKE '%\%%'
    );
############################### check update
SELECT o.ownerID
     , CASE
           WHEN TRIM(IFNULL(oname.Address1, '')) LIKE '\%%'
               THEN
               CONCAT_WS(' ',
                         CASE
                             WHEN TRIM(IFNULL(oname.Address2, '')) REGEXP '^[#]'
                                 AND TRIM(IFNULL(oname.DWADDR3, '')) <> ''
                                 THEN TRIM(oname.DWADDR3)
                             ELSE TRIM(oname.Address2)
                         END,
                         CASE
                             WHEN TRIM(IFNULL(oname.Address2, '')) REGEXP '^[#]'
                                 THEN NULLIF(TRIM(oname.Address2), '')
                             ELSE NULLIF(TRIM(oname.DWADDR3), '')
                         END
               )

           WHEN TRIM(IFNULL(oname.Address1, '')) LIKE 'PMB%'
               THEN
               CONCAT_WS(' ',
                         NULLIF(TRIM(oname.Address1), ''),
                         NULLIF(TRIM(oname.Address2), ''),
                         NULLIF(TRIM(oname.DWADDR3), '')
               )

           ELSE
               CONCAT_WS(' ',
                         COALESCE(NULLIF(TRIM(oname.Address2), ''), NULLIF(TRIM(oname.Address1), '')),
                         NULLIF(TRIM(oname.DWADDR3), '')
               )
       END AS addrDeliveryLine
     , CASE
           WHEN TRIM(IFNULL(oname.Attention, '')) <> ''
               THEN TRIM(oname.Attention)
           WHEN TRIM(IFNULL(oname.Address1, '')) LIKE '\%%'
               THEN TRIM(oname.Address1)
           WHEN TRIM(IFNULL(oname.Address1, '')) <> ''
               AND TRIM(oname.Address1) NOT REGEXP '^(PO BOX|P\.?O\.?\s*BOX|BOX|#|\d)'
               THEN TRIM(oname.Address1)
           ELSE ''
       END AS nameSecondary
FROM
    owner o
        JOIN conversionDB.AppraisalOwner oname
            ON oname.OwnerKey = o.ownerID
WHERE (
    TRIM(IFNULL(oname.Attention, '')) <> ''
        OR oname.Address1 LIKE '%\%%'
        OR oname.Address1 LIKE 'C\%%0%'
        OR TRIM(IFNULL(oname.Address2, '')) <> ''
    )
  AND (
    TRIM(IFNULL(oname.Attention, '')) <> ''
        OR TRIM(oname.Address1) REGEXP '^[A-Za-z]'
        OR oname.Address1 LIKE '%\%%'
    )
#   and o.ownerID = 163498
;