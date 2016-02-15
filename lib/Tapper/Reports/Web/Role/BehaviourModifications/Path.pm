package Tapper::Reports::Web::Role::BehaviourModifications::Path;

use Moose::Role;

# I am sick of getting relocated/rebase on our local path!
# Cut away a trailing 'tapper/' from base and prepend it to path.
# All conditionally only when this annoying environment is there.
after 'prepare_path' => sub {
                             my ($c) = @_;

                             my $base        =  $c->req->{base}."";
                             $base           =~ s,tapper/$,, if $base;
                             $c->req->{base} =  bless( do{\(my $o = $base)}, 'URI::http' );
                             $c->req->path('tapper/'.$c->req->path) unless ( $c->req->path =~ m,^tapper/?,);
                            };

1;
