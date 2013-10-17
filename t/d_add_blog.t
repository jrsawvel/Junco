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
    use_ok('Junco::BlogAdd');
    use_ok('Junco::Format');
}

can_ok('BlogAdd', ('add_blog_post'));
can_ok('BlogAdd', ('_add_blog'));

my $domain   = Config::get_value_for("email_host");
my $prog     = Config::get_value_for("cgi_app");
my $home_page = Config::get_value_for("home_page");

my $title = time() . ' - blog post title line - using LWP';
my $post = "h1. " . $title . "\n\n" . 'this is a test *again $3.50 @sign* post with spaces.' . "\n\n" . 'try a #hashtag' . "\n";
# $post = ''; # returns status 200 with Junco error message: "Error: You must enter text ."

my $ua = LWP::UserAgent->new;
$ua->cookie_jar(HTTP::Cookies->new(file => "lwpcookies.txt", autosave => 1, ignore_discard => 1));

my $url = "http://$domain" . "$prog/addarticle";

my $response = $ua->post( $url,
    [
        'markupcontent' => $post,
        'sb' => 'Post'
    ],
);

ok($response->status_line =~ m/302/s, "creating blog post - 302 status should be returned for successful post.");
if ( $response->status_line =~ m/302/s ) { 
    my @l = $response->header('location');
    # $url = "http://$domain" . $l[0];
    $url = $l[0];
    $url = "http://$domain" . $url;
    ok(defined($url), "redirect url - if successful blog post, then should have url to new blog post.");
    $response = $ua->get($url);
    ok($response->decoded_content =~ m/$title/s, "displaying new blog post.");
}    

my $hr = $response->decoded_content; 
print "\n\n HTML Response from adding blog post:\n\n" . $hr . "\n\n"  if $DISPLAY_HTML_RESPONSE;


#####
# access the data subroutine directly.
# my $articleid = _add_blog($posttitle, $logged_in_userid, $markupcontent, $formattedcontent, $tag_list_str);

my $cookie_string = $ua->cookie_jar->as_string; 

$cookie_string =~ m/dvlpjuncouserid=([\d]+)/s; 
my $userid = $1;

# this is used in the sql when inserting a new record.
$ENV{REMOTE_ADDR} = "192.168.1.7";
$title = time() . ' - blog post title line - accessing _add_blog directly';
my $markup = "h1. " . $title . "\n\n" . 'this is a test *again $3.50 @sign* post with spaces.' . "\n\n" . 'try a #hashtag' . "\n";
my $formatted = 'this is a test *again $3.50 @sign* post with spaces.' . "\n\n" . 'try a #hashtag' . "\n";
$formatted = Format::format_content($formatted, "add");
my $postid = BlogAdd::_add_blog($title, $userid, $markup, $formatted, "");
ok($postid > 0, "_add_blog - should receive post id of successful blog post.");

$url = "http://$domain" . "$prog/blogpost/$postid";
$response = $ua->get($url);
ok($response->decoded_content =~ m/$title/s, "displaying new blog post.");


#####
# delete microblog post with LWP
$url = "http://$domain" . "$prog/deleteblog/$postid";
$response = $ua->get($url);
ok($response->decoded_content =~ m/Content does not exist/s, "deleteing blog post.");
$response = $ua->get($home_page);
# href="/cgi-bin/app.pl/undeleteblog/305">[undelete]</a> 
ok($response->decoded_content =~ m/undeleteblog\/$postid">\[undelete\]/s, "viewing home page stream - deleted post should have undelete link.");


#####
# try to view deleted blog post
$url = "http://$domain" . "$prog/blogpost/$postid";
$response = $ua->get($url);
ok($response->decoded_content =~ m/Invalid article access/s, "trying to view deleted blog post - should receive Invalid article access.");
ok($response->decoded_content =~ m/Data doesn't exist/s, "trying to view deleted blog post - should receive Data doesn't exist.");


#####
# undelete blog post with LWP
$url = "http://$domain" . "$prog/undeleteblog/$postid";
$response = $ua->get($url);
ok($response->decoded_content =~ m/Content does not exist/s, "undeleteing blog post.");
$response = $ua->get($home_page);
# look for something like this:  href="/cgi-bin/app.pl/deleteblog/305">[delete]</a> 
ok($response->decoded_content =~ m/deleteblog\/$postid">\[delete\]/s, "viewing home page stream - undeleted post should have delete link.");


#####
# viewing the undeleted blog post
$url = "http://$domain" . "$prog/blogpost/$postid";
$response = $ua->get($url);
ok($response->decoded_content =~ m/$title/s, "displaying the undeleted blog post.");


#####
# create new blog post with LWP to these formatting options:
#   auto-link urls
#   auto-link hashtags
my $epoch = time();
my $url_to_link = $home_page . "/" . $epoch;

$title = $epoch . ' - blog post title line - using LWP';
$post = "h1. " . $title . "\n\n" . 'this is a test *again $3.50 @sign* post with spaces.' . "\n\n" . 'try a #hashtag' . "\n" . "auto-link url " . $url_to_link . "\n";

$url = "http://$domain" . "$prog/addarticle";

$response = $ua->post( $url,
    [
        'markupcontent' => $post,
        'sb' => 'Post'
    ],
);

ok($response->status_line =~ m/302/s, "creating blog post with more formatting - 302 status should be returned for successful post.");
if ( $response->status_line =~ m/302/s ) { 
    my @l = $response->header('location');
    $url = $l[0];
    $url = "http://$domain" . $url;
    ok(defined($url), "redirect url - if successful blog post, then should have url to new blog post.");
    $response = $ua->get($url);
    ok($response->decoded_content =~ m/$title/s, "displaying new blog post.");

    # look for auto-link hashtag:  <a href="/cgi-bin/d16augjunco.pl/tag/hashtag">#hashtag</a>
    ok($response->decoded_content =~ m/\/tag\/hashtag">#hashtag/s, "checking blog post with hashtag link.");
    # look for a auto-link url: <a href="http://home_page.com/testpost">http://home_page.com/testpost</a>   
    my $autolink = "<a href=\"$url_to_link\">$url_to_link</a>";
    ok($response->decoded_content =~ m/$autolink/s, "checking blog post with auto-linked test URL.");
}    


