#!/usr/bin/perl -w

use strict;
$|++;

use lib '/home/magee/Dvlp/Junco/lib';

use Test::More qw(no_plan);
# use Test::More tests => 8;
use REST::Client;
use LWP;
use Data::Dumper;


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

# test with valid, existing username 
test_signup_2($test_username, $test_email);

# test with valid, unique username but valid, existing email
$test_username = time();
test_signup_2($test_username, $test_email);

# test with both missing
test_signup_3(undef, undef);

# test username with invalid chars
$test_username = q(1234567890123456789012345678901); #31 chars
test_signup_4($test_username, $test_email);

# my @ic = qw(~ ` ! @ # $ % ^ & * ( ) - + = { } [ ] | \ " ' : ; , . < > ? /);
my @ic = split " ", q{~ ` ! @ # $ % ^ & * ( ) - + = { } [ ] | \ " ' : ; , . < > ? /};

foreach my $c (@ic) {
    $test_username = "abc" . $c . "123";
    test_signup_4($test_username, $test_email);
}

# test e-mail with invalid syntax
$test_username = time();
test_signup_5($test_username, $test_username);

# test e-mail with invalid syntax
$test_username = time();
test_signup_5($test_username, "Abc.example.com"); 

# test e-mail with invalid syntax
$test_username = time();
$test_email = q(just"not"right@example.com); 
test_signup_5($test_username, $test_email);

# test e-mail with invalid syntax
$test_username = time();
$test_email = q(this is"not\allowed@example.com);
test_signup_5($test_username, $test_email);

# test e-mail with invalid syntax
$test_username = time();
$test_email = q(this\ still\"not\\allowed@example.com); 
test_signup_5($test_username, $test_email);

# test e-mail with invalid syntax
$test_username = time();
$test_email = q(abc..123@test.com);
test_signup_5($test_username, $test_email);

# more e-mail syntax tests by accessing sub in StrNumUtils.pm
# http://haacked.com/archive/2007/08/21/i-knew-how-to-validate-an-email-address-until-i.aspx
test_email_syntax();



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
}

sub test_signup_2 {
    my $test_username = shift;
    my $test_email = shift;

    my $hr = test_create_user_account($test_username, $test_email);

    ok($hr =~ m|Error creating account|s, 'create_new_user() - Error creating account');
    ok($hr =~ m|already exists|s, 'create_new_user() - already exists');

    print "\n\n HTML Response from create_new_user:\n\n" . $hr . "\n\n" if $DISPLAY_HTML_RESPONSE;
}

sub test_signup_3 {
    my $test_username = shift;
    my $test_email = shift;

    my $hr = test_create_user_account($test_username, $test_email);

    ok($hr =~ m|Invalid Input|s, 'create_new_user() - Error creating account');
    ok($hr =~ m|Missing username|s, 'create_new_user() - Missing username');
    ok($hr =~ m|Missing e-mail|s, 'create_new_user() - Missing e-mail');

    print "\n\n HTML Response from create_new_user:\n\n" . $hr . "\n\n" if $DISPLAY_HTML_RESPONSE;
}

sub test_signup_4 {
    my $test_username = shift;
    my $test_email = shift;

    my $hr = test_create_user_account($test_username, $test_email);

    ok($hr =~ m|Invalid Input|s, 'create_new_user() - Error creating account');
    ok($hr =~ m|Username must contain|s,  'create_new_user() - Invalid username chars');

    print "\n\n HTML Response from create_new_user:\n\n" . $hr . "\n\n" if $DISPLAY_HTML_RESPONSE;
}

sub test_signup_5 {
    my $test_username = shift;
    my $test_email = shift;

    my $hr = test_create_user_account($test_username, $test_email);

    ok($hr =~ m|Invalid Input|s, 'create_new_user() - Error creating account');
    ok($hr =~ m|E-mail has incorrect syntax|s,  'create_new_user() - Invalid e-mail syntax');

    print "\n\n HTML Response from create_new_user:\n\n" . $hr . "\n\n" if $DISPLAY_HTML_RESPONSE;
}

sub test_create_user_account {
    my $username = shift;
    my $email = shift;
    
    my $function = "createnewuser";
    my $domain   = Config::get_value_for("email_host");
    my $prog     = Config::get_value_for("cgi_app");

    my $headers = {
        'Content-type' => 'application/x-www-form-urlencoded'
    };

    # set up a REST session
    my $rest = REST::Client->new( {
           host => "http://$domain" . "$prog",
    } );

    # then we have to url encode the params that we want in the body
    my $pdata = {
        'username'      => $username,
        'email'         => $email
    };
    my $params = $rest->buildQuery( $pdata );

    # but buildQuery() prepends a '?' so we strip that out
    $params =~ s/\?//;

    # then sent the request:
    # POST requests have 3 args: URL, BODY, HEADERS
    $rest->POST( "/$function" , $params , $headers );
    return $rest->responseContent();
}

sub test_log_into_account {
    my $email = shift;
    my $password = shift;
    
    my $function = "login";
    my $domain   = Config::get_value_for("email_host");
    my $prog     = Config::get_value_for("cgi_app");

    my $url = "http://$domain" . "$prog/$function";

    my $browser = LWP::UserAgent->new;

    my $response = $browser->post( $url,
        [
            'password'      => $password,
            'email'         => $email
        ],
    );
 
    # print Dumper $response; 
    # print Dumper $response->header('set-cookie');
    my @cookies= $response->header('set-cookie');

    foreach my $c (@cookies) {
        my @a = split(/;/, $c);
        my @b = split(/=/, $a[0]);
        print "name=$b[0]\n";
        print "value=$b[1]\n\n";
    }
}

sub test_activate_account {
    my $digest = shift;

    my $function = "acct";
    my $domain   = Config::get_value_for("email_host");
    my $prog     = Config::get_value_for("cgi_app");

    # set up a REST session
    my $rest = REST::Client->new();
    
    my $url = "http://$domain" . "$prog/$function/$digest";

    $rest->GET($url);
    return $rest->responseContent();
}

sub test_email_syntax {

    my $e;

    # invalid e-mail syntax
    $e = q(@"NotAnEmail");
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Invalid');

    $e = q(@"@NotAnEmail");
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Invalid');

    $e = q(@"""test\blah""@example.com");
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Invalid');

    $e = q("\"test\rblah\"@example.com");        
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Invalid');

    $e = q(@"""test""blah""@example.com");      
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Invalid');

    $e = q(@".wooly@example.com");             
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Invalid');

    $e = q(@"wo..oly@example.com");           
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Invalid');

    $e = q(@"pootietang.@example.com");      
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Invalid');

    $e = q(@".@example.com");               
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Invalid');

    $e = q(@"Ima Fool@example.com");       
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Invalid');


    # Valid e-mail syntax

    $e = q(@"""test\\blah""@example.com");
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Valid');

    $e = q("\"test\\\rblah\"@example.com");
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Valid');

    $e = q(@"""test\""blah""@example.com");
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Valid');

    $e = q(@"customer/department@example.com");
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Valid');

    $e = q(@"$A12345@example.com");
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Valid');

    $e = q(@"!def!xyz%abc@example.com");
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Valid');

    $e = q(@"_Yosemite.Sam@example.com");
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Valid');

    $e = q(@"~@example.com");
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Valid');

    $e = q(@"""Austin@Powers""@example.com");
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Valid');

    $e = q(@"Ima.Fool@example.com");
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Valid');

    $e = q(@"""Ima.Fool""@example.com");
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Valid');

    $e = q(@"""Ima Fool""@example.com");
    ok(StrNumUtils::is_valid_email($e) == 0, 'email syntax check - Should be Valid');

}
