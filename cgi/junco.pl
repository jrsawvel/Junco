#!/usr/bin/perl -wT
use strict;
$|++;
use lib '/home/magee/Dvlp/Junco/lib';
use Junco::Dispatch;

# test code
# use Junco::Search;
# Search::tag_search();

Junco::Dispatch::execute();
