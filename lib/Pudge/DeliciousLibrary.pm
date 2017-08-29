package Pudge::DeliciousLibrary;

use warnings;
use strict;
use feature ':5.10';

use Carp;
use DBI;
use UUID::Tiny ':std';

use base 'Class::Accessor';
__PACKAGE__->mk_ro_accessors(qw(dbh));

my %DEFAULTS = (
    'Z25_ROOTSHELF' => undef,
    'ZACTORSCOMPOSITESTRING' => undef,
    'ZAMAZONLASTLOOKUPDATE' => undef,
    'ZAMAZONLASTPRICESLOOKUPDATE' => undef,
    'ZAMAZONLASTSIMILARITEMSFROMSTORELOOKUPDATE' => undef,
    'ZAMAZONLASTSYNOPSESLOOKUPDATE' => undef,
    'ZAMAZONPRODUCTGROUP' => undef,
    'ZASIN' => undef,
    'ZASSOCIATEDURL' => undef,
    'ZAUDIENCERECOMMENDEDAGESINGULARSTRING' => undef,
    'ZBOXHEIGHTININCHES' => '0',
    'ZBOXLENGTHININCHES' => '0',
    'ZBOXWEIGHTINPOUNDS' => '0',
    'ZBOXWIDTHININCHES' => '0',
    'ZBUYPRICE' => undef,
    'ZCINEMATOGRAPHERSCOMPOSITESTRING' => undef,
    'ZCOMPOSERSCOMPOSITESTRING' => undef,
    'ZCONDITIONSINGULARSTRING' => undef,
    'ZCONDUCTORSCOMPOSITESTRING' => undef,
    'ZCOUNTRYCODE' => undef,
    'ZCOVERIMAGECOLORSCOMPOSITESTRING' => undef,
    'ZCOVERIMAGEDATAHOLDER' => undef,
    'ZCOVERIMAGEDOMINANTCOLORRGBA' => '0',
    'ZCOVERIMAGEEDGEDOMINANTCOLORRGBA' => '0',
    'ZCOVERIMAGEISCUSTOM' => undef,
    'ZCOVERIMAGELARGESTHEIGHTINPIXELS' => '0',
    'ZCOVERIMAGELARGESTWIDTHINPIXELS' => '0',
    'ZCOVERIMAGELARGEURLSTRING' => undef,
    'ZCOVERIMAGEMEDIUMURLSTRING' => undef,
    'ZCOVERIMAGENORMALIZEDAREAOFINTERESTDATA' => undef,
    'ZCOVERIMAGENORMALIZEDCORNERRADIUSLOWERLEFT' => '0',
    'ZCOVERIMAGENORMALIZEDCORNERRADIUSLOWERRIGHT' => '0',
    'ZCOVERIMAGENORMALIZEDCORNERRADIUSUPPERLEFT' => '0',
    'ZCOVERIMAGENORMALIZEDCORNERRADIUSUPPERRIGHT' => '0',
    'ZCOVERIMAGESMALLURLSTRING' => undef,
    'ZCOVERIMAGETINYIMAGEDATA' => undef,
    'ZCOVERIMAGEUSERSPECIFIEDTRAPEZOIDDATA' => undef,
    'ZCREATIONDATE' => undef,
    'ZCREATIONFETCHINGERROR' => undef,
    'ZCREATIONFETCHKEYNAME' => undef,
    'ZCREATIONREASON' => undef,
    'ZCREATORSCOMPOSITESTRING' => undef,
    'ZCURRENTVALUE' => undef,
    'ZDEWEYDECIMAL' => undef,
    'ZEAN' => undef,
    'ZEDITIONSCOMPOSITESTRING' => undef,
    'ZEXPLICITPHYSICALFORMAT' => undef,
    'ZFEATURESCOMPOSITESTRING' => undef,
    'ZFOREIGNUUIDSTRING' => undef,
    'ZFORMATSINGULARSTRING' => undef,
    'ZGENRESCOMPOSITESTRING' => undef,
    'ZHASEXPERIENCED' => '0',
    'ZILLUSTRATORSCOMPOSITESTRING' => undef,
    'ZISBN' => undef,
    'ZISSIGNED' => '0',
    'ZITUNESCOLLECTIONKEY' => undef,
    'ZKEY' => undef,
    'ZLANGUAGESCOMPOSITESTRING' => undef,
    'ZLASTMODIFICATIONDATE' => undef,
    'ZLIBRARYOFCONGRESSCALLNUMBER' => undef,
    'ZLOAN' => undef,
    'ZLOCATIONSINGULARSTRING' => undef,
    'ZMAXIMUMPLAYERS' => undef,
    'ZMINIMUMPLAYERS' => undef,
    'ZMINUTES' => '0',
    'ZNETRATING' => '0',
    'ZNETWORKDICTIONARYDATA' => undef,
    'ZNOTES' => undef,
    'ZNUMBERINSERIES' => '0',
    'ZNUMBEROFMEDIA' => '1',
    'ZORDER' => undef,
    'ZOWNERSINGULARSTRING' => undef,
    'ZPAGES' => '0',
    'ZPERSISTENTID' => undef,
    'ZPLATFORMSCOMPOSITESTRING' => undef,
    'ZPRICE' => undef,
    'ZPRIVATECOLLECTION' => '0',
    'ZPUBLISHDATE' => undef,
    'ZPUBLISHERSCOMPOSITESTRING' => undef,
    'ZPURCHASEDATE' => undef,
    'ZRARE' => '0',
    'ZRATING' => '0',
    'ZRATINGHOLDERMEDIUM' => undef,
    'ZRECOMMENDATIONWEIGHT' => undef,
    'ZROOTSHELF' => undef,
    'ZSCREENWRITERSCOMPOSITESTRING' => undef,
    'ZSERIALNUMBER' => undef,
    'ZSERIESSINGULARSTRING' => undef,
    'ZSUBTITLE' => undef,
    'ZTHEATRICALDATE' => undef,
    'ZTITLE' => undef,
    'ZTRACKSCOMPOSITESTRING' => undef,
    'ZTYPE' => undef,
    'ZUSED' => '0',
    'ZUSERSYNOPSIS' => undef,
    'ZUUIDSTRING' => undef,
    'Z_ENT' => undef,
    'Z_OPT' => undef,
);
my %IMG_DEFAULTS = (
    Z1_ABSTRACTMEDIUM   => 3,
    Z_ENT               => 15,
    Z_OPT               => 1
);

my %DESC_DEFAULTS = (
    Z2_CONCEPTUALMEDIUM     => 3,
    ZCONCEPTUALMEDIUM1      => undef,
    Z2_CONCEPTUALMEDIUM1    => undef,
    ZORDER                  => 0,
    ZSOURCE                 => 'Sony Entertainment Network',
    Z_ENT                   => 13,
    Z_OPT                   => 1
);
my %MAP = (
    title       => 'ZTITLE',
    subtitle    => 'ZSUBTITLE',
    asin        => 'ZASIN',
    serial_no   => 'ZSERIALNUMBER',
    serial_num  => 'ZSERIALNUMBER',
    url         => 'ZASSOCIATEDURL',
    audience    => 'ZAUDIENCERECOMMENDEDAGESINGULARSTRING',
    min_players => 'ZMINIMUMPLAYERS',
    max_players => 'ZMAXIMUMPLAYERS',
    desc        => 'ZUSERSYNOPSIS',
    desc_source => 'ZSOURCE',
    owner       => 'ZOWNERSINGULARSTRING',
    series      => 'ZSERIESSINGULARSTRING',
    series_num  => 'ZNUMBERINSERIES',
    pages       => 'ZPAGES',
    experienced => 'ZHASEXPERIENCED',
    height      => 'ZBOXHEIGHTININCHES',
    width       => 'ZBOXWIDTHININCHES',
    length      => 'ZBOXLENGTHININCHES',
    price       => 'ZPRICE',
    isbn        => 'ZISBN',
    used        => 'ZUSED',
    edition     => [\&_list, 'ZEDITIONSCOMPOSITESTRING'],
    features    => [\&_list, 'ZFEATURESCOMPOSITESTRING'],
    creators    => [\&_list, 'ZCREATORSCOMPOSITESTRING'],
    publishers  => [\&_list, 'ZPUBLISHERSCOMPOSITESTRING'],
    genres      => [\&_list, 'ZGENRESCOMPOSITESTRING'],
    platforms   => [\&_list, 'ZPLATFORMSCOMPOSITESTRING'],
    published   => [\&_date, 'ZPUBLISHDATE'],
    purchased   => [\&_date, 'ZPURCHASEDATE'],
);
my %CAT_DEFAULTS = (
    VideoGame  => {
        'Z25_ROOTSHELF' => '27',
        'ZCOUNTRYCODE' => 'us',
        'ZCREATIONREASON' => '6',
        'ZFORMATSINGULARSTRING' => 'Digital',
        'ZLANGUAGESCOMPOSITESTRING' => 'English',
        'ZROOTSHELF' => '12',
        'ZTYPE' => 'VideoGame',
        'Z_ENT' => '3',
        'Z_OPT' => '19',
    },
    Book  => {
        'Z25_ROOTSHELF' => '27',
        'ZCOUNTRYCODE' => 'us',
        'ZCREATIONREASON' => '6',
        'ZFORMATSINGULARSTRING' => 'Digital',
        'ZLANGUAGESCOMPOSITESTRING' => 'English',
        'ZROOTSHELF' => '12',
        'ZTYPE' => 'Book',
        'Z_ENT' => '3',
        'Z_OPT' => '19',
    }
);
my %PK_TABLE_MAP = (
    ZABSTRACTMEDIUM         => 'AbstractMedium',
    ZABSTRACTSYNOPSIS       => 'AbstractSynopsis',
    ZCOVERIMAGEDATAHOLDER   => 'CoverImageDataHolder',
);

sub new {
    my($class, $path) = @_;
    $path //= $ENV{HOME} . '/Library/Containers/com.delicious-monster.library3/Data/Library/' .
        'Application Support/Delicious Library 3/Delicious Library Items.deliciouslibrary3';
    my $dbh = DBI->connect("dbi:SQLite:dbname=$path");
    bless { dbh => $dbh }, $class;
}

sub _prep_attrs {
    my($self, $type, $attrs) = @_;

    croak "no data" unless defined $attrs && ref $attrs; # && keys %$attrs;

    my $typeh;
    if (defined $type) {
        $typeh = $CAT_DEFAULTS{$type};
        croak "no such type $type" unless defined $typeh; 
    }

    my %img;
    $img{img}   = delete $attrs->{img};
    $img{img_h} = delete $attrs->{img_h};
    $img{img_w} = delete $attrs->{img_w};
    $img{img_s} = delete $attrs->{img_s};
    my $desc    = delete $attrs->{desc};

    my %data;
    for my $attr (keys %$attrs) {
        my $k = $MAP{$attr} || $attr;

        if ( !$k && !(exists $DEFAULTS{$attr}) ) {
            croak "Can't find $attr";
        }

        my $v = $attrs->{$attr};
        if (ref $k) {
            $v = $k->[0]->($v);
            $k = $k->[1];
        }
        $data{$k} = $v;
    }

    return(\%data, $typeh, \%img, $desc);
}

sub fetch {
    my($self, $id) = @_;

    $self->_get_existing_record({ ZSERIALNUMBER => $id });
}

sub _update {
    my($self, $id, $data, $img, $desc) = @_;
    return 0 unless $id;

    $data->{ZLASTMODIFICATIONDATE}  //= _now();

    my %desc = (
        desc                => $desc,
        ZSOURCE             => delete($data->{ZSOURCE}) // $DESC_DEFAULTS{ZSOURCE},
        Z2_CONCEPTUALMEDIUM => delete($data->{Z2_CONCEPTUALMEDIUM}) // $DESC_DEFAULTS{Z2_CONCEPTUALMEDIUM},
    );

    $self->_do_update(ZABSTRACTMEDIUM => $data, $id) if $data;
    $self->_insert_image($id, $img) if $img;
    $self->_insert_desc($id, \%desc) if $desc;

    $id;
}

sub update {
    my($self, $id, $data, $img, $desc) = @_;
    return 0 unless $id;

    $self->_update( $self->_get_existing_record_id($id), $data, $img, $desc );
}

sub create {
    my($self, $type, $attrs, $old_serial_num) = @_;

    my($data, $typeh, $img, $desc) = $self->_prep_attrs($type, $attrs);

    my $sn = $old_serial_num // $data->{ZSERIALNUMBER}; #print "$sn!!!\n";

    if ($sn) {
        my $id = $self->_get_existing_record_id($data, $sn);
        if ($id) {
            return $self->_update($id, $data, $img, $desc);
        }
    }

#     print "$old_serial_num : $data->{ZSERIALNUMBER}\n";
#     my $id = $self->_get_existing_record_id($data, $old_serial_num);
#     if ($id) {
#         return $self->_update($id, $data, $img, $desc);
#     }

    for my $k (keys %$typeh) {
        $data->{$k} = $typeh->{$k} unless exists $data->{$k};
    }

    for my $k (keys %DEFAULTS) {
        $data->{$k} = $DEFAULTS{$k} unless exists $data->{$k};
    }

    $data->{ZUUIDSTRING}            //= uc(create_uuid_as_string(UUID_V1));
    $data->{ZPUBLISHDATE}           //= _now();
    $data->{ZPURCHASEDATE}          //= _now();
    $data->{ZCREATIONDATE}          //= _now();
    $data->{ZLASTMODIFICATIONDATE}  //= _now();

    my %desc = (
        desc                => $desc,
        ZSOURCE             => delete($data->{ZSOURCE}) // $DESC_DEFAULTS{ZSOURCE},
        Z2_CONCEPTUALMEDIUM => delete($data->{Z2_CONCEPTUALMEDIUM}) // $DESC_DEFAULTS{Z2_CONCEPTUALMEDIUM},
    );

    my $id = $self->_do_insert(ZABSTRACTMEDIUM => $data);
    $self->_insert_image($id, $img);
    $self->_insert_desc($id, \%desc);

    return $id;
}

sub _get_existing_record {
    my($self, $data, $old_serial_num) = @_;

    my $serial = $old_serial_num || (ref $data ? $data->{ZSERIALNUMBER} : $data);
    return if ( !$serial );

    my $found = $self->dbh->selectrow_hashref('select * from ZABSTRACTMEDIUM where ZSERIALNUMBER = ?', {}, $serial);
    if ( !$found || !$found->{Z_PK} ) {
        if ($old_serial_num) { # try without old serial num
            return $self->_get_existing_record($data);
        }
        return;
    }

    $found;
}

sub _get_existing_record_id {
    my($self, $data, $old_serial_num) = @_;
    my $found = $self->_get_existing_record($data, $old_serial_num);
    $found->{Z_PK};
}

sub _insert_desc {
    my($self, $id, $desc) = @_;

    if ($desc->{desc}) {
        $self->dbh->do('delete from ZABSTRACTSYNOPSIS where ZCONCEPTUALMEDIUM = ? and Z2_CONCEPTUALMEDIUM = ? and ZSOURCE = ?',
            {}, $id, $desc->{Z2_CONCEPTUALMEDIUM}, $desc->{ZSOURCE}
        );
        $self->dbh->do('delete from ZABSTRACTSYNOPSIS where ZCONCEPTUALMEDIUM = ? and Z2_CONCEPTUALMEDIUM = ? and ZSOURCE = ?',
            {}, $id, $DESC_DEFAULTS{Z2_CONCEPTUALMEDIUM}, $DESC_DEFAULTS{ZSOURCE}
        );

        my %desc_data = %DESC_DEFAULTS;
        $desc_data{ZCONCEPTUALMEDIUM}       = $id;
        $desc_data{ZSOURCE}                 = $desc->{ZSOURCE};
        $desc_data{ZHTMLSTRING}             = $desc->{desc};
        $desc_data{ZUUIDSTRING}             = uc(create_uuid_as_string(UUID_V1));
        $desc_data{ZLASTMODIFICATIONDATE}   = _now();
        $self->_do_insert(ZABSTRACTSYNOPSIS => \%desc_data);
    }
}

sub _insert_image {
    my($self, $id, $img) = @_;

    if ($img && keys %$img && $img->{img}) {
        $self->dbh->do('delete from ZCOVERIMAGEDATAHOLDER where ZABSTRACTMEDIUM = ? and Z1_ABSTRACTMEDIUM = ?',
            {}, $id, $IMG_DEFAULTS{Z1_ABSTRACTMEDIUM}
        );

        my %img_data = %IMG_DEFAULTS;
        $img_data{ZCOMPRESSEDIMAGEDATA}     = $img->{img};
        $img_data{ZABSTRACTMEDIUM}          = $id;
        $img_data{ZUUIDSTRING}              = uc(create_uuid_as_string(UUID_V1));
        $img_data{ZLASTMODIFICATIONDATE}    = _now();
        my $iid = $self->_do_insert(ZCOVERIMAGEDATAHOLDER => \%img_data);
        my %update = (
            ZCOVERIMAGEDATAHOLDER               => $iid,
            ZCOVERIMAGELARGESTHEIGHTINPIXELS    => $img->{img_h},
            ZCOVERIMAGELARGESTWIDTHINPIXELS     => $img->{img_w},
            ZCOVERIMAGEISCUSTOM                 => 1
        );
        $update{ZCOVERIMAGETINYIMAGEDATA} = $img->{img_s} if $img->{img_s};

        $self->_do_update(ZABSTRACTMEDIUM => \%update, $id);
    }
}

sub _do_update {
    my($self, $table, $data, $id) = @_;
    my($set, $bind) = _up_prep($data);
    $self->dbh->do("update $table set $set where Z_PK=?", {}, @$bind, $id);
}

sub _do_insert {
    my($self, $table, $data) = @_;
    my($keys, $vals, $bind) = _ins_prep($data);
#use Carp 'cluck';
#cluck "$table\n";
    $self->dbh->do("insert into $table ($keys) values ($vals)", {}, @$bind);
    my $id = $self->dbh->func('last_insert_rowid');

    if ($id && $PK_TABLE_MAP{uc $table}) {
        $self->dbh->do("update Z_PRIMARYKEY set Z_MAX=? where Z_NAME=?", {}, $id, $PK_TABLE_MAP{uc $table});
    }

    return $id || 0;
}

sub _ins_prep {
    my($data) = @_;
    my $keys = join ',', keys %$data;
    my @bind = values %$data;
    my $vals = join ', ', (('?') x scalar(@bind));
    return($keys, $vals, \@bind);
}

sub _up_prep {
    my($data) = @_;
    my @bind = values %$data;
    my $set = join ', ', map { "$_ = ?" } keys %$data;
    return($set, \@bind);
}

sub _now  { _date(time()) }
sub _date { defined $_[0] ? $_[0]-978307200 : undef } # core data timestamps begin at unix epoch + 31 years
sub _list { join "\n", map { _str($_) } @{$_[0]} if $_[0] }
sub _str  { $_[0] }
