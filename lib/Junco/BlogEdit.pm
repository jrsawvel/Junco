package BlogEdit;

use strict;
use warnings;

use HTML::Entities;
use Junco::BlogData;
use Junco::BlogPreview;
use Junco::Format;
use Junco::Backlinks;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");
my $dbtable_tags       = Config::get_value_for("dbtable_tags");

sub enhanced_edit_blog_post {
    my $tmp_hash = shift;
    
    $tmp_hash->{formtype} = "enhanced";
    edit_blog_post($tmp_hash);
}

sub splitscreen_edit {
    my $tmp_hash = shift;  

    my $articleid = $tmp_hash->{one};

    if ( !$articleid or !StrNumUtils::is_numeric($articleid) ) {
        Page->report_error("user", "Cannot access article.", "Missing article or post ID.");
    }

    User::user_allowed_to_function();

    my $userid     = User::get_logged_in_userid();
    my $sessionid  = User::get_logged_in_sessionid();

    my %article_data = _get_blog_post_for_edit($userid, $articleid, $sessionid);

    my $t;
    my $t = Page->new("splitscreenform");
    $t->set_template_variable("action", "updateblog");
    $t->set_template_variable("articleid", $article_data{articleid});

# 21aug2013    $article_data{markup} = encode_entities($article_data{markup}, '<>&');

    $t->set_template_variable("editarticle", $article_data{markup});
    $t->set_template_variable("contentdigest", $article_data{contentdigest});
    $t->display_page_min("Edit Blog Post - Split Screen " . $article_data{title});
}

sub edit_blog_post {
    my $tmp_hash = shift;  

    my $articleid = $tmp_hash->{one};

# testing
# $articleid = 10;

    if ( !$articleid or !StrNumUtils::is_numeric($articleid) ) {
        Page->report_error("user", "Cannot access article.", "Missing article or post ID.");
    }

    my $enhanced = 0;
    $enhanced = 1 if $tmp_hash->{formtype} eq "enhanced";

    User::user_allowed_to_function();

    my $userid     = User::get_logged_in_userid();
    my $sessionid  = User::get_logged_in_sessionid();

    my %article_data = _get_blog_post_for_edit($userid, $articleid, $sessionid);

    my $t;

    if ( $enhanced ) {
        $t = Page->new("enheditblogpostform");
    } else { 
        $t = Page->new("editblogpostform");
    }

    $t->set_template_variable("articleid", $article_data{articleid});

    $t->set_template_variable("title", encode_entities($article_data{title}));

    $t->set_template_variable("article", $article_data{formatted}) if $enhanced;

    $article_data{markup} = encode_entities($article_data{markup}, '<>&');

    $t->set_template_variable("editarticle", $article_data{markup});

    $t->set_template_variable("contentdigest", $article_data{contentdigest});

    if ( $article_data{status} eq "v" ) {  
        $t->set_template_variable("viewingoldversion", 1);
        $t->set_template_variable("versionnumber", $article_data{versionnumber});
        $t->set_template_variable("parentid", $article_data{parentid});
        $t->set_template_variable("cleantitle", Format::clean_title($article_data{title}));
        $article_data{title} .= " (older version) ";
    }

    $t->display_page("Edit Content - " . $article_data{title});
}

sub _get_blog_post_for_edit {
    my $userid  = shift;      # the logged in user wanting to edit the article
    my $articleid = shift;
    my $sessionid= shift;   # the logged in user wanting to edit the article
    
    my %hash;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Web::report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $get_blog_post_edit_status = Config::get_value_for("get_blog_post_edit_status");

    my $sql = "select c.id, c.parentid, c.title, c.markupcontent, c.formattedcontent, c.status, c.authorid, c.version, c.contentdigest from $dbtable_content c where c.id=$articleid and c.type in ('b') and c.status in ($get_blog_post_edit_status)";

    $db->execute($sql);
    Page->report_error("system", "(42) Error executing SQL", $db->errstr . " " . $db->err) if $db->err;

    my $ownerid = 0;

    if ( $db->fetchrow ) {
        $hash{articleid}      = $db->getcol("id");
        $hash{parentid}       = $db->getcol("parentid");
        $hash{title}          = $db->getcol("title");
        $hash{markup}         = $db->getcol("markupcontent");
        $hash{formatted}      = $db->getcol("formattedcontent");
        $hash{status}         = $db->getcol("status");
        $hash{versionnumber}  = $db->getcol("version");
        $hash{contentdigest}  = $db->getcol("contentdigest");
        $ownerid              = $db->getcol("authorid");
    }
    else {
        Page->report_error("user", "Error retrieving article.", "Article doesn't exist");
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect();
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

   if ( !BlogData::user_owns_blog_post($articleid, $ownerid) ) {
        Page->report_error("user", "Invalid access.", "Unable to edit article.");
   }

    # if ( $ownerid != $userid ) {
    #    # logged in user did not create article and cannot edit 
    #    Web::report_error("user", "Invalid access.", "Unable to edit article.");
    # }

    return %hash;
}

