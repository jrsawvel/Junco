-- junco-content.sql
-- 12-Dec-2012
--
-- mysql -p<pwd> -D <database> < junco.sql
--

-- drop table if exists junco_content;
create table junco_content(
    id			mediumint unsigned auto_increment primary key,
    parentid		mediumint unsigned not null default 0, -- (refers_to) this id number shows which article the content belongs to. if type='c', then it's the article id the comment belongs to. if status='v', then it's what article the old version belongs to. 
    parentauthorid      mediumint unsigned not null default 0, -- (refers_to) this author id of the blog post that is being replied to
    title		varchar(255) not null,
    markupcontent	mediumtext not null,
    formattedcontent	mediumtext not null,
    type		char(1) not null default 'b',  -- (b) blog posting on the front page, (m) microblog posting
    status		char(1) not null default 'o',  -- (o) open or approved, (d) deleted, (v) old version, (p) pending 
    authorid            smallint unsigned not null,
    date		datetime,
    replycount          mediumint unsigned not null default 0,
    hidereply           char(1) not null default 'n',  -- y = user hides a reply post link from the user's blog post
    version		mediumint unsigned not null default 1, 
    contentdigest       varchar(255),
    createdby           smallint unsigned not null, 
    createddate	        datetime, 
    editreason          varchar(255),
    tags                varchar(255),
    ipaddress           varchar(20) not null default '0.0.0.0',
    importdate          datetime,
    index(parentid)
) TYPE=MyISAM;

