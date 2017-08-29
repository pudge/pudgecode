package Pudge::Comics::ComiXology;

use warnings;
use strict;
use feature ':5.10';
use Carp qw(confess);

use URI::Escape 'uri_escape';
use HTML::TreeBuilder;
use Data::Dumper; $Data::Dumper::Sortkeys=1;
use Date::Parse 'str2time';
use JSON::XS qw(decode_json);

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

    $self->_add_headers;

    $self;
}

sub get_item {
    my($self, $id, $item) = @_;

    my $filter  = qq'[{"field":"id","operator":"=","value":"$id"}]';
    my $books   = $self->_fetch_books(1, 0, undef, $filter);

    my $book_data = $books->{objects}[0];
    $book_data->{userBook} = {
        progress        => 0,
        purchaseDate    => 0
    };

    my $book = eval { $self->get_book($books->{objects}[0]) };
    unless ($book) {
        print Dumper [$id, $item];
        die $@;
    }
    delete $book->{old_serial_num};
    return $book;
}

sub _add_headers {
    my($self) = @_;
    my $mech = $self->{mech};
    $mech->add_header('x-api-version' => '3.9');
    $mech->add_header('x-client-application' => 'com.comixology.webstore');
    $mech->add_header('x-currency' => 'USD_US');
    $mech->add_header('x-region' => 'US');

    my($username, $token) = $self->get_token;
    if ($username && $token) {
        $mech->add_header('x-username' => $username);
        $mech->add_header('x-user-token' => $token);
    }
}

sub _fetch_books {
    my($self, $limit, $offset, $book_ids, $books_filter) = @_;

    $books_filter     ||= sprintf '[{"field":"id","operator":"IN","values":[%s]}]', join(',', @$book_ids);
    my $order = $self->_fetch_order_ref;
    my $books_url       = 'https://api.comixology.com/books' .
        '?filter=' . uri_escape($books_filter) .
        '&order=' . uri_escape($order);
    #print $books_url, "\n" if $self->debug;

    $self->mech_get($books_url);
    my $books = decode_json($self->content);
#print Dumper $books;
    return $books;
}

sub _fetch_user_books {
    my($self, $limit, $offset, $library_filter) = @_;
    $library_filter   ||= '[{"field":"archived","operator":"=","value":"0"}]';
    my $order = $self->_fetch_order_ref;

    my $library_url     = 'https://api.comixology.com/user/books' .
        '?filter=' . uri_escape($library_filter) .
        '&order=' . uri_escape($order) .
        "&limit=$limit&offset=$offset";
    #print $library_url, "\n" if $self->debug;

    $self->mech_get($library_url);
    my $library = decode_json($self->content);
#print Dumper $library;
    return $library;
}

sub _fetch_order_ref {
    return '[{"field":"seriesInfo.title","direction":"ASC"},{"field":"seriesInfo.position","direction":"ASC"}]'
}

sub fetch_and_store_series {
    my($self) = @_;

    my $url = $self->base_url;

    my $offset = 0;
    my $limit  = 120;
    my @books;

    while (1) {
        my $library = $self->_fetch_user_books($limit, $offset);
        my %book_ids = map { $_->{bookId} => $_ } @{ $library->{objects} };
        last if !keys %book_ids;

        my $books = $self->_fetch_books($limit, $offset, [keys %book_ids]);
        push @books, map { $_->{userBook} = $book_ids{$_->{id}}; $_ } @{$books->{objects}};
        $offset += $limit;
# last;
    }

# print JSON::XS::encode_json(\@books);
# exit;

    for my $book_data (@books) {
        my $book = eval { $self->get_book($book_data) };
        print $@ if $@;
        next unless $book;

        my $old_serial_num = delete $book->{old_serial_num};
        push @{$book->{edition}}, 'comiXology-original';
        $self->save_book($book, $old_serial_num);
    }

}


sub get_book {
    my($self, $book_data) = @_;

#die Dumper $book_data;
    confess "Book has insufficient data: " . Dumper($book_data) unless
        $book_data->{image}{url} && $book_data->{image}{optionsFormat} &&
        defined $book_data->{image}{optionsFormat}{start} &&
        defined $book_data->{image}{optionsFormat}{end} &&
        defined $book_data->{image}{optionsFormat}{width} &&
        $book_data->{title} &&
        $book_data->{seriesInfo}{title} &&
        $book_data->{publisherInfo}{title} &&
        ref($book_data->{creators}) && @{$book_data->{creators}} &&
        ref($book_data->{price}) && $book_data->{price}{fullFormatted} &&
        $book_data->{pageCount} &&
        defined($book_data->{status}{ageRating}) && length($book_data->{status}{ageRating}) &&
        $book_data->{description} &&
        defined($book_data->{userBook}{progress}) &&
        defined($book_data->{userBook}{purchaseDate}) &&
    1;

    my $book = {};
    $book->{serial_num}     = 'comixology-' . $book_data->{id};
    $book->{url}            = $self->cx_url($book_data);
    $book->{old_serial_num} = $book->{url};
    $book->{title}          = $self->cx_title($book_data);
    $book->{subtitle}       = $book_data->{issueTitle} if $book_data->{issueTitle};
    $book->{asin}           = $book_data->{asin} if $book_data->{asin};
    $book->{series}         = $book_data->{seriesInfo}{title};
    $book->{series_num}     = $book_data->{issueNumber} if $book_data->{issueNumber};
    $book->{pages}          = $book_data->{pageCount};
    $book->{purchased}      = str2time($book_data->{userBook}{purchaseDate}) if $book_data->{userBook}{purchaseDate};

    $book->{desc}           = $self->format_desc($book_data->{description});
    $book->{desc_source}    = 'comiXology';

    $book->{creators}       = [ map { $_->{name} } @{$book_data->{creators}} ];
    $book->{publisher}      = $book_data->{publisherInfo}{title};
    $book->{experienced}    = $book_data->{userBook}{progress} == 100;

    $book->{edition}        = [ $book_data->{sellerOfRecord} || 'comiXology' ];
    if ($book->{edition}[0] ne 'comiXology') {
        push @{$book->{edition}}, 'comiXology';
    }

    $book->{audience}       = $book_data->{status}{ageRating};
    if ($book->{audience} eq '0') {
        $book->{audience} = 'All Ages';
    }
    elsif ($book->{audience} =~ /\d/) {
        $book->{audience} .= '+ Only';
    }

    $book->{price}          = $book_data->{price}{fullFormatted};
    if ($book->{price} eq 'price.free') {
        $book->{price} = '$0';
    }

    my $fetch_book = $self->dl->fetch($book->{serial_num});
    if ($fetch_book) {
        unless (!$fetch_book->{ZPUBLISHDATE} || $fetch_book->{ZPUBLISHDATE} eq '-978278400') {
            # core data timestamps begin at unix epoch + 31 years
            $book->{published} = $fetch_book->{ZPUBLISHDATE}+978307200;
            return $book;
        }
    }

    print "# $book->{title} - $book->{url}\n";

    $self->cx_other_data($book);

# use Data::Dumper; $Data::Dumper::Sortkeys=1;
# print Dumper $book;
# return $book;

    my $img_url = sprintf $book_data->{image}{url}, (
        $book_data->{image}{optionsFormat}{start} .
        sprintf($book_data->{image}{optionsFormat}{width}, 640) .
        $book_data->{image}{optionsFormat}{end}
    );
    my $img_url_s = sprintf $book_data->{image}{url}, (
        $book_data->{image}{optionsFormat}{start} .
        sprintf($book_data->{image}{optionsFormat}{width}, 128) .
        $book_data->{image}{optionsFormat}{end}
    );

    my $img = Pudge::Comics::_img($img_url, $img_url_s);
    @{$book}{keys %$img} = values %$img;

    return $book;
}

sub cx_other_data {
    my($self, $book, $tried) = @_;
    $tried ||= 0;

    eval {
        $self->mech_get($book->{url});
        my $tree = HTML::TreeBuilder->new_from_content($self->content);

        if ($tree->find_by_attribute(class => 'errorPage')) {
            #$book->{url} = 'https://www.comixology.com/my-books/library/';
            $book->{genres} = ['Unavailable'];
        }
        else {
            $self->findcx_genres($tree, $book);
            $self->findcx_published($tree, $book);
        }
    };
    my $err = $@;
    if ($err) {
        if ($tried >= 1) {
            print "Failed: $err\n";
        }
        else {
            warn "Retrying: $err\n";
            $self->cx_other_data($book, $tried+1);
        }
    }
}

sub findcx_genres {
    my($self, $item, $book) = @_;

    my @genres;
    print STDERR $book->{url}, "\n";
    my $credits = $item->find_by_attribute(class => 'credits');
    for my $foo ($credits->find_by_tag_name('a')) {
        if ($foo->attr('href') =~ /genre/) {
            push @genres, $self->item_content($foo);
        }
    }
    $book->{genres} =  \@genres;
}

sub findcx_published {
    my($self, $item, $book) = @_;

    my $last;
    for my $foo ($item->find_by_tag_name('h4', 'div')) {
        my $class = $foo->attr('class');
        next unless $class;
        if ($class eq 'subtitle') {
            $last = $self->item_content($foo);
        }
        elsif ($class eq 'aboutText') {
            my $text = $self->item_content($foo);
            # RELEASE DATE
            if ($last eq 'Print Release Date') {
                $book->{published} = str2time($text);
            }
            # RELEASE DATE
            elsif ($last eq 'Digital Release Date' && !$book->{published}) {
                $book->{published} = str2time($text);
            }
        }
    }
}



sub cx_title {
    my($self, $book_data) = @_;

    my $title = $book_data->{title};
    $title         .= ' Vol. ' . $book_data->{volumeNumber} if $book_data->{volumeNumber};
    $title         .= ' #' . $book_data->{issueNumber} if defined $book_data->{issueNumber};
    $title         .= ': ' . $book_data->{volumeTitle} if $book_data->{volumeTitle};

    return $title;
}

sub cx_url {
    my($self, $book_data) = @_;

    my $book_url_title = $book_data->{title};
    $book_url_title        .= ' Vol. ' . $book_data->{volumeNumber} if $book_data->{volumeNumber};
    $book_url_title        .= ' ' . $book_data->{issueNumber} if defined $book_data->{issueNumber};
    $book_url_title        .= ' of ' . $book_data->{issueCount} if $book_data->{issueCount};
    $book_url_title        .= ': ' . $book_data->{volumeTitle} if $book_data->{volumeTitle};

    $book_url_title =~ s/'//g;
    $book_url_title =~ s/[\W]+/-/g;
    $book_url_title =~ s/[\s-]+$//g;

    return "https://www.comixology.com/$book_url_title/digital-comic/$book_data->{id}";
}

sub mech_logged_in {
    return 1;
}

"Free as in comics";

__END__
