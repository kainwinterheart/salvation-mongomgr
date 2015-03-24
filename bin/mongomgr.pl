#!/usr/bin/perl -w

use utf8;
use strict;
use warnings;
use boolean;

BEGIN {

    require Carp;

    $SIG{ __DIE__ } = \&Carp::confess;
};

use JSON 'encode_json';
use Getopt::Long 'GetOptions';
use Salvation::TC ();
use Salvation::MongoMgr ();

use Salvation::TC::Utils;

enum 'KnownCommands', [ 'compare_indexes' ];

no Salvation::TC::Utils;


my %connection = ( discovery => true );
my @add_hosts = ();
my @exclude_hosts = ();
my $auth_db_name = undef;
my $no_auth_config_file = false;
my $discovery = undef;

GetOptions(
    'db=s' => \$connection{ 'db' },
    'add=s' => \@add_hosts,
    'exclude=s' => \@exclude_hosts,
    'discovery!'=> \$discovery,
    'config=s' => \$connection{ 'config_file' },
    'auth-config=s' => \$connection{ 'auth_config_file' },
    'no-auth-config!' => \$no_auth_config_file,
    'auth-db=s' => \$auth_db_name,
);

if( $no_auth_config_file ) {

    $connection{ 'auth_config_file' } = undef;
}

if( defined $auth_db_name ) {

    $connection{ 'auth_db_name' } = $auth_db_name;
}

my $mgr = Salvation::MongoMgr -> new(
    connection => \%connection,
    ( ( scalar( @add_hosts ) > 0 ) ? ( add_hosts => \@add_hosts ) : () ),
    ( ( scalar( @exclude_hosts ) > 0 ) ? ( exclude_hosts => \@exclude_hosts ) : () ),
    ( defined $discovery ? ( discovery => $discovery ) : () ),
);

my $cmd = shift( @ARGV );

Salvation::TC -> assert( $cmd, 'KnownCommands' );

print( encode_json( $mgr -> $cmd( \@ARGV ) ) . "\n" );

exit 0;

__END__
