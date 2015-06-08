package HackDB;
use warnings;
use strict;
#
# A quick simple in-memory database.  I looked at using DBD::Anydata or
# DBD::CSV, but they looked like really big hammers
#

use Text::CSV;

use HackDB::Row;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    #$self->_handle_args(@_);

    return $self;
}

sub set_column_names {
    my ($self) = shift;
    @{$self->{column_names}} = @_;
    my $nr = 0;
    for my $column (@_) {
        $self->{column_name2nr}{$column} = $nr++;
    }
    return $self;
}

sub column_names { return @{shift->{column_names}}; }

sub set_rowdata {
    my ($self,$rownr,$data) = @_;
    @{$self->{data}}[$rownr] = $data;
    return $self;
}

sub _rowdata {
    my ($self,$rownr) = @_;
    return $self->{data}[$rownr];
}

sub _column_name2nr {
    my ($self) = @_;
    return $self->{column_name2nr};
}

sub row {
    my ($self,$rownr) = @_;
    return HackDB::Row->new($self->_column_name2nr(),$self->_rowdata($rownr));
}

sub _row_count {
    my ($self) = @_;
    return scalar(@{$self->{data}});
}

sub load_csv {
    my ($self,$fh,$csv) = @_;

    if (!defined($csv)) {
        $csv = Text::CSV->new or return undef;
    }

    # nuke any existing data
    $self->{data} = [];

    while ($_ = $csv->getline($fh)) {
        $self->set_rowdata($self->_row_count(),$_);
    }

    return $self;
}

sub query {
    my ($self) = shift;
    my %args = ( @_ );

    my @results;
    my $rownr=0;
    while ($rownr < $self->_row_count()) {
        my $row = $self->row($rownr++);
        if ($row->match(%args)) {
            push @results,$row;
        }
    }
    return @results;
}


1;
