package Signup;

use strict;
use warnings;
use Junco::DigestMD5;
use Junco::CreateUser;
use Junco::ActivateAccount;
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
    my $email             = $q->param("email");

    my $u = CreateUser->new($username, $email);
    $u->check_username();    
    $u->check_email();    
    
    Page->report_error("user", "Invalid Input",  $u->get_syntax_error_string()) if $u->is_user_error(); 

    $u->add_new_user();

    Page->report_error("user",   $u->get_cusmsg(),  $u->get_sysmsg()) if $u->is_user_error(); 
    Page->report_error("system", $u->get_cusmsg(),  $u->get_sysmsg()) if $u->is_system_error(); 

    my $t = Page->new("newaccount");
    $t->set_template_variable("newusername", $username);

    if ( Config::get_value_for("debug_mode") ) {
        Page->report_error("system", "debug pwd=" . $u->get_password(),  "<a href=\"" . Config::get_value_for("cgi_app") . "/acct/" . $u->get_user_digest() . "\">activate</a>.");
    } else {
        # todo Mail::send_new_account_email($email, $username, $rc[1]{USERDIGEST});
    }

    $t->display_page("New User Sign Up");
}

sub activate_account {
    my $tmp_hash = shift; # ref to hash

    my $digest = $tmp_hash->{one};
 
    if ( !defined($digest) || length($digest) < 1 ) {
        Page->report_error("system", "Missing data.", "No digest given.");
    }

    my $u = ActivateAccount->new($digest);

    Page->report_error("user",   $u->get_cusmsg(),  $u->get_sysmsg()) if $u->is_user_error(); 
    Page->report_error("system", $u->get_cusmsg(),  $u->get_sysmsg()) if $u->is_system_error(); 

    my $t = Page->new("activateaccount");
    $t->set_template_variable("msg1", "Your account has been activated. You can now login.");
    $t->display_page("Account Enabled");
}

1;
