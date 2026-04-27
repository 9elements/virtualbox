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

our $p = new CGI();
our $dbh = get_dbh();

$SIG{__DIE__} = sub { die_xml_error($p, $dbh, $_[0]); };

my $tree = $p->param('tree') || "";
if (!$tree) {
  die_xml_error($p, $dbh, "Must specify tree!");
}
my $machine_name = $p->param('machine_name') || "";
if (!$machine_name) {
  die_xml_error($p, $dbh, "Must specify a machine name!");
}
my $os = $p->param('os') || "";
my $os_version = $p->param('os_version') || "";
my $compiler = $p->param('compiler') || "";
my $status = $p->param('status') || 0;
my $clobber = $p->param('clobber') || 0;
my $script_rev = $p->param('script_rev');
if (!$script_rev || !($script_rev =~ /^\d+$/) || $script_rev <= 0) {
  $script_rev = undef;
}


#
# Get data for response
#
my $tree_info = $dbh->selectrow_arrayref("SELECT new_machines_visible, tree_type, cvs_co_date FROM tbox_tree WHERE tree_name = ?",
                                         undef, $tree);
if (!defined($tree_info)) {
  die_xml_error($p, $dbh, "Could not get tree!");
}
my ($new_machines_visible, $tree_type, $cvs_co_date) = @{$tree_info};

#
# Insert the machine into the machines table if it is not there
#
##bird## my $machine_info = $dbh->selectrow_arrayref("SELECT machine_id, commands FROM tbox_machine WHERE tree_name = ? AND machine_name = ? AND os = ? AND os_version = ? AND compiler = ?", undef, $tree, $machine_name, $os, $os_version, $compiler);
my $machine_info = $dbh->selectrow_arrayref("SELECT machine_id, commands, last_patch_id, script_rev FROM tbox_machine " .
                                            " WHERE tree_name = ? AND machine_name = ? AND os = ?",
                                            undef, $tree, $machine_name, $os);
if (!defined($machine_info)) {
  $dbh->do("INSERT INTO tbox_machine (tree_name, machine_name, visible, os, os_version, compiler, clobber, script_rev) " .
           "     VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
           undef, $tree, $machine_name, $new_machines_visible, $os, $os_version, $compiler, Tinderbox3::DB::sql_get_bool($clobber), $script_rev);
  $machine_info = [ Tinderbox3::DB::sql_get_last_id($dbh, 'tbox_machine_machine_id_seq'), "" ]
} else {
  $script_rev ||= $machine_info->[3];
  $dbh->do("UPDATE tbox_machine SET clobber = ?, os_version = ?, compiler = ?, script_rev = ? WHERE machine_id = ?",
           undef, Tinderbox3::DB::sql_get_bool($clobber), $os_version, $compiler, $script_rev, $machine_info->[0]);
}
my ($machine_id, $commands, $last_patch_id) = @{$machine_info};
$commands ||= "";

$machine_id =~ /(\d+)/;
$machine_id = $1;

#
# Get patches.
#
my $patch_ids;
my $build_tag = "";
my $compile_only = 0;
if ($tree_type eq 'build_new_patch') {
  if (!defined($last_patch_id)) {
    # If last_patch_id is NULL (machine just created or tree switched mode), get the last submitted patch.
    $patch_ids = $dbh->selectcol_arrayref("SELECT MAX(patch_id) " .
                                          "  FROM tbox_patch " .
                                          " WHERE tree_name = ? " .
                                          "   AND in_use ",
                                          undef, $tree);

  } else {
    # Get the next patch after last_patch_id.
    $patch_ids = $dbh->selectcol_arrayref("SELECT MIN(patch_id) " .
                                          "  FROM tbox_patch " .
                                          " WHERE tree_name = ? " .
                                          "   AND patch_id > ? " .
                                          "   AND in_use ",
                                          undef, $tree, $last_patch_id);
  }
  if (!$patch_ids) {
    die_xml_error($p, $dbh, "Could not get patches!");
  }
  if (scalar(@$patch_ids) == 1 && defined($patch_ids->[0])) {
    # Calc build tag and update last_patch_id.
    my $patch_info = $dbh->selectrow_arrayref("SELECT submitter, patch_name, compile_only " .
                                              "  FROM tbox_patch " .
                                              " WHERE patch_id = ? ",
                                              undef, $patch_ids->[0]);
    if (!defined($patch_info)) {
        die_xml_error($p, $dbh, "Could not get patch info! (".$patch_ids->[0].')');
    }
    $build_tag = $patch_ids->[0] . "-" . $patch_info->[0] . "-" . $patch_info->[1];
    $compile_only = $patch_info->[2] ne '0';

    $dbh->do("UPDATE tbox_machine SET last_patch_id = ? WHERE machine_id = ?", undef, $patch_ids->[0], $machine_info->[0]);
  } elsif (scalar(@$patch_ids) > 1) {
    die_xml_error($p, $dbh, "wtf? expected 1 or 0 rows returned from scalar tbox_patch select!");
  }
} else {
  $patch_ids = $dbh->selectcol_arrayref("SELECT patch_id FROM tbox_patch WHERE tree_name = ? AND in_use", undef, $tree);
  if (!$patch_ids) {
    die_xml_error($p, $dbh, "Could not get patches!");
  }
}

#
# Get the machine config
#
my %machine_config;
my $sth = $dbh->prepare("SELECT name, value FROM tbox_initial_machine_config WHERE tree_name = ?");
$sth->execute($tree);
while (my $row = $sth->fetchrow_arrayref()) {
  $machine_config{$row->[0]} = $row->[1];
}
$sth = $dbh->prepare("SELECT name, value FROM tbox_machine_config WHERE machine_id = ?");
$sth->execute($machine_id);
while (my $row = $sth->fetchrow_arrayref()) {
  $machine_config{$row->[0]} = $row->[1];
}

{
  #
  # Close the last old build info if there is one and it was incomplete
  #
  my $last_build = $dbh->selectrow_arrayref("SELECT status, build_time, log FROM tbox_build WHERE machine_id = ? ORDER BY build_time DESC LIMIT 1", undef, $machine_id);
  if (defined($last_build) && $last_build->[0] >= 0 &&
      $last_build->[0] < 100) {
    my $rows = $dbh->do("UPDATE tbox_build SET status = ? WHERE machine_id = ? AND build_time = ?", undef, $last_build->[0] + 300, $machine_id, $last_build->[1]);
    # We have to compress the log too, be a good citizen
    compress_log($machine_id, $last_build->[2]);
  }

  # Create logfile
  my $log = create_logfile_name($machine_id);
  my $fh = get_log_fh($machine_id, $log, ">");
  close $fh;

  #
  # Insert a new build info signifying that the build has started
  #
  my $timestamp = Tinderbox3::DB::sql_current_timestamp();
  $dbh->do("INSERT INTO tbox_build (machine_id, build_time, status_time, status, log) VALUES (?, $timestamp, $timestamp, ?, ?)", undef, $machine_id, $status, $log);
}

#
# If there are commands, we have delivered them.  Set to blank.
#
if ($commands) {
  $dbh->do("UPDATE tbox_machine SET commands = '' WHERE machine_id = $machine_id");
}

Tinderbox3::DB::maybe_commit($dbh);

#
# Print response
#
print $p->header("text/xml");
print "<response>\n";
print "<tree name='$tree'>\n";
if ($tree_type ne 'build_on_commit') {
  print "<tree_type>", $p->escapeHTML($tree_type), "</tree_type>\n";
}
foreach my $patch_id (@{$patch_ids}) {
  print "<patch id='$patch_id'/>\n";
}
if ($build_tag ne "") {
  print "<build_tag>", $p->escapeHTML($build_tag), "</build_tag>\n";
}
if (defined($cvs_co_date) && $cvs_co_date ne "") {
  print "<cvs_co_date>", $p->escapeHTML($cvs_co_date), "</cvs_co_date>\n";
}
if ($compile_only) {
  print "<compile_only>1</compile_only>\n";
}
print "</tree>\n";
print "<machine id='$machine_info->[0]'>\n";
print "<commands>", $p->escapeHTML($commands), "</commands>\n";
while (my ($var, $val) = each %machine_config) {
  print "<$var>", $p->escapeHTML($val), "</$var>\n";
}
print "</machine>\n";
print "</response>\n";

$dbh->disconnect;
