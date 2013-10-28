package UserSettings;

use strict;
use warnings;

use HTML::Entities;
use Junco::Format;
use Text::Textile;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_users      = Config::get_value_for("dbtable_users");

sub show_user_settings_form {
    User::user_allowed_to_function();
    my $t = Page->new("settings");
    my @loop_data = _get_user_profile_page_settings(User::get_logged_in_userid());
    $t->set_template_variable("username", User::get_logged_in_username());
    $t->set_template_loop_data("loop_data", \@loop_data);
    $t->display_page("Customize User Settings");
}

sub _get_user_profile_page_settings {
    my $userid = shift;

    my $cgi_app    = Config::get_value_for("cgi_app");

    my @loop_data;
    undef @loop_data;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql = "select id,username,email,descmarkup from $dbtable_users where id=$userid and status ='o'";
    $db->execute($sql);
    Page->report_error("system", "(20) Error executing SQL", $db->errstr) if $db->err;

    my $tmp;

    while ( $db->fetchrow ) {
        my %hash;
        $hash{userid}                      = $db->getcol("id");
        $hash{username}                    = $db->getcol("username");
        $hash{email}                       = $db->getcol("email");
        $hash{descmarkup}                  = $db->getcol("descmarkup");
        $hash{cgi_app}                     = $cgi_app;
        push(@loop_data, \%hash);
    }

    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return @loop_data;
}

sub customize_user {
    User::user_allowed_to_function();
    my $q = new CGI;
    my $err_msg;
    undef $err_msg;

    my $userid              = User::get_logged_in_userid();
    my $username            = User::get_logged_in_username();
    my $email               = $q->param("email");
    my $descmarkup          = $q->param("descmarkup");

    my $descformat = "";

# testing
# $email = "b\@b.com";

    ########## E-MAIL
    if ( !defined($email) ) {
        $err_msg .= "Missing e-mail.<br />\n";
    } else {
        $email = StrNumUtils::trim_spaces($email);
        if ( length($email) < 1 ) {
            $err_msg .= "Missing e-mail.<br />\n";
        } elsif ( length($email) > 255 ) {
            $err_msg .= "E-mail must be less 256 characters long.<br />\n";
        } elsif ( !StrNumUtils::is_valid_email($email) ) {
            $err_msg .= "E-mail has incorrect syntax.<br />\n";
        }
    }

    ######## Description
    if ( defined($descmarkup) ) {
        $descformat = StrNumUtils::trim_spaces($descmarkup);
        $descformat = Format::remove_profile_blog_settings($descformat);
        $descformat = HTML::Entities::encode($descformat, '<>');
        $descformat = Format::permit_some_html_tags($descformat);
        $descformat = Format::custom_commands($descformat);
        $descformat = StrNumUtils::url_to_link($descformat);
        $descformat = Textile::textile($descformat);
        $descformat = Format::edit_for_bracket_case($descformat);
        $descformat = Format::check_for_external_links($descformat); 
    } else {
        $descformat = "";
    }

    my @rc;

    if ( defined($err_msg) ) {
        Page->report_error("user", "invalid input",  $err_msg);
    } else {
        _update_user($userid, $username, $email, $descformat, $descmarkup);
    }

    my $cookie_prefix = Config::get_value_for("cookie_prefix");
    my $cookie_domain = Config::get_value_for("email_host");

    my $c1 = $q->cookie( -name => $cookie_prefix . "userid",                -value => "$userid", -path => "/", -domain => ".$cookie_domain");
    my $c2 = $q->cookie( -name => $cookie_prefix . "username",              -value => "$username", -path => "/", -domain => ".$cookie_domain");

    my $url = Config::get_value_for("cgi_app") . "/savedchanges";

    print $q->redirect( -url => $url, -cookie => [$c1,$c2] );
}

sub _update_user {
    my $userid   = shift;
    my $username = shift;
    my $email    = shift;
    my $descformat = shift;
    my $descmarkup = shift;

    my @loop_data;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $descmarkup = $db->quote($descmarkup);
    $descformat = $db->quote($descformat);

    my $SqlStr;
    $SqlStr    .= "update $dbtable_users set " .
                  "email='$email', " .
                  "descformat=$descformat, " .
                  "descmarkup=$descmarkup " .
                  " where id=$userid";

#    return $loop_data[0] = {CUSMSG => "DEBUG", SYSMSG => "$showemailonprofile"};

    $db->execute($SqlStr);
    if ( $db->errstr =~ m|Duplicate entry '(.*?)'|i ) {
        Page->report_error("user", "Duplicate entry", "E-mail address $1 already exists.");
    } else {
        Page->report_error("system", "(26) Error executing SQL", $db->errstr) if $db->err;
    }

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return @loop_data;
}

sub show_user_changes {
    User::user_allowed_to_function();
    my $tmp_username = User::get_logged_in_username(); 
    my $t = Page->new("savedchanges");
    $t->set_template_variable("username", $tmp_username);
    $t->display_page("Saved Custom Changes For $tmp_username");
}

1;

