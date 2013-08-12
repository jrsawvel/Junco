package RSS;

use strict;

use HTML::Entities;
use XML::FeedPP;
use LWP::Simple;
use Junco::Stream;
use Junco::Format;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");
my $dbtable_users    = Config::get_value_for("dbtable_users");

sub get_rss_feed {
    my $rssurl = shift;

    my $getdesc = 0;

    my $html    = "";

#    if ( $rssurl =~ m|^http://(.*?) desc$|i ) {
#        $rssurl = "http://" . $1;
    if ( $rssurl =~ m|^h(.*?)://(.*?) desc$|i ) {
        $rssurl = "h" . $1 . "://" . $2;
        $getdesc = 1;
    }

# why is this here?? 7mar2013 -   $rssurl = decode_entities($rssurl);

    my $xml = get($rssurl);
    return "Could not retrieve feed for $rssurl" unless $xml;

    # $xml =~ s|<description>.*?</description>|<description></description>|gs;

# commented out the following two lines on 8may2013.
# why was i removing the cdata opening and closing syntax?
#    $xml =~ s|<!\[CDATA\[||gs;
#    $xml =~ s|\]\]>||gs;

    my $feed = XML::FeedPP->new($xml);

    if ( !$feed ) {
        $html = "Error parsing XML feed.";
        return $html;
    }

# print "Content-type: text/html\n\n";
# print "<html><body><pre>\n";
# print Dumper($feed);
# print "</pre></body></html>\n";
# exit;


    $html .=   "<p><a href=\"" . $feed->link() . "\">" . $feed->title() . "</a> - " . $feed->pubDate() . " </p>\n";

    foreach my $item ( $feed->get_item() ) {
        my $link  = $item->link();
# 8may2013       my $title = decode_entities($item->title());
        my $title = $item->title();
        my $desc;
        if ( $getdesc ) {
            $desc = $item->description();
# 8may2013           $desc = decode_entities($desc);
        }
        my $date;
        if ( $item->pubDate() ) {
            $date = $item->pubDate();
        } 

        if ( $getdesc ) {
            $html .= "<p><a href=\"$link\">$title</a> - <small>$date</small><br />$desc</p>\n";
        } else {
            $html .= "<p><a href=\"$link\">$title</a> - <small>$date</small><br /></p>\n";
        }
    }

    return $html;
}

sub get_rss {
    my $tmp_hash = shift;  

    my $stream_type = $tmp_hash->{one}; 
    my $username  = $tmp_hash->{two}; 

# testing
# $stream_type = "blog";
# $username = "J.R.";

    my $userid = 0;

    if ( $username ) {
        $userid = User::get_userid($username);
    }

    if ( !$userid ) {
        Page->report_error("user", "Invalid user $username.", "User not found.");  
    }

    if ( $stream_type ne "blog" and $stream_type ne "microblog" and $stream_type ne "stream" ) {
        Page->report_error("user", "Invalid RSS action.", "$stream_type not available");
    }

    my %values = Stream::_set_page_and_user_data($username, 1, $stream_type, "rss"); 

    my $sql_where_str  = " where $values{authoridstr} and c.parentid>=0 and $values{type} and $values{status} and c.authorid=u.id ";
    $sql_where_str    .= " order by c.date desc limit $values{max_entries} ";

    my $stream_data = Stream::_get_content($sql_where_str);

    display_rss($stream_data, $username . "'s $stream_type posts", $stream_type, "/$stream_type/$username");
}

sub display_rss {
    my $articles_ref = shift;
    my $description  = shift;
    my $post_type = shift;
    my $search_url   = shift;

    my $cgi_app          = Config::get_value_for("cgi_app");
#    my $home_page        = Config::get_value_for("home_page");
    my $home_page        = "http://" . Config::get_value_for("email_host");
    my $site_name        = Config::get_value_for("site_name");
    my $site_description = Config::get_value_for("site_description");

    my @rss_articles = ();
    foreach my $hash_ref ( @$articles_ref ) {
        my %hash = ();

# Page->report_error("user", "debug", $hash_ref->{type});

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

    my $t = Page->new("rss");
    $t->set_template_loop_data("article_loop", \@rss_articles);

    $t->set_template_variable("description", $description);
    $t->set_template_variable("site_name", $site_name);
    $t->set_template_variable("site_description", $site_description);
    $t->set_template_variable("link", $home_page . $cgi_app . $search_url);

    $t->print_template("Content-type: text/xml");
}

sub kdebug {
    my $str = shift;
    Page->report_error("user", "debug", $str);
}

1;
