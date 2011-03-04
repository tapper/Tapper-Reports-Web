package Tapper::Reports::Web::Controller::Tapper::Testplan::Taskjuggler;

use parent 'Tapper::Reports::Web::Controller::Base';
use Tapper::Testplan::Plugins::Taskjuggler;

use common::sense;
## no critic (RequireUseStrict)

=head2 index



=cut

sub index :Path :Args(0)
{
        my ( $self, $c ) = @_;
        return
}





=head1 NAME

Tapper::Reports::Web::Controller::Tapper::Testplan::OSRC - Show testplans for OSRC project planning

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
