package Page;

use strict;
use warnings;
use NEXT;

{
    $CGI::HEADERS_ONCE=1;

    use HTML::Template;
# jrs todo 11oct2013 can i comment this out here since it's called in Modules.pm?   use Junco::Config;

    sub new {
        my ($class, $template_name) = @_;
                 
        my $self = {
            TMPL => undef,
            NAME => undef
        };

        my $kestrel_th              = Config::get_value_for("template_home");
        $ENV{HTML_TEMPLATE_ROOT}    = $kestrel_th;

        $self->{TMPL} = HTML::Template->new(filename => "$kestrel_th/$template_name.tmpl");

        $self->{NAME} = $template_name;

        bless($self, $class);
                 
        return $self;
    }

    sub get_template_name {
        my ($self) = @_;
        return $self->{NAME};
    }
         
    sub set_template_variable {
        my ($self, $var_name, $var_value) = @_;
        $self->{TMPL}->param("$var_name"  =>   $var_value); 
    }

    sub set_template_loop_data {
        my ($self, $loop_name, $loop_data) = @_;
        $self->{TMPL}->param("$loop_name"  =>   $loop_data); 
    }

    sub print_template {
        my ($self, $content_type) = @_;
        print $content_type . "\n\n";
        print $self->{TMPL}->output;
        exit;
    }

    sub display_page_min {
        my ($self, $function) = @_;

        my @http_header = ("Content-type: text/html;\n\n", "");
        my $http_header_var = 0;
        print $http_header[$http_header_var]; 

        my $site_name       =  Config::get_value_for("site_name");

        __set_template_variable($self, "loggedin",           User::get_logged_in_flag());
        __set_template_variable($self, "username",           User::get_logged_in_username());
        __set_template_variable($self, "cgi_app",            Config::get_value_for("cgi_app"));
        __set_template_variable($self, "home_page",          Config::get_value_for("home_page"));
        __set_template_variable($self, "site_name",          $site_name);
        __set_template_variable($self, "css_dir_url",  Config::get_value_for("css_dir_url")); 
        __set_template_variable($self, "textsize",   User::get_text_size());

        print $self->{TMPL}->output;

        exit;
    }

    sub display_page {
        my ($self, $function) = @_;

        my @http_header = ("Content-type: text/html;\n\n", "");
        my $http_header_var = 0;
        print $http_header[$http_header_var]; 

        # format as:  Jul 18, 2013 - 8:43 p.m. EDT
        my $datetimestr = DateTimeFormatter::create_date_time_stamp_local("(monthname) (daynum), (yearfull) - (12hr):(0min) (a.p.) (TZ)");

        my $site_name = Config::get_value_for("site_name");
        __set_template_variable($self, "home_page",  Config::get_value_for("home_page")); 
        __set_template_variable($self, "loggedin",   User::get_logged_in_flag());
        __set_template_variable($self, "username",   User::get_logged_in_username());
        __set_template_variable($self, "cgi_app",    Config::get_value_for("cgi_app"));
        __set_template_variable($self, "site_name",  $site_name); 
        __set_template_variable($self, "pagetitle",          "$function | $site_name");
        __set_template_variable($self, "site_description",   Config::get_value_for("site_description"));
        __set_template_variable($self, "maincss_url",        Config::get_value_for("maincss_url"));  
        __set_template_variable($self, "serverdatetime",     $datetimestr);
        __set_template_variable($self, "requesturi", $ENV{REQUEST_URI});
        __set_template_variable($self, "css_dir_url",  Config::get_value_for("css_dir_url")); 
        __set_template_variable($self, "textsize",   User::get_text_size());
        __set_template_variable($self, "theme",   User::get_theme());
        

        print $self->{TMPL}->output;
        exit;
    }

    sub display_checkin {
        my ($self, $function) = @_;

        my @http_header = ("Content-type: text/html;\n\n", "");
        my $http_header_var = 0;
        print $http_header[$http_header_var]; 

        my $site_name       =  Config::get_value_for("site_name");
        my $datetimestr = DateTimeFormatter::create_date_time_stamp_local("(monthname) (daynum), (yearfull) - (12hr):(0min) (a.p.) (TZ)");

        __set_template_variable($self, "home_page",          Config::get_value_for("home_page"));
        __set_template_variable($self, "site_name",          $site_name);
        __set_template_variable($self, "loggedin",           User::get_logged_in_flag());
        __set_template_variable($self, "serverdatetime",     $datetimestr);
        __set_template_variable($self, "pagetitle",          "$function | $site_name");

        print $self->{TMPL}->output;

        exit;
    }

    sub report_error
    {
        my ($self, $type, $cusmsg, $sysmsg) = @_;
        my $o = $self->new("$type" . "error");

        $o->set_template_variable("cusmsg", "$cusmsg");

        if ( $type eq "user" ) { 
            $o->set_template_variable("sysmsg", "$sysmsg");
        } elsif ( ($type eq "system") and Config::get_value_for("debug_mode") ) {
            $o->set_template_variable("sysmsg", "$sysmsg");
        }
        $o->set_template_variable("referer", Utils::get_http_referer()); 
        $o->display_page("Error");
        exit;
    }

    sub DESTROY {
        my ($self) = @_;
        $self->EVERY::__destroy;
    }


    ##### private routines 
    sub __destroy {
        my ($self) = @_;
        delete $self->{TMPL};
    }

    sub __set_template_variable {
        my ($self, $var_name, $var_value) = @_;
        $self->{TMPL}->param("$var_name"  =>   $var_value); 
    }

}

1;
