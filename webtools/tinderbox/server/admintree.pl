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

use CGI;
use Tinderbox3::Header;
use Tinderbox3::DB;
use Tinderbox3::InitialValues;
use Tinderbox3::Login;
use Date::Format;
use POSIX;
use strict;

#
# Init
#
my $p = new CGI;
my $dbh = get_dbh();
my ($login, $cookie) = check_session($p, $dbh);

# For delete_machine
Tinderbox3::DB::update_machine_action($p, $dbh, $login);
# For delete_patch, stop_using_patch
Tinderbox3::DB::update_patch_action($p, $dbh, $login);
# For delete_bonsai
Tinderbox3::DB::update_bonsai_action($p, $dbh, $login);
# For edit_tree
my $tree = Tinderbox3::DB::update_tree_action($p, $dbh, $login);

#
# Get the tree info to fill in the fields
#
my $tree_info;
my %initial_machine_config;
if (!$tree) {
  $tree_info = [ $Tinderbox3::InitialValues::field_short_names,
                 $Tinderbox3::InitialValues::field_processors,
                 $Tinderbox3::InitialValues::statuses,
                 $Tinderbox3::InitialValues::min_row_size,
                 $Tinderbox3::InitialValues::max_row_size,
                 $Tinderbox3::InitialValues::default_tinderbox_view,
                 Tinderbox3::DB::sql_get_bool($Tinderbox3::InitialValues::new_machines_visible),
                 '',                    # 7: editors
                 'build_on_commit',     # 8: tree_type
                 '',                    # 9: cvs_co_date
                 ];
  %initial_machine_config = %Tinderbox3::InitialValues::initial_machine_config;
} else {
  $tree_info = $dbh->selectrow_arrayref(
    "SELECT field_short_names, field_processors, statuses, min_row_size, max_row_size, default_tinderbox_view, " .
    "       new_machines_visible, editors, tree_type, cvs_co_date " .
    "  FROM tbox_tree " .
    " WHERE tree_name = ?", undef, $tree);
  if (!defined($tree_info)) {
    die "Could not get tree!";
  }

  my $sth = $dbh->prepare("SELECT name, value FROM tbox_initial_machine_config WHERE tree_name = ?");
  $sth->execute($tree);
  while (my $row = $sth->fetchrow_arrayref) {
    $initial_machine_config{$row->[0]} = $row->[1];
  }
}
my $is_build_new_patch = $tree_info->[8] eq 'build_new_patch';

#
# Edit / Add tree form
#
header($p, $login, $cookie, ($tree ? "Edit $tree" : "Add Tree"), $tree);

# This would be nice, but it's too much work to parse results.
#<tr><th>Tree type</th><td><select name=tree_type>
#  <option value=build_on_commit@{[$tree_info->[8] = 'build_on_commit' ? ' selected' : '']}>Build on commit</option>
#  <option value=build_new_patch@{[$tree_info->[8] = 'build_new_patch' ? ' selected' : '']}>Build new patch</option>
#</select></td></tr>

# Calc the number of lines needed to show the field_processors.
my @aFieldProcs = split /^/, $tree_info->[1];
my $rows = @aFieldProcs;
foreach my $line (@aFieldProcs) {
    $rows += ceil(length($line) / 83) - 1;
}
if ($rows == 0) {
    $rows = 1;
}

print <<EOM;
<form name=editform method=get action='admintree.pl'>
<input type=hidden name=action value='edit_tree'>
@{[$p->hidden(-name=>'tree', -default=>$tree, -override=>1)]}
<table>
<tr><th>Tree Name (this is the name used to identify the tree):</th><td>@{[$p->textfield(-name=>'tree_name', -default=>$tree)]}</td></tr>
<tr><th>Status Short Names (bloat=Bl,pageload=Tp...)</th><td>@{[$p->textfield(-name=>'field_short_names', -default=>$tree_info->[0], -size=>80)]}</td></tr>
<tr><th>Status Handlers (bloat=Graph,binary_url=URL...)</th><td>@{[$p->textarea(-name=>'field_processors', -default=>$tree_info->[1], -columns=>83, -rows=>$rows)]}</td></tr>
<tr><th>Tree Statuses (open,closed...)</th><td>@{[$p->textfield(-name=>'statuses', -default=>$tree_info->[2], -size=>80)]}</td></tr>
<tr><th>Min Row Size (minutes)</th><td>@{[$p->textfield(-name=>'min_row_size', -default=>$tree_info->[3])]}</td></tr>
<tr><th>Max Row Size (minutes)</th><td>@{[$p->textfield(-name=>'max_row_size', -default=>$tree_info->[4])]}</td></tr>
<tr><th>Tinderbox Page Size (minutes)</th><td>@{[$p->textfield(-name=>'default_tinderbox_view', -default=>$tree_info->[5])]}</td></tr>
<tr><th>New Machines Visible By Default?</th><td><input type=checkbox name=new_machines_visible@{[$tree_info->[6] ? ' checked' : '']}></td></tr>
<tr><th>Editor Privileges (logins)</th><td>@{[$p->textfield(-name=>'editors', -default=>$tree_info->[7])]}</td></tr>
<tr><th>Build patch-by-patch?</th><td><input type=checkbox name=patch_by_patch@{[$is_build_new_patch ? ' checked' : '']}></td></tr>
<tr><th>Checkout date / revision (r12345)</th><td>@{[$p->textfield(-name=>'cvs_co_date', -default=>$tree_info->[9])]}</td></tr>
</table>
<p><strong>Initial LocalConfig.kmk:</strong><br>
<input type=hidden name=initial_machine_config0 value=mozconfig>
EOM

$rows = ($initial_machine_config{mozconfig} =~ tr/\n//) + 3;
$rows = $rows <= 6 ? 6 : $rows > 32 ? 32 : $rows;
print $p->textarea(-name=>'initial_machine_config0_val', -default=>$initial_machine_config{mozconfig},
                   -rows=>$rows, -columns => 130);
print "</p>\n";


print "<p><strong>Initial Machine Config</strong> (empty a line to delete it):<br>";
print "<table><tr><th>Variable</th><th>Value</th></tr>\n";
my $config_num = 1;
foreach my $var (sort keys %initial_machine_config) {
  my $value = $initial_machine_config{$var};
  if ($var ne "mozconfig") {
    print "<tr><td>", $p->textfield(-name=>"initial_machine_config$config_num", -default=>$var, -override=>1), "</td>";
    print "<td>", $p->textfield(-name=>"initial_machine_config${config_num}_val", -default=>$value, -override=>1, -size=>42), "</td></tr>\n";
    $config_num++;
  }
}
foreach my $i ($config_num..($config_num <= 5 ? 8 : $config_num + 2)) {
    print "<tr><td>", $p->textfield(-name=>"initial_machine_config$i", -override=>1), "</td>";
    print "<td>", $p->textfield(-name=>"initial_machine_config${i}_val", -override=>1, -size=>42), "</td></tr>\n";
}
print "</table></p>\n";

if (!$login) {
  print login_fields();
}

print <<EOM;
<input type=submit>
</form>
EOM

#
# If it's not new, have a list of patches and machines
#
if ($tree) {
  # Patch list
  print "<table class=editlist><tr><th>Patches</th></tr>\n";

  my $sth = $dbh->prepare('SELECT patch_id, patch_name, in_use, submitter, ' . Tinderbox3::DB::sql_get_timestamp('submit_time') . ' ' .
                          '  FROM tbox_patch ' .
                          ' WHERE tree_name = ? ' .
                          (!$is_build_new_patch ? ' ORDER BY patch_name' : ' ORDER BY patch_id DESC LIMIT 1024') );
  $sth->execute($tree);
  while (my $patch_info = $sth->fetchrow_arrayref) {
    my ($patch_class, $action, $action_name);
    if ($patch_info->[2]) {
      $patch_class = "";
      $action = "stop_using_patch";
      $action_name = "Obsolete";
    } else {
      $patch_class = " class=obsolete";
      $action = "start_using_patch";
      $action_name = "Resurrect";
    }
    print "<tr>";
    if ($is_build_new_patch) {
      my $submit_time_formatted = time2str("%D %R", $patch_info->[4]);
      print "<td>$submit_time_formatted</td><td>$patch_info->[3]</td>";
    }
    print "<td><a href='adminpatch.pl?patch_id=$patch_info->[0]'$patch_class>$patch_info->[1]</a>";
    if (!$is_build_new_patch) {
      print " (<a href='admintree.pl?tree=$tree&action=delete_patch&patch_id=$patch_info->[0]'>Del</a> |";
      print "<a href='admintree.pl?tree=$tree&action=$action&patch_id=$patch_info->[0]'>$action_name</a>)";
    } elsif ($patch_info->[2]) {
      print "(<a href='admintree.pl?tree=$tree&action=$action&patch_id=$patch_info->[0]'>$action_name</a>)";
    }
    print "</td></tr>\n";
  }
  print "<tr><td><a href='uploadpatch.pl?tree=$tree'>Upload Patch</a></td></tr>\n";
  print "</table>\n";

  # Machine list
  print "<table class=editlist>\n";
  print "<tr><th colspan=3>Machines</th></tr>\n";
  print "<tr><th>Name</th><th>Script Rev</th><th>Description</th></tr>\n";
  $sth = $dbh->prepare(
    "SELECT machine_id, machine_name, visible, description, script_rev
       FROM tbox_machine
      WHERE tree_name = ?
      ORDER BY script_rev DESC NULLS LAST, machine_name");
  $sth->execute($tree);
  while (my $machine_info = $sth->fetchrow_arrayref) {
    print "<tr><td><a href='adminmachine.pl?tree=$tree&machine_id=$machine_info->[0]'>$machine_info->[1]</a></td>";
    print "<td>".$p->escapeHTML($machine_info->[4])."</td>";
    print "<td>".($machine_info->[2] ? '' : '(invisible) ').$p->escapeHTML($machine_info->[3])."</td></tr>\n";
  }
  # XXX Add this feature in if you decide not to automatically allow machines
  # into the federation
  # print "<tr><td><a href='adminmachine.pl?tree=$tree'>New Machine</a></td></tr>\n";
  print "</table>\n";

  # Machine list
  print "<table class=editlist><tr><th>Bonsai Monitors</th></tr>\n";
  $sth = $dbh->prepare('SELECT bonsai_id, display_name FROM tbox_bonsai WHERE tree_name = ? ORDER BY display_name');
  $sth->execute($tree);
  while (my $bonsai_info = $sth->fetchrow_arrayref) {
    print "<tr><td><a href='adminbonsai.pl?tree=$tree&bonsai_id=$bonsai_info->[0]'>$bonsai_info->[1]</a> (<a href='admintree.pl?tree=$tree&action=delete_bonsai&bonsai_id=$bonsai_info->[0]'>Del</a>)</td>\n";
  }
  print "<tr><td><a href='adminbonsai.pl?tree=$tree'>New Bonsai</a></td></tr>\n";
  print "</table>\n";
}


footer($p);
$dbh->disconnect;
