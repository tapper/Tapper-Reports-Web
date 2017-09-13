package Tapper::Reports::Web::Controller::Tapper::Testplan::Id;

use parent 'Tapper::Reports::Web::Controller::Base';

use common::sense;
## no critic (RequireUseStrict)
use Tapper::Model 'model';
use Tapper::Reports::Web::Util::Testrun;

use Data::DPath 'dpath';
use File::Basename 'basename';
use YAML::Syck 'Load';

sub auto :Private
{
        my ( $self, $c ) = @_;
        $c->forward('/tapper/testplan/id/prepare_navi');
}



=head2 parse_testrun

Generate an overview of a testplan element from testrun description.

@param hash ref  - describes testrun

@return hash ref - overview of testrun

=cut

sub parse_testrun
{
        my ($self, $testrun) = @_;
        my $description = $testrun->{description};
        my %testrun;

        # several places for the root system
        push @{$testrun{image}}, dpath('/preconditions/*/mount[value eq "/"]/../image')->match($description);
        push @{$testrun{image}}, dpath('//root/precondition_type[value eq "autoinstall"]/../name')->match($description);
        push @{$testrun{image}}, dpath('//precondition_type[value eq "autoinstall"]/../name')->match($description);

        push @{$testrun{kernel}}, dpath('/preconditions/*/filename[ value =~ /linux-.*\d+.\d+/]')->match($description);
        push @{$testrun{test}},
         map { $? ? basename($_) : () }
          dpath('/preconditions/*/precondition_type[ value eq "testprogram"]/../program')->match($description);
        $testrun{shortname} = $description->{shortname};
        return \%testrun;
}


=head2 gen_testplan_overview

Generate an overview from evaluated testplan.

@param string - plan as YAML text

@return array ref - overview of all testplan elements

=cut

sub gen_testplan_overview
{
        my ($self, $c, $yaml) = @_;

        my @plans;
        eval {
                @plans = Load($yaml);
        };
        if ($@) {
                $c->stash->{error} = "Broken YAML in testplan: $@";
                return [];
        }
        my @testplan_elements;

        foreach my $plan (@plans) {
                given ($plan->{type})
                {
                        when(['multitest', 'testrun'])  { push @testplan_elements, $self->parse_testrun($plan) }
                }
        }
        return \@testplan_elements;
}


=head2 index

=cut

sub index :Path :Args(1)
{
        my ( $self, $c, $instance_id ) = @_;

        $c->stash->{title} = "Testplan id $instance_id";

        my $inst_res = model('TestrunDB')->resultset('TestplanInstance')->find($instance_id);
        if (not $inst_res) {
                $c->stash->{error} = "No testplan with id $instance_id";
                return;
        }
        my $util = Tapper::Reports::Web::Util::Testrun->new();
        my $testruns = $inst_res->testruns;
        my $testrunlist = $util->prepare_testrunlist($testruns);

        $c->stash->{instance}{id}       = $inst_res->id;
        $c->stash->{instance}{name}     = $inst_res->name || '[no name]';
        $c->stash->{instance}{testruns} = $testrunlist;
        $c->stash->{instance}{plan}     = $inst_res->evaluated_testplan;
        $c->stash->{instance}{plan}     =~ s/^\n+//m;
        $c->stash->{instance}{plan}     =~ s/\n+/\n/m;
        #$c->stash->{instance}{path}     = $inst_res->path;
        #$c->stash->{instance}{overview} = $self->gen_testplan_overview($c, $c->stash->{instance}{plan});
        $c->stash->{title} = "Testplan id $instance_id, ".$c->stash->{instance}{name};
        return;
}

sub prepare_navi :Private
{
        my ( $self, $c, $id ) = @_;

        # When showing testplans by ID no filters are active so we
        # remove the wrong filters Testplan::prepare_navi already added
        my @navi = grep {$_->{title} ne "Active Filters"} @{$c->stash->{navi}};
        $c->stash->{navi} = \@navi;

        push @{$c->stash->{navi}}, { title => 'Rerun this testplan',
                       href  => "/tapper/testplan/$id/rerun",
                       confirm => 'Do you really want to RERUN this test plan?',
                     };
        push @{$c->stash->{navi}}, { title => 'Cancel this testplan',
                                     href  => "/tapper/testplan/$id/cancel",
                                     confirm => 'Do you really want to CANCEL this testplan?',
                     };
}


=head1 NAME

Tapper::Reports::Web::Controller::Tapper::Testplan - Catalyst Controller for test plans

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 index



=head1 AUTHOR

AMD OSRC Tapper Team, C<< <tapper at amd64.org> >>

=head1 LICENSE

This program is released under the following license: freebsd

=cut

1;
