#!/usr/bin/perl
# PODNAME: tapper_reports_web_test.pl
# ABSTRACT: Tapper - web gui test

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('Tapper::Reports::Web', 'Test');

1;

=head1 SYNOPSIS

tapper_reports_web_test.pl [options] uri

 Options:
   --help    display this help and exits

 Examples:
   tapper_reports_web_test.pl http://localhost/some_action
   tapper_reports_web_test.pl /some_action

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst action from the command line.

=cut
