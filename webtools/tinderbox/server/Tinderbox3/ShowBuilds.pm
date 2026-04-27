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

package Tinderbox3::ShowBuilds;

use strict;
use Date::Format;
use Tinderbox3::Header;
use Tinderbox3::TreeColumns;
use Tinderbox3::BonsaiColumns;
use Tinderbox3::BuildTimeColumn;
use Tinderbox3::Util qw(escape_html url_sans_param);
use Time::HiRes;

sub print_showbuilds {
  my ($p, $dbh, $fh, $tree,
      $start_time, $end_time, $interval, $min_row_size, $max_row_size,
      $style, $load_time, $include_ids, $exclude_ids, $status_filter, $static_page) = @_;

  #
  # Get tree and patch info
  #
  my $tree_info = $dbh->selectrow_arrayref(
    "SELECT field_short_names, field_processors, header, footer, " .
    "       special_message, sheriff, build_engineer, cvs_co_date, status, " .
    "       min_row_size, max_row_size, tree_type " .
    "  FROM tbox_tree " .
    " WHERE tree_name = ?",
    undef, $tree);
  if (!$tree_info) {
    die "Tree $tree does not exist!";
  }
  my ($field_short_names_str, $field_processors_str, $header, $footer,
      $special_message, $sheriff, $build_engineer, $cvs_co_date, $status,
      $default_min_row_size, $default_max_row_size, $tree_type) = @{$tree_info};
  $min_row_size = $default_min_row_size if !defined($min_row_size);
  $max_row_size = $default_max_row_size if !defined($max_row_size);

  # Split up $field_short_names_str into an hash.
  my %field_short_names;
  foreach my $field_short_name (split /[,\n]/, $field_short_names_str) {
    $field_short_name =~ s/^\s+|\s+$//g;
    if ($field_short_name) {
      my ($field, $short) = split /=/, $field_short_name, 2;
      $field =~ s/\s+$//g;
      if (length($field) > 0) {
        $short =~ s/^\s+//g;
        $field_short_names{$field} = $short;
      }
    }
  }

  # Create the handlers for the different fields
  my %field_processors;
  require Tinderbox3::FieldProcessors::default;
  my %field_handlers = ( default => new Tinderbox3::FieldProcessors::default );
  foreach my $field_processor (split /[,\n]/, $field_processors_str) {
    $field_processor =~ s/^\s+|\s+$//g;
    if ($field_processor) {
      my ($field, $processor) = split /=/, $field_processor, 2;
      $field =~ s/\s+$//g;
      if (length($field) > 0) {
        $processor =~ s/^\s+//g;
        $field_processors{$field} = $processor;
        # Check if the processor is OK to put in an eval statement
        if ($processor =~ /^([A-Za-z]+)$/) {
          my $code = "require Tinderbox3::FieldProcessors::$1; \$field_handlers{$1} = new Tinderbox3::FieldProcessors::$1();";
          eval $code;
        }
      }
    }
  }

  # Get sizes in seconds for easy comparisons
  $min_row_size *= 60;
  $max_row_size *= 60;

  #
  # Construct the a href and such for the patches
  # XXX do this lazily in case there are no patches
  #
  my %patch_str;
  {
    my $sth;
    if ($tree_type eq 'build_new_patch') {
      # Patches work differently here, so different selects and presentation.
      if ($end_time + 60 >= time) {
        $sth = $dbh->prepare("SELECT patch_id, patch_name, patch_ref, in_use, submitter, " .
                                     Tinderbox3::DB::sql_get_timestamp("submit_time") . " " .
                             "  FROM tbox_patch " .
                             " WHERE tree_name = ? " .
                             "   AND submit_time > " . Tinderbox3::DB::sql_abstime("?") .
                             " ORDER BY patch_id DESC " .
                             " LIMIT 25" );
        $sth->execute($tree, $start_time - 3600*24*7);
      } else {
        $sth = $dbh->prepare("SELECT patch_id, patch_name, patch_ref, in_use, submitter, " .
                                     Tinderbox3::DB::sql_get_timestamp("submit_time") . " " .
                             "  FROM tbox_patch " .
                             " WHERE tree_name = ? " .
                             "   AND submit_time > " . Tinderbox3::DB::sql_abstime("?") .
                             "   AND submit_time < " . Tinderbox3::DB::sql_abstime("?") .
                             " ORDER BY patch_id DESC " );
        $sth->execute($tree, $start_time - 3600*2, $end_time + 60);
      }
      my $str = "<ul class='patchlist'>\n";
      while (my $row = $sth->fetchrow_arrayref) {
        my $class = !$row->[3] ? " class=obsolete" : "";
        $str .= "<li><span$class>";
        $str .= time2str("%Y-%m-%d %R", $row->[5]);
        $str .= ": <a href='get_patch.pl?patch_id=$row->[0]'>$row->[4]-$row->[1]</a>";
        $str .= " <a href='adminpatch.pl?patch_id=$row->[0]'>&#x270d;</a>";
        if ($row->[2]) {
          if ($row->[2] =~ m/^(bugref:|)([0-9]+)$/) {
              $str .= " (bugref:<a href='https://xtracker.innotek.de/index.php?bug=$2'>$2</a>)";
          } elsif ($row->[2] =~ m/^(ticketref:)([0-9]+)$/) {
              $str .= " (ticketref:<a href='https://www.virtualbox.org/ticket/$2'>$2</a>)";
          } else {
              $str .= " ($row->[2])";
          }
        }
        $str .= "</span></li>\n";
      }
      $str .= "</ul>\n";
      $patch_str{0} = $str;
    } else {
      # Normal tree.
      $sth = $dbh->prepare("SELECT patch_id, patch_name, patch_ref, in_use FROM tbox_patch WHERE tree_name = ?");
      $sth->execute($tree);
      while (my $row = $sth->fetchrow_arrayref) {
        my $str;
        my $class = !$row->[3] ? " class=obsolete" : "";
        $str = "<span$class><a href='get_patch.pl?patch_id=$row->[0]'>";
        $str .= "$row->[1]</a>";
        if ($row->[2]) {
          if ($row->[2] =~ m/^(bugref:|)([0-9]+)$/) {
              $str .= " (bugref:<a href='https://xtracker.innotek.de/index.php?bug=$2'>$2</a>)";
          } elsif ($row->[2] =~ m/^(ticketref:)([0-9]+)$/) {
              $str .= " (ticketref:<a href='https://www.virtualbox.org/ticket/$2'>$2</a>)";
          } else {
              $str .= " ($row->[2])";
          }
        }
        $str .= "</span>";
        $patch_str{$row->[0]} = $str;
      }
    }
  }

  #
  # Construct a base URL for references to the same page
  #
  my $baseurl = 'showbuilds.pl?tree='.$tree;
  if ($style ne 'full') {
    $baseurl .= '&style='.$style;
  }
  if ($p->param('start_time')) {
    $baseurl .= '&start_time='.$p->param('start_time');
  }
  if ($p->param('interval')) {
    $baseurl .= '&interval='.$p->param('interval');
  }
  if ($p->param('min_row_size')) {
    $baseurl .= '&min_row_size='.$p->param('min_row_size');
  }
  if ($p->param('max_row_size')) {
    $baseurl .= '&max_row_size='.$p->param('max_row_size');
  }
  if (@{$include_ids}) {
    $baseurl .= '&show='.join(',', @{$include_ids});
  }
  if (@{$exclude_ids}) {
    $baseurl .= '&hide='.join(',', @{$exclude_ids});
  }
  if (@{$status_filter}) {
    $baseurl .= '&sts='.join(',', @{$status_filter});
  }

  #
  # Do the work.
  #
  print $fh "",insert_dynamic_data($header, $tree, $sheriff, $build_engineer, $cvs_co_date, $status, \%patch_str,
                                   $start_time, $end_time, $interval, $style, $baseurl, $status_filter, $static_page);
  print $fh "",insert_dynamic_data($special_message, $tree, $sheriff, $build_engineer, $cvs_co_date, $status, \%patch_str,
                                   $start_time, $end_time, $interval, $style, $baseurl, $status_filter, $static_page);

  print_tree($p, $dbh, $fh, $tree, $start_time, $end_time, \%field_short_names,
             \%field_processors, \%field_handlers, $min_row_size, $max_row_size,
             \%patch_str, $style, $include_ids, $exclude_ids, $status_filter);

  print $fh "",insert_dynamic_data($footer, $tree, $sheriff, $build_engineer, $cvs_co_date, $status, \%patch_str,
                                   $start_time, $end_time, $interval, $style, $baseurl, $status_filter, $static_page);

  $load_time = (Time::HiRes::time - $load_time) * 1000;
  print $fh "<p>Load time: $load_time ms</p>";
}

sub generate_time_nav {
  my ($tree, $now, $start_time, $end_time, $interval, $style, $baseurl, $static_page, $where) = @_;
  if (defined($where) && $where) {
    $where = '-'.$where;
  } else {
    $where = '';
  }

  my $urlnotime = escape_html(url_sans_param($baseurl,'start_time') . '&'); # ASSUMES there is ?tree=xxxx;
  my $timenav = '';

  # back.
  $timenav .= " <a href='" . $urlnotime . "start_time=". ($start_time - $interval)
           . "' class='timenavprev timenavprev$where' title='One period earlier'>&lt;&lt;earlier</a> \n";

  # combo
  $timenav .= "<form method='GET' class='timenavform timenavform$where'>\n";
  $timenav .= " <select name='start_time' onchange=\"window.location='" . $urlnotime . "start_time='+this.options[this.selectedIndex].value;\" title=\"Start time\">\n";
  my @periods = ('-0: Now', '-21600: 6 hours ago', '-43200: 12 hours ago', '-64800: 18 hours ago', '-86400: 1 day ago',
                 '-172800: 2 days ago', '-259200: 3 days ago', '-345600: 4 days ago', '-432000: 5 days ago',
                 '-518400: 6 days ago', '-604800: 1 week ago', '-1209600: 2 weeks ago', '-2419200: 4 weeks ago');
  my $selected = 0;
  foreach my $period(@periods) {
      my ($value, $desc) = split(/: /, $period, 2);
      if (abs($now - $end_time + $value) <= 3600) {
          $timenav .= "  <option value='$value' selected>$desc</option>\n";
          $selected = 1;
      } else {
          $timenav .= "  <option value='$value'>$desc</option>\n";
      }
  }
  if (!$selected) {
      use integer;
      my $ago   = $now - $end_time;
      my $weeks = $ago / (7 * 24 * 3600);
      my $left  = $ago % (7 * 24 * 3600);
      my $days  = $left / (24 * 3600);
      $left = $left % (24 * 3600);
      my $hours = $left / 3600;
      $timenav .= "  <option value='-$ago' selected>";
      if ($weeks > 0) {
          $timenav .= "$weeks week".($weeks == 1 ? ' ' : 's ');
      }
      if ($days > 0) {
          $timenav .= "$days day".($days == 1 ? ' ' : 's ');
      }
      if ($hours > 0) {
          $timenav .= "$hours hour".($hours == 1 ? ' ' : 's ');
      }
      $timenav .= "ago</option>\n";
  }
  $timenav .= " </select>\n</form>";

  # forward (if applicable).
  if ($end_time - $now > -60) {
      $timenav .= " later&gt;&gt; \n";
  } else {
      $timenav .= " <a href='" . $urlnotime . "start_time=$end_time"
               . "' class='timenavprev timenavprev$where' title='One period later'>later&gt;&gt;</a>\n";
  }

  if ($static_page) {
      $timenav .= " <a href='showbuilds.pl?tree=$tree&style=$style' class='timenavstatic timenavstatic$where'>[Dynamic Now]</a>\n";
  } else {
      $timenav .= " <a href='$tree".($style eq 'full' ? '' : '-'.$style).".html' class='timenavstatic timenavstatic$where'>[Static Now]</a>\n";
  }

  # interval selection.
  $timenav .= "<form method='GET' class='intervalform intervalform$where'>\n";
  $timenav .= " <select name='interval' onchange=\"window.location='";
  $timenav .= escape_html(url_sans_param($baseurl,'interval'));
  $timenav .= "&interval='+this.options[this.selectedIndex].value;\" title=\"Display interval\">\n";
  my @intervals = ('1: 1 hour', '2: 2 hours', '3: 3 hours', '6: 6 hours', '9: 9 hours', '12: 12 hours',
                   '18: 18 hours', '24: 24 hours', '36: 36 hours', '48: 48 hours');
  $selected = 0;
  foreach my $cur(@intervals) {
      my ($value, $desc) = split(/: /, $cur, 2);
      $value *= 3600;
      if (abs($interval - $value) <= 1800) {
          $timenav .= "  <option value='$value' selected>$desc</option>\n";
          $selected = 1;
      } else {
          $timenav .= "  <option value='$value'>$desc</option>\n";
      }
  }
  if (!$selected) {
      use integer;
      my $minutes = $interval / 60;
      my $hours = $minutes / 60;
      $minutes = $minutes % 60;
      $timenav .= "  <option value='$minutes' selected>";
      if ($hours > 0) {
          $timenav .= "$hours hour".($hours == 1 ? '' : 's');
      }
      if ($minutes > 0) {
          $timenav .= " $minutes min";
      }
      $timenav .= "</option>\n";
  }
  $timenav .= " </select>\n";
  $timenav .= "</form>\n";

  return $timenav;
}

sub generate_style_selector {
  my ($style, $baseurl, $where) = @_;
  if (defined($where) && $where) {
    $where = '-'.$where;
  } else {
    $where = '';
  }

  my $ret = "<form method='GET' class='stylenavform stylenavform$where'>\n";
  $ret .= " <select name='style' onchange=\"window.location='" . url_sans_param($baseurl, 'style') . "&style='+this.options[this.selectedIndex].value;\" title=\"Style selector\">\n";
  my @styles = ('full: Fat style', 'brief: Brief style', 'pivot: Pivot style');
  foreach my $cur(@styles) {
      my ($value, $desc) = split(/: /, $cur, 2);
      $ret .= "  <option value='$value'".($value eq $style ? ' selected' : '').">$desc</option>\n";
  }
  $ret .= " </select>\n";
  $ret .= "</form>\n";
  return $ret;
}

sub generate_status_filter {
  my ($status_filter, $baseurl, $where) = @_;
  my $status_filter_str = join(',', @{$status_filter});
  if (defined($where) && $where) {
    $where = '-'.$where;
  } else {
    $where = '';
  }

  my $ret = "<form method='GET' class='statusfilterform statusfilterform$where'>\n";
  $ret .= " <select name='sts' onchange=\"window.location='" . url_sans_param($baseurl, 'sts') . "&sts='+this.options[this.selectedIndex].value;\" title=\"Status filter selector\">\n";
  my @styles = ('0: All statuses',
                '-304: Omit skipped builds (304)',
                '200: Only failures (200)',   # 200..299, but only 200 is used afaict.
                );
  foreach my $cur(@styles) {
      my ($value, $desc) = split(/: /, $cur, 2);
      $ret .= "  <option value='$value'".($value eq $status_filter_str ? ' selected' : '').">$desc</option>\n";
  }
  $ret .= " </select>\n";
  $ret .= "</form>\n";
  return $ret;
}

sub insert_dynamic_data {
  my ($str, $tree, $sheriff, $build_engineer, $cvs_co_date, $status, $patch_str, $start_time, $end_time, $interval,
      $style, $baseurl, $status_filter, $static_page) = @_;
  my $now = time;

  $str =~ s/#TREE#/$tree/g;
  my $time = time2str("%c %Z", $now);
  $str =~ s/#TIME#/$time/g;
  $str =~ s/#SHERIFF#/$sheriff/g;
  $str =~ s/#BUILD_ENGINEER#/$build_engineer/g;
  $cvs_co_date = 'HEAD' if !$cvs_co_date;
  $str =~ s/#CVS_CO_DATE#/$cvs_co_date/g;
  $str =~ s/#STATUS#/$status/g;
  $str =~ s/#START_TIME_MINUS\((\d+)\)#/$start_time - $1/eg;
  $str =~ s/#END_TIME#/$end_time/g;
  $str =~ s/#PAGE#/showbuilds.pl/g;
  if ($now - $end_time < 60) {
    $str =~ s/#IS_NOW#/1/g;
  } else {
    $str =~ s/#IS_NOW#/0/g;
  }
  $str =~ s/#STYLE#/$style/g;
  $str =~ s/#BASEURL\((\w+),(\w+)\)#/url_sans_param(url_sans_param($baseurl,$1),$2)/ge;
  $str =~ s/#BASEURL\((\w+)\)#/url_sans_param($baseurl,$1)/ge;
  $str =~          s/#TIMENAV#/generate_time_nav($tree,$now,$start_time,$end_time,$interval,$style,$baseurl,$static_page)/ge;
  $str =~ s/#TIMENAV\((\w+)\)#/generate_time_nav($tree,$now,$start_time,$end_time,$interval,$style,$baseurl,$static_page,$1)/ge;
  $str =~          s/#STYLE_SELECTOR#/generate_style_selector($style,$baseurl)/ge;
  $str =~ s/#STYLE_SELECTOR\((\w+)\)#/generate_style_selector($style,$baseurl,$1)/ge;
  $str =~          s/#STATUS_FILTER#/generate_status_filter($status_filter,$baseurl)/ge;
  $str =~ s/#STATUS_FILTER\((\w+)\)#/generate_status_filter($status_filter,$baseurl,$1)/ge;

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

sub print_tree {
  my ($p, $dbh, $fh, $tree, $start_time, $end_time, $field_short_names,
      $field_processors, $field_handlers, $min_row_size, $max_row_size,
      $patch_str, $style, $include_ids, $exclude_ids, $status_filter) = @_;

  # Get the information we will be laying out in the table
  my @event_queues;
  push @event_queues, new Tinderbox3::BuildTimeColumn($p, $dbh);
  push @event_queues, Tinderbox3::BonsaiColumns::get_bonsai_column_queues($p, $dbh, $start_time, $end_time, $tree);
  push @event_queues, Tinderbox3::TreeColumns::get_tree_column_queues($p, $dbh, $start_time, $end_time, $tree, $field_short_names,
                                                                      $field_processors, $field_handlers, $patch_str,
                                                                      $style, $include_ids, $exclude_ids, $status_filter);

  #
  # Figure out now many rows we'll be needing
  #
  my $empty_value = $end_time + 3600*24*365;
  if ($empty_value < $end_time) {
     die "Unexpected time wraparound: $end_time";
  }
  my @first_event_times = [-1];
  for (my $idx = 1; $idx < @event_queues; $idx++) {
    my $queue = $event_queues[$idx];
    if (!$queue->is_empty()) {
      push @first_event_times, $queue->first_event_time();
    } else {
      push @first_event_times, $empty_value;
    }
  }

  my $row_num = -1;
  my @rows;
  my $most_recent_queue = -1;
  my $most_recent_time = $empty_value;
  EVENTLOOP:
  while (1) {
    #
    # Get the oldest event from a queue
    #
    my ($event_time, $event, $please_split);
    my $column;
    {
      for (my $queue_num = @first_event_times - 1; $queue_num >= 1; $queue_num--) {
        my $fet = $first_event_times[$queue_num];
        if ($fet < $most_recent_time) {
          $most_recent_time = $fet;
          $most_recent_queue = $queue_num;
        }
      }
      # Break if there were no non-empty queues
      if ($most_recent_time == $empty_value) {
        last EVENTLOOP;
      }
      my $queue = $event_queues[$most_recent_queue];
      ($event_time, $event, $please_split) = $queue->pop_first();
      if ($event_time != $most_recent_time) {
        die "Event time not what was expected!";
      }
      if (!$queue->is_empty()) {
        $most_recent_time = $first_event_times[$most_recent_queue] = $queue->first_event_time();
      } else {
        $most_recent_time = $first_event_times[$most_recent_queue] = $empty_value;
      }
      $column = $most_recent_queue;
    }

    #
    # If there are no rows yet, create the first row with this event time
    #
    if ($row_num == -1) {
      push @rows, [ $event_time ];
      $row_num++;
    } else {
      #
      # If event is outside the maximum boundary, start adding rows of
      # max_row_size to compensate
      #
      # XXX potential problem: one really wants cells to start at events
      # whenever possible, and when we use this algorithm, if the event in
      # question happens to be inside the minimum row time, we will not split
      # for it so the cell will not start at the event.  This can be compensated
      # for by building these new cells *down* from the cell in question, but
      # it would require more strange cases than I care to deal with right now
      # so I'm not coding it.  JBK
      #
      if ($max_row_size > 0) {
        while ($event_time > ($rows[$row_num][0] + $max_row_size)) {
          push @rows, [ $rows[$row_num][0] + $max_row_size ];
          $row_num++;
        }
      }

      #
      # If event has asked to split, and is outside the minimum boundary (so
      # that we *can* split, split the row.
      #
      if ($please_split && $event_time > ($rows[$row_num][0] + $min_row_size)) {
        push @rows, [ $event_time ];
        $row_num++;
      }
    }

    #
    # Finally, add the event to the current row.
    #
    push @{$rows[$row_num][$column]}, $event;
  }

  #
  # Ensure there is at least one row
  #
  if ($row_num < 0) {
    push @rows, [ $start_time ];
    $row_num++;
  }

  #
  # Add extra rows if the tinderbox does not go up to the end time
  #
  if ($max_row_size > 0) {
    while ($end_time > ($rows[$row_num][0] + $max_row_size)) {
      push @rows, [ $rows[$row_num][0] + $max_row_size ];
      $row_num++;
    }
  }

  #
  # Add extra rows if the tinderbox does not start at the start time
  #
  if ($start_time < $rows[0][0]) {
    if ($max_row_size > 0) {
      do {
        unshift @rows, [ $rows[0][0] - $max_row_size ];
      } while ($start_time < $rows[0][0]);
      # Fix the last row to be start time ;)
      if ($rows[0][0] < $start_time) {
        $rows[0][0] = $start_time;
      }
    } else {
      unshift @rows, [ $start_time ];
    }
  }

  #
  # Print the table.
  #
  print $fh "<form method='GET' id='group-action-form'>\n";
  print $fh "<table class='tinderbox tinderbox-$style'>\n";
  if ($style eq 'pivot') {
    for (my $queue_num = 0; $queue_num < @event_queues; $queue_num++) {
      print $fh "<tr>\n";
      print $fh $event_queues[$queue_num]->column_header(\@rows, $queue_num, $style);
      print $fh $event_queues[$queue_num]->column_header_2(\@rows, $queue_num, $style);
      for (my $row_num = (@rows - 1); $row_num >= 0; $row_num--) {
        print $fh $event_queues[$queue_num]->cell(\@rows, $row_num, $queue_num, $style);
      }
      print $fh "</tr>\n";
    }
  } else {
    #
    # Print head of table
    #
    print $fh "<thead><tr>\n";
    for (my $queue_num = 0; $queue_num < @event_queues; $queue_num++) {
      print $fh $event_queues[$queue_num]->column_header(\@rows, $queue_num, $style);
    }
    print $fh "</tr>\n";

    print $fh "<tr>\n";
    for (my $queue_num = 0; $queue_num < @event_queues; $queue_num++) {
      print $fh $event_queues[$queue_num]->column_header_2(\@rows, $queue_num, $style);
    }
    print $fh "</tr></thead>\n";

    #
    # Print body of table
    #
    print $fh "<tbody>\n";
    for(my $row_num = (@rows - 1); $row_num >= 0; $row_num--) {
      print $fh "<tr>";
      for (my $queue_num = 0; $queue_num < @event_queues; $queue_num++) {
        print $fh $event_queues[$queue_num]->cell(\@rows, $row_num, $queue_num, $style);
      }
      print $fh "</tr>\n";
    }
    print $fh "</tbody>\n";
  }
  print $fh "</table>\n";
  print $fh "</form>\n";
}

1
