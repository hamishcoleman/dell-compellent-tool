package CredentialStore;
use warnings;
use strict;
#
# Simple module to load a file with credentials and allow lookups
#
# The credential file is "key username password" with whitespace seperators
# and ignoring lines starting with hash.  Fields may contain hash chars as
# long as the line does not start with one.
#
# whitespace at the beginning and end of the line will be removed and fields
# cannot contain whitespace (Please dont use whitespace in your usernames and
# passwords!)
#
# If both the username and password field are empty then the most recently
# seen username and password are used.  This will die with an error at the
# start of the file
#

use IO::File;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;

    my $filename = shift;
    return undef if (!defined($filename));

    return $self->_readfile($filename);
}

sub _readfile {
    my ($self,$filename) = @_;

    my $fh = IO::File->new($filename,"r");
    return undef if (!defined($fh));

    my ($prev_username,$prev_password);

    while (<$fh>) {
        chomp;
        s/^\s+//;       # delete whitespace at the start of the line
        s/^#.*//;       # delete any line starting with a comment char
        next if (!$_);  # skip if the line is empty

        my ($key,$username,$password) = split(/\s+/);

        if (!defined($username) && !defined($password)) {
            # use the previous ones
            $username=$prev_username;
            $password=$prev_password;
        }

        if (!defined($username) || !defined($password)) {
            # catch the case where we dont have any previous values
            die("Need username and password");
        }

        $self->{db}{$key}{username}=$username;
        $self->{db}{$key}{password}=$password;
        $prev_username=$username;
        $prev_password=$password;
    }
    return $self;
}

sub lookup_username {
    my ($self,$key) = @_;
    return $self->{db}{$key}{username};
}

sub lookup_password {
    my ($self,$key) = @_;
    return $self->{db}{$key}{password};
}

sub lookup {
    my ($self,$key) = @_;
    return ($self->lookup_username($key),$self->lookup_password($key));
}

1;
