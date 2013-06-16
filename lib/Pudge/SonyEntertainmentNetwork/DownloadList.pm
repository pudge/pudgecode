package Pudge::SonyEntertainmentNetwork::DownloadList;

use warnings;
use strict;
use feature ':5.10';

use Carp;

use Pudge::SonyEntertainmentNetwork;
use Pudge::SonyEntertainmentNetwork::DownloadItem;

use base 'Class::Accessor';
__PACKAGE__->mk_accessors(qw(
    list map size
));

__PACKAGE__->mk_ro_accessors(qw(
    sen
));

sub new {
    my($class, $list, $opts) = @_;

    croak "no list provided\n" unless $list && ref $list;

    my $self = bless {}, $class;
    $self->{sen} ||= $opts->{sen} ||= Pudge::SonyEntertainmentNetwork->new;

    $self->list($list);

    $self;
}

sub list {
    my($self, $dl) = @_;

    if ($dl) {
        my(@list, %map);
        for my $d (@$dl) {
            my $obj = Pudge::SonyEntertainmentNetwork::DownloadItem->new($d, { sen => $self->sen });
            push @list, $obj;
            $map{$obj->id} = $obj;
        }
        $self->size(scalar @list);
        $self->map(\%map);
        $self->SUPER::set(list => \@list);
    }

    $self->SUPER::get('list');
}

sub by_idx {
    my($self, $i) = @_;
    return $self->list->[$i];
}

sub by_id {
    my($self, $id) = @_;
    return $self->map->{$id};
}

sub items {
    my($self, $start, $length) = @_;
    $start  //= 0;
    $length //= $self->size-1;

    return [ @{ $self->list }[$start .. ($start + $length)] ];
}

1;

__END__
