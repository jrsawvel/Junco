package User;
use strict;
use warnings;

use Junco::DigestMD5;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_users      = Config::get_value_for("dbtable_users");
my $dbtable_sessionids = Config::get_value_for("dbtable_sessionids");

my %parula_h           = _get_user_cookie_settings();

sub _get_user_cookie_settings {
    my $q = new CGI;
    my %h;
    my $cookie_prefix = Config::get_value_for("cookie_prefix");
    if ( defined($q->cookie($cookie_prefix. "userid")) ) {
        $h{userid}            = $q->cookie($cookie_prefix . "userid");
        $h{username}          = $q->cookie($cookie_prefix . "username");
        $h{sessionid}         = $q->cookie($cookie_prefix . "sessionid");
        $h{loggedin}          = 1;
        $h{current}           = defined($q->cookie($cookie_prefix . "current"))  ?  $q->cookie($cookie_prefix . "current")  :  0; 
        $h{textsize}          = defined($q->cookie($cookie_prefix . "textsize"))  ?  $q->cookie($cookie_prefix . "textsize")  :  "medium"; 
        $h{theme}             = defined($q->cookie($cookie_prefix . "theme"))  ?  $q->cookie($cookie_prefix . "theme")  :  "junco"; 
    } else {
        $h{loggedin}          = 0;
        $h{userid}            = -1;
        $h{textsize}          = defined($q->cookie($cookie_prefix . "textsize"))  ?  $q->cookie($cookie_prefix . "textsize")  :  "medium"; 
        $h{theme}             = defined($q->cookie($cookie_prefix . "theme"))  ?  $q->cookie($cookie_prefix . "theme")  :  "junco"; 
    }
    return %h;
}

sub get_text_size {
    return $parula_h{textsize};
}

sub get_theme {
    return $parula_h{theme};
}

sub get_logged_in_flag {
    return $parula_h{loggedin};
}

sub get_current {
    return $parula_h{current};
}

sub get_logged_in_username {
    return $parula_h{username};
}

sub get_logged_in_userid {
    return $parula_h{userid};
}

sub get_logged_in_sessionid {
    return $parula_h{sessionid};
}

sub user_allowed_to_function {
    if ( $parula_h{userid} < 1 ) {
        my $t = Page->new("notloggedin");
        $t->display_page("Not Logged-in");
        exit;
    } 
#    if ( !_valid_user_account(\%parula_h) ) {
    if ( !valid_user() ) {
        Page->report_error("user", "User access problem.",  "Invalid user.");
    } 
    return 1;
}

sub valid_user {
    my $h = \%parula_h;

    my $multiple_sessionids = Config::get_value_for("multiple_sessionids");

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    return 0 if $db->err;

    my $sql = "select id,username,password,email,digest,sessionid,createddate,origemail from $dbtable_users where id=$h->{userid} and status='o'";
    $db->execute($sql);
    return 0 if $db->err;

    my %hash;

    if ( $db->fetchrow ) {
        $hash{userid}                      = $db->getcol("id");
        $hash{username}                    = $db->getcol("username");
        $hash{password}                    = $db->getcol("password");
        $hash{email}                       = $db->getcol("email");
        $hash{userdigest}                  = $db->getcol("digest");
        $hash{sessionid}                   = $db->getcol("sessionid");
        $hash{date}                        = $db->getcol("createddate");
        $hash{origemail}                   = $db->getcol("origemail");
    } else {
        $db->disconnect;
        return 0;
    }

    return 0 if $db->err;

    if ( $h->{userid} != $hash{userid} || $h->{username} ne $hash{username} ) {
        return 0;
    }

    if ( !$multiple_sessionids  and  $h->{sessionid} ne $hash{sessionid} ) {
            return 0;
    } elsif ( $multiple_sessionids ) {
        my $tmp_sessionid = $db->quote($h->{sessionid});
        my $sql = "select userid from $dbtable_sessionids where sessionid=$tmp_sessionid and status='o' limit 1";
        $db->execute($sql);
        return 0 if $db->err;
        if ( $db->fetchrow ) {
            my $userid = $db->getcol("userid");
            if ( $userid != $h->{userid} ) {
                $db->disconnect;
                return 0;
            }
        } else {
            $db->disconnect;
            return 0;
        }
    }

    $db->disconnect;
    return 0 if $db->err;

    my $tmp_userdigest = DigestMD5::create($hash{username}, $hash{origemail}, $hash{password}, $hash{date});
    $tmp_userdigest  =~ s|[^\w]+||g;

    if ( $tmp_userdigest eq $hash{userdigest} ) {
        return 1;
    }

    return 0;
}

sub get_userid {
    my $username = shift;

    my $userid = 0;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Web::report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $username = $db->quote($username);

    my $user_id_status = Config::get_value_for("user_id_status");

    my $sql = "select id from $dbtable_users where username=$username and status in ($user_id_status)";
    $db->execute($sql);
    Web::report_error("system", "(21) Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $userid = $db->getcol("id");
    }
    Web::report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Web::report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $userid;
}


1;
