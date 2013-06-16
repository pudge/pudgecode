#!/usr/local/bin/perl
use warnings;
use strict;
use feature ':5.10';

use Test::More;

use FindBin qw($Bin);
use lib $Bin;
use lib "$Bin/..";

my @tests = qw(
    uses
    verify_download_item
);

for my $test (@tests) {
    no strict 'refs';
    set_up();
    subtest $test => \&{$test};
    tear_down();
}

done_testing();

sub set_up {
}

sub tear_down {
}

sub uses {
    use_ok('Pudge::SonyEntertainmentNetwork::Asset');
    use_ok('Pudge::SonyEntertainmentNetwork::DownloadList');
    use_ok('Pudge::SonyEntertainmentNetwork::DownloadItem');
    use_ok('Pudge::SonyEntertainmentNetwork');
}

sub verify_download_item {
    my $sen = Pudge::SonyEntertainmentNetwork->new({ local_path => "$Bin/sen/" });
    my $dl = $sen->download_list;
    my @items = @{ $dl->items };

    for my $i (0 .. $#items) {
        my $di = $items[$i];
        ok($di && $di->isa('Pudge::SonyEntertainmentNetwork::DownloadItem'), 'Got item');
        ok($di->sen && $di->sen->isa('Pudge::SonyEntertainmentNetwork'), 'Got sen object');

        # sen id productId entitlementId availableDate contentName name
        is($di->name, $dl->by_idx($i)->{contentName}, 'name/contentName is the same');
        for my $x (qw(productId entitlementId availableDate contentName)) {
            is($di->$x, $dl->by_idx($i)->{$x}, "$x is the same");
        }
        like($di->availableDate, qr/^\d+$/, 'availableDate is epoch time');

        my $asset = $di->asset;
        {local $TODO = 'finish asset implementation';
        ok($asset);}
    }

}

