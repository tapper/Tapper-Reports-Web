package Tapper::Reports::Web::Controller::Tapper::Reports::Info;

use strict;
use warnings;

use Data::Dumper;

use parent 'Tapper::Reports::Web::Controller::Base';

sub firstid :Path('firstid') :Args(0) {
    my ( $self, $c ) = @_;

    # SELECT MIN(id) FROM report;
    my $first_id = $c->model('TestrunDB')->resultset('Report')->get_column("id")->min;
    $c->response->body($first_id);
}

sub lastid :Path('lastid') :Args(0) {
    my ( $self, $c ) = @_;

    # SELECT MAX(id) FROM report;
    my $last_id = $c->model('TestrunDB')->resultset('Report')->get_column("id")->max;
    $c->response->body($last_id);
}

1;
