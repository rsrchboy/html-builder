package HTML::Perlish;

# ABSTRACT: A declarative approach to HTML generation

use v5.10;

use strict;
use warnings;

use Template::Declare::TagSet::HTML;
use CGI ();
use HTML::Tiny;
use Sub::Install;
use List::MoreUtils 'uniq';

# debugging...
#use Smart::Comments;

my @tags;

=func our_tags

A unique, sorted list of the html tags we know about (and handle).

=cut

sub our_tags {
    state $tags = [ uniq sort
        #grep { ! /^(state)$/ }
        map { @{$_} }
        map { $CGI::EXPORT_TAGS{$_} // [] }
        qw{ :html2 :html3 :html4 }
    ];

    return @$tags;
}

BEGIN {

    sub _is_autoload_gen {
        my ($attr_href) = @_;

        return sub {
            shift;

            my $field = our $AUTOLOAD;
            $field =~ s/.*:://;

            # XXX
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
        # it was achieved over there.
        no warnings 'once', 'redefine';
        local *gets::AUTOLOAD = _is_autoload_gen(\%attrs);
        my $inner = $inner_coderef->();

        return $h->tag($tag, \%attrs, $inner);
    }

    @tags = our_tags();

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

        minimal => [ 'h1'..'h5', qw{
            div p img script
        } ],
    },
};

!!42;

__END__

=head1 SYNOPSIS

    use HTML::Perlish ':minimal';

    # $html is: <div id="main"><p>Something, huh?</p></div>
    my $html = div { id gets 'main'; p { 'Something, huh?' } };

=head1 DESCRIPTION

A quick and dirty set of helper functions to make generating small bits of
HTML a little less tedious.

=head1 USAGE

Each supported HTML tag

=head1 EXPORTED FUNCTIONS

Each tag we handle is capable of being exported, and called with a coderef.
This coderef is excuted, and the return is wrapped in the tag.  Attributes on
the tag can be set from within the coderef by using L<gets>, a la C<id gets
'foo'>.

=head2 Export Groups

=head3 all

Everything.  (Well, for a given definiton of everything, at least.)

=head3 minimal

A basic set of the most commonly used tags: C<h1>..C<h4>, C<div>, C<p>,
C<img>, C<script>

=head3 moose_safe

Everything, except tags that would conflict with L<Moose> sugar (currently
C<meta>).

=head1 ACKNOWLEDGEMENTS

This package was inspired by L<Template::Declare::Tags>...  Thanks! :)

=head1 SEE ALSO

L<HTML::Tiny>
L<Template::Declare::Tags>.

=cut

