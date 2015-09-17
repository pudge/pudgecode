package Pudge::Comics::ComiXology;

use warnings;
use strict;
use feature ':5.10';

use HTML::TreeBuilder;
use Data::Dumper; $Data::Dumper::Sortkeys=1;
use Date::Parse 'str2time';

use base 'Pudge::Comics';
use base 'Class::Accessor';
__PACKAGE__->mk_accessors(qw(
));
__PACKAGE__->mk_ro_accessors(qw(
    base_url
));

sub new {
    my($class, $parent, $opts) = @_;
    $opts ||= {};

    my $self = bless {
        base_url    => 'https://www.comixology.com/',
        mech        => $parent->mech,
        dl          => $parent->dl,
        %$opts
    }, $class;

    $self;
}

sub fetch_and_store_series {
    my($self) = @_;

    my $url = $self->base_url;

    for my $type (qw(Comics Archive)) { # Comics Archive
        my $type_path_list = $type eq 'Comics' ? 'series' : lcfirst($type);
        my $type_path_book = $type eq 'Comics' ? 'books' : $type_path_list;

        if ($type eq 'Archive' && $Pudge::Comics::KEEP_IDS) {
            for my $id (@Pudge::Comics::KEEP_IDS) {
                print                          "${url}my-${type_path_book}/sid/$id","\n"
                    if $self->debug > 1;
                $self->getcx_series('Archive', "${url}my-${type_path_book}/sid/$id");
            }
            next;
        }

        my $letters = $self->{letters} // ['A' .. 'Z', '%23'];  # %23 = '#'
        for my $letter (@$letters) {
            my %seen;
            PAGES: for my $I (1..99) {
                print           "${url}my-${type_path_list}?my${type}List_alpha=${letter}&my${type}List_pg=$I","\n"
                    if $self->debug;
                $self->mech_get("${url}my-${type_path_list}?my${type}List_alpha=${letter}&my${type}List_pg=$I");

                my %links = map { $_->url => $_ } $self->mech->find_all_links(url_regex => qr|^${url}my-${type_path_book}/sid/\d+$|);
                last unless keys %links;
                for my $series_link (sort keys %links) {
                    last PAGES if $seen{$series_link}++;
                    $self->getcx_series($type, $series_link);
                }
            }
        }
    }
}


sub getcx_series {
    my($self, $type, $series_link) = @_;
    print $series_link, "\n" if $self->debug > 2;

    return if $Pudge::Comics::KEEP_IDS && $type eq 'Archive' && $series_link !~ m|/sid/$Pudge::Comics::KEEP_IDS$|;

    print $series_link, "\n" if $self->debug == 2;

    my(%seen2, %seen2_redo);
    PAGES2: for my $J (1..99) {
        $self->mech_get($series_link . "?SeriesComics_pg=$J");
        my $content = $self->content;
        return if $content =~ /Recently Purchased/;

        my $tree = HTML::TreeBuilder->new_from_content($content);
        my @items = $tree->find_by_attribute(class => 'item-container');
        for my $item (@items) {
            my $book = {};

            print Dumper $item if $self->debug > 4;

            # URL
            my $item_link = $self->find_link($item, $book);
            next if $Pudge::Comics::SKIP_IDS && $type eq 'Archive' && $item_link =~ m|/digital-comic/$Pudge::Comics::SKIP_IDS$|;
            last PAGES2 if $seen2{$item_link}++;

            my $return = eval {
                # TITLE
                $self->find_title($item, $book);

                print "$book->{title}: $item_link\n" if $self->debug > 1;

                return if $Pudge::Comics::SKIP_STRINGS && $type eq 'Archive' && $book->{title} =~ /\b$Pudge::Comics::SKIP_STRINGS\b/;
                return if $self->dl->fetch($item_link);

                print "$book->{title}: $item_link\n" if $self->debug <= 1;

                $book->{experienced} = 1 if $type eq 'Comics';

                # SERIES
                $self->find_series($item, $book);

                $self->mech_get($item_link);
                my $content = $self->content;
                return if ($content =~ m|src="/assets/imgs/badges/(?:FR).png"|);
                my $tree = HTML::TreeBuilder->new_from_content($content);

                if ($tree->find_by_attribute(class => 'errorPage')) {
                    $book->{url} = $series_link;
                    # CREATORS
                    $self->find_creators($item, $book);
                    # DESC
                    $self->find_desc($item, $book);
                    # IMG
                    $self->find_img($item, $book);
                    # GENRES
                    $book->{genres} = ['Unavailable'];
                }
                else {
                    $book->{url} = $item_link;
                    # DESC
                    $self->find_desc($tree, $book);
                    # IMG
                    $self->find_img($tree, $book, 'cover');
                    # PUBLISHER
                    $self->findcx_publisher($tree, $book);
                    # CREATORS
                    $self->findcx_creators($tree, $book);
                    # GENRES
                    $self->findcx_genres($tree, $book);
                    # MISC
                    $self->findcx_misc($tree, $book);
                    # PRICE
                    $self->findcx_price($tree, $book);
                }

                $book->{edition} = [ 'comiXology' ];
                $self->save_book($book, $item_link);
                return 1;
            };
            my $err = $@;
            next if $return;
            if ($err) {
                warn "Retrying: $err\n";
                if (!$seen2_redo{$item_link}++) { # retry only once
                    delete $seen2{$item_link};
                    redo;
                }
            }
        }
    }
}


sub get_item {
    my($self, $item_link, $tree, $book) = @_;

    # URL
    $book->{url} = $item_link;
    # TITLE
    $self->findcx_title($tree, $book);
    print "$book->{title}: $item_link\n";

    # SERIES
    $self->find_series($tree, $book);
    # DESC
    $self->find_desc($tree, $book);
    # IMG
    $self->find_img($tree, $book, 'cover');
    # PUBLISHER
    $self->findcx_publisher($tree, $book);
    # CREATORS
    $self->findcx_creators($tree, $book);
    # GENRES
    $self->findcx_genres($tree, $book);
    # MISC
    $self->findcx_misc($tree, $book);
    # PRICE
    $self->findcx_price($tree, $book);

    $book->{edition} ||= [];
    push @{$book->{edition}}, 'comiXology';
}




sub findcx_title {
    my($self, $item, $book) = @_;
    my(@foo) = $item->find_by_attribute(class => 'hinline');
    $book->{title} = $self->item_content($foo[-1]);
}

sub findcx_creators {
    my($self, $item, $book) = @_;

    my @names;
    my $credits = $item->find_by_attribute(class => 'credits');
    for my $foo ($credits->find_by_tag_name('a')) {
        if ($foo->attr('href') =~ /creator/) {
            push @names, $self->item_content($foo);
        }
    }
    $book->{creators} =  \@names;
}

sub findcx_genres {
    my($self, $item, $book) = @_;

    my @genres;
    my $credits = $item->find_by_attribute(class => 'credits');
    for my $foo ($credits->find_by_tag_name('a')) {
        if ($foo->attr('href') =~ /genre/) {
            push @genres, $self->item_content($foo);
        }
    }
    $book->{genres} =  \@genres;
}

sub findcx_publisher {
    my($self, $item, $book) = @_;
   
    $book->{publisher} =  $self->item_content(
        $item->find_by_attribute(class => 'publisher')
             ->find_by_attribute(class => 'textLink')
             ->find_by_attribute(class => 'name')
    );
}

sub findcx_price {
    my($self, $item, $book) = @_;

    $book->{price} = $self->item_content(
        $item->find_by_attribute(class => 'item-full-price')
            ||
        $item->find_by_attribute(class => 'item-price')
#             ||
#         $item->find_by_attribute(class => 'org_price')
#             ||
#         $item->find_by_attribute(class => 'price')
#             ||
#         $item->find_by_attribute(class => 'price ')
    );
    $book->{price} = '$0' if $book->{price} =~ /FREE/;
}

sub findcx_misc {
    my($self, $item, $book) = @_;
    # pages, published, audience

    my $last;
    for my $foo ($item->find_by_tag_name('h4', 'div')) {
        my $class = $foo->attr('class');
        next unless $class;
        if ($class eq 'subtitle') {
            $last = $self->item_content($foo);
        }
        elsif ($class eq 'aboutText') {
            my $text = $self->item_content($foo);
            # PAGE COUNT
            if ($last eq 'Page Count') {
                $text =~ s/\D+//g;
                $book->{pages} = $text;
            }
            # RELEASE DATE
            elsif ($last eq 'Print Release Date') {
                $book->{published} = str2time($text);
            }
            # RELEASE DATE
            elsif ($last eq 'Digital Release Date' && !$book->{published}) {
                $book->{published} = str2time($text);
            }
            # RATING
            elsif ($last eq 'Age Rating') {
                $book->{audience} = Pudge::Comics::fixstr($text);
            }
        }
    }
}


"Free as in comics";
