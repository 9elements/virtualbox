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
# bird
#
# ***** END LICENSE BLOCK *****

use strict;
use CGI;
use Tinderbox3::DB;
use Tinderbox3::Login;
use Tinderbox3::Util qw(get_id_array_param url_sans_param);

#
# Init.
#
my $p = new CGI;
my $dbh = get_dbh();
my ($login, $cookie) = check_session($p, $dbh);

#
# Do the work.
#

# Get the parameters.
my $action = $p->param('action');
my @action_ids = get_id_array_param($p, 'action_ids');

Tinderbox3::DB::bulk_machine_command_update($p, $dbh, $login, $action, \@action_ids);

$dbh->disconnect;

#
# Construct anRemove the 'action' and 'action_ids'
#
my $url = url_sans_param(url_sans_param($p->url(-path_info => 1, -query =>1),'action'), 'action_ids');
$url =~ s/showbuildsaction\.pl/showbuilds.pl/;
print $p->redirect($url);

