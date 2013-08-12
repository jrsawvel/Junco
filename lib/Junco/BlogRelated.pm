package BlogRelated;

use strict;
use warnings;

use Junco::BlogDisplay;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");
my $dbtable_tags       = Config::get_value_for("dbtable_tags");

sub show_related_blog_posts {
    my $tmp_hash = shift;  

    my $articleid = $tmp_hash->{one};

    my %blog_post = BlogDisplay::_get_blog_post($articleid);

    my @loop_data = ();
    @loop_data = _get_related_articles($articleid, $blog_post{tags});

    my $t = Page->new("relatedblogposts");
    $t->set_template_variable("title", $blog_post{title});
    $t->set_template_variable("cleantitle",    $blog_post{cleantitle});
    $t->set_template_variable("articleid", $articleid);
    $t->set_template_loop_data("relatedarticles_loop",  \@loop_data);
    $t->display_page("Backlinks for $blog_post{title}");
}


# related article SQL from Pete Freitag's blog post at
# http://www.petefreitag.com/item/315.cfm
sub _get_related_articles {
    my $articleid = shift;
    my $tags      = shift;

    my $cgi_app = Config::get_value_for("cgi_app");

    my $offset = Utils::get_time_offset();

    # if at least one tag, then string will contain at a minimum
    #     |x|
    my @loop_data = ();
    return @loop_data if ( !$tags or (length($tags) < 3) );

    my @tagnames = ();
    my $instr = "";
    $tags =~ s/^\|//;
    $tags =~ s/\|$//;
    if ( @tagnames = split(/\|/, $tags) ) {
        foreach (@tagnames) {
            $instr .= "'$_'," if ( $_ );
        }
    }
    $instr =~ s/,$//;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $sql = <<EOSQL; 
    SELECT c.id, c.title,
      DATE_FORMAT(DATE_ADD(c.date, interval $offset hour), '%b %d, %Y') AS date,
      COUNT(m.articleid) AS wt
      FROM $dbtable_content AS c, $dbtable_tags AS m
      WHERE m.articleid <> $articleid 
      AND m.name IN ($instr)
      AND c.id = m.articleid
      AND c.status in ('o')  
      AND c.type in ('b')
      GROUP BY c.title, c.id
      HAVING wt > 1
      ORDER BY wt DESC 
EOSQL

    $db->execute($sql);
    Page->report_error("system", "(66) Error executing SQL", $db->errstr) if $db->err;

    while ( $db->fetchrow ) {
        my %hash;
        $hash{articleid}     = $db->getcol("id");
        $hash{title}         = $db->getcol("title");
        $hash{urltitle}      = Format::clean_title($hash{title});
        $hash{date}          = $db->getcol("date");
        $hash{cgi_app}       = $cgi_app;
        push(@loop_data, \%hash);
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return @loop_data;
}


1;

