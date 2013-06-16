package Pudge::SonyEntertainmentNetwork::Asset;

use warnings;
use strict;
use feature ':5.10';

use Carp;
use Data::Dumper; $Data::Dumper::Sortkeys=1;
use Date::Parse;

use Pudge::SonyEntertainmentNetwork;
use Pudge::SonyEntertainmentNetwork::DownloadItem;
use Pudge::SonyEntertainmentNetwork::DownloadList;

use base 'Class::Accessor';
__PACKAGE__->mk_ro_accessors(qw(
    sen id name release_date content_type age_limit provider_name long_desc
));

__PACKAGE__->mk_accessors(qw(
    download_item
));

my @md = qw(
    genre topic concept_source video_style reputation scenario audience story_type mood setting_physical_environment visual_style setting_time_period setting_actual_location
    playable_platform game_feature perspective play_type number_of_players
);
__PACKAGE__->mk_ro_accessors(@md);

sub new {
    my($class, $data, $opts) = @_;

    croak "no data provided\n" unless $data;

    $opts->{sen} ||= Pudge::SonyEntertainmentNetwork->new;

    if ($data && !ref $data) {
        $data = $opts->{sen}->get_product_data($data);
    }

    my $self = bless $data, $class;
    croak "no id found\n" unless $self->{id};
    $self->{sen} ||= $opts->{sen};
    $self->{content_type} = $self->{game_contentType};
    $self->release_date( $self->release_date ); # fix to epoch

    for my $t (@md) {
        if ($self->{metadata}{$t}{values}) {
            $self->{$t} = $self->{metadata}{$t}{values};
        }
    }

    $self;
}

sub download_item {
    my($self) = @_;
    $self->sen->download_list->by_id($self->id);
}

sub _date {
    my($self, $key, $date) = @_;
    if ($date) {
        $date = str2time($date) if $date =~ /\D/;
        $self->SUPER::set($key, $date);
        return $date;
    }
    $self->SUPER::get($key);
}

sub release_date {
    my($self, $date) = @_;
    $self->_date(release_date => $date);
}

sub add_download {
    my($self) = @_;
    $self->sen->add_download($self->id);
}

sub image {
    my($self) = @_;
    $self->sen->get_product_image($self->id);
}

1;

__END__
