package Tapper::Reports::Web::View::JSON;

use strict;
use warnings;

use base qw/Catalyst::View/;

sub process {

    my ( $or_self, $or_c ) = @_;

    $or_c->response->content_type('text/plain');

    if ( $or_c->stash->{content} ) {
        $or_c->response->body(
            JSON::XS::encode_json( $or_c->stash->{content} )
        );
    }

    return 1;

}

1;