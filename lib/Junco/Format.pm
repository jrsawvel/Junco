package Format;

use strict;
use warnings;

use Text::Textile;
# use Text::Markdown;
use Text::MarkdownJRS;
use Junco::BlogData;

sub permit_some_html_tags {
    my $str = shift;

    if ( $str =~ m|&lt;[\s]*iframe(.*?)&gt;|i ) {
        my $tmp = $1;
        $str =~ s|&lt;[\s]*iframe\Q$tmp&gt;|\[iframe$tmp\]|i;   
    }

    # pt is parula custom tag that gets generated within the system when
    # the user uses pt=paratagname paratag comand.
    # my @tags = qw(div span table a th tr td center pre dl dt dd img object param embed code pt i b);

    my @tags = split(/(\s+)/, Config::get_value_for("valid_html"));

    foreach (@tags) {
        my $tag = $_;
        while ( $str =~ m|&lt;[\s]*$tag(.*?)&gt;|i ) {
            my $tmp = $1;
            $str =~ s|&lt;[\s]*$tag\Q$tmp&gt;|<$tag$tmp>|i;   
        } 

        if ( $str =~ m|&lt;[\s]*/$tag&gt;|i ) {
            $str =~ s|&lt;[\s]*/$tag&gt;|</$tag>|ig;   
        }
    }

    # for tables with textile
    $str =~ s/\|&gt;\. /\|>\. /g;
    $str =~ s/\|&lt;\. /\|<\. /g;
    $str =~ s/\|&lt;&gt;\. /\|<>\. /g;

    # for images with textile
    $str =~ s/!&gt;http:/!>http:/g;
    $str =~ s/!&lt;http:/!<http:/g;

    return $str;
}

sub custom_commands {
    my $formattedcontent = shift;
    my $articleid = shift;

    # q. and q..
    # tmpl. and tmpl..
    # hr.
    # br.
    # pt=alphanumeric_plus_underscore  and pt..
    # more.
    # code. and code..

#    $formattedcontent =~ s/^q[.][.]/\n<\/div>/igm;
    $formattedcontent =~ s/^q[.][.]/\n<\/blockquote>/igm;
#    $formattedcontent =~ s/^q[.]/<div class="highlighted">/igm;
    $formattedcontent =~ s/^q[.]/<blockquote class="highlighted">/igm;

    $formattedcontent =~ s/^tmpl[.][.]/<\/tmpl>/igm;
    $formattedcontent =~ s/^tmpl[.]/<tmpl>/igm;

    $formattedcontent =~ s/^code[.][.]/<\/code><\/pre><\/div>/igm;
#    $formattedcontent =~ s/^code[.]/<textarea class="codetext" id="enhtextareaboxarticle" rows="15" cols="60" wrap="off" readonly>/igm;
    $formattedcontent =~ s/^code[.]/<div class="codeClass"><pre><code>/igm;

    $formattedcontent =~ s/^hr[.]/<hr \/>/igm;

    $formattedcontent =~ s/^br[.]/<br \/>/igm;

    $formattedcontent =~ s/^pt=(\w*)/<pt name="$1">/igm;
    $formattedcontent =~ s/^pt[.][.]/<\/pt>/igm;

    $formattedcontent =~ s/^more[.]/<more \/>/igm;

    return $formattedcontent;
}

sub edit_for_bracket_case {
    my $str = shift;
    my $action = shift;

    # convert user input into format displayed to the reader.

    # trim extra spaces surrounding text within backet case 
    $str = trim_bracket_case_spaces($str);

    # bracket case with vertical bar.
    while ( $str =~ m{\[\[([\w\s\-:'\.,]+?)[\|]([\w\s\-:'\.,]+?)\]\]}s ) {
        my $left=$1;
        my $right=$2;
        # left side of vertical bar will be the title of article stored in system.
        # right side of vertical bar will be the title displayed on the web page. 
        # left side allows for camel case. let's separate it.
        my $tmp_title = ucfirst($left);
        $str =~ s/\[\[$left\|$right\]\]/~~$tmp_title\|$right~~/;
    }

    my $cgi_app          = Config::get_value_for("cgi_app");

	# bracket case
    while ( $str =~ m|\[\[(.*?)\]\]| ) {
        my $title = $1;
        my $wiki_link_title = ucfirst(clean_title($title));
        my $wiki_page_exists = BlogData::_get_blog_post_id($title, $action); 
        my $tmp_title = ucfirst($title);
        if ( $wiki_page_exists ) {
# todo 8oct2013 name attribute unsupported in html5. do i need this info anyway?
#            $str =~ s|\[\[$title\]\]|<a name="wikilink$tmp_title" href="$cgi_app/blogpost/$wiki_page_exists/$wiki_link_title">$title</a>|;
            $str =~ s|\[\[$title\]\]|<a title="wikilink$tmp_title" href="$cgi_app/blogpost/$wiki_page_exists/$wiki_link_title">$title</a>|;
        } else {
            $str =~ s|\[\[$title\]\]|&#091;&#091;$title&#093;&#093;|;
        }
    }

        # bracket case with the vertical bar in the middle
    while ( $str =~ m/~~([\w\s\-:'\.,]+?)[\|]([\w\s\-:'\.,]+?)~~/s ) {
        my $left=$1;
        my $right=$2;
        my $title = StrNumUtils::trim_spaces($left);
        my $wiki_link_title = clean_title($title);
        my $wiki_page_exists = BlogData::_get_blog_post_id($title, $action); 
        my $new_str = ""; 
        if ( $wiki_page_exists ) {
# todo 8oct2013 name attribute unsupported in html5. do i need this info anyway?
#            $new_str = "<a name=\"wikilink$title\" href=\"$cgi_app/blogpost/$wiki_page_exists/$wiki_link_title\">$right</a>";
            $new_str = "<a title=\"wikilink$title\" href=\"$cgi_app/blogpost/$wiki_page_exists/$wiki_link_title\">$right</a>";
         } else {
            $new_str = "[[$left|$right]]";
        }
        my $old_str = "~~$left|$right~~";
        $str =~ s/\Q$old_str/$new_str/;
    }

    $str =~ s|<br /><br />$||;

    return $str;
}

sub check_for_external_links {
    my $str = shift;

    my @a;

    my $intlink = Config::get_value_for("email_host");

    if ( @a = $str =~ m/href="(http[s]?):\/\/(www\.)?([^\/|^"]*)[\/|"]/igs ) {
        my $len = @a;
        for (my $i=0; $i<$len; $i+=3) {
            my $http = $a[$i];
            my $www =  $a[$i+1];
            my $link = $a[$i+2];

            if ( lc($link) ne $intlink ) {
                $str =~ s/href="$http:\/\/$www$link/ class="extlink" href="$http:\/\/$www$link/g;
            }
        }
    }
    return $str;
}

sub trim_bracket_case_spaces {
    my $str = shift;

    while ( $str =~ m!\[\[(\s+.*?\s+)\]\]! ) {
        my $wiki_link  = $1;
        my $tmp_wiki_link = StrNumUtils::trim_spaces($wiki_link);
        $str =~ s!\Q[[$wiki_link]]![[$tmp_wiki_link]]!; 
    }

    while ( $str =~ m!\[\[([^ ][\w\s\-:'\.\|,]*?[\s]+)\]\]! ) {
        my $wiki_link  = $1;
        my $tmp_wiki_link = StrNumUtils::trim_spaces($wiki_link);
        $str =~ s!\Q[[$wiki_link]]![[$tmp_wiki_link]]!;
    }

    while ( $str =~ m{\[\[([\s]+[\w\s\-:'\.\|,]*?[^ ])\]\]} ) {
        my $wiki_link  = $1;
        my $tmp_wiki_link = StrNumUtils::trim_spaces($wiki_link);
        $str =~ s/\Q[[$wiki_link]]/[[$tmp_wiki_link]]/; 
    }

    return $str;
}

# hashtag suport sub
sub hashtag_to_link {
    my $str = shift;

    $str = " " . $str . " "; # hack to make regex work

    my @tags = ();
    my $tagsearchstr = "";
    my $tagsearchurl = Config::get_value_for("cgi_app") . "/tag/";
# 26apr2013   if ( (@tags = $str =~ m|\s#(\w+)|gsi) ) {
#    if ( (@tags = $str =~ m|\s#(\w+)|gsi) ) {
# 30jul2013    if ( (@tags = $str =~ m|\s#([\w\.\-]+)|gsi) ) {
    if ( (@tags = $str =~ m|\s#(\w+)|gsi) ) {
            foreach (@tags) {
                next if  StrNumUtils::is_numeric($_); 
                $tagsearchstr = " <a href=\"$tagsearchurl$_\">#$_</a>";
# 26apr2013                $str =~ s|#$_|$tagsearchstr|isg;
                $str =~ s|\s#$_|$tagsearchstr|is;
        }
    }
    $str = StrNumUtils::trim_spaces($str);
    return $str;
}

sub clean_title {
    my $str = shift;

    $str =~ s|[-]||g;
    $str =~ s|[ ]|-|g;
    $str =~ s|[:]|-|g;
    $str =~ s|--|-|g;

    # only use alphanumeric, underscore, and dash in friendly link url
    $str =~ s|[^\w-]+||g;

#    $str =~ s|[^a-zA-Z_0-9-]+||g;
#    $str =~ s|[^a-zA-Z_0-9-:]+||g;
    return $str;
}

sub create_blog_tag_list {
    my $str = shift;   # pipe-delimited string of tag names created in blog posts with either pound sign (#hashtag) or tag= command.

    # abnormally-delimited string because tag is surrounded by a single verticle bar or pipe like this:
    # |tagone|tagtwo|tagthree|
    # so array elements 1,2, and 3 contain tags
       
    my $html;
 
    my @tags = split(/\|/, $str);
    foreach (@tags) {
        my $tag = $_;
        if ( length($tag) > 1 ) {
            $html .= " #$tag ";
        }
    }
    $html = hashtag_to_link($html);
    return $html;
}

sub post_id_to_link {
    my $str = shift;

    $str = " " . $str; # hack to make regex work

    my @post_ids = ();
    my $postidsearchstr = "";
    my $postidsearchurl = Config::get_value_for("cgi_app") . "/post/";
    if ( (@post_ids = $str =~ m|\s/([0-9]+)/|gsi) ) {
        foreach (@post_ids) {
            $postidsearchstr = "<a href=\"$postidsearchurl$_\">/$_/</a>";
            $str =~ s|/$_/|$postidsearchstr|isg;
        }
    }
    $str = StrNumUtils::trim_spaces($str);
    return $str;
}

# hashtag suport sub
sub create_tag_list_str {
    my $str = shift; # using the markup code content

    my $tag_list_str = "";
    return $tag_list_str if Utils::get_power_command_on_off_setting_for("code", $str, 0);

    $str = " " . $str . " "; # hack to make regex work
    my @tags = ();
# 26apr2013    if ( (@tags = $str =~ m|\s+#(\w+)|gsi) ) {
#    if ( (@tags = $str =~ m|\s#(\w+)|gsi) ) {
# 30jul2013   if ( (@tags = $str =~ m|\s#([\w\.\-]+)|gsi) ) {
   if ( (@tags = $str =~ m|\s#(\w+)|gsi) ) {
        $tag_list_str = "|";
            foreach (@tags) {
               my $tmp_tag = $_;
               next if  StrNumUtils::is_numeric($tmp_tag); 
               if ( $tag_list_str !~ m|$tmp_tag| ) {
                   $tag_list_str .= "$tmp_tag|";
               }
           }
    }
    return $tag_list_str;
}

sub format_content {
    my $formattedcontent = shift;
    my $action = shift;   # preview or add

    $action = lc($action);

    my $markdown = 0;

    $markdown = 1 if Utils::get_power_command_on_off_setting_for("markdown", $formattedcontent, 0); 

    $formattedcontent = remove_image_header_commands($formattedcontent); 

    $formattedcontent = remove_power_commands($formattedcontent);

    $formattedcontent = StrNumUtils::trim_spaces($formattedcontent);

    $formattedcontent = process_custom_code_block_encode($formattedcontent);

    $formattedcontent = HTML::Entities::encode($formattedcontent, '<>') if !$markdown;

    $formattedcontent = permit_some_html_tags($formattedcontent);

    $formattedcontent = process_embedded_media($formattedcontent);

    $formattedcontent = StrNumUtils::url_to_link($formattedcontent) if !$markdown;

    $formattedcontent = custom_commands($formattedcontent); 

    $formattedcontent = hashtag_to_link($formattedcontent);

    if ( $markdown ) {
#        my $m = Text::Markdown->new;
        my $m = Text::MarkdownJRS->new;
        $formattedcontent = $m->markdown($formattedcontent);
#        $formattedcontent = HTML::Entities::decode($formattedcontent);
#        $formattedcontent = format_small_and_strikethrough($formattedcontent);
#        $formattedcontent = format_big_and_underline($formattedcontent);
    } else {
        $formattedcontent = Textile::textile($formattedcontent);
    }

    $formattedcontent = process_custom_code_block_decode($formattedcontent);

    $formattedcontent =~ s/&#39;/'/sg;

    $formattedcontent = edit_for_bracket_case($formattedcontent, $action);

    $formattedcontent = check_for_external_links($formattedcontent);

    $formattedcontent = format_webmention_replyto_links($formattedcontent);

    $formattedcontent = create_heading_list($formattedcontent);

    return $formattedcontent;
}

sub remove_profile_blog_settings {
    my $str = shift;

    while ( $str =~ m|^blog-description[\s]*=[\s]*(.+)|im ) {
        my $url = $1;
        $str =~ s|^blog-description[\s]*=[\s]*$url||im;
    }

    while ( $str =~ m|^blog-author-image[\s]*=[\s]*(.+)|im ) {
        my $url = $1;
        $str =~ s|^blog-author-image[\s]*=[\s]*$url||im;
    }

    while ( $str =~ m|^blog-banner-image[\s]*=[\s]*(.+)|im ) {
        my $url = $1;
        $str =~ s|^blog-banner-image[\s]*=[\s]*$url||im;
    }

    return $str;
}

sub remove_image_header_commands {
    my $str = shift;
    while ( $str =~ m|^imageheader[\s]*=[\s]*(.+)|im ) {
        my $url = $1;
        $str =~ s|^imageheader[\s]*=[\s]*$url||im;
    }
    while ( $str =~ m|^largeimageheader[\s]*=[\s]*(.+)|im ) {
        my $url = $1;
        $str =~ s|^largeimageheader[\s]*=[\s]*$url||im;
    }
    return $str;
}

sub remove_power_commands {
    my $str = shift;

    # commands must begin at beginning of line
    #
    # not implemented yet. possibly in future. edit=no|owner|global
    # toc=yes|no    (table of contents for the article)
    # draft=yes|no
    # replies=yes|no
    # private=yes|no
    # showintro=yes|no
    # code=yes|no
    # markdown=yes|no
    # webmention=yes|no

    $str =~ s|^toc[\s]*=[\s]*[noNOyesYES]+||mig;
    $str =~ s|^draft[\s]*=[\s]*[noNOyesYES]+||mig;
    $str =~ s|^replies[\s]*=[\s]*[noNOyesYES]+||mig;
    $str =~ s|^private[\s]*=[\s]*[noNOyesYES]+||mig;
    $str =~ s|^showintro[\s]*=[\s]*[noNOyesYES]+||mig;
    $str =~ s|^code[\s]*=[\s]*[noNOyesYES]+||mig;
    $str =~ s|^markdown[\s]*=[\s]*[noNOyesYES]+||mig;
    $str =~ s|^webmention[\s]*=[\s]*[noNOyesYES]+||mig;

    return $str;
}

sub process_embedded_media {
    my $str = shift;

    my $cmd = "";
    my $url = "";

    while ( $str =~ m|^(gmap[\s]*=[\s]*)(.*?)$|mi ) {
        $cmd=$1;
#        $url=qq(trim_spaces($2));
        $url= StrNumUtils::trim_spaces($2);
        my $iframe = qq(<iframe width="400" height="300" frameborder="0" scrolling="no" marginheight="0" marginwidth="0" src="http://maps.google.com/$url"></iframe>);
        $str =~ s|\Q$cmd$url|$iframe|;    
    }

    while ( $str =~ m|^(kickstarter[\s]*=[\s]*)(.*?)$|mi ) {
        $cmd=$1;
        $url= StrNumUtils::trim_spaces($2);
        my $iframe = qq(<iframe width="480" height="360" frameborder="0" src="http://www.kickstarter.com/projects/$url"></iframe>);
        $str =~ s|\Q$cmd$url|$iframe|;    
    }

    while ( $str =~ m|^(facebook[\s]*=[\s]*)(.*?)$|mi ) {
        $cmd=$1;
        $url= StrNumUtils::trim_spaces($2);
        my $iframe = qq(<iframe width="640" height="480" frameborder="0" src="http://www.facebook.com/video/embed?video_id=$url"></iframe>);
        $str =~ s|\Q$cmd$url|$iframe|;    
   }

    while ( $str =~ m|^(youtube[\s]*=[\s]*)(.*?)$|mi ) {
        $cmd=$1;
        $url= StrNumUtils::trim_spaces($2);
        my $iframe = qq(<iframe width="480" height="360" frameborder="0" allowfullscreen src="http://www.youtube.com/embed/$url"></iframe>);
        $str =~ s|\Q$cmd$url|$iframe|;    
    }

    while ( $str =~ m|^(vimeo[\s]*=[\s]*)(.*?)$|mi ) {
        $cmd=$1;
        $url= StrNumUtils::trim_spaces($2);
        my $iframe = qq(<iframe src="http://player.vimeo.com/video/$url" width="400" height="300" frameborder="1" webkitAllowFullScreen mozallowfullscreen allowFullScreen></iframe>);
        $str =~ s|\Q$cmd$url|$iframe|;    
    }

    while ( $str =~ m|^(gist[\s]*=[\s]*)(.*?)$|mi ) {
        $cmd=$1;
        $url= StrNumUtils::trim_spaces($2);
        my $gscript = qq(<script src="https://gist.github.com/$url"></script>);
        $str =~ s|\Q$cmd$url|$gscript|;    
    }

    return $str;
}
# embedding media
#
# you tube video: - use url from the youtube embed code in the command
# url to page:              http://www.youtube.com/watch?v=nfOUn6LgN3c
# command to embed:         youtube=nfOUn6LgN3c
#
# facebook video: - grab url to use with command from the embed or share at the facebook page
# url to video:      http://www.facebook.com/video/embed?video_id=10152670330945433
# command to embed: facebook=10152670330945433
#
# google map: - grab url from the link command
# url to map:        http://maps.google.com/maps/ms?msa=0&msid=115189530534020686385.000458eaca4e382f6e81b&cd=2&hl=en&ie=UTF8&ll=41.655824,-83.53858&spn=0.021611,0.032959&z=15 
# command to embed:  gmap=maps/ms?msa=0&msid=115189530534020686385.000458eaca4e382f6e81b&cd=2&hl=en&ie=UTF8&ll=41.648656,-83.538566&spn=0.017445,0.004533&output=embed
#
# kickstarter video: - grab url to use with the command from the embed code
# url to video page:   http://www.kickstarter.com/projects/lanceroper/actual-coffee-a-toledo-coffee-roaster
# command to embed:    kickstarter=lanceroper/actual-coffee-a-toledo-coffee-roaster/widget/video.html
#
# vimeo:
# url to video page:  http://vimeo.com/8578344
# command to embed:   vimeo=8578344


sub create_heading_list {
    my $str = shift;

    my @headers = ();
    my $header_list = "";

    if ( @headers = $str =~ m{<h([1-6])>(.*?)</h[1-6]>}igs ) {
        my $len = @headers;
        for (my $i=0; $i<$len; $i+=2) { 
            my $heading_text = StrNumUtils::remove_html($headers[$i+1]); 
            my $heading_url  = clean_title($heading_text);
            my $oldstr = "<h$headers[$i]>$headers[$i+1]</h$headers[$i]>";
            my $newstr = "<a name=\"$heading_url\"></a>\n<h$headers[$i]>$headers[$i+1]</h$headers[$i]>";
            $str =~ s/\Q$oldstr/$newstr/i;
         
# old way didn't work if question mark in heading. plus, why dynamically 
# pull off the heading level when we already got in the regex in the if statement above?
#         $str =~ s!<h([1-6])>$headers[$i+1]</h([1-6])>!<a name="$heading_url"></a>\n<h$1>$headers[$i+1]</h$2>!ig;

            $header_list .= "<!-- header:$headers[$i]:$heading_text -->\n";   
        } 
    }

    $str .= "\n$header_list";  
    return $str; 
}

sub check_for_special_tag  {
    my $err_msg = shift;
    my $tag_list_str = shift;

    my $logged_in_username = User::get_logged_in_username();

    my $special_tag = "blog_" . $logged_in_username;
    $special_tag = lc($special_tag);
    my $blog_underscore_tag_exists = 0;
    my $special_tag_match = 0;
    if ( $tag_list_str =~ m|blog_|i ) {
        $blog_underscore_tag_exists = 1;
        my @tmp_tags = split(/\|/, $tag_list_str);
        foreach (@tmp_tags) {
            my $tmp_tag = lc($_);    
            if ( $tmp_tag eq $special_tag ) {
                $special_tag_match = 1;
            }
        }
    } 
    if ( $blog_underscore_tag_exists and !$special_tag_match ) {
        $err_msg .= "You can only use the blog_ tag with your username.";
    }
    return $err_msg;
}

# adapted from the bold and italics code in Markdown.pm
# to add support for additional formatting when 
# markdown=yes is used
sub format_small_and_strikethrough {
    my $text = shift;

    # Handle at beginning of lines:
    $text =~ s{ ^(\-\-) (?=\S) (.+?[-]*) (?<=\S) \1 }
        {<small>$2</small>}gsx;

    $text =~ s{ ^(\-) (?=\S) (.+?[-]*) (?<=\S) \1 }
        {<del>$2</del>}gsx;

    # <small> must go first:
    $text =~ s{ (?<=\W) (\-\-) (?=\S) (.+?[-]*) (?<=\S) \1 }
        {<small>$2</small>}gsx;

    $text =~ s{ (?<=\W) (\-) (?=\S) (.+?[-]*) (?<=\S) \1 }
        {<del>$2</del>}gsx;

    # And now, a second pass to catch nested small special case 
    $text =~ s{ (?<=\W) (\-\-) (?=\S) (.+?[-]*) (?<=\S) \1 }
        {<small>$2</small>}gsx;

    $text =~ s{ (?<=\W) (\-) (?=\S) (.+?[-]*) (?<=\S) \1 }
        {<del>$2</del>}gsx;

    return $text;
}

sub format_big_and_underline {
    my $text = shift;

    # Handle at beginning of lines:
    $text =~ s{ ^(\+\+) (?=\S) (.+?[+]*) (?<=\S) \1 }
        {<big>$2</big>}gsx;

    $text =~ s{ ^(\+) (?=\S) (.+?[+]*) (?<=\S) \1 }
        {<ins>$2</ins>}gsx;

    # <big> must go first:
    $text =~ s{ (?<=\W) (\+\+) (?=\S) (.+?[+]*) (?<=\S) \1 }
        {<big>$2</big>}gsx;

    $text =~ s{ (?<=\W) (\+) (?=\S) (.+?[+]*) (?<=\S) \1 }
        {<ins>$2</ins>}gsx;

    # And now, a second pass to catch nested small special case 
    $text =~ s{ (?<=\W) (\+\+) (?=\S) (.+?[+]*) (?<=\S) \1 }
        {<big>$2</big>}gsx;

    $text =~ s{ (?<=\W) (\+) (?=\S) (.+?[+]*) (?<=\S) \1 }
        {<ins>$2</ins>}gsx;

    return $text;
}

sub process_custom_code_block_encode {
    my $str = shift;

    # code. and code.. custom block

    while ( $str =~ m/(.*?)code\.(.*?)code\.\.(.*)/is ) {
        my $start = $1;
        my $code  = $2;
        my $end   = $3;
        $code =~ s/</\[lt;/gs;
        $code =~ s/>/gt;\]/gs;
        $str = $start . "ccooddee." . $code . "ccooddee.." . $end;
#        Page->report_error("user", "debug", "$str");
    } 
    $str =~ s/ccooddee/code/igs;
 
    return $str;
}

sub process_custom_code_block_decode {
    my $str = shift;

    $str =~ s/\[lt;/&lt;/gs;
    $str =~ s/gt;\]/&gt;/gs;

    return $str;
}

sub format_webmention_replyto_links {
    my $str = shift;

    my @a;

    if ( @a = $str =~ m/replyto\(([^\)]*)\)/igs ) {
        my $len = @a;
        for (my $i=0; $i<$len; $i++) {
            my $replytolink = "<a href=\"$a[$i]\" rel=\"in-reply-to\" class=\"u-in-reply-to\">in reply to</a>";
            $str =~ s/replyto\($a[$i]\)/$replytolink/g;
        }
    }

    return $str;
}

1;

