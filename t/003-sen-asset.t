#!/usr/local/bin/perl
use warnings;
use strict;
use feature ':5.10';

use Test::More;

use FindBin qw($Bin);
use lib $Bin;
use lib "$Bin/..";

my %undef_md = map { $_ => 1 } qw(
    reputation scenario story_type setting_physical_environment
    setting_time_period setting_actual_location 
);

my @tests = qw(
    uses
    verify_asset
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

sub verify_asset {
    my $sen = Pudge::SonyEntertainmentNetwork->new({ local_path => "$Bin/sen/" });
    ok($sen && $sen->isa('Pudge::SonyEntertainmentNetwork'), 'Got SEN');

    my @ids = map { $_->id } @{ $sen->download_list->items };
    is(scalar @ids, 2, 'Found IDs');

    my $item = Pudge::SonyEntertainmentNetwork::Asset->new($ids[0], { sen => $sen });
    ok($item && $item->isa('Pudge::SonyEntertainmentNetwork::Asset'), 'Got asset');

    my $di  = $sen->download_list->by_idx(0);
    my $dii = $di->asset;
    ok($dii && $dii->isa('Pudge::SonyEntertainmentNetwork::Asset'), 'Got asset');


    for my $t (qw(id name release_date content_type age_limit provider_name long_desc)) {
        like($item->$t, qr/./, "$t has value");
        is($item->$t, $dii->$t, "$t has same value in both objects");
    }
    like($item->release_date, qr/^\d+$/, 'release_date is epoch time');

    for my $t (qw(genre topic concept_source video_style reputation scenario
        audience story_type mood setting_physical_environment visual_style
        setting_time_period setting_actual_location playable_platform
        game_feature perspective play_type number_of_players)) {
        if ($undef_md{$t}) {
            ok(!defined($item->$t), "$t is undefined");
            ok(!defined($dii->$t), "$t is undefined");
        }
        else {
            ok(ref($item->$t), "$t is reference");
            is_deeply($item->$t, $dii->$t, "$t has same value in both objects");
        }
    }



    my $itemdi = $item->download_item;
    for my $t (qw(id productId entitlementId availableDate contentName name)) {
        like($itemdi->$t, qr/./, "$t has value");
        is($itemdi->$t, $di->$t, "$t has same value in both objects");
    }

}


