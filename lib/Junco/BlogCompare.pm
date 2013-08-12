package BlogCompare;

use strict;
use warnings;

use Algorithm::Diff;
use HTML::Entities;
use Junco::Format;
use Junco::BlogData;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");

sub compare_versions {
    my $q = new CGI;
    my $leftid  = $q->param("leftid");
    my $rightid = $q->param("rightid");
    if ( !$leftid or !$rightid ) {
        Page->report_error("user", "Invalid comparison.", "Can't compare with itself.");
    }

    my %compare = _get_compare_info($leftid, $rightid);
    if ( !%compare ) {
        Page->report_error("user", "Invalid comparison.", "Cannot access one more posts.");
    }
    
    my $t = Page->new("compare");
    $t->set_template_variable("leftversionid",  $leftid);
    $t->set_template_variable("rightversionid",  $rightid);
    $t->set_template_variable("title",        $compare{title});
    $t->set_template_variable("urltitle",     $compare{urltitle});
    $t->set_template_variable("parentid",     $compare{parentid});
    $t->set_template_variable("leftversion",  $compare{leftversion});
    $t->set_template_variable("rightversion", $compare{rightversion});
    $t->set_template_variable("leftdate",  $compare{leftdate});
    $t->set_template_variable("lefttime",  $compare{lefttime});
    $t->set_template_variable("rightdate", $compare{rightdate});
    $t->set_template_variable("righttime", $compare{righttime});

    my @loop_data = _compare_versions($compare{leftcontent}, $compare{rightcontent});
    
    $t->set_template_loop_data("compare_loop", \@loop_data);
    $t->display_page("$compare{title}: Comparing versions $compare{leftversion} and $compare{rightversion}");
}

sub _compare_versions {
    my $leftcontent  = shift;
    my $rightcontent = shift;

    my @loop_data = ();

    my @left  = split /[\n]/, $leftcontent;
    my @right = split /[\n]/, $rightcontent;

    # sdiff returns an array of arrays
    my @sdiffs = Algorithm::Diff::sdiff(\@left, \@right);

    # first element is the mod indicator.
    # second element contains a hunk of content from the or older version (left)
    # third element contains a hunk of content from the or newer version (right)
    # the mods are based upon how the right side (newer) compares to the left (older)

    # modification indicators
    #  'added'      => '+',
    #  'removed'    => '-',
    #  'unmodified' => 'u',
    #  'changed'    => 'c',

    foreach my $arref (@sdiffs) {
        my %hash = ();

        $hash{leftdiffclass}  = "unmodified";
        $hash{rightdiffclass} = "unmodified";

        if ( $arref->[0] eq '+' ) {
            $hash{rightdiffclass} = "added";
        } elsif ( $arref->[0] eq '-' ) {
            $hash{leftdiffclass}  = "removed";
        } elsif ( $arref->[0] eq 'c' ) {
            $hash{leftdiffclass}  = "changed";
            $hash{rightdiffclass} = "changed";
        }

        $hash{modindicator} = $arref->[0];
        
        $hash{left}       = encode_entities(StrNumUtils::trim_spaces($arref->[1]));
        $hash{right}      = encode_entities(StrNumUtils::trim_spaces($arref->[2]));

        $hash{left}  = "&nbsp;" if ( length($hash{left} ) < 1 );
        $hash{right} = "&nbsp;" if ( length($hash{right}) < 1 );

        push(@loop_data, \%hash);
    }

    return @loop_data;
}

sub _get_compare_info {
    my $leftid  = shift;
    my $rightid = shift;

    my $offset = Utils::get_time_offset();

    my %compare = ();

    my $left_authorid = 0;
    my $right_authorid = 0;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Web::report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql = "select parentid, title, authorid, markupcontent, version, ";
    $sql .= "date_format(date_add(date, interval $offset hour), '%b %d, %Y') as date, ";
    $sql .= "date_format(date_add(date, interval $offset hour), '%r') as time ";
    $sql .= "from $dbtable_content where id=$leftid"; 
    $db->execute($sql);
    Web::report_error("system", "(68) Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $compare{parentid}      = $db->getcol("parentid");
        $compare{title}         = $db->getcol("title");
        $left_authorid          = $db->getcol("authorid");
        $compare{urltitle}      = Format::clean_title($compare{title});
        $compare{leftcontent}   = $db->getcol("markupcontent");
        $compare{leftversion}   = $db->getcol("version");
        $compare{leftdate}      = $db->getcol("date");
        $compare{lefttime}      = lc($db->getcol("time"));
    }
    Web::report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $sql = "select authorid, markupcontent, version, "; 
    $sql .= "date_format(date_add(date, interval $offset hour), '%b %d, %Y') as date, ";
    $sql .= "date_format(date_add(date, interval $offset hour), '%r') as time ";
    $sql .= "from $dbtable_content where id=$rightid";
    $db->execute($sql);
    Web::report_error("system", "(69) Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $right_authorid          = $db->getcol("authorid");
        $compare{rightcontent}   = $db->getcol("markupcontent");
        $compare{rightversion}   = $db->getcol("version");
        $compare{rightdate}      = $db->getcol("date");
        $compare{righttime}      = lc($db->getcol("time"));
    }

    $db->disconnect;
    Web::report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    # currently, only one person can edit a blog post. 
    # maybe later, multi-authoring will be permitted.
    if ( $right_authorid != $left_authorid ) {
        %compare = ();
    } else {
        my $is_users_blog_post = BlogData::user_owns_blog_post($compare{parentid}, $right_authorid);
        if ( BlogData::is_top_level_post_private($compare{parentid}) and !$is_users_blog_post ) {
            %compare = ();
        } elsif ( Utils::get_power_command_on_off_setting_for("private", $compare{leftcontent}, 0) and !$is_users_blog_post ) {
            %compare = ();
        } elsif ( Utils::get_power_command_on_off_setting_for("private", $compare{rightcontent}, 0) and !$is_users_blog_post ) {
            %compare = ();
        }
    }
 
    return %compare;
}



1;
