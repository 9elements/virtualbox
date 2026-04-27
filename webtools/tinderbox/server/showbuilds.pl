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
#
# ***** END LICENSE BLOCK *****

use strict;
use CGI;
use DateTime::Format::DateParse;        # debian: libdatetime-format-dateparse-perl
use Scalar::Util qw(looks_like_number); # debian: libscalar-util-numeric-perl
use Tinderbox3::DB;
use Tinderbox3::ShowBuilds;
use Tinderbox3::Util qw(get_id_array_param);
use Time::HiRes;

my $load_time = Time::HiRes::time;
my $p = new CGI;
my $dbh = get_dbh();

my $tree = $p->param('tree') || "";

# Get the tree info
my $tree_info = $dbh->selectrow_arrayref("SELECT min_row_size, max_row_size, default_tinderbox_view FROM tbox_tree WHERE tree_name = ?", undef, $tree);
if (!defined($tree_info)) {
  die "Could not get tree! $(tree)";
}

my $interval = $p->param('interval') || ($tree_info->[2]*60);
my ($start_time, $end_time);
if ($p->param('start_time')) {
  $start_time = $p->param('start_time');
  if (!looks_like_number($start_time)) # If not a number, then an ISO date giving end_time.
  {
      my $dt = DateTime::Format::DateParse->parse_datetime($start_time);
      $start_time = $dt->epoch() - $interval;
  } elsif (substr($start_time, 0, 1) eq '-') { # If '-', them it's relative end_time.
      $start_time = time + $start_time - $interval;
  }
  if ($start_time > time) {
    $start_time = time;
  }
  $end_time = $start_time + $interval;
  if ($end_time > time) {
    $end_time = time;
  }
} else {
  $end_time = time;
  $start_time = $end_time - $interval;
}

my $min_row_size = $p->param('min_row_size') || ($tree_info->[0]);
my $max_row_size = $p->param('max_row_size') || ($tree_info->[1]);

my $style = $p->param('style') || 'brief';
if ($style ne 'full' && $style ne 'brief' && $style ne 'pivot') {
  $style = 'brief';
}

my @include_ids = get_id_array_param($p, 'show');
my @exclude_ids = get_id_array_param($p, 'hide');
my @status_filter = get_id_array_param($p, 'sts');

print $p->header;
Tinderbox3::ShowBuilds::print_showbuilds($p, $dbh, *STDOUT, $tree,
                                         $start_time, $end_time, $interval, $min_row_size, $max_row_size,
                                         $style, $load_time, \@include_ids, \@exclude_ids, \@status_filter, 0);

$dbh->disconnect;
