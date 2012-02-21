package HTML::Builder;

# ABSTRACT: A declarative approach to HTML generation

use v5.10;

use strict;
use warnings;

use Capture::Tiny 0.15 'capture_stdout';
use HTML::Tiny;
use Sub::Install;
use List::MoreUtils 'uniq';

# debugging...
#use Smart::Comments;

our $IN_TAG;

=func our_tags

A unique, sorted list of the HTML tags we know about (and handle).

=func tag($tag_name, $code_ref)

The actual function responsible for handling the tagging.  All of the helper
functions pass off to tag() (e.g. C<div()> is C<sub div(&) { unshift 'div';
goto \&tag }>).

=cut

# HTML5 tags from:
# http://en.wikipedia.org/wiki/HTML5#Differences_from_HTML.C2.A04.01_and_XHTML.C2.A01.x
# 18 Feb 2012
#
# Other HTML tags from:
# http://www.w3schools.com/tags/default.asp
# 19 Feb 2012

=func html5_tags()

The list of tags we think are HTML5.

=func html_tags()

The list of tags we think are HTML ( < HTML5, that is).

=func depreciated_tags()

HTML elements considered to be depreciated.

=func our_tags()

The unique, sorted list of all tags returned by html5_tags() and html_tags().

=cut

# !--...--	Defines

sub html5_tags { qw{

    article aside audio bdo canvas command datalist details embed figcaption
    figure footer header hgroup keygen mark meter nav output progress rp rt
    ruby section source summary time video wbr

} }

# excl: s
sub depreciated_tags { qw{ applet basefont center dir font menu strike u xmp } }

sub conflicting_tags { {
    html_sub => 'sub',
    html_map => 'map',
    html_q   => 'q',
    html_tr  => 'tr',
} }

sub html_tags {

    # excl: sub map q tr

    return qw{

        a        abbr       acronym    address      area       b
        base     bdo        big        blockquote   body       br
        button   caption    cite       code         col        colgroup
        dd       del        dfn        div          dl         dt
        em       fieldset   form       frame        frameset   h1
        head     hr         html       i            iframe     img
        input    ins        kbd        label        legend     li
        link                meta       noframes     noscript   object
        ol       optgroup   option     p            param      pre
                 samp       script     select       small      span
                 strong     style                   sup        table
        tbody    td         textarea   tfoot        th         thead
        title               tt         ul           var

    };
}

sub minimal_tags {
    return ('h1'..'h5', qw{
        div span p img script br ul ol li style a
    });
}

sub our_tags {
    my @tags = (
        html5_tags(),
        html_tags(),
        depreciated_tags(),
        (keys %{ conflicting_tags() }),
    );
    return uniq sort @tags;
}

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

sub tag($&) {
    my ($tag, $inner_coderef) = @_;

    state $h = HTML::Tiny->new;

    ### @_
    my %attrs = ();

    # This is almost completely stolen from Template::Declare::Tags, and
    # completely terrifying in that it confirms my dark suspicions on how
    # it was achieved over there.
    no warnings 'once', 'redefine';
    local *gets::AUTOLOAD = _is_autoload_gen(\%attrs);
    my $inner = q{};
    my $stdout = capture_stdout { local $IN_TAG = 1; $inner .= $inner_coderef->() || q{} };

    my $return = $h->tag($tag, \%attrs, "$stdout$inner");

    ### $return
    if ($IN_TAG) {
        print $return;
        return q{};
    }
    else {
        return $return;
    }
}

use Sub::Exporter -setup => {

    exports => [ our_tags ],
    groups  => {

        default    => ':moose_safe',
        moose_safe => [ grep { ! /^(meta|with)/ } our_tags ],

        minimal     => sub { _generate_group([     minimal_tags ], @_) },
        html        => sub { _generate_group([        html_tags ], @_) },
        html5       => sub { _generate_group([       html5_tags ], @_) },
        depreciated => sub { _generate_group([ depreciated_tags ], @_) },
    },
};

sub _generate_group {
    my ($tags, $class, $group, $arg) = @_;

    return {
        map { my $tag = $_; $tag => sub(&) { unshift @_, $tag; goto \&tag } }
        @$tags
    };
}

my $_install = sub {
    my ($subname, $tag) = @_;
    $tag ||= $subname;
    Sub::Install::install_sub({
        code => sub(&) { unshift @_, $tag; goto \&tag },
        as   => $tag,
    });
};

my $conflict = conflicting_tags;
$_install->($_) for our_tags;
$_install->(@$_) for map { [ $_ => $conflict->{$_} ] } keys %$conflict;

!!42;

__END__

=head1 SYNOPSIS

    use HTML::Builder ':minimal';

    # $html is: <div id="main"><p>Something, huh?</p></div>
    my $html = div { id gets 'main'; p { 'Something, huh?' } };

=head1 DESCRIPTION

A quick and dirty set of helper functions to make generating small bits of
HTML a little less tedious.

=head1 USAGE

Each supported HTML tag takes a coderef, executes it, and returns the output
the coderef writes to STDOUT with the return value appended.

That is:

    div { say h1 { 'Hi there! }; p { "Nice day, isn't it?" } }

Generates:

    <div><h1>Hi there!</h1><p>Nice day, isn't it?</p></div>

Element attributes are handled by specifying them with C<gets>.  e.g.:

    div { id gets 'main'; 'Hi!' }

Generates:

    <div id="main">Hi!</div>

L<gets> may be specified multiple times, for multiple attributes.

=head2 Nested Tags

When one tag function is called from within another, the nested tag will print
its output to STDOUT rather than returning it.  That means that this:

    div { print h1 { 'Hi there! }; p { "Nice day, isn't it?" } }

...and this:

    div { h1 { 'Hi there! }; p { "Nice day, isn't it?" } }

Behave identically, from the perspective of the caller.

=head1 RENAMING EXPORTED FUNCTIONS

This package uses L<Sub::Exporter>, so you can take advantage of the features
that package provides.  For example, if you wanted to import the tags in the
'minimal' group, but wanted to prefix each function with 'html_', you could
do:

    use HTML::Builder -minimal => { -prefix => 'html_' };

=head1 EXPORTED FUNCTIONS

Each tag we handle is capable of being exported, and called with a coderef.
This coderef is executed, and the return is wrapped in the tag.  Attributes on
the tag can be set from within the coderef by using L<gets>, a la C<id gets
'foo'>.

=head2 Export Groups

=head3 :all

Everything.

Well, what C<@CGI::EXPORT_TAGS{qw{ :html2 :html3 :html4 }}> thinks is
everything, at any rate.

This isn't, perhaps, optimal, but I haven't run into any issues with it yet.
That being said, I'm open to changing our tags list, and where it's generated
from.

=head3 :minimal

A basic set of the most commonly used tags:

    h1..h4 div p img span script br ul ol li style a

=head3 :html5

HTML5 tags (C<article>, C<header>, C<nav>, etc) -- or at least what Wikipedia
thinks are HTML5 tags.

=head3 :moose_safe

Everything, except tags that would conflict with L<Moose> sugar (currently
C<meta>).

=head1 ACKNOWLEDGMENTS

This package was inspired by L<Template::Declare::Tags>... In particular, our
C<gets::AUTOLOAD> is pretty much a straight-up copy of Template::Declare::Tags'
C<is::AUTOLOAD>, with some modifications.  We also pass off to L<HTML::Tiny>,
and allow it to do the work of actually generating the output.  Thanks! :)

=head1 SEE ALSO

L<CGI> (in particular, C<%CGI::EXPORT_TAGS>)
L<HTML::Tiny>
L<Template::Declare::Tags>

=cut
