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

package Tinderbox3::FieldProcessors::URL;

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
  $value =~ s/http\:\/\/tindertux\.germany\.sun\.com\//\//;
  $value =~ s/http\:\/\/tindertux2\.germany\.sun\.com\//\//;
  $value =~ s/http\:\/\/tindertux\.de\.oracle\.com\//\//;
  $value =~ s/http\:\/\/tindertux2\.de\.oracle\.com\//\//;
  if (($style eq 'brief' || $style eq 'pivot') && length($field) >= 7) {
      if ($field eq 'raw_zip') {
          if (index($value, 'VBoxAll') != -1) {
              $field = 'all';
          } else {
              $field = 'rawzip';
          }
      } elsif ($field eq 'build_exe') {
          $field = 'exe';
      } elsif ($field eq 'build_zip') {
          $field = 'zip';
      } elsif ($field eq 'build_gz') {
          $field = 'tgz';
      } elsif ($field eq 'build_dmg') {
          $field = 'dmg';
      } elsif ($field eq 'build_run') {
          $field = 'run';
      } elsif ($field eq 'build_rpm') {
          $field = 'rpm';
      } elsif ($field eq 'debug_rpm') {
          $field = 'dbg';
      } elsif ($field eq 'testboxscript_zip') {
          $field = 'script';
      } elsif ($field eq 'testsuite_zip') {
          $field = 'valkit';
      } elsif ($field eq 'additions_iso') {
          $field = 'iso';
      } elsif (substr($field, 0, 11) eq 'extpack_tgz') {
        if (index($value, 'VBoxDTrace') != -1) {
            $field = 'dtrace';
        } elsif (index($value, 'ENTERPRISE') != -1) {
            $field = 'startrek';
        } else {
            $field = 'extpack';
        }
      } else {
          $field = substr($field, 0, 3).'&#x2013;'.substr($field, -3);
      }
      return '<a href="'.$value.'" title="'.$long_field.'">'.$field.'</a>';
  }
  return "<a href='$value'>$field</a>";
}

1
