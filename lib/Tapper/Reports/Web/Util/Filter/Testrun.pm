package Tapper::Reports::Web::Util::Filter::Testrun;


=head1 NAME

Tapper::Reports::Web::Util::Filter::Testrun - Filter utilities for testrun listing

=head1 SYNOPSIS

 use Tapper::Testruns::Web::Util::Filter::Testrun;
 my $filter              = Tapper::Testruns::Web::Util::Filter::Testrun->new();
 my $filter_args         = ['host','bullock','days','3'];
 my $allowed_filter_keys = ['host','days'];
 my $searchoptions       = $filter->parse_filters($filter_args, $allowed_filter_keys);

=cut



use Moose;
use Hash::Merge::Simple 'merge';
use Set::Intersection 'get_intersection';

use Tapper::Model 'model';

extends 'Tapper::Reports::Web::Util::Filter';

sub BUILD {

        my $self = shift;
        my $args = shift;

        $self->dispatch(
                merge(
                        $self->dispatch,
                        {
                                host    => \&host,
                                state   => sub { hr_set_filter_default( @_, 'state' ); },
                                success => sub { hr_set_filter_default( @_, 'success' ); },
                                topic   => sub { hr_set_filter_default( @_, 'topic' ); },
                                owner   => \&owner,
                        }
                )
        );
}


=head2 host

Add host filters to early filters.

@param hash ref - current version of filters
@param string   - host name

@return hash ref - updated filters

=cut

sub host
{
        my ($self, $filter_condition, $host) = @_;
        my $host_result = model('TestrunDB')->resultset('Host')->search({name => $host}, {rows => 1})->first;

        # (XXX) do we need to throw an error when someone filters for an unknown host?
        if (not $host_result) {
                return $filter_condition;
        }

        push @{$filter_condition->{host} ||= []}, $host_result->id;

        return $filter_condition;
}


=head2 owner

Add owner filters to early filters.

@param hash ref - current version of filters
@param string   - owner login

@return hash ref - updated filters

=cut

sub owner
{
        my ($self, $filter_condition, $owner) = @_;

        my $owner_result = model('TestrunDB')->resultset('Owner')->search({login => $owner}, {rows => 1})->first;

        if (not $owner_result) {
                $filter_condition->{error} = "No owner with login '$owner' found";
                return $filter_condition;
        }

        push @{$filter_condition->{owner} ||= []}, $owner_result->id;

        return $filter_condition;
}

sub hr_set_filter_default {
    my ( $or_self, $hr_filter, $value, $s_filter_name ) = @_;
    push @{$hr_filter->{$s_filter_name} ||= []}, $value;
    return $hr_filter;
}

1;