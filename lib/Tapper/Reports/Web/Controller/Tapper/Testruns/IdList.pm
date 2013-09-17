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

        $c->stash->{testrunlist} = $c->model('TestrunDB')->fetch_raw_sql({
            query_name  => 'testruns::web_list',
            fetch_type  => '@%',
            query_vals  => {
                testrun_id   => [ split (qr/, */, $idlist) ],
                testrun_date => $c->req->params->{testrun_date},
            },
        });

        return 1;

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
