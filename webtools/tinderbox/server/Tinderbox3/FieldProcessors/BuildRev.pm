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

package Tinderbox3::FieldProcessors::BuildRev;

use strict;

sub new {
        my $class = shift;
        $class = ref($class) || $class;
        my $this = {};
        bless $this, $class;

  return $this;
}

sub process_field {
  my $this = shift;
  my ($tree_columns, $field, $value, $style, $long_field) = @_;
  return static_process_field($value, $style, '');
}

sub static_process_field {
  my ($value, $style, $extra) = @_;
  my $ret = '<a href="https://linserv.de.oracle.com/vbox/log?rev='.$value.'"'
          . ' onmouseover="return svnHistoryTooltipShowEx(event,\'vbox\','.$value.',\'/testmanager/\');"'
          . ' onmouseout="return tooltipHide();">';
  if ($style eq 'brief') {
      if (length($value) > 4) {
          $ret .= '*'.substr($value, -3).$extra.'</a>';
      } else {
          $ret .= $value.$extra.'</a>';
      }
  } else {
      $ret .= 'r'.$value.$extra.'</a>';
  }
  return $ret;
}

1
