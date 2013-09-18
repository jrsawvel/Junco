-- drop table if exists junco_following;
create table junco_following (
  id 			mediumint unsigned NOT NULL auto_increment primary key,
  type                  char(1) not null default 'u', -- u=user t=tag b=a user's tag s=search string
  userid 		mediumint(8) unsigned NOT NULL default '0',
  followinguserid	mediumint(8) unsigned NOT NULL default '0', -- if of user being followed by above userid
  followingstring       varchar(255) default '',  -- for single tag names or search strings
  createddate	        datetime
) TYPE=MyISAM;
