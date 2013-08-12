package Theme;

use strict;
use warnings;

sub set_theme {
    my $tmp_hash = shift;  

    my $theme = $tmp_hash->{one};

    if ( !$theme ) {
        $theme = '';
    }
  
    my $q = new CGI;
    my $cookie_prefix = Config::get_value_for("cookie_prefix");
    my $cookie_domain = Config::get_value_for("email_host");
    my $c1 = $q->cookie( -name => $cookie_prefix . "theme", -value => "$theme", -path => "/", -expires => "+10y", -domain => ".$cookie_domain");
    my $url = $ENV{HTTP_REFERER};
    print $q->redirect( -url => $url, -cookie => [$c1] );
}

1;
