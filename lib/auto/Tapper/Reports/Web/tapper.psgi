#!/usr/bin/env perl

use strict;
use warnings;

use lib
    '/home/local/ANT/schaefr/git/Tapper-Reports-Web/lib',
    '/home/local/ANT/schaefr/git/Tapper-Benchmark/lib',
    '/home/local/ANT/schaefr/git/Tapper-Schema/lib',
    '/home/local/ANT/schaefr/git/Tapper-Model/lib'
;

use Tapper::Reports::Web;

Tapper::Reports::Web->setup_engine('PSGI');

my $or_app = sub {
    Tapper::Reports::Web->run(@_);
};
