#!/usr/local/bin/perl
use warnings;
use strict;
use feature ':5.10';

use utf8;
use Date::Format;
use Data::Dumper; $Data::Dumper::Sortkeys=1;
use JSON::XS 'encode_json';
use Encode qw(from_to encode decode decode_utf8);
use HTML::Entities;
use FindBin '$Bin';

use Pudge::DeliciousLibrary;

my $dl = new Pudge::DeliciousLibrary;
my $export = "$Bin/";
my $images = "${export}images/";
my $covers = "${images}covers/";
my $thumbs = "${images}thumbs/";

mkdir $images;
mkdir $covers;
mkdir $thumbs;

my $date_fmt = '%Y-%m-%d';

my(%map, @rows);
my $d = $dl->dbh->selectall_arrayref(
    'select * from ZABSTRACTMEDIUM where Z_ENT=3 and ZTYPE in ("VideoGame", "Book", "Movie", "Album")',
{ Slice => {} });

for my $i (@$d) {
    # none of these are used anymore, not playable or worth mentioning
    next if $i->{ZTYPE} eq 'VideoGame' && $i->{ZPLATFORMSCOMPOSITESTRING} && $i->{ZPLATFORMSCOMPOSITESTRING} =~ /(?:Electronic Game|Mac)/;
    # all my physical movies and music are digitized now, and will be input via
    # iTunes / scripts (not the DL3 iTunes import, which doesn't do what I want)
    # (it'd be nice to come up with a way to get my iBooks and Kindle data too)
#    next if $i->{ZTYPE} =~ /^(?:Movie|Album)/ && (!$i->{ZFORMATSINGULARSTRING} || $i->{ZFORMATSINGULARSTRING} ne 'Digital');

    my %r = (
        pk          => $i->{Z_PK},
        serial      => $i->{ZSERIALNUMBER},
        isbn        => $i->{ZISBN},
        ean         => $i->{ZEAN},
        type        => $i->{ZTYPE},
        title       => decode_utf8($i->{ZTITLE}),
        url         => $i->{ZASSOCIATEDURL},
        min_players => $i->{ZMINIMUMPLAYERS},
        max_players => $i->{ZMAXIMUMPLAYERS},
        minutes     => $i->{ZMINUTES},
        pages       => $i->{ZPAGES},
        audience    => _audience($i->{ZAUDIENCERECOMMENDEDAGESINGULARSTRING}),
        platforms   => _plat($i->{ZPLATFORMSCOMPOSITESTRING}),
        edition     => _list($i->{ZEDITIONSCOMPOSITESTRING}),
        format      => $i->{ZFORMATSINGULARSTRING},
        features    => _list($i->{ZFEATURESCOMPOSITESTRING}),
        creators    => _list($i->{ZCREATORSCOMPOSITESTRING}),
        genres      => _list($i->{ZGENRESCOMPOSITESTRING}),
        publishers  => _list($i->{ZPUBLISHERSCOMPOSITESTRING}),
        actors      => _list($i->{ZACTORSCOMPOSITESTRING}),
        published   => _date($i->{ZPUBLISHDATE}),
        purchased   => _date($i->{ZPURCHASEDATE}),
        img         => !!$i->{ZCOVERIMAGEDATAHOLDER},
    );

    my @searchStrs;
    for my $z (qw(ZFEATURESCOMPOSITESTRING ZCREATORSCOMPOSITESTRING
        ZGENRESCOMPOSITESTRING ZPUBLISHERSCOMPOSITESTRING
        ZACTORSCOMPOSITESTRING ZEDITIONSCOMPOSITESTRING
        ZFORMATSINGULARSTRING)) {
        push @searchStrs, $i->{$z} if defined $i->{$z};
    }

    my $thumb = "$thumbs$r{pk}.jpg";
    my $image = "$covers$r{pk}.jpg";
    if ($i->{ZCOVERIMAGEDATAHOLDER} && ! -f $image) {
        my $g = $dl->dbh->selectall_arrayref('select * from ZCOVERIMAGEDATAHOLDER where Z_PK=?', { Slice => {} }, $i->{ZCOVERIMAGEDATAHOLDER});
        open my $ih, '>', $image or warn "Can't open $image: $!\n";
        print $ih $g->[0]{ZCOMPRESSEDIMAGEDATA};

        system("cp $image $thumb >/dev/null 2>&1");
        system("sips --resampleHeight 60 $thumb >/dev/null 2>&1") if -e $thumb;
    }
    elsif ($i->{ZCOVERIMAGETINYIMAGEDATA} && ! -f $thumb) {
        open my $th, '>', $thumb or warn "Can't open $thumb: $!\n";
        print $th $i->{ZCOVERIMAGETINYIMAGEDATA};
    }
    elsif (! -f $thumb) {
        undef $thumb;
    }


    my $g = $dl->dbh->selectall_arrayref('select * from ZABSTRACTSYNOPSIS where ZCONCEPTUALMEDIUM = ?', { Slice => {} }, $i->{Z_PK});
    my $desc;
    for my $d (@$g) {
        $desc .= sprintf(qq{<div class="item_desc">%s</div><div class="item_desc_source">&mdash; %s</div>},
            decode_utf8($d->{ZHTMLSTRING}), decode_utf8($d->{ZSOURCE})
        );
    }
    $r{desc} = $desc;
#     if ($desc) {
#         push @searchStrs, $desc;
#     }
    s/<.+?>/ /g for @searchStrs;

    $map{ $r{pk} } = \%r;
    push @rows, [
        $r{pk},
        ($thumb
            ? '<img class="thumb show-info" id="pk_' . $r{pk} . '" src="images/thumbs/' . $r{pk} . '.jpg">'
            : '<span class="show-info" id="pk_' . $r{pk} . '">&nbsp;</span>'
        ),
        '<span class="show-info">' . $r{title} . '</span>',
        $r{audience},
        join(', ', @{$r{platforms}}),
        $r{type},
        join(' ', @searchStrs)
    ];
}

open my $fh, '>', "${export}data.js" or die $!;
print $fh "libraryArray = " . encode_json(\@rows) . ";\n";
print $fh "libraryHash = " . encode_json(\%map) . ';';
close $fh;

sub _audience {
    my $a = shift || '';

    $a eq  6 ? 'E' :
    $a eq 10 ? 'E10+' :
    $a eq 13 ? 'T' :
    $a eq 17 ? 'M' :

    $a =~ /\bEveryone.?10/ ? 'E10+' :
    $a =~ /\bEveryone\b/ ? 'E' :
    $a =~ /\bTeen\b/ ? 'T' :
    $a =~ /\bMature\b/ ? 'M' :

    $a =~ /\bG\b/ ? 'G' :
    $a =~ /\bPG\b/ ? 'PG' :
    $a =~ /\bPG-?13\b/ ? 'PG-13' :
    $a =~ /\bR\b/ ? 'R' :
    $a =~ /\b(?:NR|Unrated)\b/ ? 'NR' :

    $a;
}

sub _platform {
    my $p = shift || '';
    $p =~ /playstation\s*4/i ? 'PS3' :
    $p =~ /playstation\s*3/i ? 'PS3' :
    $p =~ /playstation\s*2/i ? 'PS2' :
    $p =~ /PS\s*P/i ? 'PSP' :
    $p =~ /PS\s*V/i ? 'PSV' :
    $p =~ /playstation/i ? 'PS' :
    $p =~ /wii/i ? 'Wii' :
    $p =~ /DS/i ? 'DS' :
    $p;
}

sub _plat { [ $_[0] ? map { _platform($_) } split /\n/, decode_utf8($_[0]) : () ] }
sub _list { [ $_[0] ? split /\n/, decode_utf8($_[0]) : () ] }
sub _date { defined $_[0] ? time2str($date_fmt, $_[0]+978307200) : undef } # core data timestamps begin at unix epoch + 31 years
