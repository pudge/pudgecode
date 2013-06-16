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
    verify_download_list
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
    use_ok('Pudge::SonyEntertainmentNetwork::DownloadList');
    use_ok('Pudge::SonyEntertainmentNetwork::DownloadItem');
    use_ok('Pudge::SonyEntertainmentNetwork');
}

sub verify_download_list {
    my $sen = Pudge::SonyEntertainmentNetwork->new({ local_path => "$Bin/sen/" });
    my $dl = $sen->download_list;

    ok($dl && $dl->isa('Pudge::SonyEntertainmentNetwork::DownloadList'), 'Got list');
    ok($dl->sen && $dl->sen->isa('Pudge::SonyEntertainmentNetwork'), 'Got sen object');

    is($dl->size, 2, 'Got list of correct size');
    is(scalar @{$dl->list}, 2, 'Got list of correct size');
    is(scalar keys %{$dl->map}, 2, 'Got list of correct size');

    for my $i (0 .. $#{$dl->list}) {
        my $di = $dl->by_idx($i);
        ok($di && $di->isa('Pudge::SonyEntertainmentNetwork::DownloadItem'), 'Got item by idx');
        like($di->entitlementId, qr/^[A-Z0-9_-]+$/, 'Check value');

        my $dii = $dl->by_id($di->entitlementId);
        ok($dii && $dii->isa('Pudge::SonyEntertainmentNetwork::DownloadItem'), 'Got item by id');
        is($di->entitlementId, $dii->entitlementId, 'Check values are same');
    }

    my $new_data = [ $dl->by_idx(1) ];
    $dl->list($new_data);

    is($dl->size, 1, 'Got shrunk list of correct size');
    is(scalar @{$dl->list}, 1, 'Got shrunk list of correct size');
    is(scalar keys %{$dl->map}, 1, 'Got shrunk list of correct size');
    for my $di (@{$dl->list}) {
        ok($di && $di->isa('Pudge::SonyEntertainmentNetwork::DownloadItem'), 'Got item');
    }

    my $a1 = $dl->by_idx(0);
    ok($a1 && $a1->isa('Pudge::SonyEntertainmentNetwork::DownloadItem'), 'Got item');

    my $a2 = $dl->by_id($a1->id);
    ok($a2 && $a2->isa('Pudge::SonyEntertainmentNetwork::DownloadItem'), 'Got item');

    is($a1->name, $a2->name, 'Same content');
    is($a1->productId, $a2->productId, 'Same content');
    is($a1->entitlementId, $a2->entitlementId, 'Same content');
}

