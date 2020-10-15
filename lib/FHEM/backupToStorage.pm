###############################################################################
#
# Developed with Kate
#
#  (c) 2020 Copyright: Marko Oldenburg (fhemsupport@cooltux.net)
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

package FHEM::backupToStorage;

use strict;
use warnings;
use utf8;

use GPUtils qw(GP_Import);

use Data::Dumper;    #only for Debugging

# try to use JSON::MaybeXS wrapper
#   for chance of better performance + open code
eval {
    require JSON::MaybeXS;
    import JSON::MaybeXS qw( decode_json encode_json );
    1;
};

if ($@) {
    $@ = undef;

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
    };

    if ($@) {
        $@ = undef;

        # In rare cases, Cpanel::JSON::XS may
        #   be installed but JSON|JSON::MaybeXS not ...
        eval {
            require Cpanel::JSON::XS;
            import Cpanel::JSON::XS qw(decode_json encode_json);
            1;
        };

        if ($@) {
            $@ = undef;

            # In rare cases, JSON::XS may
            #   be installed but JSON not ...
            eval {
                require JSON::XS;
                import JSON::XS qw(decode_json encode_json);
                1;
            };

            if ($@) {
                $@ = undef;

                # Fallback to built-in JSON which SHOULD
                #   be available since 5.014 ...
                eval {
                    require JSON::PP;
                    import JSON::PP qw(decode_json encode_json);
                    1;
                };

                if ($@) {
                    $@ = undef;

                    # Fallback to JSON::backportPP in really rare cases
                    require JSON::backportPP;
                    import JSON::backportPP qw(decode_json encode_json);
                    1;
                }
            }
        }
    }
}

## Import der FHEM Funktionen
#-- Run before package compilation
BEGIN {

    # Import from main context
    GP_Import(
        qw(
          readingsSingleUpdate
          readingsBulkUpdate
          readingsBeginUpdate
          readingsEndUpdate
          ReadingsVal
          ReadingsAge
          gettimeofday
          InternalTimer
          defs
          modules
          setKeyValue
          getKeyValue
          getUniqueId
          Log3
          CommandAttr
          attr
          AttrVal
          deviceEvents
          init_done
          devspec2array
          DoTrigger
          HttpUtils_NonblockingGet)
    );
}

sub Define {
    my $hash = shift // return;
    my $aArg = shift // return;

    return $@ unless ( FHEM::Meta::SetInternals($hash) );
    use version 0.60; our $VERSION = FHEM::Meta::Get( $hash, 'version' );

    return 'only one backupToStorage instance allowed'
      if ( devspec2array('TYPE=backupToStorage') > 1 )
      ; # es wird geprüft ob bereits eine Instanz unseres Modules existiert,wenn ja wird abgebrochen
    return 'too few parameters: define <name> backupToStorage'
      if ( scalar( @{$aArg} ) != 2 );

    my $name = shift @$aArg;
    $hash->{VERSION}        = version->parse($VERSION)->normal;
    $hash->{NOTIFYDEV}      = 'global,' . $name;
    $hash->{STORAGETYPE}    = AttrVal( $name, 'bTS_Type', 'Nextcloud' );

    Log3( $name, 3, "backupToStorage ($name) - defined" );

    return;
}

sub Undef {
    my $hash = shift;
    my $name = shift;

    Log3( $name, 3, "backupToStorage ($name) - delete device $name" );

    return;
}

sub Delete {
    my $hash = shift;
    my $name = shift;

    HttpUtils_Close( $hash->{helper}->{HttpUtilsParam} )
      if ( defined($hash->{helper}->{HttpUtilsParam}) );
    DeletePassword($hash);

    return;
}

sub Shutdown {
    my $hash = shift;

    HttpUtils_Close( $hash->{helper}->{HttpUtilsParam} )
      if ( defined($hash->{helper}->{HttpUtilsParam}) );

    return;
}

sub Notify {
    my $hash = shift // return;
    my $dev  = shift // return;

    my $name    = $hash->{NAME};
    my $devname = $dev->{NAME};
    my $devtype = $dev->{TYPE};
    my $events  = deviceEvents( $dev, 1 );
    return if ( !$events );

    Log3( $name, 4,
            "backupToStorage ($name) - Devname: "
          . $devname
          . " Name: "
          . $name
          . " Notify: "
          . Dumper $events);    # mit Dumper

    PushToStorage($hash)
      if ( ( grep m{^backup.done(.+)?$}xms, @{$events} )
        && $devname eq 'global'
        && $init_done );

    CheckAttributsForCredentials($hash)
      if (
        (
            (
                (
                    grep m{^DELETEATTR.$name.(bTS_Host|bTS_User)$}xms,
                    @{$events}
                    or grep m{^ATTR.$name.(bTS_Host|bTS_User).\S+$}xms,
                    @{$events}
                )
                && $devname eq 'global'
            )
            || (
                (
                    $devname eq $name && grep m{^password.(add|remove)$}xms,
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
                     AttrVal( $name, 'bTS_Host', 'none' ) eq 'none'
                  || AttrVal( $name, 'bTS_User', 'none' ) eq 'none'
                  || !defined( ReadPassword( $hash, $name ) )
            )
            ? 'please set storage account credentials first'
            : 'ready'
        ),
        1
      )
      if (
        (
               ( grep m{^DEFINED.$name$}xms, @{$events} )
            && $devname eq 'global'
            && $init_done
        )
        || (
            grep m{^INITIALIZED$}xms,
            @{$events} or grep m{^REREADCFG$}xms,
            @{$events} or grep m{^MODIFIED.$name$}xms,
            @{$events}
        )
        && $devname eq 'global'
      );

    return;
}

sub Set {
    my $hash = shift // return;
    my $aArg = shift // return;

    my $name = shift @$aArg;
    my $cmd  = shift @$aArg
      // return qq{"set $name" needs at least one argument};

    if ( lc $cmd eq 'addpassword' ) {
        return "please set Attribut bTS_User first"
          if ( AttrVal( $name, 'bTS_User', 'none' ) eq 'none' );
        return "usage: $cmd <password>" if ( scalar( @{$aArg} ) != 1 );

        StorePassword( $hash, $name, $aArg->[0] );
    }
    elsif ( lc $cmd eq 'deletepassword' ) {
        return "usage: $cmd" if ( scalar( @{$aArg} ) != 0 );

        DeletePassword($hash);
    }
    else {
        my $list = (
            defined( ReadPassword( $hash, $name ) )
            ? 'deletepassword:noArg'
            : 'addpassword'
        );

        return 'Unknown argument ' . $cmd . ', choose one of ' . $list;
    }

    return;
}

sub Rename {
    my $new = shift;
    my $old = shift;

    my $hash = $defs{$new};

    StorePassword( $hash, $new, ReadPassword( $hash, $old ) );
    setKeyValue( $hash->{TYPE} . "_" . $old . "_passwd", undef );

    return;
}

sub PushToStorage {
    my $hash = shift;

    my $name = $hash->{NAME};

    Log3( $name, 4, "backupToStorage ($name) - push to storage function" );
    
    return
      if ( ReadingsAge($name,'fhemBackupFile',60) > 5 );


    require "SubProcess.pm";
    my $subprocess = SubProcess->new( { onRun => \&FileUpload } );

    my $backupFile = ReadingsVal( $name, 'fhemBackupFile', 'none' );

    my @fileNameAtStorage_array = split( '/', $backupFile );
    my $fileNameAtStorage = $fileNameAtStorage_array[$#fileNameAtStorage_array];

    $subprocess->{curl} = qx(which curl);
    chomp($subprocess->{curl});
    $subprocess->{type} = $hash->{STORAGETYPE};
    $subprocess->{host} = AttrVal( $name, 'bTS_Host', '' );
    $subprocess->{user} = AttrVal( $name, 'bTS_User', '' );
    $subprocess->{pass} = ReadPassword( $hash, $name );
    $subprocess->{path}              = AttrVal( $name, 'bTS_Path', '' );
    $subprocess->{backupfile}        = $backupFile;
    $subprocess->{fileNameAtStorage} = $fileNameAtStorage;

    my $pid = $subprocess->run();

    readingsSingleUpdate( $hash, 'state', ' file upload in progress', 1 );

    if ( !defined($pid) ) {
        Log3( $name, 1,
            "backupToStorage ($name) - Cannot execute command asynchronously" );

        CleanSubprocess($hash);
        readingsSingleUpdate( $hash, 'state',
            'Cannot execute command asynchronously', 1 );
        return undef;
    }

    Log3( $name, 4,
        "backupToStorage ($name) - execute command asynchronously (PID=$pid)"
    );

    $hash->{".fhem"}{subprocess} = $subprocess;

    InternalTimer( gettimeofday() + 1,
        "FHEM::backupToStorage::PollChild", $hash );
    Log3( $hash, 4,
        "backupToStorage ($name) - control passed back to main loop." );

    return;
}

sub PollChild {
    my $hash = shift;

    my $name = $hash->{NAME};

    if ( defined( $hash->{".fhem"}{subprocess} ) ) {
        my $subprocess = $hash->{".fhem"}{subprocess};
        my $json       = $subprocess->readFromChild();

        if ( !defined($json) ) {
            Log3( $name, 5,
                    "backupToStorage ($name) - still waiting ("
                  . $subprocess->{lasterror}
                  . ")." );
            InternalTimer( gettimeofday() + 1,
                "FHEM::backupToStorage::PollChild", $hash );
            return;
        }
        else {
            Log3( $name, 4,
"backupToStorage ($name) - got result from asynchronous parsing."
            );
            $subprocess->wait();
            Log3( $name, 4,
                "backupToStorage ($name) - asynchronous finished." );

            CleanSubprocess($hash);
            WriteReadings( $hash, $json );
        }
    }
}

######################################
# Begin Childprozess
######################################
sub FileUpload {
    my $subprocess = shift;
    my $response   = {};

    if ( $subprocess->{type} eq 'Nextcloud' ) {
        my ($returnString,$returnCode) = ExecuteNCupload($subprocess);

        $response->{ncUpload} = ( $returnCode == 72057594037927935
          && $returnString eq ''
            ? 'upload successfully'
            : $returnString );
    }

    my $json = eval { encode_json($response) };
    if ($@) {
        Log3( 'backupToStorage File Upload',
            1, "backupToStorage - JSON error: $@" );
        $json = '{"jsonerror":"$@"}';
    }

    $subprocess->writeToParent($json);

    return;
}

sub ExecuteNCupload {
    my $subprocess = shift;

    my $command = $subprocess->{curl};
    $command .= ' -s -u ';
    $command .= $subprocess->{user} . ':' . $subprocess->{pass};
    $command .= ' -T ' . $subprocess->{backupfile};
    $command .= ' "https://';
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
    my $command = join q{ }, @_;
    return ( $_ = qx{$command 2>&1}, $? >> 8 );
}

######################################
# End Childprozess
######################################

sub CleanSubprocess {
    my $hash = shift;

    my $name = $hash->{NAME};

    delete( $hash->{".fhem"}{subprocess} );
    Log3( $name, 4, "backupToStorage ($name) - clean Subprocess" );
}

sub StorePassword {
    my $hash     = shift;
    my $name     = shift;
    my $password = shift;

    my $index   = $hash->{TYPE} . "_" . $name . "_passwd";
    my $key     = getUniqueId() . $index;
    my $enc_pwd = "";

    if ( eval "use Digest::MD5;1" ) {

        $key = Digest::MD5::md5_hex( unpack "H*", $key );
        $key .= Digest::MD5::md5_hex($key);
    }

    for my $char ( split //, $password ) {

        my $encode = chop($key);
        $enc_pwd .= sprintf( "%.2x", ord($char) ^ ord($encode) );
        $key = $encode . $key;
    }

    my $err = setKeyValue( $index, $enc_pwd );
    DoTrigger( $name, 'password add' );

    return "error while saving the password - $err" if ( defined($err) );

    return "password successfully saved";
}

sub ReadPassword {
    my $hash = shift;
    my $name = shift;

    my $index = $hash->{TYPE} . "_" . $name . "_passwd";
    my $key   = getUniqueId() . $index;
    my ( $password, $err );

    Log3( $name, 4, "backupToStorage ($name) - Read password from file" );

    ( $err, $password ) = getKeyValue($index);

    if ( defined($err) ) {

        Log3( $name, 3,
            "backupToStorage ($name) - unable to read password from file: $err"
        );
        return undef;
    }

    if ( defined($password) ) {
        if ( eval "use Digest::MD5;1" ) {
            $key = Digest::MD5::md5_hex( unpack "H*", $key );
            $key .= Digest::MD5::md5_hex($key);
        }

        my $dec_pwd = '';

        for my $char ( map { pack( 'C', hex($_) ) } ( $password =~ /(..)/g ) ) {

            my $decode = chop($key);
            $dec_pwd .= chr( ord($char) ^ ord($decode) );
            $key = $decode . $key;
        }

        return $dec_pwd;
    }
    else {
        Log3( $name, 3, "backupToStorage ($name) - No password in file" );
        return undef;
    }

    return;
}

sub DeletePassword {
    my $hash = shift;

    my $name = $hash->{NAME};

    setKeyValue( $hash->{TYPE} . "_" . $name . "_passwd", undef );
    DoTrigger( $name, 'password remove' );

    return;
}

sub CheckAttributsForCredentials {
    my $hash = shift;

    my $name = $hash->{NAME};

    my $ncUser = AttrVal( $name, 'bTS_User', 'none' );
    my $ncPass = ReadPassword( $hash, $name );
    my $ncHost = AttrVal( $name, 'bTS_Host', 'none' );
    my $status = 'ready';

    $status = ( $status eq 'ready'
                    && $ncUser eq 'none'
                        ? 'no user credential attribut'
                        : $status eq 'ready'
                    && $ncHost eq 'none'
                        ? 'no host credential attribut'
                        : $status eq 'ready'
                    && !defined($ncPass)
                        ? 'no password set'
                        : $status
    );

    return readingsSingleUpdate( $hash, 'state', $status, 1 );
}

sub WriteReadings {
    my $hash = shift;
    my $json = shift;

    my $name = $hash->{NAME};

    my $decode_json = eval { decode_json($json) };
    if ($@) {
        Log3( $name, 2, "backupToStorage ($name) - JSON error: $@" );
        return;
    }

    readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, 'state',       'ready' );
    readingsBulkUpdate( $hash, 'uploadState', $decode_json->{ncUpload} );
    readingsEndUpdate( $hash, 1 );
}

1;
