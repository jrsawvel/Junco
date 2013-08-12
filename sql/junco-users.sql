-- junco.sql
-- 12-Dec-2012
--
-- mysql -p<pwd> -D <database> < junco.sql
--

drop table if exists junco_users_dvlp;
create table junco_users_dvlp (
    id			mediumint unsigned auto_increment, 
    username		varchar(30) not null,
    password		varchar(30) not null,
    email		varchar(100) not null,
    createddate		datetime,
    status		char(1) not null default 'p', -- (o) open, (p) pending, (d) deleted
    descmarkup          mediumtext,
    descformat          mediumtext,
    digest		varchar(255) not null default '0', -- for password check during login
    ipaddress           varchar(20) not null default '0.0.0.0',
    origemail           varchar(255) default NULL,
    sessionid		varchar(255) not null default '0', -- send in cookie, maintain login 
    lastblogpostviewed  mediumint unsigned not null default 0,
    unique(username),   
    unique(email),
    unique(origemail),
    primary key (id)
) TYPE=MyISAM;
