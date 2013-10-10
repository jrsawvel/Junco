package BlogUpdate;

use strict;
use warnings;

use Encode qw(decode encode);
use JSON::PP;
use HTML::Entities;
use URI::Escape::JavaScript;
use Junco::BlogPreview;
use Junco::BlogData;
use Junco::Format;
use Junco::Backlinks;
use Junco::BlogTitle;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");
my $dbtable_tags       = Config::get_value_for("dbtable_tags");

sub update_blog_post {
    my $q = new CGI;
    my $err_msg = "";

    my $formattedcontent = "";

    User::user_allowed_to_function();

    my $articleid = $q->param("articleid");
# $articleid = 84;
    if ( !defined($articleid) || length($articleid) < 1 ) {
        $err_msg .= "Content id missing.<br /><br />";
    }

    my $contentdigest = $q->param("contentdigest");
# $contentdigest = "TAcholPV9RhS3nw8l0vzfQ";
    if ( !defined($contentdigest) || length($contentdigest) < 1 ) {
        $err_msg .= "Missing content digest.<br /><br />";
    }

    my $markupcontent = $q->param("markupcontent");
# $markupcontent = "test title 20aug2013 code equals\n\ncode=yes\n\nhey\n";
    if ( !defined($markupcontent) || length($markupcontent) < 1 ) {
        $err_msg .= "You must enter content.<br /><br />";
    }

    my $editreason = $q->param("editreason");
#$editreason = "test update 22jul2013";
    $editreason    = encode_entities($editreason, '<>');

    my $sb = $q->param("sb");
# $sb = "Preview";
# $sb = "Update";

    if ( !defined($sb) || length($sb) < 1 ) {
        $err_msg .= "Missing the submit button value.<br /><br />";
    }

    my $formtype = $q->param("formtype");
    if ( $formtype eq "ajax" ) {
        $markupcontent = URI::Escape::JavaScript::unescape($markupcontent);
        $markupcontent = HTML::Entities::encode($markupcontent,'^\n\x20-\x25\x27-\x7e');
    } else {
        $markupcontent = Encode::decode_utf8($markupcontent);
        $markupcontent = HTML::Entities::encode($markupcontent,'^\n^\r\x20-\x25\x27-\x7e');
    }

    my $o = BlogTitle->new();
    $o->set_article_id($articleid);
    $o->set_logged_in_username(User::get_logged_in_username());
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
        $markupcontent = encode_entities($markupcontent, '<>&');
        BlogPreview::preview_blog_edit($title, $markupcontent, $posttitle, $formattedcontent, $articleid, $contentdigest, $editreason, $err_msg, $formtype);
    } 

    my $clean_title   = Format::clean_title($posttitle);

    $formattedcontent = Format::format_content($tmp_markupcontent, $sb);

    if ( $sb eq "Preview" ) {
        $formattedcontent = BlogData::include_templates($formattedcontent);
# 9oct2013        $markupcontent = encode_entities($markupcontent, '<>&');
        BlogPreview::preview_blog_edit($title, $markupcontent, $posttitle, $formattedcontent, $articleid, $contentdigest, $editreason, $err_msg, $formtype);
    } 
    elsif ( $sb ne "Update" ) {
        Page->report_error("user", "Unable to update article.", "Invalid action: $sb");
    }

    my $logged_in_userid   = User::get_logged_in_userid();
    my $aid = _update_blog_post($posttitle, $logged_in_userid, $markupcontent, $formattedcontent, $articleid, $contentdigest, $editreason, $tag_list_str);
 
    if ( !Utils::get_power_command_on_off_setting_for("private", $markupcontent, 0) ) {
        my @backlinks = Backlinks::get_backlink_ids($formattedcontent);
        Backlinks::add_backlinks($aid, \@backlinks) if @backlinks;
    }
    
    if ( $formtype eq "ajax" ) {
        # print "Content-type: text/html\n\n";
        # print "<h1>$posttitle</h1>" . "\n";
        # print $formattedcontent . "\n";
        print "Content-type: text/html\n\n";
            my %hash;
            $hash{'content'} = "<h1>$posttitle</h1>$formattedcontent";
            $hash{'articleid'} = $articleid;
            $hash{'contentdigest'} = _get_content_digest_for($articleid);
            $hash{'errorcode'} = 0;
            $hash{'errorstring'} = "undef"; 
            my $json_str = encode_json \%hash;
            print $json_str;
        exit;
    }

    my $url = Config::get_value_for("cgi_app") . "/blogpost/$aid/$clean_title";
    print $q->redirect( -url => $url);
}

sub _update_blog_post {
    my $title         = shift;
    my $userid        = shift;
    my $markupcontent     = shift;
    my $formattedcontent     = shift;
    my $articleid       = shift;
    my $contentdigest = shift;
    my $editreason = shift;
    my $tag_list_str  = shift;

   #status = o p v d s

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
#         $formattedcontent = "<pre>\n<code>\n" . $formattedcontent . "\n</code>\n</pre>\n";
        $formattedcontent = "<textarea class=\"codetext\" id=\"enhtextareaboxarticle\" rows=\"15\" cols=\"60\" wrap=\"off\" readonly>" . $formattedcontent  . "</textarea>\n";
    }           

    if ( !_is_updating_correct_article($articleid, $contentdigest) ) { 
        Page->report_error("user", "Error updating article.", "Access denied.");
    }

    if ( !BlogData::user_owns_blog_post($articleid, $userid) ) {
         Page->report_error("user", "Invalid access.", "Unable to edit article.");
    }

    my $aid = $articleid;
    my $parentid = _is_updating_an_older_version($articleid);
    $aid = $parentid if ( $parentid > 0 );

    my $datetime = Utils::create_datetime_stamp();

    # 5jun2013 $tag_list_str = Utils::create_tag_list_str($markupcontent) if !$code_post;
    $tag_list_str = "" if $code_post;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $title            = $db->quote($title);
    $markupcontent    = $db->quote($markupcontent);
    $formattedcontent = $db->quote($formattedcontent);
    $editreason       = $db->quote($editreason);
    my $quoted_tag_list_str     = $db->quote("|" . $tag_list_str . "|");

    my $sql;

    # make copy of most recent version.
    my %old;
    $sql =  "select id, title, markupcontent, formattedcontent, ";
    $sql .= "type, status, authorid, date, version, ";
    $sql .= "contentdigest, createdby, createddate, editreason, "; 
    $sql .= "tags, ipaddress ";
    $sql .= "from $dbtable_content where id=$aid";
    $db->execute($sql);
    Page->report_error("system", "(27) Error executing SQL", $db->errstr) if $db->err;
    
    if ( $db->fetchrow ) {
        $old{parentid}         = $db->getcol("id");
        $old{title}            = $db->quote($db->getcol("title"));
        $old{markupcontent}    = $db->quote($db->getcol("markupcontent"));
        $old{formattedcontent} = $db->quote($db->getcol("formattedcontent"));
        $old{type}             = $db->getcol("type");
        $old{status}           = $db->getcol("status");
        $old{authorid}         = $db->getcol("authorid");
        $old{date}             = $db->getcol("date");
        $old{version}          = $db->getcol("version");
        $old{contentdigest}    = $db->getcol("contentdigest");
        $old{createdby}        = $db->getcol("createdby");
        $old{createddate}      = $db->getcol("createddate");
        $old{editreason}       = $db->quote($db->getcol("editreason"));
        $old{tags}             = $db->quote($db->getcol("tags"));
        $old{ipaddress}        = $db->getcol("ipaddress");
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    my $status = 'v';  # previous version 
    $sql =  "insert into $dbtable_content (parentid, title, markupcontent, formattedcontent, type, status, authorid, date, version, contentdigest, createdby, createddate, editreason, tags, ipaddress)";
    $sql .= " values ($old{parentid}, $old{title}, $old{markupcontent}, $old{formattedcontent}, '$old{type}', '$status', $old{authorid}, '$old{date}', $old{version}, '$old{contentdigest}', $old{createdby}, '$old{createddate}', $old{editreason}, $old{tags},  '$old{ipaddress}')";

    $db->execute($sql);
    Page->report_error("system", "(28) Error executing SQL", $db->errstr) if $db->err;

    #####  todo create new content digest when article updated??? for now, no.

    # add new modified content
    my $version = $old{version} + 1;
    $sql = "update $dbtable_content ";
    $sql .= " set title=$title, markupcontent=$markupcontent, formattedcontent=$formattedcontent, authorid=$userid, date='$datetime', status='$new_status', version=$version, editreason=$editreason, tags=$quoted_tag_list_str, ipaddress='$ENV{REMOTE_ADDR}' ";
    $sql .= " where id=$aid";
    $db->execute($sql);
    Page->report_error("system", "(29) Error executing SQL", $db->errstr) if $db->err;

    # removed existing tags from table
    $sql = "delete from $dbtable_tags where articleid=$articleid";
    $db->execute($sql);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;
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
        }
    }

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $aid;
}

sub _is_updating_an_older_version {
    my $articleid = shift;

    my $parentid = 0;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    # if updating an older version, the parentid should be >0 and status should = v 
    my $sql = "select parentid from $dbtable_content where id=$articleid and type in ('b') and status='v'";
    $db->execute($sql);
    Page->report_error("system", "(62) Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $parentid  = $db->getcol("parentid");
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $parentid;
}

sub _is_updating_correct_article {
    my ($articleid, $contentdigest) = @_;

    my $return_value = 0;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $contentdigest = $db->quote($contentdigest);

    my $get_blog_post_edit_status = Config::get_value_for("get_blog_post_edit_status");

    my $sql = "select title from $dbtable_content ";
    $sql .=   "where id=$articleid and type in ('b') and status in ($get_blog_post_edit_status) and contentdigest=$contentdigest"; 
    $db->execute($sql);

    if ( $db->fetchrow ) {
        $return_value = 1;
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $return_value;
}

sub _get_content_digest_for {
    my $articleid = shift;

    my $content_digest;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    return "undef" if $db->err;

    my $sql = "select contentdigest from $dbtable_content where id=$articleid";
    $db->execute($sql);
    return "undef" if $db->err;

    if ( $db->fetchrow ) {
        $content_digest = $db->getcol("contentdigest");
    }
    return "undef" if $db->err;

    $db->disconnect;
    return "undef" if $db->err;

    return $content_digest;
}

1;

