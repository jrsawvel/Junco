package Search;

use strict;
use warnings;

use URI::Escape;
use Junco::Stream;
use Junco::RSS;
use Junco::Following;
use Junco::Ajax;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_tags       = Config::get_value_for("dbtable_tags");

sub display_search_form {
    my $t = Page->new("searchform");
    $t->display_page("Search form");
}

sub tag_search {
    my $tmp_hash = shift;  
    my %hash;
    $hash{search_string} = $tmp_hash->{one}; # tag name or multiple tag names with OR or AND

# testing
# $hash{search_string} = "blog_jr";

    $hash{search_type}   = "tag";
    $hash{page_num}      = 1; 
    $hash{doing_rss}     = 0;
    $hash{sortby_userid} = 0;

    if ( lc($tmp_hash->{two}) eq "rss" ) {
        $hash{doing_rss} =  1;
    } elsif ( StrNumUtils::is_numeric($tmp_hash->{two}) ) {
        $hash{page_num} = $tmp_hash->{two};
    } elsif ( Utils::valid_username($tmp_hash->{two}) ) {
        # valid_username checks for proper syntax for possible username
        my $sortby_userid = User::get_userid($tmp_hash->{two});
        if ( $sortby_userid == 0 ) {
            Page->report_error("user", "Invalid username.", "User '$tmp_hash->{two}' does not exist.");
        }
        $hash{sortby_username} = $tmp_hash->{two};
        $hash{sortby_userid} = $sortby_userid;

        # now check for page num or rss
        if ( lc($tmp_hash->{three}) eq "rss" ) {
            $hash{doing_rss} =  1;
        } elsif ( StrNumUtils::is_numeric($tmp_hash->{three}) ) {
            $hash{page_num} = $tmp_hash->{three};
        }
    }
    
    do_search(\%hash);
}

sub search {
    my $tmp_hash = shift;  

    my %hash;
    $hash{search_string} = $tmp_hash->{one};
    $hash{search_type}   = "search";
    $hash{page_num}      = 1; 
    $hash{doing_rss}     = 0;

    if ( lc($tmp_hash->{two}) eq "rss" ) {
        $hash{doing_rss} =  1;
    } elsif ( StrNumUtils::is_numeric($tmp_hash->{two}) ) {
        $hash{page_num} = $tmp_hash->{two};
    }

    do_search(\%hash);
}

sub do_search {
    my $tmp_hash = shift;  

    my $search_string = $tmp_hash->{search_string}; 
    my $search_type   = $tmp_hash->{search_type};
    my $formtype="";

    my $page_num = $tmp_hash->{page_num};

    my @loop_data = ();
    my $type = "";
    my @search_terms = ();

    # if search term not in query string, get it from the post request in search form.
    if ( !defined($search_string) ) {
        my $q = new CGI;
        $search_string = $q->param("keywords");

        if ( !defined($search_string) ) {
            Page->report_error("user", "(1) Missing data.", "Enter keyword(s) to search on.");
        }

        $formtype = $q->param("formtype");
# $formtype="ajax";
        
        $search_string = StrNumUtils::trim_spaces($search_string);
        if ( length($search_string) < 1 ) {
            Page->report_error("user", "(2) Missing data.", "Enter keyword(s) to search on.");
        }
        if ( ($search_string =~ m/[\s]+AND[\s]+/) and  $search_string =~ m/[\s]+OR[\s]+/ ) {
            Page->report_error("user", "Invalid search query: $search_string.", "Unable to process a mix of AND and OR.");
        }
    } else {
        # CGI.pm will deal with escaped blanks in query string that contain %20.
        # if the more friendly + signs are used for spaces in query string, deal with it here.
        $search_string =~ s/\+/ /g;
    }

    my $orig_search_string = $search_string;

    if ( $search_string =~ m/[\s]+AND[\s]+/ ) {
# 14mar2013       my @words = split(/[\s]+/, $search_string);
        my @words = split(/AND/, $search_string);
        foreach (@words) {
            push(@search_terms, StrNumUtils::trim_spaces($_)) if ( $_ ne "AND" );
        }
        $type = "all";
    } 
    elsif ( $search_string =~ m/[\s]+OR[\s]+/ ) {
#        my @words = split(/[\s]+/, $search_string);
        my @words = split(/OR/, $search_string);
        foreach (@words) {
            push(@search_terms, StrNumUtils::trim_spaces($_)) if ( $_ ne "OR" );
        }
        $type = "any";
    }    
    else {
        $type = "phrase";
        push(@search_terms, $search_string);
    }

    my $tag_str = "";
    if ( $search_type eq "tag" ) {
        my @st = ();
        foreach (@search_terms) {
# 9may2013            push(@st, "#" . Utils::trim_spaces($_));
            push(@st, "|" . StrNumUtils::trim_spaces($_) . "|");
        }
        @search_terms = @st;
        $tag_str = "Tag:";
    }


    my $searchurlstr = $search_string;
    $searchurlstr    =~ s/ /\+/g;
    $searchurlstr = uri_escape($searchurlstr);

    my $template_type = "stream";

    my $tmp_topshelfblog = 0;
    my $tmp_topshelfblog_owner;

    if ( ( $search_string =~ m/^blog_(.*)/i ) and ( @search_terms == 1 ) ) {
        $tmp_topshelfblog = 1;
        $template_type = "topshelfblog";
        $tmp_topshelfblog_owner = $1; 
    }
    
    my %values = Stream::_set_page_and_user_data("", $page_num, $search_type, $template_type); 
    $values{topshelfblog} = $tmp_topshelfblog;

    my %extra_values;

    if ( $tmp_topshelfblog ) {
        $extra_values{topshelfblogowner} = $tmp_topshelfblog_owner;
        $extra_values{topshelfbloghome} = 1; 
        $extra_values{blogdescription} = "nature, food, technology, media, sports, politics, etc.";
        $extra_values{blogauthorimage} = "http://mageemarsh.com/ek/magee-tower-3.JPG";
        $extra_values{blogbannerimage} = "http://mageemarsh.com/ek/lake-erie-fall-sunrise-a.jpg";
    }

    my $sql_where_str = _create_sql_where_str($type, \@search_terms, \%values, $tmp_hash->{sortby_userid}, $search_type);
    my $stream_data = Stream::_get_content($sql_where_str);

    if ( $tmp_hash->{doing_rss} ) {
        RSS::display_rss($stream_data, "Search results for $tag_str $search_string", "rss", "/$search_type/$searchurlstr");
    }

    # possible todo eventually return stream result in json format ???
    if ( $formtype eq "ajax" ) {
        Ajax::return_stream($stream_data, "Search results for $tag_str $search_string", "rss", "/$search_type/$searchurlstr");
    }

    my @posts = Stream::_prepare_stream_data(\%values, $stream_data);
    $values{searchstring} = $tag_str . $search_string;
    $values{searchurlstr} = $searchurlstr;
    $values{searchurlstr} = $searchurlstr . "/$tmp_hash->{sortby_username}" if $tmp_hash->{sortby_userid};

    # display follow/unfollow button when it's a sitewide search on a single tag. may implemente for user tags later.
    # $search_string contains tag name
    my $logged_in_userid = User::get_logged_in_userid();
    if ( $logged_in_userid > 0 and $search_type eq "tag" and $type eq "phrase" and $tmp_hash->{sortby_userid}==0 ) {
        $values{singletagsearch} = 1;
        $values{isalreadyfollowingtag} = Following::is_already_following("t", $search_string);
    }

    Stream::_display_stream(\%values, \@posts, \%extra_values);
}

sub show_tags_by_counts {
    my $tmp_hash = shift;
    show_tags($tmp_hash, "tagcount");
}

sub show_tags_by_top_counts {
    my $tmp_hash = shift;
    show_tags($tmp_hash, "tagcounttop");
}

sub show_tags {
    my $tmp_hash = shift;  
    my $order_by = shift;

    my $sortby_username = $tmp_hash->{one};
    my $showing_user = 0;
    my $sortby_userid = 0;
    if ( Utils::valid_username($sortby_username) ) {
        $showing_user = 1;
        $sortby_userid = User::get_userid($sortby_username);     
        if ( $sortby_userid == 0 ) {
            Page->report_error("user", "Invalid username.", "User '$sortby_username' does not exist.");
        }
    } 

    my $t;

    my @loop_data = _get_tags($showing_user, $sortby_userid, $sortby_username, $order_by);

    if ( $order_by eq "tagcounttop" ) {
        $t = Page->new("toptags");
    } else {
        $t = Page->new("tags");
    }

    $t->set_template_loop_data("tags_loop", \@loop_data);

    if ( $order_by ne "tagcounttop" ) {
        @loop_data = _get_tag_cloud($showing_user, $sortby_userid, $sortby_username);
        $t->set_template_loop_data("tag_cloud_loop", \@loop_data);

        if ( $order_by eq "tagcount" ) {
            $t->set_template_variable("tagdisplaytype", "tagscounts");
            $t->set_template_variable("tagdisplayname", "count");
            $t->set_template_variable("othertagdisplaytype", "tags");
            $t->set_template_variable("othertagdisplayname", "name");
        } else {
            $t->set_template_variable("tagdisplaytype", "tags");
            $t->set_template_variable("tagdisplayname", "name");
            $t->set_template_variable("othertagdisplaytype", "tagscounts");
            $t->set_template_variable("othertagdisplayname", "count");
        }
    }

    if ( $showing_user ) {
        $t->set_template_variable("usertags", $sortby_username ."'s "); 
        $t->set_template_variable("sortby_username", $sortby_username); 
        $t->display_page($sortby_username . "'s Tag List and Counts");
    } else {
        $t->display_page("Tag List and Counts");
    }
}

sub kdebug {
    my $str = shift;
    Page->report_error("user", "debug", $str);
}

sub _create_sql_where_str {
    my $type = shift; 
    my $search_terms = shift;
    my $hash_ref = shift;
    my $sortby_userid = shift;
    my $search_type = shift;

    my $search_column = "c.markupcontent";
    $search_column = "c.tags" if $search_type eq "tag";

    my $cgi_app = Config::get_value_for("cgi_app");

    my @loop_data;

    my $authorid_str = "c.authorid>0";

    if ( $sortby_userid ) {
        $authorid_str = "c.authorid=$sortby_userid";
    }

    my $search_status =  Config::get_value_for("search_status");
    my $sqlstr;
    $sqlstr .= " where ($authorid_str and c.parentid>=0 and c.type in ('m','b') and c.status in ($search_status) and c.authorid=u.id) and ";

    if ( $type eq "phrase" ) {
        my $keyword = pop @$search_terms;
        $keyword =~ s/'/''/g;
        $sqlstr .=  " $search_column like '%$keyword%' ";
    }
    elsif ( $type eq "all" ) {
        my $tmp = "";
        foreach my $keyword (@$search_terms) {
            $keyword =~ s/'/''/g;
             $tmp .=  " $search_column like '%$keyword%' AND ";
        }
        # remove the final 'AND '
        $tmp = substr($tmp, 0, length($tmp) - 4);
        $sqlstr .= $tmp;
    }
    elsif ( $type eq "any" ) {
        my $tmp = "";
        foreach my $keyword (@$search_terms) {
            $keyword =~ s/'/''/g;
             $tmp .=  " $search_column like '%$keyword%' OR ";
        }
        # remove the final 'OR '
        $tmp = substr($tmp, 0, length($tmp) - 3);
        # wrap the OR statements with parens to preserve the AND conditions for the entire sql in the WHERE clause.
        $sqlstr .= "($tmp)";
    }

    if ( $hash_ref->{topshelfblog} ) {
        $sqlstr .= " order by c.createddate desc limit $hash_ref->{max_entries_plus_one} offset $hash_ref->{page_offset} ";
    } else {
        $sqlstr .= " order by c.date desc limit $hash_ref->{max_entries_plus_one} offset $hash_ref->{page_offset} ";
    }

    return $sqlstr;
}

sub _get_tags {
    my $showing_user = shift;
    my $sortby_userid = shift;
    my $sortby_username = shift;
    my $order_by = shift;

    my $tag_function = "tag";

    my $where_str = "where status=" . Config::get_value_for("tags_status");
    if ( $showing_user ) {
        $where_str .= " and createdby=$sortby_userid ";
#        $tag_function = "usertag";
    }

    my $top_tag_count = Config::get_value_for("top_tag_count");

    my $order_by_str = "";
    if ( $order_by eq "tagcount" ) {
        $order_by_str = " order by tagcount desc";
    } elsif ( $order_by eq "tagcounttop" ) {
        $order_by_str = " order by tagcount desc limit $top_tag_count"; 
    }
 
    my $cgi_app = Config::get_value_for("cgi_app");

    my @loop_data;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql;
    $sql  = "select name, count(*) as tagcount from $dbtable_tags $where_str group by name $order_by_str";
    $db->execute($sql);
    Page->report_error("system", "(44) Error executing SQL", $db->errstr) if $db->err;

    while ( $db->fetchrow ) {
        my %hash;
        $hash{name}          = $db->getcol("name");
        $hash{count}         = $db->getcol("tagcount");
        $hash{cgi_app}       = $cgi_app;
        $hash{tagfunction}   = $tag_function;
        $hash{sortbyusername}= $sortby_username if $showing_user;
        push(@loop_data, \%hash);
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return @loop_data;
}

sub _get_tag_cloud {
    my $showing_user = shift;
    my $sortby_userid = shift;
    my $sortby_username = shift;

    my $tag_function = "tag";

    my $where_str = "where status=" . Config::get_value_for("tags_status");
    if ( $showing_user ) {
        $where_str = " where createdby=$sortby_userid ";
#        $tag_function = "usertag";
    }
 
    my @loop_data;

    my $cgi_app = Config::get_value_for("cgi_app");

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

# HAVING count > 5 ???

    my $sql  = "select name, count(*) from $dbtable_tags $where_str group by name";
    $db->execute($sql);
    Page->report_error("system", "(70) Error executing SQL", $db->errstr) if $db->err;

    my $max = 0;
    my $min = 100000;

    while ( $db->fetchrow ) {
        my %hash;
        $hash{name}          = $db->getcol("name");
        $hash{count}         = $db->getcol('count(*)');        
#        push(@loop_data, \%hash);
        if ( $hash{count} > $max ) {
            $max = $hash{count};
        } elsif ( $hash{count} < $min ) {
            $min = $hash{count};
        }
        $hash{cgi_app} = $cgi_app;
        $hash{tagfunction}   = $tag_function;
        $hash{sortbyusername}= $sortby_username if $showing_user;
        push(@loop_data, \%hash);
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    my $diff = $max - $min;
    my $dist = $diff / 3;

    my $len = @loop_data;
    for (my $i=0; $i<$len; $i++) {
     
        if ( $loop_data[$i]->{count} == $min ) {
            $loop_data[$i]->{class} = "smallestTag";
        } elsif ( $loop_data[$i]->{count} == $max ) {
            $loop_data[$i]->{class} = "largestTag";
        } elsif ( $loop_data[$i]->{count} > ($min + ($dist*2)) ) {
            $loop_data[$i]->{class} = "largeTag";
        } elsif ( $loop_data[$i]->{count} > ($min + $dist ) ) {
            $loop_data[$i]->{class} = "mediumTag";
        } else {
            $loop_data[$i]->{class} = "smallTag";
        }
     
    }

    return @loop_data;
}

1;
