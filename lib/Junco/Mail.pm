package Mail;

use strict;
use Net::SMTP;

sub send_new_account_email {
    my $rcpt = shift;
    my $username = shift;
    my $digest = shift;

    $digest = Utils::url_encode($digest);

    my $email_host = Config::get_value_for("email_host");

    my $subject_line = "$email_host new account activation";
    my $msg;

    $msg .= "Hello $username,\n\n";
    $msg .= "Your account has been created, but it's not active yet.\n";
    $msg .= "Click on the URL below or copy it into your browser.\n";
    $msg .= "Once your account is enabled, you can login and create content.\n\n";
    $msg .= "http://" . Config::get_value_for("email_host") . Config::get_value_for("cgi_app") . "/acct/$digest";

    _send_email($rcpt, $subject_line, $msg);
}

# to-do - ensure correct headers. check rfc 
sub _send_email {
    my $rcpt = shift;
    my $subject = shift;
    my $msg = shift;

    my $email_host  = Config::get_value_for("email_host");
    my $admin_email = Config::get_value_for("admin_email");
    my $site_name   = Config::get_value_for("site_name");

    # todo - use datetimeformatter
    my $strDateTime = _get_date_time_for_email();

    my $smtp = Net::SMTP->new($email_host);

    $smtp->mail($admin_email);

    $smtp->to($rcpt);

    $smtp->data();

    $smtp->datasend("To: <$rcpt>\n");
    $smtp->datasend("From: $site_name <$admin_email>\n");
    $smtp->datasend("Reply-To: $site_name <$admin_email>\n");
    $smtp->datasend("Sender: $site_name <$admin_email>\n");
    $smtp->datasend("Subject: $subject\n");
    $smtp->datasend("Content-type: text/plain; charset=\"us-ascii\"\n");
    $smtp->datasend("Date: $strDateTime\n");
    $smtp->datasend("X-App: $site_name \n");
    $smtp->datasend("X-$site_name-Date: $strDateTime\n");
    $smtp->datasend("X-Priority: 1\n");
    $smtp->datasend("\n");
    $smtp->datasend("$msg\n");
    $smtp->dataend();

    $smtp->quit;
}

sub send_password {
    my $rcpt = shift;
    my $pwd  = shift;

    my $site_name  = Config::get_value_for("site_name");
    my $home_page  = Config::get_value_for("home_page");
    my $email_host = Config::get_value_for("email_host");

    my $msg = "A request to create a new password to $site_name has been submitted.\n";
    $msg .= "The password is only being sent to this e-mail address.\n";
    $msg .= "Here's your new password for $home_page\n";
    $msg .= "\n";
    $msg .= "$pwd\n\n";
    $msg .= "After logging in with your new password, you can click on your username and change it.\n";

    my $subject_line = "$email_host new password created";

    _send_email($rcpt, $subject_line, $msg);
}

1;

