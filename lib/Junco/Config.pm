package Config;
use strict;
use warnings;

use YAML::Tiny;

my $yml_file = "/home/magee/Dvlp/Junco/yaml/junco.yml";

my $yaml = YAML::Tiny->new;

$yaml = YAML::Tiny->read($yml_file);

sub get_value_for {
    my $name = shift;

    if ( !exists($yaml->[0]->{$name}) ) {
        return 0;
    }
    return $yaml->[0]->{$name};
}

1;

