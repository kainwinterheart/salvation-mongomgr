#!/usr/bin/perl -w

use utf8;
use strict;
use warnings;
use boolean;

BEGIN {

    require Carp;

    $SIG{ __DIE__ } = \&Carp::confess;
};

use JSON ();
use Getopt::Long 'GetOptions';
use Salvation::TC ();
use Salvation::MongoMgr ();

use Salvation::TC::Utils;

enum 'KnownCommands', [
    'compare_indexes', 'hosts_list', 'get_indexes', 'reload', 'list_masters',
    'shell', 'exec',
];

no Salvation::TC::Utils;

++$|;

{
    my %connection = ( discovery => true );
    my @add_hosts = ();
    my @exclude_hosts = ();
    my $auth_db_name = undef;
    my $use_auth = true;
    my $discovery = undef;
    my $pretty = true;
    my $shell = false;

    GetOptions(
        'db=s' => \$connection{ 'db' },
        'add=s' => \@add_hosts,
        'exclude=s' => \@exclude_hosts,
        'discovery!'=> \$discovery,
        'config=s' => \$connection{ 'config_file' },
        'auth-config=s' => \$connection{ 'auth_config_file' },
        'auth!' => \$use_auth,
        'auth-db=s' => \$auth_db_name,
        'pretty!' => \$pretty,
        'shell!' => \$shell,
    );

    if( $use_auth ) {

        unless( defined $connection{ 'auth_config_file' } ) {

            delete( $connection{ 'auth_config_file' } );
        }

    } else {

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

    if( $shell ) {

        while( true ) {

            print "mongomgr> ";
            my $line = readline( STDIN );

            last unless defined $line;

            chomp( $line );
            $line =~ s/^\s+//;
            $line =~ s/\s+$//;

            if( length( $line ) > 0 ) {

                eval{ run_command( $mgr, [ split( /\s+/, $line ) ], { pretty => $pretty } ) };

                print( "$@\n" ) if $@;
            }
        }

    } else {

        run_command( $mgr, \@ARGV, { pretty => $pretty } );
    }
}

exit 0;

sub run_command {

    my ( $mgr, $args, $opts ) = @_;
    my $cmd = shift( @$args );

    Salvation::TC -> assert( $cmd, 'KnownCommands' );

    my $rv = $mgr -> $cmd( $args );
    my $json = JSON -> new() -> utf8( 1 ) -> allow_blessed( 1 );

    if( $opts -> { 'pretty' } ) {

        $json = $json -> pretty();
    }

    print( $json -> encode( $rv ) . "\n" );

    return;
}

__END__
