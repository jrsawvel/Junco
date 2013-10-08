package Password;

use strict;
use warnings;

use Junco::DigestMD5;
use Junco::Mail;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_users      = Config::get_value_for("dbtable_users");
my $dbtable_sessionids = Config::get_value_for("dbtable_sessionids");

sub change_password {
    my $q = new CGI;

    User::user_allowed_to_function();

    my $err_msg;
    undef $err_msg;

    my $userid            = User::get_logged_in_userid{};
    my $username          = User::get_logged_in_username{};

    my $oldpassword          = $q->param("oldpassword");
    my $newpassword          = $q->param("newpassword");
    my $verifypassword       = $q->param("verifypassword");

# testing
# $oldpassword = "something";
# $newpassword = "whatever";
# $verifypassword = "whatever";


    ######## PASSWORD
    if ( !defined($oldpassword) || !defined($newpassword) || !defined($verifypassword) ) {
        $err_msg .= "Missing old, new, or verify password.<br />\n";
    } else {
        $oldpassword       = StrNumUtils::trim_spaces($oldpassword);
        $newpassword       = StrNumUtils::trim_spaces($newpassword);
        $verifypassword    = StrNumUtils::trim_spaces($verifypassword);

        if ( !Utils::valid_password($newpassword) || !Utils::valid_password($verifypassword) ) {
            $err_msg .= "Password shorter than eight characters or longer than 30 characters or contains invalid characters. \n";
        } elsif ( $newpassword ne $verifypassword ) {
            $err_msg .= "New password and verify password do not match. \n";
        } elsif ( !Utils::is_strong_password($newpassword) ) {
            $err_msg .= "Password is too weak. \n";
        }

#        if ( length($oldpassword) < 8 || length($newpassword) < 8 || length($verifypassword) < 8 ) {
#            $err_msg .= "Password missing or shorter than eight characters long.<br />\n";
#        } elsif ( $oldpassword =~ /[ ]/ || $newpassword =~ /[ ]/ ||  $verifypassword =~ /[ ]/ ) {
#            $err_msg .= "No spaces allowed in password.<br />\n";
#        } elsif ( $newpassword ne $verifypassword ) {
#            $err_msg .= "New password and verify password do not match.<br />\n";
#        } elsif ( length($newpassword) > 30 ) {
#            $err_msg .= "New Password max length is 30 characters long.<br />\n";
#        }


    }

    my @rc;

    if ( defined($err_msg) ) {
        Page->report_error("user", "Invalid Input",  $err_msg);
    } else {
        @rc = _modify_password($userid, $username, $oldpassword, $newpassword);
    }

    my $cookie_prefix = Config::get_value_for("cookie_prefix");
    my $cookie_domain = Config::get_value_for("email_host");

    my $c1 = $q->cookie( -name => $cookie_prefix . "userid",                -value => "$userid", -path => "/", -domain => ".$cookie_domain");
    my $c2 = $q->cookie( -name => $cookie_prefix . "username",              -value => "$username", -path => "/",  -domain => ".$cookie_domain");
#    my $c3 = $q->cookie( -name => $cookie_prefix . "userdigest",     -value => "$rc[0]{USERDIGEST}", -path => "/",  -domain => ".$cookie_domain");
    my $c3 = $q->cookie( -name => $cookie_prefix . "sessionid",     -value => "$rc[0]{SESSIONID}", -path => "/",  -domain => ".$cookie_domain");

    my $url = Config::get_value_for("home_page");

    print $q->redirect( -url => $url, -cookie => [$c1,$c2,$c3] );
}


sub _modify_password {
    my $userid      = shift;
    my $username    = shift;
    my $oldpassword = shift;
    my $newpassword = shift;

    my $sqlstr;

    my @loop_data;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $sqlstr = "select id, password, createddate, email, digest, origemail from $dbtable_users where id=$userid and username='$username'";
    $db->execute($sqlstr);
    Page->report_error("system", "Error executing SQL", $db->errstr) if $db->err;

    my $uid;

    my $password = "";
    my $datetime = "";
    my $digest   = "";
    my $origemail    = "";

    my $multiple_sessionids = Config::get_value_for("multiple_sessionids");
    my $current_datetime = Utils::create_datetime_stamp();

    if ( $db->fetchrow ) {
        $uid = $db->getcol("id");
        if ( $uid != $userid ) {
            Page->report_error("user", "Old password is invalid", "Try again");
        }
        $password = $db->getcol("password");
        $datetime = $db->getcol("createddate");
        $origemail    = $db->getcol("origemail");
        $digest   = $db->getcol("digest");
    } else {
        Page->report_error("user", "Old password is incorrect", "Try again");
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    my $old_enc_pass = DigestMD5::create($username, $origemail, $oldpassword, $datetime);

    my $old_userdigest = DigestMD5::create($username, $origemail, $old_enc_pass, $datetime);
    $old_userdigest  =~ s|[^\w]+||g;

    if ( $old_enc_pass ne $password or $old_userdigest ne $digest ) {
        Page->report_error("user", "Old password is incorrect", "Try again");
    }

    # if got to here, old password matches. update db with new info.

    my $new_enc_pass = DigestMD5::create($username, $origemail, $newpassword, $datetime);

    my $new_userdigest = DigestMD5::create($username, $origemail,  $new_enc_pass, $datetime);
    $new_userdigest  =~ s|[^\w]+||g;

    my $new_sessionid = DigestMD5::create($username, $origemail, $new_enc_pass, $datetime, Utils::create_datetime_stamp());
    $new_sessionid =~ s|[^\w]+||g;

    $new_enc_pass   = $db->quote($new_enc_pass);
    $new_userdigest = $db->quote($new_userdigest);
    my $tmp_new_sessionid  = $db->quote($new_sessionid);
    $username       = $db->quote($username);
    $old_enc_pass   = $db->quote($old_enc_pass);
    $old_userdigest = $db->quote($old_userdigest);

    $sqlstr = "update $dbtable_users set password=$new_enc_pass, digest=$new_userdigest, sessionid=$tmp_new_sessionid where id=$userid and username=$username and password=$old_enc_pass and digest=$old_userdigest";
    $db->execute($sqlstr);
    Page->report_error("system", "(25) Error executing SQL", $db->errstr) if $db->err;

    if ( $multiple_sessionids ) {
        $sqlstr = "insert into $dbtable_sessionids (userid, sessionid, createddate, status)";
        $sqlstr .= " values ($userid, $tmp_new_sessionid, '$current_datetime', 'o')";
        $db->execute($sqlstr);
        Page->report_error("system", "(25) Error executing SQL", $db->errstr) if $db->err;
    } 

    $db->disconnect;
    Page->("system", "Error disconnecting from database.", $db->errstr) if $db->err;

#    $loop_data[0] = {USERDIGEST => $new_userdigest};
    $loop_data[0] = {SESSIONID => $new_sessionid};
    return @loop_data;
}

sub create_new_password {
    my $q = new CGI;
    my $username          = $q->param("username");
    my $email             = $q->param("email");
    my $error_exists = 0;
    my $err_msg = "";

    ###### USERNAME
    if ( !defined($username) ) {
        $err_msg .= "Missing username.<br />\n";
    } else {
        if ( !Utils::valid_username($username) ) {
            $err_msg .= "Username must contain fewer than 31 characters, and only letters, numbers, and underscores are allowed.";
        }
    }

    ###### EMAIL
    if ( !defined($email) ) {
        $err_msg .= "Missing e-mail.<br />\n";
    } else {
        $email = StrNumUtils::trim_spaces($email);
        if ( length($email) < 1 ) {
            $err_msg .= "Missing e-mail.<br />\n";
        } elsif ( length($email) > 255 ) {
            $err_msg .= "E-mail max length is 255 characters long.<br />\n";
        } elsif ( !StrNumUtils::is_valid_email($email) ) {
            $err_msg .= "E-mail has incorrect syntax.<br />\n";
        }
    }

    if ( $err_msg ) {
        Page->report_error("user", "Invalid Data.", $err_msg);
    }

    $username = StrNumUtils::trim_spaces($username);
    $email    = StrNumUtils::trim_spaces($email);

    my @h = _create_new_password($username, $email);

    if ( !@h ) {
        Page->report_error("user", "Invalid input.",  "Username and/or e-mail does not exist.");
    }

    if ( exists($h[0]{CUSMSG}) ) {
        Page->report_error("system", $h[0]{CUSMSG},  $h[0]{SYSMSG});
    }

    my $t = Page->new("lostpassword");

    if ( Config::get_value_for("debug_mode") ) {
        Page->report_error("user", "debug", "email=$h[0]{EMAIL} new-pwd=$h[0]{PWD}"); 
    }

    Mail::send_password($h[0]{EMAIL}, $h[0]{PWD});
    $t->display_page("Creating New Password");
}

sub create_initial_password {
    my $tmp_username = shift;
    my $origemail    = shift;

    my $new_password = "";
    my $datetime = "";
    my $username_in_database = "";

   # create new password
    my $min_pwd_len = Config::get_value_for("min_pwd_len");
    srand;
    my @chars = ("A" .. "K", "a" .. "k", "M" .. "Z", "m" .. "z", 2 .. 9, qw(! @ $ % ^ & *) );
#    $new_password = join("", @chars[ map {rand @chars} ( 1 .. 8 ) ]);
    $new_password = join("", @chars[ map {rand @chars} ( 1 .. $min_pwd_len ) ]);
    $new_password = lc($new_password);

    return $new_password;
}


sub _create_new_password {
    my $tmp_username = shift;
    my $tmp_email        = shift;

    my $new_password = "";
    my $datetime = "";
    my $username_in_database = "";
    my $origemail = "";

    my @loop_data;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $username = $db->quote($tmp_username);
    my $email    = $db->quote($tmp_email);

    my $sql = "select username, createddate, origemail from $dbtable_users where username=$username and email=$email and status in ('o','p')";

    $db->execute($sql);
    Page->report_error("system", "Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $datetime             = $db->getcol("createddate");
        $username_in_database = $db->getcol("username");
        $origemail            = $db->getcol("origemail");
    } else {
        $db->disconnect;
        return @loop_data;
    }

    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

   # create new password
    my $min_pwd_len = Config::get_value_for("min_pwd_len");
    srand;
    my @chars = ("A" .. "K", "a" .. "k", "M" .. "Z", "m" .. "z", 2 .. 9, qw(! @ $ % ^ & *) );
#    $new_password = join("", @chars[ map {rand @chars} ( 1 .. 8 ) ]);
    $new_password = join("", @chars[ map {rand @chars} ( 1 .. $min_pwd_len ) ]);
    $new_password = lc($new_password);

    my $pwddigest = DigestMD5::create($tmp_username, $origemail, $new_password, $datetime);

    my $new_userdigest = DigestMD5::create($username_in_database, $origemail, $pwddigest, $datetime);
    $new_userdigest  =~ s|[^\w]+||g;

    $pwddigest      = $db->quote($pwddigest);
    $new_userdigest = $db->quote($new_userdigest);

    $sql = "update $dbtable_users set password=$pwddigest, digest=$new_userdigest  where username=$username and email=$email and status='o'";
    $db->execute($sql);
    Page->report_error("system", "Error executing SQL", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $loop_data[0] = {EMAIL=> $tmp_email, PWD => $new_password};
}

1;
