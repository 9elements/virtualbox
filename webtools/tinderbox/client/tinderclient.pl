#!/usr/bin/perl -w
# $Id: tinderclient.pl 114033 2026-04-27 09:34:52Z knut.osmundsen@oracle.com $
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

use strict;
use warnings;

use Getopt::Long;
use Cwd qw(getcwd);
use Text::ParseWords qw(shellwords);

unless (caller) {

    # Save original arguments so we can send them to the new script if we upgrade
    # ourselves
    my @original_args = @ARGV;

    #
    # Catch these signals
    #
    $SIG{INT} = sub { print "SIGINT\n"; exit(1); };
    $SIG{TERM} = sub { print "SIGTERM\n"; exit(1); };

    #
    # Redirect /dev/null to STDIN.
    #
    # Don't pass down the cygwin pty pipe or give the impression stdin can be
    # used interactively.  Our python typically ends up hanging for a long time
    # when checking out the standard handles, and subversion likes hanging around
    # asking for certificate confirmations.  The latter isn't necessarily a bad
    # thing all the time, but the former always is.
    #
    open STDIN, '<', '/dev/null';

    #
    # Tee STDERR to a log file.
    #
    # Helps with finding hidden bugs in the build script.
    #
    open my $REALSTDERR, '>&STDERR';
    tie *STDERR, 'TeeToFileHandle', 'tinderclient-stderr.log', $REALSTDERR;

    #
    # PROGRAM START
    #
    # Get arguments
    #
    my @config_files;
    push @config_files, $0;
    my @clients;
    create_clients(\@clients, \@config_files, \@original_args);

    # save the original dir, don't assume build_iteration() will always restore it.
    my $cwd = getcwd();

    # Figure out max frequency. Needed to be able to guarantee that each loop will
    # actually do at least one build. Would be wasting CPU cycles otherwise.
    my $max_freq = 0;
    foreach my $client (@clients)
    {
      $max_freq = $client->{FREQUENCY} if ($client->{FREQUENCY} > $max_freq);
    }
    # Stagger builds with the same non-maximum frequency, avoid clumping them.
    # Keep the "order" of entries by going backwards with the starting values.
    my $start_sched_val = 0;
    foreach my $client (@clients)
    {
        $client->{SCHED} = $start_sched_val;
        $start_sched_val -= $client->{FREQUENCY};
        if ($start_sched_val < 0)
        {
            $start_sched_val += $max_freq;
        }
        $start_sched_val %= $max_freq;
    }
    my $prev_build = undef;
    while (1)
    {
      my $min_start = -1;
      foreach my $client (@clients)
      {
        if (-f '.tinderclient-stop')
        {
          print("Stopping at user request\n");
          unlink('.tinderclient-stop');
          exit(0);
        }
        $client->{SCHED} += $client->{FREQUENCY};
        if (   $client->{SCHED} >= $max_freq
            && (   !defined($client->{BUILD_VARS}{SCHEDULED_START_TIME})
                || time >= $client->{BUILD_VARS}{SCHEDULED_START_TIME}))
        {
          $client->{SCHED} -= $max_freq;
          $client->build_iteration($cwd, \@config_files, $prev_build);
          $prev_build = $client;
          chdir($cwd);
        }

        # Figure out when the next build should start.
        if (   defined($client->{BUILD_VARS}{SCHEDULED_START_TIME}))
        {
          if ($min_start == -1 || $min_start > $client->{BUILD_VARS}{SCHEDULED_START_TIME})
          {
            $min_start = $client->{BUILD_VARS}{SCHEDULED_START_TIME};
          }
        } else {
          $min_start = -2;
        }
      }

      # Actually sleep the right amount if we can (no active builds).
      if (scalar(@clients) == 0)
      {
        if (-f '.tinderclient-stop')
        {
          print("Stopping at user request\n");
          unlink('.tinderclient-stop');
          exit(0);
        }
        print "No builds.  Throttling!  Not checking for updates!  Sleeping a while.\n";
        sleep(3 * 60);
      }
      elsif ($min_start > 0)
      {
        my $now = time;
        # Make sure that rounding effects (time has second granularity) cannot
        # result in too closely started builds. Rather wait a second too much.
        if ($min_start >= $now)
        {
          print 'Nothing to do.  Throttling!  Sleeping ' . ($min_start - $now + 1) . "s\n";
          sleep($min_start - $now + 1);
        }
      }
    }
} # unless (caller)


sub create_clients {
  my ($clients, $config_files, $original_args) = @_;

  print "EEK @ARGV\n";
  my $default_config = '';
  my %args;
  $args{trust} = 1;
  $args{throttle} = 5*60;
  $args{throttle_same} = 5*60;
  $args{frequency} = 1;
  $args{schedule_interval} = 0;
  $args{schedule_offset} = 0;
  $args{upgrade_interval} = 3*60;
  $args{statusinterval} = 15;
  GetOptions(\%args, 'config:s', 'default_config:s', 'dir:s', 'out_dir:s',
                     'throttle:i', 'throttle_same:i', 'frequency:i',
                     'schedule_interval:i', 'schedule_offset:i',
                     'url:s',
                     'trust!', 'usepatches!', 'usecommands!', 'usemozconfig!',
                     'upgrade!', 'upgrade_interval:i',
                     'use_svn!', 'svn_url:s', 'svn_user:s',
                     'branch:s', 'cvs_co_date:s', 'cvsroot:s', 'tests:s',
                     'clobber!', 'lowbandwidth!', 'statusinterval:s',
                     'upload_dir:s', 'uploaded_url:s', 'distribute:s',
                     'post_script:s', 'jail_post!',
                     'jail:s', 'jail_script:s',
                     'build_additions!', 'build_docs!', 'build_efi!',
                     'build_extpacks!', 'build_ose!', 'build_sdk!', 'build_testsuite!',
                     'build_vboximg!', 'build_vbb!', 'build_debrpm!',
                     'build_osetarball!', 'build_linux_kmods:s', 'build_qt!',
                     'build_parfait!', 'parfait_server:s',
                     'docs!', 'packing!', 'help|h|?!');
  if ($args{config} && $args{default_config})
  {
    # Read the single "line", and remember it for later use.
    open CONFIG, '<', $args{default_config} or die "Could not find config file $args{default_config}";
    push @{$config_files}, $args{default_config};
    my $line = '';
    while (<CONFIG>)
    {
      # chomp would require more trickery to deal with CRLF, do do it manually.
      s/\r?\n$//;
      next if ($line eq '' && $_ eq '');
      next if (/^\s*#/);
      if (/(\\\\)*\\$/)
      {
        # delete last backslash in $_.
        chop;
        $line .= $_;
        chomp $line;
      }
      else
      {
        $line .= $_;
        chomp $line;
        if ($line ne '')
        {
          if ($default_config eq '')
          {
            $default_config = $line;
          }
          else
          {
            die "Default config file $args{default_config} contains more than one line!";
          }
        }
        $line = '';
      }
    }
    if ($line ne '')
    {
      die "Parse error in default config file $args{default_config}: inconsistent quoting!";
    }
    close CONFIG;
  }
  if ($args{config})
  {
    # Go through each line, parse the arguments into @ARGV, and re-call this
    # function to interpret the args
    open CONFIG, '<', $args{config} or die "Could not find config file $args{config}";
    push @{$config_files}, $args{config};
    my $line = '';
    while (<CONFIG>)
    {
# chomp would require more trickery to deal with CRLF, do do it manually.
        s/\r?\n$//;
        next if ($line eq '' && $_ eq '');
        next if (/^\s*#/);
        if (/(\\\\)*\\$/)
        {
# delete last backslash in $_.
            chop;
            $line .= $_;
            chomp $line;
        }
        else
        {
            $line .= $_;
            chomp $line;
            @ARGV = shellwords($default_config . ' ' . $line);
            create_clients($clients, $config_files, $original_args);
        $line = '';
      }
    }
    if ($line ne '')
    {
      die "Parse error in config file $args{config}: inconsistent quoting!";
    }
    close CONFIG;
    # config is mutually exclusive with other args
    return;
  }

  if (!$args{url} || @ARGV != 2 || $args{help})
  {
    print <<EOM;

Usage: tinderclient.pl [OPTIONS] [--help] Tree MachineName ...

Runs the build continuously, sending status to the url
Tree: the name of the tree this tinderbox is attached to
MachineName: the name of this machine (how it is identified and will show up on
             tinderbox)

--url: the url of the Tinderbox we will send status to
--throttle: minimum length of time between builds (if it is failing miserably,
            we don't want to continuously send crap to the server or even bother
            building. Default is 5 minutes. This value is used when a different
            build is done next.
--throttle_same: minimum length of time between builds (if it is failing miserably,
            we don't want to continuously send crap to the server or even bother
            building. Default is 5 minutes. This value is used when the same
            build is done twice in a row.
--frequency: relative frequency of this build. Defaults to 1. Only relevant for
             switching Tinderbox config.
--schedule_interval: allow at most one real build in this many seconds. Defaults to 0,
                     which means no limit.
--schedule_offset: start the schedule intervals this many seconds after midnight UTC.
                   Defaults to 0.
--notrust: do not trust anything from the server, period--commands, cvs_co_date,
           mozconfig, patches or anything else
--nousecommands: don't obey commands from the server, such as kick or clobber
--noupgrade: do not upgrade tinderclient.pl and config automatically from server,
             via regular repository update commands.
--upgrade_interval: time in seconds between upgrade checks. Default 3 minutes.
--dir: the directory to work in
--out_dir: the directory where the build results will be located. Defaults to
           the value of --dir.
--lowbandwidth: transfer less verbose info to the server
--help: show this message

--nousemozconfig: do not get LocalConfig.kmk from the server
--nousepatches: do not bring down new patches from the tinderbox and apply them

The following options will be brought down from the server if not specified
here, unless --notrust is specified.  If --notrust is specified, defaults given
will be used instead.
--tests: the list of tests to run.  Defaults to ""
--use_svn, --nouse_svn: use Subversion or CVS. Defaults to --use_svn.
--svn_url: the Subversion root to use. Defaults to
           "https://linserv.de.oracle.com/vbox/svn"
--svn_user: The Subversion user name. Defaults to ""
--cvsroot: the cvsroot to grab the sources from.  Defaults to
           ":pserver:bird\@freebsd:2501/vbox"
--branch the branch to check out (for subversion the revision number to use)
--cvs_co_date date to check out at, or blank (current) or "off".  If you do not
             set this, the server will control it.  Defaults to blank (current).
--clobber, --noclobber: clobber or depend build.  Defaults to --noclobber.
--upload_dir: directory to copy finished builds to (using rsync, so can be
              either a local directory, network share or remore directory
              accessible via ssh)
--uploaded_url: url where the build can be found once uploaded (\%s will be
                replaced with the build name)
--distribute: the list of things to distribute.  Defaults to "build_by_suffix,raw_zip".
              "raw_zip" is another useful one, that just zips up everything in
              the dist/bin directory (actually makes a .tgz).
              For the additions builds there is the "additions_iso".
              For the docs builds there is the "docs_zip".
              For the efi firmware builds there is the "efi_firmware".
              For the efi armv8 firmware builds there is the "efi_firmware_armv8".
              For the extension pack builds there is the "extpack_tgz".
              For the validationkit builds there is the "testsuite_zip".
--raw_zip_name: the project name of the raw build (defaults to "VBoxAll")
--post_script: Script to execute after the build.
--jail_post, --nojail_post: Whether post script is run in jail. Default is --jail_post.
--jail_script: Script which enters a particular jail.
--jail: Name of the jail to use.
--build_additions: Whether to only build additions. (default is all)
--build_docs: Whether to only build documentation. (default is all)
--build_efi: Special build mode for EFI firmware. Default is off.
--build_extpacks: Special build mode for extension packs. Default is off.
--build_ose: Special build mode for VirtualBox OSE. Default is off.
--build_sdk: Whether to only build the SDK. Default is off.
--build_testsuite: Whether to only build the validation kit. Default is off.
--build_vboximg: Whether to only build the vbox-img binary. Default is off.
--build_vbb: Special build mode for VirtualBox/Blue. Default is off.
--build_debrpm: Special build mode for deb/rpm packages. Default is off.
--build_osetarball: Special build mode for creating OSE tarballs. Default is off.
--build_linux_kmods=path/build_modules.sh: Special mode build for testbuilding
              Linux kernel modules. Default is off.
--build_qt: Special build mode for Qt (VirtualBox tool flavor). Default is off.
--build_parfait: Special build mode for running the parfait static code analysis. Default is off.
--parfait_server: Server URL to upload the parfait result to (only effective with --build_parfait).
--docs, --nodocs: Disable the 'docs' build step. Defaults to --docs.
--packing, --nopacking: Disable the 'packing' build step. Defaults to --packing.

CONFIG MODE (SWITCHING TINDERBOX):
  tinderclient.pl --config=<file> [ --default_config=<file> ]

Specifies a text file where tbox configuration is stored.  Each line in the
file is nothing more than the arguments to the program.  If you specify multiple
lines (and thus multiple sets of arguments), the client will *switch* between
different builds and trees: i.e. it will build with the first line, then the
second, then the third, then back to the first, and so on.  It is HIGHLY
RECOMMENDED that you specify --dir for each tree, or else the tbox is likely
going to clobber your tree between each build (if the options for different
trees are different).

The --default_config option allows to eliminate much redundancy in config files,
by specifying options which apply to all builds in a separate file.

EOM
    exit(1);
  }

  $args{usecommands} = $args{trust} if !defined($args{usecommands});
  $args{usemozconfig} = $args{trust} if !defined($args{usemozconfig});
  $args{usepatches} = $args{trust} if !defined($args{usepatches});
  $args{upgrade} = $args{trust} if !defined($args{upgrade});
  if (!$args{trust})
  {
    $args{tests} = '' if !defined($args{tests});
    $args{svn_url} = 'https://linserv.de.oracle.com/vbox/svn' if !defined($args{svn_url});
    $args{cvsroot} = ':pserver:bird@freebsd:2501/vbox' if !defined($args{cvsroot});
    $args{cvs_co_date} = '' if !defined($args{cvs_co_date});
    $args{branch} = '' if !defined($args{branch});
    $args{clobber} = 0 if !defined($args{clobber});
  }
  $args{out_dir} = '' if !defined($args{out_dir});
  $args{use_svn} = 1 if !defined($args{use_svn});
  $args{distribute} = "build_by_suffix,raw_zip" if !defined($args{distribute});
  $args{raw_zip_name} = "VBoxAll" if !defined($args{raw_zip_name});
  $args{post_script} = '' if !defined($args{post_script});
  $args{jail_post} = 1 if (!defined($args{jail_post}));
  $args{jail} = '' if (!defined($args{jail}) || !defined($args{jail_script}));
  $args{jail_script} = '' if (!defined($args{jail}) || !defined($args{jail_script}));
  $args{build_additions} = 0 if (!defined($args{build_additions}));
  $args{build_docs} = 0 if (!defined($args{build_docs}));
  $args{build_efi} = 0 if (!defined($args{build_efi}));
  $args{build_extpacks} = 0 if (!defined($args{build_extpacks}));
  $args{build_ose} = 0 if (!defined($args{build_ose}));
  $args{build_sdk} = 0 if (!defined($args{build_sdk}));
  $args{build_testsuite} = 0 if (!defined($args{build_testsuite}));
  $args{build_vboximg} = 0 if (!defined($args{build_vboximg}));
  $args{build_vbb} = 0 if (!defined($args{build_vbb}));
  $args{build_debrpm} = 0 if (!defined($args{build_debrpm}));
  $args{build_osetarball} = 0 if (!defined($args{build_osetarball}));
  $args{build_linux_kmods} = '' if (!defined($args{build_linux_kmods}));
  $args{build_qt} = 0 if (!defined($args{build_qt}));
  $args{build_parfait} = 0 if (!defined($args{build_parfait}));
  $args{docs} = 1 if (!defined($args{docs}));
  $args{packing} = 1 if (!defined($args{packing}));

  if ($args{jail} && $args{jail_script})
  {
    push @{$config_files}, $args{jail_script};
    # Small trick to ensure uniqueness even if the same jail script appears
    # for each and every build. Not worth optimizing.
    my %tmpcfghash = map { $_, 1 } @{$config_files};
    @{$config_files} = keys %tmpcfghash;
  }

  if ($args{dir} && !-d $args{dir})
  {
    mkdir($args{dir});
  }
  if ($args{dir} && !-d $args{dir})
  {
    die "Directory $args{dir} does not exist!";
  }

  if ($args{out_dir} && !-d $args{out_dir})
  {
    mkdir($args{out_dir});
  }
  if ($args{out_dir} && !-d $args{out_dir})
  {
    die "Directory $args{out_dir} does not exist!";
  }

  push @{$clients}, new TinderClient(\%args, $ARGV[0], $ARGV[1], $original_args);
}

# Returns kBuild style host OS name.
sub get_kbuild_host_os {
   my ($os, undef, undef, undef, undef) = POSIX::uname();
   chomp($os);

   if ($os eq 'Linux' || $os eq 'linux' || $os eq 'GNU/Linux') {
     return 'linux';
   }
   if ($os eq 'SunOS') {
     return 'solaris';
   }
   if ($os eq 'Darwin' || $os eq 'darwin') {
     return 'darwin';
   }
   if ($os eq 'Windows NT') {
     return 'win';
   }
   if ($os =~ /^CYGWIN_.*$/) {
     return 'win';
   }

   return 'linux'; # whatever.
}


package TeeToFileHandle;

sub TIEHANDLE {
  my $class = shift;
  my $filename = shift;
  my $filehandle = shift;

  open my $fh1, '>>', $filename or die "Could not append to file $filename\n";

  my $self = {
    fh1 => $fh1,
    fh2 => $filehandle,
  };

  bless $self, $class;
  return $self;
}

sub PRINT {
  my $self = shift;
  my $fh1 = $self->{fh1};
  my $fh2 = $self->{fh2};
  print $fh1 @_;
  print $fh2 @_;
}



package TinderClient;

use strict;

use LWP::UserAgent;
use HTTP::Date qw(time2str);
use Cwd qw(getcwd);

our $VERSION;
our $PROTOCOL_VERSION;

sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my $this = {};
  bless $this, $class;

  $VERSION = '0.1';
  $PROTOCOL_VERSION = '0.1';

  my ($args, $tree, $machine_name, $original_args) = @_;
  # The arguments hash
  $this->{ARGS} = $args;
  $this->{CONFIG} = { %{$args} };
  # The tree
  $this->{TREE} = $tree;
  # The machine
  $this->{MACHINE_NAME} = $machine_name;
  # The build scheduling data
  $this->{SCHED} = 0;
  $this->{FREQUENCY} = $this->{ARGS}{frequency};
  # The user agent object
  $this->{UA} = new LWP::UserAgent;
  $this->{UA}->agent('TinderboxClient/' . $TinderClient::PROTOCOL_VERSION);
  # the tinderclient.log out
  $this->{LOG_OUT} = undef;
  # the tinderclient.log in
  $this->{LOG_IN} = undef;
  # the un-dealt-with commands
  $this->{COMMANDS} = {};
  # system information
  $this->{SYSINFO} = TinderClient::SysInfo::get_sysinfo($this->{ARGS}{dir}, $this->{ARGS}{jail_script}, $this->{ARGS}{jail});
  # the original program arguments in case we have to upgrade
  $this->{ORIGINAL_ARGS} = $original_args;
  # persistent vars for the build modules
  $this->{PERSISTENT_VARS} = {};

  return $this;
}

sub get_patch {
  my $this = shift;
  my ($patch_id) = @_;
  if (! -f "tbox_patches/$patch_id.patch") {
    my $req = new HTTP::Request(GET => $this->{CONFIG}{url} . "/get_patch.pl?patch_id=$patch_id");
    my $res = $this->{UA}->request($req);
    if ($res->is_success) {
      if (! -d 'tbox_patches') {
        mkdir('tbox_patches');
      }
      if (!open OUTFILE, '>', "tbox_patches/$patch_id.patch") {
        $this->print_log("ERROR: unable to create patchfile: $!\n");
        return '';
      }
      print OUTFILE ${$res->content_ref()};
      close OUTFILE;
    } else {
      $this->print_log("ERROR reaching $this->{CONFIG}{url}/get_patch.pl?patch_id=$patch_id ...\n");
      return '';
    }

  }
  return "tbox_patches/$patch_id.patch";
}

sub form_data_request {
  my $this = shift;
  my ($boundary, $name, $value) = @_;
  my $request_content;
  $request_content = '--' . $boundary . "\r\n";
  $request_content .= "Content-Disposition: form-data; name=\"$name\"\r\n\r\n";
  $request_content .= $value . "\r\n";
  return $request_content;
}

sub send_request {
  my $this = shift;
  my ($script, $params) = @_;

  my $boundary = '----------------------------------' . int(rand()*1000000000000);
  # Create a request
  my $req = new HTTP::Request(POST => $this->{CONFIG}{url} . '/xml/' . $script);
  $req->content_type("multipart/form-data; boundary=$boundary");

  ${$req->content_ref} .= $this->form_data_request($boundary, 'tree', $this->{TREE});
  foreach my $param (keys %{$params}) {
    ${$req->content_ref} .= $this->form_data_request($boundary, $param, $params->{$param});
  }
  if (defined($this->{LOG_IN})) {
    my $started_sending = 0;
    my $log_in = $this->{LOG_IN};
    while (<$log_in>) {
      if (!$started_sending) {
        ${$req->content_ref} .= '--' . $boundary . "\r\n";
        ${$req->content_ref} .= "Content-Disposition: form-data; name=\"log\"; filename=\"log.txt\"\r\n";
        ${$req->content_ref} .= "Content-Type: text/plain; charset='utf8'\r\n\r\n";
        $started_sending = 1;
      }
      ${$req->content_ref} .= $_;
    }
    if ($started_sending) {
      ${$req->content_ref} .= "\r\n";
    }
  }
  ${$req->content_ref} .= '--' . $boundary . "--\r\n";
  #print "----- REQUEST TO $this->{CONFIG}{url}/xml/$script -----\n";
  #print $req->content();
  #print "----- END REQUEST TO $this->{CONFIG}{url}/xml/$script -----\n";

  # Pass request to the user agent and get a response back
  return $this->{UA}->request($req);
}

sub parse_simple_tag {
  my $this = shift;
  my ($content_ref, $tagname, $alttagname) = @_;
  if (${$content_ref} =~ /<$tagname>([^><]*)/) {
    return $1;
  }
  if (defined($alttagname)) {
    if (${$content_ref} =~ /<$alttagname>([^><]*)/) {
      return $1;
    }
  }
  return '';
}

sub get_field {
  my $this = shift;
  my ($content_ref, $field, $altfield) = @_;
  if (!exists($this->{ARGS}{$field})) {
    $this->{CONFIG}{$field} = $this->parse_simple_tag($content_ref, $field, $altfield);
  }
}

sub get_kbuild_fields {
  my $this = shift;
  my ($content_ref) = @_;

  $this->get_field($content_ref, 'KBUILD_HOST', 'BUILD_PLATFORM');
  $this->{CONFIG}{KBUILD_HOST} ||= ::get_kbuild_host_os();
  $this->get_field($content_ref, 'KBUILD_HOST_ARCH', 'BUILD_PLATFORM_ARCH');
  $this->{CONFIG}{KBUILD_HOST_ARCH} ||= 'x86';
  $this->get_field($content_ref, 'KBUILD_TARGET', 'BUILD_TARGET');
  $this->{CONFIG}{KBUILD_TARGET} ||= $this->{CONFIG}{KBUILD_HOST};
  $this->get_field($content_ref, 'KBUILD_TARGET_ARCH', 'BUILD_TARGET_ARCH');
  $this->{CONFIG}{KBUILD_TARGET_ARCH} ||= $this->{CONFIG}{KBUILD_HOST_ARCH};
  $this->get_field($content_ref, 'KBUILD_TYPE', 'BUILD_TYPE');
  $this->{CONFIG}{KBUILD_TYPE} ||= 'debug';

  $this->get_field($content_ref, 'KMK_DEFINES', 'MAKE_DEFINES');
  $this->{CONFIG}{KMK_DEFINES} ||= '';

  $this->get_field($content_ref, 'OUT_SUB_DIR');
  $this->{CONFIG}{OUT_SUB_DIR} ||= $this->{CONFIG}{KBUILD_TARGET}.'.'.$this->{CONFIG}{KBUILD_TARGET_ARCH};
}

sub parse_content {
  my $this = shift;
  my ($content_ref, $is_start) = @_;
  if ($this->{CONFIG}{usecommands}) {
    foreach (split(/,/, $this->parse_simple_tag($content_ref, 'commands'))) {
      $this->print_log("---> New command $_! <---\n");
      $this->{COMMANDS}{$_} = 1;
    }
  }

  if ($is_start) {
    if (${$content_ref} =~ /<machine[^>]+\bid=['"](\d+)['"]>/) {
      $this->{MACHINE_ID} = $1;
    } else {
      return 0;
    }

    # Call get_config
    foreach my $module ('init_tree', 'build', 'distribute', 'tests') {
      $this->call_module($module, 'get_config', $content_ref);
    }
  }

  return 1;
}

sub sysinfo {
  my $this = shift;
  return $this->{SYSINFO};
}

sub field_vars_hash {
  my $this = shift;
  my $retval = {};
  my $i = 0;
  while (my ($field, $field_val) = each %{$this->{BUILD_VARS}{fields}}) {
    if (ref($field_val) eq 'ARRAY') {
      foreach my $val (@{$field_val}) {
        $retval->{"field_${i}"} = $field;
        $retval->{"field_${i}_val"} = $val;
        $i++;
      }
    } else {
      $retval->{"field_${i}"} = $field;
      $retval->{"field_${i}_val"} = $field_val;
      $i++;
    }
  }
  return %{$retval};
}

sub build_start {
  my $this = shift;
  my $script_rev = '$Revision: 114033 $';
  $script_rev =~ s/^\D+(\d+)\D+$/$1/;

  # Check the outcome of the response
  my $res = $this->send_request('build_start.pl', {
      machine_name => $this->{MACHINE_NAME},
      os           => $this->{SYSINFO}{OS},
      os_version   => $this->{SYSINFO}{OS_VERSION},
      compiler     => $this->{SYSINFO}{COMPILER},
      clobber      => ($this->{CONFIG}{clobber} ? 1 : 0),
      script_rev   => $script_rev,
      $this->field_vars_hash() }
  );
  my $success = $res->is_success || $res->content() !~ /<error>/;
  if ($success) {
    $this->{LAST_STATUS_SEND} = time;
    #print "\nCONTENT: " . $res->content() . "\n";
    $this->{BUILD_VARS}{fields} = {};
    my $retval = $this->parse_content($res->content_ref(), 1);
    if (!$retval) {
      print 'Error parsing content: ' . $res->content() . "\n";
    }
    return $retval;
  }
  return 0;
}

sub build_status {
  my $this = shift;
  my ($status) = @_;

  # Check the outcome of the response
  my $res = $this->send_request('build_status.pl', { machine_id => $this->{MACHINE_ID}, status => $status, $this->field_vars_hash() });
  my $success = $res->is_success || $res->content() !~ /<error>/;
  if ($success) {
    $this->{LAST_STATUS_SEND} = time;
    #print "build_status success\n";
    #print "\nCONTENT: " . $res->content() . "\n";
    $this->{BUILD_VARS}{fields} = {};
    return $this->parse_content($res->content_ref(), 0);
  }
  return 0;
}

sub build_finish {
  my $this = shift;
  my ($status) = @_;
  #print "build_finish($status)\n";
  close $this->{LOG_OUT};
  $this->{LOG_OUT} = undef;
  my $retval = $this->build_status($status);
  if (!$retval) {
    print "build_status failed, retrying...\n";
    sleep(5);
    $retval = $this->build_status($status);
  }
  close $this->{LOG_IN};
  $this->{LOG_IN} = undef;
  return $retval;
}

sub print_log {
  my $this = shift;
  my ($line) = @_;
  print $line;
  my $log_out = $this->{LOG_OUT};
  # 20080407 the log file is closed between tests, and if e.g. an incoming
  # command causes something to be logged, it'll cause a crash of this script.
  # Better behavior now: log to stdout instead.
  if (defined($log_out))
  {
    print $log_out $line;
  }
  else
  {
    print $line;
  }
}

sub file_to_log {
  my $this = shift;
  my ($file) = @_;

  my $content;
  open(my $fh, '<', $file);
  {
    local $/;
    $content = <$fh>;
  }
  close($fh);

  $this->print_log(<<EOM);
== $file
$content
== End $file
EOM
}

sub start_section {
  my $this = shift;
  my ($section) = @_;
  $this->print_log("---> TINDERBOX $section " . time2str(time) . "\n");
}

sub end_section {
  my $this = shift;
  my ($section) = @_;
  $this->print_log("<--- TINDERBOX FINISHED $section " . time2str(time) . "\n");
}

sub eat_command {
  my $this = shift;
  my ($command) = @_;
  if ($this->{COMMANDS}{$command}) {
    $this->print_log("---> Eating command $command! <---\n");
    delete $this->{COMMANDS}{$command};
    return 1;
  }
  return 0;
}

use Fcntl;
use POSIX qw(:errno_h);
use IO::Select;

sub set_nonblocking {
  my $this = shift;
  my ($handle) = @_;
  if ($^O eq 'MSWin32') {
    my $arg = 1;
    ioctl($handle, 0x8004667e, \$arg);
  } else {
    my $flags = 0;
    fcntl($handle, F_GETFL, $flags) or return;
    $flags |= O_NONBLOCK;
    fcntl($handle, F_SETFL, $flags) or return;
  }
}

sub _kill_command {
  # Kill a command and its children
  my $this = shift;
  my ($pid, $children_of) = @_;
  if ($^O eq 'cygwin') {
    # Get the windows pid to make sure non-cygwin processes like kmk.exe gets killed properly.
    my $winpid = Cygwin::pid_to_winpid($pid);
    if ($winpid != $pid && $winpid > 1) {
      $this->print_log("Killing $pid and windows pid $winpid\n");
      #system('/bin/kill', '--winpid', '--force', '-INT', "$winpid"); # requires too new cygwin version
      system('taskkill.exe', '/F', '/T', '/PID', "$winpid");  # force kill the process tree
    } else {
      $this->print_log("Killing $pid\n");
    }
  } else {
    $this->print_log("Killing $pid\n");
  }
  kill('INT', $pid);
  foreach my $child_pid (@{$children_of->{$pid}}) {
    $this->_kill_command($child_pid, $children_of);
  }
}

sub kill_command {
  # Kill a command and its children (children first)
  my $this = shift;
  my ($pid) = @_;
  # Get the ps -aux table and pass it to _kill_command
  my %children_of;
  open PS_AUX, $this->sysinfo()->{PS_COMMAND} . '|';
  while (<PS_AUX>) {
    if (/\s*(\d+)\s*(\d+)/) {
      my ($ps_pid, $ps_ppid) = ($^O ne 'MSWin32') ? ($1, $2) : ($2, $1);
      if (!exists($children_of{$ps_ppid})) {
        $children_of{$ps_ppid} = [];
      }
      push @{$children_of{$ps_ppid}}, $ps_pid;
    }
  }
  close PS_AUX;
  $this->_kill_command($pid, \%children_of);
}

sub do_command_jail {
  my $this = shift;
  my ($command, $status, $grep_sub, $max_idle_time) = @_;

  if ($this->{ARGS}{jail_script} && $this->{ARGS}{jail})
  {
    $command = $this->{ARGS}{jail_script} . ' ' . $this->{ARGS}{jail} . ' ' . $command;
  }

  return $this->do_command($command, $status, $grep_sub, $max_idle_time);
}

sub do_command {
  my $this = shift;
  my ($command, $status, $grep_sub, $max_idle_time, $retry_count) = @_;

  if (!$status)
  {
    $status = 1;
  }

  $this->start_section("RUNNING '$command'");

  my $please_send_status = 0;

  my $handle;
  my $pid = open $handle, "$command 2>&1|";
  if (!$pid) {
    $this->end_section("(FAILURE: could not start) RUNNING '$command'");
    return 200;
  }
  $this->set_nonblocking($handle);
  my $select = IO::Select->new($handle);

  my $last_read_time = time;
  my $build_error;
  while (1) {
    #
    # Read from the buffer asynchronously
    #
    my $buffer;
    my $rv = read($handle, $buffer, 4096);
    # If nothing was read, we check if the process is OK
    if (!$rv) {
      #
      # Check if the process is dead
      #
      my $wait_pid = waitpid($pid, POSIX::WNOHANG());
      if (($wait_pid == $pid && ($^O eq 'MSWin32' ? 1 : POSIX::WIFEXITED($?))) || $wait_pid == -1) {
        $build_error = $?;
        if ($build_error == 0 || !$retry_count || $retry_count <= 0) {
          last
        }
        # retry the command (svn server auth hack).
        $this->end_section("(FAILURE: $build_error) RUNNING '$command'");
        $retry_count -= 1;
        sleep(10);
        $this->start_section("RETRYING RUNNING '$command'");
        close $handle;
        $pid = open $handle, "$command 2>&1|";
        if (!$pid) {
          $this->end_section("(FAILURE: could not start) RUNNING '$command'");
          return 200;
        }
        $this->set_nonblocking($handle);
        $select = IO::Select->new($handle);
      }
      # Kill the process if it's still alive and hung
      if ($max_idle_time && (time - $last_read_time) > $max_idle_time) {
        $this->print_log("Command appears to have hanged!\n");
        $build_error = 1;
        $this->kill_command($pid);
        $please_send_status = 202;
      }
    }
    $last_read_time = time;

    if ($buffer) {
      $this->print_log($grep_sub ? &$grep_sub($buffer) : $buffer);
    }

    {
      # Send status every so often (this also gives us back new commands)
      my $current_time = time;
      my $elapsed = $current_time - $this->{LAST_STATUS_SEND};
      if ($elapsed > $this->{CONFIG}{statusinterval}) {
        my $log_out = $this->{LOG_OUT};
        flush $log_out;
        my $success = $this->build_status($status);
      }
      # If we tried to kill before and we're not dead, or if the kick command
      # is around, we kill again
      if ($please_send_status == 301 || $this->eat_command('kick')) {
        $this->kill_command($pid);
        $please_send_status = 301;
      }
    }
    # If nothing was actually read, we sleep to give the cpu a chance
    if (!$rv) {
      $select->can_read(3);
      next;
    }
  }
  close $handle;

  if ($build_error) {
    $this->end_section("(FAILURE: $build_error) RUNNING '$command'");
  } else {
    $this->end_section("(SUCCESS) RUNNING '$command'");
  }

  # Flush the log and send a status update before returning.
  # Hopefully this might help fix the yellow bars we've been seeing on some build errors.
  my $log_out = $this->{LOG_OUT};
  flush $log_out;
  my $success = $this->build_status($status);

  if ($please_send_status) {
    return $please_send_status;
  } else {
    return $build_error ? 200 : 0;
  }
}

sub read_mozconfig {
  my $this = shift;
  my $mozconfig = '';
  if ($ENV{MOZCONFIG}) {
    if (open MOZCONFIG, '<', $ENV{MOZCONFIG}) {
      while (<MOZCONFIG>) {
        $mozconfig .= $_;
      }
    }
    close MOZCONFIG;
  } elsif (open MOZCONFIG, '<', 'LocalConfig.kmk') {
    while (<MOZCONFIG>) {
      $mozconfig .= $_;
    }
    close MOZCONFIG;
  } else {
    my $mozhome;
    if (defined($ENV{HOME})) {
      $mozhome = $ENV{HOME};
    } elsif (defined($ENV{HOMEDRIVE}) && defined($ENV{HOMEPATH})) {
      $mozhome = $ENV{HOMEDRIVE} . $ENV{HOMEPATH};
    }
    if (defined($mozhome) && open MOZCONFIG, '<', $mozhome . '/.mozconfig') {
      while (<MOZCONFIG>) {
        $mozconfig .= $_;
      }
      close MOZCONFIG;
    }
  }
  return $mozconfig;
}

sub print_build_info {
  my $this = shift;
  my $id = '$Id: tinderclient.pl 114033 2026-04-27 09:34:52Z knut.osmundsen@oracle.com $';
  $this->start_section('PRINTING CONFIGURATION');
  $this->print_log(<<EOM);
== Tinderbox Info
Time: @{[time2str(time)]}
OS: $this->{SYSINFO}{OS} $this->{SYSINFO}{OS_VERSION}
Compiler: $this->{SYSINFO}{COMPILER} $this->{SYSINFO}{COMPILER_VERSION}
Tinderbox Client: $TinderClient::VERSION
Tinderbox Client Last Modified: @{[$this->get_prog_mtime()]}
Tinderbox Client Id: $id
Tinderbox Protocol: $TinderClient::PROTOCOL_VERSION
Arguments: @{[join ' ', @{$this->{ORIGINAL_ARGS}}]}
URL: $this->{CONFIG}{url}
Tree: $this->{TREE}
Commands: @{[join(' ', sort keys %{$this->{COMMANDS}})]}
Config:
@{[join("\n", map { $_ . " = '" . $this->{CONFIG}{$_} . "'" } sort keys %{$this->{CONFIG}})]}
== End Tinderbox Client Info
EOM
  if ($^O eq 'MSWin32') {
    system('title Tinderbox tree '.$this->{TREE}.' / '.$this->{MACHINE_NAME});
    $this->do_command('set');
  } else {
    if ($ENV{TERM} eq 'screen') {
        print("\ek".$this->{TREE}.':'.$this->{MACHINE_NAME}."\e\\");
    }
    $this->do_command('env');
  }

  # Print sufficient name/IP details to find the box.
  if ($this->{SYSINFO}{OS} eq 'Linux') {
    $this->do_command('hostname -f ; hostname -i ; [ -x /sbin/ip ] && /sbin/ip addr || /sbin/ifconfig', 1);
  } elsif ($this->{SYSINFO}{OS} eq 'SunOS') {
    $this->do_command('hostname ; /sbin/ifconfig -a', 1);
  } elsif ($this->{SYSINFO}{OS} eq 'Darwin') {
    $this->do_command('hostname ; /sbin/ifconfig', 1);
  } elsif ($this->{SYSINFO}{OS} eq 'WINNT') {
    if ($^O eq 'MSWin32') {
      $this->do_command('hostname& ipconfig', 1);
    } else {
      $this->do_command('hostname ; ipconfig', 1);
    }
  } else {
    $this->do_command('hostname', 1);
  }

  $this->end_section('PRINTING CONFIGURATION');
}


sub maybe_throttle {
  my $this = shift;
  my ($prev_build) = @_;
  my $elapsed = time - $this->{BUILD_VARS}{START_TIME};
  my $throttle = (!defined($prev_build) || $this == $prev_build) ? $this->{ARGS}{throttle_same} : $this->{ARGS}{throttle};
  # Make sure that rounding effects (time has second granularity) cannot
  # result in too closely started builds. Rather wait a second too much.
  if ($elapsed <= $throttle) {
    print 'Throttling!  Sleeping ' . ($throttle - $elapsed + 1) . "s\n";
    sleep($throttle - $elapsed + 1);
  }
}

sub get_prog_mtime {
  my @prog_stat = stat($0);
  my $prog_mtime = $prog_stat[9];
  my $time_str = time2str($prog_mtime);
}

sub maybe_upgrade {
  my $this = shift;
  my ($olddir, $config_files) = @_;

  # Go to CWD at the time when the script was started.
  my $current_dir = getcwd();
  $this->print_log("---> cd $olddir <---\n");
  chdir($olddir);

  $this->start_section('CHECKING FOR UPGRADE');
  my $upgraded = 0;
  my @filedates;
  foreach my $sfile (@{$config_files})
  {
    push @filedates, (stat $sfile)[9];
  }
  my $files = join(' ', @{$config_files});
  if ($^O eq 'cygwin')
  { # ASSUMING svn.exe is non-cygwin, we need to translate the paths.
    $files =~ s/\/cygdrive\/([a-z])\//$1:\//g;
    $files =~ s/\\/\\\\/g;
  }

  my $cvs_up_params = ' -PdA';
  my $svn_up_params = ' --non-interactive';
  if ($this->{CONFIG}{svn_user} ne '')
  {
    $svn_up_params .= ' --username '.$this->{CONFIG}{svn_user};
  }
  if ($this->{CONFIG}{svn_params} ne '')
  {
    $svn_up_params .= ' '.$this->{CONFIG}{svn_params};
  }
  if ($this->{CONFIG}{use_svn})
  {
    $this->do_command("svn up $svn_up_params $files");
  }
  else
  {
    $this->do_command("cvs -z3 up $cvs_up_params $files");
  }
  my $i = 0;
  foreach my $cfile (@{$config_files})
  {
    if ($filedates[$i] < (stat $cfile)[9])
    {
      my $new_file = '';
      open PROG, '<', "$cfile";
      while (<PROG>) { $new_file .= $_; }
      close PROG;
      $this->print_log("New version of file $cfile found:\n");
      $this->print_log($new_file);
      $this->print_log("Updated $cfile (now modified " . time2str((stat $cfile)[9]) . ")\n");
      $upgraded = 1;
    }
    else
    {
      $this->print_log("File $cfile not modified\n");
    }
    $i++;
  }
  $this->end_section('CHECKING FOR UPGRADE');
  if ($upgraded)
  {
    $this->print_log("Executing newly upgraded script ...\n");
    print "UPGRADING!  Throttling just for fun first ...\n";
    $this->build_finish(303);
    eval
    {
      # Throttle just in case we get in an upgrade client loop
      my $elapsed = time - $this->{BUILD_VARS}{START_TIME};
      # Make sure that rounding effects (time has second granularity) cannot
      # result in too closely started builds. Rather wait a second too much.
      if ($elapsed <= 60)
      {
        print "Throttling!  Sleeping " . (60 - $elapsed + 1) . "s\n";
        sleep(60 - $elapsed + 1);
      }
      exec("$^X", $0, @{$this->{ORIGINAL_ARGS}});
    };
    exit(0);
  }

  # back to original directory
  $this->print_log("---> cd $current_dir <---\n");
  chdir($current_dir);
}

sub call_module {
  my $this = shift;
  my ($module, $method, $content_ref) = @_;
  my $code = "TinderClient::Modules::${module}::${method}(\$this, \$this->{CONFIG}, \$this->{PERSISTENT_VARS}, \$this->{BUILD_VARS}, \$content_ref)";
  my $retval = eval $code;
  # Handle ctrl+c
  if ($@) {
    die;
  }
  return $retval;
}

sub build_iteration {
  my $this = shift;
  my ($olddir, $config_files, $prev_build) = @_;

  # Initialize transient variables
  $this->{BUILD_VARS} = { fields => {} };
  $this->{BUILD_VARS}{START_TIME} = time;
  $this->{BUILD_VARS}{SCHEDULED_START_TIME} = undef;

  # Initialize update checking logic. Special care necessary as it's not really
  # worth truly global configuration values. It is a bit convoluted to have the
  # data per build, and assumes consistent configuration - but it's easy.
  if (defined($prev_build))
  {
    $this->{BUILD_VARS}{LAST_UPDATE_CHECK} = $prev_build->{BUILD_VARS}{LAST_UPDATE_CHECK};
  }
  else
  {
    $this->{BUILD_VARS}{LAST_UPDATE_CHECK} = time - $this->{ARGS}{upgrade_interval};
  }

  # Check if it's time to look for updates.
  my $check_updates = 0;
  if (!defined($this->{BUILD_VARS}{LAST_UPDATE_CHECK}) || time >= $this->{BUILD_VARS}{LAST_UPDATE_CHECK})
  {
    $this->{BUILD_VARS}{LAST_UPDATE_CHECK} = time;
    $check_updates = 1;
  }

  if ($this->{ARGS}{dir}) {
    if (!chdir($this->{ARGS}{dir})) {
      print "Could not change to directory $this->{ARGS}{dir}!\n";
      $this->maybe_throttle($prev_build);
      return;
    }
  }

  # Open the log
  open $this->{LOG_OUT}, '>', 'tinderclient.log' or die 'Could not output to tinder log';
  open $this->{LOG_IN}, '<', 'tinderclient.log' or die 'Could not read tinder log';

  #
  # Send build start notification
  #
  if (!$this->build_start()) {
    $this->maybe_throttle($prev_build);
    return;
  }

  my $err = 0;
  eval {
    if ($this->{CONFIG}{upgrade} && $check_updates)
    {
      $this->maybe_upgrade($olddir, $config_files);
    }
    $this->print_build_info();

    # Build
    foreach my $module ('init_tree', 'build', 'distribute', 'tests') {
      $err = $this->call_module($module, 'do_action');
      last if $err;
    }

    # Call cleanup
    foreach my $module ('init_tree', 'build', 'distribute', 'tests') {
      $this->call_module($module, 'finish_build');
    }
  };

  # Handle ctrl+c
  if ($@) {
    $this->print_log("ERROR: $@\n");
    $this->build_finish(302);
    die;
  }

  # Send build finish notification (with warning count on success), and
  # calculate the next time this build should run if there is a schedule.
  if ($err < 200) {
    TinderClient::WarningCounter::count_build_warnings_in_log('tinderclient.log', $this->{BUILD_VARS});

    if (   $this->{ARGS}{schedule_interval} >= 1
        && defined($this->{BUILD_VARS}{START_TIME_BUILD}))
    {
      my $slot_now = int((time - $this->{ARGS}{schedule_offset}) / $this->{ARGS}{schedule_interval});
      my $slot_build = int(($this->{BUILD_VARS}{START_TIME_BUILD} - $this->{ARGS}{schedule_offset}) / $this->{ARGS}{schedule_interval});
      if ($slot_now == $slot_build)
      {
        $this->{BUILD_VARS}{SCHEDULED_START_TIME} = ($slot_now + 1) * $this->{ARGS}{schedule_interval} + $this->{ARGS}{schedule_offset};
      }
    }
  } else {
    $this->{BUILD_VARS}{START_TIME_BUILD} = undef;
  }
  $this->build_finish($err || 100);

  # Wait a little if the build was short
  $this->maybe_throttle($prev_build);
}


package TinderClient::SysInfo;

use strict;

use Cwd qw(abs_path);
use POSIX qw(uname);

#
# Get the sysinfo object for this system
#
sub get_sysinfo {
  #
  # Decide which OS SysInfo instance to create
  # (largely copied from the old tinderbox client)
  #
  my ($dir, $jail_script, $jail) = @_;
  my ($os, undef, $os_ver, $os_alt_ver, $cpu) = POSIX::uname();
  chomp($os, $os_ver, $os_alt_ver, $cpu);

  #
  # Handle aliases and weird version numbers
  #
  my %os_aliases = (
    'BSD_OS' => 'BSD/OS',
    'IRIX64' => 'IRIX',
  );
  if ($os_aliases{$os}) {
    $os = $os_aliases{$os};
  }
  if ($os eq 'SCO_SV') {
    $os = 'SCOOS';
    $os_ver = '5.0';
  } elsif ($os eq 'QNX') {
    $os_ver = $os_alt_ver;
    $os_ver =~ s/^([0-9])([0-9]*)$/$1.$2/;
  } elsif ($os eq 'AIX') {
    $os_ver = "$os_alt_ver.$os_ver";
  } elsif ($os eq 'Windows NT') {
    $os = 'WINNT';
    $os_alt_ver =~ tr/0-9//cd;
    $os_alt_ver = '.' . $os_alt_ver if ($os_alt_ver ne '');
    $os_ver = $os_ver . $os_alt_ver;
  } elsif ($os =~ /^CYGWIN_([^-]*)-(.*)$/) {
    $os = "WIN$1";
    $os_ver = $2;
    $os_ver =~ s/-WOW//;
  } elsif ($os eq 'SunOS' && $cpu ne 'i86pc' && substr($os_ver, 0, 1) ne '4') {
    $cpu = 'sparc';
  } elsif ($os eq 'SunOS' && $cpu eq 'i86pc') {
    $cpu = `isainfo | cut -f 1 -d ' '`;
    chomp $cpu;
  } elsif ($os eq 'Linux') {
    $os_ver =~ s/^([0-9]*)\.([0-9]*)\.([0-9]*).*$/$1.$2.$3/;
  }

  return new TinderClient::SysInfo($os, $os_ver, $cpu, $dir, $jail_script, $jail);
}

#
# Sets up the system info object
#
sub new {
  my $class = shift;
  $class = ref($class) || $class;
  my $this = {};
  bless $this, $class;

  my ($os, $os_ver, $cpu, $dir, $jail_script, $jail) = @_;
  $this->{OS} = $os;
  $this->{OS_VERSION} = $os_ver;
  $this->{CPU} = $cpu;

  #
  # Set up compiler
  #
  if ($os =~ /^WIN/) {
    $this->{COMPILER} = 'cl';
  } else {
    $this->{COMPILER} = 'gcc';
  }
  my $version = '';
  if ($this->{COMPILER} eq 'cl') {
    my @compilers = glob($dir . '/tools/win.x86/vcc/*/bin/cl.exe');
    my $cl = $compilers[-1];
    chomp $cl if ($cl);
    if ($cl) {
      $cl = abs_path($cl);
      $version = `$cl 2>&1`;
      my @lines = grep(/Version/, split("\n", $version));
      $version = $lines[0];
      $version =~ s/.*Version ([.\d]*).*/$1/;
    }
  } elsif ($this->{COMPILER} eq 'gcc') {
    if ($jail_script && $jail) {
      $version = `$jail_script $jail 'gcc -dumpfullversion 2>/dev/null || gcc -dumpversion'`;
    } else {
      $version = `gcc -dumpfullversion 2>/dev/null || gcc -dumpversion`;
    }
  }
  chomp $version;
  $this->{COMPILER_VERSION} = $version;

  #
  # Set up ps
  #
  if ($this->{OS} =~ /^WIN/) {
    if ($^O eq 'MSWin32') {
      # Unfortunately the order is always ppid followed by pid, see kill_command.
      $this->{PS_COMMAND} = 'wmic process get parentprocessid,processid';
    } else {
      $this->{PS_COMMAND} = 'ps aux';
    }
  } else {
    $this->{PS_COMMAND} = 'ps -e -o \'pid,ppid\'';
  }

  #
  # figure out a usable ssh command (used with rsync)
  #
  $this->{SSH} = 'ssh';
  if ($^O eq 'MSWin32') {
    if ($cpu eq 'amd64') {
      $this->{SSH} = 'c:/cygwin64/bin/ssh.exe';
    } else {
      $this->{SSH} = 'c:/cygwin32/bin/ssh.exe';
    }
  }

  #
  # remember the right tools fetch directory
  #
  $this->{FETCHDIR} = $ENV{FETCHDIR} || '';
  if ($this->{FETCHDIR} ne '') {
    if ($^O eq 'MSWin32') {
      $this->{FETCHDIR} =~ tr+\\+/+;
    }
    $this->{FETCHDIR_DEFINES} = ' FETCHDIR='.$this->{FETCHDIR};
  } else {
    $this->{FETCHDIR_DEFINES} = '';
  }

  return $this;
}


package TinderClient::WarningCounter;

use strict;

##
# Reads thru tinderbox.log counting the warnings, reporting to the server as a 'warnings' field.
#
# Testcase:
#     require 'tinderclient.pl';
#     foreach my $file (@ARGV){
#         my $build_vars = {};
#         TinderClient::WarningCounter::count_build_warnings_in_log($file, $build_vars);
#         print 'Counted ' . $build_vars->{fields}{warnings} . " warnings in $file.\n";
#     }
#
sub count_build_warnings_in_log {
    my $file = shift;
    my $build_vars = shift;
    my $warnings = 0;

    open LOG, '<', $file or return 0;
    while (<LOG>) {
        if (!/(warning|Warning|WARNING)/) {
            next;
        }

        #
        # Stuff to ignore.
        #
        if (/^Warnings:$/) {      # python unittests
            next;
        }
        if (/^warning: .*padding=.*suggest=/) { # structure padding suggestions
            next;
        }
        if (/^install: warning: Not hard linking, mode differs:/) {
            next;
        }
        if (/anonymous variadic macros were introduced in C99/) {
            next;
        }
        if (/unused variable .RTASSERTVAR/) {
            next;
        }

        #
        # Compiler, assembler, midl, and linker warning:
        #
        if (/ : warning /) {        # f:\...\GuestDnDPrivate.h(668) : warning C4244: 'initializing' : conversion ...
            $warnings += 1;         # LINK : warning LNK4199: /DELAYLOAD:d3d9.dll ignored; no imports found from d3d9.dll
        }                           # F:\...\VirtualBox.idl(5939) : warning MIDL2456 : SAFEARRAY(interface pointer) doesn't ...
        elsif (/warning (MIDL|LNK|C)\d{4,}/)  { # (output mixup - otherwise same as above first)
            $warnings += 1;
        }
        elsif (/: warning: /) {     # F:\...\LegacyandAMD64.mac:1833: warning: value does not fit in 32 bit field
            $warnings += 1;         # /.../xpidl_util.c:838:27: warning: 'g_basename' is deprecated [-Wdeprecated-declarations]
        }
        elsif (/: Warning ALP\d{4,}: /) { # E:\...\data.asm(160:22): Warning ALP4507: Only storing NEAR portion of FAR pointer
            $warnings += 1;
        }
        #
        # Command line warnings not caught by the above.
        #
        elsif (/ : Command line warning /) { # cl : Command line warning D9025 : overriding '/GR' with '/GR-'
            $warnings += 1;
        }
        elsif (/^warning: ignoring /) { # warning: ignoring -fapple-kext which is valid for C++ and Objective-C++ only
            $warnings += 1;
        }
        elsif (/warning: \[options\] /) { # warning: [options] source value 1.5 is obsolete and will be removed in a future release
            $warnings += 1;
        }
        #
        # Linker warnings.
        #
        elsif (/^Warning! /) {      # Warning! W1080: file F:\...\VBoxPcBios386\pcibio32.obj is a 32-bit object file
            $warnings += 1;
        }
        elsif (/^warning: /) {       # warning: no debug symbols in executable (-arch x86_64)
            $warnings += 1;
        }
        #
        # Other stuff.
        #
        elsif (/^kmk: warning: /) { # kmk: warning: undefined variable `buildserver-additions_0_OUTDIR'
            $warnings += 1;
        }
        elsif (/:\d+: warning, /) {  # /../dt_lex.l:429: warning, dangerous trailing context
            $warnings += 1;
        }
        elsif (/^Warning: /) {      # qt xml
            $warnings += 1;
        }
        elsif (/\*\*\* WARNING: /) { # *** WARNING: No build ID note found in /.../libQt5WidgetsVBox.so.5
            $warnings += 1;
        }
        elsif (/^WARNING: /) {      # WARNING: missing directory entry for <usr/kernel/drv/amd64>
            $warnings += 1;
        }
        #
        # Debug.
        #
        ##elsif (   / padding=\d+ /     # warning: GVM::gmm     : padding=512   s=264   -> 248   suggest=264
        ##       or /, 0 Warnings,/     # Compilation complete. 0 Errors, 0 Warnings, 0 Remarks, 72 Optimizations
        ##       or /[Ww]arning[a-zA-Z0-9_]*\.(cpp|c|h|moc)/      # src/widgets/UIWarningPane related progress messages
        ##       or /\+\+\+ WARNING +\+\+ WARNING \+\+\+/         # configure hardening warning
        ##       or /^\d+ warnings{0,1}$/              # java warning count
        ##       or /^\d+ warnings{0,1} generated.$/              # clang warning count
        ##       or /to silence this warning/                     # clang note regarding warning
        ##       or /^    .* \w+[Ww]arning\w*/                    # verbose warning location (public List<String> getWarnings()).
        ##       )
        ##{ }
        ##else
        ##{
        ##    print $_;
        ##}
        else {
            next;
        }
        ##print $_;
    }
    close LOG;

    $build_vars->{fields}{warnings} = $warnings;
}


package TinderClient::Modules::init_tree;

use strict;

use Cwd qw(getcwd);
use File::Which qw(which);
use HTML::Entities qw(decode_entities);

sub get_config {
  my ($client, $config, $persistent_vars, $build_vars, $content_ref) = @_;

  if ($config->{usemozconfig}) {
    if (${$content_ref} =~ /<mozconfig[^>]*>(.*)<\/mozconfig>/sm) {
      $build_vars->{MOZCONFIG} = decode_entities($1);
    }
  }
  $client->get_field($content_ref, 'use_svn');
  $client->get_field($content_ref, 'svn_url');
  $client->get_field($content_ref, 'svn_user');
  $client->get_field($content_ref, 'svn_params');
  $client->get_field($content_ref, 'cvs_co_date');
  $client->get_field($content_ref, 'tree_type');
  $client->get_field($content_ref, 'build_tag');
  $client->get_field($content_ref, 'compile_only');
  $client->get_field($content_ref, 'cvsroot');
  $client->get_field($content_ref, 'clobber');
  $client->get_field($content_ref, 'branch');
  $client->get_field($content_ref, 'checkout');
  if ($config->{usepatches}) {
    $build_vars->{PATCHES} = [];
    while (${$content_ref} =~ /<patch[^>]+id\s*=\s*['"](\d+)['"]/g) {
      push @{$build_vars->{PATCHES}}, $1;
    }
  }
  $client->get_field($content_ref, 'build_additions');
  $client->get_field($content_ref, 'build_docs');
  $client->get_field($content_ref, 'build_efi');
  $client->get_field($content_ref, 'build_extpacks');
  $client->get_field($content_ref, 'build_ose');
  $client->get_field($content_ref, 'build_sdk');
  $client->get_field($content_ref, 'build_testsuite');
  $client->get_field($content_ref, 'build_vboximg');
  $client->get_field($content_ref, 'build_vbb');
  $client->get_field($content_ref, 'build_debrpm');
  $client->get_field($content_ref, 'build_osetarball');
  $client->get_field($content_ref, 'build_linux_kmods');
  $client->get_field($content_ref, 'build_qt');
  $client->get_field($content_ref, 'build_parfait');

  $client->get_field($content_ref, 'ENV_OPT');
  $config->{ENV_OPT} ||= '';
  if ($config->{build_ose})
  {
    $client->get_field($content_ref, 'CONFIGURE_OPTIONS');
  }
  $client->get_field($content_ref, 'PARFAIT');
  $config->{PARFAIT} ||= '';
  $client->get_field($content_ref, 'PATH');
  $config->{PATH} ||= '';
  $client->get_field($content_ref, 'KBUILD_DEVTOOLS'); # for build_qt only!
  $config->{KBUILD_DEVTOOLS} ||= '';
  $client->get_field($content_ref, 'VBOX_WITH_COMBINED_PACKAGE');
  $client->get_field($content_ref, 'VBOX_TOOLSERVER_URL');
  $config->{VBOX_TOOLSERVER_URL} ||= '';
  if (!$config->{build_vbb} && !$config->{build_qt})
  {
    $client->get_kbuild_fields($content_ref);
  }

  $persistent_vars->{LAST_CHECKOUT} = 0 if !exists($persistent_vars->{LAST_CHECKOUT});
  $persistent_vars->{LAST_TREE_REV} = 0 if !exists($persistent_vars->{LAST_TREE_REV});

  my @mozconfig = $build_vars->{MOZCONFIG};

  #
  # Parse mozconfig parameters
  #
  while (<@mozconfig>)
  {
    my ($name, $value) = split /=/;
    if (defined($name))
    {
      $build_vars->{$name} = $value;
    }
  }
}

sub finish_build {
  my ($client, $config, $persistent_vars, $build_vars) = @_;

}

sub get_cvs_branch {
  my ($client) = @_;
  if (open ENTRIES, '<', 'CVS/Entries') {
    while (<ENTRIES>) {
      next if /^D/;
      chomp;
      my @line = split /\//;
      if ($line[1] eq 'Config.kmk') {
        close ENTRIES;
        return substr($line[5], 1);
      }
    }
    close ENTRIES;
  }
  $client->print_log("Warning: could not open CVS/Entries or find config.kmk in it\n");
  return undef;
}

sub do_action {
  my ($client, $config, $persistent_vars, $build_vars) = @_;
  my $init_tree_status = 2;
  my $checkout_timeout = 30*60; # 30 minutes

  #
  # We will only build if:
  # - new patches were downloaded
  # - checkout brought something down
  # - the build command was specified
  #
  $build_vars->{SHOULD_BUILD} = 0;
  if ($config->{build_ose})
  {
    $build_vars->{SHOULD_EMERGE} = 0;
  }

  if (!$config->{build_vbb} && !$config->{build_qt})
  {
    # Prepare the environment setup string before executing commands.
    ## @todo r=bird: We repeat some of these on the kmk command line, which is a little wasteful.  Try trim it down.
    $build_vars->{envsetup} = '';
    foreach my $var ('KBUILD_TYPE', 'KBUILD_TARGET', 'KBUILD_TARGET_ARCH', 'KBUILD_HOST', 'KBUILD_HOST_ARCH',
                     'PARFAIT', 'PATH', 'VBOX_TOOLSERVER_URL') {
      if ($config->{$var} ne '') {
        if ($^O eq 'MSWin32') {
          $build_vars->{envsetup} .= 'set '.$var.'='.$config->{$var}.'& ';
        } else {
          $build_vars->{envsetup} .= $var.'='.$config->{$var}.' ';
        }
      }
    }

    # Let the older branches have the old variables.
    if (   $config->{svn_url} =~ /svn\/branches\/VBox-[0-5]\./
        || $config->{svn_url} =~ /svn\/branches\/VBox-6\.0\./) {
      $client->print_log("Info: Adding old build variables to the environment.\n");
      my %old_vars = ( 'BUILD_TYPE' => 'KBUILD_TYPE',
                       'BUILD_TARGET' => 'KBUILD_TARGET', 'BUILD_TARGET_ARCH' => 'KBUILD_TARGET_ARCH',
                       'BUILD_PLATFORM' => 'KBUILD_HOST', 'BUILD_PLATFORM_ARCH' => 'KBUILD_HOST_ARCH');
      foreach my $oldvar(keys %old_vars) {
        my $var = $old_vars{$oldvar};
        if ($config->{$var} ne '') {
          if ($^O eq 'MSWin32') {
            $build_vars->{envsetup} .= 'set '.$oldvar.'='.$config->{$var}.'& ';
          } else {
            $build_vars->{envsetup} .= $oldvar.'='.$config->{$var}.' ';
          }
        }
      }
    }
  }

  #
  # find a decent shell and construct the command prefix when explicitly needed
  #
  my $shellprefix = '';
  if ($client->sysinfo()->{OS} =~ /^WIN/) {
    if ($^O eq 'MSWin32') {
      $shellprefix = getcwd() . '/kBuild/bin/win.' . $client->sysinfo()->{CPU} . '/kmk_ash.exe';
      if (! -f $shellprefix) {
        # Just a pro-forma fallback, it lacks many basics.
        $shellprefix ||= which('sh.exe');
      }
      $shellprefix ||= 'need_sh.exe';
      $shellprefix =~ tr/\//\\/; # Convert to DOS slashes so the shell can't get confused.
    }
  }
  $shellprefix .= ' ' if (length($shellprefix) > 0);
  $build_vars->{shellprefix} = $shellprefix;

  #
  # Checkout the root dir, tools and kBuild if we've never done this before
  #
  if (   !$config->{build_vbb}
      && !$config->{build_qt}
      && (   (! -f 'Config.kmk' && ! -f 'config.kmk')
          || (! -f 'kBuild/footer.kmk')
          || (! -f 'tools/env.sh' && !$config->{build_ose})
         )
     ) {
    $build_vars->{SHOULD_BUILD} = 1;

    # calc args.
    my $svn_co_rev;
    my $cvs_co_params = ' -PA';
    my $svn_co_params = ' --non-interactive';
    if ($config->{build_ose})
    {
      $svn_co_params .= ' --ignore-externals';
    }
    if ($config->{svn_user} ne '') {
      $svn_co_params .= ' --username '.$config->{svn_user};
    }
    if ($config->{svn_params} ne '') {
      $svn_co_params .= ' '.$config->{svn_params};
    }
    if ($config->{cvs_co_date} && $config->{cvs_co_date} ne 'off') {
      if ($config->{cvs_co_date} =~ /^r\d+$/) { # subversion only: r12345
        $svn_co_rev = '-' . $config->{cvs_co_date};
      } else {
        $cvs_co_params .= " -D '$config->{cvs_co_date}'";
        $svn_co_rev = "-r '{".$config->{cvs_co_date}."}'";
      }
    } else {
      $svn_co_rev = '-r HEAD';
    }
    if ($config->{branch}) {
      $cvs_co_params .= " -r $config->{branch}";
      # For subversion use the branch setting as the revision to check out
      $svn_co_rev = "-r $config->{branch}";
    }

    if ($config->{use_svn}) {
      # Checkout VBox, kBuild and kStuff.
      $client->do_command("svn co $svn_co_params $svn_co_rev $config->{svn_url} .", $init_tree_status, undef, $checkout_timeout);
      if (! -f 'kBuild/footer.kmk')
      {
        my $ext_rev_kbuild = `svn pg svn:externals .`;
        my @lines = grep(/kBuild/, split("\n", $ext_rev_kbuild));
        $ext_rev_kbuild = $lines[0];
        chomp $ext_rev_kbuild;
        $ext_rev_kbuild =~ s/^[^ ]* +([^ ]+ *[0-9]+) +.*$/$1/;
        my $tmpurl = $config->{svn_url};
        if ($config->{build_ose})
        {
          $tmpurl =~ s/\/vbox-ose\//\/kbuild-mirror\//;
        }
        else
        {
          $tmpurl =~ s/\/(vbox|xenpv)\//\/kbuild\//;
        }
        $client->do_command("svn co $svn_co_params $ext_rev_kbuild $tmpurl/kBuild kBuild", $init_tree_status, undef, $checkout_timeout);
      }
    } else {
      # The basic VBox stuff (the normal update does the rest)
      $client->do_command("cvs -z3 -d$config->{cvsroot} co$cvs_co_params -l Config.kmk", $init_tree_status, undef, $checkout_timeout);
      $client->do_command("cvs -z3 -d$config->{cvsroot} up -l $cvs_co_params", $init_tree_status, undef, $checkout_timeout);
      $client->do_command("cvs -z3 -d$config->{cvsroot} up -d $cvs_co_params tools", $init_tree_status, undef, $checkout_timeout);

      # kBuild
      my $tmproot = $config->{cvsroot};
      $tmproot =~ s/^(.*)\/[a-zA-Z0-9]*$/$1\/kbuild/;
      $client->do_command("cvs -z6 -d $tmproot co $cvs_co_params kBuild", $init_tree_status, undef, $checkout_timeout);
    }

    # verify that it went ok and we got the basic stuff.
    if (   (! -f 'Config.kmk' && ! -f 'config.kmk')
        || (! -f 'kBuild/footer.kmk')
        || (! -f 'tools/env.sh' && !$config->{build_ose})
       ) {
      $client->print_log("Could not check out root dir, tools and/or kBuild!\n");
      return 200;
    }

  }
  elsif (   ($config->{build_vbb} && ! -f 'src/configure.ac')
         || ($config->{build_qt} && ! -f 'vbox-clean-all.sh') )
  {
    $build_vars->{SHOULD_BUILD} = 1;

    # calc args.
    my $svn_co_rev;
    my $svn_co_params = ' --non-interactive';
    if ($config->{svn_user} ne '') {
      $svn_co_params .= ' --username '.$config->{svn_user};
    }
    if ($config->{svn_params} ne '') {
      $svn_co_params .= ' '.$config->{svn_params};
    }
    if ($config->{cvs_co_date} && $config->{cvs_co_date} ne 'off') {
      if ($config->{cvs_co_date} =~ /^r\d+$/) { # subversion only: r12345
        $svn_co_params .= ' -' . $config->{cvs_co_date};
      } else {
        $svn_co_params .= " -r '{".$config->{cvs_co_date}."}'";
      }
    } else {
      $svn_co_params .= ' -r HEAD';
    }
    if ($config->{branch}) {
      # For subversion use the branch setting as the revision to check out
      $svn_co_rev = "-r $config->{branch}";
    }

    if ($config->{use_svn}) {
      # Checkout tree.
      $client->do_command("svn co $svn_co_params $config->{svn_url} .", $init_tree_status, undef, $checkout_timeout);
    }

    # verify that it went ok and we got the basic stuff.
    if (   ($config->{build_vbb} && ! -f 'src/configure.ac')
        || ($config->{build_qt} && ! -f 'vbox-clean-all.sh') )
    {
      $client->print_log("Could not check out tree!\n");
      return 200;
    }
  }

  #
  # Create LocalConfig.kmk if necessary
  #
  # First read LocalConfig.kmk
  my $please_clobber = 0;
  my $mozconfig = $client->read_mozconfig();
  $mozconfig ||= '';
#  print "@@@ LocalConfig.kmk:\n$mozconfig\n@@@ network LocalConfig.kmk:\n$build_vars->{MOZCONFIG}\n";
  if ($build_vars->{MOZCONFIG}) {
    if ($mozconfig ne $build_vars->{MOZCONFIG}) {
      if ($ENV{MOZCONFIG}) { # crashed on win64dep, this seems to work around the issue...
        $ENV{MOZCONFIG} = undef;
      }
      delete $ENV{MOZCONFIG};
      $client->start_section('CREATING LocalConfig.kmk');
      open MOZCONFIG, '>', 'LocalConfig.kmk';
      print MOZCONFIG $build_vars->{MOZCONFIG};
      close MOZCONFIG;
      $mozconfig = $build_vars->{MOZCONFIG};
      $client->print_log("(Will clobber this cycle)\n");
      $client->end_section('CREATING LocalConfig.kmk');
      $please_clobber = 1;
    }
  }

  #
  # Print build info
  #
  $client->start_section('PRINTING BUILD INFO');
  $client->print_log(<<EOM);
== LocalConfig.kmk
$mozconfig
== End LocalConfig.kmk
EOM


  #
  # Clean up the tree if requested to do so. Errors are ignored.
  #
  if ($client->eat_command('cleanup')) {
    if (!$config->{build_vbb} && !$config->{build_qt})
    {
      $client->do_command('svn cleanup kBuild');
      # kStuff is gone for good, but keep the script code around for a bit just in case.
      if (0 && -f 'src/libs/kStuff/kStuff/Makefile.kmk') {
        $client->do_command('svn cleanup src/libs/kStuff/kStuff');
      }
    }
    $client->do_command('svn cleanup');
  }

  #
  # Remove patches
  #
  foreach my $patch (glob('tbox_patches/*.patch')) {
    if ($config->{use_svn}) {
      $client->do_command("svn patch --reverse-diff --strip 0 $patch", $init_tree_status);
    } else  {
      $client->do_command("patch -Nt -Rp0 < $patch", $init_tree_status);
    }
    $client->do_command("mv $patch $patch.removed");
  }
  my @old_patches;
  foreach my $rpatch (glob('tbox_patches/*.patch.removed')) {
    if ($rpatch =~ /^tbox_patches\/(.+)\.patch\.removed$/) {
      push @old_patches, $1;
    }
  }
  my $have_patches = $config->{tree_type} eq 'build_new_patch' && scalar(@{$build_vars->{PATCHES}}) > 0;

  # Invoke svn revert -R to be on the safe side.
  if (   $config->{use_svn} && $config->{tree_type} ne 'build_new_patch'
      || !$have_patches)
  {
    if (!$config->{build_vbb} && !$config->{build_qt}) {
      $client->do_command('svn revert -R kBuild');
      # kStuff is gone for good, but keep the script code around for a bit just in case.
      if (0 && -f 'src/libs/kStuff/kStuff/Makefile.kmk') {
        $client->do_command('svn revert -R src/libs/kStuff/kStuff');
      }
    }
    if (   $config->{tree_type} eq 'build_new_patch' && !$have_patches
        || $client->eat_command('revert'))
    {
      $client->do_command('svn revert -R .');
    }
  }

  my $err = 0;

  #
  # OSE: If the sync command is received, update the internal vbox-ose
  # repository. Without this it doesn't make sense to look at the repository.
  #
  if ($config->{build_ose} && $client->eat_command('emerge'))
  {
    $build_vars->{SHOULD_EMERGE} = 1;
    # Have to force building, as otherwise a not buildable (but unchanged)
    # tree can end up on the public repository.
    $build_vars->{SHOULD_BUILD} = 1;
  }
  if ($config->{build_ose} && $client->sysinfo()->{OS} eq 'Linux')
  {
    if ($client->eat_command('sync') || $build_vars->{SHOULD_EMERGE})
    {
      $err = $client->do_command_jail('../svnsync-vbox/sync-vbox-ose', $init_tree_status);
      if ($err)
      {
        return $err;
      }
    }
  }

  #
  # Update Tree - If history shows any recent changes.
  #
  $build_vars->{SHOULD_BUILD_UP} = 0;
  my $cvs_parsing_code = sub {
                       if ($_[0] =~ /^[UP] /m) {
                         $build_vars->{SHOULD_BUILD_UP} = 1;
                       }
                       if ($config->{lowbandwidth} && $_[0] =~ /^\? /m) {
                         return '';
                       }
                       return $_[0];
                     };
  my $svn_parsing_code = sub {
                       if ($_[0] =~ /^([ADUCG][ ADUCG]| [ADUCG]|Restored )/m) {
                         $build_vars->{SHOULD_BUILD_UP} = 1;
                         return $_[0];
                       }
                       if ($config->{lowbandwidth} && $_[0] =~ /^\? /m) {
                         return '';
                       }
                       return $_[0];
                     };
  my $svn_up_rev;
  my $cvs_up_params = ' -PdA';
  my $svn_up_params = ' --non-interactive';
  if ($config->{build_ose})
  {
    $svn_up_params .= ' --ignore-externals';
  }
  if ($config->{svn_user} ne '') {
    $svn_up_params .= ' --username '.$config->{svn_user};
  }
  if ($config->{svn_params} ne '') {
    $svn_up_params .= ' '.$config->{svn_params};
  }
  if ($config->{cvs_co_date} && $config->{cvs_co_date} ne 'off') {
    if ($config->{cvs_co_date} =~ /^r\d+$/) { # subversion only: r12345
      $svn_up_rev = ' -' . $config->{cvs_co_date};
    } else {
      $cvs_up_params .= " -D '$config->{cvs_co_date}'";
      $svn_up_rev = "-r '{".$config->{cvs_co_date}."}'";
    }
  } else {
    $svn_up_rev = '-r HEAD';
  }
  if ($config->{branch}) {
    $cvs_up_params .= " -r $config->{branch}";
    # For subversion use the branch setting as the revision to update to
    $svn_up_rev = "-r $config->{branch}";
  }

  my $build_rev;
  my $rev_author;
  # update VBox, kBuild and kStuff
  if ($config->{use_svn}) {
    $err = $client->do_command("svn up $svn_up_params $svn_up_rev", $init_tree_status+1, $svn_parsing_code, $checkout_timeout, 5);
    my ($command, $status, $grep_sub, $max_idle_time) = @_;
    if (!$err && !$config->{build_vbb}) {
      my $env_lc;
      if ($^O eq 'MSWin32') {
        $env_lc = 'set LC_ALL=C& ';
      } else {
        $env_lc = 'LC_ALL=C ';
      }
      my $svn_info = `${env_lc}svn info .`;
      my @lines = grep(/^Last Changed Rev/, split("\n", $svn_info));
      $build_rev = $lines[0];
      $build_rev =~ s/Last Changed Rev: *//;
      chomp $build_rev;
      $build_rev =~ s/^\s+|\s+$//g;
      @lines = grep(/^Last Changed Author/, split("\n", $svn_info));
      $rev_author = $lines[0];
      $rev_author =~ s/Last Changed Author: *//;
      chomp $rev_author;
      $rev_author =~ s/^\s+|\s+$//g;
      if ($config->{build_ose})
      {
        my $ext_rev_ose_kbuild=`svn pg svn:externals .`;
        @lines = grep(/kBuild/, split("\n", $ext_rev_ose_kbuild));
        $ext_rev_ose_kbuild = $lines[0];
        chomp $ext_rev_ose_kbuild;
        $ext_rev_ose_kbuild =~ s/^[^ ]* +([^ ]+ *[0-9]+) +.*$/$1/;
        $err = $client->do_command("svn up $svn_up_params $ext_rev_ose_kbuild kBuild", $init_tree_status+1, $svn_parsing_code, $checkout_timeout, 5);
      }
      elsif (!$config->{build_qt})
      {
        my $external = `svn pg svn:externals .`;
        @lines = grep(/kBuild/, split("\n", $external));
        $external = $lines[0];
        if (!$external) {
          $err = $client->do_command("svn up $svn_up_params kBuild", $init_tree_status+1, $svn_parsing_code, $checkout_timeout, 5);
        }
      }
    }
  } else {
    if (need_cvs_update($client, $config, $persistent_vars)) {
      $err = $client->do_command("cvs -z3 up $cvs_up_params", $init_tree_status+1, $cvs_parsing_code, $checkout_timeout);
    }
    if (!$err && chdir('kBuild')) {
      if (need_cvs_update($client, $config, $persistent_vars)) {
        $err = $client->do_command("cvs -z3 up $cvs_up_params", $init_tree_status+1, $cvs_parsing_code, $checkout_timeout);
      }
      chdir('..');
    }
  }

  if (defined($build_rev) && !$config->{build_qt}) {
    # Prepare additional environment setup before executing commands to avoid svn calls from the makefiles.
    foreach my $var_prefix ('VBOX_ADDITIONS_SH', 'VBOX_DOCUMENTATION_SH', 'VBOX_EFI_SH', 'VBOX_EXTPACKS_SH') {
      if ($config->{$var_prefix.'_BRANCH'} ne '') {
        if ($^O eq 'MSWin32') {
          $build_vars->{envsetup} .= 'set '.$var_prefix.'_BRANCH='.$config->{$var_prefix.'_BRANCH'}.'& ';
          $build_vars->{envsetup} .= 'set '.$var_prefix.'_REV='.$build_rev.'& ';
        } else {
          $build_vars->{envsetup} .= $var_prefix.'_BRANCH='.$config->{$var_prefix.'_BRANCH'}.' ';
          $build_vars->{envsetup} .= $var_prefix.'_REV='.$build_rev.' ';
        }
      }
    }
  }

  if ($config->{tree_type} eq 'build_new_patch') {
    # build_new_patch: We only build if there's a new patch pending.  We must clobber.
    if (scalar(@{$build_vars->{PATCHES}}) > 0) {
      $client->print_log("Have patches, will build: " . join(', ', @{$build_vars->{PATCHES}}) . "\n");
      $build_vars->{SHOULD_BUILD} = 1;
      $please_clobber = 1;
    } else {
      # Stop right now.
      $client->print_log("No new patches pending. Won't build.\n");
      $build_vars->{SHOULD_BUILD} = 0;
      $err = 304;
    }
  }
  elsif (   $config->{build_additions} || $config->{build_docs} || $config->{build_efi} || $config->{build_extpacks}
         || $config->{build_testsuite} || $config->{build_vboximg}) {
    my $shellprefix = $build_vars->{shellprefix};
    # When building the additions/docs/efi/testsuite calc the tree revision and check
    # if something has really changed.
    my $calcrev;
    if ($config->{build_additions}) {
      $calcrev = `${shellprefix}tools/env.sh --quiet --no-wine kmk_ash tools/bin/additions.sh --cmd calcrev`;
    }
    elsif ($config->{build_docs}) {
      $calcrev = `${shellprefix}tools/env.sh --quiet --no-wine kmk_ash tools/bin/documentation.sh --cmd calcrev`;
    }
    elsif ($config->{build_efi}) {
      $calcrev = `${shellprefix}tools/env.sh --quiet --no-wine kmk_ash tools/bin/efi_firmware.sh --cmd calcrev`;
    }
    elsif ($config->{build_extpacks}) {
      $calcrev = `${shellprefix}tools/env.sh --quiet --no-wine kmk_ash tools/bin/extpacks.sh --cmd calcrev`;
    }
    elsif ($config->{build_testsuite}) {
      $calcrev = `${shellprefix}tools/env.sh --quiet --no-wine kmk_ash tools/bin/validationkit.sh --cmd calcrev`;
    }
    elsif ($config->{build_vboximg}) {
      $calcrev = `${shellprefix}tools/env.sh --quiet --no-wine kmk_ash tools/bin/vbox_img.sh --cmd calcrev`;
    }
    $calcrev =~ s/\r//;
    $calcrev =~ s/\n//;
    $build_vars->{TREE_REV} = $calcrev;
    $client->print_log("Tree revision: $calcrev\n");
    if (   !$build_vars->{SHOULD_BUILD}
        && $build_vars->{SHOULD_BUILD_UP}) {
      if ($build_vars->{TREE_REV} ne $persistent_vars->{LAST_TREE_REV}) {
        $build_vars->{SHOULD_BUILD} = 1;
        $client->print_log("Found tree changes during checkout! (".
                           $persistent_vars->{LAST_TREE_REV}.
                           " -> ".$build_vars->{TREE_REV}.
                           ")  Will build.\n");
      } else {
        $client->print_log("No relevant tree changes.\n");
      }
    }
    $persistent_vars->{LAST_TREE_REV} = $build_vars->{TREE_REV};
  }
  elsif ($config->{build_osetarball}) {
    if (   !$build_vars->{SHOULD_BUILD}
        && $build_vars->{SHOULD_BUILD_UP}) {
      my $exact = 0;
      my $even_build = 0;
      my $prerelease = 0;
      if (open VERSION, '<', 'Version.kmk') {
        while (<VERSION>) {
# chomp would need help, so do it all in one.
          s/\s*\r?\n$//;
          $exact = 1 if (/^VBOX_RELEASE_EXACT_MATCH\s*=\s*1$/);
          $even_build = 1 if (/^VBOX_VERSION_BUILD\s*=\s*[0-9]*[02468]$/);
          $prerelease = 1 if (/^VBOX_VERSION_PRERELEASE\s*=\s*[A-Z]/);
        }
      }
      close VERSION;
      if ($exact || ($even_build && !$prerelease)) {
        $build_vars->{SHOULD_BUILD} = 1;
        $client->print_log("Found tree changes during checkout!  Will build because it is a matching release.\n");
      } else {
        $client->print_log("Found tree changes during checkout!  Will not build tarball anyway unless it is forced by a 'build' command.\n");
      }
    }

  } elsif ($build_vars->{SHOULD_BUILD_UP}) {
    $build_vars->{SHOULD_BUILD} = 1;
    $client->print_log("Found tree changes during checkout!  Will build.\n");
  }
  $persistent_vars->{LAST_CVS_CO_DATE} = $config->{cvs_co_date};

  #
  # Clobber
  #
  # We clobber:
  # - when we need to build and we are a clobber build
  # - when there is a clobber command in the queue or the mozconfig changed
  #
  if (   !$err
      && (  (   $build_vars->{SHOULD_BUILD}
             && $config->{clobber})
          || $client->eat_command('clobber')
          || $please_clobber)
     ) {
    $please_clobber = 1;
    if (!$config->{build_vbb} && !$config->{build_qt})
    {
      if ($client->sysinfo()->{OS} eq 'Darwin') {
        $err = $client->do_command('sudo rm -Rf '. ($client->{ARGS}{out_dir} ? $client->{ARGS}{out_dir}.'/' : 'out/'), $init_tree_status+4);
      } else {
        $err = $client->do_command('rm -rf '. ($client->{ARGS}{out_dir} ? $client->{ARGS}{out_dir}.'/' : 'out/'), $init_tree_status+4);
      }
    }
    elsif ($config->{build_vbb})
    {
      $client->do_command('rm -rf src/usr/ src/etc src/*/optimized/*', $init_tree_status+4);
    }
    elsif ($config->{build_qt})
    {
      my $cmd = '';
      if ($client->sysinfo()->{OS} =~ /^WIN/)
      {
        $cmd = 'vbox-clean-all.cmd verbose';
      }
      else
      {
        $cmd = './vbox-clean-all.sh --verbose';
      }
      foreach my $var ('KBUILD_DEVTOOLS', 'PATH')
      {
        if ($config->{$var} ne '')
        {
          if ($^O eq 'MSWin32')
          {
            $cmd = 'set '.$var.'='.$config->{$var}.'& ' . $cmd;
          }
          else
          {
            $cmd = $var.'='.$config->{$var}.' ' . $cmd;
          }
        }
      }
      $err = $client->do_command($cmd, $init_tree_status+4);
    }
    $build_vars->{SHOULD_BUILD} = 1;
  }

  #
  # If the build command is specified, we build no matter what
  #
  if ($client->eat_command('build') || $config->{build}) {
    $build_vars->{SHOULD_BUILD} = 1;
  }

  #
  # Apply patches
  #
  my @patches_applied;
  $build_vars->{fields}{patch} = [];
  if (   !$err
      && (   join(' ', sort @old_patches) ne join(' ', sort @{$build_vars->{PATCHES}})
          || $build_vars->{SHOULD_BUILD})
     ) {
    $build_vars->{SHOULD_BUILD} = 1;
    $client->start_section('APPLYING PATCHES');
    # Remove old patches
    unlink(<tbox_patches/*.patch.removed>);
    # Apply new patches
    foreach my $patch_id (@{$build_vars->{PATCHES}}) {
      my $npatch = $client->get_patch($patch_id);
      $client->print_log("PATCH: $npatch\n");
      if (! $npatch) {
        $err = 200;
      } else {
        my $local_err;
        if ($config->{use_svn}) {
          $local_err = $client->do_command("svn patch --dry-run --strip 0 $npatch", $init_tree_status+5);
          if (!$local_err) {
            $local_err = $client->do_command("svn patch --strip 0 $npatch", $init_tree_status+5);
          }
        } else {
          $local_err = $client->do_command("patch --dry-run -Nt -p0 < $npatch", $init_tree_status+5);
          if (!$local_err) {
            $local_err = $client->do_command("patch -Nt -p0 < $npatch", $init_tree_status+5);
          }
        }
        if ($local_err) {
          unlink($npatch);
          $err = 200;
        } else {
          push @{$build_vars->{fields}{patch}}, $patch_id;
        }
      }
    }
    $client->end_section('APPLYING PATCHES');
  }

  #
  # Show the tree state so we can spot unwanted local changes.
  #
  if ($config->{use_svn}) {
    $client->do_command('svn status');
    $client->do_command('svn diff');
  }

  #
  # Fetch tools.
  #
  if (   !$err
      && !$config->{build_ose}
      && !$config->{build_vbb}
      && !$config->{build_linux_kmods}
      && -f 'tools/Makefile.kmk' ) {
    my $kmk = $build_vars->{envsetup}.$build_vars->{shellprefix}.
              'tools/env.sh '.$config->{ENV_OPT}.
              ' kmk'.
              ' KBUILD_TARGET='.$config->{KBUILD_TARGET}.
              ' KBUILD_TYPE='.$config->{KBUILD_TYPE}.
              ' KBUILD_HOST='.$config->{KBUILD_HOST}.
              $client->sysinfo()->{FETCHDIR_DEFINES}.
              ' '.$config->{KMK_DEFINES};
    my $fetchopt = ' VBOX_NOINC_DYNAMIC_CONFIG_KMK=1';
    if ($config->{build_additions}) {
      $err = $client->do_command_jail($kmk . $fetchopt . ' additions-fetch', $init_tree_status+2);
    }
    elsif ($config->{build_efi}) {
      $err = $client->do_command_jail($kmk . $fetchopt . ' efi-fetch', $init_tree_status+2);
    }
    elsif ($config->{build_extpacks}) {
      $err = $client->do_command_jail($kmk . $fetchopt . ' extpacks-fetch', $init_tree_status+2);
    }
    elsif ($config->{build_sdk}) {
      $err = $client->do_command_jail($kmk . $fetchopt . ' -f Maintenance.kmk sdk-fetch', $init_tree_status+2);
    }
    elsif ($config->{build_testsuite}) {
      $err = $client->do_command_jail($kmk . $fetchopt . ' validationkit-fetch', $init_tree_status+2);
    }
    elsif ($config->{VBOX_WITH_COMBINED_PACKAGE} && $config->{VBOX_WITH_COMBINED_PACKAGE} eq '2') {
      $err = $client->do_command_jail($kmk . $fetchopt . ' -f Maintenance.kmk combined-package-fetch', $init_tree_status+2);
    }
    elsif ($config->{build_debrpm}) {
      $err = $client->do_command($kmk . $fetchopt . ' VBOX_WITH_TOOLS_QT_LINUX=1 -C tools pass_fetches', $init_tree_status+2);
    }
    else
    {
      $err = $client->do_command_jail($kmk . $fetchopt . ' -C tools pass_fetches', $init_tree_status+2);
      if (!$err && $config->{VBOX_WITH_COMBINED_PACKAGE}) {
        # Combined package building requires both 32bit and 64bit tools.
        # Assume this is a 32bit build.
        $err = $client->do_command_jail($kmk . $fetchopt . ' KBUILD_TARGET_ARCH=amd64 KBUILD_HOST_ARCH=amd64 -C tools pass_fetches', $init_tree_status+2);
      }
    }

    #
    # Clobber again, if clobber build, so DynamicConfig.kmk is re-generated with all the tools there.
    #
    # Note! This is also required for older GA, ExtPack and Testsuite builds, as a
    #       host generated DynamicConfig.kmk will otherwise be synced into the VMs.
    #
    if (   !$err
        && $build_vars->{SHOULD_BUILD}
        && $please_clobber) {
      $err = $client->do_command('rm -Rf '. ($client->{ARGS}{out_dir} ? $client->{ARGS}{out_dir}.'/' : 'out/'), $init_tree_status+4);
    }
  }

  #
  # Log the final decision.
  #
  if ($build_vars->{SHOULD_BUILD}) {
    if (defined($build_rev)) {
      $build_vars->{fields}{build_rev} = $build_rev;
      if (!$build_vars->{TREE_REV}) {
        $build_vars->{TREE_REV} = $build_rev;
      }
    }
    if (defined($rev_author)) {
      $build_vars->{fields}{rev_author} = $rev_author;
    }
    if (defined($config->{build_tag}) && length($config->{build_tag}) > 0) {
      $build_vars->{fields}{build_tag} = $config->{build_tag};
    }
    if (defined($config->{compile_only}) && $config->{compile_only} eq '1') {
      $build_vars->{fields}{compile_only} = '1';
    }
    $client->print_log("Will build.\n");
  } else {
    $client->print_log("Will not build.\n");
  }
  return $err;
}

# figures out if the cvs tree we're standing in needs an update
sub need_cvs_update {
  my ($client, $config, $persistent_vars) = @_;

  # calc now (UCT)
  my ($sec, $min, $hour, $day, $month, $year, $dow, $doy, $dst) = gmtime();
  my $now = sprintf('%04d-%02d-%02dZ%02d:%02d', $year + 1900, $month + 1, $day, $hour, $min);

  # when forcing checkouts return straight away.
  if ($config->{checkout} || $config->{branch}) {
    $persistent_vars->{getcwd()} = $now;
    return 1;
  }

  # check the cvs history since the last update.
  my $opts = '-c -l -a';
  if ($config->{branch}) {
    $opts .= " -r $config->{branch}";
  }
  if ($persistent_vars->{getcwd()}) {
    $opts .= ' -D "'.$persistent_vars->{getcwd()}.'"';
  }
  my $sed_expr = 's/[A-Z] \(....-..-.. ..:.. .....\).*$/\1/';
  my $last_date = `cvs history $opts 2>&1| sed -e '$sed_expr' | sort | tail -n 1`;
  chop($last_date);
  $client->print_log("need_cvs_update - '".getcwd()."' - '$opts' - '$sed_expr': $last_date\n");
  if ($last_date =~ m/^....-..-.. ..:.. .....$/) {
    $persistent_vars->{getcwd()} = $now;
    return 1;
  }
  return 0;
}


package TinderClient::Modules::build;

use strict;
use Cwd qw(getcwd);

sub get_config {
  my ($client, $config, $persistent_vars, $build_vars, $content_ref) = @_;
  $client->get_field($content_ref, 'tree_type');
  $client->get_field($content_ref, 'build_tag');
  $client->get_field($content_ref, 'upload_dir');
  $client->get_field($content_ref, 'uploaded_url');
  $client->get_field($content_ref, 'build_additions');
  $client->get_field($content_ref, 'build_docs');
  $client->get_field($content_ref, 'build_efi');
  $client->get_field($content_ref, 'build_extpacks');
  $client->get_field($content_ref, 'build_ose');
  $client->get_field($content_ref, 'build_sdk');
  $client->get_field($content_ref, 'build_testsuite');
  $client->get_field($content_ref, 'build_vboximg');
  $client->get_field($content_ref, 'build_vbb');
  $client->get_field($content_ref, 'build_debrpm');
  $client->get_field($content_ref, 'build_osetarball');
  $client->get_field($content_ref, 'build_linux_kmods');
  $client->get_field($content_ref, 'build_qt');
  $client->get_field($content_ref, 'build_parfait');
  $client->get_field($content_ref, 'parfait_server');

  $client->get_field($content_ref, 'ENV_OPT');
  $config->{ENV_OPT} ||= '';
  $client->get_field($content_ref, 'VBOX_ADDITIONS_SH_BRANCH');
  $client->get_field($content_ref, 'VBOX_DOCUMENTATION_SH_BRANCH');
  $client->get_field($content_ref, 'VBOX_EFI_SH_BRANCH');
  $client->get_field($content_ref, 'VBOX_EXTPACKS_SH_BRANCH');
  if ($config->{build_ose})
  {
    $client->get_field($content_ref, 'CONFIGURE_OPTIONS');
  }
  $client->get_field($content_ref, 'post_script');
  $client->get_field($content_ref, 'jail_post');
  $client->get_field($content_ref, 'VBOX_WITH_COMBINED_PACKAGE');
  $client->get_field($content_ref, 'VBOX_WITH_COMBINED_WIN_ADDITIONS');
  $client->get_field($content_ref, 'jail_script');
  $client->get_field($content_ref, 'jail');
  if (!$config->{build_vbb} && !$config->{build_qt})
  {
    $client->get_kbuild_fields($content_ref);
  }
}

sub finish_build {
  my ($client, $config, $persistent_vars, $build_vars) = @_;

}

sub do_action {
  my ($client, $config, $persistent_vars, $build_vars) = @_;
  my $build_tree_status = 10;

  #
  # Build
  #
  my $err = 0;
  if ($build_vars->{SHOULD_BUILD}) {
    $build_vars->{START_TIME_BUILD} = $build_vars->{START_TIME};
    my $grep = $config->{lowbandwidth}
    ? sub {
          if ($_[0] =~ s/^g?kmk.+Entering directory ['`"](.+)['`"]$/$1/mg) {
            return $_[0];
          }
          if ($_[0] =~ /^\S+$/) {
            return $_[0];
          }
          return '';
        }
    :   undef;
    my $build_vboxrev = '';
    if (   !$config->{build_vbb} && !$config->{build_qt}
        && defined $build_vars->{fields}{build_rev}
        && $build_vars->{fields}{build_rev} ne ''
        && $config->{jail_script} && $config->{jail})
    {
        $build_vboxrev = ' VBOX_SVN_REV='.$build_vars->{fields}{build_rev};
    }
    my $kmk;
    if (!$config->{build_vbb} && !$config->{build_qt})
    {
        if ($config->{build_ose}) {
            if ($client->sysinfo()->{OS} =~ /^WIN/) {
                $kmk = $build_vars->{envsetup}.'cmd.exe /c " call env.bat &&'.
                       ' kmk'.
                       ' KBUILD_TARGET='.$config->{KBUILD_TARGET}.
                       ' KBUILD_TYPE='.$config->{KBUILD_TYPE}.
                       ' KBUILD_HOST='.$config->{KBUILD_HOST}.
                       ($client->{ARGS}{out_dir} ? ' PATH_OUT_BASE='.$client->{ARGS}{out_dir} : '').
                       $build_vboxrev.
                       $client->sysinfo()->{FETCHDIR_DEFINES}.
                       ' '.$config->{KMK_DEFINES}.
                       ' "';
            } else {
                my $escape = ( $config->{jail_script} && $config->{jail} ) ? "\\" : '';
                $kmk = ". ./env.sh $escape; ".$build_vars->{envsetup}.'kmk'.
                       ' KBUILD_TARGET='.$config->{KBUILD_TARGET}.
                       ' KBUILD_TYPE='.$config->{KBUILD_TYPE}.
                       ' KBUILD_HOST='.$config->{KBUILD_HOST}.
                       ($client->{ARGS}{out_dir} ? ' PATH_OUT_BASE='.$client->{ARGS}{out_dir} : '').
                       $build_vboxrev.
                       $client->sysinfo()->{FETCHDIR_DEFINES}.
                       ' '.$config->{KMK_DEFINES};
            }
        } else {
          $kmk = $build_vars->{envsetup}.$build_vars->{shellprefix}.
                 'tools/env.sh '.$config->{ENV_OPT}.
                 ' kmk'.
                 ' KBUILD_TARGET='.$config->{KBUILD_TARGET}.
                 ' KBUILD_TYPE='.$config->{KBUILD_TYPE}.
                 ' KBUILD_HOST='.$config->{KBUILD_HOST}.
                 ($client->{ARGS}{out_dir} ? ' PATH_OUT_BASE='.$client->{ARGS}{out_dir} : '').
                 $build_vboxrev.
                 $client->sysinfo()->{FETCHDIR_DEFINES}.
                 ' '.$config->{KMK_DEFINES};
        }
    }

    # Abuse VBOX_BUILD_PUBLISHER for tagging patch builds.
    if ($config->{tree_type} eq 'build_new_patch') {
      my $publisher_tag = uc($config->{build_tag});
      $publisher_tag =~ s/_/-/g;
      $kmk .= ' VBOX_BUILD_PUBLISHER=_' . $publisher_tag .' VBOX_BUILD_TAG=' . $config->{build_tag};
    }

    # the build steps
    if ($config->{build_additions}) {
      # Only build the additions.
      if (!$err) {
        $err = $client->do_command_jail($kmk.' additions-build', $build_tree_status, $grep);
      }
      if (!$err && $config->{packing}) {
        $err = $client->do_command_jail($kmk.' -j1 additions-packing', $build_tree_status+1, $grep);
      }

    } elsif ($config->{build_efi}) {
      # Only build the EFI firmware.
      if (!$err) {
        $err = $client->do_command_jail($kmk.' efi-build', $build_tree_status, $grep);
      }
      if (!$err && $config->{packing}) {
        $err = $client->do_command_jail($kmk.' -j1 efi-packing', $build_tree_status+1, $grep);
      }

    } elsif ($config->{build_extpacks}) {
      # Only build the extension packs.
      if (!$err) {
        $err = $client->do_command_jail($kmk.' extpacks-build', $build_tree_status, $grep);
      }
      if (!$err && $config->{packing}) {
        $err = $client->do_command_jail($kmk.' -j1 extpacks-packing', $build_tree_status+1, $grep);
      }

    } elsif ($config->{build_ose}) {
      # Build VirtualBox OSE
      if (!$err) {
        if ($client->sysinfo()->{OS} =~ /^WIN/) {
          $err = $client->do_command_jail($build_vars->{envsetup}.'cscript configure.vbs '.$config->{CONFIGURE_OPTIONS}, $build_tree_status);
          $client->file_to_log('env.bat');
        } else {
          $err = $client->do_command_jail($build_vars->{envsetup}.'./configure '.$config->{CONFIGURE_OPTIONS}, $build_tree_status);
          $client->file_to_log('env.sh');
        }
        $client->file_to_log('AutoConfig.kmk');
      }
      if (!$err) {
        $err = $client->do_command_jail($kmk.' all', $build_tree_status+1, $grep);
      }
      if (!$err && $client->sysinfo()->{OS} =~ /^WIN/ && $config->{KBUILD_TARGET_ARCH} eq 'amd64') {
        # to build the 64-bit additions we also need to build the 32-bit additions
        $err = $client->do_command_jail($kmk.' KBUILD_TARGET_ARCH=x86 VBOX_ONLY_ADDITIONS=1 all', $build_tree_status+1, $grep);
      }
      if (!$err && $config->{packing}) {
        $err = $client->do_command_jail($kmk.' packing', $build_tree_status+2, $grep);
      }

    } elsif ($config->{build_sdk}) {
      # Only build the SDK.
      if (!$err) {
        $err = $client->do_command_jail($kmk.' -f Maintenance.kmk sdk-build', $build_tree_status, $grep);
      }
      if (!$err && $config->{packing}) {
        $err = $client->do_command_jail($kmk.' -f Maintenance.kmk sdk-packing', $build_tree_status+1, $grep);
      }

    } elsif ($config->{build_testsuite}) {
      # Only build the test suite.
      if (!$err) {
        $err = $client->do_command_jail($kmk.' validationkit-build', $build_tree_status, $grep);
      }
      if (!$err && $config->{packing}) {
        $err = $client->do_command_jail($kmk.' -j1 validationkit-packing', $build_tree_status+1, $grep);
      }

    } elsif ($config->{build_osetarball}) {
      # Only build the OSE tarball.
      if (!$err) {
        $err = $client->do_command_jail($kmk.' snapshot-ose', $build_tree_status, $grep);
      }

    } elsif ($config->{build_vboximg}) {
      # Only build the vbox-img binary.
      if (!$err) {
        $err = $client->do_command_jail($kmk.' vbox-img', $build_tree_status, $grep);
      }

    } elsif ($config->{build_vbb}) {
      # Build VirtualBox/Blue
      if (!$err) {
        $err = $client->do_command('cd src; autoreconf --install --force; ./configure', $build_tree_status);
      }
      if (!$err) {
        $err = $client->do_command('make -C src CFLAGS="-O0 -g" CXXFLAGS="-O0 -g"', $build_tree_status+1, $grep);
      }
      if (!$err && $config->{packing}) {
        $err = $client->do_command('make -C src packing', $build_tree_status+2, $grep);
      }

    } elsif ($config->{build_linux_kmods}) {
      # Only test build the linux kernel modules.
      if (!$err) {
        my $count_successes = 0;
        my $count_failures = 0;
        my $kmod_grep = sub {
          while ($_[0] =~ /<--- Successfully built against /g) {
            $count_successes += 1;
          }
          while ($_[0] =~ /<--- Failed \(exit code /g) {
            $count_failures += 1;
          }
          return $grep ? &$grep($_[0]) : $_[0];
        };
        $err = $client->do_command($config->{build_linux_kmods}.' --build-tree "'.getcwd().'" --keep'
                                   .' --temp-folder-name "tempdir-'.$client->{MACHINE_NAME}.'"',
                                   $build_tree_status, $kmod_grep);
        $build_vars->{fields}{kmods_okay} = $count_successes;
        $build_vars->{fields}{kmods_fail} = $count_failures;
      }

    } elsif ($config->{build_qt}) {
      # Build Qt (VirtualBox tool flavor)
      if (!$err) {
        my $cmd = '';
        if ($client->sysinfo()->{OS} =~ /^WIN/)
        {
          $cmd = 'vbox-do-it-all.cmd verbose';
        }
        else
        {
          $cmd = './vbox-do-it-all-'.::get_kbuild_host_os().'.sh --verbose';
        }
        foreach my $var ('KBUILD_DEVTOOLS', 'PATH')
        {
          if ($config->{$var} ne '')
          {
            if ($^O eq 'MSWin32')
            {
              $cmd = 'set '.$var.'='.$config->{$var}.'& ' . $cmd;
            }
            else
            {
              $cmd = $var.'='.$config->{$var}.' ' . $cmd;
            }
          }
        }
        $err = $client->do_command($cmd, $build_tree_status);
      }

    } elsif ($config->{build_debrpm}) {
      # Build deb/rpm package
      # Fetch the additions/docs/efi outside the build jail
      # Also write the SVN revision to a file
      if (! -d 'prebuild') {
        mkdir('prebuild');
      }
      my $cmd;
      my $out;
      if (!$err) {
        my $fh;
        if (open($fh, '>', 'SVN_REVISION')) {
          print $fh 'svn_revision := ' . $build_vars->{TREE_REV} . "\n";
          close $fh;
        } else {
          $err = 200;
        }
      }
      if (!$err) {
        $cmd = $build_vars->{shellprefix}.
               'tools/env.sh --quiet --no-wine tools/bin/additions.sh '.
               '--cmd fetch --filename prebuild/VBoxGuestAdditions.zip';
        $err = $client->do_command($cmd, $build_tree_status, $grep);
      }
      if (!$err) {
        $cmd = 'cd prebuild; unzip -o VBoxGuestAdditions.zip';
        $err = $client->do_command($cmd, $build_tree_status, $grep);
      }
      if (!$err) {
        $cmd = $build_vars->{shellprefix}.
               'tools/env.sh --quiet --no-wine tools/bin/documentation.sh '.
               '--cmd fetch --filename prebuild/VBoxDocumentation.zip';
        $err = $client->do_command($cmd, $build_tree_status, $grep);
      }
      if (!$err) {
        $cmd = 'cd prebuild; unzip -o VBoxDocumentation.zip';
        $err = $client->do_command($cmd, $build_tree_status, $grep);
      }
      if (!$err) {
        $cmd = $build_vars->{shellprefix}.
               'tools/env.sh --quiet --no-wine tools/bin/efi_firmware.sh '.
               '--cmd fetch --filename prebuild/VBoxEfiFirmware.zip';
        $err = $client->do_command($cmd, $build_tree_status, $grep);
      }
      if (!$err) {
        $cmd = 'cd prebuild; unzip -o VBoxEfiFirmware.zip; [ -f FV/VBOX.fd ] && mv -v FV/VBOX.fd VBoxEFI32.fd; '.
               '[ -f FV/VBOX64.fd ] && mv -v FV/VBOX64.fd VBoxEFI64.fd; [ -d FV ] && rm -rfv FV; true';
        $err = $client->do_command($cmd, $build_tree_status, $grep);
      }
      if (!$err) {
        my $args = 'NODOCS=1 STAGEDISO=$PWD/prebuild PKGDIR='. ($client->{ARGS}{out_dir} ? $client->{ARGS}{out_dir} : '$PWD/out');
        if ($config->{KBUILD_TYPE} eq 'debug') {
            $args .= ' DEBUG=1';
        }
        $err = $client->do_command_jail('"cd src/VBox/Installer/linux; '.
                                        ($client->{ARGS}{out_dir} ? 'export PATH_OUT_BASE='.$client->{ARGS}{out_dir}.'; ' : '').
                                        'if which dpkg > /dev/null 2>&1; then '.
                                        '  fakeroot debian/rules clean; '.
                                        '  fakeroot debian/rules binary ' . $args . '; '.
                                        'else '.
                                        '  rpm/rules clean; '.
                                        '  rpm/rules binary ' . $args . '; '.
                                        'fi"', $build_tree_status+2, $grep);
      }

    } elsif ($config->{VBOX_WITH_COMBINED_WIN_ADDITIONS}) {
      # special case for win64dep
      # We have to build the x86 Additions as well
      if (!$err) {
        $err = $client->do_command_jail($kmk.' additions-build-win.x86', $build_tree_status, $grep);
      }
      if (!$err) {
        $err = $client->do_command_jail($kmk.' all', $build_tree_status, $grep);
      }
      if (!$err && $config->{docs}) {
        $err = $client->do_command_jail($kmk.' docs', $build_tree_status+1, $grep);
      }
      if (!$err && $config->{packing}) {
        $err = $client->do_command_jail($kmk.' packing', $build_tree_status+2, $grep);
      }

    } elsif ($config->{VBOX_WITH_COMBINED_PACKAGE} && $config->{VBOX_WITH_COMBINED_PACKAGE} eq '2') {
      # New variant of the below, which let the root Makefile define how to do things optimally.
      if (!$err) {
        $err = $client->do_command_jail($kmk.' -f Maintenance.kmk combined-package-build', $build_tree_status, $grep);
      }
      if (!$err && $config->{packing}) {
        $err = $client->do_command_jail($kmk.' -f Maintenance.kmk combined-package-packing', $build_tree_status+1, $grep);
      }

    } elsif ($config->{VBOX_WITH_COMBINED_PACKAGE}) {
      # Build amd64 first without packaging, then x86 and do the combined packaging.
      # It's assumed that KBUILD_TARGET_ARCH etc. is x86 in this case.
      if (!$err) {
        my $additions_settings = '';
        if ($client->sysinfo()->{OS} !~ /^WIN/) {
          $additions_settings=' VBOX_WITHOUT_ADDITIONS=1 VBOX_WITH_ADDITIONS_FROM_BUILD_SERVER=';
        }
        $err = $client->do_command_jail($kmk.' KBUILD_TARGET_ARCH=amd64 KBUILD_HOST_ARCH=amd64 '.$additions_settings.' all', $build_tree_status, $grep);
      }
      if (!$err && $client->sysinfo()->{OS} =~ /^WIN/ && $config->{docs}) {
        $err = $client->do_command_jail($kmk.' KBUILD_TARGET_ARCH=amd64 KBUILD_HOST_ARCH=amd64 docs', $build_tree_status+1, $grep);
      }
      if (!$err && $client->sysinfo()->{OS} =~ /^WIN/ && $config->{packing}) {
        $err = $client->do_command_jail($kmk.' KBUILD_TARGET_ARCH=amd64 KBUILD_HOST_ARCH=amd64 packing VBOX_WITH_COMBINED_PACKAGE=1', $build_tree_status+2, $grep);
      }
      if (!$err) {
        $err = $client->do_command_jail($kmk.' all', $build_tree_status, $grep);
      }
      if (!$err && $config->{docs}) {
        $err = $client->do_command_jail($kmk.' docs', $build_tree_status+1, $grep);
      }
      if (!$err && $config->{packing}) {
        $err = $client->do_command_jail($kmk.' VBOX_WITH_COMBINED_SOLARIS_PACKAGE=1 VBOX_WITH_COMBINED_PACKAGE=1 packing', $build_tree_status+2, $grep);
      }

    } elsif ($config->{build_parfait}) {
      # Build using the parfait static code analysis
      if (!$err) {
        $err = $client->do_command_jail($kmk.' VBOX_WITH_PARFAIT=1 VBOX_PARFAIT_SERVER='.$config->{parfait_server}.' run-parfait', $build_tree_status, $grep);
      }

    } else {
      # Normal build.
      if (!$err) {
        $err = $client->do_command_jail($kmk.' all', $build_tree_status, $grep);
      }
      if (!$err && $config->{docs}) {
        $err = $client->do_command_jail($kmk.' docs', $build_tree_status+1, $grep);
      }
      if (!$err && $config->{packing}) {
        $err = $client->do_command_jail($kmk.' packing', $build_tree_status+2, $grep);
      }
    }

    # do post cmd.
    if ($err < 100 && $config->{post_script}) {
      if ( -f $config->{post_script} ) {
        if ($config->{jail_post}) {
          $err = $client->do_command_jail($build_vars->{envsetup} . $config->{post_script},
                                          $build_tree_status+5);
        } else {
          $err = $client->do_command($build_vars->{envsetup} . $config->{post_script},
                                     $build_tree_status+5);
        }
      } else {
        $client->print_log("Couldn't find ".$config->{post_script}."\n");
        $err = 200;
      }
    }
  } else {
    $client->print_log("Skipping build because no changes were made\n");
  }

  #
  # OSE: Process the mirror command if the build was successful (or skipped).
  #
  if ($err == 0 && $config->{build_ose} && $client->sysinfo()->{OS} eq 'Linux')
  {
    if ($client->eat_command('mirror') || $build_vars->{SHOULD_EMERGE})
    {
      $err = $client->do_command_jail('../svnsync-vbox/update-virtualbox.org', $build_tree_status+6);
      return $err;
    }
  }

  if (!$build_vars->{SHOULD_BUILD}) {
    $err = 304;
  }
  return $err;
}

package TinderClient::Modules::distribute;

use strict;
use Date::Format;


sub get_config {
  my ($client, $config, $persistent_vars, $build_vars, $content_ref) = @_;
  $client->get_field($content_ref, 'tree_type');
  $client->get_field($content_ref, 'build_tag');
  $client->get_field($content_ref, 'upload_dir');
  $client->get_field($content_ref, 'uploaded_url');
  $client->get_field($content_ref, 'distribute');
  foreach my $distribution (split(/,/, $config->{distribute})) {
    $client->call_module($distribution, 'get_config', $content_ref);
  }
}

sub finish_build {
  my ($client, $config, $persistent_vars, $build_vars) = @_;
  foreach my $distribution (split(/,/, $config->{distribute})) {
    $client->call_module($distribution, 'finish_build');
  }
}

sub do_action {
  my ($client, $config, $persistent_vars, $build_vars) = @_;

  #
  # Build and upload distribution
  #
  my $err = 0;
  $build_vars->{PACKAGES} = {};
  # Do not build distributions unless we built
  if ($build_vars->{SHOULD_BUILD}) {
    #
    # Build distributions
    #
    if (!$err) {
      foreach my $distribution (split(/,/, $config->{distribute})) {
        $err = $client->call_module($distribution, 'do_action');
        last if $err;
      }
    }

    #
    # Upload installer or distribution
    #
    if (!$err) {
      # Get build id
      my $build_id = '';
      if (!$build_id) {
        $build_id = time2str("%Y-%m-%d-%H-%M-%S-$client->{MACHINE_NAME}", time);
        if ($config->{tree_type} eq 'build_new_patch') {
          $build_id .= '-' . $config->{build_tag};
        }
      }

      # Upload
      foreach my $field_name (keys %{$build_vars->{PACKAGES}}) {
        my $local_file = $build_vars->{PACKAGES}{$field_name}{local_file};
        my $upload_file;
        if (defined $build_vars->{PACKAGES}{$field_name}{upload_file}) {
          $upload_file = $build_vars->{PACKAGES}{$field_name}{upload_file};
        } else {
          $local_file =~ /([^\/]*)$/;
          $upload_file = $1;
          # 20071122: use [\-.] instead of previously \. to avoid putting the
          # timestamp in the middle of the version number.
          $upload_file =~ s/([\-.].*)$/-$build_id$1/;
        }
        $err = upload_build($client, $config, $build_vars, $field_name, $local_file, $upload_file);
        last if $err;
      }
    }
  } else {
    $client->print_log("Skipping distribution because no build was done\n");
  }

  return $err;
}

sub upload_build {
  my ($client, $config, $build_vars, $field_name, $local_name, $upload_name) = @_;
  my $err = 0;
  my $upload_timeout = 2*60; # 2 minutes
  if ($config->{upload_dir}) {
    $config->{upload_dir} .= '/' if $config->{upload_dir} && $config->{upload_dir} !~ /\/$/;
    # Use rsync to guarantee that uploads are atomic.
    my $rsync = "rsync --no-owner --chmod=Fu=rw,Fgo=r $local_name $config->{upload_dir}$upload_name";
    my $ssh = $client->sysinfo()->{SSH};
    # We used to use blowfish-cbc (disabled in 6.7p1-1) and aes128-cbc (also disabled
    # on tindertux).  So, according to https://possiblelossofprecision.net/?p=2255
    # we should try aes128-ctr and hope for hardware support (very likely by now).
    my @sshcmd_variants = ($ssh.' -c aes128-ctr', $ssh);
    $err = 1;
    foreach my $sshcmd (@sshcmd_variants) {
      my $envsetup;
      if ($sshcmd ne '') {
        if ($^O eq 'MSWin32') {
          $envsetup = 'set RSYNC_RSH='.$sshcmd.'& ';
        } else {
          $envsetup = 'RSYNC_RSH=\''.$sshcmd.'\' ';
        }
      }
      $err = $client->do_command($envsetup.$rsync, 21, undef, $upload_timeout);
      last if (!$err);
    }
    if (!$err) {
      set_upload_dir($config, $field_name, $build_vars, $upload_name);
    }
  }
  return $err;
}

sub set_upload_dir {
  my ($config, $field_name, $build_vars, $upload_name) = @_;
  if ($config->{uploaded_url}) {
    my $url = $config->{uploaded_url};
    $url =~ s/\%s/$upload_name/g;
    if (!$build_vars->{fields}{$field_name}) {
      $build_vars->{fields}{$field_name} = [];
    }
    push @{$build_vars->{fields}{$field_name}}, $url;
  }
}


package TinderClient::Modules::build_by_suffix;

sub get_config {
  my ($client, $config, $persistent_vars, $build_vars, $content_ref) = @_;

  $client->get_field($content_ref, 'build_additions');
  $client->get_field($content_ref, 'build_docs');
  $client->get_field($content_ref, 'build_efi');
  $client->get_field($content_ref, 'build_extpacks');
  $client->get_field($content_ref, 'build_ose');
  $client->get_field($content_ref, 'build_sdk');
  $client->get_field($content_ref, 'build_testsuite');
  $client->get_field($content_ref, 'build_vboximg');
  $client->get_field($content_ref, 'build_vbb');
  $client->get_field($content_ref, 'build_debrpm');
  $client->get_field($content_ref, 'build_osetarball');
  $client->get_field($content_ref, 'build_linux_kmods');
  $client->get_field($content_ref, 'build_qt');
  $client->get_field($content_ref, 'build_parfait');
  $client->get_field($content_ref, 'VBOX_WITH_COMBINED_PACKAGE');
  $client->get_kbuild_fields($content_ref);

  #
  # For regular builds that get uploaded and registered with the test manager,
  # we must make sure the tinderbox has the necessary server side configuration
  # or the builds will be miscategorized and mess up testing.  We check here
  # and complain during the do_action step.
  #
  # The target, arch and type are required here, with defaults matching
  # add_build() in TestManagerInterface.pm.
  #
  my $sTmp = $client->parse_simple_tag($content_ref, 'KBUILD_TARGET', 'BUILD_TARGET');
  $config->{KBUILD_TARGET_OKAY}      = ($sTmp ne '' || $config->{KBUILD_TARGET} eq 'linux');
  $sTmp    = $client->parse_simple_tag($content_ref, 'KBUILD_TARGET_ARCH', 'BUILD_TARGET_ARCH');
  $config->{KBUILD_TARGET_ARCH_OKAY} = ($sTmp ne '' || $config->{KBUILD_TYPE}   eq 'amd64');
  $sTmp    = $client->parse_simple_tag($content_ref, 'KBUILD_TYPE', 'BUILD_TYPE');
  $config->{KBUILD_TYPE_OKAY}        = ($sTmp ne '' || $config->{KBUILD_TYPE}   eq 'release');
  if (   $config->{build_additions}
      || $config->{build_docs}
      || $config->{build_efi}
      || $config->{build_extpacks}
      || $config->{build_ose}
      || $config->{build_sdk}
      || $config->{build_testsuite}
      || $config->{build_vboximg}
      || $config->{build_vbb}
      || $config->{build_debrpm}
      || $config->{build_osetarball}
      || $config->{build_linux_kmods} ne ''
      || $config->{build_qt}
      || $config->{build_parfait}) {
    $config->{KBUILD_TARGET_OKAY}      = 1;
    $config->{KBUILD_TARGET_ARCH_OKAY} = 1;
    $config->{KBUILD_TYPE_OKAY}        = 1;
  }
}

sub finish_build {
  my ($client, $config, $persistent_vars, $build_vars) = @_;
}

sub do_action {
  my ($client, $config, $persistent_vars, $build_vars) = @_;

  my $out = $client->{ARGS}{out_dir} ? $client->{ARGS}{out_dir}.'/' : 'out/';
  # Find packaged build(s)
  # Linux
  my @local_files = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/VirtualBox*.run");
  if (!@local_files) {
    @local_files = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/bin/VirtualBox*.run");
  }
  if (!@local_files) {
    @local_files = glob("${out}virtualbox*.deb");
  }
  if (!@local_files) {
    @local_files = glob("${out}VirtualBox*.rpm");
  }
  # Windows
  if (!@local_files) {
    @local_files = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/bin/*-MultiArch.exe");
  }
  if (!@local_files && $config->{VBOX_WITH_COMBINED_PACKAGE}) {
    @local_files = glob("${out}$config->{KBUILD_TARGET}.x86/$config->{KBUILD_TYPE}/bin/*-MultiArch.exe");
  }
  if (!@local_files) {
    @local_files = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/VirtualBox*.msi");
  }
  if (!@local_files && $config->{VBOX_WITH_COMBINED_PACKAGE}) {
    @local_files = glob("${out}$config->{KBUILD_TARGET}.x86/$config->{KBUILD_TYPE}/VirtualBox*.msi");
  }
  if (!@local_files) {
    @local_files = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/bin/VirtualBox*.msi");
  }
  if (!@local_files && $config->{VBOX_WITH_COMBINED_PACKAGE}) {
    @local_files = glob("${out}$config->{KBUILD_TARGET}.amd64/$config->{KBUILD_TYPE}/bin/VirtualBox*.msi");
    if (!@local_files) {
      @local_files = glob("${out}$config->{KBUILD_TARGET}.x86/$config->{KBUILD_TYPE}/bin/VirtualBox*.msi");
    }
  }
  # Mac OS X
  if (!@local_files) {
    @local_files = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/dist/VirtualBox*.dmg");
  }
  # Solaris
  if (!@local_files) {
    @local_files = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/bin/VirtualBox*.{gz,p5p}");
  }

  # VirtualBox SDK
  if (!@local_files) {
    @local_files = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/bin/VirtualBoxSDK*.zip");
  }

  # VirtualBox OSE tarball
  if (!@local_files) {
    @local_files = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/VirtualBox*.tar.bz2");
  }

  # Windows PV stuff
  if (!@local_files) {
    @local_files = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/bin/Sun*.msi");
  }

  # VirtualBox/Blue
  if (!@local_files) {
    @local_files = glob('src/v??2-on-*.tar.gz');
  }

  # Wrap up whatever we got.
  my %suffixes;
  foreach (@local_files)
  {
    my $suffix = $_;
    $suffix =~ s/^.*\.([^.]*)$/$1/;
    $suffixes{$suffix}++;
    if ($config->{build_debrpm}) {
      my $hash;
      if (/-debug/ || /-dbg/) {
        $hash = 'debug_' . $suffix;
      } else {
        $hash = 'build_' . $suffix;
      }
      $build_vars->{PACKAGES}{$hash}{local_file} = $_;
      /([^\/]*)$/;
      $build_vars->{PACKAGES}{$hash}{upload_file} = $1;
    } else {
      my $hash = 'build_' . $suffix;
      if ($suffixes{$suffix} > 1)
      {
        $hash .= $suffixes{$suffix};
      }
      $build_vars->{PACKAGES}{$hash}{local_file} = $_;
    }
  }

  # Fail if the tinderbox isn't correctly configured (checked in get_config).
  if (   !$config->{KBUILD_TARGET_OKAY}
      || !$config->{KBUILD_TARGET_ARCH_OKAY}
      || !$config->{KBUILD_TYPE_OKAY}) {
      $client->print_log("\n");
      $client->print_log("!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
      $client->print_log("!! Tinderbox config error !!\n");
      $client->print_log("!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
      $client->print_log("Build synchronization with the test manager requires the tinderbox to have these variable set:\n");
      $client->print_log("    KBUILD_TARGET, KBUILD_TARGET_ARCH and KBUILD_TYPE\n");
      $client->print_log("Missing:\n");
      if (!$config->{KBUILD_TARGET_OKAY})       { $client->print_log("    KBUILD_TARGET\n"); }
      if (!$config->{KBUILD_TARGET_ARCH_OKAY})  { $client->print_log("    KBUILD_TARGET_ARCH\n"); }
      if (!$config->{KBUILD_TYPE_OKAY})         { $client->print_log("    KBUILD_TYPE\n"); }
      $client->print_log("\n");
      return 200;
  }
  return 0;
}

package TinderClient::Modules::raw_zip;

sub get_config {
  my ($client, $config, $persistent_vars, $build_vars, $content_ref) = @_;
  $client->get_field($content_ref, 'raw_zip_name');
  $client->get_field($content_ref, 'VBOX_WITH_COMBINED_PACKAGE');
  $client->get_kbuild_fields($content_ref);
}

sub finish_build {
  my ($client, $config, $persistent_vars, $build_vars) = @_;
}

sub do_action {
  my ($client, $config, $persistent_vars, $build_vars) = @_;

  my $bldtarget = $config->{KBUILD_TARGET};
  my $bldtype = $config->{KBUILD_TYPE};
  my $sysinfo = $client->sysinfo();
  my $tar = 'tar';
  my $targz = '-z';
  if ( -x '/usr/bin/pigz' ) {
    $targz = '--use-compress-program pigz';
  }
  $tar = 'gtar' if ($sysinfo->{OS} eq 'SunOS');
  my $out = $client->{ARGS}{out_dir} ? $client->{ARGS}{out_dir}.'/' : 'out/';
  my $local_file = "$config->{raw_zip_name}.tar.gz";
  if ($build_vars->{TREE_REV}) {
    $local_file = "$config->{raw_zip_name}-r$build_vars->{TREE_REV}.tar.gz"
  }
  if ($config->{build_additions} || $config->{build_extpacks}) {
    # Additions/ExtPacks: tar all hosts
    if (chdir($out)) {
      # Hack! To make it easier to find and use the pdb on windows, revers sort them so stage/ comes before obj/.
      $client->do_command('find . -name \*.pdb ! -name \*-obj.pdb | sort -r > pdbfiles.txt', 20);
      my $subdirs = '';
      my $uninstallers = '';
      foreach my $target ('darwin', 'linux', 'solaris', 'win') {
        foreach my $arch ('amd64', 'x86', 'arm64') {
          foreach my $subdir ('bin', 'dist', 'stage', 'repack', 'repackadd') {
            my $dir = "$target.$arch/$bldtype/$subdir";
            if ( -e $dir ) {
              $subdirs .= " $dir";
            }
          }
          my $uninst = "$target.$arch/$bldtype/obj/uninst.exe";
          if ( -e $uninst ) {
            $uninstallers .= " $uninst";
          }
        }
      }
      $client->do_command("$tar $targz -cvf $local_file -T pdbfiles.txt $subdirs $uninstallers", 20);
      chdir('..');
    }
  } elsif ($config->{build_vboximg}) {
    # vbox-img: Just tar the bin directory (no staging area)
    if (chdir("${out}$config->{OUT_SUB_DIR}/$bldtype/")) {
      $client->do_command("$tar $targz -cvf ../../$local_file bin/*", 20);
      chdir('../../..');
    }
  } elsif ($config->{VBOX_WITH_COMBINED_PACKAGE}) {
    # New combined package layout that's similar to the above additions/extpacks.
    if (chdir($out)) {
      my $subdirs = '';
      my $excludes = '';
      foreach my $arch ('amd64', 'arm64', 'x86') {
        foreach my $subdir ('stage', 'bin', 'dist', 'repack') {
          my $dir = "$bldtarget.$arch/$bldtype/$subdir";
          if ( -e $dir ) {
            $subdirs .= " $dir";
          }
        }
        $excludes .= " '--exclude=$bldtarget.$arch/$bldtype/stage/debug/bin/bld*.pdb' ";
        $excludes .= " '--exclude=$bldtarget.$arch/$bldtype/stage/debug/bin/tst*.pdb' ";
        if ( -e "$bldtarget.$arch/$bldtype/stage/debug/hardended-execs" ) {
          $excludes .= " '--exclude=$bldtarget.$arch/$bldtype/stage/debug/hardended-execs/tst*.pdb' ";
        }
        foreach my $unwanted ('stage/debug/validationkit',      'stage/debug/testboxscript',
                              'stage/debug/bin/ExtensionPacks', 'stage/debug/bin/testcase',
                              'stage/debug/bin/webtest.pdb',    'bin/ExtensionPacks') {
          my $dir = "$bldtarget.$arch/$bldtype/$unwanted";
          if ( -e $dir ) {
            $excludes .= " --exclude=$dir";
          }
        }
      }
      $client->do_command("$tar $targz $excludes -cvf $local_file $subdirs", 20);
      chdir('..');
    }
  } else {
    $client->print_log("Creating raw_zip in ${out}$config->{OUT_SUB_DIR}/$bldtype/\n");
    if (chdir("${out}$config->{OUT_SUB_DIR}/$bldtype/")) {
      my $subdirs = '';
      my $excludes = '';
      foreach my $subdir ('stage', 'bin', 'dist', 'repack') {
        if ( -e $subdir ) {
          $subdirs .= " $subdir";
        }
      }
      if ($sysinfo->{OS} eq 'WINNT' ) {
        $excludes .= " '--exclude=stage/debug/bin/bld*.pdb' ";
        $excludes .= " '--exclude=stage/debug/bin/tst*.pdb' ";
        if ( -e "stage/debug/hardended-execs" ) {
          $excludes .= " '--exclude=stage/debug/hardended-execs/tst*.pdb' ";
        }
        foreach my $unwanted ('stage/debug/validationkit',      'stage/debug/testboxscript',
                              'stage/debug/bin/ExtensionPacks', 'stage/debug/bin/testcase',
                              'stage/debug/bin/webtest.pdb',    'bin/ExtensionPacks') {
          if ( -e $unwanted ) {
            $excludes .= " --exclude=$unwanted";
          }
        }
      }
      $client->do_command("$tar $targz $excludes -cvf ../../$local_file $subdirs", 20);
      chdir('../../..');
    }
  }
  $build_vars->{PACKAGES}{raw_zip}{local_file} = "${out}$local_file";
  return 0;
}


package TinderClient::Modules::additions_iso;

sub get_config {
  my ($client, $config, $persistent_vars, $build_vars, $content_ref) = @_;
  $client->get_kbuild_fields($content_ref);
}

sub finish_build {
  my ($client, $config, $persistent_vars, $build_vars) = @_;
}

sub do_action {
  my ($client, $config, $persistent_vars, $build_vars) = @_;

  my $out = $client->{ARGS}{out_dir} ? $client->{ARGS}{out_dir}.'/' : 'out/';
  my ($local_file) = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/bin/additions/VBoxGuestAdditions.zip");
  if ($local_file) {
    $build_vars->{PACKAGES}{additions_iso}{local_file} = $local_file;
    $build_vars->{PACKAGES}{additions_iso}{upload_file} = 'VBoxGuestAdditions-r'.$build_vars->{TREE_REV}.'.zip';
  }
  return 0;
}


package TinderClient::Modules::docs_zip;

sub get_config {
  my ($client, $config, $persistent_vars, $build_vars, $content_ref) = @_;
  $client->get_kbuild_fields($content_ref);
}

sub finish_build {
  my ($client, $config, $persistent_vars, $build_vars) = @_;
}

sub do_action {
  my ($client, $config, $persistent_vars, $build_vars) = @_;

  my $out = $client->{ARGS}{out_dir} ? $client->{ARGS}{out_dir}.'/' : 'out/';
  my ($local_file) = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/bin/VBoxDocumentation.zip");
  if ($local_file) {
    $build_vars->{PACKAGES}{docs_zip}{local_file} = $local_file;
    $build_vars->{PACKAGES}{docs_zip}{upload_file} = 'VBoxDocumentation-r'.$build_vars->{TREE_REV}.'.zip';
  }
  return 0;
}


package TinderClient::Modules::efi_firmware;

sub get_config {
  my ($client, $config, $persistent_vars, $build_vars, $content_ref) = @_;
  $client->get_kbuild_fields($content_ref);
}

sub finish_build {
  my ($client, $config, $persistent_vars, $build_vars) = @_;
}

sub do_action {
  my ($client, $config, $persistent_vars, $build_vars) = @_;

  my $out = $client->{ARGS}{out_dir} ? $client->{ARGS}{out_dir}.'/' : 'out/';
  my ($local_file) = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/VBoxEfiFirmware*.zip");
  if (!$local_file) {
      ($local_file) = glob("${out}VBoxEfiFirmware*.zip");
  }
  if ($local_file) {
    $build_vars->{PACKAGES}{efi_fw}{local_file} = $local_file;
    $build_vars->{PACKAGES}{efi_fw}{upload_file} = 'VBoxEfiFirmware-r'.$build_vars->{TREE_REV}.'.zip';
  }
  return 0;
}


package TinderClient::Modules::efi_firmware_armv8;

sub get_config {
  my ($client, $config, $persistent_vars, $build_vars, $content_ref) = @_;
  $client->get_kbuild_fields($content_ref);
}

sub finish_build {
  my ($client, $config, $persistent_vars, $build_vars) = @_;
}

sub do_action {
  my ($client, $config, $persistent_vars, $build_vars) = @_;

  my $out = $client->{ARGS}{out_dir} ? $client->{ARGS}{out_dir}.'/' : 'out/';
  my ($local_file) = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/VBoxEfiFirmware-armv8.zip");
  if (!$local_file) {
      ($local_file) = glob("${out}VBoxEfiFirmware-armv8.zip");
  }
  if ($local_file) {
    $build_vars->{PACKAGES}{efi_fw_armv8}{local_file} = $local_file;
    $build_vars->{PACKAGES}{efi_fw_armv8}{upload_file} = 'VBoxEfiFirmware-armv8-r'.$build_vars->{TREE_REV}.'.zip';
  }
  return 0;
}


package TinderClient::Modules::extpack_tgz;

sub get_config {
  my ($client, $config, $persistent_vars, $build_vars, $content_ref) = @_;
  $client->get_kbuild_fields($content_ref);
}

sub finish_build {
  my ($client, $config, $persistent_vars, $build_vars) = @_;
}

sub do_action {
  my ($client, $config, $persistent_vars, $build_vars) = @_;

  my $out = $client->{ARGS}{out_dir} ? $client->{ARGS}{out_dir}.'/' : 'out/';
  my $i = 1;
  my @local_files = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/Packages/*.vbox-extpack");
  foreach (@local_files)
  {
    my $hash = 'extpack_tgz';
    $hash .= $i if ($i > 1);
    $build_vars->{PACKAGES}{$hash}{local_file} = $_;
    /([^\/]*)$/;
    $build_vars->{PACKAGES}{$hash}{upload_file} = $1;
    $i++;
  }
  return 0;
}


package TinderClient::Modules::testsuite_zip;

sub get_config {
  my ($client, $config, $persistent_vars, $build_vars, $content_ref) = @_;
  $client->get_kbuild_fields($content_ref);
}

sub finish_build {
  my ($client, $config, $persistent_vars, $build_vars) = @_;
}

sub do_action {
  my ($client, $config, $persistent_vars, $build_vars) = @_;

  my $out = $client->{ARGS}{out_dir} ? $client->{ARGS}{out_dir}.'/' : 'out/';
  my ($local_file) = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/VBoxValidationKit.zip");
  if ($local_file) {
    $build_vars->{PACKAGES}{testsuite_zip}{local_file} = $local_file;
    $build_vars->{PACKAGES}{testsuite_zip}{upload_file} = 'VBoxValidationKit-r'.$build_vars->{TREE_REV}.'.zip';
  }

  my ($local_file2) = glob("${out}$config->{OUT_SUB_DIR}/$config->{KBUILD_TYPE}/VBoxTestBoxScript.zip");
  if ($local_file2) {
    $build_vars->{PACKAGES}{testboxscript_zip}{local_file} = $local_file2;
    $build_vars->{PACKAGES}{testboxscript_zip}{upload_file} = 'VBoxTestBoxScript-r'.$build_vars->{TREE_REV}.'.zip';
  }
  return 0;
}


package TinderClient::Modules::vboxqt_by_suffix;

sub get_config {
  my ($client, $config, $persistent_vars, $build_vars, $content_ref) = @_;
}

sub finish_build {
  my ($client, $config, $persistent_vars, $build_vars) = @_;
}

sub do_action {
  my ($client, $config, $persistent_vars, $build_vars) = @_;

  my @local_files = glob('staged-install/'.::get_kbuild_host_os().'.*.qt.*.tar.bz2');
  if (!@local_files) {
    @local_files = glob('staged-install/'.::get_kbuild_host_os().'.*.qt.*.zip');
  }

  my %suffixes;
  foreach (@local_files)
  {
    my $suffix = $_;
    # Normalize .tar.whatever suffix to .txx, keeping name intact
    $suffix =~ s/^(.*\.t)ar\.([^.]{2})[^.]*$/$1$2/;
    # Determine actual suffix
    $suffix =~ s/^.*\.([^.]*)$/$1/;
    $suffixes{$suffix}++;
    my $hash = 'vboxqt_' . $suffix;
    $hash .= $suffixes{$suffix} if ($suffixes{$suffix} > 1);
    $build_vars->{PACKAGES}{$hash}{local_file} = $_;
    /([^\/]*)$/;
    $build_vars->{PACKAGES}{$hash}{upload_file} = $1;
  }
  return 0;
}


package TinderClient::Modules::tests;

use strict;

sub get_config {
  my ($client, $config, $persistent_vars, $build_vars, $content_ref) = @_;
  $client->get_field($content_ref, 'tests');
  foreach my $module (split(/,/, $config->{tests})) {
    $client->call_module($module, 'get_config', $content_ref);
  }
}

sub finish_build {
  my ($client, $config, $persistent_vars, $build_vars) = @_;
  foreach my $module (split(/,/, $config->{tests})) {
    $client->call_module($module, 'finish_build');
  }
}

sub do_action {
  my ($client, $config, $persistent_vars, $build_vars) = @_;
  foreach my $module (split(/,/, $config->{tests})) {
    my $err = $client->call_module($module, 'do_action');
    if ($err) {
      return $err;
    }
  }
  return 0;
}

1
