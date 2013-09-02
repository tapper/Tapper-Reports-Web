package Tapper::Reports::Web::Controller::Tapper::Testruns::Id;

use 5.010;

use strict;
use warnings;
use Tapper::Model 'model';
use Tapper::Reports::Web::Util::Report;
use YAML::Syck;

use parent 'Tapper::Reports::Web::Controller::Base';


sub auto :Private
{
        my ( $self, $c ) = @_;

        $c->forward('/tapper/testruns/id/prepare_navi');
}


sub index :Path :Args(1)
{
        my ( $self, $c, $testrun_id ) = @_;

        $c->stash->{reportlist_rgt} = {};

        eval {
                $c->stash->{testrun} = $c->model('TestrunDB')->resultset('Testrun')->find($testrun_id);
        };
        if ($@ or not $c->stash->{testrun}) {
                $c->response->body(qq(No testrun with id "$testrun_id" found in the database!));
                return;
        }

        return unless $c->stash->{testrun}->testrun_scheduling;

        $c->stash->{time}     = $c->stash->{testrun}->starttime_testrun ? "started at ".$c->stash->{testrun}->starttime_testrun : "Scheduled for ".($c->stash->{testrun}->starttime_earliest || '');
        $c->stash->{hostname} = $c->stash->{testrun}->testrun_scheduling->host ? $c->stash->{testrun}->testrun_scheduling->host->name : "unknown";

        $c->stash->{title} = "Testrun $testrun_id: ". $c->stash->{testrun}->topic_name . " @ ".$c->stash->{hostname};
        $c->stash->{overview} = $c->forward('/tapper/testruns/get_testrun_overview', [ $c->stash->{testrun} ]);

        my @preconditions_hash = map { $_->precondition_as_hash } $c->stash->{testrun}->ordered_preconditions;
        $YAML::Syck::SortKeys  = 1;
        $c->stash->{precondition_string} = YAML::Syck::Dump(@preconditions_hash);

        my $rgt_reports = $c->model('ReportsDB')->resultset('Report')->search
          (
           {
            "reportgrouptestrun.testrun_id" => $testrun_id
           },
           {  order_by  => 'me.id desc',
              join      => [ 'reportgrouptestrun', 'suite'],
              '+select' => [ 'reportgrouptestrun.testrun_id', 'reportgrouptestrun.primaryreport', 'suite.name', 'suite.type', 'suite.description' ],
              '+as'     => [ 'rgt_id',                        'rgt_primary',                      'suite_name', 'suite_type', 'suite_description' ],
           }
          );
        my $util_report = Tapper::Reports::Web::Util::Report->new();

        $c->stash->{reportlist_rgt} = $util_report->prepare_simple_reportlist($c,  $rgt_reports);
        $c->stash->{report} = $c->model('ReportsDB')->resultset('Report')->search
          (
           {
            "reportgrouptestrun.primaryreport" => 1,
           },
           {
            join => [ 'reportgrouptestrun', ]
           }
           );
}

sub prepare_navi : Private
{
        my ( $self, $c, $testrun_id ) = @_;

        $c->stash->{navi} =[
                            {
                             title  => "Testruns by date",
                             href   => "/tapper/testruns/days/2",
                             active => 0,
                             subnavi => [
                                         {
                                          title  => "today",
                                          href   => "/tapper/testruns/days/1",
                                         },
                                         {
                                          title  => "1 week",
                                          href   => "/tapper/testruns/days/7",
                                         },
                                         {
                                          title  => "2 weeks",
                                          href   => "/tapper/testruns/days/14",
                                         },
                                         {
                                          title  => "3 weeks",
                                          href   => "/tapper/testruns/days/21",
                                         },
                                         {
                                          title  => "1 month",
                                          href   => "/tapper/testruns/days/30",
                                         },
                                         {
                                          title  => "2 months",
                                          href   => "/tapper/testruns/days/60",
                                         },
                                        ],
                            },
                            {
                             title  => "Control",
                             href   => "",
                             active => 0,
                             subnavi => [
                                         {
                                          title  => "Rerun this Testrun",
                                          href   => "/tapper/testruns/$testrun_id/rerun",
                                          confirm => 'Do you really want to re-start this testrun?',
                                         },
                                         {
                                          title  => "Create new Testrun",
                                          href   => "/tapper/testruns/create/",
                                         },
                                        ],
                            },
                           ];
}

1;
