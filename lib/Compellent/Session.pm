package Compellent::Session;
use warnings;
use strict;
#
# Setup a session with a compellent
#

use LWP::UserAgent;
use IO::Socket::SSL;
use XML::Twig;

use HC::HackDB;
use HC::Cache::Dir;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    #$self->_handle_args(@_);

    my $ua = LWP::UserAgent->new;
    $ua->agent("$class/0.1");

    $self->set_sessionstate('new');
    $self->set_ua($ua);

    my $cache = HC::Cache::Dir->new();
    if (defined($ENV{'HOME'})) {
        $cache->set_cachedir($ENV{'HOME'}.'/.cache/compellent');
    }
    $self->set_cache($cache);

    return $self;
}

######################################################################
#
# boilerplate getters and setters

sub set_baseurl {
    my ($self,$url) = @_;
    # TODO - validate?
    $self->{baseurl} = $url;
    return $self;
}

sub set_username {
    my ($self,$username) = @_;
    $self->{username} = $username;
    return $self;
}

sub set_password {
    my ($self,$password) = @_;
    $self->{password} = $password;
    return $self;
}

sub set_ua {
    my ($self,$ua) = @_;
    $self->{ua} = $ua;
    return $self;
}

sub set_sessionkey {
    my ($self,$sessionkey) = @_;
    $self->{sessionkey} = $sessionkey;
    return $self;
}

sub set_sessionstate {
    my ($self,$sessionstate) = @_;
    $self->{sessionstate} = $sessionstate;
    return $self;
}

sub set_errcode {
    my ($self,$errcode) = @_;
    $self->{errcode} = $errcode;
    return $self;
}

sub set_errmsg {
    my ($self,$errmsg) = @_;
    $self->{errmsg} = $errmsg;
    return $self;
}

sub set_cache {
    my ($self,$cache) = @_;
    $self->{cache} = $cache;
    return $self;
}


sub baseurl      { return shift->{baseurl}; }
sub username     { return shift->{username}; }
sub password     { return shift->{password}; }
sub ua           { return shift->{ua}; }
sub sessionkey   { return shift->{sessionkey}; }
sub sessionstate { return shift->{sessionstate}; }
sub errcode      { return shift->{errcode}; }
sub errmsg       { return shift->{errmsg}; }
sub cache        { return shift->{cache}; }

######################################################################

sub no_check_certificate {
    my ($self) = @_;

    # FIXME
    # - dont do this!
    # However, that requires the active participation of the people
    # installing the SAN to actually use a real cert...

    # The version of LWP on OEL6.3 on our nagios server cannot do this?!
    # - luckily, it is old enough that it defaults to no verification :-(
    return undef if (!$self->ua->can('ssl_opts'));

    $self->ua->ssl_opts(
        SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE,
        verify_hostname => 0,
    );
}

sub open {
    my ($self) = @_;

    if ($self->sessionstate() eq 'open') {
        # no need to open a new one
        # TODO - what about timeouts, etc
        return $self;
    }

    # sanity check the required params
    $self->set_errcode(-1);
    $self->set_errmsg('bad params');
    return undef if(!defined($self->baseurl));
    return undef if(!defined($self->username));
    return undef if(!defined($self->password));

    my $username = $self->username;
    my $password = $self->password;

    my $res = $self->ua->post($self->baseurl."/compellent/post",
        Content_Type => "text/xml",
        Content      => <<EOT,
<xml>
<version>
<messagever>mcXMLv1.0</messagever>
</version>
<sessionhandle>null</sessionhandle>
<syncmode>1</syncmode>
<cmd>
<cmdname>NAME_OPEN</cmdname>
<cmdtype>TYPE_SESSION</cmdtype>
<object>
<username>$username</username>
<userpassword>$password</userpassword>
<sessionhandle>0</sessionhandle>
<requestkey>1</requestkey>
</object>
</cmd>
</xml>
EOT
    );

    if (!$res->is_success) {
        $self->set_errcode(-1);
        $self->set_errmsg($res->status_line);
        return undef;
    }

    my $xml = XML::Twig->new();
    $xml->parse($res->decoded_content);

    my $root=$xml->root();
    my $errcode = $root->get_xpath('status/errcode',0)->text();
    if ($errcode) {
        $self->set_errcode($errcode);
        $self->set_errmsg($root->get_xpath('status/errmsg',0)->text());
        $self->set_sessionstate('error');
        return undef;
    }

    $self->set_sessionkey($root->get_xpath('session/key',0)->text());
    $self->set_sessionstate('open');
    $self->set_errcode(0);

    return $self;
}

sub _query {
    my ($self,$cmdname,$cmdtype) = @_;

    my $content;
    my $cachekey = $self->baseurl.','.$cmdname.','.$cmdtype;
    $cachekey =~ y(:/)(_);

    # first, look for a cached copy of the data
    my $contentref = $self->cache->get($cachekey);

    if (!defined($contentref)) {
        # no valid cached content found, so move on to fetching some data

        # ensure we have a valid session
        return undef if (!defined($self->open()));

        my $sessionkey = $self->sessionkey;

        my $res = $self->ua->post($self->baseurl."/compellent/post",
            Content_Type => "text/xml",
            Content      => <<EOT,
<xml>
<version>
<messagever>mcXMLv1.0</messagever>
</version>
<sessionKey>$sessionkey</sessionKey>
<dontresettimer>1</dontresettimer>
<syncmode>1</syncmode>
<cmd>
<cmdname>$cmdname</cmdname>
<cmdtype>$cmdtype</cmdtype>
<object>
</object>
</cmd>
</xml>
EOT
        );

        if (!$res->is_success) {
            $self->set_errcode(-1);
            $self->set_errmsg($res->status_line);
            return undef;
        }

        $content = $res->decoded_content;

        # save this result in the cache
        $self->cache->put($cachekey,\$content);
    } else {
        $content = ${$contentref};
    }

    my $xml = XML::Twig->new();
    $xml->parse($content);

    my $root=$xml->root();
    my $errcode_n = $root->get_xpath('status/errcode',0);
    if ($errcode_n) {
        $self->set_errcode($errcode_n->text());
        $self->set_errmsg($root->get_xpath('status/errmsg',0)->text());
        return undef;
    }

    $self->set_errcode(0);
    return $xml;
}

sub xml2csvtext {
    my ($xml) = @_;

    return undef if (!defined($xml));
    my @csvtext;

    my $root=$xml->root();

    my $attrlistnode = $root->get_xpath('CSVNode/Header/AttrList',0);
    if ($attrlistnode) {
        push @csvtext,$attrlistnode->text();
    } else {
        push @csvtext,"# missing AttrList\n";
    }

    push @csvtext,"\n";
    push @csvtext,"# TableName= ". $root->get_xpath('CSVNode/Header/TableName',0)->text(). "\n";
    push @csvtext,"# Subsystem= ". $root->get_xpath('CSVNode/Header/Subsystem',0)->text(). "\n";
    push @csvtext,"# TableId= ". $root->get_xpath('CSVNode/Header/TableId',0)->text(). "\n";
    push @csvtext,"# SubsystemId= ". $root->get_xpath('CSVNode/Header/SubsystemId',0)->text(). "\n";
    push @csvtext,"\n";

    my $datanode = $root->get_xpath('CSVNode/Data',0);
    if ($datanode) {
        push @csvtext,$datanode->text();
    } else {
        push @csvtext,"# missing Data\n";
    }
    return join('',@csvtext);
}

sub xml2hackdb {
    my ($xml) = @_;

    return undef if (!defined($xml));

    my $root=$xml->root();

    my $attrlistnode = $root->get_xpath('CSVNode/Header/AttrList',0);
    if (!$attrlistnode) {
        # no attrs, no results
        return undef;
    }

    my $columns = $attrlistnode->text();
    chomp($columns);
    my @column_names = split(/,/,$columns);

    my $datanode = $root->get_xpath('CSVNode/Data',0);
    if (!$datanode) {
        # no data, no results
        return undef;
    }

    my $data = $datanode->text();
    CORE::open(my $fh,"<",\$data);

    my $hackdb = HC::HackDB->new();
    $hackdb->set_column_names(@column_names);
    $hackdb->load_csv($fh);

    return $hackdb;
}

# Use GETBULKCSV, but cache the results in the session
sub table {
    my ($self,$tablename) = @_;

    my $xml = $self->_query('NAME_GETBULKCSV',$tablename);
    return undef if (!defined($xml));

    my $table = xml2hackdb($xml);
    if (!defined($table)) {
        $self->set_errcode(-1);
        $self->set_errmsg('xml table error');
    }

    return $table;
}

1;
