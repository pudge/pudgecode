package Pudge::SonyEntertainmentNetwork;

use warnings;
use strict;
use feature ':5.10';

use Cwd 'cwd';
use JSON::XS qw(encode_json decode_json);
use WWW::Mechanize;
use URI::Escape qw(uri_escape);

use Carp;
use Data::Dumper; $Data::Dumper::Sortkeys=1;

use Pudge::SonyEntertainmentNetwork::Asset;
use Pudge::SonyEntertainmentNetwork::DownloadItem;
use Pudge::SonyEntertainmentNetwork::DownloadList;

use base 'Class::Accessor';
__PACKAGE__->mk_accessors(qw(
    debug login_url session_id session_url main_url base_url prod_url user_id
    account_id local_path store_url search_url download_list agent_alias
));
__PACKAGE__->mk_ro_accessors(qw(mech));

sub new {
    my($class, $opts) = @_;
    $opts ||= {};
    $opts->{agent_alias}    //= 'Mac Safari';
    $opts->{local_path}     //= "$ENV{HOME}/.sen/";
    $opts->{login_url}      //= 'https://account.sonyentertainmentnetwork.com/external/auth/login.action?returnURL=https%3A%2F%2Fstore.sonyentertainmentnetwork.com%2Fshared%2Fhtml%2FsigninSuccessfulRedirect_grc.html&cancelURL=https%3A%2F%2Fstore.sonyentertainmentnetwork.com%2Fshared%2Fhtml%2FsigninCanceledRedirect_grc.html&request_locale=en_US&service-entity=psn';
    $opts->{main_url}       //= 'https://store.sonyentertainmentnetwork.com/';
    $opts->{base_url}       //= $opts->{main_url} . 'store/api/chihiro/00_09_000/';
    $opts->{session_url}    //= $opts->{main_url} . 'kamaji/api/chihiro/00_09_000/';
    $opts->{store_url}      //= $opts->{base_url} . 'container/US/en/19/';
    $opts->{search_url}     //= $opts->{base_url} . 'tumbler/US/en/19/';
    $opts->{prod_url}       //= $opts->{main_url} . '#!/en-us/games/game/cid=';
    $opts->{debug}          //= 0;

    my $self = bless {
        agent_alias => $opts->{agent_alias},
        local_path  => $opts->{local_path},
        login_url   => $opts->{login_url},
        main_url    => $opts->{main_url},
        base_url    => $opts->{base_url},
        session_url => $opts->{session_url},
        store_url   => $opts->{store_url},
        search_url  => $opts->{search_url},
        prod_url    => $opts->{prod_url},
        debug       => $opts->{debug},
        %$opts
    }, $class;

    $self->_init_mech;
    $self->_load_download_list;
    $self;
}

sub login {
    my($self, $username, $password, $save) = @_;

    ($username, $password) = $self->_credentials($username, $password, $save);

    say "  logging in" if $self->debug;
    say "  getting login page" if $self->debug > 1;
    $self->mech->get( $self->login_url );
    $self->_mech_debug;

    say "  submitting login form" if $self->debug > 1;
    $self->mech->submit_form( form_number => 1, fields => {
        j_username    => $username,
        j_password    => $password,
    });
    $self->_mech_debug;

    my $location = $self->mech->response->previous->header('location');
    (my $session_id = $location) =~ s/^.+sessionId=(.+)$/$1/;
    $self->session_id( $session_id );

    say "  setting session" if $self->debug > 1;
    my $req = HTTP::Request->new(POST => $self->session_url . 'user/session');
    $req->content_type('application/x-www-form-urlencoded');
    $req->content("sessionId=$session_id&noNuke=false");

    my $res = $self->mech->request($req);
    $self->_mech_debug;

    my $session = decode_json($res->content);
    $self->account_id( $session->{data}{accountId} );
    $self->session_url( $session->{data}{sessionUrl} );

    1;
}

sub _load_download_list {
    my($self, $data) = @_;
    my $json = $self->_file_input('downloads.json');
    return unless $json;
    $data ||= decode_json( $json );
    $self->download_list(
        Pudge::SonyEntertainmentNetwork::DownloadList->new( $data->{data}{drmDefList}, { sen => $self } )
    ) if $data;
}

sub fetch_download_list {
    my($self) = @_;

    say "  getting download list" if $self->debug;
    # why 4048?  seems to be the max ... also "entitlements"
    $self->mech->get($self->session_url . 'user/downloadlist?size=4048&start=0');
    $self->_mech_debug;

    my $content = $self->mech->success && $self->mech->content;
    my $ok;
    if ($content) {
        my $json = decode_json($content);
        my $ok = $self->_json_success($json);
        if ($ok) {
            $self->_file_output('downloads.json', $content);
            return $self->_load_download_list($json);
        }
    }
    undef;
}

sub get_product_data {
    my($self, $id, $force, $no_dl, $image) = @_;

    my $str = $image ? 'image' : 'data';
    my $ext = $image ?   'jpg' : 'json';
    my $url = $self->store_url . ($image ? "$id/image" : $id);

    my $file = "games/$id.$ext";
    my $content;

    $content = $self->_file_input($file) unless $force;

    if (!defined $content) {
        return if $no_dl;

        say "  getting product $str for $id" if $self->debug > 1;
        $self->mech->get($url);
        $self->_mech_debug;

        if ($self->mech->success) {
            $content = $self->mech->content;
            unless ($content) {
                warn "  No product $str found for $id, unknown problem\n";
                return;
            }
            $self->_file_output($file, $content);
        }
        else {
            say sprintf("  Failure fetching product %s for %s: %s\n", $str, $id, $self->mech->status)
                if $self->debug > 1;
            # a lot of items have no content available, so we'll cache the result anyway
            # we can always delete or override them later
            $self->_file_output($file, '-1');
            return;
        }
    }

    return if $content eq '-1';

    $image
        ? $content
        : Pudge::SonyEntertainmentNetwork::Asset->new(decode_json($content), { sen => $self });
}

sub get_product_image {
    my($self, $id, $force) = @_;
    $self->get_product_data($id, $force, 0, 1);
}

sub get_product_image_small {
    my($self, $id, $force) = @_;
    my $image = $self->get_product_image($id, $force);

    if ($image) {
        my $jpegf = "games/$id.jpg";
        my $jpegs = "games/$id-sm.jpg";

        my $content;
        $content = $self->_file_input($jpegs) unless $force;

        if (!defined $content) {
            my $cwd = cwd();
            chdir $self->local_path;
            system("cp $jpegf $jpegs >/dev/null 2>&1");
            system("sips -Z 128 $jpegs >/dev/null 2>&1") if -e $jpegs;
            chdir $cwd;
        }

        $content ||= $self->_file_input($jpegs);
        return $content;
    }
}

sub add_download {
    my($self, @id) = @_;

    my @data;
    for (@id) {
        print "  adding $_\n" if $self->debug > 1;
        push @data, { platformString => 'ps3', contentId => $_ };
    }

    say "  adding downloads" if $self->debug;
    my $req = HTTP::Request->new(POST => $self->session_url . 'user/notification/download');
    $req->content_type('application/json');
    $req->content(encode_json(\@data));

    my $res = $self->mech->request($req);
    $self->_mech_debug;

    my $json = decode_json($res->content);
    $self->_json_success($json);
}

sub online_search {
    my($self, $str) = @_;

    say "  searching" if $self->debug;
    $str =~ s/ /_/g;
    
    $self->mech->get($self->search_url . uri_escape($str) . '?suggested_size=25&mode=game'); # &mode=film&mode=tv
    $self->_mech_debug;

    my $content = $self->mech->content;
    $self->_fetch_links($content);
}

sub addons {
    my($self, $id, $owned) = @_;

    say "  searching" if $self->debug;

    $self->mech->get($self->store_url . $id . '?relationship=ADD-ONS&size=2000');
    $self->_mech_debug;

    my $content = $self->mech->content;
    return undef unless $content;

    my($json, $links) = $self->_fetch_links($content);
    if ($owned) {
        my @data;
        for my $d (@$links) {
            my $id = $d->id;
            push @data, $d if $self->download_list->by_id($id);
        }
        return($json, \@data);
    }

    return($json, $links);
}


###############################################################################
# utils

sub username {
    my($self, $username) = @_;

    if (defined $username) {
        $self->SUPER::set(username => $username);
    }

    $username = $self->SUPER::get('username');
    if (! defined $username) {
        ($username) = $self->_credentials;
    }

    $username;
}

sub _credentials {
    my($self, $username, $password, $save) = @_;

    if (defined $username && defined $password && $save) {
        $self->_file_output('credentials', "$username\n$password\n");
    }
    else {
        my $creds = $self->_file_input('credentials');
        if ($creds) {
            my($u, $p) = split /\n/, $creds;
            $username //= $u;
            $password //= $p;
        }

        croak "Cannot find login credentials"
            unless ( defined $username && defined $password );
    }

    $self->username( $username );

    ($username, $password);
}

sub _init_mech {
    my($self) = @_;
    my $mech = WWW::Mechanize->new; #(autocheck => 1);
    $mech->agent_alias($self->agent_alias);
    $self->{mech} = $mech;
}

sub _mech_debug {
    my($self) = @_;
    if ($self->debug > 4) {
        print Dumper $self->mech;
        say $self->mech->content if $self->debug > 9;
    }
}

sub _json_success {
    my($self, $json) = @_;
    ($json && $json->{header} && $json->{header}{message_key} eq 'success') ? 1 : 0;
}

sub _file_output {
    my($self, $name, $content) = @_;
    $self->_mk_local_dir;
    my $file = $self->local_path . $name;
    open my $fh, '>', $file or croak "Can't open $file: $!";
    print $fh $content;
}

sub _file_input {
    my($self, $name) = @_;
    my $file = $self->local_path . $name;
    open my $fh, '<', $file or do {
        $@ = "Can't open $file: $!";
        return;
    };
    local $/;
    <$fh>;
}

sub _mk_local_dir {
    my($self) = @_;
    unless (-d $self->local_path) {
        mkdir $self->local_path;
        chmod 0700, $self->local_path;
    }
}

sub _fetch_links {
    my($self, $content) = @_;
    if ($content) {
        my $json = decode_json($content);
        my @links;
        my %seen;
        for (@{$json->{links}}) {
            my $d = Pudge::SonyEntertainmentNetwork::Asset->new($_, { sen => $self });
            push @links, $d unless ( $seen{$d->id}++ );
        }
        return($json, \@links);
    }
    undef;
}

1;
