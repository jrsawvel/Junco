#!/usr/bin/perl -wT

use strict;
use warnings;

my $str = "this is a **test of bolded** text\n";
print _DoItalicsAndBold($str);

print _DoItalicsAndBold("this is a *test of bolded* text\nand another line of text\nthird line with **bold text**.\n");

print format_small_and_strikethrough("this is a -test --line-- of- text - math 4-5 = - 1 to test -strikethrough- text\n");

print format_big_and_underline("this is a +test ++line++ of+ text + math 4+5 = 9 to test +strikethrough+ text\n");

# from Markdown.pm
sub _DoItalicsAndBold {
    my $text = shift;

    # Handle at beginning of lines:
    $text =~ s{ ^(\*\*|__) (?=\S) (.+?[*_]*) (?<=\S) \1 }
        {<strong>$2</strong>}gsx;

    $text =~ s{ ^(\*|_) (?=\S) (.+?) (?<=\S) \1 }
        {<em>$2</em>}gsx;

    # <strong> must go first:
    $text =~ s{ (?<=\W) (\*\*|__) (?=\S) (.+?[*_]*) (?<=\S) \1 }
        {<strong>$2</strong>}gsx;

    $text =~ s{ (?<=\W) (\*|_) (?=\S) (.+?) (?<=\S) \1 }
        {<em>$2</em>}gsx;

    # And now, a second pass to catch nested strong and emphasis special cases
    $text =~ s{ (?<=\W) (\*\*|__) (?=\S) (.+?[*_]*) (?<=\S) \1 }
        {<strong>$2</strong>}gsx;

    $text =~ s{ (?<=\W) (\*|_) (?=\S) (.+?) (?<=\S) \1 }
        {<em>$2</em>}gsx;

    return $text;
}

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

