#!perl
use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'          => 'Pudge',
    'VERSION_FROM'  => 'lib/Pudge.pm',
    'EXE_FILES'     => [map { "bin/$_" } qw(
        sen
    )],
    'PREREQ_PM'     => {
        'Class::Accessor'   => 0,
        'WWW::Mechanize'    => 0,
        'URI::Escape'       => 0,
        'JSON::XS'          => 0,
        'Cwd'               => 0,
        'Carp'              => 0,
        'Data::Dumper'      => 0,
        'Date::Parse'       => 0,
        'Date::Format'      => 0,
    },
    'NO_META'       => 1,
);

__END__
