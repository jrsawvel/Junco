package BlogSource;

use strict;
use warnings;

use Junco::Format;
use Junco::BlogData;
use HTML::Entities;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");

sub show_blog_source {
    my $tmp_hash = shift;  

    my $articleid = $tmp_hash->{one}; 

# testing
# $articleid = 7;

    if ( !defined($articleid)  or !$articleid or $articleid !~ /^[0-9]+$/ ) {
        Page->report_error("user", "Invalid input", "Missing or invalid article id: $articleid.");
    }

    my %article_data = _get_blog_source($articleid);

    if ( !%article_data ) {
        Page->report_error("user", "Invalid article access.", "Data doesn't exist.") 
    }

    my $markupcontent = $article_data{markupcontent};
#    $markupcontent = encode_entities($markupcontent, '<>&');
#    $markupcontent = StrNumUtils::newline_to_br($markupcontent);

    my $t = Page->new("blogsource");
#    $t->set_template_variable("id",            $articleid);
#    $t->set_template_variable("title",         $article_data{title});
#    $t->set_template_variable("cleantitle",    Format::clean_title($article_data{title}));
    $t->set_template_variable("markupcontent", $markupcontent);
#    $t->display_page("Blog post source for: $article_data{title}");
    $t->print_template("Content-type: text/plain");
}

sub _get_blog_source {
    my $article_id = shift;

    my %article_data = ();

    my $authorid = 0;
    my $parentid = 0;
    my $status;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $get_blog_source_status = Config::get_value_for("get_blog_source_status");

    my $sql = "select parentid, title, authorid, markupcontent, status from $dbtable_content where id = $article_id and status in ($get_blog_source_status)";

    $db->execute($sql);
    Page->report_error("system", "(77) Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $parentid                    = $db->getcol("parentid");
        $article_data{title}         = $db->getcol("title");
        $authorid                    = $db->getcol("authorid");
        $article_data{markupcontent} = $db->getcol("markupcontent");
        $status                      = $db->getcol("status");
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    if ( $status eq "v" and !BlogData::user_owns_blog_post($parentid, $authorid) ) {
        if ( Utils::get_power_command_on_off_setting_for("private", $article_data{markupcontent}, 0) ) {
            %article_data = ();
        } elsif ( BlogData::is_top_level_post_private($parentid) ) {
            %article_data = ();
        }
    }

    return %article_data;
}

1;

