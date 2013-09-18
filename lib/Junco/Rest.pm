package Rest;

use strict;
use warnings;
use MIME::Base64;
use HTML::Entities;
use Junco::Format;
use Junco::BlogTitle;
use Junco::Backlinks;
use REST::Client;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_users       = Config::get_value_for("dbtable_users");
my $dbtable_content     = Config::get_value_for("dbtable_content");
my $dbtable_tags        = Config::get_value_for("dbtable_tags");

sub create_blogpost_draft_stub {
    my $title = shift;

    # set set up some defaults:
    my $domain   = Config::get_value_for("email_host");
    my $function = 'addblog';
#    my $user = 'JR';
    my $prog = Config::get_value_for("cgi_app");
    my $datetime = Utils::create_datetime_stamp();

    my $headers = {
        'Content-type' => 'application/x-www-form-urlencoded'
    };

    # set up a REST session
    my $rest = REST::Client->new( {
           host => "http://$domain" . "$prog",
    } );

    my $markup = "$title\n\n#draftstub\ndraft=yes\n";

    

    # then we have to url encode the params that we want in the body
    my $pdata = {
        'markup'        => $markup,
        'date'          => $datetime,
        'createddate'   => $datetime,
        'sb'            => 'submit',
        'authorid'      => User::get_logged_in_userid()
    };
    my $params = $rest->buildQuery( $pdata );

    # but buildQuery() prepends a '?' so we strip that out
    $params =~ s/\?//;

    # then sent the request:
    # POST requests have 3 args: URL, BODY, HEADERS
    $rest->POST( "/rest/$function" , $params , $headers );
    return $rest->responseContent();
}

sub do_rest {
    my $tmp_hash = shift;

    my $function = $tmp_hash->{one};
    my $action   = $tmp_hash->{two};

    my $q = new CGI;
    my $request_method = $q->request_method();

    if ( $request_method eq "GET" ) {
        do_get($function, $action);
    } elsif ( $request_method eq "POST" and $function eq "addmicroblog" ) {
        add_microblog();
    } elsif ( $request_method eq "POST" and $function eq "addblog" ) {
        add_blog();
    } elsif ( $request_method eq "PUT" ) {
        do_put();
    } else {
        Page->report_error("user", "Invalid action.", "$request_method unsupported.");
    }
}

sub do_get {
    my $function = shift;
    my $value    = shift;
    Page->report_error("user", "Function - Value - Request Method", "$function - $value - GET");
}

sub do_post {
    my $q = new CGI;
    my $function = $q->param("function");
    my $value    = $q->param("value");
    my $auth     = decode_base64($q->param("auth"));

    my $hstr = "";
    my %headers = map { $_ => $q->http($_) } $q->http();
    for my $header ( keys %headers ) {
        $hstr .= "$header: $headers{$header} \n";
    }
#    Page->report_error("user", "Function - Value - Request Method", "$function - $value - POST - <br>auth-type=$auth_type <br>header=$hstr<br><br>");
    Page->report_error("user", "Function - Value - Request Method", "$function - $value - POST - $auth");
}

sub do_put {
    my $q = new CGI;
    my $function = $q->param("function");
    my $value = $q->param("value");
    Page->report_error("user", "Function - Value - Request Method", "$function - $value - PUT");
}

sub add_microblog {
    my $q = new CGI;

    my $err_msg;
    undef $err_msg;

#    User::user_allowed_to_function();

    my $user_submitted_microblogtext = $q->param("markup");
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

    my $postdate = $q->param("date");
    if ( !defined($postdate) || length($postdate) < 1 ) {
        $err_msg .= "Missing the post date.<br />\n";
    }

    my $createddate = $q->param("createddate");
    if ( !defined($createddate) || length($createddate) < 1 ) {
        $err_msg .= "Missing the created date.<br />\n";
    }

    my $id = $q->param("id");

#    my $logged_in_username = User::get_logged_in_username();
#    my $logged_in_userid   = User::get_logged_in_userid();
    my $logged_in_username = "JR";
    my $logged_in_userid   = 1;

    if ( defined($err_msg) ) {
        $err_msg = "Error: " . $err_msg;
        print "Content-type: text/plain;\n\n";
        print "id=$id unsuccessfully added $err_msg .\n";
        exit;
    } 

    my $markupcontent = $microblogtext;
    my $title = HTML::Entities::encode($markupcontent, '<>');
    my $formattedcontent = HTML::Entities::encode($markupcontent, '<>');
    $formattedcontent = StrNumUtils::url_to_link($formattedcontent);
    $formattedcontent = Format::hashtag_to_link($formattedcontent);
    $formattedcontent = Format::post_id_to_link($formattedcontent);
    $formattedcontent = Format::check_for_external_links($formattedcontent);

    my $postid = _add_microblog($title, $logged_in_userid, $markupcontent, $formattedcontent, $postdate, $createddate);

#    Page->report_error("user", "success.", "post added");

    if ( $postid ) {
        print "Content-type: text/plain;\n\n";
        print "id=$id successfully added.\n";
    } else {
        print "Content-type: text/plain;\n\n";
        print "id=$id unsuccessfully added.\n";
    }
    exit
}

sub _add_microblog {
    my $title            = shift;
    my $userid           = shift;
    my $markupcontent    = shift;
    my $formattedcontent = shift;
    my $postdate         = shift;
    my $createddate      = shift;

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
        print STDERR "user " . "Sorry. " . "Only 7 unique hashtags are permitted.";
        return 0;
    }

    my @loop_data;

    my $epochsecs = time();

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    die "system " . "Error connecting to database. " . $db->errstr if $db->err;

    $title            = $db->quote($title);
    $markupcontent    = $db->quote($markupcontent);
    $formattedcontent = $db->quote($formattedcontent);
    my $quoted_tag_list_str     = $db->quote("|" . $tag_list_str . "|");

    # create article digest
    my $md5 = Digest::MD5->new;
    $md5->add(Utils::otp_encrypt_decrypt($title, $createddate, "enc"), $userid, $createddate);
    my $contentdigest = $md5->b64digest;
    $contentdigest =~ s|[^\w]+||g;

    my $SqlStr;
    $SqlStr    .= "insert into $dbtable_content (title, markupcontent, formattedcontent, type, status, authorid, date, contentdigest, createdby, createddate, tags, ipaddress, importdate)";
    $SqlStr    .= " values ($title, $markupcontent, $formattedcontent, 'm', '$status', $userid, '$postdate', '$contentdigest', $userid, '$createddate', $quoted_tag_list_str, '$ENV{REMOTE_ADDR}', '$datetime')";
    my $articleid = $db->execute($SqlStr);
    die "system " . "(32) Error executing SQL " . $db->errstr if $db->err;

    foreach (@tags) {
        my $tag = $_;
        $tag = $db->quote($tag);
        if ( $tag ) {
            $SqlStr = "insert into $dbtable_tags (name, articleid, type, status, createdby, createddate) "; 
            $SqlStr .= " values ($tag, $articleid, 'm', 'o', $userid, '$datetime') "; 
            $db->execute($SqlStr);
            die "system " . "(32-a) Error executing SQL " . $db->errstr if $db->err;
        }
    }

    $db->disconnect;
    die "system " . "Error disconnecting from database. " . $db->errstr if $db->err;

    return $articleid;
}

sub add_blog {
    my $q = new CGI;
    my $err_msg = "";
   
#    User::user_allowed_to_function();

    my $formattedcontent = "";

    my $markupcontent = $q->param("markup");
# testing my $markupcontent = "h1. this is a test\n\nsome more text";
    if ( !defined($markupcontent) || length($markupcontent) < 1 ) {
        $err_msg .= "You must enter content.<br /><br />";
    }

    my $sb = $q->param("sb");
# testing my $sb = "sb";
    if ( !defined($sb) || length($sb) < 1 ) {
        $err_msg .= "Missing the submit button value.<br /><br />";
    }

    my $postdate = $q->param("date");
    if ( !defined($postdate) || length($postdate) < 1 ) {
        $err_msg .= "Missing the post date.<br />\n";
    }

    my $createddate = $q->param("createddate");
    if ( !defined($createddate) || length($createddate) < 1 ) {
        $err_msg .= "Missing the created date.<br />\n";
    }

    my $logged_in_userid = $q->param("authorid");
    if ( !defined($logged_in_userid)  ||  (length($logged_in_userid) < 1)  ||  !StrNumUtils::is_numeric($logged_in_userid) ) {
        $err_msg .= "Missing or invalid author ID.<br />\n";
    }

    my $logged_in_username = User::get_username_for_id($logged_in_userid);
    if ( length($logged_in_username) < 1 ) {
        $err_msg .= "Missing or invalid username.<br />\n";
    }

    my $id = $q->param("id");

    my $o = BlogTitle->new();
    $o->set_logged_in_username($logged_in_username);
    $o->process_title($markupcontent);
    my $tmp_markupcontent = $o->get_after_title_markup();
    my $title             = $o->get_title();
    my $posttitle         = $o->get_post_title();
    $err_msg             .= $o->get_error_string() if $o->is_error();

    my $tag_list_str = Format::create_tag_list_str($markupcontent);
    # remove beginning and ending pipe delimeter to make a proper delimited string
    $tag_list_str =~ s/^\|//;
    $tag_list_str =~ s/\|$//;
    my @tags = split(/\|/, $tag_list_str);
    my $tmp_tag_len = @tags;
    my $max_unique_hashtags = Config::get_value_for("max_unique_hashtags");
    if ( $tmp_tag_len > $max_unique_hashtags ) {
        $err_msg .= "Sorry. Only 7 unique hashtags are permitted.";
    }

    $err_msg = Format::check_for_special_tag($err_msg, $tag_list_str); 

    if ( $err_msg ) {
        $err_msg = "Error: " . $err_msg;
        print "Content-type: text/plain;\n\n";
        print "id=$id unsuccessfully added $err_msg .\n";
        exit;
    } 

    my $clean_title   = Format::clean_title($posttitle);

    $formattedcontent = Format::format_content($tmp_markupcontent, "add");

#    my $logged_in_userid   = User::get_logged_in_userid();

    my $articleid = _add_blog($posttitle, $logged_in_userid, $markupcontent, $formattedcontent, $tag_list_str, $postdate, $createddate);

    if ( !Utils::get_power_command_on_off_setting_for("private", $markupcontent, 0) ) {
        my @backlinks = Backlinks::get_backlink_ids($formattedcontent);
        Backlinks::add_backlinks($articleid, \@backlinks) if @backlinks;
    }

    if ( $articleid ) {
        print "Content-type: text/plain;\n\n";
#        print "id=$id successfully added.\n";
        print "$articleid";
    } else {
        print "Content-type: text/plain;\n\n";
        print "id=$id unsuccessfully added.\n";
    }
    exit
}

sub _add_blog {
    my $title             = shift;
    my $userid            = shift;
    my $markupcontent     = shift;
    my $formattedcontent  = shift;
    my $tag_list_str  = shift;
    my $postdate         = shift;
    my $createddate      = shift;

    my $parentid = 0;
    my $parentauthorid = 0;

    my $new_status = 'o'; # default 
    if ( Utils::get_power_command_on_off_setting_for("draft", $markupcontent, 0) ) {
        $new_status = 'p'; # don't display in streams but do display in searches 
    }

    if ( Utils::get_power_command_on_off_setting_for("private", $markupcontent, 0) ) {
        $new_status = 's'; # secret or private post
    }

    my $code_post = 0;
    if ( Utils::get_power_command_on_off_setting_for("code", $markupcontent, 0) ) {
        $code_post = 1;
        my $tmp_markupcontent = $markupcontent;
        $tmp_markupcontent =~ s/$title//;
        $tmp_markupcontent = Format::remove_power_commands($tmp_markupcontent);
        $tmp_markupcontent = StrNumUtils::trim_spaces($tmp_markupcontent);
        $formattedcontent = HTML::Entities::encode($tmp_markupcontent, '<>');
        # $formattedcontent = "<pre>\n<code>\n" . $formattedcontent . "\n</code>\n</pre>\n";
        $formattedcontent = "<textarea class=\"codetext\" id=\"enhtextareaboxarticle\" rows=\"15\" cols=\"60\" wrap=\"off\" readonly>" . $formattedcontent  . "</textarea>\n";
    }

    my $datetime = Utils::create_datetime_stamp();

    my $type = 'b';

    $tag_list_str = "" if $code_post;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    die "system " . "Error connecting to database. " . $db->errstr if $db->err;

    $title            = $db->quote($title);
    $markupcontent    = $db->quote($markupcontent);
    $formattedcontent = $db->quote($formattedcontent);
    my $quoted_tag_list_str     = $db->quote("|" . $tag_list_str . "|");

    # create article digest
    my $contentdigest = DigestMD5::create(Utils::otp_encrypt_decrypt($title, $datetime, "enc"), $userid, $datetime);
    $contentdigest =~ s|[^\w]+||g;

    my $sql;

# don't update import date right now. 6sep2013
#    $sql .= "insert into $dbtable_content (parentid, parentauthorid, title, markupcontent, formattedcontent, type, status, authorid, date, contentdigest, createdby, createddate, tags, ipaddress, importdate)";
#    $sql .= " values ($parentid, $parentauthorid, $title, $markupcontent, $formattedcontent, '$type', '$new_status', $userid, '$postdate', '$contentdigest', $userid, '$createddate', $quoted_tag_list_str, '$ENV{REMOTE_ADDR}', '$datetime')";

    $sql .= "insert into $dbtable_content (parentid, parentauthorid, title, markupcontent, formattedcontent, type, status, authorid, date, contentdigest, createdby, createddate, tags, ipaddress)";
    $sql .= " values ($parentid, $parentauthorid, $title, $markupcontent, $formattedcontent, '$type', '$new_status', $userid, '$postdate', '$contentdigest', $userid, '$createddate', $quoted_tag_list_str, '$ENV{REMOTE_ADDR}')";

    my $articleid = $db->execute($sql);
    "system " . "(30) Error executing SQL " . $db->errstr if $db->err;
 
    # remove beginning and ending pipe delimeter to make a proper delimited string
    $tag_list_str =~ s/^\|//;
    $tag_list_str =~ s/\|$//;
    my @tags = split(/\|/, $tag_list_str);
    foreach (@tags) {
        my $tag = $_;
        $tag = $db->quote($tag);
        if ( $tag ) {
            $sql = "insert into $dbtable_tags (name, articleid, type, status, createdby, createddate) "; 
            $sql .= " values ($tag, $articleid, 'b', 'o', $userid, '$datetime') "; 
            $db->execute($sql);
            Page->report_error("system", "(32-a) Error executing SQL", $db->errstr) if $db->err;
            die "system " . "(32) Error executing SQL " . $db->errstr if $db->err;
        }
    }

    $db->disconnect;
    die "system " . "Error disconnecting from database. " . $db->errstr if $db->err;

    return $articleid;
}


1;

