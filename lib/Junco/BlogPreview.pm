package BlogPreview;

use strict;
use warnings;

sub preview_new_blog_post {
    my $title            = shift;
    my $markupcontent    = shift;
    my $posttitle        = shift;
    my $formattedcontent = shift;
    my $err_msg          = shift;
    my $formtype = shift;

    User::user_allowed_to_function();

    my $t;

    if ( $formtype eq "enhanced" ) {
        $t = Page->new("enhblogpostform");
    } elsif ( $formtype eq "ajax" ) {
        print "Content-type: text/html\n\n";
        if ( $err_msg ) {
            print "Error: " . $err_msg . "\n";
        } else {
            print "<h1>$posttitle</h1>" . "\n";
            print $formattedcontent . "\n";
        }
        exit;
    } else { 
        $t = Page->new("blogpostform");
    }

    $t->set_template_variable("previewingarticle", "1"); 
    $t->set_template_variable("previewtitle", $posttitle);
    $t->set_template_variable("previewarticle", $formattedcontent);
    $t->set_template_variable("article", $markupcontent);

    if ( $err_msg ) {
        $t->set_template_variable("errorexists", "1");
        $t->set_template_variable("errormessage", $err_msg);
    }

    $t->display_page("Previewing New Blog Post");
    exit;
}

sub preview_blog_edit {
    my $title             = shift;
    my $markupcontent     = shift;
    my $posttitle         = shift;
    my $formattedcontent  = shift;
    my $articleid         = shift;
    my $contentdigest     = shift;
    my $editreason        = shift;
    my $err_msg           = shift;
    my $formtype          = shift;

    User::user_allowed_to_function();

    my $t;
    
    if ( $formtype eq "enhanced" ) {
        $t = Page->new("enheditblogpostform");
    } else { 
        $t = Page->new("editblogpostform");
    }

    $t->set_template_variable("articleid", $articleid);
    $t->set_template_variable("title", $posttitle);
    $t->set_template_variable("article", $formattedcontent);
    $t->set_template_variable("title", $title);
    $t->set_template_variable("contentdigest", $contentdigest);
    $t->set_template_variable("editreason", $editreason);
    $t->set_template_variable("editarticle", $markupcontent);

    if ( $err_msg ) {
        $t->set_template_variable("errorexists", "1");
        $t->set_template_variable("errormessage", $err_msg);
    }

    $t->display_page("Edit Content - " . $title);
    exit;
}

1;
