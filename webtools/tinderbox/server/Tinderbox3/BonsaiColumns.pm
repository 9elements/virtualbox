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

package Tinderbox3::BonsaiColumns;

use strict;

use Tinderbox3::Util;
use Tinderbox3::FieldProcessors::BuildRev;
use Tinderbox3::FieldProcessors::RevAuthor;
use Date::Format;
use CGI qw/-oldstyle_urls/;

sub new {
        my $class = shift;
        $class = ref($class) || $class;
        my $this = {};
        bless $this, $class;

  my ($start_time, $end_time, $bonsai_id, $display_name, $bonsai_url, $module, $branch,
      $directory, $cvsroot) = @_;
  $this->{START_TIME} = $start_time;
  $this->{END_TIME} = $end_time;
  $this->{BONSAI_ID} = $bonsai_id;
  $this->{DISPLAY_NAME} = $display_name;
  $this->{BONSAI_URL} = $bonsai_url;
  $this->{MODULE} = $module;
  $this->{BRANCH} = $branch;
  $this->{DIRECTORY} = $directory;
  $this->{CVSROOT} = $cvsroot;

  $this->{EVENTS} = [];

  return $this;
}

sub first_event_time {
  my $this = shift;
  return $this->{EVENTS}[0]{checkin_date};
}

sub pop_first {
  my $this = shift;
  return ($this->{EVENTS}[0]{checkin_date}, shift @{$this->{EVENTS}}, 0);
}

sub is_empty {
  my $this = shift;
  return @{$this->{EVENTS}} ? 0 : 1;
}

sub column_header {
  my $this = shift;
  return "<th>$this->{DISPLAY_NAME}</th>";
}

sub column_header_2 {
#  return "<td>Click on a name to see what they did</td>";
  return "<td></td>";
}

sub _escape {
  my ($str) = @_;
  $str =~ s/(['"<>\\])/\\$1/g;
  return $str;
}

sub cell {
  my $this = shift;
  my ($rows, $row_num, $column, $style) = @_;
  my $cell = $rows->[$row_num][$column];

  my $str;
  if (defined($cell)) {
    $str = "<td class=checkin>";
    foreach my $event (@{$cell}) {
      my $cur;
      if ($event->{vcstype} eq 'svn') {
        #my $bonsai_url = $this->{BONSAI_URL} . $event->{revision};
        my $who = Tinderbox3::FieldProcessors::RevAuthor::static_process_field($event->{who}, 'pivot');
        $cur  = "\n".Tinderbox3::FieldProcessors::BuildRev::static_process_field($event->{revision}, 'full',
                                                                                 ' '.$who);
      } else {
        my $checkin_date_str = time2str('%D %H:%M', $event->{checkin_date});
        my $who = $event->{who};
        $who =~ s/%.+//g;
        my $who_email = $event->{who};
        $who_email =~ s/%/\@/g;
        my $bonsai_url = $this->build_bonsai_url($event->{checkin_date} - 7*60, $event->{checkin_date}, $event->{who});
        my $popup_str = <<EOM;
  <a href='mailto:$who_email'>$who_email</a><br>
  <a href='$bonsai_url'>View Checkin</a> (+$event->{size_plus}/-$event->{size_minus}) $checkin_date_str<br>
  $event->{description}
EOM
        $cur = "\n<a href='$bonsai_url' onclick='return do_popup(event, \"cvs\", \"" . escape_html(escape_js($popup_str)) . "\")'>$who</a> ";
      }
      # don't repeat ourselves. imports ends up with a lot's of similar stuff for instance.
      $str .= $cur if (index($str,$cur) < 0);
    }
  } else {
    $str = "<td>";
  }

  $str .= "</td>";
  return $str;
}

sub build_bonsai_url {
  my $this = shift;
  my ($start_date, $end_date, $who) = @_;
  return "$this->{BONSAI_URL}/cvsquery.cgi?module=$this->{MODULE}&branch=$this->{BRANCH}&dir=$this->{DIRECTORY}&cvsroot=$this->{CVSROOT}&date=explicit&mindate=$start_date&maxdate=$end_date" . ($who ? "&who=" . escape_url($who) : "");
}

sub get_bonsai_column_queues {
  my ($p, $dbh, $start_time, $end_time, $tree) = @_;

  #
  # Get the list of bonsai installs
  #
  my %columns;
  my $count_svn = 0;
  my $count_bonsai = 0;
  my $sth = $dbh->prepare("SELECT bonsai_id, display_name, bonsai_url, module, branch, directory, cvsroot FROM tbox_bonsai WHERE tree_name = ?");
  $sth->execute($tree);
  while (my $row = $sth->fetchrow_arrayref) {
    $columns{$row->[0]} = new Tinderbox3::BonsaiColumns($start_time, $end_time, @{$row});
    if ($row->[6] eq 'subversion') {
      $count_svn += 1;
    } else {
      $count_bonsai += 1;
    }
  }

  if (keys %columns) {
    #
    # Fill in the bonsais with data
    #
    if ($count_bonsai > 0 && $count_svn == 0) {
      $sth = $dbh->prepare("
        SELECT bonsai_id,
               " . Tinderbox3::DB::sql_get_timestamp("checkin_date") . ",
               who,
               files,
               revisions,
               size_plus,
               size_minus,
               description
          FROM tbox_bonsai_cache
         WHERE checkin_date >= " . Tinderbox3::DB::sql_abstime("?") . "
           AND checkin_date <= " . Tinderbox3::DB::sql_abstime("?") . "
           AND bonsai_id IN (" . join(', ', map { "?" } keys %columns) . ")
         ORDER BY checkin_date");
      $sth->execute($start_time, $end_time, map { $_->{BONSAI_ID} } values %columns);
      while (my $row = $sth->fetchrow_arrayref) {
        push @{$columns{$row->[0]}{EVENTS}}, {
          vcstype => 'cvs', checkin_date => $row->[1], who => $row->[2], files => $row->[3],
          revisions => $row->[4], size_plus => $row->[5], size_minus => $row->[6],
          description => $row->[7]
        };
      }
    } elsif ($count_bonsai == 0 && $count_svn > 0) {
      # The convoluted sql_abstime_tz() stuff causes postgres to fetch all
      # entries in the table with matching sRepository, then locally do the
      # tsCreated filtering (>300ms on a fast machine).
      # So, instead we simplify the tsCreated limits before doing the query.
      my $converted = $dbh->selectrow_arrayref("SELECT ". Tinderbox3::DB::sql_abstime_tz("?")
                                                  . "," . Tinderbox3::DB::sql_abstime_tz("?"),
                                               undef, $start_time, $end_time);
      my $conv_start_time = $converted->[0];
      my $conv_end_time = $converted->[1];

      #if ($count_svn == 1 && 1) { # - no real speedup, so disabled for now.
      #  my $it = (values %columns)[0];
      #  my $bonsai_id = $it->{BONSAI_ID};
      #  $sth = $dbh->prepare("
      #    SELECT " . Tinderbox3::DB::sql_get_timestamp("tsCreated") . ",
      #           sAuthor,
      #           iRevision,
      #           sMessage
      #      FROM testmanager_vcs_revisions
      #     WHERE tsCreated >= ?
      #       AND tsCreated <= ?
      #       AND sRepository = ?
      #     ORDER BY iRevision");
      #  $sth->execute($conv_start_time, $conv_end_time, $it->{MODULE});
      #
      #  while (my $row = $sth->fetchrow_arrayref) {
      #    push @{$columns{$bonsai_id}{EVENTS}}, {
      #      vcstype => 'svn', checkin_date => $row->[0], who => $row->[1],
      #      revision => $row->[2], description => $row->[3]
      #    };
      #  }
      #} else
      {
        $sth = $dbh->prepare("
          SELECT CASE " . join(' ', map { "WHEN sRepository = ? THEN " . $_ } keys %columns) . "
                      ELSE -1
                 END,
                 " . Tinderbox3::DB::sql_get_timestamp("tsCreated") . ",
                 sAuthor,
                 iRevision,
                 sMessage
            FROM testmanager_vcs_revisions
           WHERE tsCreated >= ?
             AND tsCreated <= ?
             AND sRepository IN (" . join(', ', map { "?" } keys %columns) . ")
           ORDER BY iRevision");
        my @args;
        push @args, map { $_->{MODULE} } values %columns;
        push @args, $conv_start_time;
        push @args, $conv_end_time;
        push @args, map { $_->{MODULE} } values %columns;
        $sth->execute(@args);

        while (my $row = $sth->fetchrow_arrayref) {
          push @{$columns{$row->[0]}{EVENTS}}, {
            vcstype => 'svn', checkin_date => $row->[1], who => $row->[2],
            revision => $row->[3], description => $row->[4]
          };
        }
      }
    }
  }

  return sort { $a->{DISPLAY_NAME} cmp $b->{DISPLAY_NAME} } values %columns;
}

1
