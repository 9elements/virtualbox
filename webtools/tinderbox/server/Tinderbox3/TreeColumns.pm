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

package Tinderbox3::TreeColumns;

use strict;

use Date::Format;
use Tinderbox3::Util;
use CGI::Carp qw/fatalsToBrowser/;
use Time::HiRes qw( gettimeofday tv_interval );

sub new {
        my $class = shift;
        $class = ref($class) || $class;
        my $this = {};
        bless $this, $class;

  my ($start_time, $end_time, $tree, $field_short_names, $field_processors,
      $field_handlers, $patch_str,
      $machine_id, $machine_name, $os, $os_version, $compiler, $clobber, $visible, $commands, $description, $script_rev) = @_;

  $this->{START_TIME} = $start_time;
  $this->{END_TIME} = $end_time;
  $this->{TREE} = $tree;
  $this->{TREE_JS_HTML} = escape_html(escape_js($tree));
  $this->{FIELD_SHORT_NAMES} = $field_short_names;
  $this->{FIELD_PROCESSORS} = $field_processors;
  $this->{FIELD_HANDLERS} = $field_handlers;
  $this->{MACHINE_ID} = $machine_id;
  $this->{MACHINE_NAME} = $machine_name;
  $this->{MACHINE_NAME_HTML} = escape_html($machine_name);
  $this->{MACHINE_NAME_JS_HTML} = escape_html(escape_js($machine_name));
  $this->{OS} = $os;
  $this->{OS_VERSION} = $os_version;
  $this->{COMPILER} = $compiler;
  $this->{CLOBBER} = $clobber;
  $this->{PATCH_STR} = $patch_str;
  $this->{COMMANDS} = $commands;
  $this->{DESCRIPTION} = $description;
  $this->{SCRIPT_REV} = $script_rev;

  $this->{AT_START} = 1;
  $this->{STARTED_PRINTING} = 0;
  $this->{PROCESSED_THROUGH} = 0x40000000; # 1G, unlikely to have more rows than that.

  return $this;
}

sub check_boundaries {
  my $this = shift;
  my ($time) = @_;
  if ($time < $this->{START_TIME}) {
    return $this->{START_TIME};
  }
  if ($time > $this->{END_TIME}) {
    return $this->{END_TIME};
  }
  return $time;
}

sub add_event {
  my $this = shift;
  my ($event) = @_;
  # "Fix" the previous event if it ended after this one began
  if (defined($this->{EVENTS}) && scalar(@{$this->{EVENTS}})) {
    if ($this->{EVENTS}[@{$this->{EVENTS}} - 1]{status_time} >
        $event->{build_time}) {
      $this->{EVENTS}[@{$this->{EVENTS}} - 1]{status_time} = $event->{build_time};
    }
  }
  push @{$this->{EVENTS}}, $event;
}

sub first_event_time {
  my $this = shift;
  # bird: Called a lot (52531 for a random 24h trunk period), so inline the boundrary check.
  # bird: Update it _was_ called a lot, it is now called once for every event, 1246 in the previous case.
  #my ($event) = @_;
  #return $this->check_boundaries($this->{AT_START} ?
  #                               $this->{EVENTS}[0]{build_time} :
  #                               $this->{EVENTS}[0]{status_time});
  my $time = $this->{AT_START} ? $this->{EVENTS}[0]{build_time} : $this->{EVENTS}[0]{status_time};
  my $tmp = $this->{START_TIME};
  if ($time >= $tmp) {
    $tmp = $this->{END_TIME};
    if ($time <= $tmp) {
      return $time;
    }
  }
  return $tmp;
}

sub pop_first {
  my $this = shift;
  my $event = $this->{EVENTS}[0];
  if ($this->{AT_START}) {
    $this->{AT_START} = 0;
    return ($this->check_boundaries($event->{build_time}), [$event, 1], 1);
  } else {
    shift @{$this->{EVENTS}};
    $this->{AT_START} = 1;
    return ($this->check_boundaries($event->{status_time}), [$event, 0], 0);
  }
}

sub is_empty {
  my $this = shift;
  return !defined($this->{EVENTS}) || !scalar(@{$this->{EVENTS}});
}

sub machine_title {
    my $this = shift;
    my $title = "name: \t".$this->{MACHINE_NAME}." (#".$this->{MACHINE_ID}.")&#10;";
    $title   .= "desc: \t".$this->{DESCRIPTION}."&#10;";
    $title   .= "os:   \t".$this->{OS}."&#10;";
    $title   .= "ver:  \t".$this->{OS_VERSION}."&#10;";
    $title   .= "type: \t".($this->{CLOBBER} ? 'Clobber' : 'Incremental')."&#10;";
    $title   .= "rev:  \t".($this->{SCRIPT_REV} || "")."&#10;";
    $title   .= "cmds: \t".($this->{COMMANDS} || "");
    return escape_html($title);
}

sub column_header {
  my $this = shift;
  my ($rows, $column, $style) = @_;
  # Get the status from the first column
  my $class = "";
  for (my $row=0; $row < @{$rows}; $row++) {
    my $col = $rows->[$row][$column];
    if (defined($col)) {
      for (my $i=@{$col} - 1; $i >= 0; $i--) {
        # Ignore "incomplete" status and pick up first complete status to show
        # state of entire tree
        if ($col->[$i][0]{status} >= 100 && $col->[$i][0]{status} < 300) {
          $class = " class=status" . $col->[$i][0]{status};
          last;
        }
      }
    }
  }

  my $title = $this->machine_title();
  if ($style eq 'brief' || $style eq 'pivot') {
      my $name = $this->{MACHINE_NAME};
      if (length($name) >= 6 && index($name, '-') == -1 && $style ne 'pivot') {
          $name =~ s/dep/-dep/;
          $name =~ s/ose/-ose/;
          $name =~ s/check/-check/;
          $name =~ s/extpacks/ext-packs/;
          $name =~ s/testsuite/valkit/;
          $name =~ s/ub(\d+)/ub-$1/;
      }
      if ($style eq 'pivot') {
         return "<th$class title='$title' nowrap>$name</th>";
      }
      return "<th$class title='$title'>$name</th>";
  }
  return "<th$class title='$title'>$this->{MACHINE_NAME} $this->{OS} $this->{OS_VERSION} @{[$this->{CLOBBER} ? 'Clbr' : 'Dep']}</th>";
}

sub column_header_2 {
  my $this = shift;
  my ($rows, $column, $style) = @_;

  my $ret = "<th class='colhdr2-$style'";
  if ($style eq 'pivot') {
    $ret .= ' nowrap>';
  } else {
    $ret .= '>';
  }

  my $title = $this->machine_title(); # Note! The title attribute is important as input for the advanced selection actions!
  $ret .= '<input type="checkbox" name="id" value="'.$this->{MACHINE_ID}.'" class="group_action_checkbox" title="'.$title.'"/>';
  if ($style ne 'pivot') {
    $ret .= '<br>';
  }

  if ($style eq 'brief') {
    $ret .= "<a href='adminmachine.pl?machine_id=$this->{MACHINE_ID}'>E</a> ";
    $ret .= "<a href='adminmachine.pl?action=kick_machine&machine_id=$this->{MACHINE_ID}'>K</a>";
  } else {
    $ret .= "<a href='adminmachine.pl?machine_id=$this->{MACHINE_ID}'>Edit</a>";
    $ret .= " <a href='adminmachine.pl?action=kick_machine&machine_id=$this->{MACHINE_ID}'>Kick</a>";
  }
  ## @todo add 'Build' command.

  $ret .= '</th>';
  return $ret;
}

sub cell {
  my $this = shift;
  my ($rows, $row_num, $column, $style) = @_;

  my $cell = $rows->[$row_num][$column];

  my $tdtitle = ' title="'. $this->{MACHINE_NAME_HTML} . '"';

  #
  # If this is the first time cell() has been called, we look for the real
  # starting row, and if it has an in-progress status, we move the end event
  # into the current cell so it shows continuous like it should.
  #
  if (!$this->{STARTED_PRINTING}) {
    if (!defined($cell)) {
      for (my $i = $row_num-1; $i >= 0; $i--) {
        if (defined($rows->[$i][$column])) {
          my $last_event = @{$rows->[$i][$column]} - 1;
          if ($rows->[$i][$column][$last_event][0]{status} < 100) {
            # Take the top event from that cell and put it in this one
            push @{$cell}, pop @{$rows->[$i][$column]};
            if (!@{$rows->[$i][$column]}) {
              $rows->[$i][$column] = undef;
            }
            last;
          }
        }
      }
    }
    # XXX uncomment for debug
    if (defined($cell)) {
      # die if it is a start cell
      if ($cell->[@{$cell} - 1][1]) {
        die "Start cell without end cell found!";
      }
    }
    # XXX end debug

    $this->{STARTED_PRINTING} = 1;
  }

  #
  # Print the cell
  #
  if (defined($cell)) {
    #
    # If the last event in this cell is an end event, we print a td all the way
    # down to and including the corresponding start cell.
    #
    # XXX If there is a start/end/start[/end] situation, print the other
    # start/end as well
    #
    my $top_event_info = $cell->[@{$cell} - 1];
    my ($top_event, $top_is_start) = @{$top_event_info};
    my $retval = "";
    if (!$top_is_start) {
      # Search for the start tag (only need to search if the end tag is the only
      # one in this cell)
      my $rowspan;
      if (@{$cell} == 1) {
        my $i;
        for ($i = $row_num - 1; $i >= 0; $i--) {
          if (defined($rows->[$i][$column])) {
            last;
          }
        }
        $rowspan = $row_num - $i + 1;
        # XXX uncomment to debug
        if ($i == -1) {
          die "End tag without start tag found!";
        }
        # XXX end debug
      } else {
        $rowspan = 1;
      }

      my $br;
      $retval = "<td class='status$top_event->{status}'";
      if ($style eq 'pivot') {
        $retval .= ($rowspan == 1 ? "" : " colspan=$rowspan") . $tdtitle . ' nowrap>';
        $br = "\n";
      } else {
        $retval .= ($rowspan == 1 ? "" : " rowspan=$rowspan") . $tdtitle . '>';
        $br = "<br>\n";
      }

      # Print "L" (log and add comment)
      # ASSUMES sane log filename.  Don't want to waste time in escape_js_and_sq_html!
      $retval .= "<a href='showlog.pl?machine_id=$this->{MACHINE_ID}&logfile=$top_event->{logfile}' "
               . "onclick='return do_L_popup(event,\"$this->{TREE_JS_HTML}\",\"$this->{MACHINE_NAME_JS_HTML}\",$this->{MACHINE_ID},"
               . "$top_event->{build_time},\"$top_event->{logfile}\");'>L</a>\n";

      # Print comment star
      if (defined($top_event->{comments}) && @{$top_event->{comments}} > 0) {
        my $popup_str = "<strong>Comments</strong> (<a href='buildcomment.pl?tree=$this->{TREE}&machine_id=$this->{MACHINE_ID}&build_time=$top_event->{build_time}'>Add Comment</a>)$br";
        foreach my $comment (sort { $b->[2] <=> $a->[2] } @{$top_event->{comments}}) {
          $popup_str .= "<a href='mailto:$comment->[0]'>$comment->[0]</a> - " . time2str("%H:%M", $comment->[2]) .
                        "$br<p><code>$comment->[1]</code></p>";
        }

        $retval .= "<a href='#' onclick='return do_popup(event, \"comments\", \"" . escape_js_and_sq_html($popup_str) . "\")'><img src='star.gif'></a>\n";
      }

      $retval .= "$br\n";

      {
        my $build_time = ($top_event->{status_time} - $top_event->{build_time});
        my $build_time_str = "";
        if ($build_time > 60*60) {
          $build_time_str .= int($build_time / (60*60)) . "h";
          $build_time %= 60*60;
        }
        if ($build_time > 60) {
          $build_time_str .= int($build_time / 60) . "m";
          $build_time %= 60;
        }
        if (!$build_time_str) {
          $build_time_str = $build_time . "s";
        }
        if ($style eq 'brief' || $style eq 'pivot') {
          $retval .= "$build_time_str\n";
        } else {
          $retval .= "<b>Time:</b> $build_time_str$br\n";
        }
      }
      if ($top_event->{status} != 100) {
        if ($style eq 'brief' || $style eq 'pivot') {
          $retval .= "$br<b>$top_event->{status}</b>\n";
        } else {
          $retval .= "<b>Status:</b> $top_event->{status}$br\n";
        }
      }
      foreach my $field (@{$top_event->{fields}}) {
        my $processor = $this->{FIELD_PROCESSORS}{$field->[0]};
        $processor = "URL" if !$processor && $field->[0] =~ /-(vob|png)$/;
        $processor = "default" if !$processor;
        my $handler = $this->{FIELD_HANDLERS}{$processor};
        my $short = $this->{FIELD_SHORT_NAMES}{$field->[0]} || $field->[0];
        my $str = $handler->process_field($this, $short, $field->[1], $style, $field->[0]);
        if ($style eq 'brief') {
          $retval .= $br . $str;
        } else {
          $retval .= " " . $str;
        }
      }
      $retval .= "</td>";

      $this->{PROCESSED_THROUGH} = $row_num - $rowspan + 1;
    }

    #
    # If there are multiple events in the cell and the first event is an end
    # event, we move it into the next cell so it will be printed there.
    #
    if (@{$cell} > 1 && !$cell->[0][1]) {
      # XXX uncomment to debug
      if ($row_num == 0) {
        die "End tag without start tag found!";
      }
      # XXX end debug
      push @{$rows->[$row_num-1][$column]}, shift @{$cell};
    }

    return $retval;
  }
  if ($row_num < $this->{PROCESSED_THROUGH}) { # Note! $row_num is decreasing.
    # Print empty cell large enough to cover empty rows
    my $i;
    for ($i = $row_num-1; $i >= 0; $i--) {
      if (defined($rows->[$i][$column])) {
        last;
      }
    }
    $this->{PROCESSED_THROUGH} = $i + 1;
    if (($row_num - $i) > 1) {
      if ($style eq 'pivot') {
          return '<td colspan=' . ($row_num - $i) . "$tdtitle></td>\n";
      }
      return '<td rowspan=' . ($row_num - $i) . "$tdtitle></td>\n";
    }
    return "<td$tdtitle></td>\n";
  }
  return "";
}


#
# Method to get a the TreeColumns objects for a tree
#
sub get_tree_column_queues {
  my ($p, $dbh, $start_time, $end_time, $tree, $field_short_names, $field_processors, $field_handlers, $patch_str,
      $style, $include_ids, $exclude_ids, $status_filter) = @_;
  #
  # Get the list of machines
  #
  #my $t0 = [gettimeofday];
  my $sql = "
    SELECT machine_id, machine_name, os, os_version, compiler, clobber, visible, commands, description, script_rev
      FROM tbox_machine
     WHERE tree_name = ?";

  if (@{$include_ids}) {
      $sql .= "\n       AND machine_id IN (".join(',', @{$include_ids}).')';
  }
  if (@{$exclude_ids}) {
      $sql .= "\n       AND machine_id NOT IN (".join(',', @{$exclude_ids}).')';
  }

  my $sth = $dbh->prepare($sql);
  $sth->execute($tree);
  #my $elapsed = tv_interval ($t0);
  #print "<!-- columns $elapsed -->\n";

  my %columns;
  while (my $row = $sth->fetchrow_arrayref) {
    $columns{$row->[0]} = new Tinderbox3::TreeColumns($start_time, $end_time, $tree, $field_short_names, $field_processors, $field_handlers, $patch_str, @{$row});
  }

  if (!keys %columns) {
    return ();
  }

  #
  # Dump the relevant events into the columns
  #
  my $whereextra = "";
  my $negcount = 0;
  my $poscount = 0;
  foreach my $status(@{$status_filter}) {
    if ($status < 0) {
      if ($negcount == 0) {
        $whereextra .= ' AND b.status NOT IN (' . (-$status);
      } else {
        $whereextra .= ', ' . (-$status);
      }
      $negcount += 1;
    } elsif ($status > 0) {
      if ($poscount == 0) {
        if ($negcount > 0) {
          $whereextra .= ')';
        }
        $whereextra .= ' AND b.status IN (' . $status;
      } else {
        $whereextra .= ', ' . $status;
      }
      $poscount += 1;
    }
  }
  if ($poscount > 0 || $negcount > 0) {
    $whereextra .= ')';
  }

  # Normalize the start and end times for the DB.
  my $converted = $dbh->selectrow_arrayref("SELECT ". Tinderbox3::DB::sql_abstime("?")
                                              . "," . Tinderbox3::DB::sql_abstime("?"),
                                           undef, $start_time, $end_time);
  my $db_start_time = $converted->[0];
  my $db_end_time   = $converted->[1];

  #my $t1 = [gettimeofday];

  # Cursor #1 - builds
  $sth = $dbh->prepare(
    "SELECT b.machine_id,
            " . Tinderbox3::DB::sql_get_timestamp("b.build_time") . ",
            " . Tinderbox3::DB::sql_get_timestamp("b.status_time") . ",
            b.status,
            b.log,
            b.build_time
       FROM tbox_build b
      WHERE b.machine_id IN (" . join(", ", map { "?" } keys %columns) . ")
        AND b.status_time >= ?
        AND b.build_time  <= ?" . $whereextra . "
      ORDER BY b.build_time, b.machine_id");
  $sth->execute(keys %columns, $db_start_time, $db_end_time);

  #$elapsed = tv_interval ($t1);
  #print "<!-- SQL: " . $sth->{Statement} . "\nNUM_OF_PARAMS:" . $sth->{NUM_OF_PARAMS} ."\n";
  #my $params = $sth->{ParamValues};
  #foreach my $param (keys %{$params}) {
  #  print "$param: $params->{$param}\n";
  #}
  #print "<!-- Time Elapsed: $elapsed -->\n";
  #my $t2 = [gettimeofday];

  # Cursor #2 - build fields.
  my $sth_fields = $dbh->prepare(
    "SELECT f.machine_id,
            f.build_time,
            f.name,
            f.value
       FROM tbox_build b
            INNER JOIN tbox_build_field f
                    ON f.machine_id = b.machine_id
                   AND f.build_time = b.build_time
      WHERE b.machine_id IN (" . join(", ", map { "?" } keys %columns) . ")
        AND b.status_time >= ?
        AND b.build_time  <= ?" . $whereextra . "
      ORDER BY f.build_time, f.machine_id, f.name");
  $sth_fields->execute(keys %columns, $db_start_time, $db_end_time);
  my $field_row = $sth_fields->fetchrow_arrayref;

  # Cursor #3 - comments .
  my $sth_comments = $dbh->prepare(
    "SELECT c.machine_id,
            c.build_time,
            c.login,
            c.build_comment,
            " . Tinderbox3::DB::sql_get_timestamp("c.comment_time") ."
       FROM tbox_build b
            INNER JOIN tbox_build_comment c
                    ON c.machine_id = b.machine_id
                   AND c.build_time = b.build_time
      WHERE b.machine_id IN (" . join(", ", map { "?" } keys %columns) . ")
        AND b.status_time >= ?
        AND b.build_time  <= ?" . $whereextra . "
      ORDER BY c.build_time, c.machine_id, c.comment_time DESC");
  $sth_comments->execute(keys %columns, $db_start_time, $db_end_time);
  my $comment_row = $sth_comments->fetchrow_arrayref;

  # Combine the results for the three cursors into column events.
  while (my $build = $sth->fetchrow_arrayref) {
    my $machine_id    = $build->[0];
    my $db_build_time = $build->[5];
    my $event = {
      build_time => $build->[1], status_time => $build->[2],
      status => $build->[3], logfile => $build->[4], fields => []
    };

    while ($field_row && $field_row->[0] == $machine_id && $field_row->[1] eq $db_build_time) {
      push @{$event->{fields}}, [ $field_row->[2], $field_row->[3] ];
      $field_row = $sth_fields->fetchrow_arrayref;
    }

    while ($comment_row && $comment_row->[0] == $machine_id && $comment_row->[1] eq $db_build_time) {
      push @{$event->{comments}}, [ $comment_row->[2], $comment_row->[3], $comment_row->[4] ];
      $comment_row = $sth_comments->fetchrow_arrayref;
    }

    $columns{$machine_id}->add_event($event);
  }

  #while ($field_row) {
  #  print "<!-- wtf field: $field_row->[0]; $field_row->[1]; $field_row->[2]; $field_row->[3]; $field_row->[4] -->\n";
  #  $field_row = $sth_fields->fetchrow_arrayref;
  #}

  #$elapsed = tv_interval ($t2);
  #print "<!-- data fetch $elapsed -->\n";
  #$elapsed = tv_interval ($t0);
  #print "<!-- columns+data $elapsed -->\n";

  return sort { $a->{MACHINE_NAME} cmp $b->{MACHINE_NAME} } (map { defined($_->{EVENTS}) ? ($_) : () } values %columns);
}


1
