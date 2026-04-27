#!/usr/bin/perl -wT -I.
# ***** BEGIN LICENSE BLOCK *****
# Version: MPL 1.1
#
# The contents of this file are subject to the Mozilla Public License Version
# 1.1 (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
# http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
# for the specific language governing rights and limitations under the
# License.
#
# The Original Code is Tinderbox 3.
#
# The Initial Developer of the Original Code is
# John Keiser (john@johnkeiser.com).
# Portions created by the Initial Developer are Copyright (C) 2004
# the Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   InnoTek
#
# ***** END LICENSE BLOCK *****

use strict;
use CGI;
use Tinderbox3::Header;
use Tinderbox3::DB;
use Tinderbox3::Login;

my $p = new CGI;
my $dbh = get_dbh();

my ($login, $cookie) = check_session($p, $dbh);
header($p, $login, $cookie, "Saved Cause Of Failure");

my $machine_id = $p->param('machine_id');
$machine_id =~ s/\D//g;

my $build_time = $p->param('build_time');
$build_time =~ s/\D//g;

my $tree = $p->param('tree') || "";
my $cause = $p->param('cause') || "";

if (!$login) {
  die "Must log in!";
}

# purge old causes
my $sth = $dbh->prepare(
  "DELETE FROM tbox_build_field
         WHERE machine_id = ?
           AND build_time = " . Tinderbox3::DB::sql_abstime("?") . "
           AND name = 'cause'
  ");
$sth->execute($machine_id, $build_time);

# insert
if ($cause ne "") {
  $sth = $dbh->prepare(
    "INSERT INTO tbox_build_field (machine_id, build_time, name, value)
     VALUES (?, " . Tinderbox3::DB::sql_abstime("?") . ", 'cause', ?)
    ");
  $sth->execute($machine_id, $build_time, $cause);
}

Tinderbox3::DB::maybe_commit($dbh);

print "<p>Cause changed.  Thank you for playing.  <a href='showtests.pl?tree=$tree'>Tree Test View</a></p>\n";

footer($p);
$dbh->disconnect;
