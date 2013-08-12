package Login;

use strict;
use warnings;
use Junco::DigestMD5;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_users      = Config::get_value_for("dbtable_users");
my $dbtable_sessionids = Config::get_value_for("dbtable_sessionids");

sub show_login_form {
    my $t = Page->new("loginform");
    $t->display_page("Login Form");
}

sub login {
    my $tmp_hash = shift; # ref to hash

    my $sessionid = $tmp_hash->{one}; 
    $sessionid = "";

    my $q = new CGI;
    my $error_exists = 0;
    my $email             = $q->param("email");
    my $password          = $q->param("password");
    my $savepassword      = $q->param("savepassword");
    if ( !defined($savepassword) ) {
        $savepassword = "no";
    } 

# Page->report_error("user", "email=$email", "password=$password");

    ###### EMAIL
    if ( !StrNumUtils::is_valid_email($email) ) {
        $error_exists = 1;
    }

    ######## PASSWORD
    if ( !Utils::valid_password($password) ) {
        $error_exists = 1;
    }

    my @h = ();

    if ( $sessionid ) {
        @h = _get_user_settings_from_db($sessionid); # not in use - 7aug2013
    }
    elsif ( $error_exists ) {
         report_invalid_login();
    }
    else {
        @h = _verify_login($email, $password);
    }

    if ( !@h ) {
        report_invalid_login();
    }

    my $cookie_prefix = Config::get_value_for("cookie_prefix");
    my $cookie_domain = Config::get_value_for("email_host");

    my ($c1, $c2, $c3, $c4);
    if ( $savepassword eq "yes" ) {
        $c1 = $q->cookie( -name => $cookie_prefix . "userid",          -value => "$h[0]{userid}",     -path => "/",  -expires => "+10y",  -domain => ".$cookie_domain");
        $c2 = $q->cookie( -name => $cookie_prefix . "username",        -value => "$h[0]{username}",   -path => "/",  -expires => "+10y",  -domain => ".$cookie_domain");
        $c3 = $q->cookie( -name => $cookie_prefix . "sessionid",       -value => "$h[0]{sessionid}",  -path => "/",  -expires => "+10y",  -domain => ".$cookie_domain");
        $c4 = $q->cookie( -name => $cookie_prefix . "current",         -value => "1",                 -path => "/",  -domain => ".$cookie_domain");
    } else {
        $c1 = $q->cookie( -name => $cookie_prefix . "userid",          -value => "$h[0]{userid}",     -path => "/",  -domain => ".$cookie_domain");
        $c2 = $q->cookie( -name => $cookie_prefix . "username",        -value => "$h[0]{username}",   -path => "/",  -domain => ".$cookie_domain");
        $c3 = $q->cookie( -name => $cookie_prefix . "sessionid",       -value => "$h[0]{sessionid}",  -path => "/",  -domain => ".$cookie_domain");
        $c4 = $q->cookie( -name => $cookie_prefix . "current",         -value => "1",                 -path => "/",  -domain => ".$cookie_domain");
    }

    my $url;

    my $lastviewed = $h[0]{lastblogpostviewed};

    if ( $lastviewed ) {
        $url = Config::get_value_for("cgi_app") . "/blogpost/" . $lastviewed;
    } else {
        $url = Config::get_value_for("home_page");
    }

    print $q->redirect( -url => $url, -cookie => [$c1,$c2,$c3,$c4] );
}

sub report_invalid_login
{
    my $t = Page->new("invalidlogin");
    $t->display_page("Invalid Login");
}

sub _verify_login {
    my $tmp_email    = shift;
    my $tmp_password = shift;

    my $sessionid = "";
    my $sql = "";
    my @loop_data = ();

    my $current_datetime = Utils::create_datetime_stamp();

    $tmp_email    = StrNumUtils::trim_spaces($tmp_email);
    $tmp_password = StrNumUtils::trim_spaces($tmp_password);

    my $multiple_sessionids = Config::get_value_for("multiple_sessionids");

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;
   
    my $email = $db->quote($tmp_email); 
    $sql = "select id, username, password, createddate, origemail, lastblogpostviewed from $dbtable_users where email=$email and status='o'";

    $db->execute($sql);
    Page->report_error("system", "Error executing SQL", $db->errstr) if $db->err;

    my $datetime = "";
    my $md5_password = "";

    if ( $db->fetchrow ) {
        my %hash;

        $hash{userid}     = $db->getcol("id");
        $hash{username}   = $db->getcol("username");
        $md5_password    = $db->getcol("password");
        $datetime         = $db->getcol("createddate");
        $hash{origemail}   = $db->getcol("origemail");
        $hash{lastblogpostviewed}   = $db->getcol("lastblogpostviewed");

        my $tmp_dt = DateTimeFormatter::create_date_time_stamp_utc("(yearfull)-(0monthnum)-(0daynum) (24hr):(0min):(0sec)"); # db date format in gmt:  2013-07-17 21:15:34
        $hash{sessionid} = DigestMD5::create($hash{username}, $hash{origemail}, $md5_password, $datetime, $tmp_dt);
        $hash{sessionid} =~ s|[^\w]+||g;

        push(@loop_data, \%hash);
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    my $pwddigest = DigestMD5::create($loop_data[0]->{username}, $loop_data[0]->{origemail}, $tmp_password, $datetime);

    if ( $md5_password ne $pwddigest ) {
        @loop_data = ();
    } else {
        my $sessionid = $db->quote($loop_data[0]{sessionid});
        if ( $multiple_sessionids ) {
            $sql = "insert into $dbtable_sessionids (userid, sessionid, createddate, status)";
            $sql .= " values ($loop_data[0]{userid}, $sessionid, '$current_datetime', 'o')";
        } else {
            $sql = "update $dbtable_users set sessionid=$sessionid where id=$loop_data[0]{userid}";
        }
        $db->execute($sql);
        Page->report_error("system", "Error executing SQL", $db->errstr) if $db->err;
    }

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return @loop_data;
}


# not in use at the moment, and it only supports one sessionid
sub _get_user_settings_from_db {
    my $sessionid = shift;
    my @loop_data = ();

    my $tmp_password = "";
    my $password = "";
    my $sql = "";
    my $normal_login = 0;

    $normal_login = 1;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $sessionid = $db->quote($sessionid);

    $sql = "select id, username, password, createddate, lastblogpostviewed from $dbtable_users where sessionid=$sessionid and status='o'";

    $db->execute($sql);
    Page->report_error("system", "(82) Error executing SQL", $db->errstr) if $db->err;

    my $datetime = "";
    my $user_password = "";

    if ( $db->fetchrow ) {
        my %hash;

        $hash{userid}     = $db->getcol("id");
        $hash{username}   = $db->getcol("username");
        $hash{sessionid}  = $db->getcol("sessionid");
        $user_password    = $db->getcol("password");
        $datetime         = $db->getcol("createddate");
        $hash{lastblogpostviewed}  = $db->getcol("lastblogpostviewed");

        push(@loop_data, \%hash);
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    if ( $datetime and $normal_login ) {
        my $password = Utils::otp_encrypt_decrypt($tmp_password, $datetime, "enc");
        if ( $password ne $user_password ) {
            @loop_data = ();
        }
    }

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return @loop_data;
}

1;

