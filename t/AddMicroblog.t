#!/usr/bin/perl -w

use strict;
$|++;

use lib '/home/magee/Dvlp/Junco/lib';

use Test::More qw(no_plan);
use HTTP::Cookies;
use LWP::UserAgent;
use HTML::Entities;
use Data::Dumper;

my $DISPLAY_HTML_RESPONSE = 0;

BEGIN {
    use_ok('Junco::Modules');
    use_ok('Junco::Microblog');
    use_ok('Junco::Microblog');
}

can_ok('Microblog', ('add_microblog'));
can_ok('Microblog', ('delete_microblog'));
can_ok('Microblog', ('undelete_microblog'));
can_ok('Microblog', ('show_microblog_post'));
can_ok('Microblog', ('_add_microblog'));


my $function = "addmicroblog";
my $domain   = Config::get_value_for("email_host");
my $prog     = Config::get_value_for("cgi_app");
my $url = "http://$domain" . "$prog/$function";
my $home_page = Config::get_value_for("home_page");

my $post = time() . ' test microblog post.';
# $post = ''; # returns status 200 with Junco error message: "Error: You must enter text ."

my $ua = LWP::UserAgent->new;
$ua->cookie_jar(HTTP::Cookies->new(file => "lwpcookies.txt", autosave => 1, ignore_discard => 1));

my $response = $ua->post( $url,
    [
        'microblogtext' => $post,
        'sb' => 'Post'
    ],
);

ok($response->status_line =~ m/302/s, "creating microblog post - 302 status should be returned for successful post.");

if ( $response->status_line =~ m/302/s ) { 
    my @l = $response->header('location');
    # $url = "http://$domain" . $l[0];
    $url = $l[0];
    ok(defined($url), "redirect url - if successful microblog post, then should have url back to home page.");
    ok($url eq $home_page, "redirect url - should equal to home_page config value.");
    $response = $ua->get($url);
    ok($response->decoded_content =~ m/stream posts/s, "stream posts phrase should be found on user's home page."); 
}    

my $hr = $response->decoded_content; 
print "\n\n HTML Response from adding microblog post:\n\n" . $hr . "\n\n"  if $DISPLAY_HTML_RESPONSE;


#####
# access the data subroutine directly.
# _add_microblog($title, $logged_in_userid, $markupcontent, $formattedcontent);
# the above subroutine returns the id of the newly created post.

my $cookie_string = $ua->cookie_jar->as_string; 

$cookie_string =~ m/dvlpjuncouserid=([\d]+)/s; 
my $userid = $1;

# this is used in the sql when inserting a new record.
$ENV{REMOTE_ADDR} = "192.168.1.7";
$post = "accessing _add_microblog directly - " . $post;
my $postid = Microblog::_add_microblog($post, $userid, $post, $post);
ok($postid > 0, "_add_microblog - should receive post id of successful microblog post.");

$url = "http://$domain" . "$prog/microblogpost/$postid";
$response = $ua->get($url);
ok($response->decoded_content =~ m/$post/s, "displaying new microblog post.");
 
