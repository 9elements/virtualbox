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
header($p, $login, $cookie, "Edit Cause Of Failure");

my $machine_id = $p->param('machine_id');
$machine_id =~ s/\D//g;

# query the machine name.
my $machine_name = @{$dbh->selectcol_arrayref("SELECT machine_name FROM tbox_machine WHERE machine_id = ?", undef, $machine_id)}[0];
print "Machine: $machine_name (id=$machine_id)<br>\n";

my $build_time = $p->param('build_time');
$build_time =~ s/\D//g;

my $tree = $p->param('tree');

print qq^<form action='savecause.pl'>
@{[$p->hidden(-name=>'tree', -default=>$tree)]}
<input type=hidden name=machine_id value='$machine_id'>
<input type=hidden name=build_time value='$build_time'>
<p>
^;
if (!$login) {
  print login_fields(), "<br>\n";;
} else {
  print "<strong>Email:</strong> " . $login . "<br>\n";
}

# find current causes.
my $fields = $dbh->selectall_arrayref(
  "SELECT value
     FROM tbox_build_field
    WHERE machine_id = ?
      AND build_time = " . Tinderbox3::DB::sql_abstime("?") . "
      AND name = 'cause'
  ", undef, $machine_id, $build_time);
my $cause = "";
foreach my $field (@{$fields}) {
  $cause .= ";\n" if $cause ne "";
  $cause .= $field->[0];
}

# if no causes, get failed field names.
if ($cause eq "") {
  my $fields = $dbh->selectall_arrayref(
    "SELECT name
       FROM tbox_build_field
      WHERE machine_id = ?
        AND build_time = " . Tinderbox3::DB::sql_abstime("?") . "
        AND value = 'fail'
    ", undef, $machine_id, $build_time);
  foreach my $field (@{$fields}) {
    $cause .= "\n" if $cause ne "";
    $cause .= $field->[0] . '=;';
  }
}

# use the machine name otherwise.
if ($cause eq "") {
   $cause = "$machine_name=;";
}

print "<textarea name=cause rows=10 cols=30>$cause</textarea><br>\n";
print "<input type=submit>\n</p>\n";

print "</form>\n";

footer($p);
$dbh->disconnect;
