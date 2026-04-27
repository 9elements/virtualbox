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

package Tinderbox3::ShowTests;

use strict;
use Date::Format;
use Tinderbox3::Header;
use Time::HiRes qw( gettimeofday tv_interval );


sub print_showtests {
  my ($p, $dbh, $fh, $tree, $start_time, $end_time,
      $min_row_size, $max_row_size, $all_builds) = @_;

  #
  # Get tree and patch info
  #
  my $tree_info = $dbh->selectrow_arrayref("SELECT field_short_names, field_processors, header, footer, special_message, sheriff, build_engineer, cvs_co_date, status, min_row_size, max_row_size FROM tbox_tree WHERE tree_name = ?", undef, $tree);
  if (!$tree_info) {
    die "Tree $tree does not exist!";
  }
  my ($field_short_names, $field_processors_str, $header, $footer,
      $special_message, $sheriff, $build_engineer, $cvs_co_date, $status,
      $default_min_row_size, $default_max_row_size) = @{$tree_info};
  $min_row_size = $default_min_row_size if !defined($min_row_size);
  $max_row_size = $default_max_row_size if !defined($max_row_size);
  my %field_processors;
  # Create the handlers for the different fields
  require Tinderbox3::FieldProcessors::default;
  my %field_handlers = ( default => new Tinderbox3::FieldProcessors::default );
  foreach my $field_processor (split /,/, $field_processors_str) {
    my ($field, $processor) = split /=/, $field_processor;
    $field_processors{$field} = $processor;
    # Check if the processor is OK to put in an eval statement
    if ($processor =~ /^([A-Za-z]+)$/) {
      my $code = "require Tinderbox3::FieldProcessors::$1; \$field_handlers{$1} = new Tinderbox3::FieldProcessors::$1();";
      eval $code;
    }
  }

  # Get sizes in seconds for easy comparisons
  $min_row_size *= 60;
  $max_row_size *= 60;

  my %patch_str; # no patches

  print $fh "",insert_dynamic_data($header, $tree, $sheriff, $build_engineer, $cvs_co_date, $status, \%patch_str, $start_time, $end_time);
  print $fh "",insert_dynamic_data($special_message, $tree, $sheriff, $build_engineer, $cvs_co_date, $status, \%patch_str, $start_time, $end_time);

  print_tree($p, $dbh, $fh, $tree, $start_time, $end_time, $field_short_names,
             \%field_processors, \%field_handlers, $min_row_size, $max_row_size,
             \%patch_str, $all_builds);

  print $fh "",insert_dynamic_data($footer, $tree, $sheriff, $build_engineer, $cvs_co_date, $status, \%patch_str, $start_time, $end_time);

}

sub print_tree {
  my ($p, $dbh, $fh, $tree, $start_time, $end_time, $field_short_names,
      $field_processors, $field_handlers, $min_row_size, $max_row_size,
      $patch_str, $all_builds) = @_;
  my $only_failed = 1; ## FIXME

  # statistics
  my %stat_cause = ();
  my %stat_status = ();
  my %stat_test = (());

  #
  # Select all the builds for the given period and display them orderd by start time.
  #
  my $t0 = [gettimeofday];
  my $sth;
  if ($all_builds) {
    $sth = $dbh->prepare(
      "SELECT m.machine_id,
              m.machine_name,
              " . Tinderbox3::DB::sql_get_timestamp("b.build_time") . ",
              " . Tinderbox3::DB::sql_get_timestamp("b.status_time") . ",
              b.status,
              b.log
         FROM tbox_machine m,
              tbox_build b
        WHERE m.tree_name = ?
          AND b.status_time >= " . Tinderbox3::DB::sql_abstime("?") . "
          AND b.build_time  <= " . Tinderbox3::DB::sql_abstime("?") . "
          AND m.machine_id   = b.machine_id
     ORDER BY b.status_time DESC,
              b.build_time DESC,
              b.machine_id
      ");
  } else {
    $sth = $dbh->prepare(
      "SELECT m.machine_id,
              m.machine_name,
              " . Tinderbox3::DB::sql_get_timestamp("b.build_time") . ",
              " . Tinderbox3::DB::sql_get_timestamp("b.status_time") . ",
              b.status,
              b.log
         FROM tbox_machine m,
              tbox_build b
        WHERE m.tree_name = ?
          AND b.status_time >= " . Tinderbox3::DB::sql_abstime("?") . "
          AND b.build_time  <= " . Tinderbox3::DB::sql_abstime("?") . "
          AND m.machine_id   = b.machine_id
          AND b.status >= 100
          AND b.status < 300
     ORDER BY b.status_time DESC,
              b.machine_id
      ");
  }
  $sth->execute($tree, $start_time, $end_time);
  my $elapsed = tv_interval($t0);
  print $fh "<!-- columns $elapsed -->\n";

  print $fh "\n"
       ."<table class=tinderbox>\n"
       ." <thead>\n"
       ."  <tr>\n"
       ."   <th>Time</th>\n"
       ."   <th>Machine</th>\n"
       ."   <th>Status</th>\n"
       ."   <th>Log</th>\n"
       ."   <th>Fields</th>\n"
       ."   <th>Tests</th>\n"
       ."   <th>Causes</th>\n"
       ."   <th>Comment</th>\n"
       ."  </tr>\n"
       ." </thead>\n"
       ." <tbody>\n";
  while (my $rowdata = $sth->fetchrow_arrayref) {
    my $machine_id = $rowdata->[0];
    my $machine_name = $rowdata->[1];
    my $build_time = $rowdata->[2];
    my $status_time = $rowdata->[3];
    my $status = $rowdata->[4];
    my $log = $rowdata->[5];
    my $smoke_test = "";
    if ($machine_name =~ /smoke/) {
      $smoke_test = "smoketest.";
    }

    my $row = '<tr>';

    # machine and test info
    $row .= "<td class=time>" . time2str("%D %R", $build_time) . "&nbsp;-&nbsp;" . time2str("%R", $status_time) . "</td>";
    $row .= "<td >$machine_name</td>";
    $row .= "<td >$status</td>";
    $row .= "<td ><a href='showlog.pl?machine_id=$machine_id&logfile=$log'>L</a> "
           ."<a href='showlog.pl?machine_id=$machine_id&logfile=$log&format=raw'>R</a></td>";

    # fields
    my $fields = $dbh->selectall_arrayref(
      "SELECT name,
              value
         FROM tbox_build_field
        WHERE machine_id = ?
          AND build_time = " . Tinderbox3::DB::sql_abstime("?") . "
     ORDER BY name
      ",
      undef, $machine_id, $build_time);

    # fields with processors
    $row .= "<td class=fields>";
    my $prev = undef;
    foreach my $field (@{$fields}) {
      my $processor = $field_processors->{$field->[0]};
      $processor = "URL" if !$processor && $field->[0] =~ /-(vob|png)$/;
      if ($processor && ($field->[0] ne "cause")) {
        my $cur = $field->[0];
        $cur =~ s/-[a-zA-Z0-9]*$//;
        $row .= "<BR>" if $prev && $cur ne $prev;
        $prev = $cur;

        my $handler = $field_handlers->{$processor};
        $row .= $handler->process_field(undef, $field->[0], $field->[1]) . " ";
      }
    }
    $row .= "</td>";

    # other fields ('tests')
    $row .= "<td class=test_fields>";
    my $first_field = 1;
    my $cause = "";
    foreach my $field (@{$fields}) {
      my $name = $field->[0];
      if ($name eq "cause") {
        $cause .= $field->[1];
      } else {
        my $processor = $field_processors->{$name};
        $processor = "URL" if !$processor && $name =~ /-(vob|png)$/;
        if (!$processor) {
          if (!$stat_test{$smoke_test.$name}) {
            $stat_test{$smoke_test.$name}{runs} = 0;
            $stat_test{$smoke_test.$name}{min} = 99999999999999;
            $stat_test{$smoke_test.$name}{max} = 0;
            $stat_test{$smoke_test.$name}{total} = 0;
          }

          $row .= "<BR>" if !$first_field;
          if ($field->[1] =~ /[fF][aA][iI][lL]/) {
            $row .= "<strong>".$field->[0] . "=" . $field->[1] . "</strong>";
            $stat_test{$smoke_test.$field->[0]}{failed} ++;
          } else {
            $row .= $field->[0] . "=" . $field->[1];
            my $num = getnum($field->[1]);
            if ($num) {
              $stat_test{$smoke_test.$name}{min} = $num if $num < $stat_test{$smoke_test.$name}{min};
              $stat_test{$smoke_test.$name}{max} = $num if $num > $stat_test{$smoke_test.$name}{max};
              $stat_test{$smoke_test.$name}{total} += $num;
            }
          }
          $first_field = 0;
          $stat_test{$smoke_test.$name}{runs} ++;
        }
      }
    }
    $row .= "</td>";

    # cause of failure
    $row .= "<td class=cause><strong><a href='editcause.pl?tree=$tree&machine_id=$machine_id&build_time=$build_time'>Edit</a><strong>";
    if ($cause ne "") {
      $cause =~ s/^[\n\t\r ]*;//g;
      $cause =~ s/;[\n\t\r ]*$//g;
      my $processor = $field_processors->{'cause'};
      if (!$processor) {
        my $tmp = $cause;
        $tmp =~ s/;/<BR>/g;
        $row .= "<BR>$tmp";
      } else {
        my $handler = $field_handlers->{$processor};
        $row .= $handler->process_field(undef, 'cause', $cause) . " ";
      }

      # collect cause statistics
      $cause = ";" . $cause;
      $cause =~ s/[\n\r\t ]*;[\n\r\t ]*[^=;]*=[\n\r\t ]*/;/g;
      $cause =~ s/^;//;
      foreach my $element (split(/;/, $cause)) {
        $stat_cause{$element} ++;
      }
    }
    $row .= "</td>";

    # comments
    my $comments = $dbh->selectall_arrayref(
      "SELECT login,
              build_comment,
              " . Tinderbox3::DB::sql_get_timestamp("comment_time") . "
         FROM tbox_build_comment
        WHERE machine_id = ?
          AND build_time = " . Tinderbox3::DB::sql_abstime("?") ."
     ORDER BY comment_time
      ",
      undef, $machine_id, $build_time);
    $row .= "<td class=comment><strong><a href='buildcomment.pl?tree=$tree&machine_id=$machine_id&build_time=$build_time'>Add Comment</a></strong>";
    foreach my $comment (@{$comments}) {
      $row .= "<p>"
             ."<strong>$comment->[0] - " . time2str("%D %R", $comment->[2]) . "</strong>: "
             ."<CODE>$comment->[1]</CODE></P>";
    }
    $row .= "</td>";

    # end of row
    if ($status >= 200 || $all_builds) {
      print $fh $row . "</tr>\n";
    }

    # collect statistics
    $stat_status{$status}++;;
  }
  print $fh " </tbody>\n"
       ."</table>\n\n";

  #
  # Statistics
  #

  print $fh "<p><br><p>"
       ."<table>\n"
       ."  <tr>"
       ."   <th>Tests</th>\n"
       ."   <th>Causes</th>\n"
       ."   <th>Status Codes</th>\n"
       ."  </tr>\n"
       ."  <tr>\n";

  # tests
  print $fh "<td valign=top>\n"
       ."<table class=statistics><thead><tr><th>Test</th><th>Runs</th><th>Failures</th>"
       ."<th>Min</th><th>Avg</th><th>Max</th><th>Total</th></tr></thead>\n"
       ."<tbody>";
  foreach my $key (sort(keys %stat_test)) {
    my $test = $stat_test{$key};
    print $fh "<tr><td>$key</td>"
         ."<td>$test->{runs}</td>"
         ."<td>";
    if ($test->{failed}) {
      print $fh $test->{failed} . " (" . int($test->{failed} * 100 / $test->{runs} + 0.5) . "%)";
    }
    print $fh "</td>"
         ."<td>$test->{min}</td>"
         ."<td>".int($test->{total} / $test->{runs} + 0.5)."</td>"
         ."<td>$test->{max}</td>"
         ."<td>$test->{total}</td>"
         ."</tr>\n";
  }
  print $fh "</tbody></table>"
       ."</td>";

  # causes
  print $fh "<td valign=top>\n"
       ."<table class=statistics><thead><tr><th>Cause</th><th>Occurences</th></tr></thead>\n"
       ."<tbody>";
  my $total = 0;
  foreach my $key (keys %stat_cause) {
    $total += $stat_cause{$key};
  }
  foreach my $key (sort(keys %stat_cause)) {
    print $fh "<tr><td>$key</td><td>$stat_cause{$key} (".int($stat_cause{$key} * 100 / $total + 0.5)."%)</td></tr>\n";
  }
  print $fh "</tbody></table>"
       ."</td>";

  # status
  print $fh "<td valign=top>\n"
       ."<table class=statistics><thead><tr><th>Status</th><th>Occurences</th></tr></thead>\n"
       ."<tbody>";
  $total = 0;
  foreach my $key (keys %stat_status) {
    $total += $stat_status{$key};
  }
  foreach my $key (sort(keys %stat_status)) {
    print $fh "<tr><td>$key</td><td>$stat_status{$key} ("
         . int($stat_status{$key} * 100 / $total + 0.5)
         ."%)</td></tr>\n";
  }
  print $fh "<tr><td>Total</td><td>$total</td></tr>\n";
  print $fh "</tbody></table>\n"
       ."</td>\n";

  # end of statistics
  print $fh "  </tr>\n"
       ."</table>\n";

}

sub insert_dynamic_data {
  my ($str, $tree, $sheriff, $build_engineer, $cvs_co_date, $status, $patch_str, $start_time, $end_time) = @_;

  $str =~ s/#TREE#/$tree/g;
  my $time = time2str("%c %Z", time);
  $str =~ s/#TIME#/$time/g;
  $str =~ s/#SHERIFF#/$sheriff/g;
  $str =~ s/#BUILD_ENGINEER#/$build_engineer/g;
  $cvs_co_date = 'current' if !$cvs_co_date;
  $str =~ s/#CVS_CO_DATE#/$cvs_co_date/g;
  $str =~ s/#STATUS#/$status/g;
  $str =~ s/#START_TIME_MINUS\((\d+)\)#/$start_time - $1/eg;
  $str =~ s/#END_TIME#/$end_time/g;
  $str =~ s/#PAGE/showtests.pl/g;

  if ($str =~ /#PATCHES#/) {
    my $patches_str = "";
    if (keys %{$patch_str}) {
      $patches_str = join(', ', values %{$patch_str});
    } else {
      $patches_str = "None";
    }
    $str =~ s/#PATCHES#/$patches_str/g;
  }

  return $str;
}

sub getnum {
  use POSIX qw(strtod);
  my $str = shift;
  $str =~ s/^\s+//;
  $str =~ s/\s+$//;
  $! = 0;
  my ($num, $unparsed) = strtod($str);
  if (($str eq '') || ($unparsed != 0) || $!) {
    return;
  }
  return $num;
}

sub is_numeric { defined scalar &getnum }

1
