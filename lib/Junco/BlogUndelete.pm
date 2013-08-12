package BlogUndelete;

use strict;
use warnings;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");
my $dbtable_tags       = Config::get_value_for("dbtable_tags");
my $dbtable_backlinks  = Config::get_value_for("dbtable_backlinks");

sub undelete_blog {
    my $tmp_hash = shift;  

    my $articleid = $tmp_hash->{one}; 

    User::user_allowed_to_function();

    my $q = new CGI;

    _undelete_blog_post(User::get_logged_in_userid(), $articleid);

    print $q->redirect( -url => $ENV{HTTP_REFERER});
}

sub _undelete_blog_post {
    my $userid = shift;
    my $articleid = shift;

    my $sql;
    my $tag_list_str;
    my $status_str = "o";

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $sql = "select id, tags, markupcontent from $dbtable_content where id=$articleid and authorid=$userid and type='b' and status='d'";
    $db->execute($sql);
    Page->report_error("system", "(41-a) Error executing SQL", $db->errstr) if $db->err;

    if ( !$db->fetchrow ) {
        $db->disconnect;
        Page->report_error("user", "Invalid action performed.", "Content does not exist");
    } else {
        $tag_list_str = $db->getcol("tags");
        my $tmp_markup = $db->getcol("markupcontent");
        if ( Utils::get_power_command_on_off_setting_for("private", $tmp_markup, 0) ) {
            $status_str = "s";
        } elsif ( Utils::get_power_command_on_off_setting_for("draft", $tmp_markup, 0) ) {
            $status_str = "p";
        }
    }

    $sql = "update $dbtable_content set status='$status_str' where id=$articleid and authorid=$userid and type='b'";
    $db->execute($sql);
    Page->report_error("system", "(41-b) Error executing SQL", $db->errstr) if $db->err;

    if ( $tag_list_str ) {
        # remove beginning and ending pipe delimeter to make a proper delimited string
        $tag_list_str =~ s/^\|//;
        $tag_list_str =~ s/\|$//;
        my @tags = split(/\|/, $tag_list_str);
        foreach (@tags) {
            my $tag = $_;
            $tag = $db->quote($tag);
            if ( $tag ) {
                $sql = "update $dbtable_tags set status='o' where articleid=$articleid and name=$tag";
                $db->execute($sql);
                Page->report_error("system", "(32-a) Error executing SQL", $db->errstr) if $db->err;
            }
        }
    }

    $sql = "update $dbtable_backlinks set status='o' where linkingfromarticleid = $articleid";
    $db->execute($sql);
    Page->report_error("system", "(32-a) Error executing SQL", $db->errstr) if $db->err;
      
    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;
}


1;
