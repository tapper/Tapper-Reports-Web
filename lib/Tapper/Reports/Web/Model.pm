package Tapper::Reports::Web::Model;

use strict;
use warnings;

use parent 'Catalyst::Model::DBIC::Schema';

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

            my ( $s_query_ns, $s_query_sub ) = ( $hr_params->{query_name} =~ /(.*)::(.*)/ );
            my $s_storage_engine             = ( split /::/, ref $or_storage         )[-1];
            my $s_schema                     = ( split /::/, ref $or_storage->schema )[-1];

            if (! $s_storage_engine ~~ @a_supported_storage_engines ) {
                die 'storage engine not supported';
            }

            my $s_module = 'Tapper::RawSQL::' . $s_schema . '::' . $s_query_ns;

            Module::Load::load( $s_module );
            if ( my $fh_query_sub = $s_module->can($s_query_sub) ) {

                my $hr_query_vals = $hr_params->{query_vals};
                my $hr_query      = $fh_query_sub->( $hr_query_vals );

                if ( my $s_sql = $hr_query->{$s_storage_engine} || $hr_query->{default} ) {

                    # replace own placeholer with sql placeholder ("?")
                    my @a_vals;
                    $s_sql =~ s/
                        \$(.+?)\$
                    /
                        ref $hr_query_vals->{$1} eq 'ARRAY'
                            ? ( push( @a_vals, @{$hr_query_vals->{$1}} ) && join ',', map { q#?# } @{$hr_query_vals->{$1}} )
                            : ( push( @a_vals,   $hr_query_vals->{$1}  ) &&                 q#?#                           )
                    /egx;

                    if ( $hr_params->{debug} ) {
                        require Carp;
                        Carp::cluck( $s_sql . '(' . join( q#,#, @a_vals ) . ')' );
                    }

                    if ( $hr_params->{fetch_type} ) {
                        if ( $hr_params->{fetch_type} eq q|$$| ) {
                            return $or_dbh->selectrow_arrayref( $s_sql, { Columns => [ 0 ] }, @a_vals )->[0]
                        }
                        elsif ( $hr_params->{fetch_type} eq q|$@| ) {
                            return $or_dbh->selectrow_arrayref( $s_sql, {}, @a_vals )
                        }
                        elsif ( $hr_params->{fetch_type} eq q|$%| ) {
                            return $or_dbh->selectrow_hashref ( $s_sql, {}, @a_vals )
                        }
                        elsif ( $hr_params->{fetch_type} eq q|@$| ) {
                            return $or_dbh->selectcol_arrayref( $s_sql, {}, @a_vals )
                        }
                        elsif ( $hr_params->{fetch_type} eq q|@@| ) {
                            return $or_dbh->selectall_arrayref( $s_sql, {}, @a_vals )
                        }
                        elsif ( $hr_params->{fetch_type} eq q|@%| ) {
                            return $or_dbh->selectall_arrayref( $s_sql, { Slice => {} }, @a_vals )
                        }
                        else {
                            die 'unknown fetch type'
                        }
                    }

                }
                else {
                    die "raw sql statement isn't supported for storage engine '$s_storage_engine'";
                }
            }
            else {
                die 'named query does not exist';
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