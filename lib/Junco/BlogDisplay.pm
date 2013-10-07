package BlogDisplay;

use strict;
use warnings;

use Junco::Format;
use Junco::BlogData;
use Junco::Backlinks;
use Junco::BlogRelated;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");
my $dbtable_users      = Config::get_value_for("dbtable_users");

sub show_blog_post {
    my $tmp_hash = shift;  

    my $articleid = $tmp_hash->{one}; 

# testing
# $articleid = 20;

    my $canedit = 0;

    if ( !defined($articleid)  or !$articleid or $articleid !~ /^[0-9]+$/ ) {
        Page->report_error("user", "Invalid input", "Missing or invalid article id: $articleid.");
    }

    my %blog_post = _get_blog_post($articleid);

    Page->report_error("user", "Invalid article access.", "Data doesn't exist.") if ( !%blog_post );

    my $t = Page->new("blogpost");

    if ( $blog_post{redirectedpage} ) {
        $t->set_template_variable("redirectedpage", 1);
        $t->set_template_variable("originalid", $blog_post{originalid});
        $t->set_template_variable("originaltitle", $blog_post{originaltitle});
    } 

    # make include templates dynamic. a change in the template automatic takes affect at display time in every article using the template.
    $blog_post{blogpost} = BlogData::include_templates($blog_post{blogpost});

    $t->set_template_variable("authorname",    $blog_post{authorname});
    $t->set_template_variable("cgi_app",       $blog_post{cgi_app});
    $t->set_template_variable("articleid",     $blog_post{articleid});
    $t->set_template_variable("cleantitle",    $blog_post{cleantitle});
    $t->set_template_variable("urldate",       $blog_post{urldate});
    $t->set_template_variable("title",         $blog_post{title});
    $t->set_template_variable("blogpost",      $blog_post{blogpost});
    $t->set_template_variable("createddate",   $blog_post{createddate});
    $t->set_template_variable("createdtime",   $blog_post{createdtime});
    $t->set_template_variable("replycount",    $blog_post{replycount});

    my $logged_in_username = User::get_logged_in_username();
    my $logged_in_userid   = User::get_logged_in_userid();
    if ( $logged_in_userid > 0 and User::valid_user() and ($logged_in_username eq $blog_post{authorname})  ) {
        $t->set_template_variable("canedit", 1);
        $canedit = 1;
    }

    if ( $blog_post{updated} ) {
        $t->set_template_variable("updated", 1);
        $t->set_template_variable("modifieddate",   $blog_post{modifieddate});
        $t->set_template_variable("modifiedtime",   $blog_post{modifiedtime});
    }

    if ( $blog_post{importdate} ) {
        $t->set_template_variable("importdateexists", 1);
        $t->set_template_variable("importdate",   $blog_post{importdate});
    }

    if ( $blog_post{status} eq "v" ) {
        $t->set_template_variable("versionlinkarticleid", $blog_post{parentid});
        $t->set_template_variable("viewingoldversion", 1);
        $t->set_template_variable("versionnumber", $blog_post{version});
    } 

    if ( $blog_post{usingimageheader} ) {
        $t->set_template_variable("usingimageheader", 1);
        $t->set_template_variable("imageheaderurl", $blog_post{imageheaderurl});
    }

    if ( $blog_post{usinglargeimageheader} ) {
        $t->set_template_variable("usinglargeimageheader", 1);
        $t->set_template_variable("largeimageheaderurl", $blog_post{largeimageheaderurl});
    }

    $t->set_template_variable("wordcount", $blog_post{words});
    $t->set_template_variable("charcount", $blog_post{chars});
    $t->set_template_variable("readingtime", $blog_post{readingtime});

    my @loop_data = ();
    @loop_data = BlogRelated::_get_related_articles($articleid, $blog_post{tags});
    if ( @loop_data ) {
        $t->set_template_variable("relatedarticlesexist", 1);
        my $len = @loop_data;
        if ( $len > 5 ) {
            $t->set_template_variable("morerelatedarticles", 1);
            for (my $i=$len; $i>5; $i--) {
                pop(@loop_data);
            } 
        }
        $t->set_template_loop_data("relatedarticles_loop", \@loop_data);
    }

    if ( $blog_post{toc} ) {
        my @toc_loop = _create_table_of_contents($blog_post{blogpost});
        if ( @toc_loop ) {
            $t->set_template_variable("usingtoc", "1");
            $t->set_template_loop_data("toc_loop", \@toc_loop);
        }    
    }

    $t->set_template_variable("webmention", $blog_post{webmention});
    $t->set_template_variable("email_host", Config::get_value_for("email_host"));
    $t->set_template_variable("articlepage", 1);

    if ( Backlinks::backlinks_exist($articleid) ) {
        $t->set_template_variable("backlinks", 1);
    }

    my $article_url = "http://" . Config::get_value_for("email_host") . $blog_post{cgi_app} . "/blogpost/" . $blog_post{articleid} . "/" . $blog_post{urldate} . "/" . $blog_post{cleantitle};
    $t->set_template_variable("article_url", $article_url);

    _update_last_blog_post_viewed($articleid, $logged_in_userid);

    $t->display_page($blog_post{title} . " - by $blog_post{authorname} "); 
}

sub _create_table_of_contents {
    my $str = shift;

    my @headers = ();
    my @loop_data = ();

    if ( @headers = $str =~ m{<!-- header:([1-6]):(.*?) -->}igs ) {
        my $len = @headers;
        for (my $i=0; $i<$len; $i+=2 ) {
            my %hash = ();
            $hash{level}      = $headers[$i];
            $hash{toclink}    = $headers[$i+1];
            $hash{cleantitle} = Format::clean_title($headers[$i+1]);
            push(@loop_data, \%hash); 
        }
    }

    return @loop_data;    
}

sub _get_blog_post {
    my $articleid = shift;

    my $cgi_app = Config::get_value_for("cgi_app");

    my %hash = ();

    my $offset = Utils::get_time_offset();

    my $status_str = "c.status in (" . Config::get_value_for("get_blog_post_status") . ")";

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql = "select c.id, c.parentid, c.title, c.authorid, c.markupcontent, c.formattedcontent, c.hidereply, c.replycount, c.status, c.version, c.editreason, c.tags, c.contentdigest, c.date as dbdate, c.createddate as dbcreateddate, c.importdate, ";
    $sql .=      "date_format(date_add(c.date, interval $offset hour), '%b %d, %Y') as modifieddate, ";
    $sql .=      "date_format(date_add(c.date, interval $offset hour), '%r') as modifiedtime, ";
    $sql .=      "date_format(date_add(c.createddate, interval $offset hour), '%b %d, %Y') as createddate, ";
    $sql .=      "date_format(date_add(c.createddate, interval $offset hour), '%r') as createdtime, ";
    $sql .=      "date_format(date_add(c.date, interval $offset hour), '%d%b%Y') as urldate, "; 
    $sql .=      "u.username from $dbtable_content c, $dbtable_users u  ";
    $sql .=      "where c.id=$articleid and c.type='b' and $status_str and c.authorid=u.id";

    $db->execute($sql);
    Page->report_error("system", "Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $hash{articleid}        = $db->getcol("id");
        $hash{parentid}         = $db->getcol("parentid");
        $hash{title}            = $db->getcol("title");

        my $tmp_markup         = $db->getcol("markupcontent");
        if ( $tmp_markup =~ m/^@([0-9]+)\s$/m ) {
            $db->disconnect();
            my %tmp_hash = _get_blog_post($1);
            $tmp_hash{redirectedpage}     = 1;
            $tmp_hash{redirectedpageid}   = $1;
            $tmp_hash{originalid}         = $articleid;
            $tmp_hash{originaltitle}      = $hash{title};
            return %tmp_hash;
        } else {
            $hash{redirectedpage} = 0;
        }

        $hash{cleantitle}       = Format::clean_title($hash{title}); 
        $hash{blogpost}         = $db->getcol("formattedcontent");
        $hash{urldate}          = $db->getcol("urldate");
        $hash{status}           = $db->getcol("status");
        $hash{hidereply}        = $db->getcol("hidereply");
        $hash{replycount}       = $db->getcol("replycount");
        $hash{modifieddate}     = $db->getcol("modifieddate");
        $hash{modifiedtime}     = lc($db->getcol("modifiedtime"));
        $hash{createddate}      = $db->getcol("createddate");
        $hash{createdtime}      = lc($db->getcol("createdtime"));
        $hash{authorid}         = $db->getcol("authorid");
        $hash{authorname}       = $db->getcol("username");
        $hash{editreason}       = $db->getcol("editreason");
        $hash{tags}             = $db->getcol("tags");
        $hash{contentdigest}    = $db->getcol("contentdigest");
        $hash{dbdate}           = $db->getcol("dbdate");
        $hash{dbcreateddate}    = $db->getcol("dbcreateddate");
        $hash{importdate}       = $db->getcol("importdate");
        $hash{cgi_app}          = $cgi_app;

        $hash{version}             = $db->getcol("version");
        if ( $hash{version} > 1 or ($hash{dbdate} ne $hash{dbcreateddate}) ) {
            $hash{updated} = 1;
        } else {
            $hash{updated} = 0;
        }

        $hash{toc} = Utils::get_power_command_on_off_setting_for("toc", $tmp_markup, 1);

        $hash{webmention} = 0;
        if ( $tmp_markup =~ m|#blog_$hash{authorname}|ig ) {
            $hash{webmention} = Utils::get_power_command_on_off_setting_for("webmention", $tmp_markup, 1);
        } else {
            $hash{webmention} = Utils::get_power_command_on_off_setting_for("webmention", $tmp_markup, 0);
        }

        if ( $hash{status} eq 's' and !BlogData::user_owns_blog_post($hash{articleid}, $hash{authorid}) ) {
            %hash = ();
        }    

        if ( $tmp_markup =~ m|^imageheader[\s]*=[\s]*(.+)|im ) {
            $hash{usingimageheader} = 1;
            $hash{imageheaderurl}   = $1;
        }

        if ( $tmp_markup =~ m|^largeimageheader[\s]*=[\s]*(.+)|im ) {
            $hash{usinglargeimageheader} = 1;
            $hash{largeimageheaderurl}   = $1;
        }

        my $tmp_post = StrNumUtils::remove_html($hash{blogpost});
        $hash{chars} = length($tmp_post);
        $hash{words} = scalar(split(/\s+/s, $tmp_post));
        $hash{readingtime} = 0;
        $hash{readingtime} = int($hash{words} / 180) if $hash{words} >= 180;

        if ( $hash{status} eq 'v' and !BlogData::user_owns_blog_post($hash{articleid}, $hash{authorid}) ) {
            if ( Utils::get_power_command_on_off_setting_for("private", $tmp_markup, 0) ) {
                %hash = ();
            } elsif ( _is_top_level_post_private($hash{parentid}) ) {
                %hash = ();
            }
        }
        
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect();
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return %hash;
}

sub  _is_top_level_post_private {
    my $articleid = shift;

    my $return_status = 1;  # default to private
 
    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql = "select markupcontent from $dbtable_content where id=$articleid"; 

    $db->execute($sql);
    Page->report_error("system", "Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        my $tmp_markup         = $db->getcol("markupcontent");
        if ( !Utils::get_power_command_on_off_setting_for("private", $tmp_markup, 0) ) {
            $return_status = 0;
        }
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect();
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $return_status;
}

sub _update_last_blog_post_viewed {
    my $articleid = shift;
    my $userid    = shift;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql = "update $dbtable_users set lastblogpostviewed = $articleid where id = $userid";
    $db->execute($sql);
    Page->report_error("system", "Error executing SQL", $db->errstr) if $db->err;

    $db->disconnect();
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;
}


1;
