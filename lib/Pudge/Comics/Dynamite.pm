package Pudge::Comics::Dynamite;

use warnings;
use strict;
use feature ':5.10';

use Data::Dumper; $Data::Dumper::Sortkeys=1;
use Date::Parse 'str2time';
use Encode qw(from_to);

use base 'Pudge::Comics';

sub new {
    my($class, $parent, $opts) = @_;
    $opts ||= {};

    my $self = bless {
        mech        => $parent->mech,
        %$opts
    }, $class;

    $self;
}


sub dh_fixstr {
    $_ = shift;
    s/ TPB$//;
    s/\. \. \./.../g; # lame
    s/\(.+?\s+collection\)\s*$//; # "hardcover" etc.
    from_to($_, 'cp1250', 'utf8');
    $_;
}

sub get_item {
    my($self, $item_link, $tree, $book) = @_;
    my $src = 'Dynamite';

    # URL
    $book->{url} = $item_link;
    # TITLE
    $self->find_title($tree, $book, 'title');
    $book->{title} = dh_fixstr($book->{title});
    print "$book->{title}: $item_link\n";

    # SERIES
    $self->find_series($tree, $book);
    # DESC
    $self->find_desc($tree, $book, 'product-description', $src);
    $book->{desc} = dh_fixstr($book->{desc});
    # MISC / PRICE
    $self->finddh_misc($tree, $book);
    # IMG
    $self->find_img($tree, $book, 'product_img');
    # PUBLISHER
    $book->{publisher} = $src;
    # CREATORS
    $self->finddh_creators($tree, $book);
    # GENRES
    $self->finddh_genres($tree, $book);

    $book->{edition} ||= [];
    push @{$book->{edition}}, $src;
}

sub finddh_creators {
    my($self, $item, $book) = @_;

    $book->{creators} = [];

    my @creators = $item->find_by_attribute(class => 'product_details')
             ->find_by_tag_name('dd');

    for my $creator (@creators) {
        my $content = $self->item_content($creator);
        if (ref $content) {
            $content = $self->item_content($content);
        }
        my @content = map { s/^\s*and\s*//; dh_fixstr($_) } split /\s*,\s*/, $content;
        push @{$book->{creators}}, @content;
    }

    $book->{creators};
}

sub finddh_genres {
    my($self, $item, $book) = @_;

    my @genres =  $item->find_by_attribute(class => 'genre')
             ->find_by_tag_name('a');
    $book->{genres} = [ map { dh_fixstr($self->item_content($_)) } @genres ];
}

sub finddh_misc {
    my($self, $item, $book) = @_;
    # pages, published, audience, price, height, width, isbn

    my $dt;
    for my $foo ($item->find_by_attribute(class => 'product-meta')->find_by_tag_name('dt', 'dd')) {
        if ($foo->tag eq 'dt') {
            $dt = $self->item_content($foo);
        }
        elsif ($foo->tag eq 'dd') {
            if ($dt =~ /\bDate\b/) {
                $book->{published} = str2time($self->item_content($foo));
            }
            elsif ($dt =~ /\bFormat\b/) {
                my $str = $self->item_content($foo);
                if ($str =~ /\b([\d.\/ ]+?)\s*"\s*x\s*([\d.\/ ]+?)\s*"/) {
                    $book->{width} = $1;
                    $book->{height} = $2;
                    for ($book->{width}, $book->{height}) {
                        s|\s+(\d+)\s*/\s*(\d+)$|my $x = sprintf('%.02f', $1/$2); $x =~ s/^0\.//; ".$x"|e;  # fix 5/8 to decimal
                    }
                }
                if ($str =~ /\b(\d+)(?:pg| Pages)/i) {
                    $book->{pages} = $1;
                }
            }
            elsif ($dt =~ /\bPrice\b/) {
                $book->{price} = $self->item_content($foo);
            }
            elsif ($dt =~ /\bAge\b/) {
                $book->{audience} = $self->item_content($foo);
                if ($book->{audience} =~ /^\d+$/) {
                    $book->{audience} .= '+ Only';
                }
            }
            # this is dangerous because someone could use the ISBN
            # to "reload" from Amazon, blowing away all everything
#             elsif ($dt =~ /\bISBN-10\b/) {
#                 # only set if not already set
#                 $book->{isbn} //= $self->item_content($foo);
#             }
#             elsif ($dt =~ /\bISBN-13\b/) {
#                 # override if already set
#                 $book->{isbn} = $self->item_content($foo);
#             }
        }
    }

}



"Free as in comics";
