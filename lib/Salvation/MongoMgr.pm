package Salvation::MongoMgr;

use strict;
use warnings;
use boolean;

use Salvation::TC ();
use List::MoreUtils 'uniq';
use Salvation::MongoMgr::Connection ();

our $VERSION = 0.01;


sub new {

    my ( $proto, %args ) = @_;

    Salvation::TC -> assert( \%args, 'HashRef(
        HashRef :connection!,
        ArrayRef[Str] :add_hosts,
        ArrayRef[Str] :exclude_hosts,
        Bool :discovery
    )' );

    unless( exists $args{ 'discovery' } ) {

        $args{ 'discovery' } = true;
    }

    $self -> { '_connection_args' } = delete( $self -> { 'connection' } );

    my $self = bless( \%args, ( ref( $proto ) || $proto ) );

    $self -> { 'connection' } = Salvation::MongoMgr::Connection
        -> new( %{ $self -> { '_connection_args' } } );

    return $self;
}

sub compare_indexes {

    my ( $self, $collections ) = @_;
    my @missing = ();
    my $hosts_count = undef;

    Salvation::TC -> assert( $collections, 'ArrayRef[Str]' );

    foreach my $collection ( @$collections ) {

        my %tree = ();

        foreach my $host ( @{ $self -> hosts_list() } ) {

            my $mgr = $self -> new(
                connection => {
                    %{ $self -> { '_connection_args' } },
                    host => $host,
                },
                add_hosts => [ $host ],
                discovery => false,
            );

            foreach my $index ( $mgr
                -> { 'connection' }
                -> get_collection( $collection )
                -> get_indexes()
            ) {

                Salvation::TC -> assert( $index, 'HashRef(
                    HashRef[Int] :key!
                )' );

                my $dest = $tree{ join( "\0", map( { join( ':', ( $_, $index -> { $_ } ) ) }
                    sort( keys( %{ $index -> { 'key' } } ) ) ) ) } //= {

                    hosts => [],
                    index => $index,
                };

                push( @{ $dest -> { 'hosts' } }, $host );
            }
        }

        $hosts_count //= $self -> hosts_count();

        while( my ( undef, $data ) = each( %tree ) ) {

            if( scalar( @{ $data -> { 'hosts' } } ) != $hosts_count ) {

                push( @missing, {
                    index => $data -> { 'index' },
                    hosts => $self -> remaining_hosts( @{ $data -> { 'hosts' } } ),
                } );
            }
        }
    }

    return \@missing;
}

sub remaining_hosts {

    my ( $self, @list ) = @_;
    my %map = map( { $_ => 1 } @list );

    return [ grep( { ! exists $map{ $_ } } @{ $self -> hosts_list() } ) ];
}

sub hosts_count {

    my ( $self ) = @_;

    return scalar( @{ $self -> hosts_list() } );
}

sub hosts_list {

    my ( $self ) = @_;

    unless( exists $self -> { 'hosts_list' } ) {

        if( $self -> { 'discovery' } ) {

            if( $self -> is_mongos() ) {

                my @out = ();

                foreach my $shard ( @{ $self -> list_shards() } ) {

                    foreach my $host ( split( /\s*,\s*/, $shard -> { 'host' } ) ) {

                        $host =~ s/^.+?\///;

                        push( @out, lc( $host ) );
                    }
                }

                $self -> { 'hosts_list' } = \@out;

            } else {

                my $metadata = $self -> metadata();

                if( exists $metadata -> { 'hosts' } ) {

                    $self -> { 'hosts_list' } = [ map( { lc( $_ ) } @{ $metadata -> { 'hosts' } } ) ];

                } else {

                    $self -> { 'hosts_list' } = [ lc( $metadata -> { 'me' } ) ];
                }
            }

        } else {

            $self -> { 'hosts_list' } = [];
        }

        if( exists $self -> { 'add_hosts' } ) {

            push( @{ $self -> { 'hosts_list' } },
                map( { lc( $_ ) } @{ $self -> { 'add_hosts' } } ) );
        }

        @{ $self -> { 'hosts_list' } } = uniq( @{ $self -> { 'hosts_list' } } );

        if( exists $self -> { 'exclude_hosts' } ) {

            my %map = map( { lc( $_ ) => 1 } @{ $self -> { 'exclude_hosts' } } );
            my @new_list = ();

            while( defined( my $host = shift( @{ $self -> { 'hosts_list' } } ) ) ) {

                unless( exists $map{ $host } ) {

                    push( @new_list, $host );
                }
            }

            $self -> { 'hosts_list' } = \@new_list;
        }
    }

    return $self -> { 'hosts_list' };
}

sub list_shards {

    my ( $self ) = @_;

    unless( exists $self -> { 'list_shards' } ) {

        my $rv = $self -> _run_admin_command( { listShards => 1 } );

        Salvation::TC -> assert( $rv, 'HashRef(
            Bool :ok!
        )' );

        if( $rv -> { 'ok' } ) {

            Salvation::TC -> assert( $rv, 'HashRef(
                ArrayRef[HashRef( Str :_id!, Str :host! )] :shards!
            )' );

            $self -> { 'list_shards' } = $rv -> { 'shards' };

        } else {

            $self -> { 'list_shards' } = [];
        }
    }

    return $self -> { 'list_shards' };
}

sub is_mongos {

    my ( $self ) = @_;

    return !! $self -> metadata() -> { 'msg' };
}

sub metadata {

    my ( $self ) = @_;

    unless( exists $self -> { 'metadata' } ) {

        my $rv = $self -> _run_admin_command( { isMaster => 1 } );

        Salvation::TC -> assert( $rv, 'HashRef(
            Str :msg,
            ArrayRef[Str] :hosts,
            Str :me!
        )' );

        $self -> { 'metadata' } = $rv;
    }

    return $self -> { 'metadata' };
}

sub _run_admin_command {

    my ( $self, $spec ) = @_;

    return $self -> { 'connection' } -> get_database( 'admin' ) -> run_command( $spec );
}

sub reload {

    my ( $self ) = @_;

    delete( @$self{ 'metadata', 'list_shards', 'hosts_list' } );

    return;
}


1;

__END__
