use strict;
use warnings;
use Test::More;
use Tapper::Schema::TestTools;
use Test::Fixture::DBIC::Schema;

BEGIN { use_ok q#Catalyst::Test#, 'Tapper::Reports::Web' }
BEGIN { use_ok 'Tapper::Reports::Web::Controller::Tapper::Reports' }

# -----------------------------------------------------------------------------------------------------------------
construct_fixture( schema  => testrundb_schema, fixture => 't/fixtures/testrundb/report.yml' );
# -----------------------------------------------------------------------------------------------------------------

ok( request('tapper/reports')->is_success, 'Request should succeed' );
ok( request('tapper/reports?report_date=2011-08-05')->is_success, 'Request should succeed' );

done_testing;
