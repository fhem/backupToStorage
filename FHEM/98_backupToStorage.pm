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

package main;

use strict;
use warnings;
use utf8;

use FHEM::backupToStorage;

sub backupToStorage_Initialize {
    my $hash = shift;

## Da ich mit package arbeite müssen in die Initialize für die jeweiligen hash Fn Funktionen der Funktionsname
    #  und davor mit :: getrennt der eigentliche package Name des Modules
    $hash->{SetFn}    = \&FHEM::backupToStorage::Set;
    $hash->{DefFn}    = \&FHEM::backupToStorage::Define;
    $hash->{NotifyFn} = \&FHEM::backupToStorage::Notify;
    $hash->{UndefFn}  = \&FHEM::backupToStorage::Undef;
    $hash->{AttrList} = 'bTS_Host ' . 'bTS_User ' . 'bTS_Path ';
    $hash->{NotifyOrderPrefix} = '51-';    # Order Nummer für NotifyFn

    return FHEM::Meta::InitMod( __FILE__, $hash );
}

1;

=pod
=item device
=item summary       Module for copy finished fhem backups to storage (Nextcloud)
=item summary_DE    Modul zum kopieren fertiger fhem Backups auf ein Storage (Nextcloud)


=begin html

<a name="backupToStorage"></a>
<h3>backupToStorage</h3>
<ul>

</ul>

=end html

=begin html_DE

<a name="backupToStorage"></a>
<h3>backupToStorage</h3>
<ul>

</ul>

=end html_DE

=for :application/json;q=META.json 98_backupToStorage.pm
{
  "abstract": "Module for copy finished fhem backups to storage (Nextcloud)",
  "x_lang": {
    "de": {
      "abstract": "Modul zum kopieren fertiger fhem Backups auf ein Storage (Nextcloud)"
    }
  },
  "keywords": [
    "fhem-mod-device",
    "fhem-core",
    "Backup",
    "Nextcloud"
  ],
  "release_status": "devepolment",
  "license": "GPL_2",
  "version": "v0.0.1",
  "author": [
    "Marko Oldenburg <fhemsupport@cooltux.net>"
  ],
  "x_fhem_maintainer": [
    "CoolTux"
  ],
  "x_fhem_maintainer_github": [
    "LeonGaultier"
  ],
  "prereqs": {
    "runtime": {
      "requires": {
        "FHEM": 5.00918799,
        "perl": 5.016, 
        "Meta": 0,
        "JSON": 0,
        "Date::Parse": 0
      },
      "recommends": {
      },
      "suggests": {
      }
    }
  }
}
=end :application/json;q=META.json

=cut
