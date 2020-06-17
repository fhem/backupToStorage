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

use GPUtils qw(GP_Import GP_Export);

use Data::Dumper;    #only for Debugging

## Import der FHEM Funktionen
#-- Run before package compilation
BEGIN {

    # Import from main context
    GP_Import(
        qw(
          readingsSingleUpdate
          readingsBulkUpdate
          readingsBulkUpdateIfChanged
          readingsBeginUpdate
          readingsEndUpdate
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
          devspec2array)
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
    $hash->{VERSION}   = version->parse($VERSION)->normal;
    $hash->{NOTIFYDEV} = 'global';

    readingsSingleUpdate( $hash, 'state',
        'please set storage account credentials first', 1 )
      if ( AttrVal( $name, 'bTS_Host', 'none' ) eq 'none'
        || AttrVal( $name, 'bTS_User', 'none' ) eq 'none'
        || !defined( ReadPassword( $hash, $name ) ) );

    Log3( $name, 3, "backupToStorage ($name) - defined" );

    return;
}

sub Undef {
    my $hash = shift;
    my $name = shift;

    Log3( $name, 3, "backupToStorage ($name) - delete device $name" );

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
            "AutoShuttersControl ($name) - Devname: "
          . $devname
          . " Name: "
          . $name
          . " Notify: "
          . Dumper $events);    # mit Dumper

    PushToStorage($hash)
      if ( grep /^backup.done/,
        @{$events} && $devname eq 'global' && $init_done );

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
        return 'Unknown argument ' . $cmd
          . ', choose one of addpassword,deletepassword';
    }

    return;
}

sub PushToStorage {
    my $hash = shift;

    my $name = $hash->{NAME};

    return;
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
    return "error while saving the password - $err" if ( defined($err) );

    return "password successfully saved";
}

sub ReadPassword {
    my $hash = shift;
    my $name = shift;

    my $index = $hash->{TYPE} . "_" . $name . "_passwd";
    my $key   = getUniqueId() . $index;
    my ( $password, $err );

    Log3 $name, 4, "backupToStorage ($name) - Read password from file";

    ( $err, $password ) = getKeyValue($index);

    if ( defined($err) ) {

        Log3 $name, 3,
          "backupToStorage ($name) - unable to read password from file: $err";
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
        Log3 $name, 3, "backupToStorage ($name) - No password in file";
        return undef;
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
