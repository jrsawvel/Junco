#!/usr/bin/perl -w

use strict;
$|++;

use lib '/home/magee/Dvlp/Junco/lib';

use Test::More qw(no_plan);
use HTTP::Cookies;
use LWP::UserAgent;
use Data::Dumper;

my $DISPLAY_HTML_RESPONSE = 0;

BEGIN {
    use_ok('Junco::Modules');
}
    my $function = "addarticle";
    my $domain   = Config::get_value_for("email_host");
    my $prog     = Config::get_value_for("cgi_app");
    my $url = "http://$domain" . "$prog/$function";

    my $post = time() . ' - blog post title line' . "\n\n" . 'this is a test *again $3.50 @sign* post with spaces.' . "\n\n" . 'try a #hashtag' . "\n";
    # $post = ''; # returns status 200 with Junco error message: 
    #   Article Input Error
    #   You must enter content.
    #   You must give a title for your article.
    # if post title already exists, return status 200 with Junco error message:
    #   Article Input Error
    #   <title of the post> already exists. Choose a different title.
    

    my $ua = LWP::UserAgent->new;
    $ua->cookie_jar(HTTP::Cookies->new(file => "lwpcookies.txt", autosave => 1, ignore_discard => 1));
    my $response = $ua->post( $url,
        [
            'markupcontent' => $post,
            'sb' => 'Post'
        ],
    );

    # print Dumper $response;
    # print $response->status_line . "\n";
    # print Dumper $response->header('location') . "\n";

    # process the redirect and show/get the newly-created blog post  
    # the newly-created blog post will have the something like the following in the title tag:
    #     <title>1381867853 - blog post title line - by 1381864205  | Dvlp</title>
    if ( $response->status_line eq "302" ) { 
        my @l = $response->header('location');
        $url = "http://$domain" . $l[0];
        $response = $ua->get($url);
#        print $response->decoded_content . "\n";
    }    


