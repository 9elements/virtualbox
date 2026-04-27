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

package Tinderbox3::Login;

use strict;
use LWP::UserAgent;
use CGI;
use Tinderbox3::DB;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(check_session can_admin can_edit_tree can_sheriff_tree can_edit_machine can_edit_patch login_fields);

# Not used.
sub login {
  my ($login, $password) = @_;

  return 1;

  my $p = new CGI({Bugzilla_login => $login, Bugzilla_password => $password, GoAheadAndLogIn => 1});
  my $url = "http://bugzilla.mozilla.org/query.cgi?" . $p->query_string;

  my $ua = new LWP::UserAgent;
  $ua->agent("TinderboxServer/0.1");
  my $req = new HTTP::Request(GET => $url);
  my $response = $ua->request($req);
  if ($response->is_success) {
    if (${$response->content_ref()} =~ /Log(\s|&nbsp;)*out/i &&
        ${$response->content_ref()} =~ /$login/) {
      return 1;
    }
  }

  return 0;
}

sub delete_session {
  my ($dbh, $session_id) = @_;
  $dbh->do("DELETE FROM tbox_session WHERE session_id = ?", undef, $session_id);
  Tinderbox3::DB::maybe_commit($dbh);
}

sub check_session {
  my ($p, $dbh) = @_;
  if (1) {
    # New no-session management code.  We depend on apache to auth users.
    # We only do some select user translations here.
    my $user = lc($p->remote_user());
    if ($user) {
      my $user_info = $dbh->selectcol_arrayref("SELECT sUsername " .
                                               "  FROM testmanager_Users " .
                                               " WHERE sLoginName = ? " .
                                               "   AND tsExpire   = TIMESTAMP WITH TIME ZONE 'infinity'",
                                               undef, $user);
      if (defined($user_info) && scalar(@{$user_info}) > 0) {
        return ($user_info->[0], '');
      }
    }
    return ('', '');
  } else {
    # Old session management code.
    my $session_id = $p->cookie('tbox_session');
    my $login = $p->param('-login');
    my $password = $p->param('-password');

    my ($login_return, $cookie);
    if ($login) {
      if (login($login, $password)) {
        if ($session_id) {
          delete_session($dbh, $session_id);
        }
        my $new_session_id = time . "-" . int(rand()*100000) . "-" . $login;
        $dbh->do("INSERT INTO tbox_session (login, session_id, activity_time) VALUES (?, ?, " . Tinderbox3::DB::sql_current_timestamp() . ")", undef, $login, $new_session_id);
        Tinderbox3::DB::maybe_commit($dbh);
        # Determine the path for the cookie
        my $path = $p->url(-absolute => 1);
        $path =~ s/\/[^\/]*$/\//g;
        $cookie = $p->cookie(-name => 'tbox_session', -value => $new_session_id, -path => $path);
        $login_return = $login;
      }
    } elsif ($p->param('-logout') && $session_id) {
      delete_session($dbh, $session_id);
    } elsif($session_id) {
      my $row = $dbh->selectrow_arrayref("SELECT login, " . Tinderbox3::DB::sql_get_timestamp("activity_time") . " FROM tbox_session WHERE session_id = ?", undef, $session_id);
      if (defined($row)) {
        if (time > $row->[1]+24*60*60) {
          delete_session($dbh, $session_id);
        } else {
          $dbh->do("UPDATE tbox_session SET activity_time = " . Tinderbox3::DB::sql_current_timestamp() . " WHERE session_id = ?", undef, $session_id);
          Tinderbox3::DB::maybe_commit($dbh);
          $login_return = $row->[0];
        }
      }
    }

    return ($login_return, $cookie);
  }
}

sub is_readonly_user {
  my ($login, $dbh) = @_;
  my $user_info = $dbh->selectcol_arrayref("SELECT fReadOnly " .
                                           "  FROM testmanager_Users " .
                                           " WHERE sUsername = ? " .
                                           "   AND tsExpire  = TIMESTAMP WITH TIME ZONE 'infinity'",
                                           undef, $login);
  if (defined($user_info) && scalar(@{$user_info}) > 0) {
    return $user_info->[0] ? 1 : 0;
  }
  return 1;
}

sub can_admin {
  my ($login) = @_;
  if (grep { $_ eq $login } @Tinderbox3::Login::superusers) {
    return 1;
  } else {
    return 0;
  }
}

sub can_edit_tree {
  my ($login, $editors) = @_;
  if ((grep { $_ eq $login } split(/,/, $editors)) ||
      (grep { $_ eq $login } @Tinderbox3::Login::superusers)) {
    return 1;
  } else {
    return 0;
  }
}

sub can_sheriff_tree {
  my ($login, $editors, $sheriffs) = @_;
  if ((grep { $_ eq $login } split(/,/, $editors)) ||
      (grep { $_ eq $login } split(/,/, $sheriffs)) ||
      (grep { $_ eq $login } @Tinderbox3::Login::superusers)) {
    return 1;
  } else {
    return 0;
  }
}

# Returns 2 if edit access is limited.
sub can_edit_machine {
  my ($login, $editors, $sheriffs, $dbh) = @_;
  if ((grep { $_ eq $login } split(/,/, $editors)) ||
      (grep { $_ eq $login } split(/,/, $sheriffs)) ||
      (grep { $_ eq $login } @Tinderbox3::Login::superusers)) {
    return 1;
  } else {
    return is_readonly_user($login, $dbh) ? 0 : 2;
  }
}

#
# This is only used for build_new_patch trees, other trees uses can_edit_tree.
# Returns 2 if access is limited.
#
sub can_edit_patch {
  my ($login, $editors, $sheriffs, $dbh) = @_;
  if ((grep { $_ eq $login } split(/,/, $editors)) ||
      (grep { $_ eq $login } split(/,/, $sheriffs)) ||
      (grep { $_ eq $login } @Tinderbox3::Login::superusers)) {
    return 1;
  } else {
    return is_readonly_user($login, $dbh) ? 0 : 2;
  }
}


sub login_fields {
  if (1) {
    # No login with new session management.
    return '';
  } else {
    return "<strong>Login:</strong> <input type=text name='-login'> <strong>Password:</strong> <input type=password name='-password'>";
  }
}

our @superusers = ('klaus', 'werner', 'michael', 'bird');

1
