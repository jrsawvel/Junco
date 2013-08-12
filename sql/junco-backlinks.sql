drop table if exists junco_backlinks_dvlp ;
create table junco_backlinks_dvlp (
  id 			        mediumint unsigned NOT NULL auto_increment primary key,
  linkingfromarticleid 		mediumint(8) unsigned NOT NULL default '0',
  linkingtoarticleid 		mediumint(8) unsigned NOT NULL default '0',
  status               	        char(1) NOT NULL default 'x', -- o open, d deleted
  createdby 		        smallint unsigned not null,
  createddate	                datetime,
  unique(linkingfromarticleid,linkingtoarticleid)
) TYPE=MyISAM;
