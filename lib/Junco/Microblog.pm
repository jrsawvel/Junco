package Microblog;

use strict;

use Junco::Format;
use Junco::Reply;
use HTML::Entities;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");
my $dbtable_users      = Config::get_value_for("dbtable_users");
my $dbtable_tags       = Config::get_value_for("dbtable_tags");


sub add_microblog {
    my $q = new CGI;

    my $err_msg;
    undef $err_msg;

    User::user_allowed_to_function();

    my $user_submitted_microblogtext = $q->param("microblogtext");
    my $microblogtext    = StrNumUtils::trim_spaces($user_submitted_microblogtext);

    if ( !defined($microblogtext) || length($microblogtext) < 1 )  { 
       $err_msg .= "You must enter text .<br />\n";
    } 

    if ( length($microblogtext) > 300 ) {
        my $len = length($microblogtext);
        $err_msg .= "$len chars entered. Max is 300.<br />\n";
    }

    my $sb = $q->param("sb");
    if ( !defined($sb) || length($sb) < 1 ) {
        $err_msg .= "Missing the submit button value.<br />\n";
    }

    my $logged_in_username = User::get_logged_in_username();
    my $logged_in_userid   = User::get_logged_in_userid();

    if ( defined($err_msg) ) {
        $err_msg = "Error: " . $err_msg;
        my $t = Page->new("stream");
#        Web::set_template_variable("username_of_favorite_articles", $logged_in_username);
        $t->set_template_variable("logged_in_user_viewing_own_stream", $logged_in_username);
        $t->set_template_variable("microblogpostingtext", $user_submitted_microblogtext);
        $t->set_template_variable("errmsg", $err_msg);
        $t->display_page($logged_in_username . "'s Micro Blog");
    } 

    my $markupcontent = $microblogtext;
    my $title = HTML::Entities::encode($markupcontent, '<>');
    my $formattedcontent = HTML::Entities::encode($markupcontent, '<>');
    $formattedcontent = StrNumUtils::url_to_link($formattedcontent);
    $formattedcontent = Format::hashtag_to_link($formattedcontent);
    $formattedcontent = Format::post_id_to_link($formattedcontent);
    $formattedcontent = Format::check_for_external_links($formattedcontent);

    _add_microblog($title, $logged_in_userid, $markupcontent, $formattedcontent);

    # my $url = Config::get_value_for("cgi_app") . "/microblog/$logged_in_username";
    # print $q->redirect( -url => $url);
    # 23may2013 print $q->redirect( -url => $ENV{HTTP_REFERER});

    my $url = Config::get_value_for("home_page");
    print $q->redirect( -url => $url);

    exit;
}

sub delete_microblog {
    my $tmp_hash = shift;  

    my $articleid = $tmp_hash->{one}; 

    User::user_allowed_to_function();

    my $q = new CGI;

    _delete_microblog_post(User::get_logged_in_userid(), $articleid);
    # 23may2013 print $q->redirect( -url => $ENV{HTTP_REFERER});
    # 5jun2013 my $url = Config::get_value_for("home_page");
    # 5jun2013 print $q->redirect( -url => $url);
    print $q->redirect( -url => $ENV{HTTP_REFERER});
}

sub undelete_microblog {
    my $tmp_hash = shift;  

    my $articleid = $tmp_hash->{one}; 

    User::user_allowed_to_function();

    my $q = new CGI;

    _undelete_microblog_post(User::get_logged_in_userid(), $articleid);
    # 23may2013 print $q->redirect( -url => $ENV{HTTP_REFERER});
    # 5jun2013 my $url = Config::get_value_for("home_page");
    # 5jun2013 print $q->redirect( -url => $url);
    print $q->redirect( -url => $ENV{HTTP_REFERER});
}

sub show_microblog_post {
    my $tmp_hash = shift;  

    my $articleid = $tmp_hash->{one}; 

# testing
# $articleid = 2;

    if ( !defined($articleid)  or !$articleid or $articleid !~ /^[0-9]+$/ ) {
        Page->report_error("user", "Invalid input", "Missing or invalid article id: $articleid.");
    }

    # reference to an array of hashes used for looping in HTML::Template
    my $microblog_post = _get_microblog_post($articleid);

    Page->report_error("user", "Invalid article access.", "Data doesn't exist.") if ( !$microblog_post );

    my $t = Page->new("microblogpost");

    $t->set_template_variable("cgi_app",       $microblog_post->{cgi_app});
    $t->set_template_variable("parentid",     $microblog_post->{parentid});
    $t->set_template_variable("articleid",     $microblog_post->{articleid});
    $t->set_template_variable("microblogpost", $microblog_post->{microblogpost});
    $t->set_template_variable("createddate",   $microblog_post->{createddate});
    $t->set_template_variable("createdtime",   $microblog_post->{createdtime});
    $t->set_template_variable("authorname",    $microblog_post->{authorname});
    $t->set_template_variable("replycount",    $microblog_post->{replycount});

    if ( $microblog_post->{importdate} ) {
        $t->set_template_variable("importdateexists", 1);
        $t->set_template_variable("importdate",   $microblog_post->{importdate});
    }

    if ( $microblog_post->{parentid} ) {
        my %replytoinfo = Reply::get_reply_to_info($microblog_post->{parentid});
#        if ( $replytoinfo{microblogpost} ) {
#            $t->set_template_variable("replytotitle", $replytoinfo{replytomarkup});
#        } else {
#            $t->set_template_variable("replytotitle", $replytoinfo{replytotitle});
#        }
        $t->set_template_variable("replytoid", $replytoinfo{replytoid});
        $t->set_template_variable("microblogposttype", $replytoinfo{microblogpost});
    }

    $t->display_page("$microblog_post->{authorname}'s Micro Blog: " . $articleid);
}

########## private procedures

sub _add_microblog {
    my $title            = shift;
    my $userid           = shift;
    my $markupcontent    = shift;
    my $formattedcontent = shift;

    my $status = "o";

    my $datetime = Utils::create_datetime_stamp();

    my $tag_list_str = Format::create_tag_list_str($markupcontent);

    # remove beginning and ending pipe delimeter to make a proper delimited string
    $tag_list_str =~ s/^\|//;
    $tag_list_str =~ s/\|$//;
    my @tags = split(/\|/, $tag_list_str);
    my $tmp_tag_len = @tags;
    my $max_unique_hashtags = Config::get_value_for("max_unique_hashtags");
    if ( $tmp_tag_len > $max_unique_hashtags ) {
        Page->report_error("user", "Sorry.", "Only 7 unique hashtags are permitted.");
    }

    my @loop_data;

    my $epochsecs = time();

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $title            = $db->quote($title);
    $markupcontent    = $db->quote($markupcontent);
    $formattedcontent = $db->quote($formattedcontent);
    my $quoted_tag_list_str     = $db->quote("|" . $tag_list_str . "|");

    # create article digest
    my $md5 = Digest::MD5->new;
    $md5->add(Utils::otp_encrypt_decrypt($title, $datetime, "enc"), $userid, $datetime);
    my $contentdigest = $md5->b64digest;
    $contentdigest =~ s|[^\w]+||g;

    my $SqlStr;
    $SqlStr    .= "insert into $dbtable_content (title, markupcontent, formattedcontent, type, status, authorid, date, contentdigest, createdby, createddate, tags, ipaddress)";
    $SqlStr    .= " values ($title, $markupcontent, $formattedcontent, 'm', '$status', $userid, '$datetime', '$contentdigest', $userid, '$datetime', $quoted_tag_list_str, '$ENV{REMOTE_ADDR}')";
    my $articleid = $db->execute($SqlStr);
    Page->report_error("system", "(32) Error executing SQL", $db->errstr) if $db->err;

    foreach (@tags) {
        my $tag = $_;
        $tag = $db->quote($tag);
        if ( $tag ) {
            $SqlStr = "insert into $dbtable_tags (name, articleid, type, status, createdby, createddate) "; 
            $SqlStr .= " values ($tag, $articleid, 'm', 'o', $userid, '$datetime') "; 
            $db->execute($SqlStr);
            Page->report_error("system", "(32-a) Error executing SQL", $db->errstr) if $db->err;
        }
    }

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $articleid;
}

sub _get_microblog_post {
    my $articleid = shift;

    my $cgi_app = Config::get_value_for("cgi_app");

    my %hash = ();

    my $offset = Utils::get_time_offset();

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql = "select c.id, c.parentid, c.formattedcontent, c.replycount, c.importdate, ";
    $sql .=      "date_format(date_add(c.date, interval $offset hour), '%b %d, %Y') as createddate, ";
    $sql .=      "date_format(date_add(c.date, interval $offset hour), '%r') as createdtime, ";
    $sql .=      "u.username from $dbtable_content c, $dbtable_users u  ";
    $sql .=      "where c.id=$articleid and c.type='m' and c.status='o' and c.authorid=u.id";

    $db->execute($sql);
    Page->report_error("system", "(31) Error executing SQL", $db->errstr) if $db->err;

    while ( $db->fetchrow ) {
        $hash{articleid}        = $db->getcol("id");
        $hash{parentid}         = $db->getcol("parentid");
        $hash{microblogpost}    = $db->getcol("formattedcontent");
        $hash{createddate}      = $db->getcol("createddate");
        $hash{createdtime}      = $db->getcol("createdtime");
        $hash{authorname}       = $db->getcol("username");
        $hash{replycount}       = $db->getcol("replycount");
        $hash{importdate}       = $db->getcol("importdate");
        $hash{cgi_app}          = $cgi_app;
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect();
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return \%hash;
}

sub _delete_microblog_post {
    my $userid = shift;
    my $articleid = shift;

    my $sql;
    my $tag_list_str;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $sql = "select id,tags from $dbtable_content where id=$articleid and authorid=$userid and type='m' and status='o'";
    $db->execute($sql);
    Page->report_error("system", "(40-a) Error executing SQL", $db->errstr) if $db->err;

    if ( !$db->fetchrow ) {
        $db->disconnect;
        Page->report_error("user", "Invalid action performed.", "Content does not exist");
    } else {
        $tag_list_str = $db->getcol("tags");
    }

    $sql = "update $dbtable_content set status='d' where id=$articleid and authorid=$userid and type='m'";
    $db->execute($sql);
    Page->report_error("system", "(40-b) Error executing SQL", $db->errstr) if $db->err;
      
    if ( $tag_list_str ) {
        # remove beginning and ending pipe delimeter to make a proper delimited string
        $tag_list_str =~ s/^\|//;
        $tag_list_str =~ s/\|$//;
        my @tags = split(/\|/, $tag_list_str);
        foreach (@tags) {
            my $tag = $_;
            $tag = $db->quote($tag);
            if ( $tag ) {
                $sql = "update $dbtable_tags set status='d' where articleid=$articleid and name=$tag";
                $db->execute($sql);
                Page->report_error("system", "(32-a) Error executing SQL", $db->errstr) if $db->err;
            }
        }
    }
      
    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;
}

sub _undelete_microblog_post {
    my $userid = shift;
    my $articleid = shift;

    my $sql;
    my $tag_list_str;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $sql = "select id,tags from $dbtable_content where id=$articleid and authorid=$userid and type='m' and status='d'";
    $db->execute($sql);
    Page->report_error("system", "(41-a) Error executing SQL", $db->errstr) if $db->err;

    if ( !$db->fetchrow ) {
        $db->disconnect;
        Page->report_error("user", "Invalid action performed.", "Content does not exist");
    } else {
        $tag_list_str = $db->getcol("tags");
    }

    $sql = "update $dbtable_content set status='o' where id=$articleid and authorid=$userid and type='m'";
    $db->execute($sql);
    Page->report_error("system", "(41-b) Error executing SQL", $db->errstr) if $db->err;
      
    if ( $tag_list_str ) {
        # remove beginning and ending pipe delimeter to make a proper delimited string
        $tag_list_str =~ s/^\|//;
        $tag_list_str =~ s/\|$//;
        my @tags = split(/\|/, $tag_list_str);
        foreach (@tags) {
            my $tag = $_;
            $tag = $db->quote($tag);
            if ( $tag ) {
                $sql = "update $dbtable_tags set status='o' where articleid=$articleid and name=$tag";
                $db->execute($sql);
                Page->report_error("system", "(32-a) Error executing SQL", $db->errstr) if $db->err;
            }
        }
    }
      
    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;
}

sub kdebug {
    my $str = shift;
    Page->report_error("user", "debug", $str);
}

1;

