package Pudge::Comics;

use warnings;
use strict;
use feature ':5.10';

use Pudge::Comics::ComiXology;
use Pudge::Comics::DarkHorse;

use Carp qw(croak cluck);
use Data::Dumper; $Data::Dumper::Sortkeys=1;
use WWW::Mechanize;
use HTTP::Cookies;
use HTML::TreeBuilder;
use Pudge::DeliciousLibrary;
use Date::Parse 'str2time';
use Image::Size;
use LWP::Simple qw($ua);

use base 'Class::Accessor';
__PACKAGE__->mk_accessors(qw(
    debug agent_alias local_path dl base_url
));
__PACKAGE__->mk_ro_accessors(qw(
    mech comixology darkhorse
));

our($SKIP_STRINGS, $KEEP_IDS, @KEEP_IDS, $SKIP_IDS);

# audience, edition, series, series_num, experienced, format, serial_num, url
# genres, creators, publishers, published, pages, price, title, desc, desc_source

sub new {
    my($class, $opts) = @_;

    $ua->agent('Safari');

    $opts ||= {};
    $opts->{agent_alias}    //= 'Mac Safari';
    $opts->{local_path}     //= "$ENV{HOME}/.comics";
    $opts->{debug}          //= 0;

    my $self = bless {
        dl          => Pudge::DeliciousLibrary->new,
        agent_alias => $opts->{agent_alias},
        local_path  => $opts->{local_path},
        debug       => $opts->{debug},
        %$opts
    }, $class;

    $self->_load_archives;
    $self->_init_mech;

    $self->{comixology} = Pudge::Comics::ComiXology->new($self, $opts);
    $self->{darkhorse} = Pudge::Comics::DarkHorse->new($self, $opts);

    $self;
}

sub fetch_and_store_series {
    my($self) = @_;
    $self->comixology->fetch_and_store_series;
}

sub fetch_and_store_extras {
    my($self) = @_;

    my $extras = $self->_load_extras;

    my %seen;
    for my $item (@$extras) {
        my $item_link = $item->{link};

        my $book;
        $book->{experienced} //= $item->{experienced} // 0;

        if ($self->dl->fetch($item_link)) {
            $self->dl->create(Book => $book, $item_link);
            next;
        }

        if ($item_link =~ /comixology/i) {
            (my $id_num = $item_link) =~ s|^.+?/(\d+)$|$1|;
            my $id = 'comixology-' . $id_num;
            if ($self->dl->fetch($id)) {
                $self->dl->create(Book => $book, $id);
                next;
            }
            my $cx_book = $self->comixology->get_item($id_num);
            for my $k (keys %$cx_book) {
                $book->{$k} //= $cx_book->{$k};
            }
        }

        $book->{edition} //= [];
        push @{$book->{edition}}, $item->{src} if defined $item->{src};

        my $return = eval {
            if ($item_link !~ /comixology/i) {
                $self->mech_get($item_link);
                my $tree = HTML::TreeBuilder->new_from_content($self->content);
                $self->darkhorse->get_item($item_link, $tree, $book);
            }

            $self->save_book($book, $item_link);
        };
        my $err = $@;
        next if $return;
        if ($err) {
            warn "Retrying $item_link: $err\n";
            if (!$seen{$item_link}++) { # retry only once
                redo;
            }
        }
    }
}


sub _init_mech {
    my($self) = @_;
    my $mech = WWW::Mechanize->new(cookie_jar => $self->_get_cookie);
    $mech->agent_alias($self->agent_alias);
    return $self->{mech} = $mech;
}

sub mech_get {
    my($self, $link) = @_;
    $self->mech->get($link);
    $self->_mech_debug;
    if ($self->mech->content =~ /loginLink/) {
        croak "Not logged in";
    }
}

sub _mech_debug {
    my($self) = @_;
    if ($self->debug > 4) {
        print Dumper $self->mech;
        say $self->mech->content if $self->debug > 9;
    }
}

sub _get_cookie {
    my($self) = @_;
    my $cookie_jar = HTTP::Cookies->new;
    if (open my $fh, '<', $self->local_path . "/cookies/comixology") {
        chomp(my $cookie = <$fh>);
        $cookie_jar->set_cookie( undef,
            'CMXSESSIONID',
            $cookie,
            '/', '.comixology.com'
        );
    }

    $cookie_jar;
}

sub get_token {
    my($self) = @_;
    if (open my $fh, '<', $self->local_path . "/cookies/comixology-token") {
        my($username, $token) = map { chomp; $_ } <$fh>;
        return($username, $token);
    }

    ();
}

sub _load_extras {
    my($self) = @_;
    if (open my $fh, '<', $self->local_path . "/extras") {
        my $src;
        my @extras;
        while (<$fh>) {
            if (/^##\s*(.+)\s*$/) {
                $src = $1;
                next;
            }
            next if /^(\s|#)/;
            chomp;
            my $link = $_;

            my $experienced = 0;
            if ($link =~ /^(\S+)\s+(\d)$/) {
                $link           = $1;
                $experienced    = $2;
            }
            push @extras, { link => $link, experienced => $experienced, src => $src };
        }
        return \@extras;
    }
}

sub _load_archives {
    my($self) = @_;
    if (open my $fh, '<', $self->local_path . "/archives") {
        my(@skip_str, @skip_ids);
        my $what = 'series';
        while (<$fh>) {
            if (/^# archive issue/) {
                $what = 'issue';
            }
            elsif (/^(\d+)/) {
                if ($what eq 'issue') {
                    push @skip_ids, $1;
                }
                else {
                    push @KEEP_IDS, $1;
                }
            }
            elsif (/^([^#\s].+)$/) {
                push @skip_str, $1;
            }
        }
        if (@skip_str) {
            my $skip_str = join '|', @skip_str;
            $SKIP_STRINGS = qr/(?:$skip_str)/;
        }
        if (@KEEP_IDS) {
            my $keep_ids = join '|', @KEEP_IDS;
            $KEEP_IDS = qr/(?:$keep_ids)/;
        }
        if (@skip_ids) {
            my $skip_ids = join '|', @skip_ids;
            $SKIP_IDS = qr/(?:$skip_ids)/;
        }
    }
}

sub content {
    my($self) = @_;
    my $content = $self->mech->content;
    $content =~ s{<(/?)(?:article|section)\b}{<$1div}g;
    $content;
}

sub item_content {
    my($self, $item) = @_;
    cluck("undef item") if !$item;
    fixstr($item->content_array_ref->[0]);
}

sub _img {
    my($url, $url_s) = @_;
    my %img;

    # Dark Horse
    if ($url =~ s|(covers)/\d00/|$1/100/|) {
        $img{img_s} = LWP::Simple::get($url_s || $url);

        $url =~ s|(covers)/\d00/|$1/600/|;
        $img{img} = LWP::Simple::get($url);

        if (!$img{img}) {
            $url =~ s|(covers)/\d00/|$1/400/|;
            $img{img} = LWP::Simple::get($url);
        }
    }
    else {
        $img{img_s} = LWP::Simple::get($url_s || $url);
        $img{img} = LWP::Simple::get($url);
    }


    die "No img for $url" unless $img{img};

    my($w, $h, $t) = imgsize(\ $img{img});
    $img{img_h} = $h;
    $img{img_w} = $w;

    # scale pixels to match 5.7 inches wide (max. 8.75 inches tall)
    $img{height} //= sprintf '%.02f', (5.7 / ($img{img_w} / $img{img_h}));

    if ($img{height} > 8.75) {
        $img{width}  //= sprintf '%.02f', (8.75 / ($img{img_h} / $img{img_w}));
        $img{height} //= 8.75;
    }
    else {
        $img{width}  //= 5.7;
    }

    \%img;
}

sub fixstr {
    $_ = shift;
    return if !defined;
    s/^\s+//; s/\s+$//;
    $_;
}

sub save_book {
    my($self, $book, $old_serial_num) = @_;

    $book->{creators}     = [ keys %{{ map { $_ => 1 } @{$book->{creators}} }} ]; # dedup
    $book->{publishers}   = [delete $book->{publisher}] if defined $book->{publisher};
    $book->{serial_num}   ||= $book->{url};
    $book->{published}    ||= str2time('January 1, 1970');
    $book->{edition}      ||= [];
    unshift @{$book->{edition}}, 'Comic';

    if ($self->debug > 3) {
        print Dumper { map { $_ => $book->{$_} } grep !/img/, keys %$book };
    }
    $self->dl->create(Book => $book, $old_serial_num);
# exit;
}

sub dump {
    my($self, $book) = @_;
    my $copy = { %$book };
    $copy->{img_length}     = length delete $copy->{img};
    $copy->{img_s_length}   = length delete $copy->{img_s};
    print Dumper $copy;
}


#### base finds

sub find_link {
    my($self, $item, $book) = @_;
    my($foo) = $item->find_by_attribute(class => 'item-link');
    (my $item_link = $foo->attr('href')) =~ s/\?.*$//;
    $item_link;
}

sub find_title {
    my($self, $item, $book, $class) = @_;
    $class ||= 'item-title';
    my($foo) = $item->find_by_attribute(class => $class);
    $book->{title} = $self->item_content($foo);
}

sub find_series {
    my($self, $item, $book) = @_;

    if ($book->{title} =~ /^(.+?)\s+\#(\d+)/) {
        $book->{series} = $1;
        $book->{series_num} = $2;
    }
    elsif ($book->{title} =~ /^(.+?):?\s+Vol(?:\.|ume)[\s\d]/) {
        $book->{series} = $1;
    }
    elsif ($book->{title} =~ /^(.+?):/) {
        $book->{series} = $1;
    }
}

sub find_desc {
    my($self, $item, $book, $class, $src) = @_;
    $class ||= 'item-description';
    $src   ||= 'comiXology';
    my($foo) = $item->find_by_attribute(class => $class);

    $book->{desc} = $self->format_desc($foo->as_text);
    $book->{desc_source} = $src;
}

sub format_desc {
    my($self, $desc) = @_;
    return '<div>' . fixstr($desc) . '<br>-30-</div>';
}

sub find_img {
    my($self, $item, $book, $class) = @_;
    $class ||= 'item-cover';
    my($foo) = $item->find_by_attribute(class => $class);
    my $cover_url = $foo->attr('src');

    # hack!  do this right with URI and $mech->uri (?)
    $cover_url = "http:$cover_url" if $cover_url =~ m|^//|;

    my $img = _img($cover_url);
    @{$book}{keys %$img} = values %$img;
}

sub find_creators {
    my($self, $item, $book) = @_;

    my @names;
    my(@credits) = $item->find_by_attribute(class => 'credits');
    for my $credits (@credits) {
        my(@found) = $credits->find_by_tag_name('a');
        push @names, map { $self->item_content($_) } @found;
    }
    $book->{creators} = \@names;
}

"Free as in comics";
