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


my $domain   = Config::get_value_for("email_host");
my $prog     = Config::get_value_for("cgi_app");
my $home_page = Config::get_value_for("home_page");

my $post = time() . ' test microblog post.';
# $post = ''; # returns status 200 with Junco error message: "Error: You must enter text ."

my $ua = LWP::UserAgent->new;
$ua->cookie_jar(HTTP::Cookies->new(file => "lwpcookies.txt", autosave => 1, ignore_discard => 1));

my $url = "http://$domain" . "$prog/addmicroblog";

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


#####
# delete microblog post with LWP
$url = "http://$domain" . "$prog/deletemicroblog/$postid";
$response = $ua->get($url);
ok($response->decoded_content =~ m/Content does not exist/s, "deleteing microblog post.");
$response = $ua->get($home_page);
# href="/cgi-bin/app.pl/undeletemicroblog/305">[undelete]</a> 
ok($response->decoded_content =~ m/undeletemicroblog\/$postid">\[undelete\]/s, "viewing home page stream - deleted post should have undelete link.");


#####
# try to view deleted microblog post
$url = "http://$domain" . "$prog/microblogpost/$postid";
$response = $ua->get($url);
ok($response->decoded_content =~ m/Invalid article access/s, "trying to view deleted microblog post - should receive Invalid article access.");
ok($response->decoded_content =~ m/Data doesn't exist/s, "trying to view deleted microblog post - should receive Data doesn't exist.");


#####
# undelete microblog post with LWP
$url = "http://$domain" . "$prog/undeletemicroblog/$postid";
$response = $ua->get($url);
ok($response->decoded_content =~ m/Content does not exist/s, "undeleteing microblog post.");
$response = $ua->get($home_page);
# look for something like this:  href="/cgi-bin/app.pl/deletemicroblog/305">[delete]</a> 
ok($response->decoded_content =~ m/deletemicroblog\/$postid">\[delete\]/s, "viewing home page stream - undeleted post should have delete link.");


#####
# viewing the undeleted microblog post
$url = "http://$domain" . "$prog/microblogpost/$postid";
$response = $ua->get($url);
ok($response->decoded_content =~ m/$post/s, "displaying the undeleted microblog post.");


#####
# create new microblog post with LWP to test the only two formatting options:
#   auto-link urls
#   auto-link hashtags
my $epoch = time();
my $url_to_link = $home_page . "/" . $epoch;
$post = $epoch . ' microblog post test formatting: #hashtag ' . $url_to_link;

$url = "http://$domain" . "$prog/addmicroblog";

$response = $ua->post( $url,
    [
        'microblogtext' => $post,
        'sb' => 'Post'
    ],
);

ok($response->status_line =~ m/302/s, "creating microblog post with formatting - 302 status should be returned for successful post.");
# view home page stream
$response = $ua->get($home_page);
# look for auto-link hashtag:  <a href="/cgi-bin/d16augjunco.pl/tag/hashtag">#hashtag</a>
ok($response->decoded_content =~ m/\/tag\/hashtag">#hashtag/s, "checking home page stream for microblog post with hashtag link.");
# look for a auto-link url: <a href="http://home_page.com/testpost">http://home_page.com/testpost</a>   
my $autolink = "<a href=\"$url_to_link\">$url_to_link</a>";
ok($response->decoded_content =~ m/$autolink/s, "checking home page stream for microblog post with auto-linked test URL.");

