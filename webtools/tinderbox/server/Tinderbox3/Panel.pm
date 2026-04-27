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

package Tinderbox3::Panel;

use strict;
use Date::Format;
use Tinderbox3::Header;


sub print_showpanel {
  my ($p, $dbh, $fh, $tree) = @_;

  #
  # Get tree and patch info
  #
  my $tree_info = $dbh->selectrow_arrayref("SELECT special_message, status FROM tbox_tree WHERE tree_name = ?", undef, $tree);
  if (!$tree_info) {
    die "Tree $tree does not exist!";
  }
  my ($special_message, $status) = @{$tree_info};

  #
  # Header.
  #
  my $time = time2str("%c&nbsp;%Z", time);
  print $fh <<EOF;
<head>
<META HTTP-EQUIV="Refresh" CONTENT="300">
<style>
body, td {
  font-family: Verdana, Sans-Serif;
  font-size: 8pt;
}
.status0,.status1,.status2 {
  background-color: yellow
}
.status100,.status101,.status102,.status103 {
  background-color: lightgreen
}
th.status200,th.status201,th.status202,th.status203 {
  background: url("1afi003r.gif");
  background-color: black;
  color: white
}
th.status200 a,th.status201 a,th.status202 a,th.status203 a {
  color: white
}
.status200,.status201,.status202,.status203 {
  background-color: red
}
.status300,.status301,.status302,.status303 {
  background-color: lightgray
}
</style>
</head>
<body BGCOLOR="#FFFFFF" TEXT="#000000" LINK="#0000EE" VLINK="#551A8B" ALINK="#FF0000">
<a target="_content" href="showbuilds.pl?tree=$tree">
$tree is $status, $time</a><br>

<table border=0 cellpadding=1 cellspacing=1>
EOF

  #
  # The tinder boxes.
  #
  my $sth = $dbh->prepare(
    "SELECT DISTINCT ON (b.machine_id) b.machine_id, b.status, t.machine_name, t.os, t.os_version, t.clobber
       FROM tbox_build b,
            tbox_machine t
      WHERE b.machine_id = t.machine_id
        AND t.visible
        AND b.status BETWEEN 100 AND 300
     ORDER BY b.machine_id, b.build_time DESC");
  $sth->execute();

  my %columns;
  while (my $row = $sth->fetchrow_arrayref) {
     my $status = $row->[1];
     my $machine = $row->[2];
     my $os = $row->[3];
     my $os_version = $row->[4];
     my $type = $row->[4] ? "Clobber" : "Depend";
     print $fh
        "<tr><td class=\"status$status\">$machine $os $os_version $type</td></tr>\n";
  }

  #
  # Footer.
  #
  print $fh
        "</table></body>";
}

1
