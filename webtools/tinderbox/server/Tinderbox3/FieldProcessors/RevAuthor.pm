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

package Tinderbox3::FieldProcessors::RevAuthor;

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
  return static_process_field($value, $style);
}

sub static_process_field {
  my ($value, $style) = @_;
  chomp $value;
  $value =~ s/^\s+|\s+$//g;
  if ($style eq 'brief' || $style eq 'pivot') {
      if ($value eq 'ramshankar') {
          $value = 'ram';
      } elsif (length($value) >= 6 && $style ne 'pivot') {
          return '<span class="revauthor-long-'.$style.'">'.$value.'</span>';
      }
      return '<span class="revauthor-'.$style.'">'.$value.'</span>';
  }
  return "[$value]";
}

1
