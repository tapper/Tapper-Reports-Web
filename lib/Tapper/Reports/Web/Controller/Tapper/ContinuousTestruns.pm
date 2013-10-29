package Tapper::Reports::Web::Controller::Tapper::Continuoustestruns;

# ABSTRACT: Tapper - List and edit continuous tests

use strict;
use warnings;

use parent 'Tapper::Reports::Web::Controller::Base';

use Try::Tiny;
use Tapper::Model 'model';

sub index :Path : Args() {

    my ( $or_self, $or_c ) = @_;

    $or_c->go('/tapper/continuoustestruns/prepare_list');

    return 1;

}

sub prepare_list : Private {

    my ( $or_self, $or_c ) = @_;

    $or_c->stash->{head_overview}       = 'Continuous Testruns';
    $or_c->stash->{continuous_testruns} = $or_c->model('TestrunDB')->fetch_raw_sql({
        query_name  => 'testruns::continuous_list',
        fetch_type  => '@%',
    });

    return 1;

}

sub update_testrun : Private {

    my ( $or_self, $or_schema, $hr_atts ) = @_;

    for my $s_key (qw/ old_state testrun_id /) {
        if (! $hr_atts->{$s_key} ) {
            return "missing attribute: '$s_key'";
        }
    }

    require DateTime;
    my $dt_now = DateTime->now()->strftime('%F %T');

    my $i_success = 0;
    if ( $hr_atts->{testrun_id} =~ /^\d+$/ ) {

        try {
            $or_schema->txn_do(sub {

                my $hr_update = {};
                if ( exists $hr_atts->{new_state} ) {
                    $hr_update->{status} = $hr_atts->{new_state};
                }
                if ( exists $hr_atts->{auto_rerun} ) {
                    $hr_update->{auto_rerun} = $hr_atts->{auto_rerun};
                }

                $or_schema->resultset("TestrunScheduling")
                    ->search({
                        auto_rerun => 1,
                        testrun_id => $hr_atts->{testrun_id},
                        status     => $hr_atts->{old_state},
                    })
                    ->update( $hr_update )
                ;

            });
        }
        catch {
            return "Transaction failed: $_";
        };

        return '';
    }
    else {
        return "Testrun-ID has a wrong format";
    }

    return '';

}

sub pause : Local {

    my ( $or_self, $or_c ) = @_;

    $or_c->stash->{error} = $or_self->update_testrun(
        $or_c->model('TestrunDB'),
        {
            old_state   => 'schedule',
            new_state   => 'prepare',
            testrun_id  => $or_c->req->params->{testrun_id}
        },
    );

    $or_c->go('/tapper/continuoustestruns/prepare_list');

    return 1;

}

sub continue : Local {

    my ( $or_self, $or_c ) = @_;

    $or_c->stash->{error} = $or_self->update_testrun(
        $or_c->model('TestrunDB'),
        {
            old_state   => 'prepare',
            new_state   => 'schedule',
            testrun_id  => $or_c->req->params->{testrun_id}
        },
    );

    $or_c->go('/tapper/continuoustestruns/prepare_list');

    return 1;

}

sub cancel : Local {

    my ( $or_self, $or_c ) = @_;

    $or_c->stash->{error} = $or_self->update_testrun(
        $or_c->model('TestrunDB'),
        {
            auto_rerun  => 0,
            old_state   => [ 'prepare', 'schedule' ],
            testrun_id  => $or_c->req->params->{testrun_id}
        },
    );

    $or_c->go('/tapper/continuoustestruns/prepare_list');

    return 1;

}

sub edit : LocalRegex('edit|clone') {

    my ( $or_self, $or_c ) = @_;

    $or_c->stash->{head_overview} = 'Continuous Testruns - ' . ucfirst( $or_c->stash->{command} );

    if (! $or_c->stash->{continuous_testrun} ) {
        my $or_testrun = $or_c
            ->model('TestrunDB')
            ->resultset('Testrun')
            ->search({
                'testrun_scheduling.auto_rerun' => 1,
                'testrun_scheduling.testrun_id' => $or_c->req->params->{testrun_id},
                'testrun_scheduling.status'     => [qw/ prepare schedule /],
            },{
                'join'                          => [
                    'testrun_scheduling',
                    'testrun_requested_host',
                ],
            })
            ->first()
        ;
        $or_c->stash->{continuous_testrun} = {
            testrun_id  => $or_c->req->params->{testrun_id},
            topic       => $or_testrun->topic_name,
            queue       => $or_testrun->testrun_scheduling->queue_id,
            host        => [map { [ $_->host_id, $_->host->name ] } $or_testrun->testrun_requested_host],
        };
        $or_c->stash->{command}            = ( split /\//, $or_c->req->match )[-1];
    }

    return 1;

}

sub save : Local {

    my ( $or_self, $or_c ) = @_;

    my $or_schema = $or_c->model('TestrunDB');

    try {
        $or_schema->txn_do(sub {

            my $i_testrun_id;
            if ( $or_c->req->params->{command} eq 'edit' ) {

                $i_testrun_id = $or_c->req->params->{testrun_id};

                # check topic name
                if (
                    $or_schema
                        ->resultset('Testrun')
                        ->search({
                            -not        => { id => $i_testrun_id },
                            topic_name  => $or_c->req->params->{topic},
                        })
                        ->count() > 0
                ) {
                    die "topic name already exists\n";
                }

                # update topic
                $or_schema
                    ->resultset('Testrun')
                    ->search({
                        -not    => { topic_name => $or_c->req->params->{topic}, },
                        id      => $i_testrun_id,
                    })
                    ->update({
                        topic_name => $or_c->req->params->{topic},
                    })
                ;

                # update queue
                $or_schema
                    ->resultset('TestrunScheduling')
                    ->search({
                        -not       => { queue_id => $or_c->req->params->{queue_id}, },
                        testrun_id => $i_testrun_id,
                        auto_rerun => 1,
                        status     => ['prepare','schedule'],
                    })
                    ->update({
                        queue_id => $or_c->req->params->{queue}
                    })
                ;

                # delete old testruns
                $or_schema
                    ->resultset('TestrunRequestedHost')
                    ->search({ testrun_id => $i_testrun_id })
                    ->delete_all()
                ;

            }
            elsif ( $or_c->req->params->{command} eq 'clone' ) {

                # check topic name
                if (
                    $or_schema
                        ->resultset('Testrun')
                        ->search({
                            topic_name  => $or_c->req->params->{topic},
                        })
                        ->count() > 0
                ) {
                    die "topic name already exists\n";
                }

                # add a new testrun entry
                my $or_testrun = $or_schema
                    ->resultset('Testrun')
                    ->find( $or_c->req->params->{testrun_id} )
                ;
                my $or_new_testrun = $or_schema
                    ->resultset('Testrun')
                    ->new({
                        shortname           => $or_testrun->shortname,
                        notes               => $or_testrun->notes,
                        topic_name          => $or_c->req->params->{topic},
                        owner_id            => $or_testrun->owner_id,
                        testplan_id         => $or_testrun->testplan_id,
                        wait_after_tests    => $or_testrun->wait_after_tests,
                        rerun_on_error      => $or_testrun->rerun_on_error,
                    })
                    ->insert()
                ;

                # add a new testrun scheduling entry
                my $or_testrun_scheduling = $or_schema
                    ->resultset('TestrunScheduling')
                    ->search({
                        testrun_id => $or_c->req->params->{testrun_id},
                        auto_rerun => 1,
                        status     => ['prepare','schedule'],
                    })
                    ->first()
                ;

                $i_testrun_id = $or_new_testrun->id();

                $or_schema
                    ->resultset('TestrunScheduling')
                    ->new({
                        testrun_id      => $i_testrun_id,
                        queue_id        => $or_c->req->params->{queue},
                        prioqueue_seq   => $or_testrun_scheduling->prioqueue_seq,
                        status          => 'schedule',
                        auto_rerun      => 1,
                    })
                    ->insert()
                ;

            }
            else {
                die "unknown command '$or_c->req->params->{command}'\n";
            }

            # insert testrun requested hosts
            for my $i_host ( @{toarrayref( $or_c->req->params->{host} )} ) {
                $or_schema
                    ->resultset('TestrunRequestedHost')
                    ->new({
                        host_id     => $i_host,
                        testrun_id  => $i_testrun_id,
                    })
                    ->insert()
                ;
            }

        });
    }
    catch {
        $or_c->stash->{error}               = "Transaction failed: $_";
        $or_c->stash->{command}             = $or_c->req->params->{command};
        $or_c->stash->{continuous_testrun}  = {
            testrun_id  => $or_c->req->params->{testrun_id},
            topic       => $or_c->req->params->{topic},
            queue       => $or_c->req->params->{queue},
            host        => [
                map {[
                    $_, $or_schema->resultset('Host')->find( $_ )->name,
                ]} @{toarrayref( $or_c->req->params->{host} )}
            ],
        };
        $or_c->go('/tapper/continuoustestruns/edit');
    };

    $or_c->go('/tapper/continuoustestruns/prepare_list');

    return 1;

}

sub toarrayref : Private {

    my ( $value ) = @_;

    if ( ref( $value ) ne 'ARRAY' ) {
        return [ $value ];
    }

    return $value;

}

1;