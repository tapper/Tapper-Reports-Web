package Tapper::Reports::Web::Model;

use strict;
use warnings;

use parent 'Catalyst::Model::DBIC::Schema';
use feature qw/ switch /;

my @a_supported_storage_engines = qw/ mysql sqlite postgresql /;

my $fn_execute_raw_sql = sub {

    my ( $or_schema, $hr_params ) = @_;

    if (! $hr_params->{query_name} ) {
        die 'missing query name';
    }

    require Module::Load;
    return $or_schema->storage->dbh_do(
        sub {
            my ( $or_storage, $or_dbh, $hr_params ) = @_;

            my @a_query_name     = ( $hr_params->{query_name} =~ /(.*)::(.*)/ );
            my $s_storage_engine = ( split /::/, ref $or_storage         )[-1];
            my $s_schema         = ( split /::/, ref $or_storage->schema )[-1];

            if (! $s_storage_engine ~~ @a_supported_storage_engines ) {
                die 'storage engine not supported';
            }

            my $s_module = 'Tapper::RawSQL::' . $s_schema . '::' . $a_query_name[0];

            Module::Load::load( $s_module );
            if ( my $fh_query_sub = $s_module->can($a_query_name[1]) ) {
                my $hr_query = $fh_query_sub->( $hr_params->{query_vals} );
                if ( my $s_sql = $hr_query->{$s_storage_engine} || $hr_query->{default} ) {

                    # replace own placeholer with sql placeholder ("?")
                    my @a_vals;
                    $s_sql =~ s/\$(.+?)\$/push @a_vals, $1; q#?#/eg;

                    # get values of found keys
                    @a_vals = @a_vals
                        ? @{$hr_params->{query_vals}}{@a_vals}
                        : ()
                    ;

                    if ( $hr_params->{debug} ) {
                        require Carp;
                        Carp::cluck( $s_sql . '(' . join( q#,#, @a_vals ) . ')' );
                    }

                    if ( $hr_params->{fetch_type} ) {
                        given ( $hr_params->{fetch_type} ) {
                            when ( q|$$| ) { return $or_dbh->selectrow_arrayref( $s_sql, { Columns => [ 0 ] }, @a_vals)->[0]     }
                            when ( q|$@| ) { return $or_dbh->selectrow_arrayref( $s_sql, {}, @a_vals )                           }
                            when ( q|$%| ) { return $or_dbh->selectrow_hashref ( $s_sql, {}, @a_vals )                           }
                            when ( q|@$| ) { return $or_dbh->selectcol_arrayref( $s_sql, {}, @a_vals )                           }
                            when ( q|@@| ) { return $or_dbh->selectall_arrayref( $s_sql, {}, @a_vals )                           }
                            when ( q|@%| ) { return $or_dbh->selectall_arrayref( $s_sql, { Slice => {} }, @a_vals )              }
                            default        { die 'unknown fetch type'                                                            }
                        }
                    }

                }
                else {
                    die "raw sql statement isn't supported for storage engine '$s_storage_engine'";
                }
            }
            else {
                die 'named query not exists';
            }

        },
        $hr_params,
    );

    return;

};

sub fetch_raw_sql {
    my ( $or_schema, $s_name, $s_fetch_type, $ar_vals ) = @_;
    return $fn_execute_raw_sql->( $or_schema, $s_name, $s_fetch_type, $ar_vals )
}

sub execute_raw_sql {
    my ( $or_schema, $s_name, $ar_vals ) = @_;
    return $fn_execute_raw_sql->( $or_schema, $s_name, undef, $ar_vals )
}

1;