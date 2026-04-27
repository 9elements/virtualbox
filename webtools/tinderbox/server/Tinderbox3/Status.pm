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
# Knut St. Osmundsen (bird-mozilla@anduin.net)
# Portions created by the Initial Developer are Copyright (C) 2005
# the Initial Developer. All Rights Reserved.
#
# Contributor(s):
#
# ***** END LICENSE BLOCK *****

#
# The status stuff is for the mozdev/tinderstatus button like things.
#
package Tinderbox3::Status;

use strict;
use Date::Format;
use Tinderbox3::DB qw(sql_prepare sql_execute);

sub print_showstatus {
  my ($p, $dbh, $fh, $tree) = @_;

  #
  # Get tree status
  #
  my $tree_info = $dbh->selectrow_arrayref("SELECT status FROM tbox_tree WHERE tree_name = ?", undef, $tree);
  if (!$tree_info) {
    die "Tree $tree does not exist!";
  }
  my ($tree_status) = @{$tree_info};


  #
  # The tinder boxes.
  #
  my $sth = $dbh->prepare(
    "SELECT DISTINCT ON (b.machine_id) b.machine_id, b.status
       FROM tbox_build b,
            tbox_machine t
      WHERE b.machine_id = t.machine_id
        AND t.tree_name = ?
        AND t.visible
        AND b.status_time >= " . Tinderbox3::DB::sql_abstime(time - 24*60*60) . "
        AND b.build_time  >= " . Tinderbox3::DB::sql_abstime(time - 24*60*60) . "
        AND b.status BETWEEN 100 AND 300
     ORDER BY b.machine_id, b.build_time DESC");
  $sth->execute($tree);

  my $msg = "success";
  my $status = 100;
  while (my $row = $sth->fetchrow_arrayref) {
     my $rc = $row->[1];
     if ($rc >= 100 && $rc < 200 && $status >= 100 && $status < 200 && $rc > $status) {
        $status = $rc;
     }
     if ($rc >= 200 && $rc < 300 && (!($status >= 200 && $status < 300) || $rc < $status)) {
        $msg = "busted";
        $status = $rc;
     }
  }

  #
  # Print the message - all on one line!
  #
  print $fh <<EOF;
TREE=$tree_status MSG=$msg STATUS=$status
EOF

}

sub print_treestatus {
  my ($p, $dbh, $fh, $tree) = @_;

  #
  # Create tree list for the IN criteria.
  # @todo figure the right perl / postgres way to do this...
  #
  $tree =~ s/,/\',\'/g;
  my $in_trees = "\'$tree\'";

  #
  # Get the tree status.
  #
  my $sth = $dbh->prepare(
    "SELECT status,
            tree_name
       FROM tbox_tree
      WHERE tree_name IN ($in_trees)");
  $sth->execute();
#  sql_execute($sth);
  while (my $row = $sth->fetchrow_arrayref) {
    my ($tree_status, $tree_name) = @{$row};
    print $fh "State|$tree_name|$tree_name|$tree_status\n";

    #
    # Get status of the last complete build on each of the machines.
    #
    my $sth2 = $dbh->prepare(
      "SELECT DISTINCT ON (b.machine_id) b.machine_id,
              b.status,
              t.machine_name,
              t.os,
              t.clobber
         FROM tbox_build b,
              tbox_machine t
        WHERE t.tree_name = (?)
          AND t.visible
          AND b.machine_id = t.machine_id
          AND b.status_time >= " . Tinderbox3::DB::sql_abstime(time - 24*60*60) . "
          AND b.build_time  >= " . Tinderbox3::DB::sql_abstime(time - 24*60*60) . "
          AND b.status BETWEEN 100 AND 300
       ORDER BY b.machine_id, b.build_time DESC");
    $sth2->execute($tree_name);
#    sql_execute($sth2, $tree_name);

    while (my $row = $sth2->fetchrow_arrayref) {
       my ($machine_id, $status, $machine_name, $os, $clobber) = @{$row};
       my $state = "whut?";
       if ($status >= 100 && $status < 200) {
          $state = "success";
       }
       if ($status >= 200 && $status < 300) {
          $state = "busted";
       }

       my $clobber_str;
       if ($clobber) {
         $clobber_str = "Clobber";
       } else {
         $clobber_str = "Depend";
       }

       print $fh "Build|$tree_name|$machine_name $os $clobber_str|$state\n";
    }
  }
}

1
