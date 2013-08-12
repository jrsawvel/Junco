package Ajax;

use strict;
use warnings;

use Junco::Format;
use HTML::Entities;

sub return_stream {
    my $articles_ref = shift;
    my $description  = shift;
    my $post_type = shift;
    my $search_url   = shift;

    my $cgi_app          = Config::get_value_for("cgi_app");
    my $home_page        = "http://" . Config::get_value_for("email_host");
    my $site_name        = Config::get_value_for("site_name");
    my $site_description = Config::get_value_for("site_description");

    my @rss_articles = ();
    foreach my $hash_ref ( @$articles_ref ) {
        my %hash = ();
         if ( $hash_ref->{type} eq "m" ) {
# 27apr2013             $hash{title}        = encode_entities(StrNumUtils::remove_html($hash_ref->{formattedcontent}), '&');
             $hash{title}        = encode_entities(StrNumUtils::remove_html($hash_ref->{formattedcontent}));
         } else {
# 27apr2013            $hash{title}        = encode_entities($hash_ref->{title}, '&');
             $hash{title}        = encode_entities($hash_ref->{title});

             $hash{posttext} = StrNumUtils::remove_html($hash_ref->{formattedcontent});
             $hash{posttext} =~ s|http://[\S]+||ig; 
             $hash{posttext} = StrNumUtils::trim_spaces($hash{posttext});
             if ( length($hash{posttext}) > 250 ) {
                $hash{posttext} = substr $hash{posttext}, 0, 250;
                $hash{posttext} .= "...";
             }
            $hash{posttext} = Format::hashtag_to_link($hash{posttext});
            $hash{posttext} = StrNumUtils::remove_newline($hash{posttext}); # not working - todo
            $hash{posttext} = encode_entities($hash{post});
         }

        my %date_time = Utils::format_date_time_for_rss($hash_ref->{date}, $hash_ref->{time});

        $hash{articleid}    = $hash_ref->{id};
        $hash{creationdate} = $date_time{date};
        $hash{creationtime} = $date_time{time};
        $hash{author}       = $hash_ref->{username};
        $hash{cgi_app}      = $cgi_app;
        $hash{home_page}    = $home_page;
        $hash{urltitle}     = Format::clean_title($hash_ref->{title}) if $hash_ref->{type} eq "b";
        if ( $hash_ref->{type} eq "b" ) {
            $hash{posttype} = "blog";
        } elsif ( $hash_ref->{type} eq "m" ) {
            $hash{posttype} = "microblog";
        }
        push(@rss_articles, \%hash);
    }

    my $t = Page->new("ajax");
    $t->set_template_loop_data("article_loop", \@rss_articles);

    $t->set_template_variable("description", $description);
    $t->set_template_variable("site_name", $site_name);
    $t->set_template_variable("site_description", $site_description);
    $t->set_template_variable("link", $home_page . $cgi_app . $search_url);

    $t->print_template("Content-type: text/html");
}

1;
