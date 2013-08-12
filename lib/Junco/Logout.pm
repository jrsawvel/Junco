package Logout;

use strict;
use warnings;

sub logout {
    my $q = new CGI;
    my %h; 

    my $cookie_prefix = Config::get_value_for("cookie_prefix");
    my $cookie_domain = Config::get_value_for("email_host");

    my $c1 = $q->cookie( -name => $cookie_prefix . "userid",                -value => "0", -path => "/", -expires => "-10y", -domain => ".$cookie_domain");
    my $c2 = $q->cookie( -name => $cookie_prefix . "username",              -value => "0", -path => "/", -expires => "-10y", -domain => ".$cookie_domain");
    my $c3 = $q->cookie( -name => $cookie_prefix . "sessionid",             -value => "0", -path => "/", -expires => "-10y", -domain => ".$cookie_domain");
    my $c4 = $q->cookie( -name => $cookie_prefix . "current",               -value => "0", -path => "/", -expires => "-10y", -domain => ".$cookie_domain");

    my $url = Config::get_value_for("home_page"); 
    print $q->redirect( -url => $url, -cookie => [$c1,$c2,$c3,$c4] );
}

1; 
