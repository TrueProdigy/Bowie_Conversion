use bowie_appraisal;
set @pYearMin = 2020;
set @pYearMax = 2025;


set @p_skipTrigger = 1;
set @createdBy = 'TrueProdigyConversion - insertAgent';
set @createDt = now();
set sql_safe_updates = 1;


set foreign_key_checks = 0;
truncate propertyAccountAgent;
truncate agent;
truncate agentNotes;
set foreign_key_checks = 1;

#alter table agent add legacyJSON json null;

insert into agent (
	companyName,
	addrCity,
	addrState,
	emailAddress,
	webURL,
	#ftpAddress,
	#webSuppression,
	#addrFreeForm,
	addrUnitDesignator,
	addrDeliveryLine,
	addrCountry,
	addrZip,
    contactPhone,
    legacyAgentID,
    #contactName,
	createdBy,
	createDt)
select
#    x.*,
	DWAGENT as companyName,
	City as addrCity,
	State as addrState,
	DWEMAIL as emailAddress,
	DWWEB as webURL,
	#ftp_addr as ftpAddress,
	#if(web_suppression like 'y', 1, 0) as webSuppression,
	#0 as addrFreeForm,
	Attention as addrUnitDesignator,
	CONCAT (Address1, Address2) as addrDeliveryLine,
	COUNTRY as addrCountry,
	DWPOSTAL as addrZip,
	DWPHONE1 as contactPhone,
    DWAGNKEY as legacyAgentID,
	#if(length(phone.phone_num) > 15, concat('Legacy Phone Overflow: ',phone.phone_num),null) as contactName,
	@createdBy,
	@createDt as createDt
from
	conversionDB.AppraisalAgent x;


drop temporary table if exists agentMapping;
create temporary table agentMapping
select agentID, left(agent.legacyJSON ->> '$.x_agent.xagent_code',50) as xagent_code, agent.legacyJSON ->> '$.x_agent.xagent_yr' as xagent_yr from agent;

create index agentID on agentMapping (agentID);
create index agentCode on agentMapping (xagent_code);

use bowie_appraisal;
set @pYearMin = 2020;
set @pYearMax = 2025;


set @p_skipTrigger = 1;
set @createdBy = 'TrueProdigyConversion - insertAgent';
set @createDt = now();
set sql_safe_updates = 1;

insert into propertyAccountAgent (
pYear,
pID,
pVersion,
pRollCorr,
pAccountID,
agentID,
effectiveDt,
applicationDt,
expirationDt,
mailingsTaxingUnit,
mailingsARB,
authorityResolveTaxMatters,
authorityConfidential,
mailingsCAD,
authorityProtest,
agentComment,
createdBy,
createDt)

select
	pYear,
	pID,
	pVersion,
	pRollCorr,
	pAccountID,
	a.agentID,
	DATE_FORMAT(STR_TO_DATE(agent.BeginningTs,'%Y%m%d%H%i%s'), '%Y-%m-%d 00:00:00') AS effectiveDt,
	CASE
    WHEN agent.ApplicationReceivedDate REGEXP '^[0-9]{8}$'
      THEN DATE_FORMAT(STR_TO_DATE(agent.ApplicationReceivedDate, '%Y%m%d'), '%Y-%m-%d 00:00:00')
    ELSE NULL
    END AS applicationDt,
    CASE
    WHEN agent.AgentEndDate REGEXP '^[0-9]{8}$'
      THEN DATE_FORMAT(STR_TO_DATE(agent.AgentEndDate, '%Y%m%d'), '%Y-%m-%d 00:00:00')
    ELSE NULL
    END AS expirationDt,
	CASE when agent.AgentReceivesInfoFromJurisdictions = 'T'
    then 1
    else 0
    end as mailingsTaxingUnit,
    CASE when agent.AgentReceivesInfoFromArb = 'T'
    then 1
    else 0
    end as mailingsARB,
    CASE when agent.AgentNegotiatesTaxMatters = 'T'
    then 1
    else 0
    end as authorityResolveTaxMatters,
    CASE when agent.AgentReceivesConfidentialInfo = 'T'
    then 1
    else 0
    end as authorityConfidential,
    CASE when agent.AgentReceivesInfoFromCad = 'T'
    then 1
    else 0
    end as mailingsCAD,
    CASE when agent.AgentFilesNoticeOfProtest = 'T'
    then 1
    else 0
    end as authorityProtest,
    NULLIF(agent.OtherAgentRole,'') as agentComment,
    @createdBy,
    NOW()
from property p
	join  propertyAccount pa using (pYear, pID, pVersion, pRollCorr)
    join conversionDB.AccountAgent agent on agent.PropertyKey = p.pid
    join agent a on a.legacyAgentID = agent.AgentKey
where p.pYear between @pYearMin and @pYearMax;





