package Tapper::Reports::Web::Util;

use Moose;
use strict;
use warnings;
use 5.010;

use Perl6::Junction qw /any/;

=head1 NAME

Tapper::Reports::Web::Util - Basic utilities for all Tapper::Reports::Web controller

=head1 SYNOPSIS

 use Tapper::Reports::Web::Util;
 my $util = Tapper::Reports::Web::Util->new();
 $util->prepare_top_menu($active_system);

=head1 METHODS

=head2 prepare_top_menu

Creates the required datastructure to show the top menu in all pages.

@param string - active element

@return hash ref containing top menu

=cut

sub prepare_top_menu
{
        my ($self, $active) = @_;
        my $top_menu = [
                        {key => 'start',       text => 'Start',       uri => "/tapper/start/"},
                        {key => 'reports',     text => 'Reports',     uri => "/tapper/reports"},
                        {key => 'testruns',    text => 'Testruns',    uri => "/tapper/testruns"},
                        {key => 'testplans',   text => 'Testplans',   uri => "/tapper/testplan"},
                        {key => 'metareports', text => 'Metareports', uri => "/tapper/metareports/"},
                        {key => 'manual',      text => 'Manual',      uri => "/tapper/manual/"},
                        {key => 'user',        text => 'Login',       uri => "/tapper/user/login"},
                       ];

        # Some keys may be singular with their actions being named in plural or vice versa. Unify this.
        if ($active) {
                $active = lc($active);
                (my $active_singular) = ($active =~ m/^(.+)s$/) // '';
                (my $active_plural)   = $active."s" // '';
                foreach (@$top_menu) { $_->{active} = 1 if $_->{key} eq any($active, $active_singular, $active_plural) }
        }
        return $top_menu;
}



1;

=head1 AUTHOR

AMD OSRC Tapper Team, C<< <tapper at amd64.org> >>

=head1 BUGS

None.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

 perldoc Tapper


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008-2011 AMD OSRC Tapper Team, all rights reserved.

This program is released under the following license: freebsd


