package Tapper::Reports::Web::Controller::Tapper::User;

use strict;
use warnings;
use 5.010;
use parent 'Tapper::Reports::Web::Controller::Base';

=head1 NAME

Tapper::Reports::Web::Controller::Tapper::User - Catalyst Controller for user handling

=head1 DESCRIPTION

Catalyst Controller .

=head1 METHODS

All methods described in here expect the object (because they are
methods) and the catalyst context (because they are catalyst controller
methods) as the first two parameters. The method API documentation will
not name these two parameters explicitly.

=head2 index



=cut 

sub index :Path :Args(0)
{
        my ( $self, $c ) = @_;
}


=head2 login

=cut

sub login :Local :Args(0)
{
        my ($self, $c) = @_;
        $c->stash->{'template'} = 'tapper/user/login.mas';
        if ( exists($c->req->params->{'username'})) {
                if ( $c->authenticate({ username => $c->req->params->{'username'},
                                        password => $c->req->params->{'password'},
                                      })) {
                        $c->response->redirect('/tapper/start');
                        $c->detach();
                        return;
                } else {
                        $c->stash->{message} = 'Invalid login';
                }
        }
}

=head2 logout

=cut

sub logout :Local :Args(0) {
        my ($self, $c) = @_;
        $c->stash->{template} = 'tapper/user/logout.mas';
        $c->logout();
        $c->response->redirect('/tapper/start');
        $c->detach();
        return;
}



=head1 AUTHOR

AMD OSRC Tapper Team, C<< <tapper at amd64.org> >>

=head1 LICENSE

This program is released under the following license: freebsd

=cut

1;


