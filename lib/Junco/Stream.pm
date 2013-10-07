package Stream;

use strict;

use Junco::Format;
use Junco::BlogLastViewed;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");
my $dbtable_users      = Config::get_value_for("dbtable_users");

my $T; # object for HTML template usage;

sub show_entire_stream {
    my $tmp_hash = shift;
    my $logged_in_username = User::get_logged_in_username();
    my $stream_username = $tmp_hash->{one};

    if ( !$stream_username and $logged_in_username ) {
        $tmp_hash->{one} = $logged_in_username;
    } elsif ( !$stream_username && !$logged_in_username) {
        my $t = Page->new("notloggedin");
        $t->display_page("Not Logged-in");
        exit;
    } 

    if ( !User::get_current() and $logged_in_username ) {
        BlogLastViewed::display_last_viewed_blog_post();                
    }

    show_stream($tmp_hash, "stream");
}

sub show_microblog_stream {
    my $tmp_hash = shift;
    show_stream($tmp_hash, "microblog");
}

sub show_blog_stream {
    my $tmp_hash = shift;
    show_stream($tmp_hash, "blog");
}

sub show_private_blog_stream {
    my $tmp_hash = shift;
    Page->report_error("user", "Invalid action.", "Unsupported function.") if !User::valid_user();
    $tmp_hash->{one} = User::get_logged_in_username();
    show_stream($tmp_hash, "private");
}

sub show_draft_blog_stream {
    my $tmp_hash = shift;
    Page->report_error("user", "Invalid action.", "Unsupported function.") if !User::valid_user();
    $tmp_hash->{one} = User::get_logged_in_username();
    show_stream($tmp_hash, "draft");
}

sub show_archives_month_year {
    my $tmp_hash = shift;
    show_stream($tmp_hash, "blogarchivepage");
}

sub show_stream {
    my $tmp_hash = shift;  
    my $stream_type = shift; # blog or microblog

    my $username;
    my $tmp_page_num;
    my $month;
    my $quotemonth;
    my $year;
    my $quoteyear;

    $username = $tmp_hash->{one}; 
    $tmp_page_num = $tmp_hash->{two}; 

    if ( $stream_type eq "blogarchivepage" ) {
        $month         = $tmp_hash->{one};
        $year          = $tmp_hash->{two};
        $quotemonth    = StrNumUtils::quote_string($tmp_hash->{one});
        $quoteyear     = StrNumUtils::quote_string($tmp_hash->{two});
        $tmp_page_num  = $tmp_hash->{three}; 
        $username      = $tmp_hash->{four}; 
    }

    my %values = _set_page_and_user_data($username, $tmp_page_num, $stream_type, "stream"); 

    $values{month} = $month;
    $values{year}  = $year;

    my $offset = Utils::get_time_offset();

    my $sql_where_str = " where $values{authoridstr} and c.parentid>=0 and $values{type} and $values{status} and c.authorid=u.id ";

    if ( $stream_type eq "blogarchivepage" ) {
        $sql_where_str .=  " and date_format(date_add(c.createddate, interval $offset hour), '%Y') = $quoteyear ";
        $sql_where_str .=  " and date_format(date_add(c.createddate, interval $offset hour), '%m') = $quotemonth ";
# todo can this by changed from c.id to something else?
# what about using createddate? yep, it worked in kestrel code. 27jul2013
#        $sql_where_str .=      "order by c.id desc limit $values{max_entries_plus_one} offset $values{page_offset} ";
        $sql_where_str .=      "order by c.createddate desc limit $values{max_entries_plus_one} offset $values{page_offset} ";
    } else {
        $sql_where_str    .= " order by c.date desc limit $values{max_entries_plus_one} offset $values{page_offset} ";
    }

    my $stream_data = _get_content($sql_where_str);

    my @posts = _prepare_stream_data(\%values, $stream_data);

    _display_stream(\%values, \@posts);
}

sub _get_content {
    my $sql_where_str = shift;

    my $offset = Utils::get_time_offset();

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql = <<EOSQL;
      select c.id, c.parentid, c.title, c.markupcontent, c.formattedcontent, 
             c.type, c.status, c.authorid, c.tags, c.date as datetime, c.replycount, 
             date_format(date_add(c.date, interval $offset hour), '%b %d, %Y') as date, 
             date_format(date_add(c.date, interval $offset hour), '%r') as time, 
             date_format(date_add(c.date, interval $offset hour), '%d%b%Y') as urldate, 
             unix_timestamp(c.date) as dateepochseconds, 
             u.username 
             from $dbtable_content c, $dbtable_users u 
             $sql_where_str
EOSQL

    my @loop_data = $db->gethashes($sql);

    Page->report_error("system", "(39) Error executing SQL", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return \@loop_data;
}

sub _set_page_and_user_data {
    my $username = shift;
    my $page     = shift;
    my $stream_type = shift;
    my $template = shift;

    my %hash;

    $T = Page->new($template);

    $hash{streamtype} = $stream_type;

    $hash{userid}   = 0;
    $hash{username} = "All";
    $hash{page}     = 1;

    if ( StrNumUtils::is_numeric($page) ) {
        $hash{page} = $page;
    }

    if ( !defined($username) or !$username or lc($username) eq "all" ) {
        $hash{authoridstr} = "c.authorid > 0";   
    } else {
        $hash{userid} = User::get_userid($username);
        $hash{username} = $username;
        $hash{authoridstr} = "c.authorid=$hash{userid}";   
    }

    $hash{type} = "c.type in ('m','b')";
    if ( $stream_type eq "blog" or $stream_type eq "private" or $stream_type eq "blogarchivepage" or $stream_type eq "draft" ) {
        $hash{type} = "c.type in ('b')"; 
    } elsif ( $stream_type eq "microblog" ) {
        $hash{type} = "c.type in ('m')";
    }    

    $hash{status} = "c.status in (" . Config::get_value_for("stream_default_display_status") . ")";

    $hash{logged_in_username} = User::get_logged_in_username();

    $hash{logged_in_user_viewing_own_stream}  = 0; 
    if ( $hash{userid} > 0 and User::valid_user() and ($hash{logged_in_username} eq $hash{username})  ) {
        $hash{logged_in_user_viewing_own_stream} = 1;
        $hash{status} = "c.status in (" . Config::get_value_for("stream_user_display_status") . ")";
# 22apr2013        Web::set_template_variable("logged_in_user_viewing_own_favorites", $hash{username}) if ($hash{streamtype} eq "microblog" or $hash{streamtype} eq "stream") and $template ne "rss" ;
        $T->set_template_variable("logged_in_user_viewing_own_stream", $hash{username}) if ($hash{streamtype} eq "stream") and $template ne "rss" ;
        if ( $stream_type eq "private" ) {
            $hash{status} = "c.status in (" . Config::get_value_for("stream_private_display_status") . ")";
        } elsif ( $stream_type eq "draft" ) {
            $hash{status} = "c.status in (" . Config::get_value_for("stream_draft_display_status") . ")";
        }
    } elsif ( $hash{userid} == 0 and User::valid_user() and $hash{username} eq "All"  ) {
        $T->set_template_variable("logged_in_user_viewing_own_stream", $hash{username}) if ($hash{streamtype} eq "microblog" or $hash{streamtype} eq "stream") and $template ne "rss" ;
    }

    $hash{max_entries} = Config::get_value_for("max_entries_on_page");
    $hash{max_entries} = Config::get_value_for("max_replies_on_page") if $stream_type eq "replies";
    $hash{page_offset} = $hash{max_entries} * ($hash{page} - 1);
    $hash{max_entries_plus_one} = $hash{max_entries} + 1;
    $hash{cgiapp} = Config::get_value_for("cgi_app");

    return %hash;
}

sub _display_stream {
    my $hash = shift;
    my $stream = shift;
    my $extra_hash = shift; #additional or custom info to display in a custom template

    my $no_posts = 0;

    my $webpage_title = $hash->{username} . " " . $hash->{streamtype} . " posts";

    $T->set_template_variable("username_of_favorite_articles", $hash->{username});
    $T->set_template_variable("display_username", "$hash->{username}'s");

    if ( exists($stream->[0]->{post}) ) {
       $T->set_template_loop_data("stream_loop", $stream);
    } else {
        $no_posts = 1;
    }

    if ( $hash->{userid} == 0 ) {
        $T->set_template_variable("viewing_all_stream", 1);
    }
 
    $hash->{maxitemsonmainpage} = Config::get_value_for("max_entries_on_page");
    my $len = $stream;
 
    if ( $hash->{page} == 1 ) {
        $T->set_template_variable("notpageone", 0);
    } else {
        $T->set_template_variable("notpageone", 1);
    }

    if ( $len >= $hash->{maxitemsonmainpage} && $hash->{next_link_bool} ) {
        $T->set_template_variable("notlastpage", 1);
    } else {
        $T->set_template_variable("notlastpage", 0);
    }

    my $previouspagenum = $hash->{page} - 1;
    my $nextpagenum     = $hash->{page} + 1;

    $T->set_template_variable("streamtype", $hash->{streamtype});
    if ( $hash->{streamtype} eq "blog" or $hash->{streamtype} eq "microblog"  or $hash->{streamtype} eq "private"  or $hash->{streamtype} eq "draft" ) {
        $T->set_template_variable("streamtypetext", $hash->{streamtype}); 
    } 

    my $nextpageurl     = "$hash->{cgiapp}/$hash->{streamtype}/$hash->{username}/$nextpagenum";
    my $previouspageurl = "$hash->{cgiapp}/$hash->{streamtype}/$hash->{username}/$previouspagenum";

    if ( $hash->{streamtype} eq "blogarchivepage" ) {
        $nextpageurl     = "$hash->{cgiapp}/$hash->{streamtype}/$hash->{month}/$hash->{year}/$nextpagenum/$hash->{username}";
        $previouspageurl = "$hash->{cgiapp}/$hash->{streamtype}/$hash->{month}/$hash->{year}/$previouspagenum/$hash->{username}";
    } elsif ( $hash->{streamtype} eq "followingstream" ) {
        $nextpageurl     = "$hash->{cgiapp}/$hash->{streamtype}/$hash->{followingtype}/$hash->{username}/$nextpagenum";
        $previouspageurl = "$hash->{cgiapp}/$hash->{streamtype}/$hash->{followingtype}/$hash->{username}/$previouspagenum";
    } elsif ( $hash->{streamtype} eq "search" or $hash->{streamtype} eq "tag" ) {
        $nextpageurl     = "$hash->{cgiapp}/$hash->{streamtype}/$hash->{searchurlstr}/$nextpagenum";
        $previouspageurl = "$hash->{cgiapp}/$hash->{streamtype}/$hash->{searchurlstr}/$previouspagenum";

        if ( $len < 1 ) {
            $T->set_template_variable("nomatches", "1");
        } else {
            $T->set_template_variable("nomatches", "0");
        }
        $T->set_template_variable("doingsearch", 1);
        $T->set_template_variable("nomatches", 1) if $no_posts;
        $T->set_template_variable("keywords", $hash->{searchstring});
        $T->set_template_variable("searchurlstr", $hash->{searchurlstr});
        if ( $hash->{singletagsearch} ) {
            $T->set_template_variable("singletagsearch", 1); 
            $T->set_template_variable("isalreadyfollowingtag", $hash->{isalreadyfollowingtag}); 
        }
        $webpage_title = "Search Results For $hash->{searchstring}";
    } 

    $T->set_template_variable("nextpageurl", $nextpageurl);
    $T->set_template_variable("previouspageurl", $previouspageurl);

    my $pageheadingurl = "";

    if ( $hash->{streamtype} eq "followingstream" ) {
        $T->set_template_variable("showfollowing", 1);
        $T->set_template_variable("followingtype", $hash->{followingtype});
        $T->set_template_variable("otherfollowingtype", $hash->{otherfollowingtype});
    } elsif ( $hash->{userid} >= 0 and $hash->{streamtype} ne "blogarchivepage" and $hash->{streamtype} ne "private" and $hash->{streamtype} ne "draft" and $hash->{streamtype} ne "repliesstream" ) { 
        $pageheadingurl = " <a href=\"$hash->{cgiapp}/$hash->{streamtype}/All\">all $hash->{streamtype} postings</a>"; 
        $T->set_template_variable("pageheadingurl", $pageheadingurl);
    } elsif ( $hash->{streamtype} eq "blogarchivepage" ) {
        $pageheadingurl = " blog archive - $hash->{month}/$hash->{year} - <a href=\"$hash->{cgiapp}/blogarchives\">all archives</a>"; 
        $T->set_template_variable("pageheadingurl", $pageheadingurl);
    }

    if ( $extra_hash ) {
        foreach my $key ( keys %$extra_hash ) {
            $T->set_template_variable($key, $extra_hash->{$key});
        }
    }

    $T->display_page($webpage_title);
}

sub _prepare_stream_data {
    my $values      = shift;
    my $stream_data = shift;

    my @posts = ();

    my $row_count = 0;

    foreach my $hash_ref ( @$stream_data ) {
        my %hash = ();
        $row_count++;
        if ( $row_count > $values->{max_entries} ) {
            $values->{next_link_bool} = 1;
            last;
        }
        $hash{articleid}       = $hash_ref->{id};
        $hash{title}           = $hash_ref->{title};
        $hash{post}            = $hash_ref->{formattedcontent};
    #    $hash{creationdate}    = $hash_ref->{date};
    #    $hash{creationtime}    = lc($hash_ref->{time});
        $hash{creationdate}    = _format_creation_date($hash_ref->{date}, $hash_ref->{dateepochseconds});
        $hash{author}          = $hash_ref->{username};
        $hash{cgi_app}         = $values->{cgiapp};

        my $tmp_status = $hash_ref->{status};
        if ( ($tmp_status eq "o") or ($values->{logged_in_user_viewing_own_stream} and ($tmp_status eq "s" or $tmp_status eq "p") ) ) {
            $hash{useraction} = "delete";
        } elsif ( $tmp_status eq "d" ) {
            $hash{useraction} = "undelete";
        }

        $hash{logged_in_user_viewing_own_stream} = $values->{logged_in_user_viewing_own_stream};
        $hash{blogposttype} = 0;
        %hash = _process_blog_post(\%hash, $hash_ref, $values) if $hash_ref->{type} eq "b"; 
        %hash = _process_microblog_post(\%hash, $hash_ref, $values) if $hash_ref->{type} eq "m"; 

        # only microblog posts can be replies.
        # parentid > 0 and type = m and status =o is a reply post, 
        #     and parentid refers to the post being replied to.
        if ( $hash_ref->{parentid} && $values->{streamtype} ne "replies"  ) {
            $hash{post} = "<em>(RE:)</em> " . $hash{post}; 
            $hash{parentid} = $hash_ref->{parentid};
        }

        $hash{replycount} = $hash_ref->{replycount};

        push(@posts, \%hash);
    }
    return @posts;
}

sub _process_microblog_post {
    my $hash = shift;
    my $hash_ref = shift;
    my $values = shift;

    $hash->{urldate}         = $hash_ref->{urldate};
    $hash->{urltitle}        = Format::clean_title($hash->{title});

    if ( length($hash->{urltitle}) > 75 ) {
        $hash->{urltitle} = substr $hash->{urltitle}, 0, 75;
    }

    return %$hash;
}

sub _process_blog_post {
    my $hash = shift;
    my $hash_ref = shift;
    my $values = shift;

    $hash->{blogposttype} = 1;

    my $tmp_post = StrNumUtils::remove_html($hash->{post});
    my $tmp_word_count = scalar(split(/\s+/s, $tmp_post));
    $hash->{readingtime} = 0;
    $hash->{readingtime} = int($tmp_word_count / 180) if $tmp_word_count >= 180;

    if ( !$values->{topshelfblog} ) {
        $hash->{post} = StrNumUtils::remove_html($hash->{post});
        $hash->{post} =~ s|http://[\S]+||ig; 
        $hash->{post} = StrNumUtils::trim_spaces($hash->{post});

        # display part of post as intro text - 300 chars
        if ( Utils::get_power_command_on_off_setting_for("showintro", $hash_ref->{markupcontent}, 1) ) {
            if ( length($hash->{post}) > 250 ) {
                $hash->{post} = substr $hash->{post}, 0, 250;
                $hash->{post} .= "...";
                $hash->{extendedtextexists} = 1;
            }
            $hash->{post} = Format::hashtag_to_link($hash->{post});
        } else {
                $hash->{post} = "...";
                $hash->{extendedtextexists} = 1;
        }
    } else {
        if ( $hash->{post} =~ m|^(.*?)<more \/>(.*?)$|is ) {
            $hash->{post} = $1;
            my $tmp_extended = StrNumUtils::trim_spaces($2);
            if ( length($tmp_extended) > 0 ) {
                $hash->{extendedtextexists} = 1;
            }
        } 
    }


    # display part of post as intro text - 50 words
#    my @introtext_array = split(/\s+/s, $hash->{post});
#    my $introtext_array_len = @introtext_array;
#    if ( $introtext_array_len > 50 ) {
#        $hash->{post} = "";
#        my $i_ia;
#        for ($i_ia=0; $i_ia < 50; $i_ia++) {
#            $hash->{post} .= $introtext_array[$i_ia] . " "; 
#        } 
#        $hash->{post} .= "...";
#        $hash->{extendedtextexists} = 1;
#    }


    $hash->{urltitle}        = Format::clean_title($hash->{title});

    $hash->{urldate}         = $hash_ref->{urldate};

    my $tmp_tag_str          = $hash_ref->{tags};
    if ( length($tmp_tag_str) > 2 ) {
        $hash->{blogtaglinkstr} = Format::create_blog_tag_list($tmp_tag_str);
        $hash->{blogtagsexist} = 1;
    }
    return %$hash;
}

sub kdebug {
    my $str = shift;
    Page->report_error("user", "debug", $str);
}

sub _format_creation_date {
    my $creationdate = shift;
    my $dateepochseconds = shift;

    my $offset = Utils::get_time_offset();

    my $current_epochseconds = time(); 
    my $twenty_four_hours = 86400;

    my $tmp_offset = $offset - 3;   # include the three hours for Pacific time

       my $tmp_dateepochseconds = $dateepochseconds + (3600 * $tmp_offset);
       my $tmp_diff = $current_epochseconds - $tmp_dateepochseconds;

       if ( $tmp_diff < $twenty_four_hours ) {
           $creationdate = " ";
           if ( $tmp_diff < 3600 ) {
               my $tmp_min = int($tmp_diff / 60); 
               if ( $tmp_min == 0 ) {
                   $creationdate = $tmp_diff . " secs ago";
               } elsif ( $tmp_min == 1 ) {
                   $creationdate = $tmp_min . " min ago";
               } else {
                   $creationdate = $tmp_min . " mins ago";
               }
           } else {
               my $tmp_hr = int($tmp_diff / 3600); 
               if ( $tmp_hr == 1 ) {
                   $creationdate = $tmp_hr . " hr ago";
               } else {
                   $creationdate = $tmp_hr . " hrs ago";
               }
           }
       }
    return $creationdate;
}

1;
