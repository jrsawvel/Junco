package Signup;

use strict;
use warnings;
use Junco::DigestMD5;
use Junco::Password;
# use Junco::Mail;

sub show_signup_form {
    Page->report_error("user", "New user sign-ups are not available at the moment.", "Sorry for the inconvenience.") if !Config::get_value_for("new_user_signups_allowed");
    my $t = Page->new("signupform");
    $t->display_page("New User Sign-up Form");
}

sub create_new_user {
    my $q = new CGI;
    my $err_msg;
    undef $err_msg;

    my $username          = $q->param("username");
#    my $password          = $q->param("password");
#    my $verifypassword    = $q->param("verifypassword");
    my $email             = $q->param("email");

    ###### USERNAME

    if ( !defined($username) ) {
        $err_msg .= "Missing username.<br />\n";
    } else {
        $username = StrNumUtils::trim_spaces($username);
        if ( !Utils::valid_username($username) ) {
            $err_msg .= "Username must contain fewer than 31 characters, and only letters, numbers, and underscores are allowed.";
        }
    }

    ########## E-MAIL

    if ( !defined($email) ) {
        $err_msg .= "Missing e-mail.<br />\n";
    } else {
        $email = StrNumUtils::trim_spaces($email);
        if ( length($email) < 1 ) {
            $err_msg .= "Missing e-mail.<br />\n";
        } elsif ( length($email) > 255 ) {
            $err_msg .= "E-mail must be shorter than 256 characters long.<br />\n";
        } elsif ( !StrNumUtils::is_valid_email($email) ) {
            $err_msg .= "E-mail has incorrect syntax.<br />\n";
        } 
    }

    my @rc;

    if ( defined($err_msg) ) {
        Page->report_error("user", "Invalid Input",  $err_msg);
    } else {
        my $password = Password::create_initial_password($username, $email);
        @rc = _add_new_user($username, $password, $email);
    }

    my $t = Page->new("newaccount");
    $t->set_template_variable("newusername", $username);

    if ( Config::get_value_for("debug_mode") ) {
        Page->report_error("system", "debug pwd=$rc[2]{PASSWORD}",  "<a href=\"" . Config::get_value_for("cgi_app") . "/acct/" . $rc[1]{USERDIGEST} . "\">activate</a>.");
    } else {
# todo        Mail::send_new_account_email($email, $username, $rc[1]{USERDIGEST});
    }

    $t->display_page("New User Sign Up");
}

sub activate_account {
    my $tmp_hash = shift; # ref to hash

    my $digest = $tmp_hash->{one};
 
    if ( !defined($digest) || length($digest) < 1 ) {
        Page->report_error("system", "Missing data.", "No digest given.");
    }
    _activate_account($digest);
    my $t = Page->new("activateaccount");
    $t->set_template_variable("msg1", "Your account has been activated. You can now login.");
    $t->display_page("Account Enabled");
}


########## private procedures #########

sub _add_new_user {
    my $username = shift;
    my $password = shift;
    my $email    = shift;

    my $ipaddress = "";
    my $datetime = Utils::create_datetime_stamp();

    my @loop_data;

    my $pt_db_source       = Config::get_value_for("database_host");
    my $pt_db_catalog      = Config::get_value_for("database_name");
    my $pt_db_user_id      = Config::get_value_for("database_username");
    my $pt_db_password     = Config::get_value_for("database_password");

    my $dbtable_users       = Config::get_value_for("dbtable_users");

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $enc_pass = DigestMD5::create($username, $email, $password, $datetime);

    my $userdigest = DigestMD5::create($username, $email, $enc_pass, $datetime);
    $userdigest  =~ s|[^\w]+||g;

    $datetime   = $db->quote($datetime);
    $username   = $db->quote($username);
    $enc_pass   = $db->quote($enc_pass);
    $email      = $db->quote($email);
    $userdigest = $db->quote($userdigest);
    $ipaddress  = $db->quote($ENV{REMOTE_ADDR});

    my $sql = "";
    $sql    .= "insert into $dbtable_users(username,  password,  email,  digest,      createddate, ipaddress,  origemail)";
    $sql    .= "                   values ($username, $enc_pass, $email, $userdigest, $datetime,   $ipaddress, $email)";
 
    my $userid = $db->execute($sql);
    if ( $db->err ) {
        if ( $db->errstr =~ m/Duplicate entry(.*?)for key/i ) {
            $db->disconnect;
            Page->report_error("user", "Error creating account.", "$1 already exists.");
        }
        Page->report_error("system", "(1) Error executing SQL", $db->errstr) if $db->err;
    }

    $sql = "select id, digest from $dbtable_users where username = $username";
    $db->execute($sql);
    Page->report_error("system", "(2) Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $loop_data[0] = {USERID     => $db->getcol("id")};
        $loop_data[1] = {USERDIGEST => $db->getcol("digest")};
        $loop_data[2] = {PASSWORD   => $password};
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return @loop_data;
}

sub _activate_account {
    my $digest = shift;

    my $pt_db_source       = Config::get_value_for("database_host");
    my $pt_db_catalog      = Config::get_value_for("database_name");
    my $pt_db_user_id      = Config::get_value_for("database_username");
    my $pt_db_password     = Config::get_value_for("database_password");

    my $dbtable_users       = Config::get_value_for("dbtable_users");

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $digest = $db->quote($digest);

    my $sql;

    $sql = "select id from $dbtable_users where digest = $digest";
    $db->execute($sql);
    Page->report_error("system", "(4) Error executing SQL", $db->errstr) if $db->err;

    if ( !$db->fetchrow ) {
        Page->report_error("system", "Error activating account", "Invalid data given or account does not exist.");
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $sql = "update $dbtable_users set status = 'o' where digest = $digest and status = 'p'";
    $db->execute($sql);
    Page->report_error("system", "(5) Error executing SQL", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;
}

1;

