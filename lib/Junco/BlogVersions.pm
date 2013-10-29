package BlogVersions;

use strict;
use warnings;

use Junco::BlogDisplay;
use Junco::BlogData;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");
my $dbtable_users      = Config::get_value_for("dbtable_users");

sub show_version_list {
    my $tmp_hash = shift;  

    my $articleid = $tmp_hash->{one}; 
# $articleid=7;

    if ( !$articleid or !StrNumUtils::is_numeric($articleid) ) {
        Page->report_error("user", "Invalid version access.", "Missing blog post id");
    } 

    my %article_data = BlogDisplay::_get_blog_post($articleid);
    if ( !%article_data ) {
        Page->report_error("user", "Invalid version access. (1)", "Data doesn't exist");
    }

    if ( BlogData::is_top_level_post_private($articleid) and !BlogData::user_owns_blog_post($articleid, $article_data{authorid}) ) {
        Page->report_error("user", "Invalid version access. (2)", "Data doesn't exist");
    }

    my @loop_data = _get_versions($articleid);
#    if ( !@loop_data ) {
#        Page->report_error("user", "Invalid version access. (3)", "Data doesn't exist");
#    }

    my $len = @loop_data;
    my $t = Page->new("versions");

    $t->set_template_variable("title",               $article_data{title});    
    $t->set_template_variable("titleurl",            $article_data{cleantitle}); 
    $t->set_template_variable("currentarticleid",    $article_data{articleid});   
    $t->set_template_variable("currentversion",      $len+1);
    $t->set_template_variable("currentauthor",       $article_data{authorname});
    $t->set_template_variable("currentcreationdate", $article_data{modifieddate});   
    $t->set_template_variable("currentcreationtime", $article_data{modifiedtime});   
    $t->set_template_variable("currenteditreason",   $article_data{editreason});   

    $t->set_template_loop_data("versions_loop", \@loop_data);
    $t->display_page("Versions for: $article_data{title}");
}

sub _get_versions {
    my $articleid = shift;

    my $cgi_app = Config::get_value_for("cgi_app");

    my $offset = Utils::get_time_offset();

    my @loop_data; 

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql = "select c.id,  ";
    $sql .=      "date_format(date_add(c.date, interval $offset hour), '%b %d, %Y') as date, ";
    $sql .=      "date_format(date_add(c.date, interval $offset hour), '%r') as time, ";
    $sql .=      "c.version, u.username, c.editreason from $dbtable_content c, $dbtable_users u ";
    $sql .=      "where c.parentid=$articleid and c.type in ('b') and c.status='v' and c.authorid=u.id ";
    $sql .=      "order by c.version desc";

    $db->execute($sql);
    Page->report_error("system", "(61) Error executing SQL", $db->errstr) if $db->err;

    my $cnt = 0;
    while ( $db->fetchrow ) {
        $cnt++;
        my %hash = ();
        $hash{articleid}       = $db->getcol("id");
        $hash{creationdate}    = $db->getcol("date");
        $hash{creationtime}    = lc($db->getcol("time"));
        $hash{version}         = $db->getcol("version");
        $hash{author}          = $db->getcol("username");
        $hash{editreason}      = $db->getcol("editreason");
        $hash{checked}         = "checked" if $cnt == 1;
        $hash{cgi_app}         = $cgi_app;
        push(@loop_data, \%hash);
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect();
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return @loop_data;
}

1;

