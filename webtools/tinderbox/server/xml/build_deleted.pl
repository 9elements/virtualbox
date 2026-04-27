#!/usr/bin/perl -wT -I..
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
#
# ***** END LICENSE BLOCK *****

use strict;
use CGI;
use Tinderbox3::DB;
use Tinderbox3::XML;
use Tinderbox3::Log;
use Tinderbox3::TestManagerInterface;

our $p = new CGI();
our $dbh = get_dbh();

$SIG{__DIE__} = sub { die_xml_error($p, $dbh, $_[0]); };

my $url = $p->param('url') || "";
if (!$url) {
  die_xml_error($p, $dbh, "Must specify url!");
}

# Get the build_time, machine id, ++ and tell the test manager.
my $fields = $dbh->selectall_arrayref(
  "SELECT DISTINCT
          tbox_build_field.build_time,
          tbox_build_field.machine_id,
          tbox_machine.machine_name,
          tbox_machine.tree_name,
          tbox_build_field.value
     FROM tbox_build_field, tbox_machine
    WHERE tbox_build_field.value = ?
      AND tbox_build_field.machine_id = tbox_machine.machine_id
 ORDER BY tbox_build_field.build_time
  ",
  undef, $url);

foreach my $field (@{$fields}) {
    my $build_time    = $field->[0];
    my $machine_id    = $field->[1];
    my $machine_name  = $field->[2];
    my $tree          = $field->[3];
    my $untainted_url = $field->[4];
    Tinderbox3::TestManagerInterface::del_build($dbh, $tree, $machine_id, $machine_name, $build_time, $untainted_url);
}

# TestManagerInterface::del_build runs a script and the open DB connection
# is either not inherited during fork() or it is closed during exec()
$dbh->disconnect;
$dbh = get_dbh();

# delete the build reference(s).
my $rows = $dbh->do("DELETE FROM tbox_build_field WHERE value = ?", undef, $url);
Tinderbox3::DB::maybe_commit($dbh);

if ($rows eq "0E0") {
  die_xml_error($p, $dbh, "No rows deleted!");
}


#
# Print response
#
print $p->header("text/xml");
print "<response>\n";
print "<builds_deleted rows='$rows'/>\n";
print "</response>\n";

$dbh->disconnect;
