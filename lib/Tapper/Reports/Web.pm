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

sub debug
{
        return 1 if $ENV{TAPPER_DEBUG};
        return 0 if $ENV{HARNESS_ACTIVE};
        return 0 if $ENV{TAPPER_REPORTS_WEB_LIVE};
        return 1;
}

# Configure the application.
__PACKAGE__->config( name => 'Tapper::Reports::Web',
                    'Plugin::Authentication' => {
                                                 'realms' => {
                                                              'default' => {
                                                                            'credential' => {
                                                                                             'class' => 'Authen::Simple',
                                                                                             'authen' => [
                                                                                                          {
                                                                                                           'class' => 'PAM',
                                                                                                           args => {
                                                                                                                    service => 'login'
                                                                                                                   },
                                                                                                          },
                                                                                                         ]
                                                                                            }
                                                                           }
                                                             }
                                                }

                   );

__PACKAGE__->config->{"Plugin::Static::Simple"}->{dirs} = [
                                                           'tapper/static',
                                                          ];
__PACKAGE__->config->{"Plugin::Static::Simple"}->{include_path} = [
                                                                   dist_dir('Tapper-Reports-Web'),
                                                                   __PACKAGE__->config->{root},
                                                                   "./root/",
                                                                  ];

# Start the application
__PACKAGE__->setup(qw/-Debug
                      ConfigLoader
                      Authentication
                      Static::Simple Session
                      Session::State::Cookie
                      Session::Store::File/,
                  );

1;
