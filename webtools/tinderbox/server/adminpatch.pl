#!/usr/bin/perl -wT -I.
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

use CGI;
use Tinderbox3::Header;
use Tinderbox3::DB;
use Tinderbox3::Login;
use Date::Format;
use strict;

#
# Init
#
my $p = new CGI;
my $dbh = get_dbh();
my ($login, $cookie) = check_session($p, $dbh);

# For edit_patch
my $patch_id = Tinderbox3::DB::update_patch_action($p, $dbh, $login);

# Get patch from DB
my $patch_info = $dbh->selectrow_arrayref("SELECT tree_name, patch_name, patch_ref, patch, in_use, compile_only, submitter, " .
                                                  Tinderbox3::DB::sql_get_timestamp("submit_time") . " " .
                                          "  FROM tbox_patch " .
                                          " WHERE patch_id = ?",
                                          undef, $patch_id);
if (!defined($patch_info)) {
  die "Could not get patch!";
}
my ($tree, $patch_name, $patch_ref, $patch, $in_use, $compile_only, $submitter, $submit_time) = @{$patch_info};
my $submit_time_formatted = time2str("%D %R", $submit_time);
my $bug_id = $patch_ref;
# bird: We shouldn't need this.
#if ($patch_ref =~ /Bug\s+(.*)/) {
#  $bug_id = $1;
#}

# Get tree type from DB so we can tailor the output accordingly
my $tree_type = Tinderbox3::DB::get_tree_type($dbh, $tree);

header($p, $login, $cookie, "Edit Patch $patch_name", $tree);

#
# Edit patch form
#
print <<EOM;
<form name=editform method=get action='adminpatch.pl'>
<input type=hidden name=action value='edit_patch'>
<input type=hidden name=patch_id value='$patch_id'>
<table>
<!-- in_use=$in_use -->
<tr><th>Patch Name:</th><td>@{[$p->textfield(-name=>'patch_name', -default=>$patch_name)]}</td></tr>
<tr><th>Bug #:</th><td>@{[$p->textfield(-name=>'bug_id', -default=>$bug_id)]}</td></tr>
<tr><th>In use:</th><td><input type=checkbox name=in_use@{[$in_use ? ' checked' : '']}></td></tr>
EOM
if ($tree_type == 'build_new_patch') {
    print <<EOM;
<tr><th>Compile only (no testing required):</th><td><input type=checkbox name=compile_only@{[$compile_only ? ' checked' : '']}></td></tr>
<tr><th>Submitter:</th><td>$submitter</td></tr>
<tr><th>Submitted:</th><td>$submit_time_formatted</td></tr>
<tr><th>Build tag:</th><td>$patch_id-$submitter-$patch_name</td></tr>
EOM
} else {
  print <<EOM;
<tr><th>Compile only (not relevant):</th><td><input type=checkbox name=compile_only@{[$compile_only ? ' checked' : '']}></td></tr>
<tr><th>Submitter:</th><td>$submitter</td></tr>
<tr><th>Submitted:</th><td>$submit_time_formatted</td></tr>
EOM
}
print <<EOM;
<tr><th>Patch ID:</th><td>$patch_id</td></tr>
</table>
EOM

if (!$login) {
  print login_fields();
}

print <<EOM;
<input type=submit>
</form>
<hr>
<PRE>
$patch
</PRE>
EOM


footer($p);
$dbh->disconnect;
