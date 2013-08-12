package BlogAdd;

use strict;
use warnings;

use HTML::Entities;
use URI::Escape::JavaScript;
use Junco::BlogData;
use Junco::BlogPreview;
use Junco::Format;
use Junco::Backlinks;
use Junco::BlogTitle;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");
my $dbtable_tags       = Config::get_value_for("dbtable_tags");

sub show_blog_post_form {
    User::user_allowed_to_function();
    my $t = Page->new("blogpostform");
    $t->display_page("Blog Post Form");
}

sub show_splitscreen_form {
    User::user_allowed_to_function();
    my $t = Page->new("splitscreenform");
    $t->display_page_min("Blog Post Form - Split Screen");
}

sub show_enhanced_blog_post_form {
    User::user_allowed_to_function();
    my $t = Page->new("enhblogpostform");
    $t->display_page("Enhanced Blog Post Form");
}

sub show_textile_editor_form {
    User::user_allowed_to_function();
    my $t = Page->new("textileeditor");
    $t->display_page_min("Textile Editor Blog Post Form");
}

sub add_blog_post {
    my $q = new CGI;
    my $err_msg = "";
   
    User::user_allowed_to_function();

    my $formattedcontent = "";

    my $markupcontent = $q->param("article");

# testing my 
# $markupcontent = "h1. this is a test 6aug2013 x\n\nmarkdown=yes\n\n--small--\n\nyoutube=embed/nfOUn6LgN3c\n";

    if ( !defined($markupcontent) || length($markupcontent) < 1 ) {
        $err_msg .= "You must enter content.<br /><br />";
    }

    my $sb = $q->param("sb");
# testing my 
# $sb = "sb";
    if ( !defined($sb) || length($sb) < 1 ) {
        $err_msg .= "Missing the submit button value.<br /><br />";
    }

    my $formtype = $q->param("formtype");

    if ( $formtype eq "ajax" ) {
        $markupcontent = URI::Escape::JavaScript::unescape($markupcontent);
        $markupcontent = HTML::Entities::encode($markupcontent,'^\n\x20-\x25\x27-\x7e');
    }

    my $o = BlogTitle->new();
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
        $err_msg .= "Sorry. Only $max_unique_hashtags unique hashtags are permitted.";
    }

    $err_msg = Format::check_for_special_tag($err_msg, $tag_list_str); 

    if ( $err_msg ) {
        $formattedcontent = Format::format_content($tmp_markupcontent);
        $formattedcontent = BlogData::include_templates($formattedcontent);
        BlogPreview::preview_new_blog_post($title, $markupcontent, $posttitle, $formattedcontent, $err_msg, $formtype);
# Page->report_error("user", "debug", "$err_msg");
    } 

    my $clean_title   = Format::clean_title($posttitle);

    $formattedcontent = Format::format_content($tmp_markupcontent);

    if ( $sb eq "Preview" ) {
        $formattedcontent = BlogData::include_templates($formattedcontent);
        BlogPreview::preview_new_blog_post($title, $markupcontent, $posttitle, $formattedcontent, $err_msg, $formtype);
# Page->report_error("user", "debug", "$title $formattedcontent");
    }

    my $logged_in_userid   = User::get_logged_in_userid();

    my $articleid = _add_blog($posttitle, $logged_in_userid, $markupcontent, $formattedcontent, $tag_list_str);

    if ( !Utils::get_power_command_on_off_setting_for("private", $markupcontent, 0) ) {
        my @backlinks = Backlinks::get_backlink_ids($formattedcontent);
        Backlinks::add_backlinks($articleid, \@backlinks) if @backlinks;
    }

    if ( $formtype eq "ajax" ) {
        print "Content-type: text/html\n\n";
        print "<h1>$posttitle</h1>" . "\n";
        print $formattedcontent . "\n";
        exit;
    }

    my $url = Config::get_value_for("cgi_app") . "/blogpost/$articleid/$clean_title";
    print $q->redirect( -url => $url);
}

sub _add_blog {
    my $title             = shift;
    my $userid            = shift;
    my $markupcontent     = shift;
    my $formattedcontent  = shift;
    my $tag_list_str  = shift;

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
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $title            = $db->quote($title);
    $markupcontent    = $db->quote($markupcontent);
    $formattedcontent = $db->quote($formattedcontent);
    my $quoted_tag_list_str     = $db->quote("|" . $tag_list_str . "|");

    # create article digest
    my $contentdigest = DigestMD5::create(Utils::otp_encrypt_decrypt($title, $datetime, "enc"), $userid, $datetime);
    $contentdigest =~ s|[^\w]+||g;

    my $sql;

    $sql .= "insert into $dbtable_content (parentid, parentauthorid, title, markupcontent, formattedcontent, type, status, authorid, date, contentdigest, createdby, createddate, tags, ipaddress)";
    $sql .= " values ($parentid, $parentauthorid, $title, $markupcontent, $formattedcontent, '$type', '$new_status', $userid, '$datetime', '$contentdigest', $userid, '$datetime', $quoted_tag_list_str, '$ENV{REMOTE_ADDR}')";

    my $articleid = $db->execute($sql);
    Page->report_error("system", "(30) Error executing SQL", $db->errstr) if $db->err;
 
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

    return $articleid;
}

1;

