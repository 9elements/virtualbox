# $Id: TestManagerInterface.pm 114033 2026-04-27 09:34:52Z knut.osmundsen@oracle.com $
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
# Oracle and/or its affiliates.
# Portions created by the Initial Developer are Copyright (C) 2012
# the Initial Developer. All Rights Reserved.
#
# Contributor(s):
#
# ***** END LICENSE BLOCK *****



package Tinderbox3::TestManagerInterface;

use strict;
my $tm_dir = '/srv/localhost/www/testmanager/testmanager/';
my $tm_add_build = $tm_dir . 'batch/add_build.py';
my $tm_del_build = $tm_dir . 'batch/del_build.py';


## For debugging.
sub dprintf {
    my ($msg) = @_;
    if (open(MYFILE, '>>/tmp/build-tbox-to-tm.log')) {
      print MYFILE "debug: " . $msg . "\n";
      close(MYFILE);
    }
}

##
# Execute a test manager script.
sub run_tm_script {
    my (@args) = @_;

    # Log.pm screws with the PATH, temporarily unscrew it!
    my $saved_path = $ENV{PATH};
    $ENV{PATH} = '/opt/python-to-python3:/bin:/usr/bin';

    # Don't use system(@args); here! Seems perl detects taint (or something) and dies.
    use POSIX;
    my $pid = fork();
    my $pidret;
    my $status;
    if ($pid) {
        $pidret = waitpid($pid, 0);
        $status = $?;
    } else {
        exec(@args);
        die "exec failed";
    }
    #dprintf("run_tm_script: waitpid($pid) -> $pidret / $status  (args=@args)");

    $ENV{PATH} = $saved_path;
}

##
# Checks if the given tree/machine is of any interest to the Test Manager.
sub is_of_interest {
    my ($tree, $machine_name) = @_;

    # Only VBox stuff
    if ($tree !~ m/^VBox/) {
        return 0;
    }

    # No tests.
    if ($tree =~ m/.*[Tt][Ee][Ss][Tt].*/) {
        return 0;
    }

    # No component builds.
    if ($machine_name =~ m/^(add|doc|efi|extpacks|sdk)/) {
        return 0;
    }

    # No dependency builds.
    if ($machine_name =~ m/.*dep.*/) {
        return 0;
    }

    return 1;
}

sub add_build {
    my ($dbh, $tree, $machine_id, $machine_name, $build_time, $log, $build_tag) = @_;
    #dprintf("add_build: build_time=$build_time tree=$tree machine_name=$machine_name");

    #
    # Reject uninteresting trees and machines.
    #
    if (!is_of_interest($tree, $machine_name)) {
        #dprintf("not of interest: $tree $machine_name $build_time");
        return;
    }

    #
    # Skip if the test manager isn't installed.
    #
    if ( !(-f $tm_add_build) || !(-x $tm_add_build) ) {
        #dprintf("tm scripts are missing");
        return;
    }

    #
    # Extract build file and revision from the fields table.
    #
    my $raw_zip = '';
    my $build_file = '';
    my $revision = '';
    my $fields_sth = $dbh->prepare('SELECT name, value FROM tbox_build_field WHERE machine_id = ? AND build_time = ?');
    $fields_sth->execute($machine_id, $build_time);
    while (my $row = $fields_sth->fetchrow_arrayref) {
        if ($row->[0] eq 'raw_zip') {
            $raw_zip = $row->[1];
        } elsif (   $row->[0] eq 'testsuite_zip'
                 || $row->[0] eq 'build_run'
                 || $row->[0] eq 'build_rpm'
                 || $row->[0] eq 'build_msi'
                 || $row->[0] eq 'build_dmg'
                 || $row->[0] eq 'build_gz'
                 || $row->[0] eq 'build_exe'
                 || $row->[0] eq 'build_deb'
            ) {
            $build_file = $row->[1];
        } elsif ($row->[0] eq 'build_rev') {
            $revision = $row->[1];
        }
    }

    #
    # Use raw_zip if found, otherwise fall back on the build file.
    #
    ## @todo figure out how to do .deb and .rpm tests.
    my $is_testsuite = ($machine_name =~ m/^testsuite.*/);
    my $file = $is_testsuite ? $build_file : $raw_zip;
    if ($file ne '' && $build_file ne '' && $revision ne '')
    {
        $file =~ s|^/tinderbox/||;
        $file =~ s|^/builds/||;

        #
        # Extract the version from the build_file.
        #
        my $version = '0.0.0';
        if ($build_file =~ m/[-_](\d+\.\d+\.\d+)[-_r]/) {
            $version = $1;
        }

        # Add the patch ID from the build tag, if present.
        if ($build_tag =~ m/^(\d+)[-_]/) {
            $version .= '-p' . $1;
        }

        #
        # From the machine config, we'll get the type, os and arch.
        #
        my $type        = 'release';
        my $os          = 'linux';
        my $arch        = 'amd64';
        my $combined    = 0;
        my $config_sth  = $dbh->prepare('SELECT name, value FROM tbox_machine_config WHERE machine_id = ?');
        $config_sth->execute($machine_id);
        while (my $row = $config_sth->fetchrow_arrayref) {
            if ($row->[0] eq 'BUILD_TYPE' ||  $row->[0] eq 'KBUILD_TYPE') {
                $type = $row->[1];
            } elsif ($row->[0] eq 'BUILD_TARGET' ||  $row->[0] eq 'KBUILD_TARGET') {
                $os = $row->[1];
            } elsif ($row->[0] eq 'BUILD_TARGET_ARCH' ||  $row->[0] eq 'KBUILD_TARGET_ARCH') {
                $arch = $row->[1];
            } elsif ($row->[0] eq 'VBOX_WITH_COMBINED_PACKAGE') {
                $combined = 1;
            }
        }

        #
        # Invoke the testmanager interface script.
        #
        ## @todo pass build_tag along too.
        my $logurl = '/showlog.pl?machine_id=' . $machine_id . '&logfile=' . $log; # Putting this in the @args definition causes taint error. Weird!!
        my @args = ($tm_add_build,
                    '--quiet',
                    '--file',          $file,
                    '--branch',        $tree eq 'VBox' ? 'trunk' : $tree,
                    '--log',           $logurl,
                    '--type',          $type,
                    '--product',       $is_testsuite ? 'VBox Validation Kit' : 'VirtualBox',
                    '--revision',      $revision,
                    '--version',       $version,
                    '--os-arch');
        if ($machine_name =~ m/^testsuite.*/) {
            push(@args, 'os-agnostic.noarch');
        } elsif ($combined) {
            if ($version =~ m/^(?:[789]\.|[1-9][0-9]\.)/) {
                push(@args, ( $os . '.amd64', '--os-arch', $os . '.arm64' ));
            } else {
                push(@args, ( $os . '.x86', '--os-arch', $os . '.amd64' ));
            }
        } else {
            push(@args, $os . '.' . $arch);
        }
        run_tm_script(@args);
    } else {
        #dprintf("stuff missing: $file / $build_file  / $revision / $tree / $machine_name / $build_time");
    }
}

sub del_build {
    my ($dbh, $tree, $machine_id, $machine_name, $build_time, $given_file) = @_;

    #
    # Reject uninteresting trees and machines.
    #
    if (!is_of_interest($tree, $machine_name)) {
        #dprintf("del_build: not of interest: $tree $machine_name $build_time");
        return;
    }

    #
    # Skip if the test manager isn't installed.
    #
    if ( !(-f $tm_del_build) || !(-x $tm_del_build) ) {
        #dprintf("del_build: tm scripts are missing");
        return;
    }

    #
    # Extract all build files from the fields table.
    #
    #dprintf("del_build: checking out $tree $machine_name $build_time $given_file...");
    my $raw_zip = '';
    my $build_file = '';
    my $fields_sth = $dbh->prepare('SELECT name, value FROM tbox_build_field WHERE machine_id = ? AND build_time = ?');
    $fields_sth->execute($machine_id, $build_time);
    while (my $row = $fields_sth->fetchrow_arrayref) {
        #dprintf("del_build: field=" . $row->[0] . " value=" . $row->[1]);
        if ($row->[0] eq 'raw_zip') {
            $raw_zip = $row->[1];
        } elsif (   $row->[0] eq 'testsuite_zip'
                 || $row->[0] eq 'build_run'
                 || $row->[0] eq 'build_rpm'
                 || $row->[0] eq 'build_msi'
                 || $row->[0] eq 'build_dmg'
                 || $row->[0] eq 'build_gz'
                 || $row->[0] eq 'build_exe'
                 || $row->[0] eq 'build_deb'
            ) {
            $build_file = $row->[1];
        }
    }

    #
    # Drop path prefixes like we do above in add_build.
    #
    $raw_zip =~ s|^/tinderbox/||;
    $raw_zip =~ s|^/builds/||;

    $build_file =~ s|^/tinderbox/||;
    $build_file =~ s|^/builds/||;

    $given_file =~ s|^/tinderbox/||;
    $given_file =~ s|^/builds/||;

    #
    # Invoke the build deletion script, telling it to mark all builds with
    # matching binaries as deleted.
    #
    my @args = ($tm_del_build, '--quiet', $given_file);
    if ($raw_zip ne ''  &&  $raw_zip ne $given_file) {
        push(@args, $raw_zip);
    }
    if ($build_file ne ''  &&  $build_file ne $given_file  &&  $raw_zip ne $build_file ) {
        push(@args, $build_file);
    }
    run_tm_script(@args);
}

