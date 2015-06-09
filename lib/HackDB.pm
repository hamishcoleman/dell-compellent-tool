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
    my $nr = 0;
    for my $column (@_) {
        $self->{column_name2nr}{$column} = $nr++;
    }
    return $self;
}

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

sub _add_row {
    my ($self,$row) = @_;
    if (!defined($self->{column_name2nr})) {
        $self->set_column_names($row->column_names());
    }

    # TODO - confirm that the columns from this row match our existing ones
    $self->set_rowdata($self->_row_count(),$row->_rowdata());
    return $self;
}

sub row {
    my ($self,$rownr) = @_;
    return HackDB::Row->new($self->_column_name2nr(),$self->_rowdata($rownr));
}

sub _row_count {
    my ($self) = @_;
    if (defined($self->{data})) {
        return scalar(@{$self->{data}});
    } else {
        return 0;
    }
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

sub foreach {
    my ($self,$code) = @_;

    my $rownr=0;
    while ($rownr < $self->_row_count()) {
        $_ = $self->row($rownr++);
        &{$code}();
    }
}

sub query {
    my ($self) = shift;
    my %args = ( @_ );

    my $results = HackDB->new();
    $self->foreach( sub {
        if ($_->match(%args)) {
            $results->_add_row($_);
        }
    });
    return $results;
}

sub extract {
    my ($self) = shift;
    my @fields = @_;

    my $results = HackDB->new();
    $self->foreach( sub {
        $results->_add_row($_->extract(@fields));
    });
    return $results;
}

sub print_columns {
    my ($self) = shift;
    my @columns = $self->row(0)->column_names();
    print(join(',',@columns));
}

sub print {
    my ($self) = shift;
    $self->print_columns();
    print("\n");
    $self->foreach( sub {
        $_->print();
    });
    return $self;
}

1;
