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
use File::Temp qw(tempfile);

my $p = new CGI();
my $dbh = get_dbh();

$SIG{__DIE__} = sub { die_xml_error($p, $dbh, $_[0]); };

#
# Retrieve, validate and launder parameters.
#
my $tainted_tree = $p->param('tree') || "";
if (!$tainted_tree) {
  die_xml_error($p, $dbh, "Must specify tree!");
}
my $tree;
if ($tainted_tree =~ /^([a-zA-Z0-9_.,\-]+)$/) {
  $tree = $1;
} else  {
  die_xml_error($p, $dbh, "Invalid tree name!");
}

my $tainted_machine_id = $p->param('machine_id') || "";
if (!$tainted_machine_id) {
  die_xml_error($p, $dbh, "Must specify a machine name!");
}
my $machine_id;
if ($tainted_machine_id =~ /(\d+)/) {
  $machine_id = $1;
} else {
  die_xml_error($p, $dbh, "Invalid machine id!");
}

my $tainted_status = $p->param('status');
if (!defined($tainted_status)) {
  die_xml_error($p, $dbh, "You really need to define a status.");
}
my $status;
if ($tainted_status =~ /^(\d+)$/) {
  $status = $1;
} else {
  die_xml_error($p, $dbh, "Invalid status.");
}

my $log_chunk_fh = $p->upload('log');

#
# Get data for response
#

#
# Validate and untaint the tree & machine id, while retriving the machine name
# and pending commands.
#
my $machine_info = $dbh->selectrow_arrayref("SELECT machine_name, commands, tree_name FROM tbox_machine WHERE tree_name = ? AND machine_id = ?", undef, $tree, $machine_id);
if (!defined($machine_info)) {
  die_xml_error($p, $dbh, "No such machine!");
}
my ($machine_name, $commands, $tree_name) = @{$machine_info};
$commands ||= "";

#
# Update build info
#
my $build_info = $dbh->selectrow_arrayref("SELECT build_time, log FROM tbox_build WHERE machine_id = ? ORDER BY build_time DESC LIMIT 1", undef, $machine_id);
if (!defined($build_info)) {
  die_xml_error("No build time");
}
my ($build_time, $log) = @{$build_info};
$log =~ /(.+)/;
$log = $1;

my $done = $dbh->do("UPDATE tbox_build SET status_time = " . Tinderbox3::DB::sql_current_timestamp() . ", status = ? WHERE machine_id = ? AND build_time = ?", undef, $status, $machine_id, $build_time);

#
# Update fields
#
my $insert_sth = $dbh->prepare("INSERT INTO tbox_build_field (machine_id, build_time, name, value) VALUES (?, ?, ?, ?)");
foreach my $param ($p->param()) {
  if ($param =~ /^field_(\d+)$/) {
    my $field = $p->param("field_$1");
    my $field_val = $p->param("field_$1_val");
    $insert_sth->execute($machine_id, $build_time, $field, $field_val);
  }
}

#
# Clear commands
#
if ($commands) {
  $dbh->do("UPDATE tbox_machine SET commands = '' WHERE machine_id = ?", undef, $machine_id);
}

Tinderbox3::DB::maybe_commit($dbh);

#
# Update logfile
#
if ($log_chunk_fh) {
  my $log_in_fh;
  if ($p->param('log_compressed')) {
    # XXX this is a very roundabout way of uncompressing the incoming logfile
    my ($fh, $filename) = tempfile(SUFFIX => '.gz');
    while (<$log_chunk_fh>) {
      print $fh $_;
    }
    close $fh;
    system("gzip", "-d", $filename);
    $filename =~ s/\.gz$//g;
    open $log_in_fh, $filename;
  } else {
    $log_in_fh = $log_chunk_fh;
  }

  if (!$log) {
    die_xml_error($p, $dbh, "No log exists!");
  }
  my $log_fh = get_log_fh($machine_id, $log, ">>");
  while (<$log_in_fh>) {
    print $log_fh $_;
  }
  close $log_in_fh;
  close $log_fh;
}

#
# Print response
#
print $p->header("text/xml");
print "<response>\n";
print "<machine id='$machine_id'>\n";
print "<commands>", $p->escapeHTML($commands), "</commands>\n";
print "</machine>\n";
print "</response>\n";

#
# Notify the testmanager about successful builds.
#
if ($status == 100) {
  my $skip_info = $dbh->selectcol_arrayref("SELECT 1 " .
                                           "  FROM tbox_build_field " .
                                           " WHERE machine_id = ? " .
                                           "   AND build_time = ? " .
                                           "   AND name = 'compile_only' " .
                                           "   AND value <> '' " .
                                           "   AND value <> '0' ",
                                           undef, $machine_id, $build_time);
  if (!defined($skip_info) || scalar(@{$skip_info}) == 0) {
    my $tag_info = $dbh->selectcol_arrayref("SELECT value " .
                                            "  FROM tbox_build_field " .
                                            " WHERE machine_id = ? " .
                                            "   AND build_time = ? " .
                                            "   AND name = 'build_tag' " .
                                            " ORDER BY value DESC ",
                                            undef, $machine_id, $build_time);
    Tinderbox3::TestManagerInterface::add_build($dbh, $tree_name, $machine_id, $machine_name, $build_time, $log,
                                                defined($tag_info) && scalar(@{$tag_info}) > 0 ? $tag_info->[0] : "");
  }
}

$dbh->disconnect;

