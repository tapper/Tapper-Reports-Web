use strict;
use warnings;
use Test::More tests => 2;

BEGIN { use_ok 'Catalyst::Test', 'Tapper::Reports::Web' }

diag "Hint: set TAPPER_DEBUG=1 to enable verbose Catalyst debug output.";

ok( request('/')->is_success, 'Request should succeed' );
