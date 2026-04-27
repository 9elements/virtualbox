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
use Tinderbox3::Login;
use strict;
require Algorithm::Diff;

#
# Init
#
my $p = new CGI;
my $dbh = get_dbh();
my ($login, $cookie) = check_session($p, $dbh);

my $tree = $p->param('tree') || "";

# For edit_machine
my $machine_id = Tinderbox3::DB::update_machine_action($p, $dbh, $login);

# Redirect after edit or kicking (still needed with 'post'?).
if ($machine_id ne "") {
  my $action = $p->param('action') || "";
  if (   $action eq "edit_machine"
      || $action eq "kick_machine") {
      print $p->redirect(-location => "adminmachine.pl?machine_id=$machine_id", -status=>"303 See Other");
      $dbh->disconnect;
      exit;
  }
}

# Get patch from DB
my $machine_info = $dbh->selectrow_arrayref("
  SELECT tree_name, machine_name, os, os_version, compiler,
         clobber, commands, visible, last_patch_id, description, script_rev
  FROM   tbox_machine
  WHERE  machine_id = ?", undef, $machine_id);
if (!defined($machine_info)) {
  die "Could not get machine!";
}
my ($machine_name, $os, $os_version, $compiler, $clobber, $commands, $visible, $last_patch_id, $description, $script_rev);
($tree, $machine_name, $os, $os_version, $compiler, $clobber, $commands, $visible, $last_patch_id, $description, $script_rev) = @{$machine_info};

my %machine_config;
my $sth = $dbh->prepare("SELECT name, value FROM tbox_machine_config WHERE machine_id = ? ORDER BY name");
$sth->execute($machine_id);
while (my $row = $sth->fetchrow_arrayref) {
  $machine_config{$row->[0]} = $row->[1];
}

header($p, $login, $cookie, "Edit Machine $machine_name", $tree, $machine_id, $machine_name);

#
# Edit patch form
#

## @todo display last patch id
print <<EOM;
<form name=editform method=post action='adminmachine.pl?machine_id=$machine_id'>
<input type=hidden name=action value='edit_machine'>
@{[$p->hidden(-name=>'tree', -default=>$tree)]}
@{[$p->hidden(-name=>'machine_id', -default=>$machine_id)]}
<table>
<tr><th>Machine Name:</th><td>@{[$p->escapeHTML($machine_name)]}</td></tr>
<tr><th>OS:</th><td>@{[$p->escapeHTML("$os $os_version")]}</td></tr>
<tr><th>Compiler:</th><td>@{[$p->escapeHTML($compiler)]}</td></tr>
<tr><th>Clobber:</th><td>@{[$clobber ? 'Clobber' : 'Depend']}</td></tr>
<tr><th>tinderclient.pl rev:</th><td>@{[$script_rev ? "r" . $script_rev : "NA"]}</td></tr>
<tr><th>Commands</th><td>@{[$p->textfield(-name=>'commands', -default=>$commands)]}</td></tr>
<tr><th>Visible:</th><td><input type=checkbox name=visible@{[$visible ? " checked" : ""]}><td></tr>
<tr><th>Last Patch ID</th><td>@{[$p->textfield(-name=>'last_patch_id', -default=>$last_patch_id)]}</td></tr>
<tr><th>Description</th><td>@{[$p->textfield(-name=>'description', -default=>$description, -size=>'100')]}</td></tr>
</table>

<strong>LocalConfig.kmk:</strong><br>
<input type=hidden name=machine_config0 value=mozconfig>
EOM
my $rows = ($machine_config{mozconfig} =~ tr/\n//) + 6;
$rows = $rows <= 16 ? 16 : $rows > 28 ? 28 : $rows;
print $p->textarea(-name=>'machine_config0_val', -default=>$machine_config{mozconfig}, -rows=>$rows,
                   -columns=>130);
print "<br>\n";


print "<p><strong>Machine Config</strong> (empty a line to use default for tree):<br>";
print "<table><tr><th>Variable</th><th>Value</th></tr>\n";
my $config_num = 1;
foreach my $var (sort keys %machine_config) {
  my $value = $machine_config{$var};
  if ($var ne "mozconfig") {
    print "<tr><td>", $p->textfield(-name=>"machine_config$config_num", -default=>$var, -override=>1), "</td>";
    print "<td>", $p->textfield(-name=>"machine_config${config_num}_val", -default=>$value, -override=>1, -size=>42), "</td></tr>\n";
    $config_num++;
  }
}
foreach my $i ($config_num..($config_num <= 5 ? 8 : $config_num + 1)) {
    print "<tr><td>", $p->textfield(-name=>"machine_config$i", -override=>1), "</td>";
    print "<td>", $p->textfield(-name=>"machine_config${i}_val", -override=>1, -size=>42), "</td></tr>\n";
}
print "</table></p>\n";

if (!$login) {
  print login_fields();
}

print <<EOM;
<input type=submit>
</form>
<br>
<hr>
<form action='admintree.pl'>@{[$p->hidden(-name => 'tree', -default => $tree, -override => 1)]}@{[$p->hidden(-name => 'action', -default => 'delete_machine', -override => 1)]}@{[$p->hidden(-name => 'machine_id', -default => $machine_id, -override => 1)]}<input type=submit value='DELETE this machine and ALL logs associated with it' onclick='return confirm("Dude.  Seriously, this will wipe out all the logs and fields and everything associated with this machine.  Think hard here.\\n\\nDo you really want to do this?")'>
</form>
EOM

# some history
print <<EOM;
<hr>
<table class="history">
  <tr><th colspan=3>History</th></tr>
  <tr><th>When</th><th>Who</th><th>Changes</th></tr>
EOM

sub diff_row_fields {
  my ($i, $new_row, $old_row, $names) = @_;
  for (; $i < scalar @$names; $i += 1) {
    if (!defined($new_row->[$i]) && !defined($old_row->[$i])) {
        # match, both are NULL.
    } elsif (   !defined($new_row->[$i])
             || !defined($old_row->[$i])
             || "$new_row->[$i]" ne "$old_row->[$i]") {
      print("<li>$names->[$i]" . ": <tt>$new_row->[$i]</tt> (was: $old_row->[$i])\n");
    }
  }
}

sub print_string_diff {
  my ($old, $new) = @_;
  my @old = split(/\n/, $old);
  my @new = split(/\n/, $new);
  my $diff = Algorithm::Diff->new(\@old, \@new);
  $diff->Base(1);
  while ($diff->Next()) {
    if (!$diff->Same()) {
      my $fSep = 0;
      if(!$diff->Items(2)) {
        printf "%d,%dd%d\n", $diff->Get(qw( Min1 Max1 Max2 ));
      } elsif(  ! $diff->Items(1)  ) {
        printf "%da%d,%d\n", $diff->Get(qw( Max1 Min2 Max2 ));
      } else {
        printf "%d,%dc%d,%d\n", $diff->Get(qw( Min1 Max1 Min2 Max2 ));
        $fSep = 1;
      }
      print "< $_"   for  $diff->Items(1);
      print("---\n") if $fSep;
      print "> $_"   for  $diff->Items(2);
    }
  }
}

sub format_field_value {
  my ($value) = @_;
  if ($value =~ /\n/) {
    return "<br><pre class='history history-mozconfig'>$value</pre>\n";
  } else {
    return "<tt class='history-value'>$value</tt>";
  }
}

sub diff_arrays {
  my ($new_names, $new_values, $old_names, $old_values) = @_;
  my $iNew = 0;
  my $iOld = 0;
  while ($iNew < scalar @$new_names && $iOld < scalar @$old_names) {
    if ($new_names->[$iNew] eq $old_names->[$iOld]) {
      if ($new_values->[$iNew] ne $old_values->[$iOld]) {
        if ($new_names->[$iNew] eq "moz_config") {
          print("<li class='history history-mozconfig'>" . $new_names->[$iNew]
                . ":<br>\n<pre class='history history-mozconfig history-diff '>");
          print_string_diff($old_values->[$iOld], $new_values->[$iNew]);
          print("</pre>");
          print("<span type=button class='accordion'>Show new in full</span>\n" .
                "<pre class='history history-mozconfig' style='display:none;'>" . $new_values->[$iNew] . "</div>\n");
        } else {
          print("<li class='history'>" . $new_names->[$iNew] . ": " . format_field_value($new_values->[$iNew]) .
                " (was: " . format_field_value($old_values->[$iOld]) . ")\n");
        }
      }
      $iNew += 1;
      $iOld += 1;
    } elsif (lc($new_names->[$iNew]) lt lc($old_names->[$iOld])) { # Case insenstive ordering by our postgresql DB.
      print("<li class='history history-new'>" . $new_names->[$iNew] . ": " . format_field_value($new_values->[$iNew]) . "</tt> (New!)\n");
      $iNew += 1;
    } else {
      print("<li class='history history-del'>" . $old_names->[$iOld] . ": Deleted! (was: " . format_field_value($old_values->[$iOld]) . ")\n");
      $iOld += 1;
    }
  }
  while ($iNew < scalar @$new_names) {
    print("<li class='history history-new'>" . $new_names->[$iNew] . ": <tt>" . format_field_value($new_values->[$iNew]) . "</tt> (New!)\n");
    $iNew += 1;
  }
  while ($iOld < scalar @$old_names) {
    print("<li class='history history-del'>" . $old_names->[$iOld] . ": Deleted! (was: " . format_field_value($old_values->[$iOld]) . ")\n");
    $iOld += 1;
  }
}


$sth = $dbh->prepare("
  SELECT changes.tsEffective, changes.sAuthor,
         tmh.sCommands, tmh.fVisible, tmh.idLastPatch, tmh.sDescription,
         tmh.sOpSys, tmh.sOsVersion, tmh.sCompiler, tmh.fClobber, tmh.iScriptRev,
         array_agg(tmch.sName  ORDER BY tmch.sName),
         array_agg(tmch.sValue ORDER BY tmch.sName)
    FROM ((SELECT DISTINCT tsEffective, sAuthor FROM tbox_machine_history WHERE idMachine = ? ORDER BY tsEffective DESC)
          UNION
          (SELECT DISTINCT tsEffective, sAuthor FROM tbox_machine_config_history WHERE idMachine = ? ORDER BY tsEffective DESC)
          UNION
          (SELECT DISTINCT tsExpire, sAuthorExp FROM tbox_machine_history WHERE idMachine = ? AND tsExpire < '9999-12-24' AND sAuthorExp IS NOT NULL ORDER BY tsExpire DESC)
          UNION
          (SELECT DISTINCT tsExpire, sAuthorExp FROM tbox_machine_config_history WHERE idMachine = ? AND tsExpire < '9999-12-24' AND sAuthorExp IS NOT NULL ORDER BY tsExpire DESC)
          ) AS changes (tsEffective, sAuthor)
    JOIN tbox_machine_history AS tmh
      ON     changes.tsEffective >= tmh.tsEffective
         AND changes.tsEffective <  tmh.tsExpire
         AND tmh.idMachine       =  ?
    LEFT JOIN tbox_machine_config_history AS tmch
      ON     changes.tsEffective >= tmch.tsEffective
         AND changes.tsEffective <  tmch.tsExpire
         AND tmch.idMachine      =  ?
    GROUP BY changes.tsEffective, changes.sAuthor,
             tmh.sCommands, tmh.fVisible, tmh.idLastPatch, tmh.sDescription,
             tmh.sOpSys, tmh.sOsVersion, tmh.sCompiler, tmh.fClobber, tmh.iScriptRev
    ORDER BY 1 DESC
    LIMIT ?
    OFFSET ?
    ");

my $hist_limit = $p->param('history_limit');
if (!defined($hist_limit) || $hist_limit !~ /^[0-9]+$/) {
  $hist_limit = 16;
} else {
  $hist_limit = $hist_limit + 0;
  $hist_limit = 16 if $hist_limit < 0;
  $hist_limit = 1024 if $hist_limit > 1024;
}

my $hist_offset = $p->param('history_offset');
if (!defined($hist_offset) || $hist_offset !~ /^[0-9]+$/) {
  $hist_offset = 0;
} else {
  $hist_offset = $hist_offset + 0;
  $hist_offset = 0 if $hist_offset < 0;
  $hist_offset = 16384 if $hist_offset > 16384;
}

$sth->execute($machine_id, $machine_id, $machine_id, $machine_id, $machine_id, $machine_id, $hist_limit, $hist_offset);
my @field_names = (undef, undef, 'Commands', 'Visible', 'Last Patch ID', 'Description',
                   'OS', 'OS Version', 'Compiler', 'Clobber', 'Script Revision');
my $data = $sth->fetchall_arrayref();
for (my $iRow = 0; $iRow < scalar @$data; $iRow += 1) {
  my $new_row = $data->[$iRow];
  print("  <tr>\n");
  print("    <td>" . $new_row->[0] . "</td><td>" . $new_row->[1] . "</td></td>\n");
  print("    <td>\n");
  if ($iRow + 1 >= scalar @$data)  {
      print("    ...\n");
  } else {
     print("    <ul>\n");
     my $old_row = $data->[$iRow + 1];
     diff_row_fields(2, $new_row, $old_row, \@field_names);
     diff_arrays($new_row->[11], $new_row->[12], $old_row->[11], $old_row->[12]);
     print("    </ul>\n");
  }
  print("    </td>\n");
  print("  </tr>\n");
}
print <<EOM;
</table>
EOM

print <<EOM;
<script>
/* hook all the accordion button elements */
var aElements = document.getElementsByClassName("accordion");
var i;
for (i = 0; i < aElements.length; i++) {
  aElements[i].addEventListener("click", function () {
    this.classList.toggle("active");
    this.nextElementSibling.style.display = this.nextElementSibling.style.display == "block" ? "none" : " block";
  });
}
</script>
EOM

footer($p);
$dbh->disconnect;
