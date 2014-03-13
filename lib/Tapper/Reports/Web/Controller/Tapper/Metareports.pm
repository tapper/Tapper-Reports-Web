package Tapper::Reports::Web::Controller::Tapper::Metareports;

# ABSTRACT: Tapper - Catalyst Controller Metareports

use strict;
use warnings;
use parent 'Tapper::Reports::Web::Controller::Base';

use Try::Tiny;
use List::MoreUtils qw( any );

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

    if ( $or_c->req->params->{chart_tiny_url_id} ) {
        $or_c->stash->{chart} = $or_c
            ->model('TestrunDB')
            ->resultset('Charts')
            ->search({
                'chart_tiny_url_lines.chart_tiny_url_id' => $or_c->req->params->{chart_tiny_url_id}
            },{
                rows => 1,
                join => {
                    chart_lines => 'chart_tiny_url_lines'
                },
            })
            ->first
        ;
    }
    elsif ( $or_c->req->params->{chart_id} ) {
        $or_c->stash->{chart} = $or_c
            ->model('TestrunDB')
            ->resultset('Charts')
            ->find( $or_c->req->params->{chart_id} )
        ;
    }

    return 1;

}

sub chart_overview : Local {

    my ( $or_self, $or_c ) = @_;

    $or_c->stash->{head_overview} = 'Metareports - Overview';

    # get charts for user
    $or_c->stash->{charts} = [
        $or_c->model('TestrunDB')->resultset('Charts')->search({
            active   => 1,
            owner_id => $or_c->req->params->{owner_id},
        },{
            order_by => { -asc => 'chart_name' }
        })
    ];

    return 1;

}

sub get_chart_points : Local {

    my ( $or_self, $or_c ) = @_;

    my %h_params = %{$or_c->req->params};

    # get chart information
    my $or_chart = $or_c->model('TestrunDB')->resultset('Charts')->search({
        'me.chart_id' => $h_params{chart},
    },{
        prefetch => [
            {
                'chart_lines' => [
                    'chart_additionals',
                    {
                        'chart_axis_elements' => [
                            'axis_column',
                            'axis_separator',
                        ],
                    },
                ],
            },
            'chart_axis_type_x',
            'chart_axis_type_y',
            'chart_type',
        ],
    })->first();

    my ( @a_first, @a_last, @a_result );
    my %h_axis = ( x => {}, y => {}, );

    # update tiny url counter if exists
    my $or_tiny_url;
    if ( my $i_chart_tiny_url_id = $h_params{chart_tiny_url_id} ) {
        $or_tiny_url = $or_c
            ->model('TestrunDB')
            ->resultset('ChartTinyUrls')
            ->search({
                'me.chart_tiny_url_id' => $i_chart_tiny_url_id,
            },{
                rows     => 1,
                prefetch => {
                    chart_tiny_url_line => 'chart_tiny_url_relation'
                },
            })
            ->first()
        ;
        $or_tiny_url->visit_count( $or_tiny_url->visit_count() + 1 );
        $or_tiny_url->last_visited(\'NOW()');
        $or_tiny_url->update();
    }

    if ( my @a_chart_lines = $or_chart->chart_lines ) {

        require JSON::XS;
        require YAML::Syck;
        require Tapper::Benchmark;
        my $or_bench = Tapper::Benchmark
            ->new({ dbh => $or_c->model('TestrunDB')->storage->dbh, })
        ;

        require DateTime;
        require DateTime::Format::Epoch;
        require DateTime::Format::Strptime;
        my $formatter = DateTime::Format::Epoch->new(
            epoch               => DateTime->new( year => 1970, month => 1, day => 1 ),
            unit                => 'milliseconds',
            type                => 'int',    # or 'float', 'bigint'
            skip_leap_seconds   => 1,
            start_at            => 0,
            local_epoch         => undef,
        );

        my %h_counter       = (
            x   => 0 ,
            y   => 0,
        );
        my %h_axis_type     = (
            x   => $or_chart->chart_axis_type_x->chart_axis_type_name,
            y   => $or_chart->chart_axis_type_y->chart_axis_type_name,
        );
        my %h_label_type    = (
            x   => $h_axis_type{x} eq 'alphanumeric' || $or_chart->order_by_x_axis == 2 && $or_chart->order_by_y_axis == 1 ? 'list' : 'auto',
            y   => $h_axis_type{y} eq 'alphanumeric' || $or_chart->order_by_y_axis == 2 && $or_chart->order_by_x_axis == 1 ? 'list' : 'auto',
        );

        $h_params{limit} ||= $h_params{graph_width} ? int( $h_params{graph_width} / 4 ) : 100;

        if ( $h_params{pager_direction} ) {
            if ( $h_params{pager_direction} eq 'prev' ) {
                $h_params{offset} = $h_params{offset};
            }
            else {
                $h_params{offset} = $h_params{offset} - ( $h_params{limit} * 2 );
            }
        }
        else {
            $h_params{offset} = 0;
        }

        for my $or_chart_line ( @a_chart_lines ) {

            my @a_additionals;
            my $b_value_id_exists = 0;
            for my $or_additional_column ( $or_chart_line->chart_additionals ) {
                if ( $or_additional_column->chart_line_additional_column eq 'VALUE_ID' ) {
                    $b_value_id_exists = 1;
                }
                push @a_additionals, [
                    $or_additional_column->chart_line_additional_column,
                    $or_additional_column->chart_line_additional_url,
                ];
            }
            if ( !$b_value_id_exists ) {
                unshift @a_additionals, ['VALUE_ID'];
            }

            my $hr_chart_search        = $or_chart_line->chart_line_statement;
            $hr_chart_search->{limit}  = $h_params{limit};
            $hr_chart_search->{offset} = $h_params{offset};

            for my $s_axis (qw/ x y /) {
                for my $or_element ( sort { $a->chart_line_axis_element_number <=> $b->chart_line_axis_element_number } $or_chart_line->chart_axis_elements ) {
                    if ( $or_element->chart_line_axis eq $s_axis && $or_element->axis_column ) {
                        push @{$hr_chart_search->{order_by}}, [
                            $or_element->axis_column->chart_line_axis_column,
                            'DESC',
                            { numeric => $h_axis_type{$s_axis} eq 'numeric' },
                        ];
                    }
                }
            }

            my ( %h_strp );
            if ( $or_chart->chart_axis_type_x->chart_axis_type_name eq 'date' ) {
                if ( my $dt_format = $or_chart_line->chart_axis_x_column_format ) {
                    require DateTime::Format::Strptime;
                    $h_strp{x} = DateTime::Format::Strptime->new( pattern => $dt_format );
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
                }
            }

            if ( $or_tiny_url ) {
                my $or_chart_tiny_url_line;
                for my $or_act_line ( $or_tiny_url->chart_tiny_url_line ) {
                    if ( $or_act_line->chart_line_id == $or_chart_line->chart_line_id ) {
                        $or_chart_tiny_url_line = $or_act_line;
                    }
                }
                $hr_chart_search->{where} = [[
                    '=', 'VALUE_ID', map {
                        $_->bench_value_id
                    } $or_chart_tiny_url_line->chart_tiny_url_relation,
                ]];
            }

            my @a_chart_line_points;
            my $ar_chart_points = $or_bench->search_array( $hr_chart_search );

            if ( $ar_chart_points && @{$ar_chart_points} ) {

                for my $or_element ( sort { $a->chart_line_axis_element_number <=> $b->chart_line_axis_element_number } $or_chart_line->chart_axis_elements ) {
                    if ( $or_element->axis_column ) {
                        push @a_first, [ $or_element->axis_column->chart_line_axis_column, $ar_chart_points->[-1]{$or_element->axis_column->chart_line_axis_column} ];
                        push @a_last , [ $or_element->axis_column->chart_line_axis_column, $ar_chart_points->[ 0]{$or_element->axis_column->chart_line_axis_column} ];
                    }
                }

                for my $hr_point ( @{$ar_chart_points} ) {

                    my $hr_chart_point = { x => q##, y => q##, additionals => {} };
                    for my $or_element ( sort { $a->chart_line_axis_element_number <=> $b->chart_line_axis_element_number } $or_chart_line->chart_axis_elements ) {
                        $hr_chart_point->{$or_element->chart_line_axis} .= $or_element->axis_column
                            ? $hr_point->{$or_element->axis_column->chart_line_axis_column}
                            : $or_element->axis_separator->chart_line_axis_separator
                        ;
                    }

                    for my $s_axis (qw/ x y /) {
                        $hr_chart_point->{$s_axis.'o'} = $hr_chart_point->{$s_axis};
                        if ( $h_strp{$s_axis} ) {
                            $hr_chart_point->{$s_axis} = $formatter->format_datetime(
                                $h_strp{$s_axis}->parse_datetime( $hr_chart_point->{$s_axis.'o'} )
                            );
                        }
                    }

                    if ( $or_chart->order_by_x_axis == 1 && $or_chart->order_by_y_axis == 2 ) {
                        $hr_chart_point->{'yh'} = $hr_chart_point->{'x'}.'|-|'.$hr_chart_point->{'y'};
                    }
                    elsif ( $or_chart->order_by_x_axis == 2 && $or_chart->order_by_y_axis == 1 ) {
                        $hr_chart_point->{'xh'} = $hr_chart_point->{'y'}.'|-|'.$hr_chart_point->{'x'};
                    }

                    for my $s_axis (qw/ x y /) {
                        if ( $h_label_type{$s_axis} eq 'list' ) {
                            $hr_chart_point->{$s_axis.'h'} //= $hr_chart_point->{$s_axis.'o'};
                            $hr_chart_point->{$s_axis}       = $h_axis{$s_axis}{$hr_chart_point->{$s_axis.'h'}} //= $h_counter{$s_axis}++;
                        }
                    }

                    for my $ar_chart_line_addition ( @a_additionals ) {
                        $hr_chart_point->{additionals}{$ar_chart_line_addition->[0]} = [
                            $hr_point->{$ar_chart_line_addition->[0]},
                        ];
                        if ( $ar_chart_line_addition->[1] ) {
                            $hr_chart_point->{additionals}{$ar_chart_line_addition->[0]}[1] =
                                $ar_chart_line_addition->[1];
                        }
                    }

                    if (( defined $hr_chart_point->{x} ) && ( defined $hr_chart_point->{y} )) {
                        push @a_chart_line_points, $hr_chart_point;
                    }

                }

            }

            push @a_result, {
                data          => \@a_chart_line_points,
                label         => $or_chart_line->chart_line_name,
                chart_line_id => $or_chart_line->chart_line_id,
            };

        }

        my %h_sort_function = (
            date                  => sub { $_[0] <=> $_[1] },
            numeric               => sub { $_[0] <=> $_[1] },
            alphanumeric          => sub { $_[0] cmp $_[1] },
        );

        $h_sort_function{x_first_array} =  sub {
               $h_sort_function{$h_axis_type{x}}->( $_[0]->[0], $_[1]->[0] )
            || $h_sort_function{$h_axis_type{y}}->( $_[0]->[1], $_[1]->[1] )
        };
        $h_sort_function{y_first_array} =  sub {
               $h_sort_function{$h_axis_type{y}}->( $_[0]->[0], $_[1]->[0] )
            || $h_sort_function{$h_axis_type{x}}->( $_[0]->[1], $_[1]->[1] )
        };
        $h_sort_function{x_first_hash} =  sub {
              $_[0]->{x} <=> $_[1]->{x}
           || $_[0]->{y} <=> $_[1]->{y}
        };
        $h_sort_function{y_first_hash} =  sub {
               $_[0]->{y} <=> $_[1]->{y}
            || $_[0]->{x} <=> $_[1]->{x}
        };

        # sortiere die Labels
        if ( $h_label_type{x} eq 'list' ) {
            my $i_counter = 0;
            if ( $or_chart->order_by_x_axis == 2 && $or_chart->order_by_y_axis == 1 ) {
                for my $ar_key ( sort { $h_sort_function{'y_first_array'}->( $a, $b ) } map {[split /\|-\|/, $_]} keys %{$h_axis{x}} ) {
                    $h_axis{x}{join '|-|', @{$ar_key}} = $i_counter++;
                }
            }
            else {
                for my $s_key ( sort { $h_sort_function{$h_axis_type{x}}->( $a, $b ) } keys %{$h_axis{x}} ) {
                    $h_axis{x}{$s_key} = $i_counter++;
                }
            }
        }
        if ( $h_label_type{y} eq 'list' ) {
            my $i_counter = 0;
            if ( $or_chart->order_by_x_axis == 1 && $or_chart->order_by_y_axis == 2 ) {
                for my $ar_key ( sort { $h_sort_function{'x_first_array'}->( $a, $b ) } map {[split /\|-\|/, $_]} keys %{$h_axis{y}} ) {
                    $h_axis{y}{join '|-|', @{$ar_key}} = $i_counter++;
                }
            }
            else {
                for my $s_key ( sort { $h_sort_function{$h_axis_type{y}}->( $a, $b ) } keys %{$h_axis{y}} ) {
                    $h_axis{y}{$s_key} = $i_counter++;
                }
            }
        }
        # setze die richtigen Label-Verknüpfungen nach der sortierung
        for my $hr_line ( @a_result ) {
            for my $hr_point ( @{$hr_line->{data}} ) {
                for my $s_axis (qw/ x y /) {
                    if ( $h_label_type{$s_axis} eq 'list' ) {
                        $hr_point->{$s_axis} = $h_axis{$s_axis}{delete $hr_point->{$s_axis.'h'}};
                    }
                }
            }
        }
        # sortiere die Datenpunkte
        AXIS: for my $s_axis (qw/ x y /) {
            if ( $or_chart->get_column('order_by_'.$s_axis.'_axis') == 1 ) {
                for my $hr_line ( @a_result ) {
                    @{$hr_line->{data}} = sort { $h_sort_function{$s_axis.'_first_hash'}->( $a, $b ) } @{$hr_line->{data}};
                }
                last AXIS;
            }
        } # AXIS

    }

    $or_c->stash->{content} = {
        chart_type      => $or_chart->chart_type->chart_type_flot_name,
        xaxis_alphas    => [ map { [ $h_axis{x}{$_}, $_ ] } keys %{$h_axis{x}} ],
        yaxis_alphas    => [ map { [ $h_axis{y}{$_}, $_ ] } keys %{$h_axis{y}} ],
        xaxis_type      => $or_chart->chart_axis_type_x->chart_axis_type_name,
        yaxis_type      => $or_chart->chart_axis_type_y->chart_axis_type_name,
        order_by_x_axis => $or_chart->order_by_x_axis,
        order_by_y_axis => $or_chart->order_by_y_axis,
        offset          => $h_params{offset} + $h_params{limit},
        series          => \@a_result,
    };

    return 1;

}

sub create_static_url : Local {

    my ( $or_self, $or_c ) = @_;

    my $i_chart_tiny_url_id;
    my $or_schema = $or_c->model('TestrunDB');
    my $hr_params = $or_c->req->params;

    try {
        $or_schema->txn_do(sub {

            if ( $hr_params->{ids} ) {

                require JSON::XS;
                my $ar_ids = JSON::XS::decode_json( $hr_params->{ids} );

                require DateTime;
                my $or_chart_tiny_url = $or_schema->resultset('ChartTinyUrls')->new({
                    created_at   => DateTime->now(),
                });
                $or_chart_tiny_url->insert();

                if ( $i_chart_tiny_url_id = $or_chart_tiny_url->chart_tiny_url_id ) {
                    for my $hr_chart_line ( @{$ar_ids} ) {
                        if ( $hr_chart_line->{chart_line_id} ) {

                            my $or_chart_tiny_url_line = $or_schema->resultset('ChartTinyUrlLines')->new({
                                chart_tiny_url_id => $i_chart_tiny_url_id,
                                chart_line_id     => $hr_chart_line->{chart_line_id},
                            });
                            $or_chart_tiny_url_line->insert();

                            if ( my $i_chart_tiny_url_line_id = $or_chart_tiny_url_line->chart_tiny_url_line_id ) {

                                my @a_relations;
                                for my $i_bench_value_id ( @{$hr_chart_line->{data}} ) {
                                    push @a_relations, {
                                        chart_tiny_url_line_id => $or_chart_tiny_url_line->chart_tiny_url_line_id,
                                        bench_value_id         => $i_bench_value_id,
                                    };
                                }

                                $or_schema->resultset('ChartTinyUrlRelations')->populate(
                                    \@a_relations
                                );

                            }
                            else {
                                die "error: cannot insert tiny url line";
                            }

                        }
                        else {
                            die "error: cannot find chart line id";
                        }
                    }
                }
                else {
                    die "error: cannot insert tiny url";
                }
            }

            $or_c->stash->{content} = {
                chart_tiny_url_id => $i_chart_tiny_url_id,
            };

        });
    }
    catch {
        $or_c->res->status( 500 );
        $or_c->response->body( "Transaction failed: $_" );
    };

    return 1;

}

sub get_columns : Private {

    my ( $or_self, $or_c ) = @_;

    my @a_columnlist = $or_c->model('TestrunDB')
        ->resultset('BenchAdditionalTypes')
        ->get_column('bench_additional_type')
        ->all()
    ;
    my %h_columns = Tapper::Benchmark
        ->new({ dbh => Tapper::Model::model()->storage->dbh, })
        ->{query}
        ->default_columns()
    ;

    push @a_columnlist, keys %h_columns;

    return \@a_columnlist;

}

sub is_column : Private {

    my ( $or_self, $or_c, $s_column ) = @_;

    my %h_columns = Tapper::Benchmark
        ->new({ dbh => Tapper::Model::model()->storage->dbh, })
        ->{query}
        ->default_columns()
    ;

    return 1 if $h_columns{$s_column};

    my @a_columnlist = $or_c->model('TestrunDB')
        ->resultset('BenchAdditionalTypes')
        ->search({ bench_additional_type => $s_column })
        ->get_column('bench_additional_type_id')
        ->all()
    ;

    return @a_columnlist ? 1 : 0;

}

sub edit_chart : Local {

    my ( $or_self, $or_c ) = @_;

    require YAML::Syck;
    require Tapper::Config;
    require Tapper::Benchmark;

    my $or_schema = $or_c->model('TestrunDB');
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

    $or_c->stash->{columns}       = $or_self->get_columns( $or_c );
    $or_c->stash->{head_overview} = 'Metareports - Edit' . ( $or_c->req->params->{asnew} ? ' as New' : q## );

    return 1;

}

sub get_edit_page_chart_hash_by_chart_id {

    my ( $i_chart_id, $or_schema ) = @_;

    my $or_chart = $or_schema->resultset('Charts')->search(
        {
            'me.chart_id' => $i_chart_id,
        },
        {
            prefetch => {
                'chart_lines' => 'chart_additionals',
                'chart_lines' => {
                    'chart_axis_elements' => [
                        'axis_column',
                        'axis_separator',
                    ],
                },
            },
        },
    )->first();

    my $hr_chart = {
        chart_id                => $or_chart->chart_id(),
        chart_name              => $or_chart->chart_name(),
        chart_type_id           => $or_chart->chart_type_id(),
        chart_axis_type_x_id    => $or_chart->chart_axis_type_x_id(),
        chart_axis_type_y_id    => $or_chart->chart_axis_type_y_id(),
        order_by_x_axis         => $or_chart->order_by_x_axis(),
        order_by_y_axis         => $or_chart->order_by_y_axis(),
        chart_lines             => [],
    };

    for my $or_line ( $or_chart->chart_lines ) {
        my ( %h_chart_elements );
        for my $or_element (
            sort {
                  $a->chart_line_axis_element_number <=> $b->chart_line_axis_element_number
            } $or_line->chart_axis_elements
        ) {
            push @{$h_chart_elements{$or_element->chart_line_axis} ||= []},
                $or_element->axis_column
                    ? [ 'column', $or_element->axis_column->chart_line_axis_column, ]
                    : [ 'separator', $or_element->axis_separator->chart_line_axis_separator, ]
            ;
        }
        push @{$hr_chart->{chart_lines}}, {
            chart_line_name         => $or_line->chart_line_name(),
            chart_line_statement    => $or_line->chart_line_statement(),
            chart_line_x_column     => $h_chart_elements{x},
            chart_line_x_format     => $or_line->chart_axis_x_column_format(),
            chart_line_y_column     => $h_chart_elements{y},
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

    my ( $or_self, $or_c, $hr_params, $or_schema ) = @_;

    my $hr_chart = {
        chart_id                => $hr_params->{chart_id},
        chart_name              => $hr_params->{chart_name},
        chart_type_id           => $hr_params->{chart_type},
        chart_axis_type_x_id    => $hr_params->{chart_axis_type_x},
        chart_axis_type_y_id    => $hr_params->{chart_axis_type_y},
        order_by_x_axis         => $hr_params->{order_by_x_axis},
        order_by_y_axis         => $hr_params->{order_by_y_axis},
        chart_lines             => [],
    };

    # column values for chart lines
    my @a_chart_line_names      = @{toarrayref($hr_params->{chart_line_name})};
    my @a_chart_line_x_columns  = @{toarrayref($hr_params->{chart_axis_x_column})};
    my @a_chart_line_y_columns  = @{toarrayref($hr_params->{chart_axis_y_column})};
    my @a_chart_line_x_counters = @{toarrayref($hr_params->{chart_axis_x_counter})};
    my @a_chart_line_y_counters = @{toarrayref($hr_params->{chart_axis_y_counter})};
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
        ->new({ dbh => $or_schema->storage->dbh, })
        ->{query}
        ->default_columns()
    ;

    while ( my $s_chart_line_name = shift @a_chart_line_names ) {

        my $hr_chart_line_statement = { select => [], where => [], };
        my $s_chart_line_x_format   = shift @a_chart_line_x_formats;
        my $s_chart_line_y_format   = shift @a_chart_line_y_formats;
        my $i_chart_where_counter   = shift @a_chart_where_counter;
        my $i_chart_add_counter     = shift @a_chart_add_counter;
        my $i_chart_line_x_counter  = shift @a_chart_line_x_counters;
        my $i_chart_line_y_counter  = shift @a_chart_line_y_counters;

        my @a_act_chart_line_x_columns;
        for my $i_chart_line_x_counter ( 1..$i_chart_line_x_counter ) {
            my $s_chart_line_x_column = shift @a_chart_line_x_columns;
            if ( $or_self->is_column( $or_c, $s_chart_line_x_column ) ) {
                if (! $h_default_columns{$s_chart_line_x_column} ) {
                    push @{$hr_chart_line_statement->{select}}, $s_chart_line_x_column;
                }
                push @a_act_chart_line_x_columns, [ 'column', $s_chart_line_x_column ];
            }
            else {
                push @a_act_chart_line_x_columns, [ 'separator', $s_chart_line_x_column ];
            }
        }

        my @a_act_chart_line_y_columns;
        for my $i_chart_line_y_counter ( 1..$i_chart_line_y_counter ) {
            my $s_chart_line_y_column = shift @a_chart_line_y_columns;
            if ( $or_self->is_column( $or_c, $s_chart_line_y_column ) ) {
                if (! $h_default_columns{$s_chart_line_y_column} ) {
                    push @{$hr_chart_line_statement->{select}}, $s_chart_line_y_column;
                }
                push @a_act_chart_line_y_columns, [ 'column', $s_chart_line_y_column ];
            }
            else {
                push @a_act_chart_line_y_columns, [ 'separator', $s_chart_line_y_column ];
            }
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
            chart_line_x_column  => \@a_act_chart_line_x_columns,
            chart_line_x_format  => $s_chart_line_x_format || undef,
            chart_line_y_column  => \@a_act_chart_line_y_columns,
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

    my $hr_search_param = {
        active      => 1,
        chart_name  => $hr_params->{chart_name},
    };
    if ( $hr_params->{chart_id} ) {
        $hr_search_param->{-not} = { chart_id => $hr_params->{chart_id} };
    }

    my @a_charts = $or_schema->resultset('Charts')->search( $hr_search_param );
    if ( @a_charts ) {
        $or_c->stash->{error} = 'chart name already exists';
        $or_c->go('/tapper/metareports/edit_chart');
    }

    # serialize input data
    $or_c->stash->{chart} = $or_self->get_edit_page_chart_hash_by_params(
        $or_c, $hr_params, $or_schema,
    );

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

    $or_c->redirect('/tapper/metareports/chart_overview?owner_id=' . $or_c->req->params->{owner_id});
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

    $or_c->redirect('/tapper/metareports/chart_overview?owner_id=' . $or_c->req->params->{owner_id});
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
        order_by_x_axis         => $hr_params->{order_by_x_axis},
        order_by_y_axis         => $hr_params->{order_by_y_axis},
        active                  => 1,
        created_at              => \'NOW()',
    });
    $or_chart->insert();

    if ( my $i_chart_id = $or_chart->chart_id() ) {

        my $ar_columns = $or_self->get_columns( $or_c );
        for my $hr_chart_line ( @{$hr_params->{chart_lines}} ) {

            my $or_chart_line = $or_c->model('TestrunDB')->resultset('ChartLines')->new({
                chart_id                    => $i_chart_id,
                chart_line_name             => $hr_chart_line->{chart_line_name},
                chart_axis_x_column_format  => $hr_chart_line->{chart_line_x_format} || undef,
                chart_axis_y_column_format  => $hr_chart_line->{chart_line_y_format} || undef,
                chart_line_statement        => $hr_chart_line->{chart_line_statement},
            });
            $or_chart_line->insert();

            if ( my $i_chart_line_id = $or_chart_line->chart_line_id ) {

                for my $s_axis (qw/ x y /) {
                    my $i_chart_line_number = 0;
                    for my $ar_element ( @{$hr_chart_line->{'chart_line_' . $s_axis . '_column'}} ) {
                        my $or_chart_element = $or_c->model('TestrunDB')->resultset('ChartLineAxisElements')->new({
                            chart_line_id                  => $i_chart_line_id,
                            chart_line_axis                => $s_axis,
                            chart_line_axis_element_number => ++$i_chart_line_number,
                        });
                        $or_chart_element->insert();
                        if ( my $i_element_id = $or_chart_element->chart_line_axis_element_id ) {
                            if ( $ar_element->[0] eq 'column' ) {
                                $or_c->model('TestrunDB')->resultset('ChartLineAxisColumns')->new({
                                    chart_line_axis_element_id => $i_element_id,
                                    chart_line_axis_column     => $ar_element->[1],
                                })->insert();
                            }
                            else {
                                $or_c->model('TestrunDB')->resultset('ChartLineAxisSeparators')->new({
                                    chart_line_axis_element_id => $i_element_id,
                                    chart_line_axis_separator  => $ar_element->[1],
                                })->insert();
                            }
                        }
                        else {
                            die 'cannot insert chart line element';
                        }
                    }
                }

                for my $hr_additionals ( @{$hr_chart_line->{chart_additionals}} ) {
                    $or_c->model('TestrunDB')->resultset('ChartLineAdditionals')->new({
                        chart_line_id                => $i_chart_line_id,
                        chart_line_additional_column => $hr_additionals->{chart_line_additional_column},
                        chart_line_additional_url    => $hr_additionals->{chart_line_additional_url} || undef,
                    })->insert();
                }

            }
            else {
                die 'cannot insert chart line'
            }

        }

    }
    else {
        die 'cannot insert chart';
    }

    return 1;

}

sub remove_chart : Private {

    my ( $or_self, $or_c ) = @_;

    if (! $or_c->req->params->{chart_id} ) {
        return 'chart_id is missing';
    }

    my $or_chart = $or_c->model('TestrunDB')->resultset('Charts')->find(
        $or_c->req->params->{chart_id},
    );

    $or_chart->active(0);
    $or_chart->updated_at(\'NOW()');
    $or_chart->update();

    return q##;

}

sub get_benchmark_operators : Private {

    my ( $or_self, $or_c ) = @_;

    require YAML::Syck;
    require Tapper::Config;
    require Tapper::Benchmark;

    return Tapper::Benchmark
        ->new({ dbh => Tapper::Model::model()->storage->dbh, })
        ->{query}
        ->benchmark_operators()
    ;

}

sub base : Chained PathPrefix CaptureArgs(0) {
    my ( $self, $c ) = @_;
    my $rule =  File::Find::Rule->new;
    $c->stash(rule => $rule);
}

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
