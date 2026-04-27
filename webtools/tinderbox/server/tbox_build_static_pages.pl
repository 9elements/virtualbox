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
use Tinderbox3::DB;
use Tinderbox3::ShowBuilds;
use Tinderbox3::ShowTests;
use Time::HiRes;

my $tmpsuff=$$;

open INDEX_FILE, ">index.html.$tmpsuff";

print INDEX_FILE <<EOM;
<html>
<head>
<title>Tinderbox - Index</title>
</head>
<body>
<h2>Tinderbox - Index</h2>
<p><a href='admin.pl'>Administrate This Tinderbox</a></p>
<p>This Tinderbox has the following trees:</p>
<table>
EOM

#
# Create the actual tree static pages
#
my $p = new CGI;
my $dbh = get_dbh();
my @empty;

my $trees = $dbh->selectcol_arrayref("SELECT tree_name FROM tbox_tree ORDER BY tree_name");
foreach my $tree (@{$trees}) {
  # Get the tree info
  my $tree_info = $dbh->selectrow_arrayref("SELECT min_row_size, max_row_size, default_tinderbox_view FROM tbox_tree WHERE tree_name = ?", undef, $tree);
  if (!defined($tree_info)) {
    die "Could not get tree info! $tree";
  }

  my $min_row_size = $tree_info->[0];
  my $max_row_size = $tree_info->[1];
  my $end_time = time;
  my $interval = $tree_info->[2]*60;
  my $start_time = time - $interval;

  # style=full
  open OUTFILE, ">$tree.html.$tmpsuff";
  Tinderbox3::ShowBuilds::print_showbuilds($p, $dbh, *OUTFILE, $tree,
                                           $start_time, $end_time, $interval,
                                           $min_row_size, $max_row_size, 'full',
                                           Time::HiRes::time, \@empty, \@empty, \@empty, 1);
  close OUTFILE;
  rename("$tree.html.$tmpsuff", "$tree.html");

  # style=brief
  open OUTFILE, ">$tree-brief.html.$tmpsuff";
  Tinderbox3::ShowBuilds::print_showbuilds($p, $dbh, *OUTFILE, $tree,
                                           $start_time, $end_time, $interval,
                                           $min_row_size, $max_row_size, 'brief',
                                           Time::HiRes::time, \@empty, \@empty, \@empty, 1);
  close OUTFILE;
  rename("$tree-brief.html.$tmpsuff", "$tree-brief.html");

  # bird: This is no longer needed.
  ## InnoTek addition (showtests is new)
  #open OUTFILE, ">$tree-test.html.$tmpsuff";
  #Tinderbox3::ShowTests::print_showtests($p, $dbh, *OUTFILE, $tree,
  #                                       $start_time, $end_time,
  #                                       $min_row_size, $max_row_size);
  #close OUTFILE;
  #rename("$tree-test.html.$tmpsuff", "$tree-test.html");

  print INDEX_FILE "<tr>";
  print INDEX_FILE "<td><a href='$tree.html'>$tree</a> (<a href='showbuilds.pl?tree=$tree'>dynamic</a>)</td>";
  print INDEX_FILE "<td><a href='$tree-brief.html'>style:brief</a> (<a href='showbuilds.pl?tree=$tree&style=brief'>dynamic</a>)</td>";
  #print INDEX_FILE "(<a href='showbuilds.pl?tree=$tree'>dynamic</a> | <a href='showbuilds.pl?tree=$tree&style=brief'>brief</a>)<br>\n";
  print INDEX_FILE "</tr>";
}

print INDEX_FILE "</table></body>
</html>";
close INDEX_FILE;
rename("index.html.$tmpsuff", "index.html");

$dbh->disconnect;

