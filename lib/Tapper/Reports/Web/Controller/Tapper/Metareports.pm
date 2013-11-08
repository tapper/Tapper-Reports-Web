package Tapper::Reports::Web::Controller::Tapper::Metareports;

# ABSTRACT: Tapper - Catalyst Controller Metareports

use strict;
use warnings;
use parent 'Tapper::Reports::Web::Controller::Base';

use Try::Tiny;

use 5.010;

sub index :Path :Args() {

    my ( $self, $c, @args ) = @_;

    $c->go('/tapper/metareports/chart_overview');

}

sub auto : Private {

   my ( $self, $c ) = @_;

    $c->forward('/tapper/metareports/prepare_navi');
}

sub detail : Local {

    my ( $or_self, $or_c ) = @_;

    $or_c->stash->{head_overview} = 'Metareports - Detail';

    $or_c->stash->{chart} = $or_c
        ->model('TestrunDB')
        ->resultset('Charts')
        ->find( $or_c->req->params->{chart_id} )
    ;

    return 1;

}

sub chart_overview : Local {

    my ( $or_self, $or_c ) = @_;

    $or_c->stash->{head_overview} = 'Metareports - Overview';

    # get charts for user
    $or_c->stash->{charts} = [
        $or_c->model('TestrunDB')->resultset('Charts')->search({
            owner_id => $or_c->req->params->{owner_id},
        })
    ];

    return 1;

}

sub get_chart_points : Local {

    my ( $or_self, $or_c ) = @_;

    my %h_params  = %{$or_c->req->params};

    # get chart information
    my $or_chart = $or_c->model('TestrunDB')->resultset('Charts')->search({
        chart_id => $h_params{chart},
    },{
        prefetch => [
            'chart_axis_type_x',
            'chart_axis_type_y',
        ],
    })->first();

    # get chart lines
    my @a_chart_lines = $or_c->model('TestrunDB')->resultset('ChartLines')->search({
        chart_id => $h_params{chart},
    });

    my @a_result;
    my %h_counter = ( x => 0 , y => 0,  );
    my %h_lists   = ( x => {}, y => {}, );

    if ( @a_chart_lines ) {

        require JSON::XS;
        require YAML::Syck;
        require Tapper::Benchmark;
        my $or_bench = Tapper::Benchmark
            ->new({
                debug  => 0,
                dbh    => $or_c->model('TestrunDB')->storage->dbh,
                config => YAML::Syck::LoadFile( Tapper::Config->subconfig->{benchmark}{config_file} ),
            })
        ;

        require DateTime::Format::Epoch;
        my $formatter = DateTime::Format::Epoch->new(
            epoch               => DateTime->new( year => 1970, month => 1, day => 1 ),
            unit                => 'milliseconds',
            type                => 'int',    # or 'float', 'bigint'
            skip_leap_seconds   => 1,
            start_at            => 0,
            local_epoch         => undef,
        );

        for my $or_chart_line ( @a_chart_lines ) {

            my %h_local_params  = %{$or_c->req->params};
            my $hr_chart_search = $or_chart_line->chart_line_statement;

            my @a_additionals = $or_c->model('TestrunDB')->resultset('ChartLineAdditionals')->search({
                chart_line_id => $or_chart_line->chart_line_id,
            });

            $hr_chart_search->{limit}    ||= $h_params{graph_width} ? int( $h_params{graph_width} / 4 ) : 100;
            $hr_chart_search->{order_by} ||= [[
                $or_chart_line->chart_axis_x_column,
                $h_params{searchfrom} && !$h_params{searchto} ? 'ASC' : 'DESC',
                { numeric => $or_chart->chart_axis_type_x->chart_axis_type_name eq 'numeric' },
            ]];

            require DateTime;
            for my $s_key (qw/ right_of_value left_of_value /) {
                if ( $h_local_params{$s_key} ) {
                    if ( $or_chart->chart_axis_type_x->chart_axis_type_name eq 'date' ) {
                        $h_local_params{$s_key} = DateTime
                            ->from_epoch( epoch => $h_local_params{$s_key} / 1000 )
                            ->strftime( $or_chart_line->chart_axis_x_column_format )
                        ;
                    }
                }
            }
            require DateTime::Format::Strptime;
            for my $s_key (qw/ searchfrom searchto /) {
                if ( $h_local_params{$s_key} ) {
                    if ( $or_chart->chart_axis_type_x->chart_axis_type_name eq 'date' ) {
                        $h_local_params{$s_key} = DateTime::Format::Strptime
                            ->new( pattern => '%F %H:%M' )
                            ->parse_datetime( $h_local_params{$s_key} )
                            ->strftime( $or_chart_line->chart_axis_x_column_format )
                        ;
                    }
                }
            }

            if ( my $min_value = $h_local_params{right_of_value} || $h_local_params{searchfrom} ) {
                push @{$hr_chart_search->{where}}, [ '>', $or_chart_line->chart_axis_x_column, $min_value ];
            }
            if ( my $max_value = $h_local_params{left_of_value} || $h_local_params{searchto} ) {
                push @{$hr_chart_search->{where}}, [ '<', $or_chart_line->chart_axis_x_column, $max_value ];
            }

            my @a_chart_line_points;
            my $ar_chart_line_points = $or_bench->search_array( $hr_chart_search );

            my ( $or_strp_x, $or_strp_y );
            if ( $or_chart->chart_axis_type_x->chart_axis_type_name eq 'date' ) {
                if ( my $dt_format = $or_chart_line->chart_axis_x_column_format ) {
                    require DateTime::Format::Strptime;
                    $or_strp_x = DateTime::Format::Strptime->new( pattern => $dt_format );
                }
                else {
                    $or_c->response->status( 500 );
                    $or_c->body('xaxis type is date but no date format is given for "' . $or_chart_line->chart_line_name . '"');
                    return 1;
                }
            }
            if ( $or_chart->chart_axis_type_y->chart_axis_type_name eq 'date' ) {
                if ( my $dt_format = $or_chart_line->chart_axis_y_column_format ) {
                    require DateTime::Format::Strptime;
                    $or_strp_y = DateTime::Format::Strptime->new( pattern => $dt_format );
                }
                else {
                    $or_c->response->status( 500 );
                    $or_c->response->body('yaxis type is date but no date format is given for "' . $or_chart_line->chart_line_name . '"');
                    return 1;
                }
            }

            for my $or_point ( @{$ar_chart_line_points} ) {

                my $hr_chart_point = {};
                   $hr_chart_point->{additionals} = [];
                   $hr_chart_point->{x_value}     = $or_point->{$or_chart_line->chart_axis_x_column};
                   $hr_chart_point->{y_value}     = $or_point->{$or_chart_line->chart_axis_y_column};

                if ( $or_strp_x ) {
                    $hr_chart_point->{x_value} = $formatter->format_datetime(
                         $or_strp_x->parse_datetime( $hr_chart_point->{x_value} )
                    );
                }
                elsif ( $or_chart->chart_axis_type_x->chart_axis_type_name eq 'alphanumeric' ) {
                    if (! $h_lists{x}{$hr_chart_point->{x_value}} ) {
                        $h_lists{x}{$hr_chart_point->{x_value}} = $h_counter{'x'};
                        $h_counter{'x'}++;
                    }
                    $hr_chart_point->{x_value_tmp} = $h_lists{x}{$hr_chart_point->{x_value}};
                }
                if ( $or_strp_y ) {
                    $hr_chart_point->{y_value} = $formatter->format_datetime(
                         $or_strp_y->parse_datetime( $hr_chart_point->{y_value} )
                    );
                }
                elsif ( $or_chart->chart_axis_type_y->chart_axis_type_name eq 'alphanumeric' ) {
                    if (! $h_lists{y}{$hr_chart_point->{y_value}} ) {
                        $h_lists{y}{$hr_chart_point->{y_value}} = $h_counter{'y'};
                        $h_counter{'y'}++;
                    }
                    $hr_chart_point->{y_value_tmp} = $h_lists{y}{$hr_chart_point->{y_value}};
                }

                for my $or_chart_line_addition ( @a_additionals ) {
                    push @{$hr_chart_point->{additionals}},[
                        $or_chart_line_addition->chart_line_additional_column,
                        $or_point->{$or_chart_line_addition->chart_line_additional_column},
                        $or_chart_line_addition->chart_line_additional_url,
                    ];
                }

                if (
                    (
                           defined $hr_chart_point->{x_value}
                        || defined $hr_chart_point->{x_value_tmp}
                    ) && (
                           defined $hr_chart_point->{y_value}
                        || defined $hr_chart_point->{y_value_tmp}
                    )
                ) {
                    push @a_chart_line_points, $hr_chart_point;
                }

            }

            push @a_result, {
                data    => \@a_chart_line_points,
                label   => $or_chart_line->chart_line_name,
            };

        }

        # resort alphanumeric values
        my %h_new_counter = ( x => 0, y => 0 );
        if ( $or_chart->chart_axis_type_x->chart_axis_type_name eq 'alphanumeric' ) {
            for my $s_key ( sort { $a cmp $b } keys %{$h_lists{x}} ) {
                for my $hr_line ( @a_result ) {
                    for my $hr_point ( @{$hr_line->{data}} ) {
                        if ( $hr_point->{x_value_tmp} eq $s_key ) {
                            $hr_point->{x_value} = $h_new_counter{x};
                        }
                    }
                }
                $h_lists{x}{$s_key} = $h_new_counter{x};
                $h_new_counter{x}++;
            }
        }
        if ( $or_chart->chart_axis_type_y->chart_axis_type_name eq 'alphanumeric' ) {
            for my $s_key ( sort { $a cmp $b } keys %{$h_lists{y}} ) {
                for my $hr_line ( @a_result ) {
                    for my $hr_point ( @{$hr_line->{data}} ) {
                        if ( $hr_point->{y_value_tmp} eq $s_key ) {
                            $hr_point->{y_value} = $h_new_counter{y};
                        }
                    }
                }
                $h_lists{y}{$s_key} = $h_new_counter{y};
                $h_new_counter{y}++;
            }
        }

    }

    $or_c->stash->{content} = {
        xaxis_alphas    => [ map { [ $h_lists{x}{$_}, $_ ] } sort { $a cmp $b } keys %{$h_lists{x}} ],
        yaxis_alphas    => [ map { [ $h_lists{y}{$_}, $_ ] } sort { $a cmp $b } keys %{$h_lists{y}} ],
        xaxis_type      => $or_chart->chart_axis_type_x->chart_axis_type_name,
        yaxis_type      => $or_chart->chart_axis_type_y->chart_axis_type_name,
        series          => \@a_result,
    };

    return 1;

}

sub edit_chart : Local {

    my ( $or_self, $or_c ) = @_;

    require YAML::Syck;
    require Tapper::Config;
    require Tapper::Benchmark;

    my $or_schema    = $or_c->model('TestrunDB');
    my @a_columnlist = $or_schema
        ->resultset('BenchAdditionalTypes')
        ->get_column('bench_additional_type')
        ->all()
    ;
    my %h_columns = Tapper::Benchmark
        ->new({
            dbh    => Tapper::Model::model()->storage->dbh,
            config => YAML::Syck::LoadFile( Tapper::Config->subconfig->{benchmark}{config_file} ),
        })
        ->{query}
        ->default_columns()
    ;

    push @a_columnlist, keys %h_columns;

    if (! $or_c->stash->{chart} ) {
        if ( $or_c->req->params->{chart_id} ) {
            $or_c->stash->{chart} = get_edit_page_chart_hash_by_chart_id(
                $or_c->req->params->{chart_id}, $or_schema,
            );
        }
        else {
            $or_c->stash->{chart} = {};
        }
    }

    $or_c->stash->{columns}       = \@a_columnlist;
    $or_c->stash->{head_overview} = 'Metareports - Edit' . ( $or_c->req->params->{asnew} ? ' as New' : q## );

    return 1;

}

sub get_edit_page_chart_hash_by_chart_id {

    my ( $i_chart_id, $or_schema ) = @_;

    my $or_chart = $or_schema->resultset('Charts')->search(
        { 'me.chart_id' => $i_chart_id, },
        { prefetch => { 'chart_lines' => 'chart_additionals' }, },
    )->first();

    my $hr_chart = {
        chart_id                => $or_chart->chart_id(),
        chart_name              => $or_chart->chart_name(),
        chart_type_id           => $or_chart->chart_type_id(),
        chart_axis_type_x_id    => $or_chart->chart_axis_type_x_id(),
        chart_axis_type_y_id    => $or_chart->chart_axis_type_y_id(),
        chart_lines             => [],
    };

    for my $or_line ( $or_chart->chart_lines ) {
        push @{$hr_chart->{chart_lines}}, {
            chart_line_name         => $or_line->chart_line_name(),
            chart_line_statement    => $or_line->chart_line_statement(),
            chart_line_x_column     => $or_line->chart_axis_x_column(),
            chart_line_x_format     => $or_line->chart_axis_x_column_format(),
            chart_line_y_column     => $or_line->chart_axis_y_column(),
            chart_line_y_format     => $or_line->chart_axis_y_column_format(),
            chart_additionals       => [],
        };
        for my $or_add ( $or_line->chart_additionals ) {
            push @{$hr_chart->{chart_lines}[-1]{chart_additionals}}, {
                chart_line_additional_column    => $or_add->chart_line_additional_column,
                chart_line_additional_url       => $or_add->chart_line_additional_url,
            };
        }
    }

    return $hr_chart;

}

sub get_edit_page_chart_hash_by_params {

    my ( $hr_params, $or_schema ) = @_;

    my $hr_chart = {
        chart_id                => $hr_params->{chart_id},
        chart_name              => $hr_params->{chart_name},
        chart_type_id           => $hr_params->{chart_type},
        chart_axis_type_x_id    => $hr_params->{chart_axis_type_x},
        chart_axis_type_y_id    => $hr_params->{chart_axis_type_y},
        chart_lines             => [],
    };

    # column values for chart lines
    my @a_chart_line_names      = @{toarrayref($hr_params->{chart_line_name})};
    my @a_chart_line_x_columns  = @{toarrayref($hr_params->{chart_axis_x_column})};
    my @a_chart_line_y_columns  = @{toarrayref($hr_params->{chart_axis_y_column})};
    my @a_chart_line_x_formats  = @{toarrayref($hr_params->{chart_axis_x_format})};
    my @a_chart_line_y_formats  = @{toarrayref($hr_params->{chart_axis_y_format})};

    # column values chart line statements
    my @a_chart_where_counter   = @{toarrayref($hr_params->{chart_where_counter})};
    my @a_chart_where_column    = @{toarrayref($hr_params->{chart_line_where_column})};
    my @a_chart_where_operator  = @{toarrayref($hr_params->{chart_line_where_operator})};
    my @a_chart_value_counter   = @{toarrayref($hr_params->{chart_line_where_counter})};
    my @a_chart_where_value     = @{toarrayref($hr_params->{chart_line_where_value})};

    # additional column data
    my @a_chart_add_counter     = @{toarrayref($hr_params->{chart_additional_counter})};
    my @a_chart_add_columns     = @{toarrayref($hr_params->{chart_additional_column})};
    my @a_chart_add_urls        = @{toarrayref($hr_params->{chart_additional_url})};

    # get default columns for check
    require YAML::Syck;
    require Tapper::Benchmark;
    my %h_default_columns = Tapper::Benchmark
        ->new({
            dbh    => $or_schema->storage->dbh,
            config => YAML::Syck::LoadFile( Tapper::Config->subconfig->{benchmark}{config_file} ),
        })
        ->{query}
        ->default_columns()
    ;

    while ( my $s_chart_line_name = shift @a_chart_line_names ) {

        my $hr_chart_line_statement = { select => [], where => [], };
        my $s_chart_line_x_column   = shift @a_chart_line_x_columns;
        my $s_chart_line_y_column   = shift @a_chart_line_y_columns;
        my $s_chart_line_x_format   = shift @a_chart_line_x_formats;
        my $s_chart_line_y_format   = shift @a_chart_line_y_formats;
        my $i_chart_where_counter   = shift @a_chart_where_counter;
        my $i_chart_add_counter     = shift @a_chart_add_counter;

        if (! $h_default_columns{$s_chart_line_x_column} ) {
            push @{$hr_chart_line_statement->{select}}, $s_chart_line_x_column;
        }
        if (! $h_default_columns{$s_chart_line_y_column} ) {
            push @{$hr_chart_line_statement->{select}}, $s_chart_line_y_column;
        }

        for my $i_where_counter ( 1..$i_chart_where_counter ) {
            my $i_chart_value_counter = shift @a_chart_value_counter;
            push @{$hr_chart_line_statement->{where}}, [
                shift @a_chart_where_operator,
                shift @a_chart_where_column,
                map { shift @a_chart_where_value } 1..$i_chart_value_counter,
            ];
        }

        push @{$hr_chart->{chart_lines}}, {
            chart_line_name      => $s_chart_line_name,
            chart_line_x_column  => $s_chart_line_x_column,
            chart_line_x_format  => $s_chart_line_x_format || undef,
            chart_line_y_column  => $s_chart_line_y_column,
            chart_line_y_format  => $s_chart_line_y_format || undef,
            chart_line_statement => $hr_chart_line_statement,
            chart_additionals    => [],
        };

        for my $i_add_counter ( 1..$i_chart_add_counter ) {
            my $s_add_column = shift @a_chart_add_columns;
            if (! $h_default_columns{$s_add_column} ) {
                push @{$hr_chart_line_statement->{select}}, $s_add_column;
            }
            push @{$hr_chart->{chart_lines}[-1]{chart_additionals}}, {
                chart_line_additional_column => $s_add_column,
                chart_line_additional_url    => shift @a_chart_add_urls,
            };
        }

    }

    return $hr_chart;

}

sub save_chart : Local {

    my ( $or_self, $or_c ) = @_;

    my $or_schema = $or_c->model('TestrunDB');
    my $hr_params = $or_c->req->params;

    my $hr_search_param = { chart_name  => $hr_params->{chart_name}, };
    if ( $hr_params->{chart_id} ) {
        $hr_search_param->{-not} = { chart_id => $hr_params->{chart_id} };
    }
    my @a_charts = $or_schema->resultset('Charts')->search( $hr_search_param );
    if ( @a_charts ) {
        $or_c->stash->{error} = 'chart name already exists';
    }

    # serialize input data
    $or_c->stash->{chart} = get_edit_page_chart_hash_by_params( $hr_params, $or_schema );

    require Data::Dumper;
    warn Data::Dumper::Dumper( $or_c->stash->{chart} );

    try {
        $or_schema->txn_do(sub {
            if ( $hr_params->{chart_id} ) {
                if ( my $s_error = $or_self->remove_chart( $or_c, $or_schema ) ) {
                    $or_c->stash->{error} = $s_error;
                }
            }
            if ( my $s_error = $or_self->insert_chart( $or_c, $or_schema ) ) {
                $or_c->stash->{error} = $s_error;
            }
        });
    }
    catch {
        $or_c->stash->{error} = "Transaction failed: $_";
        $or_c->go('/tapper/metareports/edit_chart');
    };

    $or_c->redirect($or_c->uri_for("/tapper/metareports/chart_overview", { owner_id => $or_c->req->params->{owner_id} }));
    $or_c->detach();

    return 1;

}

sub toarrayref : Private {

    my ( $value ) = @_;

    if ( ref( $value ) ne 'ARRAY' ) {
        return [ $value ];
    }

    return $value;

}

sub delete_chart : Local {

    my ( $or_self, $or_c ) = @_;

    my $or_schema = $or_c->model('TestrunDB');

    try {
        $or_schema->txn_do(sub {
            if ( my $s_error = $or_self->remove_chart( $or_c, $or_schema ) ) {
                die "Transaction failed: $s_error";
            }
        });
    }
    catch {
        $or_c->stash->{error} = "Transaction failed: $_";
    };

    if (! $or_c->stash->{error} ) {
        $or_c->stash->{message} = 'Chart successfully deleted';
    }

    $or_c->redirect($or_c->uri_for("/tapper/metareports/chart_overview", { owner_id => $or_c->req->params->{owner_id} }));
    $or_c->detach();

    return 1;

}

sub insert_chart : Private {

    my ( $or_self, $or_c, $or_schema ) = @_;

    my $hr_params = $or_c->stash->{chart};
    my $or_chart  = $or_c->model('TestrunDB')->resultset('Charts')->new({
        chart_type_id           => $hr_params->{chart_type_id},
        owner_id                => $or_c->req->params->{owner_id},
        chart_axis_type_x_id    => $hr_params->{chart_axis_type_x_id},
        chart_axis_type_y_id    => $hr_params->{chart_axis_type_y_id},
        chart_name              => $hr_params->{chart_name},
    });
    $or_chart->insert();

    if ( my $i_chart_id = $or_chart->chart_id() ) {

        for my $hr_chart_line ( @{$hr_params->{chart_lines}} ) {

            my $or_chart_line = $or_c->model('TestrunDB')->resultset('ChartLines')->new({
                chart_id                    => $i_chart_id,
                chart_line_name             => $hr_chart_line->{chart_line_name},
                chart_axis_x_column         => $hr_chart_line->{chart_line_x_column},
                chart_axis_x_column_format  => $hr_chart_line->{chart_line_x_format} || undef,
                chart_axis_y_column         => $hr_chart_line->{chart_line_y_column},
                chart_axis_y_column_format  => $hr_chart_line->{chart_line_y_format} || undef,
                chart_line_statement        => $hr_chart_line->{chart_line_statement},
            });
            $or_chart_line->insert();

            if ( my $i_chart_line_id = $or_chart_line->chart_line_id ) {

                for my $hr_additionals ( @{$hr_chart_line->{chart_additionals}} ) {
                    my $or_chart_line_add = $or_c->model('TestrunDB')->resultset('ChartLineAdditionals')->new({
                        chart_line_id                => $i_chart_line_id,
                        chart_line_additional_column => $hr_additionals->{chart_line_additional_column},
                        chart_line_additional_url    => $hr_additionals->{chart_line_additional_url} || undef,
                    });
                    $or_chart_line_add->insert();
                }

            }

        }

    }
    else {
        die "cannot insert chart";
    }

    return 1;

}

sub remove_chart : Private {

    my ( $or_self, $or_c ) = @_;

    if (! $or_c->req->params->{chart_id} ) {
        return 'chart_id is missing';
    }

    my $or_chart = $or_c->model('TestrunDB')->resultset('Charts')->search(
        { 'me.chart_id' => $or_c->req->params->{chart_id} },
    )->first();

    for my $or_chart_line ( $or_chart->chart_lines ) {
        for my $or_additional ( $or_chart_line->chart_additionals ) {
            $or_additional->delete();
        }
        $or_chart_line->delete();
    }
    $or_chart->delete();

    return q##;

}

sub get_benchmark_operators : Private {

    my ( $or_self, $or_c ) = @_;

    require YAML::Syck;
    require Tapper::Config;
    require Tapper::Benchmark;

    return Tapper::Benchmark
        ->new({
            dbh    => Tapper::Model::model()->storage->dbh,
            config => YAML::Syck::LoadFile( Tapper::Config->subconfig->{benchmark}{config_file} ),
        })
        ->{query}
        ->benchmark_operators()
    ;

}

sub base : Chained PathPrefix CaptureArgs(0) {
    my ( $self, $c ) = @_;
    my $rule =  File::Find::Rule->new;
    $c->stash(rule => $rule);
}

=head2 prepare_navi

Generate data structure that describes the navigation part.

=cut

sub prepare_navi : Private {
    my ( $self, $c ) = @_;

    $c->stash->{navi} = [
        {
            title  => "Metareports",
            href => "/tapper/metareports/",
        },
    ];

}

1;