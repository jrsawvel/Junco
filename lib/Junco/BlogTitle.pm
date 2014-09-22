package BlogTitle;

use strict;
use warnings;
use NEXT;

{
    my $MAX_TITLE_LEN = Config::get_value_for("max_blog_post_title_length");

    sub new {
        my ($class) = @_;

        my $ self = {
            after_title_markup => undef,
            err                => 0,
            err_str            => undef,
            title              => undef,
            posttitle          => undef,
            articleid          => 0,
            username           => undef
        };

        bless($self, $class);
        return $self;
    }

    sub process_title {
        my ($self, $markup) = @_;
        $self->{title} = $markup;

        if ( $self->{title} =~ m/(.+)/ ) {
            my $tmp_title = $1;
            if ( length($tmp_title) < $MAX_TITLE_LEN+1  ) {
                my $tmp_title_len = length($tmp_title);
                $self->{title} = $tmp_title;
                my $tmp_total_len = length($markup);
                $self->{after_title_markup} = substr $markup, $tmp_title_len, $tmp_total_len - $tmp_title_len;
            } else {
                $self->{title} = substr $markup, 0, $MAX_TITLE_LEN;
                my $tmp_total_len = length($markup);
                $self->{after_title_markup} = substr $markup, $MAX_TITLE_LEN, $tmp_total_len - $MAX_TITLE_LEN;
            }   
        }
        if ( !defined($self->{title}) || length($self->{title}) < 1 ) {
            $self->{err_str} .= "You must give a title for your article.<br /><br />";
            $self->{err} = 1;
        } else {
            # remove textile or markdown / multimarkdown heading 1 markup commands if exists.
            my $md = 0;
            $md = 1 if Utils::get_power_command_on_off_setting_for("markdown", $markup, 0); 
            $md = 1 if Utils::get_power_command_on_off_setting_for("multimarkdown", $markup, 0); 
            if ( !$md and $self->{title} =~ m/^h1\.(.+)/i ) {
                $self->{title} = $1;
            } elsif ( $md and $self->{title} =~ m/^#[\s+](.+)/ ) {
                $self->{title} = $1;
            }

# commented out this code block on July 16, 2014.
# stopped enforcing the namespace feature, since I'm the only one using the site.
#            if ( $self->{title} =~ m/^(.+?):(.*)$/ ) {
#                my $namespace = StrNumUtils::trim_spaces($1);
#                if ( (lc($namespace) ne lc($self->{username})) ) {
#                    $self->{err_str} .= "The text preceding the colon punctuation mark must match your username. That area is reserved for your namespace. If you don't wish to use this for your namespace, then replace the colon mark.<br /><br />";
#                    $self->{err} = 1;
#                }
#            }

            if ( BlogData::title_exists(StrNumUtils::trim_spaces($self->{title}), $self->{articleid} ) ) {
                $self->{err_str} .= "Article title: \"$self->{title}\" already exists. Choose a different title.<br /><br />";
                $self->{err} = 1;
            }
        }
        $self->{posttitle}  = StrNumUtils::trim_spaces($self->{title});
        $self->{posttitle}  = ucfirst($self->{posttitle});
        $self->{posttitle}  = HTML::Entities::encode_entities($self->{posttitle}, '<>');
    } # end process_title

    sub set_article_id {
        my ($self, $articleid) = @_;
        $self->{articleid} = $articleid;
    }

    sub set_logged_in_username {
        my ($self, $username) = @_;
        $self->{username} = $username;
    } 
         
    sub get_title {
        my ($self) = @_;
        return $self->{title};
    }
         
    sub get_post_title {
        my ($self) = @_;
        return $self->{posttitle};
    }

    sub get_after_title_markup {
        my ($self) = @_;
        return $self->{after_title_markup};
    }

    sub is_error {
        my ($self) = @_;
        return $self->{err};
    }

    sub get_error_string {
        my ($self) = @_;
        return $self->{err_str};
    }
}

# todo add destroy object code

1;


