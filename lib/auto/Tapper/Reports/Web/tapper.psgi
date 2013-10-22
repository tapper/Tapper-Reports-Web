#!/usr/bin/env perl

use strict;
use warnings;

use Tapper::Reports::Web;

Tapper::Reports::Web->setup_engine('PSGI');

my $or_app = sub {
    Tapper::Reports::Web->run(@_);
};
