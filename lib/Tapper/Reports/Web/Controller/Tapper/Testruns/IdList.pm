package Tapper::Reports::Web::Controller::Tapper::Testruns::IdList;

use 5.010;

use strict;
use warnings;
use Tapper::Reports::Web::Util::Testrun;

use parent 'Tapper::Reports::Web::Controller::Base';


sub auto :Private
{
        my ( $self, $c ) = @_;
        $c->forward('/tapper/testruns/idlist/prepare_navi');
}


=head2 index

Index function for /tapper/testruns/idlist/. Expects a comma separated
list of testrun ids. The requested testruns are put into stash as has
%testrunlist because we use the template /tapper/testruns/testrunlist.mas
which expects this.

@param string - comma separated ids

@stash hash   - hash with key testruns => array of testrun hashes

@return ignored

=cut

sub index :Path :Args(1)
{
        my ( $self, $c, $idlist ) = @_;

        %{$c->stash->{testrunlist}} = ();
        my $filter_condition;

        my @ids = split (qr/, */, $idlist);

        $filter_condition = {
                             id  => { '-in' => [@ids] }
                            };


        my $util = Tapper::Reports::Web::Util::Testrun->new();
        my $testruns = $c->model('TestrunDB')->resultset('Testrun')->search
          (
           $filter_condition,
           {
            order_by => 'me.id desc' }
          );

        %{$c->stash->{testrunlist}} = (testruns => $util->prepare_testrunlist($testruns) );

}

sub prepare_navi :Private
{
        my ( $self, $c, $id ) = @_;

        # When showing test by ID no filters are active so we
        # remove the wrong filters Testrun::prepare_navi already added
        my @navi = grep {$_->{title} ne "Active Filters"} @{$c->stash->{navi}};
        $c->stash->{navi} = \@navi;
}



1;
