#! /usr/bin/perl

BEGIN { $ENV{CATALYST_ENGINE} ||= 'CGI' }

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tapper::Reports::Web;

Tapper::Reports::Web->run;

1;

=head1 NAME

tapper_reports_web_cgi.pl - Catalyst CGI

=head1 SYNOPSIS

See L<Catalyst::Manual>

=head1 DESCRIPTION

Run a Catalyst application as a cgi script.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This program is released under the following license: freebsd

=cut
