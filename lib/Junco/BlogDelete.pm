package BlogDelete;

use strict;
use warnings;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");
my $dbtable_tags       = Config::get_value_for("dbtable_tags");
my $dbtable_backlinks  = Config::get_value_for("dbtable_backlinks");

sub delete_blog {
    my $tmp_hash = shift;  

    my $articleid = $tmp_hash->{one}; 

    User::user_allowed_to_function();

    my $q = new CGI;

    _delete_blog_post(User::get_logged_in_userid(), $articleid);

    print $q->redirect( -url => $ENV{HTTP_REFERER});
}

sub _delete_blog_post {
    my $userid = shift;
    my $articleid = shift;

    my $sql;
    my $tag_list_str;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $delete_blog_post_status = Config::get_value_for("delete_blog_post_status");

    $sql = "select id,tags from $dbtable_content where id=$articleid and authorid=$userid and type='b' and status in ($delete_blog_post_status)";
    $db->execute($sql);
    Page->report_error("system", "(40-a) Error executing SQL", $db->errstr) if $db->err;

    if ( !$db->fetchrow ) {
        $db->disconnect;
        Page->report_error("user", "Invalid action performed.", "Content does not exist");
    } else {
        $tag_list_str = $db->getcol("tags");
    }

    $sql = "update $dbtable_content set status='d' where id=$articleid and authorid=$userid and type='b'";
    $db->execute($sql);
    Page->report_error("system", "(40-b) Error executing SQL", $db->errstr) if $db->err;

    if ( $tag_list_str ) {
        # remove beginning and ending pipe delimeter to make a proper delimited string
        $tag_list_str =~ s/^\|//;
        $tag_list_str =~ s/\|$//;
        my @tags = split(/\|/, $tag_list_str);
        foreach (@tags) {
            my $tag = $_;
            $tag = $db->quote($tag);
            if ( $tag ) {
                $sql = "update $dbtable_tags set status='d' where articleid=$articleid and name=$tag";
                $db->execute($sql);
                Page->report_error("system", "(32-a) Error executing SQL", $db->errstr) if $db->err;
            }
        }
    }

    $sql = "update $dbtable_backlinks set status='d' where linkingfromarticleid = $articleid";
    $db->execute($sql);
    Page->report_error("system", "(32-a) Error executing SQL", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;
}

1;
