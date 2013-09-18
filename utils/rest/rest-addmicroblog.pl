#!/usr/bin/perl -wT

use strict;
use warnings;
$|++;
use lib '/home/account/Junco/lib';
use MIME::Base64;
use REST::Client;

# set set up some defaults:
my $domain   = 'hostname.com';
my $function = 'addmicroblog';
my $user = 'username';
my $prog = 'test.pl';

my $headers = {
    'Content-type' => 'application/x-www-form-urlencoded'
};

# set up a REST session
my $rest = REST::Client->new( {
           host => "http://$domain/cgi-bin/$prog",
} );

# then we have to url encode the params that we want in the body
my $pdata = {
    'markup'        => 'http://jothut.com test post number 5 from #rest client script. old date - test import date insert #test.',
    'date'          => '2013-09-05 20:55:10',
    'createddate'   => '2013-09-05 20:55:10',
    'sb'            => 'submit'
};
my $params = $rest->buildQuery( $pdata );

# but buildQuery() prepends a '?' so we strip that out
$params =~ s/\?//;

# then sent the request:
# POST requests have 3 args: URL, BODY, HEADERS
$rest->POST( "/rest/$function" , $params , $headers );
print $rest->responseContent() . "\n";

