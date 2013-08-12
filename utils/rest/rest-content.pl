#!/usr/bin/perl -wT

use strict;
use warnings;
$|++;
use lib '/home/magee/Dvlp/Junco/lib';
use MIME::Base64;
use REST::Client;
use Junco::Config;
use Junco::Db;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = "kestrel_content";

# set set up some defaults:
my $function;
my $domain      = 'jothut.com';
my $user        = 'J.R.';
my $prog        = 'dvlpjunco.pl';
my $headers     = {
    'Content-type' => 'application/x-www-form-urlencoded'
};

my $params;

my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

my $sql = "select id, markupcontent, date, type, createddate from $dbtable_content where type in ('b','m') and status='o' order by id asc";

$db->execute($sql);
Page->report_error("system", "(31) Error executing SQL", $db->errstr) if $db->err;

while ( $db->fetchrow ) {
    my $id             = $db->getcol("id");
    my $markupcontent  = $db->getcol("markupcontent");
    my $date           = $db->getcol("date");
    my $type           = $db->getcol("type");

    if ( $type eq "m" ) {
        $function = "addmicroblog";
    } elsif ( $type eq "b" ) {
        $function = "addblog";
    }
    my $createddate    = $db->getcol("createddate");
    my $rest = REST::Client->new( { host => "http://$domain/cgi-bin/$prog", } );
    my $pdata = {
        'id'            => $id,
        'markup'        => $markupcontent,
        'date'          => $date,
        'createddate'   => $createddate,
        'sb'            => 'submit'
    };
    $params = $rest->buildQuery( $pdata );
    # but buildQuery() prepends a '?' so we strip that out
    $params =~ s/\?//;
    # POST requests have 3 args: URL, BODY, HEADERS
    print STDERR "processing id $id ... ";
    $rest->POST( "/rest/$function" , $params , $headers );
    print $rest->responseContent() . "\n\n";
}
Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

$db->disconnect();
Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

