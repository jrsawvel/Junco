package BlogLastViewed;

use strict;
use warnings;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_users      = Config::get_value_for("dbtable_users");

sub display_last_viewed_blog_post {
    my $q = new CGI;
    my $cookie_prefix = Config::get_value_for("cookie_prefix");
    my $cookie_domain = Config::get_value_for("email_host");
    my $c4 = $q->cookie( -name => $cookie_prefix . "current",         -value => "1",                 -path => "/",  -domain => ".$cookie_domain");
    my $url;
    my $lastviewed = _get_last_blog_post_viewed(User::get_logged_in_userid());
    if ( $lastviewed ) {
        $url = Config::get_value_for("cgi_app") . "/blogpost/" . $lastviewed;
    } else {
        $url = Config::get_value_for("home_page");
    }
    print $q->redirect( -url => $url, -cookie => [$c4] );
}

sub _get_last_blog_post_viewed {
    my $userid = shift;

    my $lastblogpostviewed = 0;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql = "select lastblogpostviewed from $dbtable_users where id=$userid";

    $db->execute($sql);
    Page->report_error("system", "Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $lastblogpostviewed   = $db->getcol("lastblogpostviewed");
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $lastblogpostviewed;
}

1;
