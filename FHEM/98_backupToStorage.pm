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
use Meta;

use FHEM::backupToStorage;

sub backupToStorage_Initialize {
    my $hash = shift;

## Da ich mit package arbeite müssen in die Initialize für die jeweiligen hash Fn Funktionen der Funktionsname
    #  und davor mit :: getrennt der eigentliche package Name des Modules
    $hash->{SetFn}      = \&FHEM::backupToStorage::Set;
    $hash->{DefFn}      = \&FHEM::backupToStorage::Define;
    $hash->{NotifyFn}   = \&FHEM::backupToStorage::Notify;
    $hash->{UndefFn}    = \&FHEM::backupToStorage::Undef;
    $hash->{RenameFn}   = \&FHEM::backupToStorage::Rename;
    $hash->{DeleteFn}   = \&FHEM::backupToStorage::Delete;
    $hash->{ShutdownFn} = \&FHEM::backupToStorage::Shutdown;
    $hash->{NotifyOrderPrefix} = '51-';    # Order Nummer für NotifyFn
    $hash->{AttrList} =
        'bTS_Host '
      . 'bTS_User '
      . 'bTS_Path '
      . 'bTS_Proto:http '
      . 'bTS_Type:Nextcloud '
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

<a name="backupToStorage"></a>
<h3>backupToStorage</h3>
<ul>
    The module offers the possibility to automatically load the created backup files from the backup module onto a storage.<br>
    <a name="backupToStoragedefine"></a>
    <br>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; backupToStorage</code>
        <br>
        Beispiel:
        <ul>
            <code>define backupNextcloudUpload backupToStorage</code>
        </ul>
        <br>
    </ul>
    <a name="backupToStorageattributes"></a>
    <b>Attributs</b>
    <ul>
        <li>bTS_Host - Server name where the storage is located</li>
        <li>bTS_User - remote user for login</li>
        <li>bTS_Path - remote path where the upload file should go. e.g. Nextcloud &lt;/FHEM-Backup&gt;</li>
        <li>bTS_Type - Storage Type, default is Nextcloud</li>
    </ul>
    <br>
    <a name="backupToStorageset"></a>
    <b>Set</b>
    <ul>
        <li>addpassword - puts the storage password in the keyfile / !!! don't use = !!!</li>
        <li>deletepassword - removes the storage password from the keyfile</li>
    </ul>
    <br>
    <a name="backupToStoragereadings"></a>
    <b>Readings</b>
    <ul>
        <li>state - shows the current status of the module</li>
        <li>fhemBackupFile - the path of the last backup file is automatically set by the backup module</li>
        <li>uploadState - Status of the last upload.</li>
    </ul>
</ul>

=end html

=begin html_DE

<a name="backupToStorage"></a>
<h3>backupToStorage</h3>
<ul>
    Das Modul bietet die M&ouml;glichkeit die erstellten Backupdateien vom Modul backup automatisiert auf ein Storage zu laden.<br>
    <a name="backupToStoragedefine"></a>
    <br>
    <b>Define</b>
    <ul>
        <code>define &lt;name&gt; backupToStorage</code>
        <br>
        Beispiel:
        <ul>
            <code>define backupNextcloudUpload backupToStorage</code>
        </ul>
        <br>
    </ul>
    <a name="backupToStorageattributes"></a>
    <b>Attribute</b>
    <ul>
        <li>bTS_Host - Servername wo sich das Storage drauf befindet</li>
        <li>bTS_User - remote User f&uuml;r den Login</li>
        <li>bTS_Path - remote Path wohin das uploadfile soll. z.B. Nextcloud &lt;/FHEM-Backup&gt;</li>
        <li>bTS_Type - Storage Type, default ist Nextcloud</li>
    </ul>
    <br>
    <a name="backupToStorageset"></a>
    <b>Set</b>
    <ul>
        <li>addpassword - setzt das Storage Passwort ins Keyfile / !!!Keine = verwenden!!!</li>
        <li>deletepassword - entfernt das Storage Passwort aus dem Keyfile</li>
    </ul>
    <br>
    <a name="backupToStoragereadings"></a>
    <b>Readings</b>
    <ul>
        <li>state - zeigt den aktuellen Status des Modules an</li>
        <li>fhemBackupFile - der Pfad des letzten Backupfiles, wird automatisch vom backup Modul gesetzt</li>
        <li>uploadState - Status des letzten uploads.</li>
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
  "version": "v1.1.0",
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
