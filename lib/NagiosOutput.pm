package NagiosOutput;
use warnings;
use strict;
#
# quick and simple module for formatting check results for nagios
#

# For the moment, no state is kept in this module and only a single output
# with no perfdata is provided

# http://nagios.sourceforge.net/docs/3_0/pluginapi.html

# output:
# TEXT OUTPUT|optional Perfdata
# Long text 1
# Long text 2|perfdata 2
# perfdata 3

# Exit code
my $state2code = {
    OK       => 0,
    WARNING  => 1,
    CRITICAL => 2,
    UNKNOWN  => 3,

    UP       => 0,
    DOWN     => 2,
};

sub state {
    my $state = shift;
    my $code = $state2code->{$state};
    return undef if (!defined($code));
    print(@_,"\n");
    exit($code);
}

sub OK       { state('OK',@_); }
sub WARNING  { state('WARNING',@_); }
sub CRITICAL { state('CRITICAL',@_); }
sub UNKNOWN  { state('UNKNOWN',@_); }


1;
