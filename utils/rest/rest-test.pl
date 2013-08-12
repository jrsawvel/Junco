#!/usr/bin/perl -wT

use strict;
use warnings;
$|++;
use lib '/home/magee/Dvlp/Junco/lib';
use MIME::Base64;
use REST::Client;
use Data::Dumper;

# set set up some defaults:
my $domain   = 'jothut.com';
my $function = 'getuser';
my $user = 'j.r.';
my $digest = 'ru5Q9bWV2Olns9E';
my $prog = 'dvlpjunco.pl';

my $headers = {
#    Authorization => 'Basic '.  encode_base64($user . ':' . $digest),
    'Content-type' => 'application/x-www-form-urlencoded'
};
# die Dumper $headers;

# set up a REST session
my $rest = REST::Client->new( {
           host => "http://$domain/cgi-bin/$prog",
#            host => "http://toledotalk.com/cgi-bin",
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
# $rest->POST( "/kestrel.pl" , $params , $headers );
print $rest->responseContent() . "\n";

