package Pudge::SonyEntertainmentNetwork::DownloadItem;

use warnings;
use strict;
use feature ':5.10';

use Carp;
use Date::Parse;

use Pudge::SonyEntertainmentNetwork;

use base 'Class::Accessor';
__PACKAGE__->mk_ro_accessors(qw(
    sen id productId entitlementId availableDate contentName name firstPlayExpiration
));

__PACKAGE__->mk_accessors(qw(
    asset
));

sub new {
    my($class, $data, $opts) = @_;

    my $self = bless $data, $class;

    $self->{id} ||= $data->{entitlementId} || $data->{productId};
    croak "no id found\n" unless $self->{id};

    $self->{name} ||= $data->{contentName};
    $self->availableDate( $self->availableDate ); # fix to epoch

    $self->{sen} ||= $opts->{sen} ||= Pudge::SonyEntertainmentNetwork->new;
    $self;
}

sub asset {
    my($self, $asset) = @_;

    if ($asset) {
        $self->SUPER::set(asset => $asset);
    }

    $asset ||= $self->SUPER::get('asset');

    if (!$asset) {
        $asset = $self->sen->get_product_data( $self->id );
        $self->SUPER::set(asset => $asset) if $asset;
    }

    $asset;
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

sub availableDate {
    my($self, $date) = @_;
    $self->_date(availableDate => $date);
}

1;

__END__
