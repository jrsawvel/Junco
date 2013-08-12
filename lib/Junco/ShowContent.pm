package ShowContent;

use strict;
use warnings;

use Junco::Microblog;
use Junco::BlogDisplay;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");
my $dbtable_content    = Config::get_value_for("dbtable_content");

sub show_content {
    my $tmp_hash = shift;  
    my $articleid = $tmp_hash->{one}; 
    if ( !defined($articleid)  or !$articleid or !StrNumUtils::is_numeric($articleid) ) {
        Page->report_error("user", "Invalid input", "Missing or invalid article id: $articleid.");
    }
    my $type = _get_post_type($articleid);

    if ( $type eq "m" ) {
        Microblog::show_microblog_post($tmp_hash);
    } elsif ( $type eq "b" ) {
        BlogDisplay::show_blog_post($tmp_hash);
    } else {
        Page->report_error("user", "Invalid input", "Missing or invalid article id: $articleid.");
    }
}

sub _get_post_type {
    my $articleid = shift;

    my $post_type = "x";

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql = "select type from $dbtable_content where id=$articleid"; 

    $db->execute($sql);
    Page->report_error("system", "(77) Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $post_type = $db->getcol("type");
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $post_type;
}

1;

