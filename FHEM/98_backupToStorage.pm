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

package FHEM::backupToStorage;

use strict;
use warnings;
use utf8;
use FHEM::Meta;

require FHEM::Services::backupToStorage;

#-- Run before package compilation
BEGIN {
    sub ::backupToStorage_Initialize { goto &Initialize }
}

sub Initialize {
    my $hash = shift;

## Da ich mit package arbeite müssen in die Initialize für die jeweiligen hash Fn Funktionen der Funktionsname
    #  und davor mit :: getrennt der eigentliche package Name des Modules
    $hash->{SetFn}             = \&FHEM::Services::backupToStorage::Set;
    $hash->{DefFn}             = \&FHEM::Services::backupToStorage::Define;
    $hash->{NotifyFn}          = \&FHEM::Services::backupToStorage::Notify;
    $hash->{UndefFn}           = \&FHEM::Services::backupToStorage::Undef;
    $hash->{AttrFn}            = \&FHEM::Services::backupToStorage::Attr;
    $hash->{RenameFn}          = \&FHEM::Services::backupToStorage::Rename;
    $hash->{DeleteFn}          = \&FHEM::Services::backupToStorage::Delete;
    $hash->{ShutdownFn}        = \&FHEM::Services::backupToStorage::Shutdown;
    $hash->{NotifyOrderPrefix} = '51-';    # Order Nummer für NotifyFn
    $hash->{AttrList} =
        'bTS_Host '
      . 'bTS_User '
      . 'bTS_Path '
      . 'bTS_Proto:http '
      . 'bTS_Type:Nextcloud,SynologyFileStation '
      . 'bTS_KeepLastBackups:1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20 '
      . 'disable:1 '
      . 'disabledForIntervals';
    $hash->{parseParams} = 1;

    return FHEM::Meta::InitMod( __FILE__, $hash );
}

1;

=pod
=item device
=item summary       Module for copy finished fhem backups to storage (Nextcloud)
=item summary_DE    Modul zum kopieren fertiger fhem Backups auf ein Storage (Nextcloud)


=begin html

<a id="backupToStorage"></a>
<h3>backupToStorage</h3>
<ul>
    The module offers the possibility to automatically load the created backup files from the backup module onto a storage.<br>
    <a name="backupToStoragedefine"></a>
    <br>
    <a id="backupToStorage-define"></a>
    <h4>Define</h4>
    <ul>
        <code>define &lt;name&gt; backupToStorage</code>
        <br>
        Beispiel:
        <ul>
            <code>define backupNextcloudUpload backupToStorage</code>
        </ul>
        <br>
    </ul>
    <a id="backupToStorage-attr"></a>
    <h4>Attributs</h4>
    <ul>
        <a id="backupToStorage-attr-bTS_Host"></a>
        <li><i>bTS_Host</i>
            Server name where the storage is located
        </li>
        <a id="backupToStorage-attr-bTS_User"></a>
        <li><i>bTS_User</i>
            remote user for login
        </li>
        <a id="backupToStorage-attr-bTS_Path"></a>
        <li><i>bTS_Path</i>
            remote path where the upload file should go. e.g. Nextcloud &lt;/FHEM-Backup&gt;
        </li>
        <a id="backupToStorage-attr-bTS_Type"></a>
        <li><i>bTS_Type</i>
            Storage Type, default is Nextcloud
        </li>
    </ul>
    <br>
    <a id="backupToStorage-set"></a>
    <h4>Set</h4>
    <ul>
        <a id="backupToStorage-set-addpassword"></a>
        <li><i>addpassword</i>
            puts the storage password in the keyfile / !!! don't use = !!!
        </li>
        <a id="backupToStorage-set-deletepassword"></a>
        <li><i>deletepassword</i>
            removes the storage password from the keyfile
        </li>
    </ul>
    <br>
    <a id="backupToStorage-readings"></a>
    <b>Readings</b>
    <ul>
        <li><b>state</b> - shows the current status of the module</li>
        <li><b>fhemBackupFile</b> - the path of the last backup file is automatically set by the backup module</li>
        <li><b>uploadState</b> - Status of the last upload.</li>
    </ul>
</ul>

=end html

=begin html_DE

<a id="backupToStorage"></a>
<h3>backupToStorage</h3>
<ul>
    Das Modul bietet die M&ouml;glichkeit die erstellten Backupdateien vom Modul backup automatisiert auf ein Storage zu laden.<br>
    <a name="backupToStoragedefine"></a>
    <br>
    <a id="backupToStorage-define"></a>
    <h4>Define</h4>
    <ul>
        <code>define &lt;name&gt; backupToStorage</code>
        <br>
        Beispiel:
        <ul>
            <code>define backupNextcloudUpload backupToStorage</code>
        </ul>
        <br>
    </ul>
    <a id="backupToStorage-attr"></a>
    <h4>Attribute</h4>
    <ul>
        <a id="backupToStorage-attr-bTS_Host"></a>
        <li><i>bTS_Host</i>
            Servername wo sich das Storage drauf befindet
        </li>
        <a id="backupToStorage-attr-bTS_User"></a>
        <li><i>bTS_User</i>
            remote User f&uuml;r den Login
        </li>
        <a id="backupToStorage-attr-bTS_Path"></a>
        <li><i>bTS_Path</i>
            remote Path wohin das uploadfile soll. z.B. Nextcloud &lt;/FHEM-Backup&gt;
        </li>
        <a id="backupToStorage-attr-bTS_Type"></a>
        <li><i>bTS_Type</i>
            Storage Type, default ist Nextcloud
        </li>
    </ul>
    <br>
    <a id="backupToStorage-set"></a>
    <h4>Set</h4>
    <ul>
        <a id="backupToStorage-set-addpassword"></a>
        <li><i>addpassword</i><br>
            setzt das Storage Passwort ins Keyfile / !!!Keine = verwenden!!!
        </li>
        <a id="backupToStorage-set-deletepassword"></a>
        <li><i>deletepassword</i><br>
            entfernt das Storage Passwort aus dem Keyfile
        </li>
    </ul>
    <br>
    <a id="backupToStorage-readings"></a>
    <h4>Readings</h4>
    <ul>
        <li><b>state</b> - zeigt den aktuellen Status des Modules an</li>
        <li><b>fhemBackupFile</b> - der Pfad des letzten Backupfiles, wird automatisch vom backup Modul gesetzt</li>
        <li><b>uploadState</b> - Status des letzten uploads.</li>
    </ul>
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
  "version": "v2.0.0",
  "author": [
    "Marko Oldenburg <fhemdevelopment@cooltux.net>"
  ],
  "x_fhem_maintainer": [
    "CoolTux"
  ],
  "x_fhem_maintainer_github": [
    "CoolTuxNet"
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
