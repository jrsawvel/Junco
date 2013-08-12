package Include;

use strict;
use warnings;

use Junco::RSS;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");

sub include_templates {
    my $str = shift;

    while ( $str =~ m/{{(.*?)}}/ ) {
        my $title = $1;
        my $include = "";
        if ( $title =~ m|^feed=h(.*?)://(.*?)$|i ) {
            my $rssurl = "h" . $1 . "://" .  $2;
            $include = RSS::get_rss_feed($rssurl);
        } 
        else {
            $include = _get_formatted_content_for_template($title);
            if ( !$include ) {
                $include = "**Include template \"$title\" not found.**";
            }
        }
        my $old_str = "{{$title}}";
        $str =~ s/\Q$old_str/$include/;
    }

    return $str;
}

sub _get_formatted_content_for_template {
    my $orig_str = shift;

    $orig_str = StrNumUtils::trim_spaces($orig_str);

    my $str;

    if ( $orig_str !~ m /^Template:/i ) {
        $str = "Template:" . $orig_str;
    } else {
        $str = $orig_str;
    }    

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $title            = $db->quote($str);

    my $sql = "select formattedcontent from $dbtable_content where title = $title and status in ('o') and type in ('b')";
    $db->execute($sql);
    Page->report_error("system", "(72) Error executing SQL", $db->errstr) if $db->err;

    my $formattedcontent = "";

    if ( $db->fetchrow ) {
        $formattedcontent = $db->getcol("formattedcontent");
    } else {
        $title            = $db->quote($orig_str);
        $sql = "select formattedcontent from $dbtable_content where title = $title and status in ('o') and type in ('b')";
        $db->execute($sql);
        Page->report_error("system", "(72) Error executing SQL", $db->errstr) if $db->err;
        if ( $db->fetchrow ) {
            $formattedcontent = $db->getcol("formattedcontent");
        }
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    if ( $formattedcontent =~ m/<tmpl>(.*?)<\/tmpl>/is ) {
        $formattedcontent = StrNumUtils::trim_br($1);
        $formattedcontent = StrNumUtils::trim_spaces($formattedcontent);
    }  

    return $formattedcontent;
}

1;
