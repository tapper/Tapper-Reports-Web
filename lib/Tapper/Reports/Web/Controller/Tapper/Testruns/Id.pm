package Tapper::Reports::Web::Controller::Tapper::Testruns::Id;

use 5.010;

use strict;
use warnings;
use Tapper::Model 'model';
use Tapper::Reports::Web::Util::Report;

use parent 'Tapper::Reports::Web::Controller::Base';


sub auto :Private
{
        my ( $self, $c ) = @_;

        $c->forward('/tapper/testruns/id/prepare_navi');
}


sub index :Path :Args(1)
{
        my ( $self, $c, $testrun_id ) = @_;
        my $report        : Stash;
        my $testrun       : Stash;
        my $overview      : Stash;
        my $hostname      : Stash;
        my $time          : Stash;


        my $reportlist_rgt : Stash = {};
        eval {
                $testrun = $c->model('TestrunDB')->resultset('Testrun')->find($testrun_id);
        };
        if ($@ or not $testrun) {
                $c->response->body(qq(No testrun with id "$testrun_id" found in the database!));
                return;
        }

        return unless $testrun->testrun_scheduling;

        $time     = $testrun->starttime_testrun ? "started at ".$testrun->starttime_testrun : "Scheduled for ".$testrun->starttime_earliest;
        $hostname = $testrun->testrun_scheduling->host ? $testrun->testrun_scheduling->host->name : "unknown";

        $c->stash->{title} = "Testrun $testrun_id: ". $testrun->topic_name . " @ $hostname";
        $overview = $c->forward('/tapper/testruns/get_testrun_overview', [ $testrun ]);

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

        $reportlist_rgt = $util_report->prepare_simple_reportlist($c,  $rgt_reports);
        $report = $c->model('ReportsDB')->resultset('Report')->search
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

        my $navi : Stash = [
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
