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

package Tinderbox3::BuildTimeColumn;

use strict;
use Date::Format;

sub new {
        my $class = shift;
        $class = ref($class) || $class;
        my $this = {};
        bless $this, $class;

  my ($p, $dbh) = @_;

  return $this;
}

sub column_header {
  return "<th>Build Time</th>";
}

sub column_header_2 {
  my $this = shift;
  my ($rows, $column, $style) = @_;
  my $ret = '<th>';
  $ret .= '<input type="checkbox" onclick=\'return toggle_check_boxes(this,"group_action_checkbox");\'/><br>'."\n";
  $ret .= '<select class="group-action-combo-'.$style.'" title="Group actions and filtering"';
  $ret .= ' onchange=\'return group_action_combo_changed(this, "group_action_checkbox");\'>';
  $ret .= '<option value="" disabled selected hidden>';
  if ($style eq 'brief') {
    $ret .= 'Do';
  } else {
    $ret .= 'Action';
  }
  $ret .= '</option>';
  $ret .= '<optgroup label="Commands">';
  $ret .= '<option value="kick">Issue "kick" command to all selected boxes</option>';
  $ret .= '<option value="build">Issue "build" command to all selected boxes</option>';
  $ret .= '<option value="clobber">Issue "clobber" command to all selected boxes</option>';
  $ret .= '<option value="cleanup">Issue "cleanup" command to all selected boxes</option>';
  $ret .= '<option value="cleanup_build">Issue "cleanup,build" commands to all selected boxes</option>';
  $ret .= '<option value="cleanup_clobber">Issue "cleanup,clobber" commands to all selected boxes</option>';
  $ret .= '<option value="clear">Clear all pending commands on the selected boxes</option>';
  $ret .= '</optgroup>';
  $ret .= '<optgroup label="Filtering">';
  $ret .= '<option value="view_only">Only show results for selected boxes</option>';
  $ret .= '<option value="view_omit">Omit the selected boxes from the results</option>';
  $ret .= '<option value="view_all">View results for all boxes</option>';
  $ret .= '</optgroup>';
  $ret .= '<optgroup label="Advanced Selection">';
  $ret .= '<option value="select_os_WINNT"          >Select Windows build boxes</option>';
  $ret .= '<option value="select_os_Linux"          >Select Linux build boxes</option>';
  $ret .= '<option value="select_os_Darwin"         >Select macOS build boxes</option>';
  $ret .= '<option value="select_os_SunOS"          >Select Solaris build boxes</option>';
  $ret .= '<option value="select_type_Clobber"      >Select "clobbering" build boxes</option>';
  $ret .= '<option value="select_type_Incremental"  >Select "depend" (incremental) build boxes</option>';
  $ret .= '<option value="unselect_os_WINNT"        >Unselect Windows build boxes</option>';
  $ret .= '<option value="unselect_os_Linux"        >Unselect Linux build boxes</option>';
  $ret .= '<option value="unselect_os_Darwin"       >Unselect macOS build boxes</option>';
  $ret .= '<option value="unselect_os_SunOS"        >Unselect Solaris build boxes</option>';
  $ret .= '<option value="unselect_type_Clobber"    >Unselect "clobbering" build boxes</option>';
  $ret .= '<option value="unselect_type_Incremental">Unselect "depend" (incremental) build boxes</option>';
  $ret .= '</optgroup>';
  $ret .= '</select>';
  return $ret . '</th>';
}

sub cell {
  my $this = shift;
  my ($rows, $row_num, $column, $style) = @_;
  my $class;
  if (time2str("%H", $rows->[$row_num][$column]) % 2 == 1) {
    $class = "time";
  } else {
    $class = "time_alt";
  }
  if ($style eq 'brief') {
      return "<td class=$class>" . time2str("%m-%d %H:%M", $rows->[$row_num][$column]) . "</td>";
  }
  return "<td class=$class>" . time2str("%D %R", $rows->[$row_num][$column]) . "</td>";
}

1

