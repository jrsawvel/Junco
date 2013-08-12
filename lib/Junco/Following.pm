package Following;

use strict;

use Junco::Stream;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_following = Config::get_value_for("dbtable_following");
my $dbtable_users     = Config::get_value_for("dbtable_users");

sub follow_user {
    my $tmp_hash = shift;  
    my $username_to_follow = $tmp_hash->{one}; 
    $username_to_follow = StrNumUtils::trim_spaces($username_to_follow);
    if ( !$username_to_follow or !defined($username_to_follow) ) {
        Page->report_error("user", "Invalid input", "Missing username.");
    }
    if ( !User::get_userid($username_to_follow) ) {
        Page->report_error("user", "Invalid input", "Username does not exist.");
    }
    User::user_allowed_to_function();
    my $q = new CGI;
    _follow('u', User::get_logged_in_userid(), User::get_userid($username_to_follow));
    print $q->redirect( -url => Utils::get_http_referer());
}

sub follow_tag {
    my $tmp_hash = shift;  
    my $tag_to_follow = $tmp_hash->{one}; 
    $tag_to_follow = StrNumUtils::trim_spaces($tag_to_follow);
    if ( !$tag_to_follow or !defined($tag_to_follow) ) {
        Page->report_error("user", "Invalid input", "Missing tag.");
    }
    User::user_allowed_to_function();
    my $q = new CGI;
    _follow('t', User::get_logged_in_userid(), $tag_to_follow);
    print $q->redirect( -url => Utils::get_http_referer());
}

sub show_following_stream {
    my $tmp_hash = shift;  

    my $type = $tmp_hash->{one};    

    if ( $type eq "users" ) {
        show_following_stream_users($tmp_hash);
    } elsif ( $type eq "tags" ) {
        show_following_stream_tags($tmp_hash);
    } else {
        show_following_stream_users($tmp_hash); # default to showing users
        # Web::report_error("user", "Invalid action.", "Following type not permitted.");
    }
}

sub show_following_stream_users {
    my $tmp_hash = shift;  

    User::user_allowed_to_function();

    my $logged_in_username = User::get_logged_in_username();
    my $stream_username = $tmp_hash->{two};
    if ( !$stream_username and !$logged_in_username ) {
        my $t = Page->new("notloggedin");
        $t->display_page("Not Logged-in");
        exit;
    } 

    my $page_num = 1;

    if ( $tmp_hash->{three} ) {
        $page_num = $tmp_hash->{three};
    }

    my %values           = Stream::_set_page_and_user_data("All", $page_num, "followingstream", "stream"); 
    my $following_authorid_str = create_following_authorid_string();
    my $sql_where_str = " where c.authorid in ($following_authorid_str) and c.parentid>=0 and $values{type} and $values{status} and c.authorid=u.id ";
    $sql_where_str    .= " order by c.date desc limit $values{max_entries_plus_one} offset $values{page_offset} ";
    my $stream_data      = Stream::_get_content($sql_where_str);
    my @posts            = Stream::_prepare_stream_data(\%values, $stream_data);
    $values{followingtype} = "users";
    $values{otherfollowingtype} = "tags";
    Stream::_display_stream(\%values, \@posts);
}

sub show_following_stream_tags {
    my $tmp_hash = shift;  

    User::user_allowed_to_function();

    my $logged_in_username = User::get_logged_in_username();
    my $stream_username = $tmp_hash->{two};
    if ( !$stream_username and !$logged_in_username ) {
        my $t = Page->new("notloggedin");
        $t->display_page("Not Logged-in");
        exit;
    } 

    my $page_num = 1;

    if ( $tmp_hash->{three} ) {
        $page_num = $tmp_hash->{three};
    }

    my %values           = Stream::_set_page_and_user_data("All", $page_num, "followingstream", "stream"); 
    my $following_tags_str = create_following_tags_string();
#####    Web::report_error("user", "You're not following any tags.", "") if !$following_tags_str;
    my $sql_where_str = " where ($following_tags_str) and c.parentid>=0 and $values{type} and $values{status} and c.authorid=u.id ";
    $sql_where_str    .= " order by c.date desc limit $values{max_entries_plus_one} offset $values{page_offset} ";
    my $stream_data      = Stream::_get_content($sql_where_str);
    my @posts            = Stream::_prepare_stream_data(\%values, $stream_data);
    $values{followingtype} = "tags";
    $values{otherfollowingtype} = "users";
    Stream::_display_stream(\%values, \@posts);
}

sub unfollow_user {
    my $tmp_hash = shift;  
    my $username_to_unfollow = $tmp_hash->{one}; 
    User::user_allowed_to_function();
    my $q = new CGI;
    _unfollow('u', User::get_logged_in_userid(), User::get_userid($username_to_unfollow));
    print $q->redirect( -url => Utils::get_http_referer());
}

sub unfollow_tag {
    my $tmp_hash = shift;  
    my $tag_to_unfollow = $tmp_hash->{one}; 
    User::user_allowed_to_function();
    my $q = new CGI;
    _unfollow('t', User::get_logged_in_userid(), $tag_to_unfollow);
    print $q->redirect( -url => Utils::get_http_referer());
}

# show list of users the logged-in user is following via the logged-in user's profile page 
# or the list of tags the user is following
sub show_following {
    my $tmp_hash = shift;  

    my $type = $tmp_hash->{one};

    User::user_allowed_to_function();

    my $userid = User::get_logged_in_userid();

    my $follows;

    my $t = Page->new($type . "following");

    $follows = _get_items_following($type, $userid);

    if ( exists($follows->[0]->{item}) ) {
           $t->set_template_loop_data($type . "following_loop", $follows);
    }

    $t->display_page("ucfirst($type)that You Are Following");
}

sub show_followed_by {
    User::user_allowed_to_function();

    my $userid = User::get_logged_in_userid();

    my $followed_by;

    my $t = Page->new("followedbyusers");

    $followed_by = _get_followed_by_users($userid);

    if ( exists($followed_by->[0]->{username}) ) {
           $t->set_template_loop_data("followedbyusers_loop", $followed_by);
    }

    $t->display_page("Users Who are Following You");
}

sub is_already_following {
    my $type = shift;
    my $item = shift;

    my $already_following = 0;

    my $sql;

    my $logged_in_userid = User::get_logged_in_userid();
    return $already_following if !$logged_in_userid; 

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    if ( $type eq "u" ) {
        my $profile_userid   = User::get_userid($item);
        $sql = "select id from $dbtable_following where type='u' and followinguserid=$profile_userid and userid=$logged_in_userid"; 
    } elsif ( $type eq "t" ) {
        $item = $db->quote($item);
        $sql = "select id from $dbtable_following where type='t' and followingstring=$item and userid=$logged_in_userid"; 
    }

    $db->execute($sql);
    Page->report_error("system", "(F61a) Error executing SQL", $db->errstr) if $db->err;
   
    if ( $db->fetchrow ) {
        $already_following = 1;      
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect();
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $already_following;
}

sub _follow {
    my $type   = shift;
    my $userid = shift;
    my $item   = shift;

    my $sql;
    my $item_string = "";
    my $dbcolumn = "";

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    if ( $type eq 'u' ) {
        $sql = "select id from $dbtable_following where type='u' and userid=$userid and followinguserid=$item";
        $item_string = "user";
        $dbcolumn = "followinguserid";        
    } elsif ( $type eq 't' ) {
        $item = $db->quote($item);
        $sql = "select id from $dbtable_following where type='t' and userid=$userid and followingstring=$item";
        $item_string = "tag";
        $dbcolumn = "followingstring";        
    } else {
        Page->report_error("user", "Invalid action performed.", "Missing type of item to follow.");
    }
    $db->execute($sql);
    Page->report_error("system", "(40-a) Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $db->disconnect;
        Page->report_error("user", "Invalid action performed.", "You are already following this $item_string.");
    }

    my $datetime = Utils::create_datetime_stamp();
    my $datetime = $db->quote($datetime);

    $sql =  "insert into $dbtable_following (type, userid, $dbcolumn, createddate) ";
    $sql .= " values ('$type', $userid, $item, $datetime)";
    $db->execute($sql);
    Page->report_error("system", "(40-c) Error executing SQL", $db->errstr) if $db->err;
     
    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;
}

sub _unfollow {
    my $type   = shift;
    my $userid = shift;
    my $item   = shift;

    my $sql;
    my $item_string = "";
    my $dbcolumn = "";

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    if ( $type eq 'u' ) {
        $sql = "select id from $dbtable_following where type='u' and userid=$userid and followinguserid=$item";
        $item_string = "user";
        $dbcolumn = "followinguserid";        
    } elsif ( $type eq 't' ) {
        $item = $db->quote($item);
        $sql = "select id from $dbtable_following where type='t' and userid=$userid and followingstring=$item";
        $item_string = "tag";
        $dbcolumn = "followingstring";        
    } else {
        Page->report_error("user", "Invalid action performed.", "Missing type of item to follow.");
    }
    $db->execute($sql);
    Page->report_error("system", "(40-a) Error executing SQL", $db->errstr) if $db->err;

    if ( !$db->fetchrow ) {
        $db->disconnect;
        Page->report_error("user", "Invalid action performed.", "You are not following this $item_string.");
    }

    my $datetime = Utils::create_datetime_stamp();
    my $datetime = $db->quote($datetime);

    $sql =  "delete from $dbtable_following where type='$type' and userid=$userid and $dbcolumn=$item";

    $db->execute($sql);
    Page->report_error("system", "(40-c) Error executing SQL", $db->errstr) if $db->err;
     
    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;
}

sub _get_items_following {
    my $type = shift;
    my $userid = shift;

    my @loop_data;

    my $cgi_app = Config::get_value_for("cgi_app");

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql;

    if ( $type eq "users" ) {
        $sql = "select u.username as item from $dbtable_following f, $dbtable_users u where f.type='u' and f.userid=$userid and f.followinguserid=u.id order by u.username asc";
    } elsif ( $type eq "tags" ) {
        $sql = "select followingstring as item from $dbtable_following where type='t' and userid=$userid order by followingstring asc";
    } else {
        Page->report_error("user", "Invalid action.", "$type not available.");
    }

    $db->execute($sql);
    Page->report_error("system", "(F61b) Error executing SQL", $db->errstr) if $db->err;

    while ( $db->fetchrow ) {
        my %hash = ();
        $hash{item}    = $db->getcol("item");
        $hash{cgi_app}     = $cgi_app;
        push(@loop_data, \%hash);
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect();
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return \@loop_data;
}

sub _get_followed_by_users {
    my $userid = shift;

    my @loop_data;

    my $cgi_app = Config::get_value_for("cgi_app");

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql;

    $sql = "select u.username from $dbtable_following f, $dbtable_users u where f.type='u' and f.followinguserid=$userid and f.userid=u.id order by f.createddate desc";

    $db->execute($sql);
    Page->report_error("system", "(F61c) Error executing SQL", $db->errstr) if $db->err;

    while ( $db->fetchrow ) {
        my %hash = ();
        $hash{username}    = $db->getcol("username");
        $hash{cgi_app}     = $cgi_app;
        push(@loop_data, \%hash);
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect();
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return \@loop_data;
}

sub get_following_count {
    my $type = shift;

    User::user_allowed_to_function();

    my $logged_in_userid = User::get_logged_in_userid();

    my $following_count =0;

    return $following_count if !$logged_in_userid; 

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql;

    $sql = "select count(*) as followingcount from $dbtable_following where type='$type' and userid=$logged_in_userid"; 

    $db->execute($sql);
    Page->report_error("system", "(F61d) Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $following_count = $db->getcol("followingcount");
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect();
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $following_count;
}

sub get_followed_by_count {
    User::user_allowed_to_function();

    my $logged_in_userid = User::get_logged_in_userid();

    my $followed_by_count =0;

    return $followed_by_count if !$logged_in_userid; 

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql;
    $sql = "select count(*) as followedbycount from $dbtable_following where type='u' and followinguserid=$logged_in_userid"; 

    $db->execute($sql);
    Page->report_error("system", "(F61e) Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $followed_by_count = $db->getcol("followedbycount");
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect();
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $followed_by_count;
}

sub kdebug {
    my $str = shift;
    Page->report_error("user", "debug", $str);
}

sub create_following_authorid_string {

    my $userid = User::get_logged_in_userid();

    my $idstr = "";

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql;

    $sql = "select followinguserid from $dbtable_following where type='u' and userid=$userid order by followinguserid asc";

    $db->execute($sql);
    Page->report_error("system", "(F61f) Error executing SQL", $db->errstr) if $db->err;

    while ( $db->fetchrow ) {
        my $following = $db->getcol("followinguserid");
        $idstr .= "$following,";
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect();
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    $idstr = $1 if ( $idstr =~ /(.*),$/ );        

    if ( !$idstr ) {
        $idstr = "0";
    }

    return $idstr;
}

sub create_following_tags_string {

    my $userid = User::get_logged_in_userid();

    my $tag_str = "";

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql;

    $sql = "select followingstring from $dbtable_following where type='t' and userid=$userid order by followingstring asc";

    $db->execute($sql);
    Page->report_error("system", "(F61f) Error executing SQL", $db->errstr) if $db->err;

    while ( $db->fetchrow ) {
        my $following = $db->getcol("followingstring");
        $following = $db->quote("%|$following|%");
        $tag_str .= " tags like $following or";
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect();
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    $tag_str = $1 if ( $tag_str =~ /(.*)or$/ );        

    if ( !$tag_str ) {
        return 0;
    } else {
        $tag_str = "( " . $tag_str . " )";
    }

    return $tag_str;
}

1;

