package BlogData;

use strict;
use warnings;

use Junco::RSS;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");
my $dbtable_users      = Config::get_value_for("dbtable_users");

sub title_exists {
    my $new_article_title = shift;
    my $articleid = shift; # provided for updating a blog post

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $new_article_title = $db->quote($new_article_title);

    my $sql;

    if ( $articleid ) { 
        $sql = "select id from $dbtable_content where title=$new_article_title and id != $articleid and type='b' and status != 'v'";
    } else {
        $sql = "select id from $dbtable_content where title=$new_article_title"; 
    }

    $db->execute($sql);
    Page->report_error("system", "(63) Error executing SQL", $db->errstr) if $db->err;

    my $title_already_exists = 0;

    if ( $db->fetchrow ) {
        $title_already_exists = 1; 
    } else {
        $sql = "select id from $dbtable_users where username=$new_article_title";
        $db->execute($sql);
        Page->report_error("system", "(63) Error executing SQL", $db->errstr) if $db->err;
        if ( $db->fetchrow ) {
            $title_already_exists = 1; 
        }
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $title_already_exists;
}

sub include_templates {
    my $str = shift;

    while ( $str =~ m/{{(.*?)}}/ ) {
        my $title = $1;
        my $include = "";
        if ( $title =~ m|^feed=h(.*?)://(.*?)$|i ) {
            my $rssurl = "h" . $1 . "://" .  $2;
            $include = RSS::get_rss_feed($rssurl);
        } 
        else {
            $include = _get_formatted_content_for_template($title);
            if ( !$include ) {
                $include = "**Include template \"$title\" not found.**";
            }
        }
        my $old_str = "{{$title}}";
        $str =~ s/\Q$old_str/$include/;
    }

    return $str;
}

sub _get_formatted_content_for_template {
    my $orig_str = shift;

    $orig_str = StrNumUtils::trim_spaces($orig_str);

    my $str;

    if ( $orig_str !~ m /^Template:/i ) {
        $str = "Template:" . $orig_str;
    } else {
        $str = $orig_str;
    }    

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $title            = $db->quote($str);

    my $sql = "select formattedcontent from $dbtable_content where title = $title and status in ('o') and type in ('b')";
    $db->execute($sql);
    Page->report_error("system", "(72) Error executing SQL", $db->errstr) if $db->err;

    my $formattedcontent = "";

    if ( $db->fetchrow ) {
        $formattedcontent = $db->getcol("formattedcontent");
    } else {
        $title            = $db->quote($orig_str);
        $sql = "select formattedcontent from $dbtable_content where title = $title and status in ('o') and type in ('b')";
        $db->execute($sql);
        Page->report_error("system", "(72) Error executing SQL", $db->errstr) if $db->err;
        if ( $db->fetchrow ) {
            $formattedcontent = $db->getcol("formattedcontent");
        }
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    if ( $formattedcontent =~ m/<tmpl>(.*?)<\/tmpl>/is ) {
        $formattedcontent = StrNumUtils::trim_br($1);
        $formattedcontent = StrNumUtils::trim_spaces($formattedcontent);
    }  

    return $formattedcontent;
}

sub _get_blog_post_id {
    my $title = shift;

    my $blog_post_id = 0;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $title = $db->quote($title);

    my $sql = "select id from $dbtable_content where title=$title and type='b' and status='o' limit 1";

    $db->execute($sql);
    Page->report_error("system", "(77) Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $blog_post_id = $db->getcol("id");
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $blog_post_id;
}

sub user_owns_blog_post {
    my $articleid = shift;
    my $authorid  = shift;

    return 0 if !StrNumUtils::is_numeric($articleid);

    return 0 if !StrNumUtils::is_numeric($authorid);

    return 0 if $articleid < 1 or $authorid < 1;

        # get value from user's browser cookie
    my $logged_in_userid       = User::get_logged_in_userid();

        # the logged in user must equal the blog post author
    return 0 if $logged_in_userid ne $authorid;

        # User::valid_user compares logged in user's cookie info with what's stored in the database for the userid.
        # the username, userid, and digest from the browser cookies and database are compared in User::valid_user and they must equal.
    return 0 if !User::valid_user();

        # the logged in user's browser cookies equals info stored in user database table and 
        # the logged in user equals the author of the blog post
    return 1;
}

sub get_blog_post_count {
    my $status = shift;

    User::user_allowed_to_function();

    my $logged_in_userid = User::get_logged_in_userid();

    my $blog_count =0;

    return $blog_count if !$logged_in_userid; 

    return $blog_count if $status ne "s" and $status ne "p";

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql;

    $sql = "select count(*) as blogcount from $dbtable_content where type='b' and status='$status' and authorid=$logged_in_userid"; 

    $db->execute($sql);
    Page->report_error("system", "Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $blog_count = $db->getcol("blogcount");
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect();
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $blog_count;
}

sub is_top_level_post_private {
    my $articleid = shift;

    my $return_status = 1;  # default to private
 
    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql = "select markupcontent from $dbtable_content where id=$articleid"; 

    $db->execute($sql);
    Page->report_error("system", "(31-a) Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        my $tmp_markup         = $db->getcol("markupcontent");
        if ( !Utils::get_power_command_on_off_setting_for("private", $tmp_markup, 0) ) {
            $return_status = 0;
        }
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect();
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $return_status;
}



1;

