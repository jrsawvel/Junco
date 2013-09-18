-- drop table if exists junco_sessionids;
create table junco_sessionids (
  id 			        mediumint unsigned NOT NULL auto_increment primary key,
  userid 		        mediumint unsigned NOT NULL,
  sessionid		        varchar(255) not null default '0', -- send in cookie, maintain login 
  createddate	                datetime,
  status               	        char(1) NOT NULL default 'x', -- o open, d deleted
  unique(userid,sessionid)
) TYPE=MyISAM;
