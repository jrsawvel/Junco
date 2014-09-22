package Checkin;

use strict;
use warnings;

use Encode qw(decode encode);
use HTML::Entities;
use REST::Client;
use JSON::PP;
use URI::Escape; 
use CGI qw(:standard);

use JRS::DateTimeUtils;
use Junco::Error;
use Junco::Format;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");

my $remote_ipaddress = $ENV{REMOTE_ADDR};


sub show_checkins {
    User::user_allowed_to_function();
    my $t = Page->new("checkin");
    $t->display_checkin("Check-in");
}

sub add_checkin {
    my $q = new CGI;

    # my $request_method = $q->request_method();
    my $message_text = $q->param("message");
    my $latitude     = $q->param("lat");
    my $longitude    = $q->param("lon");
    my $sb           = $q->param("sb");

    if ( !_allowed_to_post() ) {
        Error::report_error("400", "Invalid access.", "You need to login.");
    } 

    $message_text = StrNumUtils::trim_spaces($message_text);
    $message_text = Encode::decode_utf8($message_text);

    ## $message_text = HTML::Entities::decode($message_text);
    ## $message_text = URI::Escape::uri_unescape($message_text);

    my $err_msg;

    my $logged_in_userid   = User::get_logged_in_userid();

 if ( $sb ne "Get" ) {

    if ( !defined($message_text) || length($message_text) < 1 )  { 
       $err_msg .= "You must enter text.";
    } 

    if ( length($message_text) > 300 ) {
        my $len = length($message_text);
        $err_msg .= "$len chars entered. Max is 300.";
    }

    if ( defined($err_msg) ) {
        my %hash;
        $hash{error_code}      = 1;
        $hash{status}          = 400;
        $hash{error_message}   = $err_msg;
        $hash{message_text}    = $message_text;
        my $json_str = encode_json \%hash;
        #  print header('application/json', '400 Accepted');
        print header('application/json', '200 Accepted');
        print $json_str;
        exit;
    } 

    my $markupcontent = $message_text;
    $markupcontent = HTML::Entities::encode($markupcontent,'^\n^\r\x20-\x25\x27-\x7e');
    my $title = HTML::Entities::encode($markupcontent, '<>');
    my $formattedcontent = HTML::Entities::encode($markupcontent, '<>');
    my $checkin_id = _add_checkin($title, $logged_in_userid, $markupcontent, $formattedcontent, $latitude, $longitude);
 }

    my @checkins = _get_checkins($logged_in_userid);

    @checkins = _format_checkin_stream(\@checkins);

    my %json_hash;
    $json_hash{messages} = \@checkins;
    $json_hash{error_code} = 0;
    $json_hash{status}     = 200;

    my $json_str = encode_json \%json_hash;
    print header('application/json', '200 Accepted');
    print $json_str;

    exit;

}


sub _add_checkin {
    my $title              = shift;
    my $userid             = shift;
    my $markupcontent      = shift;
    my $formattedcontent   = shift;
    my $latitude           = shift;
    my $longitude          = shift;

    my $status = "o"; # s = secret or private

    my $datetime = Utils::create_datetime_stamp();

    my $tag_list_str = Format::create_tag_list_str($markupcontent);

    # remove beginning and ending pipe delimeter to make a proper delimited string
    $tag_list_str =~ s/^\|//;
    $tag_list_str =~ s/\|$//;
    my @tags = split(/\|/, $tag_list_str);
    my $tmp_tag_len = @tags;
    my $max_unique_hashtags = Config::get_value_for("max_unique_hashtags");
    if ( $tmp_tag_len > $max_unique_hashtags ) {
        Error::report_error("400", "Sorry.", "Only 7 unique hashtags are permitted.");
    }

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Error::report_error("500", "Error connecting to database.", $db->errstr) if $db->err;

    $title            = $db->quote($title);
    $markupcontent    = $db->quote($markupcontent);
    $formattedcontent = $db->quote($formattedcontent);
    $latitude         = $db->quote($latitude);
    $longitude        = $db->quote($longitude);
    my $quoted_tag_list_str     = $db->quote("|" . $tag_list_str . "|");

    # create article digest
    my $md5 = Digest::MD5->new;
    $md5->add(Utils::otp_encrypt_decrypt($title, $datetime, "enc"), $userid, $datetime);
    my $contentdigest = $md5->b64digest;
    $contentdigest =~ s|[^\w]+||g;

    # set type to c = check-in
    my $sql;
    $sql .= "insert into $dbtable_content (title, markupcontent, formattedcontent, type, status, authorid, date, contentdigest, createdby, createddate, tags, ipaddress, latitude, longitude)";
    $sql .= " values ($title, $markupcontent, $formattedcontent, 'c', '$status', $userid, '$datetime', '$contentdigest', $userid, '$datetime', $quoted_tag_list_str, '$ENV{REMOTE_ADDR}', $latitude, $longitude)";

    my $checkin_id= $db->execute($sql);
    Error::report_error("500", "Error executing SQL.", $db->errstr) if $db->err;

    $db->disconnect;
    Error::report_error("500", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $checkin_id;
}


sub _get_checkins {
    my $userid = shift;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Error::report_error("500", "Error connecting to database.", $db->errstr) if $db->err;

#        date_format(date_add(createddate, interval 0 hour), '%b %d, %Y') as createddate, 
    my $sql = <<EOSQL;
        select id, formattedcontent, status, createddate as dbdate,
        date_format(date_add(createddate, interval 0 hour), '%b %d, %Y - %r utc') as createddate, 
        unix_timestamp(createddate) as date_epoch_seconds,
        latitude, longitude 
        from $dbtable_content  
        where authorid=$userid and status='o' and type='c' 
        order by id desc limit 200
EOSQL


    my @loop_data = $db->gethashes($sql);
    Error::report_error("500", "Error executing SQL.", $db->errstr) if $db->err;

    $db->disconnect;
    Error::report_error("500", "Error disconnecting from database.", $db->errstr) if $db->err;

    return @loop_data;

}

sub _format_checkin_stream {
    my $loop_data         = shift;
    my @messages = ();
    foreach my $hash_ref ( @$loop_data ) {
        $hash_ref->{createddate}   = DateTimeUtils::format_creation_date($hash_ref->{createddate}, $hash_ref->{date_epoch_seconds});
        push(@messages, $hash_ref);
    }
    return @messages;
}

sub _allowed_to_post {

    my $rc = 1;

    my $logged_in_userid   = User::get_logged_in_userid();

    if ( $logged_in_userid < 1 ) {
        return 0;
    } 

    if ( !User::valid_user() ) {
        return 0;
    } 

    return 1;
}

sub _debug {
    my $str = shift;
    my %hash;
    $hash{error_code}      = 1;
    $hash{status}          = 200;
    $hash{error_message}   = $str;
    $hash{message_text}    = "debug";
    my $json_str = encode_json \%hash;
    print header('application/json', '200 Accepted');
    print $json_str;
    exit;
}


1;


