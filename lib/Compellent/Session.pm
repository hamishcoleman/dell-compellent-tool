package Compellent::Session;
use warnings;
use strict;
#
# Setup a session with a compellent
#

use WWW::Mechanize;
use IO::Socket::SSL;
use XML::Twig;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    #$self->_handle_args(@_);

    $self->set_mech(WWW::Mechanize->new());
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

sub set_mech {
    my ($self,$mech) = @_;
    $self->{mech} = $mech;
    return $self;
}

sub set_sessionkey {
    my ($self,$sessionkey) = @_;
    $self->{sessionkey} = $sessionkey;
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

sub baseurl    { return shift->{baseurl}; }
sub username   { return shift->{username}; }
sub password   { return shift->{password}; }
sub mech       { return shift->{mech}; }
sub sessionkey { return shift->{sessionkey}; }
sub errcode    { return shift->{errcode}; }
sub errmsg     { return shift->{errmsg}; }

######################################################################

sub no_check_certificate {
    my ($self) = @_;

    # FIXME
    # - dont do this!
    # However, that requires the active participation of the people
    # installing the SAN to actually use a real cert...

    $self->mech->ssl_opts(
        SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE,
        verify_hostname => 0,
    );
}

sub open {
    my ($self) = @_;

    # sanity check the required params
    return undef if(!defined($self->baseurl));
    return undef if(!defined($self->username));
    return undef if(!defined($self->password));

    my $username = $self->username;
    my $password = $self->password;

    $self->mech->post($self->baseurl."/compellent/post",
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

    my $xml = XML::Twig->new();
    $xml->parse($self->mech->content);

    my $root=$xml->root();
    my $errcode = $root->get_xpath('status/errcode',0)->text();
    if ($errcode) {
        $self->set_errcode($errcode);
        $self->set_errmsg($root->get_xpath('status/errmsg',0)->text());
        return undef;
    }

    $self->set_sessionkey($root->get_xpath('session/key',0)->text());

    return $self;
}

sub _query {
    my ($self,$cmdname,$cmdtype) = @_;

    my $sessionkey = $self->sessionkey;

    $self->mech->post($self->baseurl."/compellent/post",
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

    my $xml = XML::Twig->new();
    $xml->parse($self->mech->content);

    my $root=$xml->root();
    my $errcode_n = $root->get_xpath('status/errcode',0);
    if ($errcode_n) {
        $self->set_errcode($errcode_n->text());
        $self->set_errmsg($root->get_xpath('status/errmsg',0)->text());
        return undef;
    }

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

#sub NAME_GETBULKCSV {
#    my ($self,$cmdtype) = @_;
#
#    my $xml = $self->_query('NAME_GETBULKCSV',$cmdtype);
#    return xml2csvtext($xml);
#}

1;
