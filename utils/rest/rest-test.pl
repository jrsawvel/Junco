#!/usr/bin/perl -wT

use strict;
use warnings;
$|++;
use lib '/home/account/Junco/lib';
use MIME::Base64;
use REST::Client;
use Data::Dumper;

# set set up some defaults:
my $domain   = 'hostname.com';
my $function = 'getuser';
my $user = 'username';
my $digest = 'user-digest';
my $prog = 'test.pl';

my $headers = {
#    Authorization => 'Basic '.  encode_base64($user . ':' . $digest),
    'Content-type' => 'application/x-www-form-urlencoded'
};
# die Dumper $headers;

# set up a REST session
my $rest = REST::Client->new( {
           host => "http://$domain/cgi-bin/$prog",
} );

# then we have to url encode the params that we want in the body
my $pdata = {
    'function' => $function,
    'value' => 'percent sign 20% this is a test',
    'auth' => encode_base64($user . ':' . $digest)
};
my $params = $rest->buildQuery( $pdata );
# die Dumper $params;

# but buildQuery() prepends a '?' so we strip that out
$params =~ s/\?//;

# then sent the request:
# POST requests have 3 args: URL, BODY, HEADERS
 $rest->POST( "/rest" , $params , $headers );
print $rest->responseContent() . "\n";

