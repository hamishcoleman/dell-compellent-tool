package HackDB::Row;
use warnings;
use strict;
#
# Represent a single row in a table
#

sub new {
    my $class = shift;
    my $name2nr = shift;
    my $rowdata = shift;

    return undef if (!defined($name2nr)); # need a column name mapping
    return undef if (!defined($rowdata)); # need a row

    my $self = {};
    bless $self, $class;

    $self->_set_column_name2nr($name2nr);
    $self->_set_rowdata($rowdata);
    return $self;
}

sub _set_column_name2nr {
    my ($self) = shift;
    $self->{column_name2nr} = shift;
    return $self;
}

sub _set_rowdata {
    my ($self) = shift;
    $self->{rowdata} = shift;
    return $self;
}

sub _rowdata { return shift->{rowdata}; }

sub _column_name2nr {
    my ($self,$column) = @_;
    return $self->{column_name2nr}{$column};
}

sub field {
    my ($self) = shift;
    my @result;
    for my $column (@_) {
        push @result, @{$self->_rowdata()}[$self->_column_name2nr($column)]
    }
    return @result;
}

sub match {
    my ($self) = shift;
    my %args = ( @_ );

    while (my ($fieldname,$tomatch) = each %args) {
        my $field = ($self->field($fieldname))[0];
        # TODO, support more than simply exact "eq"
        if ($tomatch ne $field) {
            return undef;
        }
    }
    return $self;
}

sub column_names {
    my ($self) = @_;
    my @columns;

    while (my ($field, $nr) = each %{$self->{column_name2nr}}) {
        $columns[$nr] = $field;
        # TODO - perhaps confirm that there are no overwrites?
    }

    return @columns;
}

1;
