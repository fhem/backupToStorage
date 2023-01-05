###############################################################################
#
# Developed with VSCodium and richterger perl plugin
#
#  (c) 2020-2023 Copyright: Marko Oldenburg (fhemdevelopment at cooltux dot net)
#  All rights reserved
#
#   Special thanks goes to:
#       -
#
#
#  This script is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License,or
#  any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#
# $Id$
#
###############################################################################

package FHEM::Services::backupToStorage;

use strict;
use warnings;
use utf8;

use GPUtils qw(GP_Import);

BEGIN {

    # Import from main context
    GP_Import(
        qw( init_done
          defs
        )
    );
}

# try to use JSON::MaybeXS wrapper
#   for chance of better performance + open code
eval {
    require JSON::MaybeXS;
    import JSON::MaybeXS qw( decode_json encode_json );
    1;
} or do {

    # try to use JSON wrapper
    #   for chance of better performance
    eval {
        # JSON preference order
        local $ENV{PERL_JSON_BACKEND} =
          'Cpanel::JSON::XS,JSON::XS,JSON::PP,JSON::backportPP'
          unless ( defined( $ENV{PERL_JSON_BACKEND} ) );

        require JSON;
        import JSON qw( decode_json encode_json );
        1;
    } or do {

        # In rare cases, Cpanel::JSON::XS may
        #   be installed but JSON|JSON::MaybeXS not ...
        eval {
            require Cpanel::JSON::XS;
            import Cpanel::JSON::XS qw(decode_json encode_json);
            1;
        } or do {

            # In rare cases, JSON::XS may
            #   be installed but JSON not ...
            eval {
                require JSON::XS;
                import JSON::XS qw(decode_json encode_json);
                1;
            } or do {

                # Fallback to built-in JSON which SHOULD
                #   be available since 5.014 ...
                eval {
                    require JSON::PP;
                    import JSON::PP qw(decode_json encode_json);
                    1;
                } or do {

                    # Fallback to JSON::backportPP in really rare cases
                    require JSON::backportPP;
                    import JSON::backportPP qw(decode_json encode_json);
                    1;
                };
            };
        };
    };
};

sub Define {
    use version 0.60;

    my $hash = shift // return;
    my $aArg = shift // return;

    return $@ unless ( FHEM::Meta::SetInternals($hash) );

    $version = FHEM::Meta::Get( $hash, 'version' );
    our $VERSION = $version;

    return q{only one backupToStorage instance allowed}
      if ( ::devspec2array('TYPE=backupToStorage') > 1 )
      ; # es wird geprüft ob bereits eine Instanz unseres Modules existiert,wenn ja wird abgebrochen
    return q{too few parameters: define <name> backupToStorage}
      if ( scalar( @{$aArg} ) != 2 );

    my $name = shift @$aArg;
    $hash->{VERSION}     = version->parse($VERSION)->normal;
    $hash->{NOTIFYDEV}   = 'global,' . $name;
    $hash->{STORAGETYPE} = ::AttrVal( $name, 'bTS_Type', 'Nextcloud' );

    ::Log3( $name, 3, qq{backupToStorage ($name) - defined} );

    return;
}

sub Undef {
    my $hash = shift;
    my $name = shift;

    ::Log3( $name, 3, q{qbackupToStorage ($name) - delete device $name} );

    return;
}

sub Delete {
    my $hash = shift;
    my $name = shift;

    HttpUtils_Close( $hash->{helper}->{HttpUtilsParam} )
      if ( defined( $hash->{helper}->{HttpUtilsParam} ) );
    DeletePassword($hash);

    return;
}

sub Shutdown {
    my $hash = shift;

    HttpUtils_Close( $hash->{helper}->{HttpUtilsParam} )
      if ( defined( $hash->{helper}->{HttpUtilsParam} ) );

    return;
}

sub Notify {
    my $hash = shift // return;
    my $dev  = shift // return;

    my $name    = $hash->{NAME};
    my $devname = $dev->{NAME};
    my $devtype = $dev->{TYPE};
    my $events  = ::deviceEvents( $dev, 1 );

    _CheckIsDisabledAfterSetAttr($hash)
      if (
        (
            (
                grep { /^DELETEATTR.$name.(disable|disabledForIntervals)$/x }
                @{$events}
                or grep { /^ATTR.$name.(disable|disabledForIntervals).\S+$/x }
                @{$events}
            )
            && $devname eq 'global'
            && $init_done
        )
        || $devname eq $name
      );

    return if ( !$events
        || ::IsDisabled($name) );

    ::Log3( $name, 4,
        qq{backupToStorage ($name) - Devname: $devname  Name: $name Notify: } );

    PushToStorage($hash)
      if ( ( grep { /^backup.done(.+)?$/x } @{$events} )
        && $devname eq 'global'
        && $init_done );

    CheckAttributsForCredentials($hash)
      if (
        (
            (
                (
                    grep { /^DELETEATTR.$name.(bTS_Host|bTS_User)$/x }
                    @{$events}
                    or grep { /^ATTR.$name.(bTS_Host|bTS_User).\S+$/x }
                    @{$events}
                )
                && $devname eq 'global'
            )
            || (
                (
                    $devname eq $name && grep { /^password.(add|remove)$/x }
                    @{$events}
                )
            )
        )
        && $init_done
      );

    readingsSingleUpdate(
        $hash, 'state',
        (
            (
                     ::AttrVal( $name, 'bTS_Host', 'none' ) eq 'none'
                  || ::AttrVal( $name, 'bTS_User', 'none' ) eq 'none'
                  || !defined( ReadPassword( $hash, $name ) )
            )
            ? 'please set storage account credentials first'
            : 'ready'
        ),
        1
      )
      if (
        (
               ( grep { /^DEFINED.$name$/x } @{$events} )
            && $devname eq 'global'
            && $init_done
        )
        || (   grep { /^INITIALIZED$/x } @{$events}
            or grep { /^REREADCFG$/x } @{$events}
            or grep { /^MODIFIED.$name$/x } @{$events} )
        && $devname eq 'global'
      );

    return;
}

sub Set {
    my $hash = shift // return;
    my $aArg = shift // return;

    my $name = shift @$aArg;
    my $cmd  = shift @$aArg
      // return qq{set "$name" needs at least one argument};

    if ( lc $cmd eq 'addpassword' ) {
        return q{please set Attribut bTS_User first}
          if ( ::AttrVal( $name, 'bTS_User', 'none' ) eq 'none' );
        return qq{usage: "$cmd" <password>}
          if ( scalar( @{$aArg} ) != 1 );

        StorePassword( $hash, $name, $aArg->[0] );
    }
    elsif ( lc $cmd eq 'deletepassword' ) {
        return qq{usage: $cmd}
          if ( scalar( @{$aArg} ) != 0 );

        DeletePassword($hash);
    }
    elsif ( lc $cmd eq 'active' ) {
        return qq{usage: $cmd}
          if ( scalar( @{$aArg} ) != 0 );

        readingsSingleUpdate( $hash, 'state', 'ready', 1 );
    }
    elsif ( lc $cmd eq 'inactive' ) {
        return qq{usage: $cmd}
          if ( scalar( @{$aArg} ) != 0 );

        readingsSingleUpdate( $hash, 'state', $cmd, 1 );
    }
    else {
        my $list = 'active:noArg inactive:noArg';
        $list .= (
            defined( ReadPassword( $hash, $name ) )
            ? ' deletepassword:noArg'
            : ' addpassword'
        );

        return qq{Unknown argument "$cmd", choose one of $list};
    }

    return;
}

sub Attr {
    my $cmd  = shift;
    my $name = shift;

    my $hash     = $defs{$name};
    my $attrName = shift;
    my $attrVal  = shift;

    if (   $attrName eq 'disable'
        || $attrName eq 'disabledForIntervals' )
    {

        if ( $cmd eq 'set' ) {
            if ( $attrName eq 'disabledForIntervals' ) {
                return
'check disabledForIntervals Syntax HH:MM-HH:MM or HH:MM-HH:MM HH:MM-HH:MM ...'
                  if ( $attrVal !~ /^((\d{2}:\d{2})-(\d{2}:\d{2})\s?)+$/x );
                ::Log3( $name, 3,
                    qq{backupToStorage ($name) - disabledForIntervals} );
            }
            elsif ( $attrName eq 'disable' ) {
                ::Log3( $name, 3, qq{backupToStorage ($name) - disabled} );
            }
        }

        ::InternalTimer(
            ::gettimeofday() + 1,
            'FHEM::Services::backupToStorage::_CheckIsDisabledAfterSetAttr',
            $hash, 0
        );
    }
    elsif ( $attrName eq 'bTS_Type' ) {
        ::InternalTimer(
            ::gettimeofday() + 1,
            sub {
                $hash->{STORAGETYPE} =
                  ::AttrVal( $name, 'bTS_Type', 'Nextcloud' );
            },
            $hash,
            0
        );
    }

    return;
}

sub _CheckIsDisabledAfterSetAttr {
    my $hash = shift;

    my $name  = $hash->{NAME};
    my $state = (
        ::IsDisabled($name)
        ? 'inactive'
        : 'ready'
    );

    ::Log3( $name, 3,
        qq{backupToStorage ($name) - _CheckIsDisabledAfterSetAttr} );

    readingsSingleUpdate( $hash, 'state', $state, 1 )
      if ( ::ReadingsVal( $name, 'state', 'ready' ) ne $state );

    return;
}

sub Rename {
    my $new = shift;
    my $old = shift;

    my $hash = $defs{$new};

    StorePassword( $hash, $new, ReadPassword( $hash, $old ) );
    ::setKeyValue( $hash->{TYPE} . "_" . $old . "_passwd", undef );

    return;
}

sub PushToStorage {
    my $hash = shift;

    my $name = $hash->{NAME};

    ::Log3( $name, 4, qq{backupToStorage ($name) - push to storage function} );

    return ::Log3( $name, 4,
        qq{backupToStorage ($name) - fhemBackupFile Reading to old} )
      if ( ::ReadingsAge( $name, 'fhemBackupFile', 1 ) > 3600 );

    ::Log3( $name, 4, qq{backupToStorage ($name) - after readings age return} );

    if ( $hash->{STORAGETYPE} eq 'SynologyFileStation' ) {

    }
    else {
        require SubProcess;
        my $subprocess = SubProcess->new( { onRun => \&FileUpload } );

        my $backupFile = ::ReadingsVal( $name, 'fhemBackupFile', 'none' );

        my @fileNameAtStorage_array = split( '/', $backupFile );
        my $fileNameAtStorage =
          $fileNameAtStorage_array[$#fileNameAtStorage_array];

        $subprocess->{curl} = qx(which curl);
        chomp( $subprocess->{curl} );
        $subprocess->{fhemhost} = qx(hostname -f);
        chomp( $subprocess->{fhemhost} );
        $subprocess->{type}              = $hash->{STORAGETYPE};
        $subprocess->{host}              = ::AttrVal( $name, 'bTS_Host', '' );
        $subprocess->{user}              = ::AttrVal( $name, 'bTS_User', '' );
        $subprocess->{pass}              = ReadPassword( $hash, $name );
        $subprocess->{path}              = ::AttrVal( $name, 'bTS_Path', '' );
        $subprocess->{backupfile}        = $backupFile;
        $subprocess->{fileNameAtStorage} = $fileNameAtStorage;
        $subprocess->{proto}    = ::AttrVal( $name, 'bTS_Proto', 'https' );
        $subprocess->{loglevel} = ::AttrVal( $name, 'verbose',   3 );

        my $pid = $subprocess->run();

        readingsSingleUpdate( $hash, 'state', ' file upload in progress', 1 );

        if ( !defined($pid) ) {
            ::Log3( $name, 1,
qq{backupToStorage ($name) - Cannot execute command asynchronously}
            );

            CleanSubprocess($hash);
            readingsSingleUpdate( $hash, 'state',
                'Cannot execute command asynchronously', 1 );
            return;
        }

        ::Log3( $name, 4,
qq{backupToStorage ($name) - execute command asynchronously (PID="$pid")}
        );

        $hash->{".fhem"}{subprocess} = $subprocess;

        ::InternalTimer( ::gettimeofday() + 1,
            "FHEM::Services::backupToStorage::PollChild", $hash );
    }

    ::Log3( $hash, 4,
        qq{backupToStorage ($name) - control passed back to main loop.} );

    return;
}

sub KeepLastN {
    my $hash = shift;

    my $name = $hash->{NAME};

    ::Log3( $name, 4,
        qq{backupToStorage ($name) - Keep Last N at Storage function} );

    if ( $hash->{STORAGETYPE} eq 'SynologyFileStation' ) {

    }
    else {
        require SubProcess;
        my $subprocess = SubProcess->new( { onRun => \&CleanUp } );

        my $backupFile = ::ReadingsVal( $name, 'fhemBackupFile', 'none' );

        my @fileNameAtStorage_array = split( '/', $backupFile );
        my $fileNameAtStorage =
          $fileNameAtStorage_array[$#fileNameAtStorage_array];

        $subprocess->{curl} = qx(which curl);
        chomp( $subprocess->{curl} );
        $subprocess->{type}              = $hash->{STORAGETYPE};
        $subprocess->{host}              = ::AttrVal( $name, 'bTS_Host', '' );
        $subprocess->{user}              = ::AttrVal( $name, 'bTS_User', '' );
        $subprocess->{pass}              = ReadPassword( $hash, $name );
        $subprocess->{path}              = ::AttrVal( $name, 'bTS_Path', '' );
        $subprocess->{fileNameAtStorage} = $fileNameAtStorage;
        $subprocess->{proto}     = ::AttrVal( $name, 'bTS_Proto', 'https' );
        $subprocess->{loglevel}  = ::AttrVal( $name, 'verbose',   3 );
        $subprocess->{keeplastn} = ::AttrVal( $name, 'bTS_KeepLastBackups', 5 );

        my $pid = $subprocess->run();

        readingsSingleUpdate( $hash, 'state',
            ' clean up pass last N in progress', 1 );

        if ( !defined($pid) ) {
            ::Log3( $name, 1,
qq{backupToStorage ($name) - Cannot execute command asynchronously}
            );

            CleanSubprocess($hash);
            readingsSingleUpdate( $hash, 'state',
                'Cannot execute command asynchronously', 1 );
            return;
        }

        ::Log3( $name, 4,
qq{backupToStorage ($name) - execute command asynchronously (PID="$pid")}
        );

        $hash->{".fhem"}{subprocess} = $subprocess;

        ::InternalTimer( ::gettimeofday() + 1,
            "FHEM::Services::backupToStorage::PollChild", $hash );
    }

    ::Log3( $hash, 4,
        qq{backupToStorage ($name) - control passed back to main loop.} );

    return;
}

sub PollChild {
    my $hash = shift;

    my $name = $hash->{NAME};

    if ( defined( $hash->{".fhem"}{subprocess} ) ) {
        my $subprocess = $hash->{".fhem"}{subprocess};
        my $json       = $subprocess->readFromChild();

        if ( !defined($json) ) {
            ::Log3( $name, 5,
qq{backupToStorage ($name) - still waiting ($subprocess->{lasterror}).}
            );

            ::InternalTimer( ::gettimeofday() + 1,
                "FHEM::Services::backupToStorage::PollChild", $hash );
            return;
        }
        else {
            ::Log3( $name, 4,
qq{backupToStorage ($name) - got result from asynchronous parsing: $json}
            );

            $subprocess->wait();
            ::Log3( $name, 4,
                qq{backupToStorage ($name) - asynchronous finished.} );

            CleanSubprocess($hash);
            WriteReadings( $hash, $json );
        }
    }

    return;
}

######################################
# Begin Childprozess
######################################
sub FileUpload {
    my $subprocess = shift;
    my $response   = {};

    if ( $subprocess->{type} eq 'Nextcloud' ) {
        my ( $returnString, $returnCode ) = ExecuteNCupload($subprocess);

        print 'backupToStorage File Upload - FileUpload Nextcloud, returnCode: '
          . $returnCode
          . ' , returnString: '
          . $returnString . "\n"
          if ( $subprocess->{loglevel} > 4 );

        if (    $returnString =~ /100\s\s?[0-9].*\s100\s\s?[0-9].*/xm
            and $returnString =~ /\s\s<o:hint xmlns:o="o:">(.*)<\/o:hint>/xm )
        {
            $response->{ncUpload} = $1;
        }
        elsif ( $returnString =~ /100\s\s?[0-9].*\s100\s\s?[0-9].*/xm ) {
            $response->{ncUpload} = 'upload successfully';
        }
        elsif ( $returnString =~ /(curl:\s.*)/x ) {
            $response->{ncUpload} = $1;
        }
        else {
            $response->{ncUpload} = 'unknown error';
        }
    }

    my $json = eval { encode_json($response) };
    if ($@) {
        print 'backupToStorage File Upload backupToStorage - JSON error: $@'
          . "\n";
        $json = '{"jsonerror":"$@"}';
    }

    $subprocess->writeToParent($json);

    return;
}

sub ExecuteNCupload {
    my $subprocess = shift;

    my $command = $subprocess->{curl};
    $command .= ' -k -X PUT -u ';
    $command .= $subprocess->{user} . ':' . $subprocess->{pass};
    $command .= ' -T ' . $subprocess->{backupfile};
    $command .= ' "' . $subprocess->{proto} . '://';
    $command .= $subprocess->{host};
    $command .= '/remote.php/dav/files/';
    $command .= $subprocess->{user};
    $command .= $subprocess->{path};
    $command .= '/';
    $command .=
      $subprocess->{fhemhost} . '-' . $subprocess->{fileNameAtStorage};
    $command .= '"';

    return ExecuteCommand($command);
}

sub CleanUp {
    my $subprocess = shift;
    my $response   = {};

    if ( $subprocess->{type} eq 'Nextcloud' ) {
        my ( $returnString, $returnCode ) = ExecuteCleanUp($subprocess);

        print 'backupToStorage File Upload - FileUpload Nextcloud, returnCode: '
          . $returnCode
          . ' , returnString: '
          . $returnString . "\n"
          if ( $subprocess->{loglevel} > 4 );

        if (    $returnString =~ /100\s\s?[0-9].*\s100\s\s?[0-9].*/xm
            and $returnString =~ /\s\s<o:hint xmlns:o="o:">(.*)<\/o:hint>/xm )
        {
            $response->{ncUpload} = $1;
        }
        elsif ( $returnString =~ /100\s\s?[0-9].*\s100\s\s?[0-9].*/xm ) {
            $response->{ncUpload} = 'upload successfully';
        }
        elsif ( $returnString =~ /(curl:\s.*)/x ) {
            $response->{ncUpload} = $1;
        }
        else {
            $response->{ncUpload} = 'unknown error';
        }
    }

    my $json = eval { encode_json($response) };
    if ($@) {
        print 'backupToStorage File Upload backupToStorage - JSON error: $@'
          . "\n";
        $json = '{"jsonerror":"$@"}';
    }

    $subprocess->writeToParent($json);

    return;
}

sub ExecuteNCfetchFileList {
    my $subprocess = shift;

    my $command = $subprocess->{curl};
    $command .= ' -k -X PROPFIND -u ';
    $command .= $subprocess->{user} . ':' . $subprocess->{pass};
    $command .= ' "' . $subprocess->{proto} . '://';
    $command .= $subprocess->{host};
    $command .= '/remote.php/dav/files/';
    $command .= $subprocess->{user};
    $command .= $subprocess->{path};
    $command .=
'" --data \'<?xml version="1.0" encoding="UTF-8"?><d:propfind xmlns:d="DAV:"><d:prop xmlns:oc="http://owncloud.org/ns"><d:getlastmodified/></d:prop></d:propfind>\'';

    return ExecuteCommand($command);
}

sub ExecuteNCremoveFile {
    my $subprocess = shift;

    my $command = $subprocess->{curl};
    $command .= ' -k -X DELETE -u ';
    $command .= $subprocess->{user} . ':' . $subprocess->{pass};
    $command .= ' "' . $subprocess->{proto} . '://';
    $command .= $subprocess->{host};
    $command .= '/remote.php/dav/files/';
    $command .= $subprocess->{user};
    $command .= $subprocess->{path};
    $command .= '/';
    $command .= $subprocess->{fileNameAtStorage};
    $command .= '"';

    return ExecuteCommand($command);
}

sub ExecuteCommand {
    my @options = @_;
    my $command = join q{ }, @options;
    return ( $_ = qx{$command 2>&1}, $? >> 8 );
}

######################################
# End Childprozess
######################################

sub CleanSubprocess {
    my $hash = shift;

    my $name = $hash->{NAME};

    delete( $hash->{".fhem"}{subprocess} );
    ::Log3( $name, 4, qq{backupToStorage ($name) - clean Subprocess} );

    return;
}

sub StorePassword {
    my $hash     = shift;
    my $name     = shift;
    my $password = shift;

    my $index   = $hash->{TYPE} . "_" . $name . "_passwd";
    my $key     = ::getUniqueId() . $index;
    my $enc_pwd = "";

    if ( eval { use Digest::MD5; 1 } ) {

        $key = Digest::MD5::md5_hex( unpack "H*", $key );
        $key .= Digest::MD5::md5_hex($key);
    }

    for my $char ( split //, $password ) {

        my $encode = chop($key);
        $enc_pwd .= sprintf( "%.2x", ord($char) ^ ord($encode) );
        $key = $encode . $key;
    }

    my $err = ::setKeyValue( $index, $enc_pwd );
    ::DoTrigger( $name, 'password add' );

    return qq{error while saving the password - $err}
      if ( defined($err) );

    return q{password successfully saved};
}

sub ReadPassword {
    my $hash = shift;
    my $name = shift;

    my $index = $hash->{TYPE} . "_" . $name . "_passwd";
    my $key   = ::getUniqueId() . $index;
    my ( $password, $err );

    ::Log3( $name, 4, qq{backupToStorage ($name) - Read password from file} );

    ( $err, $password ) = ::getKeyValue($index);

    if ( defined($err) ) {

        ::Log3( $name, 3,
qq{backupToStorage ($name) - unable to read password from file: $err}
        );
        return;
    }

    if ( defined($password) ) {
        if ( eval { use Digest::MD5; 1 } ) {
            $key = Digest::MD5::md5_hex( unpack "H*", $key );
            $key .= Digest::MD5::md5_hex($key);
        }

        my $dec_pwd = '';

        for my $char ( map { pack( 'C', hex($_) ) } ( $password =~ /(..)/xg ) )
        {

            my $decode = chop($key);
            $dec_pwd .= chr( ord($char) ^ ord($decode) );
            $key = $decode . $key;
        }

        return $dec_pwd;
    }
    else {
        ::Log3( $name, 3, qq{backupToStorage ($name) - No password in file} );
        return;
    }

    return;
}

sub DeletePassword {
    my $hash = shift;

    my $name = $hash->{NAME};

    ::setKeyValue( $hash->{TYPE} . "_" . $name . "_passwd", undef );
    ::DoTrigger( $name, 'password remove' );

    return;
}

sub CheckAttributsForCredentials {
    my $hash = shift;

    my $name = $hash->{NAME};

    my $ncUser = ::AttrVal( $name, 'bTS_User', 'none' );
    my $ncPass = ReadPassword( $hash, $name );
    my $ncHost = ::AttrVal( $name, 'bTS_Host', 'none' );
    my $status = 'ready';

    $status = (
        $status eq 'ready' && $ncUser eq 'none' ? 'no user credential attribut'
        : $status eq 'ready'
          && $ncHost eq 'none' ? 'no host credential attribut'
        : $status eq 'ready' && !defined($ncPass) ? 'no password set'
        :                                           $status
    );

    return readingsSingleUpdate( $hash, 'state', $status, 1 );
}

sub WriteReadings {
    my $hash = shift;
    my $json = shift;

    my $name = $hash->{NAME};

    my $decode_json = eval { decode_json($json) };
    if ($@) {
        ::Log3( $name, 2, qq{backupToStorage ($name) - JSON error: $@} );
        return;
    }

    ::readingsBeginUpdate($hash);
    ::readingsBulkUpdate( $hash, 'state',       'ready' );
    ::readingsBulkUpdate( $hash, 'uploadState', $decode_json->{ncUpload} );
    ::readingsEndUpdate( $hash, 1 );

    return;
}

1;
