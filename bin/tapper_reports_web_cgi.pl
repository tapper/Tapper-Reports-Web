#!/usr/bin/perl
# PODNAME: tapper_reports_web_cgi.pl
# ABSTRACT: Tapper - web gui start script - cgi

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('Tapper::Reports::Web', 'CGI');

1;

=head1 SYNOPSIS

See L<Catalyst::Manual>

=head1 DESCRIPTION

Run a Catalyst application as a cgi script.

=cut

