package Mail;

use strict;
use Net::SMTP;

sub send_new_account_email {
    my $rcpt = shift;
    my $username = shift;
    my $digest = shift;

    Page->report_error("user", "Action unsupported.", "Sending e-mail is not enabled at this time.");

    $digest = Utils::url_encode($digest);

    my $site_name = Config::get_value_for("site_name");
    my $email_host = Config::get_value_for("email_host");

    my $subject_line = "$site_name new account activation";
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

    my $email_host  = Config::get_value_for("email_host_2");
    my $admin_email = Config::get_value_for("admin_email_2");
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

    Page->report_error("user", "Action unsupported.", "Sending e-mail is not enabled at this time.");

    my $site_name  = Config::get_value_for("site_name");
    my $home_page  = Config::get_value_for("home_page");
    my $email_host = Config::get_value_for("email_host_2");

    my $msg = "A request to create a new password to $site_name has been submitted.\n";
    $msg .= "The password is only being sent to this e-mail address.\n";
    $msg .= "Here's your new password for $home_page\n";
    $msg .= "\n";
    $msg .= "$pwd\n\n";
    $msg .= "After logging in with your new password, you can click on your username and change it.\n";

    my $subject_line = "$site_name password created";

    _send_email($rcpt, $subject_line, $msg);
}

sub _get_date_time_for_email {

    my $offset = -4;  # change the -0500 below

    my $epochsecs = time();

    # set to Eastern U.S.
    $epochsecs = $epochsecs + ($offset * 3600);

    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @days   = qw(Sun Mon Tue Wed Thu Fri Sat);

    my ($sec, $mi, $h)    = (gmtime($epochsecs))[0, 1, 2];

    my ($d, $m, $y, $dow) = (gmtime($epochsecs))[3,4,5,6];

    my $dt = sprintf "%s, %02d %s %04d %02d:%02d:%02d -0400", $days[$dow], $d, $months[$m], 2000+($y-100), $h, $mi, $sec;

    return $dt;
}

1;

