#!/usr/bin/perl
# PODNAME: tapper_reports_web_fastcgi.pl
# ABSTRACT: Tapper - web gui start script - fastcgi

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('Tapper::Reports::Web', 'FastCGI');

1;

=head1 NAME

tapper_reports_web_fastcgi.pl - Catalyst FastCGI

=head1 SYNOPSIS

tapper_reports_web_fastcgi.pl [options]

 Options:
   -? -help      display this help and exits
   -l --listen   Socket path to listen on
                 (defaults to standard input)
                 can be HOST:PORT, :PORT or a
                 filesystem path
   -n --nproc    specify number of processes to keep
                 to serve requests (defaults to 1,
                 requires -listen)
   -p --pidfile  specify filename for pid file
                 (requires -listen)
   -d --daemon   daemonize (requires -listen)
   -M --manager  specify alternate process manager
                 (FCGI::ProcManager sub-class)
                 or empty string to disable
   -e --keeperr  send error messages to STDOUT, not
                 to the webserver
   --proc_title  Set the process title (if possible)

=cut
