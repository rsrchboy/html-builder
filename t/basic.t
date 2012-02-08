use strict;
use warnings;

use Test::More 0.88;
use List::MoreUtils 'uniq';
use HTML::Perlish ':all';

my @tags = HTML::Perlish::our_tags();
my %SKIPS = map { $_ => 1 } (); #qw{ applet area article };

for my $tag (@tags) {

    subtest "checking: $tag" => sub {

        plan skip_all => "$tag needs work" if $SKIPS{$tag};

        can_ok('HTML::Perlish', $tag);

        is eval("$tag {}"),
            qq{<$tag></$tag>}, "simple $tag works";
        is eval("$tag { one gets 'two' }"),
            qq{<$tag one="two"></$tag>}, "$tag w/attribute";
        is eval("$tag { 'content!' }"),
            qq{<$tag>content!</$tag>}, "$tag w/content";
        is eval("$tag { one gets 'two'; 'content!' }"),
            qq{<$tag one="two">content!</$tag>}, "$tag w/attribute and content";
        #is eval("$tag { attributes one => 'two', three => 4 }"),
        #    qq{<$tag one="two"></$tag>}, "$tag w/more attributes!";
        #note $@;
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
