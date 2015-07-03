package HackCache;
use warnings;
use strict;
#
# Keep a dir with cached data
#

use Storable;
use File::Path qw(make_path);

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;

    $self->set_maxage(2*60); # TODO - is this a good default?

    #$self->_handle_args(@_);

    return $self;
}

sub _cachedir { return shift->{cachedir}; }
sub _maxage { return shift->{maxage}; }

sub set_cachedir {
    my $self = shift;

    my $cachedir = shift;
    $self->{cachedir} = $cachedir;

    return $self;
}

# Sets how many seconds cached data is considered valid
sub set_maxage {
    my $self = shift;
    $self->{maxage} = shift;
    return $self;
}

# Returns false if the key is an ilegal combination of chars
sub _check_key_sanity {
    my $self = shift;
    my $key = shift;

    return undef if ($key =~ m%/%); # no path separators (FIXME - hardcoded sep)
    return $self;
}

# Returns false if that cachedir cannot be used
#
sub _check_cachedir {
    my $self = shift;
    my $cachedir = $self->_cachedir();
    return undef if (!defined($cachedir));

    if (! -e $cachedir) {
        # Doesnt exist, try to make it, or just fail
        return undef if (! make_path($cachedir));
    }

    return undef if (! -d $cachedir); # if it exists, it must be a dir

    # TODO - a writablility test?

    return $self;
}

# Get data from the cache, if it is available and still valid
#
sub get {
    my $self = shift;
    my $key = shift;

    return undef if (!$self->_check_key_sanity($key));
    return undef if (!$self->_check_cachedir());

    my $filename = $self->_cachedir . '/' . $key;

    return undef if (! -r $filename); # if we cannot read it, no luck

    my ($mtime) = (stat($filename))[9];
    return undef if (!defined($mtime));

    my $age = time() - $mtime;
    return undef if ($age > $self->_maxage()); # is it still valid?

    return retrieve($filename);
}

# put data into the cache (overwriting old data if needed)
sub put {
    my $self = shift;
    my $key = shift;
    my $value = shift;

    if (!ref($value)) {
        die("cache value must be a reference");
    }

    return undef if (!$self->_check_key_sanity($key));
    return undef if (!$self->_check_cachedir());

    my $filename = $self->_cachedir . '/' . $key;

    return undef if (!defined(store($value,$filename)));

    return $self;
}

1;

