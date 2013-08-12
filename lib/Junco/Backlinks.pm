package Backlinks;

use strict;
use warnings;

use Junco::Format;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_backlinks  = Config::get_value_for("dbtable_backlinks");
my $dbtable_content    = Config::get_value_for("dbtable_content");

sub get_backlink_ids {
    my $str = shift;

    # will be searching for /<cgi-app>/blogpost/<id>
    # don't include duplicate post ids in the returned array

    my $linkurl = Config::get_value_for("cgi_app") . "/blogpost/";
    my @link_ids;
    my @backlinks;
    my $tmp_str;
    my $i=0;

    if ( @link_ids = $str =~ m|$linkurl([0-9]+)|gsi ) { 
        foreach (@link_ids) {
            my $tmp_id = $_;
            if ( $tmp_str !~ m|$tmp_id| ) {
                $backlinks[$i] = $tmp_id;
                $tmp_str = $tmp_str . " $tmp_id ";
                $i++;
            }
        }
    }            

    return @backlinks;
}

sub add_backlinks {
    my $articleid = shift;
    my $backlinks = shift;

    my $sql;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

        # removed existing backlinks from table if they exist
    $sql = "delete from $dbtable_backlinks where linkingfromarticleid=$articleid";
    $db->execute($sql);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    foreach (@$backlinks) {
        my $bl = $_;
        if ( $bl ) {
            $sql = "insert into $dbtable_backlinks (linkingfromarticleid, linkingtoarticleid) "; 
            $sql .= " values ($articleid, $bl) "; 
            $db->execute($sql);
            Page->report_error("system", "(82-a) Error executing SQL", $db->errstr) if $db->err;
        }
    }

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;
}


sub backlinks_exist {
    my $articleid =  shift;

    my $sql;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $sql = "select id from $dbtable_backlinks where linkingtoarticleid = $articleid and status='o' limit 1";
    $db->execute($sql);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        return 1;
    }

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return 0;
}

sub show_backlinks {
    my $tmp_hash = shift;  

    my $articleid = $tmp_hash->{one}; 

    my $title = _get_article_title($articleid);

    my $t = Page->new("backlinks");
    $t->set_template_variable("title", $title);
    $t->set_template_variable("articleid", $articleid);
    $t->set_template_variable("cleantitle", Format::clean_title($title));

    my @backlinks = ();
    @backlinks = _get_backlinks($articleid);
    if ( @backlinks ) {
        $t->set_template_variable("havebacklinks", "1"); 
        $t->set_template_loop_data("backlinks_loop",  \@backlinks);
    }

    $t->display_page("Backlinks for $title");
}

sub _get_backlinks {
    my $articleid = shift;
   
    my $cgi_app = Config::get_value_for("cgi_app");

    my @loop_data = ();
 
    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql = "select c.id, c.title from $dbtable_content c, $dbtable_backlinks b where b.linkingtoarticleid = $articleid and b.linkingfromarticleid=c.id and b.status='o'";
    $db->execute($sql);
    Page->report_error("system", "(54) Error executing SQL : $sql", $db->errstr) if $db->err;

    while ( $db->fetchrow ) {
        my %hash = ();
        $hash{articleid}  = $db->getcol("id");
        $hash{title}      = $db->getcol("title");
        $hash{urltitle}    = Format::clean_title($hash{title});
        $hash{cgi_app}    = $cgi_app;
        push(@loop_data, \%hash);
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return @loop_data;
}

sub _get_article_title {
    my $articleid = shift;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql = "select title from $dbtable_content where id = $articleid";
    $db->execute($sql);
    Page->report_error("system", "(65) Error executing SQL", $db->errstr) if $db->err;

    my $title = "";

    if ( $db->fetchrow ) {
        $title = $db->getcol("title");
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    if ( !$title or length($title) < 1 ) {
        Page->report_error("user", "Error retreiving article title.", "Article for the ID number provided doesn't exist.");
    }

    return $title;
}

1;


