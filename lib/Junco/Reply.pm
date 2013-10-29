package Reply;

use strict;
use warnings;

use HTML::Entities;
use Junco::Format;
use Junco::BlogData;
use Junco::Stream;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");
my $dbtable_users      = Config::get_value_for("dbtable_users");
my $dbtable_tags       = Config::get_value_for("dbtable_tags");

sub show_reply_form {
    my $tmp_hash = shift;  
 
    my $replytoid = $tmp_hash->{one};

    if ( !defined($replytoid) or !StrNumUtils::is_numeric($replytoid) ) {
        Page->report_error("user", "Invalid Function.", "Cannot determine what post you are replying to.");
    } 
    User::user_allowed_to_function();

    my %replytoinfo = get_reply_to_info($replytoid);
    Page->report_error("user", "Sorry.", "Post not found.") if !%replytoinfo;

    Page->report_error("user", "Sorry.", "Post not found.") if BlogData::is_top_level_post_private($replytoid);

    my $t = Page->new("replypostform");
    $t->set_template_variable("replytotitle", $replytoinfo{replytotitle});
    $t->set_template_variable("replytoid", $replytoinfo{replytoid});
    $t->set_template_variable("replytocontentdigest", $replytoinfo{replytocontentdigest});
    $t->set_template_variable("replytoauthorname", $replytoinfo{replytoauthorname});
    $t->set_template_variable("replytocreateddate", $replytoinfo{replytocreateddate});
    $t->set_template_variable("microblogpost", $replytoinfo{microblogpost});
    $t->set_template_variable("replytourldate", $replytoinfo{replytourldate});
    $t->set_template_variable("replytocleantitle", $replytoinfo{replytocleantitle});
    $t->display_page("Reply Post Form");
}

sub show_replies {
    my $tmp_hash = shift;  

    my $stream_type = "replies";
 
    my $replytoid = $tmp_hash->{one};
# $replytoid = 4;
    my $tmp_page_num = $tmp_hash->{two}; 
    if ( !defined($replytoid) or !StrNumUtils::is_numeric($replytoid) ) {
        Page->report_error("user", "Invalid Function.", "Cannot determine what post you are replying to.");
    } 
    my %replytoinfo = get_reply_to_info($replytoid);
    Page->report_error("user", "Sorry.", "Post not found.") if !%replytoinfo;
 
    my %values = Stream::_set_page_and_user_data($replytoid, $tmp_page_num, $stream_type, "replies"); 
    my $offset = Utils::get_time_offset();
    my $sql_where_str = " where c.parentid=$replytoid and c.type='m' and c.status='o' and c.authorid=u.id ";
    $sql_where_str   .= " order by c.date asc limit $values{max_entries_plus_one} offset $values{page_offset} ";
    my $stream_data = Stream::_get_content($sql_where_str);
    my @posts = Stream::_prepare_stream_data(\%values, $stream_data);
    my %extra;
    $extra{replytoauthorname}  = $replytoinfo{replytoauthorname};
    $extra{replytocreateddate} = $replytoinfo{replytocreateddate};
    $extra{microblogpost}      = $replytoinfo{microblogpost};
    $extra{replytoid}          = $replytoinfo{replytoid};
    $extra{replytourldate}     = $replytoinfo{replytourldate};
    $extra{replytocleantitle}  = $replytoinfo{replytocleantitle};
    $extra{replytotitle}       = $replytoinfo{replytotitle};
    $extra{replytomarkup}      = $replytoinfo{replytomarkup};
    $extra{replytocount}       = $replytoinfo{replytocount};
    $extra{replytostring}      = $replytoinfo{replytocount} == 1 ? "reply" : "replies";
    $extra{showreplylink}      = 1;

    if ( $replytoinfo{replytoparentid} ) {
        my %tmp_replytoinfo = get_reply_to_info($replytoinfo{replytoparentid});
        $extra{replytoparentmicroblogpost}    = $tmp_replytoinfo{microblogpost};
        $extra{replytoparentid}    = $replytoinfo{replytoparentid};
    }

    Stream::_display_stream(\%values, \@posts, \%extra);
}

sub get_reply_to_info {
    my $replytoid = shift;

    my %hash;
    my $offset = Utils::get_time_offset();

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $reply_to_status = Config::get_value_for("reply_to_status");
    my $sql = "select c.id, c.parentid, c.authorid, c.title, c.markupcontent, c.formattedcontent, c.type, c.contentdigest, c.replycount, ";
    $sql .=      "date_format(date_add(c.date, interval $offset hour), '%b %d, %Y') as createddate, ";
    $sql .=      "date_format(date_add(c.date, interval $offset hour), '%r') as createdtime, ";
    $sql .=      "date_format(date_add(c.date, interval $offset hour), '%d%b%Y') as urldate, "; 
    $sql .=      "u.username from $dbtable_content c, $dbtable_users u  ";
    $sql .=      "where c.id=$replytoid and c.type in ('b','m') and c.status in ($reply_to_status) and c.authorid=u.id";

    $db->execute($sql);
    Page->report_error("system", "(77) Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $hash{replytoid}            = $db->getcol("id");
        $hash{replytoparentid}      = $db->getcol("parentid");
        $hash{replytoauthorid}      = $db->getcol("authorid");
        $hash{replytoauthorname}    = $db->getcol("username");
        $hash{replytotitle}         = $db->getcol("title");
        $hash{replytomarkup}        = $hash{replytotitle};
        $hash{replytourldate}       = $db->getcol("urldate");
        $hash{replytocontentdigest} = $db->getcol("contentdigest");
        $hash{replytocount}         = $db->getcol("replycount");
        $hash{replytotype}          = $db->getcol("type");
        $hash{replytocreateddate}   = $db->getcol("createddate");
        if ( $hash{replytotype} eq "m" ) {
            $hash{replytotitle}  = $db->getcol("formattedcontent");
            $hash{replytomarkup} = $db->getcol("markupcontent");
            $hash{microblogpost} = 1;
        } else {
            $hash{microblogpost} = 0;
            $hash{replytocleantitle} = Format::clean_title($hash{replytotitle}); 
        }
    } 
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return %hash;
}

sub add_reply {
    my $q = new CGI;

    my $err_msg;
    undef $err_msg;

    User::user_allowed_to_function();

    my $replytoid = $q->param("replytoid");
#testing
# $replytoid = "48";
    if ( !defined($replytoid) or !StrNumUtils::is_numeric($replytoid) ) {
        Page->report_error("user", "Invalid Function.", "Cannot determine what post you are replying to.");
    } 

    my $user_submitted_microblogtext = $q->param("microblogtext");
    my $microblogtext    = StrNumUtils::trim_spaces($user_submitted_microblogtext);
#testing
# $microblogtext = "this is a #test.\n";

    if ( !defined($microblogtext) || length($microblogtext) < 1 )  { 
       $err_msg .= "You must enter text .<br />\n";
    } 

    if ( length($microblogtext) > 300 ) {
        my $len = length($microblogtext);
        $err_msg .= "$len chars entered. Max is 300.<br />\n";
    }

    my $sb = $q->param("sb");
#testing
# $sb = "sb";
    if ( !defined($sb) || length($sb) < 1 ) {
        $err_msg .= "Missing the submit button value.<br />\n";
    }

    my $replytocontentdigest = $q->param("replytocontentdigest");
#testing
# $replytocontentdigest = "hAxY7Y2HdeSrGFfM9BhUeA";
    if ( !defined($replytocontentdigest) || length($replytocontentdigest) < 1 ) {
        $err_msg .= "Missing info about the post being replied to.<br />\n";
    }

    my $logged_in_username = User::get_logged_in_username();
    my $logged_in_userid   = User::get_logged_in_userid();

    if ( defined($err_msg) ) {
        $err_msg = "Error: " . $err_msg;
        my %replytoinfo = get_reply_to_info($replytoid);
        Page->report_error("user", "Sorry.", "Post not found.") if !%replytoinfo;
        my $t = Page->new("replypostform");
        $t->set_template_variable("microblogpostingtext", $user_submitted_microblogtext);
        $t->set_template_variable("errmsg", $err_msg);
        $t->set_template_variable("replytotitle", $replytoinfo{replytotitle});
        $t->set_template_variable("replytoid", $replytoinfo{replytoid});
        $t->set_template_variable("replytocontentdigest", $replytoinfo{replytocontentdigest});
        $t->display_page("Reply Post Form");
    } 

# todo verify replytoid and replytocontentdigest match same post.

    my %replytoinfo = get_reply_to_info($replytoid);
    my $markupcontent = $microblogtext;
    my $title = HTML::Entities::encode($markupcontent, '<>');
    my $formattedcontent = HTML::Entities::encode($markupcontent, '<>');
    $formattedcontent = StrNumUtils::url_to_link($formattedcontent);
    $formattedcontent = Format::hashtag_to_link($formattedcontent);
    $formattedcontent = Format::post_id_to_link($formattedcontent);
    $formattedcontent = Format::check_for_external_links($formattedcontent);

    my $articleid = _add_reply($replytoid, $replytoinfo{replytoauthorid}, $title, $logged_in_userid, $markupcontent, $formattedcontent);

    # my $url = Config::get_value_for("cgi_app") . "/microblog/$logged_in_username";
    # print $q->redirect( -url => $url);
    # 23may2013 print $q->redirect( -url => $ENV{HTTP_REFERER});

    my $url = Config::get_value_for("cgi_app") . "/replies/$replytoid";
    print $q->redirect( -url => $url);
    exit;
}

sub _add_reply {
    my $parentid         = shift;
    my $parentauthorid   = shift;
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

    my $sql;
    $sql .= "insert into $dbtable_content (parentid, parentauthorid, title, markupcontent, formattedcontent, type, status, authorid, date, contentdigest, createdby, createddate, tags, ipaddress)";
    $sql .= " values ($parentid, $parentauthorid, $title, $markupcontent, $formattedcontent, 'm', '$status', $userid, '$datetime', '$contentdigest', $userid, '$datetime', $quoted_tag_list_str, '$ENV{REMOTE_ADDR}')";
    my $articleid = $db->execute($sql);
    Page->report_error("system", "(32) Error executing SQL", $db->errstr) if $db->err;

    foreach (@tags) {
        my $tag = $_;
        $tag = $db->quote($tag);
        if ( $tag ) {
            $sql = "insert into $dbtable_tags (name, articleid, type, status, createdby, createddate) "; 
            $sql .= " values ($tag, $articleid, 'm', 'o', $userid, '$datetime') "; 
            $db->execute($sql);
            Page->report_error("system", "(32-a) Error executing SQL", $db->errstr) if $db->err;
        }
    }

    $sql = "update $dbtable_content set replycount=replycount+1 where id=$parentid";
    $db->execute($sql);
    Page->report_error("system", "(32-a) Error executing SQL", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $articleid;
}

sub show_replies_stream {
    my $tmp_hash = shift;  

    User::user_allowed_to_function();

    my $logged_in_username = User::get_logged_in_username();
    my $logged_in_userid   = User::get_logged_in_userid();
    if ( !$logged_in_username or !$logged_in_userid ) {
        my $t = Page->new("notloggedin");
        $t->display_page("Not Logged-in");
        exit;
    } 

    my $page_num = 1;

    if ( $tmp_hash->{two} ) {
        $page_num = $tmp_hash->{two};
    }

    my %values           = Stream::_set_page_and_user_data("All", $page_num, "repliesstream", "stream"); 
    my $sql_where_str = " where c.parentauthorid=$logged_in_userid and c.authorid != $logged_in_userid and $values{type} and $values{status} and c.authorid=u.id ";
    $sql_where_str    .= " order by c.date desc limit $values{max_entries_plus_one} offset $values{page_offset} ";
    my $stream_data      = Stream::_get_content($sql_where_str);
    my @posts            = Stream::_prepare_stream_data(\%values, $stream_data);
    Stream::_display_stream(\%values, \@posts);
}

1;
