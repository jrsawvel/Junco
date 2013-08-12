
drop table if exists junco_tags_dvlp;
create table junco_tags_dvlp (
  id 			mediumint unsigned NOT NULL auto_increment primary key,
  name 			varchar(50) NOT NULL default '',
  articleid 		mediumint(8) unsigned NOT NULL default '0',
  type 			char(1) NOT NULL default 'x', -- b blog tag, m microblog tag
  status               	char(1) NOT NULL default 'x', -- o open, d deleted
  createdby 		smallint unsigned not null,
  createddate	        datetime,
  unique(type,name,articleid)
) TYPE=MyISAM;
