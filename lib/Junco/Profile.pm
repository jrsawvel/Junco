package Profile;
use strict;

use Junco::Include;
use Junco::Following;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_users      = Config::get_value_for("dbtable_users");
my $dbtable_content    = Config::get_value_for("dbtable_content");

sub show_user {
    my $tmp_hash = shift;

    my $username_for_profile = $tmp_hash->{one};

# testing
# $username_for_profile = "doesnotexist";
# $username_for_profile = "j.r.";

    $username_for_profile = StrNumUtils::trim_spaces($username_for_profile);
    
    if ( !defined($username_for_profile) ) {
        Page->report_error("user", "Invalid input", "Missing username.");
    } elsif ( !Utils::valid_username($username_for_profile) ) {
        Page->report_error("user", "Invalid input", "Missing username.");
    }

    my %user_data = _get_user_profile($username_for_profile);

    my $deleted_user = 0;
    if ( $user_data{status} eq "d" ) {
        $deleted_user = 1;
    }

    my $t = Page->new("showuser");

    my $logged_in_username = User::get_logged_in_username();

    my $logged_in_user_viewing_own_profile = 0; 
    if ( $logged_in_username and ( lc($logged_in_username) eq lc($username_for_profile) )  ) {
        $t->set_template_variable("ownerloggedin", "1"); 
        $logged_in_user_viewing_own_profile = 1; 
    }

    $t->set_template_variable("profileusername"     , $user_data{profileusername});
    $t->set_template_variable("creationdate"        , $user_data{creationdate});
    $t->set_template_variable("blogcount"    , $user_data{blogcount});
    $t->set_template_variable("microblogcount"  , $user_data{microblogcount});
    $t->set_template_variable("deleteduser"               , $deleted_user);
    $user_data{descformat} =  Include::include_templates($user_data{descformat});
    $t->set_template_variable("descformat"         , $user_data{descformat});
    $t->set_template_variable("isalreadyfollowing", Following::is_already_following("u", $user_data{profileusername}));

    if ( $logged_in_user_viewing_own_profile ) {
        $t->set_template_variable("followingcount",       Following::get_following_count("u"));
        $t->set_template_variable("followingtagcount",    Following::get_following_count("t"));
### leave disabled Web::set_template_variable("beingfollowedbycount", Following::get_followed_by_count());
        $t->set_template_variable("privateblogcount",     BlogData::get_blog_post_count("s"));
        $t->set_template_variable("draftblogcount",       BlogData::get_blog_post_count("p"));
    }

    $t->display_page("Show User $user_data{profileusername}");
}

sub _get_user_profile {
    my $username = shift;

    my %hash;

    my $offset = Utils::get_time_offset();

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $username = $db->quote($username);

    my $user_profile_status = Config::get_value_for("user_profile_status");

    my $sql = "select id, username, date_format(date_add(createddate, interval $offset hour), '%b %d, %Y') as cd, email, status, descformat from $dbtable_users where username=$username and (status in ($user_profile_status))";

    $db->execute($sql);
    Page->report_error("system", "(15) Error executing SQL", $db->errstr) if $db->err;

    my $tmp;

    if ( $db->fetchrow ) {
        $hash{userid}                      = $db->getcol("id");
        $hash{profileusername}             = $db->getcol("username");
        $hash{creationdate}                = $db->getcol("cd");
        $hash{email}                       = $db->getcol("email");
        $hash{status}                      = $db->getcol("status");
        $hash{descformat}                  = $db->getcol("descformat");
    } else {
        Page->report_error("user", "Invalid username.", "User '$username' does not exist.");
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    $hash{blogcount}      = _get_user_post_count($hash{userid}, "b");
    $hash{microblogcount} = _get_user_post_count($hash{userid}, "m");

    return %hash;
}

sub _get_user_post_count {
    my $userid = shift;
    my $type = shift;

    my $postcount = 0;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Web::report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql = "select count(*) as postcount from $dbtable_content where authorid=$userid and type='$type' and status='o'"; 
    $db->execute($sql);
    Web::report_error("system", "(21) Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $postcount = $db->getcol("postcount");
    }
    Web::report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Web::report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $postcount;
}

1;

