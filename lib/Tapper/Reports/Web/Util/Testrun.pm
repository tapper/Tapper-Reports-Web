package Tapper::Reports::Web::Util::Testrun;

use Moose;
use Tapper::Model 'model';

use common::sense;

=head2 prepare_testrunlist

For each of the given testruns generate a hash describing the
testrun. This hash is used to display the testrun in the template.

hash contains:
* primary_report_id
* success_ratio
* testrun_id
* suite_name
* host_name
* status
* created_at
* updated_at

@param DBIC resultset - testruns

@return array ref - list of hash refs describing the testruns

=cut


sub prepare_testrunlist
{
        my ( $self, $testruns ) = @_;


        my @testruns;
        foreach my $testrun ($testruns->all)
        {
                my $testrun_report = model('ReportsDB')->resultset('ReportgroupTestrunStats')->search({testrun_id => $testrun->id})->first;
                my ($primary_report, $suite_name, $updated_at, $primary_report_id);

                if ($testrun_report) {
                        $primary_report = $testrun_report->reportgrouptestruns->search({primaryreport => 1})->first;
                        eval{ # prevent dereferencing to undefined db links
                                if ($primary_report) {
                                        $suite_name        = $primary_report->report->suite->name;
                                        $updated_at        = $primary_report->report->updated_at || $primary_report->created_at;
                                        $primary_report_id = $primary_report->report->id;
                                }
                        };
                        say STDERR $@ if $@;
                }

                my $created_at_ymd_hm = $testrun->created_at;
                $created_at_ymd_hm    =~ s/:\d\d$//;

                my $tr = {
                          testrun_id            => $testrun->id,
                          success_ratio         => $testrun_report ? $testrun_report->success_ratio : 0,
                          primary_report_id     => $primary_report_id,
                          suite_name            => $suite_name || $testrun->topic_name,
                          machine_name          => $testrun->testrun_scheduling->host->name || 'unknownmachine',
                          status                => $testrun->testrun_scheduling->status || 'unknown status',
                          created_at            => $testrun->created_at,
                          updated_at            => $updated_at || $testrun->updated_at,
                         };
                push @testruns, $tr;
        }
        return  \@testruns;
}


1;