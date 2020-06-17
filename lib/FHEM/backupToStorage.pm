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

    Log3( $name, 3, "backupToStorage ($name) - defined" );

    return;
}

sub Undef {
    my $hash = shift;
    my $name = shift;

    Log3( $name, 3, "backupToStorage ($name) - delete device $name" );

    return;
}
