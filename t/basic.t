use strict;
use warnings;

use Test::More 0.88;

use List::MoreUtils 'uniq';
use HTML::Tiny;
use HTML::Perlish ':all';
use Template::Declare::TagSet::HTML ();
use Try::Tiny;

my $h = HTML::Tiny->new;

subtest 'tags check against HTML::Tiny output' => sub {

    # not in HTML::Tiny -- not investigated yet (utoh -- no html5 elements?)
    my %SKIPS = map { $_ => 1 } qw{ applet area article };

    my @tags = uniq sort
        grep { ! $SKIPS{$_} }
        @{Template::Declare::TagSet::HTML::get_tag_list()}
        ;

    for my $tag (@tags) {

        can_ok('HTML::Perlish', $tag);

        is eval("$tag {}"),                             try { $h->$tag() }, "simple $tag works";
        is eval("$tag { one gets 'two' }"),             try { $h->$tag({ one => 'two'}) }, "$tag w/attribute";
        is eval("$tag { 'content!' }"),                 try { $h->$tag('content!') }, "$tag w/content";
        is eval("$tag { one gets 'two'; 'content!' }"), try { $h->$tag({ one => 'two'}, 'content!') }, "$tag w/attribute and content";

    }

};

subtest "check script, as it's picky" => sub {

    is
        script { bip gets 'baz' },
        '<script bip="baz"></script>',
        'script() checks out',
        ;
};

done_testing;
