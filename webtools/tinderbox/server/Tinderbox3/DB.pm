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

package Tinderbox3::DB;

use strict;
use DBI;
use Tinderbox3::InitialValues;
use Tinderbox3::Bonsai;
use Tinderbox3::Login;
use Tinderbox3::Log;
use Time::HiRes qw(gettimeofday tv_interval);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(get_dbh sql_current_timestamp sql_abstime sql_abstime_tz sql_get_last_id sql_get_timestamp sql_get_bool sql_prepare sql_execute);

our $high_exp_ts    = '9999-12-31 23:59:59+00'; # For setting.
our $highish_exp_ts = '9999-12-24 23:59:59+00'; # For comparing with (to avoid any kind of time zone issues)

# dbtype = mysql or Pg
our $dbtype = "Pg";
our $dbname = "tbox";
our $username = "";
our $password = "";
sub get_dbh {
  my $dbh = DBI->connect("dbi:$dbtype:dbname=$dbname", $username, $password, { RaiseError => 1 });
  return $dbh;
}

sub maybe_commit {
  my ($dbh) = @_;
  # $dbh->commit();
}

sub check_edit_tree {
  my ($login, $dbh, $tree, $action) = @_;
  my $row = $dbh->selectrow_arrayref("SELECT editors FROM tbox_tree WHERE tree_name = ?", undef, $tree);
  if (!can_edit_tree($login, $row->[0])) {
    die "$login: Insufficient privileges to $action (need edit tree)!";
  }
}

sub check_sheriff_tree {
  my ($login, $dbh, $tree, $action) = @_;
  my $row = $dbh->selectrow_arrayref("SELECT editors, sheriffs FROM tbox_tree WHERE tree_name = ?", undef, $tree);
  if (!can_sheriff_tree($login, $row->[0], $row->[1])) {
    die "$login: Insufficient privileges to $action (need sheriff tree)!";
  }
}

#
# Check if user is allowed to upload a patch.
# Returns submitter name.
#
sub check_upload_patch {
  my ($p, $login, $dbh, $tree, $is_build_new_patch_tree) = @_;
  if (!$is_build_new_patch_tree) {
    check_edit_tree($login, $dbh, $tree, "upload patch");
  } else {
    my $row = $dbh->selectrow_arrayref("SELECT editors, sheriffs FROM tbox_tree WHERE tree_name = ?", undef, $tree);
    if (!defined($login) || length($login) == 0 || !can_edit_patch($login, $row->[0], $row->[1], $dbh)) {
      die "$login: Insufficient privileges to upload patch!";
    }
  }
}

sub check_edit_patch {
  my ($login, $dbh, $patch_id, $is_build_new_patch_tree, $action) = @_;
  if (!$is_build_new_patch_tree) {
    my $row = $dbh->selectrow_arrayref("SELECT t.editors FROM tbox_patch p, tbox_tree t WHERE p.patch_id = ? AND t.tree_name = p.tree_name", undef, $patch_id);
    if (!can_edit_tree($login, $row->[0])) {
      die "$login: Insufficient privileges to $action (need edit tree)!";
    }
  } else {
    my $row = $dbh->selectrow_arrayref("SELECT t.editors, t.sheriffs FROM tbox_patch p, tbox_tree t WHERE p.patch_id = ? AND t.tree_name = p.tree_name", undef, $patch_id);
    if (!can_edit_patch($login, $row->[0], $row->[1], $dbh)) {
      die "$login: Insufficient privileges to $action!";
    }
  }
}

sub check_edit_machine {
  my ($login, $dbh, $machine_id, $action) = @_;
  my $row = $dbh->selectrow_arrayref("SELECT t.editors, t.sheriffs FROM tbox_machine m, tbox_tree t WHERE m.machine_id = ? AND t.tree_name = m.tree_name", undef, $machine_id);
  my $rc = can_edit_machine($login, $row->[0], $row->[1], $dbh);
  if ($rc == 0) {
    die "$login: Insufficient privileges to $action (need edit tree)!";
  }
  return $rc;
}

sub check_delete_machine {
  my ($login) = @_;
  if (!can_admin($login)) {
    die "$login: Insufficient privileges to delete machine (need admin/supervisor)!";
  }
}

sub check_edit_bonsai {
  my ($login, $dbh, $bonsai_id) = @_;
  my $row = $dbh->selectrow_arrayref("SELECT t.editors FROM tbox_bonsai b, tbox_tree t WHERE b.bonsai_id = ? AND t.tree_name = b.tree_name", undef, $bonsai_id);
  if (!can_edit_tree($login, $row->[0])) {
    die "Insufficient privileges to edit bonsai (need edit tree)!";
  }
}

#
# 'build_new_patch' tree: Validates the patch name.
#
sub check_patch_name_for_build_new_patch_tree {
  my ($patch_name) = @_;
  if ($patch_name =~ m/[^-a-zA-Z0-9]/) {
    die "Patch name contains invalid characters: $patch_name (allowed: a-z, A-Z, 0-9, and -)";
  }
  if (length($patch_name) < 4) {
    die "Patch name too short: $patch_name (min 4 chars)";
  }
  if (length($patch_name) > 32) {
    die "Patch name too long: $patch_name (max 32 chars)";
  }
}

#
# Validates bug ID.
#
sub check_patch_bug_id {
  my ($bug_id) = @_;

  if (!($bug_id =~ /^(bugref:|ticketref:|)[0-9]*$/)) {
    die "Maformed bug ID: $bug_id (expected: 1234, bugref:1234, ticketref:1234)";
  }
}

#
# Returns 'build_on_commit' or 'build_new_patch' (given a tree name).
#
sub get_tree_type {
  my ($dbh, $tree) = @_;
  my $row = $dbh->selectrow_arrayref("SELECT tree_type FROM tbox_tree WHERE tree_name = ?", undef, $tree);
  return $row->[0];
}

#
# Returns 'build_on_commit' or 'build_new_patch' (given a patch ID).
#
sub get_tree_type_for_patch {
  my ($dbh, $patch_id) = @_;
  my $row = $dbh->selectrow_arrayref("SELECT tbox_tree.tree_type " .
                                     "  FROM tbox_tree " .
                                     "  JOIN tbox_patch " .
                                     "    ON (    tbox_tree.tree_name = tbox_patch.tree_name " .
                                     "        AND tbox_patch.patch_id = ? )", undef, $patch_id);
  return $row->[0];
}


#
# Perform the upload_patch or edit_patch action
#
sub update_patch_action {
  my ($p, $dbh, $login) = @_;

  my $patch_id = $p->param('patch_id') || "";
  my $action = $p->param('action') || "";
  if ($action eq 'upload_patch' || $action eq 'edit_patch') {
    my $patch_name = $p->param('patch_name') || "";
    my $bug_id = $p->param('bug_id') || "";
    my $in_use = sql_get_bool($p->param('in_use'));
    my $compile_only = sql_get_bool($p->param('compile_only'));
    # bird: Choose to ignore patch_ref_url and instead use commit bug notation, with the
    #       default prefix of 'bugref:' if only numbers given:  1234, bugref:1234, ticketref:1234
    #       This will allow us to move xTracker and other trackers as we wish, even migrate to
    #       new a system if we like.
    #my $patch_ref = "Bug $bug_id";
    #my $patch_ref_url = "http://bugzilla.mozilla.org/show_bug.cgi?id=$bug_id";
    my $patch_ref = "$bug_id";
    my $patch_ref_url = "";

    if (!$patch_name) { die "Must specify a non-blank patch name!"; }

    if ($action eq 'upload_patch') {
      # Check security
      my $tree = $p->param('tree') || "";
      my $tree_type = get_tree_type($dbh, $tree);
      check_upload_patch($p, $login, $dbh, $tree, $tree_type eq 'build_new_patch');

      # Check input a little.
      if ($tree_type eq 'build_new_patch') {
          check_patch_name_for_build_new_patch_tree($patch_name);
          $in_use = sql_get_bool(1);
      }
      check_patch_bug_id($bug_id);

      # Get patch
      my $patch_fh = $p->upload('patch');
      if (!$patch_fh) { die "No patch file uploaded!"; }
      my $patch = "";
      while (<$patch_fh>) {
        $patch .= $_;
      }

      # Perform patch insert
      $dbh->do("INSERT INTO tbox_patch (tree_name, patch_name, patch_ref, patch_ref_url, patch, in_use, compile_only, submitter) " .
               "     VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
               undef, $tree, $patch_name, $patch_ref, $patch_ref_url, $patch, $in_use, $compile_only, $login);
      maybe_commit($dbh);

    } else {
      # Check security
      my $tree_type = get_tree_type_for_patch($dbh, $patch_id);
      check_edit_patch($login, $dbh, $patch_id, $tree_type eq 'build_new_patch', "edit patch", );

      # Check input a little.
      if ($tree_type eq 'build_new_patch') {
          check_patch_name_for_build_new_patch_tree($patch_name);
          $in_use = sql_get_bool(1);
      }
      check_patch_bug_id($bug_id);

      # Perform patch update.
      # If build_new_patch, don't allow the patch name to be changed.
      my $rows;
      if ($tree_type eq 'build_new_patch') {
        $rows = $dbh->do("UPDATE tbox_patch SET patch_ref = ?, in_use = ?, compile_only = ? WHERE patch_id = ?",
                         undef, $patch_ref, $in_use, $compile_only, $patch_id);
      } else{
        $rows = $dbh->do("UPDATE tbox_patch SET patch_name = ?, patch_ref = ?, patch_ref_url = ?, in_use = ?, compile_only = ?" .
                         " WHERE patch_id = ?",
                         undef, $patch_name, $patch_ref, $patch_ref_url, $in_use, $compile_only, $patch_id);
      }
      if (!$rows) {
        die "Could not find patch!";
      }
      maybe_commit($dbh);
    }

  } elsif ($action eq 'delete_patch') {
    if (!$patch_id) { die "Need patch id!"; }

    # Check security
    my $tree_type = get_tree_type_for_patch($dbh, $patch_id);
    check_edit_patch($login, $dbh, $patch_id, $tree_type eq 'build_new_patch', "delete patch");
    if ($tree_type eq 'build_new_patch') {
        die "cannot delete patches from 'build_new_patch' trees";
    }

    # Perform patch delete
    my $rows = $dbh->do("DELETE FROM tbox_patch WHERE patch_id = ?", undef, $patch_id);
    if (!$rows) {
      die "Delete failed.  No such tree / patch.";
    }
    maybe_commit($dbh);

  } elsif ($action eq 'stop_using_patch' || $action eq 'start_using_patch') {
    if (!$patch_id) { die "Need patch id!" }

    # Check security
    my $tree_type = get_tree_type_for_patch($dbh, $patch_id);
    check_edit_patch($login, $dbh, $patch_id, $tree_type eq 'build_new_patch', "start/stop using patch");
    if (   $action eq 'start_using_patch'
        && $tree_type == 'build_new_patch') {
      die "Invalid patch action 'start_using_patch' for 'build_new_patch' tree!";
    }

    my $rows = $dbh->do("UPDATE tbox_patch SET in_use = ? WHERE patch_id = ?",
                        undef, sql_get_bool($action eq 'start_using_patch'), $patch_id);
    if (!$rows) {
      die "Update failed.  No such tree / patch.";
    }
    maybe_commit($dbh);
  }

  return $patch_id;
}

#
# Update / Insert the tree and perform other DB operations
#
sub update_tree_action {
  my ($p, $dbh, $login) = @_;

  my $tree = $p->param('tree') || "";

  my $action = $p->param('action') || "";
  if ($action eq 'edit_tree') {
    my $newtree = $p->param('tree_name') || "";
    my $field_short_names = $p->param('field_short_names') || "";
    my $field_processors = $p->param('field_processors') || "";
    my $statuses = $p->param('statuses') || "";
    my $min_row_size = $p->param('min_row_size') || "0";
    my $max_row_size = $p->param('max_row_size') || "0";
    my $default_tinderbox_view = $p->param('default_tinderbox_view') || "0";
    my $new_machines_visible = sql_get_bool($p->param('new_machines_visible'));
    my $tree_type = $p->param('patch_by_patch') ? 'build_new_patch' : 'build_on_commit';
    my $cvs_co_date = $p->param('cvs_co_date') || "";
    my $editors = $p->param('editors') || "";

    if (!$newtree) { die "Must specify a non-blank tree!"; }

    # Update or insert the tree
    if ($tree) {
      # Check security
      check_edit_tree($login, $dbh, $tree, "edit tree");

      ## @todo renaming a tree will leave machines, patches and initial-machine-config rows orphaned...

      # Perform tree update
      my $rows = $dbh->do("UPDATE tbox_tree " .
                          "   SET tree_name = ?, field_short_names = ?, field_processors = ?, statuses = ?, " .
                          "       min_row_size = ?, max_row_size = ?, default_tinderbox_view = ?, new_machines_visible = ?, " .
                          "       editors = ?, tree_type = ?, cvs_co_date = ? " .
                          " WHERE tree_name = ?",
                          undef,
                          $newtree, $field_short_names, $field_processors, $statuses,
                          $min_row_size, $max_row_size, $default_tinderbox_view, $new_machines_visible,
                          $editors, $tree_type, $cvs_co_date,
                          $tree);
      if (!$rows) {
        die "No tree named $tree!";
      }
    } else {
      # Check security
      if (!can_admin($login)) {
        die "Insufficient privileges to add tree!  (Need superuser)";
      }

      # Perform tree insert
      my $rows = $dbh->do("INSERT INTO tbox_tree (tree_name, field_short_names, field_processors, statuses, min_row_size, " .
                          "                       max_row_size, default_tinderbox_view, new_machines_visible, editors, " .
                          "                       tree_type, header, footer, " .
                          "                       special_message, sheriff, " .
                          "                       build_engineer, status, sheriffs, cvs_co_date) " .
                          "     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                          undef,
                          $newtree, $field_short_names, $field_processors, $statuses, $min_row_size,
                          $max_row_size, $default_tinderbox_view, $new_machines_visible, $editors,
                          $tree_type, $Tinderbox3::InitialValues::header, $Tinderbox3::InitialValues::footer,
                          $Tinderbox3::InitialValues::special_message, $Tinderbox3::InitialValues::sheriff,
                          $Tinderbox3::InitialValues::build_engineer, $Tinderbox3::InitialValues::status, '', $cvs_co_date);
      if (!$rows) {
        die "Passing strange.  Insert failed.";
      }
      $tree = $newtree;
    }

    # Update initial config values
    $dbh->do("DELETE FROM tbox_initial_machine_config WHERE tree_name = ?", undef, $newtree);
    my $i = 0;
    my $sth = $dbh->prepare("INSERT INTO tbox_initial_machine_config (tree_name, name, value) VALUES (?, ?, ?)");
    while (defined($p->param("initial_machine_config$i"))) {
      my $var = $p->param("initial_machine_config$i");
      if ($var) {
        my $val = $p->param("initial_machine_config${i}_val");
        $val =~ s/\r//g;
        $sth->execute($newtree, $var, $val);
      }
      $i++;
    }

    maybe_commit($dbh);

    # Return the new tree name
    $tree = $newtree;
  } elsif ($action eq 'edit_sheriff') {
    # Check security
    check_sheriff_tree($login, $dbh, $tree, "sheriff tree");

    my $header = $p->param('header') || "";
    my $footer = $p->param('footer') || "";
    my $special_message = $p->param('special_message') || "";
    my $sheriff = $p->param('sheriff') || "";
    my $build_engineer = $p->param('build_engineer') || "";
    my $status = $p->param('status') || "";
    my $sheriffs = $p->param('sheriffs') || "";
    my $rows = $dbh->do("UPDATE tbox_tree " .
                        "   SET header = ?, footer = ?, special_message = ?, sheriff = ?, build_engineer = ?, " .
                        "       status = ?, sheriffs = ? " .
                        " WHERE tree_name = ?",
                        undef,
                        $header, $footer, $special_message, $sheriff, $build_engineer,
                        $status, $sheriffs,
                        $tree);
    if (!$rows) {
      die "No tree named $tree!";
    }
    maybe_commit($dbh);
  }

  return $tree;
}

#
# Update machine information
#
sub update_machine_action {
  my ($p, $dbh, $login) = @_;

  my $machine_id = $p->param('machine_id') || "";
  $machine_id = $1 if $machine_id =~ /(\d+)/;

  # Get the current timestamp, as we don't seem to be using transactions. sigh.
  my $rows = $dbh->selectrow_arrayref("select " . sql_current_timestamp());
  my $now = $rows->[0];

  my $action = $p->param('action') || "";
  if ($action eq 'edit_machine') {
    die "Must pass machine_id!" if !$machine_id;

    # Check security
    my $full_access = check_edit_machine($login, $dbh, $machine_id, "edit machine");

    my $visible = sql_get_bool($p->param('visible'));
    my $commands = $p->param('commands');
    my $last_patch_id = $p->param('last_patch_id') || "";
    $last_patch_id =~ s/^\s+|\s+$//g;
    my $description = $p->param('description');

    if ($full_access == 1) {
      # Full update.
      $rows = $dbh->do('UPDATE tbox_machine SET visible = ?, commands = ?, last_patch_id = ?, description = ? WHERE machine_id = ?',
                       undef, $visible, $commands, length($last_patch_id) > 0 ? $last_patch_id : undef, $description, $machine_id);
      if (!$rows) {
        die "Could not update machine!";
      }

      # Update the history table as needed.
      $dbh->do('UPDATE tbox_machine_history SET tsExpire = ?, sAuthorExp = ? ' .
               ' WHERE idMachine = ? ' .
               "   AND tsExpire > '$highish_exp_ts'::timestamptz " .
               '   AND (fVisible <> ? OR sCommands <> ? OR idLastPatch <> ? OR sDescription <> ?)',
               undef, $now, $login, $machine_id,
               $visible, $commands, length($last_patch_id) > 0 ? $last_patch_id : undef, $description);

      # Update config values
      $dbh->do("DELETE FROM tbox_machine_config WHERE machine_id = ?", undef, $machine_id);
      my $i = 0;
      my $sth = $dbh->prepare("INSERT INTO tbox_machine_config (machine_id, name, value) VALUES (?, ?, ?)");
      while (defined($p->param("machine_config$i"))) {
        my $var = $p->param("machine_config$i");
        if ($var) {
          my $val = $p->param("machine_config${i}_val");
          # Don't put mozconfig in the table if the value is empty
          if (!($var eq "mozconfig" && !$val)) {
            $val =~ s/\r//g;
            $sth->execute($machine_id, $var, $val);
          }
        }
        $i++;
      }

      # Update the history - 1. mark anything changed expired. 2. insert new entries.
      $rows = $dbh->do("
        UPDATE tbox_machine_config_history SET tsExpire = ?, sAuthorExp = ?
         WHERE idMachine = ?
           AND tsExpire > '$highish_exp_ts'::timestamptz
           AND NOT EXISTS (SELECT 1 FROM tbox_machine_config tmc
                           WHERE tmc.machine_id = tbox_machine_config_history.idMachine
                             AND tmc.name       = tbox_machine_config_history.sName
                             AND tmc.value      = tbox_machine_config_history.sValue )
        ", undef, $now, $login, $machine_id);
    } else {
      # Only allow updating command and last_patch_id.
      my $rows = $dbh->do('UPDATE tbox_machine SET commands = ?, last_patch_id = ? WHERE machine_id = ?',
                          undef, $commands, length($last_patch_id) > 0 ? $last_patch_id : undef, $machine_id);
      if (!$rows) {
        die "Could not update machine!";
      }

      # Update the history table as needed.
      $dbh->do('UPDATE tbox_machine_history SET tsExpire = ?, sAuthorExp = ? ' .
               ' WHERE idMachine = ? ' .
               "   AND tsExpire > '$highish_exp_ts'::timestamptz " .
               '   AND idLastPatch <> ?',
               undef, $now, $login, $machine_id, length($last_patch_id) > 0 ? $last_patch_id : undef);
    }

  } elsif ($action eq 'kick_machine') {
    die "Must pass machine_id!" if !$machine_id;

    # Check security
    check_edit_machine($login, $dbh, $machine_id, "kick machine");

    my $commands = $dbh->selectrow_arrayref("SELECT commands FROM tbox_machine WHERE machine_id = ?", undef, $machine_id);
    if (!$commands) {
      die "Invalid machine id $machine_id!";
    }
    my @commands = split /,/, $commands->[0];
    if (! grep { $_ eq 'kick' } @commands) {
      push @commands, 'kick';
    }
    my $rows = $dbh->do('UPDATE tbox_machine SET commands = ? WHERE machine_id = ?', undef, join(',', @commands), $machine_id);
    if (!$rows) {
      die "Could not update machine!";
    }

    # Update the history table as needed.
    $dbh->do('UPDATE tbox_machine_history SET tsExpire = ?, sAuthorExp = ? ' .
             ' WHERE idMachine = ? ' .
             "   AND tsExpire > '$highish_exp_ts'::timestamptz " .
             '   AND sCommands <> ?',
             undef, $now, $login, $machine_id, join(',', @commands));

  } elsif ($action eq 'delete_machine') {
    die "Must pass machine_id!" if !$machine_id;

    # Check security
    check_delete_machine($login);

    my $row = $dbh->do('DELETE FROM tbox_build_field WHERE machine_id = ?', undef, $machine_id);
    $row = $dbh->do('DELETE FROM tbox_build_comment WHERE machine_id = ?', undef, $machine_id);
    $row = $dbh->do('DELETE FROM tbox_build WHERE machine_id = ?', undef, $machine_id);
    $row = $dbh->do('DELETE FROM tbox_machine WHERE machine_id = ?', undef, $machine_id);
    die "Could not delete machine" if !$row;
    delete_logs($machine_id);
    maybe_commit($dbh);
    return $machine_id;
  } else {
    return $machine_id;
  }

  # complete the tbox_machine_history.
  $rows = $dbh->selectrow_arrayref("
    SELECT COUNT(idMachine)
      FROM tbox_machine_history
     WHERE idMachine = $machine_id
       AND tsEffective <= ?
       AND tsExpire > '$highish_exp_ts'::timestamptz",
     undef, $now );
  if ($rows->[0] < 1) {
      $rows = $dbh->do("
        INSERT INTO tbox_machine_history(idMachine, tsEffective, sAuthor, sTreeName,
                                         sMachineName, sCommands, fVisible, idLastPatch, sDescription,
                                         sOpSys, sOsVersion, sCompiler, fClobber, iScriptRev)
        SELECT tm.machine_id, ?, ?, tm.tree_name,
               tm.machine_name, tm.commands, tm.visible, tm.last_patch_id, tm.description,
               tm.os, tm.os_version, tm.compiler, tm.clobber, tm.script_rev
         FROM  tbox_machine tm
        WHERE  tm.machine_id = ?", undef, $now, $login, $machine_id);
      if (!$rows) {
        die "Could not update machine history!";
      }
  }
  $rows = $dbh->do("
    INSERT INTO tbox_machine_config_history (idMachine, tsEffective, sAuthor, sName, sValue)
     SELECT tmc.machine_id, ?, ?, tmc.name, tmc.value
       FROM tbox_machine_config tmc LEFT OUTER JOIN tbox_machine_config_history tmch
         ON tmc.machine_id = tmch.idMachine
        AND tmc.name       = tmch.sName
        AND tmch.tsExpire  > '$highish_exp_ts'::timestamptz
      WHERE tmc.machine_id = ?
        AND tmch.idMachine IS NULL",
    undef, $now, $login, $machine_id);

  maybe_commit($dbh);
  return $machine_id;
}

#
# Bulk machine command updating.
#
sub bulk_machine_command_update {
  my ($p, $dbh, $login, $action, $machine_ids) = @_;

  # Validate the command.
  my $sCommands;
  if ($action eq 'kick') {
    $sCommands = 'kick';
  } elsif ($action eq 'build') {
    $sCommands = 'build';
  } elsif ($action eq 'clobber') {
    $sCommands = 'clobber';
  } elsif ($action eq 'clobber_build') {
    $sCommands = 'clobber,build';
  } elsif ($action eq 'cleanup') {
    $sCommands = 'cleanup';
  } elsif ($action eq 'cleanup_build') {
    $sCommands = 'cleanup,build';
  } elsif ($action eq 'cleanup_clobber') {
    $sCommands = 'cleanup,clobber';
  } elsif ($action eq 'clear') {
    $sCommands = '';
  } else {
    return "Invalid action: $action";
  }

  # Must have at least one machine ID.
  if (!@{$machine_ids}) {
    return "No machine IDs specified with action $action!";
  }
  foreach my $id (@{$machine_ids}) {
    if ($id !~ /^[ \t]*[0-9]+[ \t]*$/) {
      return "Invalid machine ID: $id!";
    }
  }
  my $in_ids = '('.join(',',@{$machine_ids}).')';

  # Check security.
  my $rows = $dbh->selectall_arrayref("
    SELECT t.editors, t.sheriffs, t.tree_name
      FROM tbox_machine m, tbox_tree t
     WHERE m.machine_id IN " . $in_ids . "
       AND t.tree_name = m.tree_name");

  foreach my $row(@{$rows}) {
    my $rc = can_edit_machine($login, $row->[0], $row->[1], $dbh);
    if ($rc == 0) {
      return "$login: Insufficient privileges to perform $action on machines in ".$row->[2]." (need edit tree or sheriff)!";
    }
  }

  # Get the current timestamp, as we don't seem to be using transactions. sigh.
  $rows = $dbh->selectrow_arrayref("select " . sql_current_timestamp());
  my $now = $rows->[0];

  # Perform the update.
  $rows = $dbh->do("UPDATE tbox_machine SET commands = ? WHERE machine_id IN " . $in_ids, undef, $sCommands);
  if (!$rows) {
    return "Could not update machines!";
  }

  # Historize it.
  $dbh->do("
  UPDATE tbox_machine_history SET tsExpire = ?, sAuthorExp = ?
   WHERE idMachine IN $in_ids
     AND sCommands <> ?
  ", undef, $now, $login, $sCommands);

  $rows = $dbh->do("
    INSERT INTO tbox_machine_history(idMachine, tsEffective, sAuthor, sTreeName,
                                     sMachineName, sCommands, fVisible, idLastPatch, sDescription,
                                     sOpSys, sOsVersion, sCompiler, fClobber, iScriptRev)
    SELECT tm.machine_id, ?, ?, tm.tree_name,
           tm.machine_name, tm.commands, tm.visible, tm.last_patch_id, tm.description,
           tm.os, tm.os_version, tm.compiler, tm.clobber, tm.script_rev
     FROM  tbox_machine tm LEFT OUTER JOIN tbox_machine_history tmh
        ON tm.machine_id   = tmh.idMachine
       AND tmh.tsExpire    > '$highish_exp_ts'::timestamptz
     WHERE tm.machine_id IN $in_ids
       AND tmh.idMachine IS NULL
    ", undef, $now, $login);

  # Since we might start the history for a textbox here, make sure all the current
  # values are present as well, or the changelog will be looking rather confusing.
  $rows = $dbh->do("
    INSERT INTO tbox_machine_config_history (idMachine, tsEffective, sAuthor, sName, sValue)
     SELECT tmc.machine_id, ?, ?, tmc.name, tmc.value
       FROM tbox_machine_config tmc LEFT OUTER JOIN tbox_machine_config_history tmch
         ON tmc.machine_id = tmch.idMachine
        AND tmc.name       = tmch.sName
        AND tmch.tsExpire  > '$highish_exp_ts'::timestamptz
      WHERE tmc.machine_id IN $in_ids
        AND tmch.idMachine IS NULL",
    undef, $now, $login);

  maybe_commit($dbh);

  return undef;
}


sub update_bonsai_action {
  my ($p, $dbh, $login) = @_;

  my $tree = $p->param('tree') || "";
  my $bonsai_id = $p->param('bonsai_id') || "";

  my $action = $p->param('action') || "";

  if ($action eq 'edit_bonsai') {
    my $display_name = $p->param('display_name') || "";
    my $bonsai_url = $p->param('bonsai_url') || "";
    my $module = $p->param('module') || "";
    my $branch = $p->param('branch') || "";
    my $directory = $p->param('directory') || "";
    my $cvsroot = $p->param('cvsroot') || "";

    if ($bonsai_id) {
      # Check security
      check_edit_bonsai($login, $dbh, $bonsai_id);

      my $rows = $dbh->do("UPDATE tbox_bonsai SET display_name = ?, bonsai_url = ?, module = ?, branch = ?, directory = ?, cvsroot = ? WHERE bonsai_id = ?", undef, $display_name, $bonsai_url, $module, $branch, $directory, $cvsroot, $bonsai_id);
      if (!$rows) {
        die "Could not update bonsai!";
      }
      Tinderbox3::Bonsai::clear_cache($dbh, $bonsai_id);
    } else {
      # Check security
      check_edit_tree($login, $dbh, $tree, "edit machine");

      $dbh->do("INSERT INTO tbox_bonsai (tree_name, display_name, bonsai_url, module, branch, directory, cvsroot) VALUES (?, ?, ?, ?, ?, ?, ?)", undef, $tree, $display_name, $bonsai_url, $module, $branch, $directory, $cvsroot);
      $bonsai_id = sql_get_last_id($dbh, 'tbox_bonsai_bonsai_id_seq');
    }
    maybe_commit($dbh);
  } elsif ($action eq "delete_bonsai") {
    Tinderbox3::Bonsai::clear_cache($dbh, $bonsai_id);
    my $rows = $dbh->do("DELETE FROM tbox_bonsai WHERE bonsai_id = ?", undef, $bonsai_id);
    if (!$rows) {
      die "Could not delete bonsai!";
    }
    maybe_commit($dbh);
  }

  return ($tree, $bonsai_id);
}

sub sql_current_timestamp {
  if ($dbtype eq "Pg") {
      return "(current_timestamp at time zone 'UTC')";
  } elsif ($dbtype eq "mysql") {
      return "current_timestamp()";
  }
}

sub sql_get_timestamp {
  my ($arg) = @_;
  if ($dbtype eq "Pg") {
    return "EXTRACT (EPOCH FROM $arg)";
  } elsif ($dbtype eq "mysql") {
    return "unix_timestamp($arg)";
  }
}

sub sql_abstime {
  my ($arg) = @_;
  if ($dbtype eq "Pg") {
    # return "abstime($arg + 0)"; - abstime is an internal type, don't use.
    # http://www.postgresql.org/docs/current/static/functions-datetime.html says
    # this is the right way to convert from unix timestamp to postgres timestamp:
    return "(TIMESTAMP WITHOUT TIME ZONE 'epoch' + ($arg) * '1 second'::INTERVAL)";
  } elsif ($dbtype eq "mysql") {
    return "from_unixtime($arg)";
  }
}

# bird 2020-06-20: sql_abstime doesn't work when getting stuff from VcsRevisions,
#                  ended up with a timezone skew.  Don't want to break stuff that
#                  is working by modifying sql_abstime, so introducing this variant.
sub sql_abstime_tz {
  my ($arg) = @_;
  if ($dbtype eq "Pg") {
    return "(TIMESTAMP WITH TIME ZONE 'epoch' + ($arg) * '1 second'::INTERVAL)";
  } elsif ($dbtype eq "mysql") {
    return "from_unixtime($arg)";
  }
}

sub sql_get_last_id {
  my ($dbh, $sequence) = @_;
  if ($dbtype eq "Pg") {
    my $row = $dbh->selectrow_arrayref("SELECT currval('$sequence')");
    return $row->[0];
  } elsif ($dbtype eq "mysql") {
    my $row = $dbh->selectrow_arrayref("SELECT last_insert_id()");
    return $row->[0];
  }
}

sub sql_get_bool {
  my ($bool) = @_;
  if ($dbtype eq 'Pg') {
    return $bool ? 'Y' : 'N';
  } elsif ($dbtype eq 'mysql') {
    return $bool ? 1 : 0;
  }
}

# todo add timing to these two subs.
sub sql_prepare {
  my ($dbh, $sql) = @_;

  my $t0 = [gettimeofday];
  my $ret = $dbh->prepare($sql);
  my $elapsed = tv_interval($t0);

  print "\n<!--  prepare: $elapsed - $sql -->";
  return $ret;
}

sub sql_execute {
  my @args = @_;
  my $sth = shift @args;

  my $t0 = [gettimeofday];
  my $ret;
  if (!$args[0]) {
    $ret = $sth->execute();
  } else {
    $ret = $sth->execute($args[0]);
  }
  my $elapsed = tv_interval($t0);

  print "\n<!--  execute: $elapsed -->";
  return $ret;
}

1
