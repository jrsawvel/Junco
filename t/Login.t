#!/usr/bin/perl -w

use strict;
$|++;

use lib '/home/magee/Dvlp/Junco/lib';

use Test::More qw(no_plan);
# use Test::More tests => 8;
use Data::Dumper;
use HTTP::Cookies;
use WWW::Mechanize;
use LWP::UserAgent;

my $DISPLAY_HTML_RESPONSE = 0;

BEGIN {
    use_ok('Junco::Modules');
    use_ok('Junco::Signup');
}

can_ok('Signup', ('show_signup_form'));
can_ok('Signup', ('create_new_user'));
can_ok('Signup', ('activate_account'));

# test with valid, unique username and email
my $test_username = time();
my $test_email = "$test_username\@test.com";
test_signup_1($test_username, $test_email);


sub test_signup_1 {
    my $test_username = shift;
    my $test_email = shift;

    my $hr = test_create_user_account($test_username, $test_email);

    my $password;
    if ( $hr =~ m|debug pwd=([\w!@\$%\^&\*]+)|s ) {
        $password = $1;
    }        
    ok(defined($password), 'create_new_user() - password returned in debug mode');

    my $digest;
    if ( $hr =~ m|acct/(.+)">activate|s ) {
        $digest = $1; 
    }
    ok(defined($digest), 'create_new_user() - digest returned in debug mode');
    print "\n\n HTML Response from create_new_user:\n\n" . $hr . "\n\n" if $DISPLAY_HTML_RESPONSE;

    $hr = test_activate_account($digest) if $digest;
    ok($hr =~ m|Account Enabled|s, 'activate_account() - account activated');
    print "\n\n HTML Response from activate_account:\n\n" . $hr . "\n\n" if $DISPLAY_HTML_RESPONSE;

    $hr = test_log_into_account($test_email, $password);
    # ok need to test for something
    print "\n\n HTML Response from logging into account :\n\n" . $hr . "\n\n" if $DISPLAY_HTML_RESPONSE;
}

sub test_create_user_account {
    my $username = shift;
    my $email = shift;
    
    my $function = "createnewuser";
    my $domain   = Config::get_value_for("email_host");
    my $prog     = Config::get_value_for("cgi_app");

    my $mech = WWW::Mechanize->new();
    my $url = "http://jothut.com/cgi-bin/d16augjunco.pl/signup";
    $mech->get($url);
    $mech->submit_form (
        form_number => 2,
        fields => {
            username => $username,
            email    => $email
        }
    );
    return $mech->content();
}

sub test_activate_account {
    my $digest = shift;

    my $function = "acct";
    my $domain   = Config::get_value_for("email_host");
    my $prog     = Config::get_value_for("cgi_app");

    my $url = "http://$domain" . "$prog/$function/$digest";

    my $mech = WWW::Mechanize->new();
    $mech->get($url);
    return $mech->content();
}

sub test_log_into_account {
    my $email = shift;
    my $password = shift;
    
    my $function = "login";
    my $domain   = Config::get_value_for("email_host");
    my $prog     = Config::get_value_for("cgi_app");
    my $url = "http://$domain" . "$prog/$function";

    my $ua = LWP::UserAgent->new;
    $ua->cookie_jar(HTTP::Cookies->new(file => "lwpcookies.txt", autosave => 1, ignore_discard => 1));
    my $response = $ua->post( $url,
        [
            'password'      => $password,
            'email'         => $email
        ],
    );

    # should be 302 response
    # my $ua = LWP::UserAgent->new;
    # $ua->cookie_jar(HTTP::Cookies->new(file => "lwpcookies.txt", autosave => 1, ignore_discard => 1));
    # $url = "http://$domain" . "$prog/stream";
    # $response = $ua2->get($url);
    # print $response->decoded_content;

    return $response->decoded_content;
}

