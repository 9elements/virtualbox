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
#    InnoTek
#
# ***** END LICENSE BLOCK *****

use strict;
use CGI;
use Tinderbox3::DB;
use Tinderbox3::ShowTests;

my $p = new CGI;
my $dbh = get_dbh();

my $tree = $p->param('tree') || "";

# Get the tree info
my $tree_info = $dbh->selectrow_arrayref("SELECT min_row_size, max_row_size, default_tinderbox_view FROM tbox_tree WHERE tree_name = ?", undef, $tree);
if (!defined($tree_info)) {
  die "Could not get tree! $(tree)";
}

my ($start_time, $end_time);
if ($p->param('start_time')) {
  $start_time = $p->param('start_time');
  if ($start_time > time) {
    $start_time = time;
  }
  $end_time = $start_time + ($p->param('interval') || ($tree_info->[2]*60));
  if ($end_time > time) {
    $end_time = time;
  }
} else {
  $end_time = time;
  $start_time = $end_time - ($p->param('interval') || ($tree_info->[2]*60));
}

my $min_row_size = $p->param('min_row_size') || ($tree_info->[0]);
my $max_row_size = $p->param('max_row_size') || ($tree_info->[1]);
my $all_builds   = $p->param('all_builds')   || 0;

print $p->header;
Tinderbox3::ShowTests::print_showtests($p, $dbh, *STDOUT, $tree, $start_time,
                                       $end_time, $min_row_size, $max_row_size, $all_builds);

$dbh->disconnect;
