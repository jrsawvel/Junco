#!/usr/bin/perl -w

use strict;
$|++;

use lib '/home/magee/Dvlp/Junco/lib';

use Test::More qw(no_plan);
use HTTP::Cookies;
use LWP::UserAgent;

my $DISPLAY_HTML_RESPONSE = 0;

BEGIN {
    use_ok('Junco::Modules');
}
    my $function = "addmicroblog";
    my $domain   = Config::get_value_for("email_host");
    my $prog     = Config::get_value_for("cgi_app");
    my $url = "http://$domain" . "$prog/$function";

    my $post = '15oct2013 - 1534 - this is a test $3.50 @sign post with spaces.';
    # $post = ''; # returns status 200 with Junco error message: "Error: You must enter text ."

    my $ua = LWP::UserAgent->new;
    $ua->cookie_jar(HTTP::Cookies->new(file => "lwpcookies.txt", autosave => 1, ignore_discard => 1));
    my $response = $ua->post( $url,
        [
            'microblogtext' => $post,
            'sb' => 'Post'
        ],
    );

    # print Dumper $response;
    # return $response->decoded_content;

    print $response->status_line . "\n";

    print $response->decoded_content . "\n";

#    print "\n\n HTML Response from activate_account:\n\n" . $hr . "\n\n"; # if $DISPLAY_HTML_RESPONSE;
