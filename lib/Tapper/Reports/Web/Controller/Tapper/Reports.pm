package Tapper::Reports::Web::Controller::Tapper::Reports;

use parent 'Tapper::Reports::Web::Controller::Base';

use DateTime::Format::Natural;
use Data::Dumper;

use Tapper::Reports::Web::Util::Filter::Report;
use Tapper::Reports::Web::Util::Report;
use common::sense;
## no critic (RequireUseStrict)

sub auto :Private
{
        my ( $self, $c ) = @_;

        $c->forward('/tapper/reports/prepare_navi');
}

sub index :Path :Args()
{
        my ( $self, $c, @args ) = @_;

        exit 0 if $args[0] eq 'exit';

        my $filter = Tapper::Reports::Web::Util::Filter::Report->new(context => $c);
        my $filter_condition = $filter->parse_filters(\@args);

        if ($filter_condition->{error}) {
                $c->flash->{error_msg} = join("; ", @{$filter_condition->{error}});
                $c->res->redirect("/tapper/reports/days/2");

        }

        $c->stash->{requested_day} =
          $filter->requested_day || DateTime::Format::Natural->new->parse_datetime("today at midnight");

        $filter->{early}->{-or} = [{rga_primary => 1}, {rgt_primary => 1}];
        $c->forward('/tapper/reports/prepare_this_weeks_reportlists', [ $filter_condition ]);

}

sub prepare_this_weeks_reportlists : Private {

        my ( $self, $c, $filter_condition ) = @_;

        if ( !$filter_condition->{early} || !( ref $filter_condition->{early} eq 'HASH' ) ) {
            $filter_condition->{early} = {};
        }

        $c->stash->{reports} = $c->model('ReportsDB')->fetch_raw_sql({
            query_name  => 'reports::web_list',
            fetch_type  => '@%',
            query_vals  => {
                suite_id         => $filter_condition->{early}{suite_id}{in},
                machine_name     => $filter_condition->{early}{machine_name}{in},
                success_ratio    => $filter_condition->{early}{success_ratio},
                successgrade     => $filter_condition->{early}{successgrade},
                days             => !$filter_condition->{date} && !$filter_condition->{days} ? 7 : $filter_condition->{days},
                date             => $filter_condition->{date},
                (
                    exists $filter_condition->{late}
                        ? ( owner => $filter_condition->{late}[0]{-or}[0]{'reportgrouptestrun.owner'} )
                        : ()
                )
            },
        });

        $c->stash->{title} = "Reports of last ".$c->stash->{days}." days";

}


sub prepare_navi : Private
{
        my ( $self, $c ) = @_;
        $c->stash->{navi} = [];

        my %args = @{$c->req->arguments};

        if ( (grep { /^date$/ } keys %args) or                    # "/date" can not be combined usefully with generic filters
             ($c->req->path =~ m,tapper/reports/(id|idlist|tap),) # these controller paths are special, not generic filters
            ) {
                 $c->stash->{navi} = [
                          {
                           title  => "reports by date",
                           href   => "/tapper/overview/date",
                           subnavi => [
                                       {
                                        title  => "today",
                                        href   => "/tapper/reports/days/1",
                                       },
                                       {
                                        title  => "2 days",
                                        href   => "/tapper/reports/days/2",
                                       },
                                       {
                                        title  => "1 week",
                                        href   => "/tapper/reports/days/7",
                                       },
                                       {
                                        title  => "2 weeks",
                                        href   => "/tapper/reports/days/14",
                                       },
                                       {
                                        title  => "3 weeks",
                                        href   => "/tapper/reports/days/21",
                                       },
                                       {
                                        title  => "1 month",
                                        href   => "/tapper/reports/days/31",
                                       },
                                       {
                                        title  => "2 months",
                                        href   => "/tapper/reports/days/62",
                                       },
                                       {
                                        title  => "4 months",
                                        href   => "/tapper/reports/days/124",
                                       },
                                       {
                                        title  => "6 months",
                                        href   => "/tapper/reports/days/182",
                                       },
                                       {
                                        title  => "12 months",
                                        href   => "/tapper/reports/days/365",
                                       },

                                      ],
                          },
                          {
                           title  => "reports by suite",
                           href   => "/tapper/overview/suite",
                          },
                          {
                           title  => "reports by host",
                           href   => "/tapper/overview/host",
                          },
                         ];
        } else {
                $c->stash->{navi} = [
                         {
                          title  => "reports by date",
                          href   => "/tapper/overview/date",
                          subnavi => [
                                      {
                                       title  => "today",
                                       href   => "/tapper/reports/".$self->prepare_filter_path($c, 1),
                                      },
                                      {
                                       title  => "2 days",
                                       href   => "/tapper/reports/".$self->prepare_filter_path($c, 2),
                                      },
                                      {
                                       title  => "1 week",
                                       href   => "/tapper/reports/".$self->prepare_filter_path($c, 7),
                                      },
                                      {
                                       title  => "2 weeks",
                                       href   => "/tapper/reports/".$self->prepare_filter_path($c, 14),
                                      },
                                      {
                                       title  => "3 weeks",
                                       href   => "/tapper/reports/".$self->prepare_filter_path($c, 21),
                                      },
                                      {
                                       title  => "1 month",
                                       href   => "/tapper/reports/".$self->prepare_filter_path($c, 31),
                                      },
                                      {
                                       title  => "2 months",
                                       href   => "/tapper/reports/".$self->prepare_filter_path($c, 62),
                                      },
                                      {
                                       title  => "4 months",
                                       href   => "/tapper/reports/".$self->prepare_filter_path($c, 124),
                                      },
                                      {
                                       title  => "6 months",
                                       href   => "/tapper/reports/".$self->prepare_filter_path($c, 182),
                                      },
                                      {
                                       title  => "12 months",
                                       href   => "/tapper/reports/".$self->prepare_filter_path($c, 365),
                                      },

                                     ],
                         },
                         {
                          title  => "reports by suite",
                          href   => "/tapper/overview/suite",
                         },
                         {
                          title  => "reports by host",
                          href   => "/tapper/overview/host",
                         },
                         {
                          title  => "This list as RSS",
                          href   => "/tapper/rss/".$self->prepare_filter_path($c),
                          image  => "/tapper/static/images/rss.png",
                         },
                         {
                          title  => "reports by people",
                          href   => "/tapper/reports/people/",
                          active => 0,
                         },
                        ];
                push @{$c->stash->{navi}}, {title   => 'Active Filters',
                              subnavi => [
                                          map {
                                               { title => "$_: ".$args{$_},
                                                 href  => "/tapper/reports/".$self->reduced_filter_path(\%args, $_),
                                                 image => "/tapper/static/images/minus.png",
                                               }
                                              } keys %args
                                         ]};
        }

}

1;
