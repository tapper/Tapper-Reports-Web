package Tapper::Reports::Web;
# ABSTRACT: Tapper - Frontend web application based on Catalyst

use 5.010;
use strict;
use warnings;

use Moose;
use Catalyst::Runtime;

extends 'Catalyst';
with 'Tapper::Reports::Web::Role::BehaviourModifications::Path';

use Tapper::Config;
use File::ShareDir ':ALL';
use Cwd;

my $root_dir = eval { dist_dir("Tapper-Reports-Web") } || getcwd."/root";

# Configure the application
__PACKAGE__->config( name => 'Tapper::Reports::Web' );
__PACKAGE__->config->{tapper_config} = Tapper::Config->subconfig;

# Configure plugins
__PACKAGE__->config("Plugin::Static::Simple" => { dirs               => [ 'tapper/static' ],
                                                  include_path       => [ $root_dir ]});
if (__PACKAGE__->config->{tapper_config}{web}{use_authentication}) {
        __PACKAGE__->config("Plugin::Authentication" => { realms => { default => { credential => { class  => 'Authen::Simple',
                                                                                                   authen => [{ class => 'PAM',
                                                                                                                args  =>
                                                                                                                {
                                                                                                                 service => 'login'
                                                                                                                }}]}}}});
}
__PACKAGE__->config( 'Controller::HTML::FormFu' => {
                                                    constructor => { config_file_path => [ "$root_dir/forms", 'root/forms/' ] },
                                                   } );

my @plugins = (qw(ConfigLoader
                  Static::Simple Session
                  Session::State::Cookie
                  Session::Store::File));
push @plugins, "Authentication" if __PACKAGE__->config->{use_authentication};

# Start the application
__PACKAGE__->setup(@plugins);

1;
