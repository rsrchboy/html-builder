package HTML::Perlish;

# ABSTRACT: A declarative approach to HTML generation

use strict;
use warnings;

use Template::Declare::TagSet::HTML;
use HTML::Tiny;
use Sub::Install;
use List::MoreUtils 'uniq';

# debugging...
#use Smart::Comments;

my @tags;

BEGIN {

    sub _is_autoload_gen {
        my ($attr_href) = @_;

        return sub {
            shift;

            my $field = our $AUTOLOAD;
            $field =~ s/.*:://;

            $field =~ s/__/:/g;   # xml__lang  is 'foo' ====> xml:lang="foo"
            $field =~ s/_/-/g;    # http_equiv is 'bar' ====> http-equiv="bar"

            # Squash empty values, but not '0' values
            my $val = join ' ', grep { defined $_ && $_ ne '' } @_;

            #push @$attr_aref, $field => $val;
            $attr_href->{$field} = $val;

            return;
        };
    }

    my $h = HTML::Tiny->new;

    sub tag($&) {
        my ($tag, $inner_coderef) = @_;

        ### @_

        my %attrs = ();

        # This is almost completely stolen from Template::Declare::Tags, and
        # completely terrifying in that it confirms my dark suspicions on how
        # to achieve this.
        no warnings 'once';
        local *gets::AUTOLOAD = _is_autoload_gen(\%attrs);
        my $inner = $inner_coderef->();

        return $h->$tag(\%attrs, $inner);
    }

    @tags = uniq sort @{ Template::Declare::TagSet::HTML::get_tag_list() };

    for my $tag (@tags) {

        Sub::Install::install_sub({
            #code => sub(&) { my $sub = shift; tag($tag, $sub) },
            code => sub(&) { unshift @_, $tag; goto \&tag },
            as   => $tag,
        });
    }
}

use Sub::Exporter -setup => {

    exports => [ @tags ],
    groups  => {

        default    => ':moose_safe',
        moose_safe => [ grep { ! /^(meta|with)/ } @tags ],
    },
};

!!42;

__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

L<HTML::Tiny>
L<Template::Declare::Tags>

=cut

