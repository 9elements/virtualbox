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

package Tinderbox3::Util;

use strict;
use CGI;
use Scalar::Util qw(looks_like_number); # debian: libscalar-util-numeric-perl

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(escape_html escape_js escape_js_and_sq_html escape_url dprint dprintln url_sans_param get_id_array_param);

sub escape_html {
  my ($str) = @_;
  # Many of the calls we get doesn't need any escaping.
  if ($str =~ /[><'"\n]/) {
    $str =~ s/>/&gt;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/'/&apos;/g;
    $str =~ s/"/&quot;/g;
    die if $str =~ /\n/;
  }
  return $str;
}

sub escape_js {
  my ($str) = @_;
  $str =~ s/(['"\\])/\\$1/g;
  $str =~ s/(\r?)\n/\\n/g;
  return $str;
}

# escape string for javascript embedded in a single quoted html attribute.
sub escape_js_and_sq_html {
  my ($str) = @_;
  # escape_js
  $str =~ s/(["\\])/\\$1/g;
  $str =~ s/'/\\&apos;/g;
  $str =~ s/(\r?)\n/\\n/g;
  # escape_html:
  $str =~ s/>/&gt;/g;
  $str =~ s/</&lt;/g;
  #$str =~ s/'/&apos;/g; - handled above
  #$str =~ s/"/&quot;/g; - not needed for attr='value'
  return $str;
}

sub escape_url {
  my ($str) = @_;
  $str =~ s/ /+/g;
  $str =~ s/([%&])/sprintf('%%%x', ord($1))/eg;
  return $str;
}

sub dprint {
  my ($str) = @_;
  if (open(my $log, '>>', '/tmp/tinderbox-dprint.log')) {
    open(my $log, '>>', '/tmp/tinderbox-dprint.log');
    print $log $str;
    close $log;
  }
}

sub dprintln {
  my ($str) = @_;
  if (open(my $log, '>>', '/tmp/tinderbox-dprint.log')) {
    print $log $str;
    print $log "\n";
    close $log;
  }
}

sub is_tainted {
  local $@;
  return ! eval { eval("#" . substr(join("", @_), 0, 0)); 1 };
}

# Return the given URL without any PARAM parameters.
sub url_sans_param {
  my ($url, $param) = @_;
  $url =~ s/[?&]$param=[^&]*$//;
  $url =~ s/([?&])$param=[^&]*&/$1/;
  return $url;
}

# Get an array of comment/pipe separated machine IDs, eliminating duplicates.
sub get_id_array_param {
  my ($p, $param) = @_;
  my @ret;
  my @values;
  if (exists &CGI::multi_param) {
    @values = $p->multi_param($param);
  } else {
    @values = $p->param($param);
  }
  if (@values) {
    my %hash;
    foreach my $ids(@values) {
      my @subids = split(/[,|]/, $ids);
      foreach my $id(@subids) {
        if (looks_like_number($id)) {
          $hash{$id} = 1;
        }
      }
    }
    @ret = sort (keys %hash);
  }
  return @ret;
}

1
