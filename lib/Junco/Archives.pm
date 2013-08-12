package Archives;

use strict;

my $pt_db_source       = Config::get_value_for("database_host");
my $pt_db_catalog      = Config::get_value_for("database_name");
my $pt_db_user_id      = Config::get_value_for("database_username");
my $pt_db_password     = Config::get_value_for("database_password");

my $dbtable_content    = Config::get_value_for("dbtable_content");
my $dbtable_users    = Config::get_value_for("dbtable_users");

sub show_archives {
    my $tmp_hash = shift;  

    my $username = $tmp_hash->{one}; 
    
    my $str = "";
    my @loop_data = _get_archives($username);
    my $t = Page->new("archives");
    $t->set_template_loop_data("archives_loop", \@loop_data);
    if ( $username ) {
        $t->set_template_variable("userblog", 1);
        $t->set_template_variable("userarchives", $username);
        $str = "for $username\'s workspace";
    }
    $t->display_page("Archives $str");
}

sub _get_archives {
    my $username = shift;

    my @months = qw(xxx January February March April May June July August September October November December);

    my $offset = Utils::get_time_offset();

    my $archives_status = Config::get_value_for("archives_status");

    my @loop_data;

    my $db = Db->new($pt_db_catalog, $pt_db_user_id, $pt_db_password);
    Page->report_error("system", "Error connecting to database.", $db->errstr) if $db->err;

    my $id=0;
    my $sql;

    $sql  = "select distinct date_format(date_add(createddate, interval $offset hour), '%Y') as year, ";
    $sql .= "date_format(date_add(createddate, interval $offset hour),  '%m') as month ";

     if ( $username ) {
         $id = User::get_userid($username);
         $sql .= "from $dbtable_content where authorid = $id and type in ('b') and status in ($archives_status) order by year desc, month desc";
     } else {
         $sql .= "from $dbtable_content where type in ('b') and status in ($archives_status) order by year desc, month desc";
     }

    $db->execute($sql);

    Page->report_error("system", "(35) Error executing SQL", $db->errstr) if $db->err;

    my $cgi_app = Config::get_value_for("cgi_app");

    while ( $db->fetchrow ) {
        my %hash;

        $hash{year}          = $db->getcol("year");
        $hash{month}         = $db->getcol("month");
        $hash{monthyear}     = "$months[$hash{month}] $hash{year}";
        $hash{userarchives}  = $username if ( $username );
        $hash{cgi_app} = $cgi_app;
        push(@loop_data, \%hash);
    }
    Page->report_error("system", "Error retrieving data from database.", $db->errstr) if $db->err;

    $db->disconnect;
    Page->report_error("system", "Error disconnecting from database.", $db->errstr) if $db->err;

    return @loop_data;
}

1;
