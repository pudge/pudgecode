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
my $images = "${Bin}images/";
my $thumbs = "${images}thumbs/";

mkdir $images;
mkdir $thumbs;

my @data;
my $d = $dl->dbh->selectall_arrayref(
    'select * from ZABSTRACTMEDIUM where ZTYPE="VideoGame" and Z_ENT=3',
{ Slice => {} });

for my $i (@$d) {
    next if $i->{ZPLATFORMSCOMPOSITESTRING} && $i->{ZPLATFORMSCOMPOSITESTRING} =~ /(?:Electronic Game|Mac)/;

# synopsis!

    my %r = (
        pk          => $i->{Z_PK},
        serial      => $i->{ZSERIALNUMBER},
        title       => decode_utf8($i->{ZTITLE}),
        url         => $i->{ZASSOCIATEDURL},
        min_players => $i->{ZMINIMUMPLAYERS},
        max_players => $i->{ZMAXIMUMPLAYERS},
        audience    => _audience($i->{ZAUDIENCERECOMMENDEDAGESINGULARSTRING}),
        platforms   => _list($i->{ZPLATFORMSCOMPOSITESTRING}),
        edition     => _list($i->{ZEDITIONSCOMPOSITESTRING}),
        format      => $i->{ZFORMATSINGULARSTRING},
        features    => _list($i->{ZFEATURESCOMPOSITESTRING}),
        creators    => _list($i->{ZCREATORSCOMPOSITESTRING}),
        genres      => _list($i->{ZGENRESCOMPOSITESTRING}),
        publishers  => _list($i->{ZPUBLISHERSCOMPOSITESTRING}),
        published   => time2str('%C', _date($i->{ZPUBLISHDATE})),
        purchased   => time2str('%C', _date($i->{ZPURCHASEDATE})),
    );

    if ($i->{ZCOVERIMAGETINYIMAGEDATA}) {
        my $thumb = "$thumbs$r{pk}.jpg";
        open my $th, '>', $thumb or warn "Can't open $thumb: $!\n";
        print $th $i->{ZCOVERIMAGETINYIMAGEDATA};
    }

    if ($i->{ZCOVERIMAGEDATAHOLDER}) {
        my $g = $dl->dbh->selectall_arrayref('select * from ZCOVERIMAGEDATAHOLDER where Z_PK=?', { Slice => {} }, $i->{ZCOVERIMAGEDATAHOLDER});
        my $image = "$images$r{pk}.jpg";
        open my $ih, '>', $image or warn "Can't open $image: $!\n";
        print $ih $g->[0]{ZCOMPRESSEDIMAGEDATA};
    }

    if ($i->{ZCOVERIMAGEDATAHOLDER}) {
        my $g = $dl->dbh->selectall_arrayref('select * from ZABSTRACTSYNOPSIS where ZCONCEPTUALMEDIUM = ?', { Slice => {} }, $i->{Z_PK});
        my $desc;
        for my $d (@$g) {
            $desc .= sprintf(qq{<div class="item_desc">%s</div><div class="item_desc_source">&mdash; %s</div>},
                decode_utf8($d->{ZHTMLSTRING}), decode_utf8($d->{ZSOURCE})
            );
        }
        $r{desc} = $desc;
    }

    push @data, \%r;
}

open my $fh, '>', "${export}data.js" or die $!;
print $fh "libraryData = " . encode_json(\@data);
close $fh;

sub _audience {
    my $a = shift || '';
    $a eq  6 ? 'Everyone' :
    $a eq 10 ? 'Everyone 10+' :
    $a eq 13 ? 'Teen' :
    $a eq 17 ? 'Mature' :
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
sub _date { defined $_[0] ? $_[0]+978307200 : undef } # core data timestamps begin at unix epoch + 31 years
