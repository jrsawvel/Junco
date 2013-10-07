package Junco::Dispatch;
use strict;
use Junco::Modules;

my %cgi_params = Function::get_cgi_params_from_path_info("function", "one", "two", "three", "four");

# my $function = $cgi_params{function};
# if ( defined $function ) {
# Page->report_error("user", "debug", "function exists [$function]");
# } elsif ( !defined $function ) {
# Page->report_error("user", "debug", "function does not exist [$function]");
# }

my $dispatch_for = {
    blogarchives       =>   sub { return \&do_sub(       "Archives",       "show_archives"            ) },
    backlinks          =>   sub { return \&do_sub(      "Backlinks",       "show_backlinks"           ) },
    addarticle         =>   sub { return \&do_sub(        "BlogAdd",       "add_blog_post"            ) },
    blogpostform       =>   sub { return \&do_sub(        "BlogAdd",       "show_blog_post_form"      ) },
    textileeditor      =>   sub { return \&do_sub(        "BlogAdd",       "show_textile_editor_form" ) },
    splitscreen        =>   sub { return \&do_sub(        "BlogAdd",       "show_splitscreen_form"    ) },
    b                  =>   sub { return \&do_sub(    "BlogDisplay",       "show_blog_post"           ) },
    blogpost           =>   sub { return \&do_sub(    "BlogDisplay",       "show_blog_post"           ) },
    edit               =>   sub { return \&do_sub(       "BlogEdit",       "edit_blog_post"           ) },
    splitscreenedit    =>   sub { return \&do_sub(       "BlogEdit",       "splitscreen_edit"         ) },
    textileeditoredit  =>   sub { return \&do_sub(       "BlogEdit",       "textile_editor_edit"      ) },
    deleteblog         =>   sub { return \&do_sub(     "BlogDelete",       "delete_blog"              ) },
    undeleteblog       =>   sub { return \&do_sub(   "BlogUndelete",       "undelete_blog"            ) },
    updateblog         =>   sub { return \&do_sub(     "BlogUpdate",       "update_blog_post"         ) },
    versions           =>   sub { return \&do_sub(   "BlogVersions",       "show_version_list"        ) },
    compare            =>   sub { return \&do_sub(    "BlogCompare",       "compare_versions"         ) },
    source             =>   sub { return \&do_sub(     "BlogSource",       "show_blog_source"         ) },
    relatedblogposts   =>   sub { return \&do_sub(    "BlogRelated",       "show_related_blog_posts"  ) },
    follow             =>   sub { return \&do_sub(      "Following",       "follow_user"              ) },
    followtag          =>   sub { return \&do_sub(      "Following",       "follow_tag"               ) },
    following          =>   sub { return \&do_sub(      "Following",       "show_following"           ) },
#   followedby         =>   sub { return \&do_sub(      "Following",       "show_followed_by"         ) },
    unfollow           =>   sub { return \&do_sub(      "Following",       "unfollow_user"            ) },
    unfollowtag        =>   sub { return \&do_sub(      "Following",       "unfollow_tag"             ) },
    followingstream    =>   sub { return \&do_sub(      "Following",       "show_following_stream"    ) },
    showerror          =>   sub { return \&do_sub(       "Function",       "do_invalid_function"      ) },
    loginform          =>   sub { return \&do_sub(          "Login",       "show_login_form"          ) },
    logout             =>   sub { return \&do_sub(         "Logout",       "logout"                   ) },
    login              =>   sub { return \&do_sub(          "Login",       "login"                    ) },
    addmicroblog       =>   sub { return \&do_sub(      "Microblog",       "add_microblog"            ) },
    deletemicroblog    =>   sub { return \&do_sub(      "Microblog",       "delete_microblog"         ) },
    undeletemicroblog  =>   sub { return \&do_sub(      "Microblog",       "undelete_microblog"       ) },
    m                  =>   sub { return \&do_sub(      "Microblog",       "show_microblog_post"      ) },
    microblogpost      =>   sub { return \&do_sub(      "Microblog",       "show_microblog_post"      ) },
    changepassword     =>   sub { return \&do_sub(       "Password",       "change_password"          ) },
    newpassword        =>   sub { return \&do_sub(       "Password",       "create_new_password"      ) },
    user               =>   sub { return \&do_sub(        "Profile",       "show_user"                ) },
    rss                =>   sub { return \&do_sub(            "RSS",       "get_rss"                  ) },
    search             =>   sub { return \&do_sub(         "Search",       "search"                   ) }, 
    searchform         =>   sub { return \&do_sub(         "Search",       "display_search_form"      ) }, 
    tag                =>   sub { return \&do_sub(         "Search",       "tag_search"               ) },
    tags               =>   sub { return \&do_sub(         "Search",       "show_tags"                ) },
    tagscounts         =>   sub { return \&do_sub(         "Search",       "show_tags_by_counts"      ) },
    tagscountstop      =>   sub { return \&do_sub(         "Search",       "show_tags_by_top_counts"  ) },
    blog               =>   sub { return \&do_sub(         "Stream",       "show_blog_stream"         ) },
    stream             =>   sub { return \&do_sub(         "Stream",       "show_entire_stream"       ) },
    microblog          =>   sub { return \&do_sub(         "Stream",       "show_microblog_stream"    ) },
    blogarchivepage    =>   sub { return \&do_sub(         "Stream",       "show_archives_month_year" ) },
    private            =>   sub { return \&do_sub(         "Stream",       "show_private_blog_stream" ) },
    draft              =>   sub { return \&do_sub(         "Stream",       "show_draft_blog_stream"   ) },
    signup             =>   sub { return \&do_sub(         "Signup",       "show_signup_form"         ) },
    createnewuser      =>   sub { return \&do_sub(         "Signup",       "create_new_user"          ) },
    acct               =>   sub { return \&do_sub(         "Signup",       "activate_account"         ) },
    settings           =>   sub { return \&do_sub(   "UserSettings",       "show_user_settings_form"  ) },
    customizeuser      =>   sub { return \&do_sub(   "UserSettings",       "customize_user"           ) },
    savedchanges       =>   sub { return \&do_sub(   "UserSettings",       "show_user_changes"        ) },
    reply              =>   sub { return \&do_sub(          "Reply",       "show_reply_form"          ) },
    addreply           =>   sub { return \&do_sub(          "Reply",       "add_reply"                ) },
    replies            =>   sub { return \&do_sub(          "Reply",       "show_replies"             ) },
    repliesstream      =>   sub { return \&do_sub(          "Reply",       "show_replies_stream"      ) },
    rest               =>   sub { return \&do_sub(           "Rest",       "do_rest"                  ) },
    post               =>   sub { return \&do_sub(    "ShowContent",       "show_content"             ) },
    p                  =>   sub { return \&do_sub(    "ShowContent",       "show_content"             ) },
    textsize           =>   sub { return \&do_sub(       "TextSize",       "set_text_size"            ) },
    theme              =>   sub { return \&do_sub(          "Theme",       "set_theme"                ) },
    webmention         =>   sub { return \&do_sub(     "WebMention",       "post_webmention"          ) },
};

sub execute {
    my $function = $cgi_params{function};

    $dispatch_for->{stream}->() if !defined $function;
    $dispatch_for->{showerror}->($function) unless exists $dispatch_for->{$function};
    defined $dispatch_for->{$function}->();
}

sub do_sub {
    my $module = shift;
    my $subroutine = shift;
    eval "require Junco::$module" or do Page->report_error("user", "Runtime Error (1):", $@);
    my %hash = %cgi_params;
    my $coderef = "$module\:\:$subroutine(\\%hash)"  or do Page->report_error("user", "Runtime Error (2):", $@);
    eval "{ &$coderef };";
}

1;
