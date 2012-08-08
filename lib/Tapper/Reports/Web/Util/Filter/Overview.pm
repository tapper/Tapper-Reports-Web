package Tapper::Reports::Web::Util::Filter::Overview;


=head1 NAME

Tapper::Reports::Web::Util::Filter::Overview - Filter utilities for overview listing

=head1 SYNOPSIS

 use Tapper::Overviews::Web::Util::Filter::Overview;
 my $filter              = Tapper::Overviews::Web::Util::Filter::Overview->new();
 my $filter_args         = ['host','bullock','days','3'];
 my $allowed_filter_keys = ['host','days'];
 my $searchoptions       = $filter->parse_filters($filter_args, $allowed_filter_keys);

=cut



use Moose;
use Hash::Merge::Simple 'merge';
use Set::Intersection 'get_intersection';

use Tapper::Model 'model';

extends 'Tapper::Reports::Web::Util::Filter';

sub BUILD{
        my $self = shift;
        my $args = shift;

        $self->dispatch(
                        merge($self->dispatch,
                              {like    => \&like,
                               weeks  => \&weeks,
                              })
                       );
}


=head2 weeks

Add weeks filters to early filters. This checks whether the overview
element was used in the last given weeks.

@param hash ref - current version of filters
@param int      - number of weeks

@return hash ref - updated filters


=cut

sub weeks
{
        my ($self, $filter_condition, $duration) = @_;

        my $timeframe = DateTime->now->subtract(weeks => $duration);
        my $dtf = model("ReportsDB")->storage->datetime_parser;
        push @{$filter_condition->{late}}, {'reports.created_at' => {'>=' => $dtf->format_datetime($timeframe) }};
        return $filter_condition;
}


=head2 like

Add like filters to early filters. Note that the expected regular
expression is not a real regexp. Instead * as wildcard is accepted.

@param hash ref - current version of filters
@param string   - like regexp

@return hash ref - updated filters

=cut

sub like
{
        my ($self, $filter_condition, $regexp) = @_;

        $regexp =~ tr/*/%/;
        $filter_condition->{early}->{name} = { 'like', $regexp} ;

        return $filter_condition;
}

1;
