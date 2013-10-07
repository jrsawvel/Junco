package WebMention;

use strict;
use warnings;

use LWP::Simple;
use HTML::Entities;
use HTML::TokeParser;
use Junco::Format;
use Junco::Reply;
use Data::Dumper;

use CGI qw(:standard);

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");

my $RETURN_JSON = 0;

sub post_webmention {
    my $q = new CGI;

    my $err_msg;
    undef $err_msg;

    my $json = 0;

    my $posttype = $q->param("posttype");
    if ( $posttype ne "manual" ) {
        $RETURN_JSON = 1;
    }

    # url to the post (webmention) that is a response to the target post
    my $source_url = $q->param("source");
    $source_url = StrNumUtils::trim_spaces($source_url);
    if ( !defined($source_url) || length($source_url) < 1 )  { 
        report_error("source_not_found", "The source URI does not exist.");
    } 

    # target url of the blog post that's being commented on by a webmention (source url)
    my $target_url = $q->param("target");
    $target_url = StrNumUtils::trim_spaces($target_url);
    if ( !defined($target_url) || length($target_url) < 1 )  { 
        report_error("target_not_found", "The target URI does not exist.");
    } 

    my $target_id = 0;
    my %params = parse_target_url($target_url);
    if ( exists($params{blogpost}) ) {
        $target_id = $params{blogpost};
    }
    elsif ( exists($params{b}) ) {
        $target_id = $params{b};
    }
    elsif ( exists($params{microblogpost}) ) {
        $target_id = $params{microblogpost};
    }
    elsif ( exists($params{m}) ) {
        $target_id = $params{m};
    }

    if ( !StrNumUtils::is_numeric($target_id) || $target_id < 1 ) {
        report_error("target_not_found", "The target URI does not exist because target post id is not numeric.");
    }

    my $short_target_url = "http://" . Config::get_value_for("email_host") . Config::get_value_for("cgi_app") . "/b/" . $target_id;

    my $source_content = get($source_url);    
    # search source_content for the target_url
    if ( ($source_content !~ m|$target_url[\D]|) && ($source_content !~ m|$short_target_url[\D]|) ) {
        report_error("no_link_found", "The source URI does not contain a link to the target URI.");
    } 

    my $p = HTML::TokeParser->new(\$source_content);

    # my $d = $p->get_tag('meta');
    # $d->[1]{name});  == author
    # $d->[1]{content}); == barney
    # Data Dumper: VAR1 = [ 'meta', { '/' => '/', 'content' => 'barney', 'name' => 'author' }, [ 'name', 'content', '/' ], '' ];

    my $source_author = "";

    while ( my $meta_tag = $p->get_tag('meta') ) {
        if ( $meta_tag->[1]{name} eq "author" ) {
            $source_author = $meta_tag->[1]{content}; 
        }
    }

    my $p2 = HTML::TokeParser->new(\$source_content);
    my $econtent = "";
    while ( my $div_tag = $p2->get_tag('div','section') ) {
        if ( $div_tag->[1]{class} =~ m|e-content|i ) {
            $econtent  = $p2->get_text('/div','/section');
            $econtent = StrNumUtils::trim_spaces($econtent);
        }
    }

    if ( !target_post_exists($target_id) ) {
        report_error("target_not_supported", "The specified target URI is not a WebMention-enabled resource because target post does not exist.");
    }

    if ( source_url_exists_for_target($source_url, $target_id) ) {
        report_error("already_registered", "The specified WebMention has already been registered.");
    }

    add_webmention($target_id, $source_url, $source_author, $econtent, $posttype);

#    Page->report_error("user", "debug", "source_url=$source_url <br /> target_id=$target_id <br /> target_url=$target_url <br /><br /> $source_content");

}

sub add_webmention {
    my $replytoid = shift;
    my $source_url = shift;
    my $source_author = shift;
    my $econtent = shift;
    my $posttype = shift;

    my $domain = $source_url;
    $domain =~ s!^https?://(?:www\.)?!!i;
    $domain =~ s!/.*!!;
    $domain =~ s/[\?\#\:].*//;

    if ( !$econtent or length($econtent) < 1  ) {
        $econtent = $source_url;
    }

    my $extended_text = 0;
    if ( length($econtent) > 300 ) {
        $econtent = substr $econtent, 0, 300;
        $econtent .= " ... ";
        $extended_text = 1;
    }

    my $q = new CGI;

    my $logged_in_username = "webmention";
    my $logged_in_userid   = User::get_userid("webmention");

    my %replytoinfo = Reply::get_reply_to_info($replytoid);
    my $markupcontent = $econtent;

    if ( source_content_exists_for_target($markupcontent, $replytoid) ) {
        report_error("already_registered", "The specified WebMention has already been registered.");
    } 

    my $title = $source_url;
    my $formattedcontent = HTML::Entities::encode($markupcontent, '<>');
    $formattedcontent .= " <a  rel=\"nofollow\"  href=\"$source_url\">more &gt;&gt;</a>" if $extended_text;
    $formattedcontent = StrNumUtils::url_to_link($formattedcontent);
    $formattedcontent = Format::check_for_external_links($formattedcontent);

    if ( length($source_author) > 0 )  { 
        $formattedcontent = " <small>(by <a rel=\"nofollow\" href=\"$source_url\">$source_author</a> at $domain)</small> -  " . $formattedcontent;
    } else {
        $formattedcontent = " <small>(at <a rel=\"nofollow\" href=\"$source_url\">$domain</a>)</small> -  " . $formattedcontent;
    }

    my $articleid = Reply::_add_reply($replytoid, $replytoinfo{replytoauthorid}, $title, $logged_in_userid, $markupcontent, $formattedcontent);

    if ( $posttype eq "manual" ) {
        my $url = Config::get_value_for("cgi_app") . "/replies/$replytoid";
        print $q->redirect( -url => $url);
        exit;
    } else {
        my $json = <<JSONMSG;
{
  "result": "WebMention was successful"
}
JSONMSG
        print header('application/json', '202 Accepted');
        print $json;
        exit;
    }
}

sub source_url_exists_for_target {
    my $source_url = shift;
    my $target_id  = shift;

    my $rc = 0;
    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $source_url = $db->quote($source_url);

    my $sql = "select id from $dbtable_content where parentid=$target_id and title=$source_url limit 1";

    $db->execute($sql);
    Page->report_error("system", "Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $rc=1;
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $rc;
}

sub target_post_exists {
    my $target_id  = shift;

    my $rc=0;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql = "select id from $dbtable_content where id=$target_id and status='o' and type in ('b','m')";

    $db->execute($sql);
    Page->report_error("system", "Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $rc=1;
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $rc;
}

sub source_content_exists_for_target {
    my $source_content = shift;
    my $target_id  = shift;

    my $rc = 0;
    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    $source_content = $db->quote($source_content);

    my $sql = "select id from $dbtable_content where parentid=$target_id and markupcontent=$source_content limit 1";

    $db->execute($sql);
    Page->report_error("system", "Error executing SQL", $db->errstr) if $db->err;

    if ( $db->fetchrow ) {
        $rc=1;
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return $rc;
}


# http://webmention.org
# WebMention defines several error cases that must be handled.
# All errors below MUST be returned with an HTTP 400 Bad Request response code.
#   source_not_found: The source URI does not exist.
#   target_not_found: The target URI does not exist. This must only be used when an external GET on the target URI would result in an HTTP 404 response.
#   target_not_supported: The specified target URI is not a WebMention-enabled resource. For example, on a blog, individual post pages may be WebMention-enabled but the home page may not.
#   no_link_found: The source URI does not contain a link to the target URI.
#   already_registered: The specified WebMention has already been registered.

sub report_error {
    my $error = shift;
    my $description = shift;

    if ( $RETURN_JSON ) {
        my $json = <<JSONMSG;
{
  "error": "$error",
  "error_description": "$description"
}
JSONMSG

        print header('application/json', '404 Bad Request');
        print $json;
        exit;
    } else {
        Page->report_error("user", $error, $description);
    }
}

# http://domain/cgi-bin/junco.pl/blogpost/123/whatever-here-does-not-matter
sub parse_target_url {
    my $url = shift;

    my %params;
    my @values = ();
    # remove dummy .html extension if exists
    if ( $url ) {
        $url =~ s/\.html//g; 
        $url =~ s/\/// if ( $url );
        @values = split(/\//, $url);
    }
    my $len = @values;
    for (my $i=0; $i<$len; $i+=2) {
        $params{$values[$i]} = $values[$i+1];
    }
    # name=value > blogpost=123
    return %params;
}

1;
