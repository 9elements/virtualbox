#!/bin/sh
# $Id: start.sh 114033 2026-04-27 09:34:52Z knut.osmundsen@oracle.com $
## @file
# Starts tinderclient.pl on a tinderbox.
#

#
# Copyright (C) 2008-2026 Oracle and/or its affiliates.
#
# This file is part of VirtualBox base platform packages, as
# available from https://www.virtualbox.org.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, in version 3 of the
# License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <https://www.gnu.org/licenses>.
#
# SPDX-License-Identifier: GPL-3.0-only
#

if [ "${USER}" = "root" -o "${LOGNAME}" = "root" -o "${USERNAME}" = "Administrator" ]; then
    echo "Don't run the builds as root/Administrator!"
    echo "ssh to the box using: user:vbox pw:********"
    exit 1
fi

# Guess tinderbox base directory, can be overwritten by option file.
my_tinderbox_dir="$(cd -P "$(dirname "$(readlink "$0" || echo "$0")")" && pwd)"
[ -f "${my_tinderbox_dir}/tinderclient.pl" ] && my_tinderbox_dir="$(dirname "${my_tinderbox_dir}")"
[ \! -f "${my_tinderbox_dir}/client/tinderclient.pl" ] && my_tinderbox_dir="${HOME}/tinderbox"

# Config prefix and suffix can come from file.
my_cfg_prefix=vbox
[ -f "${my_tinderbox_dir}/.build-config-prefix" ] && my_cfg_prefix="$(cat "${my_tinderbox_dir}/.build-config-prefix")"
my_cfg_suffix=
[ -f "${my_tinderbox_dir}/.build-config-suffix" ] && my_cfg_suffix="$(cat "${my_tinderbox_dir}/.build-config-suffix")"

my_hostname="$(hostname)"
case "${my_hostname}" in
    *.*)
        my_hostname="$(echo "${my_hostname}" | sed -e 's/^\([^.]*\)\..*$/\1/')"
        # 'hostname' on Solaris does not know option -s.
        ;;
esac

while [ $# -ge 1 ]; do
    ARG="$1"
    shift
    case "$1" in
        --cfgprefix)
            if [ $# -eq 0 ]; then
                echo "error: missing --cfgprefix argument" >&2
                exit 1
            fi
            if [ -z "$1" ]; then
                echo "error: --cfgprefix argument must be non-empty" >&2
                exit 1
            fi
            my_cfg_prefix="$1"
            shift
            ;;

        --hostname)
            if [ $# -eq 0 ]; then
                echo "error: missing --hostname argument" >&2
                exit 1
            fi
            if [ -z "$1" ]; then
                echo "error: --hostname argument must be non-empty" >&2
                exit 1
            fi
            my_hostname="$1"
            shift
            ;;

        a|b|c|d|e)
            my_cfg_suffix="-${ARG}"
            ;;

        0)
            my_cfg_suffix=
            ;;

        1|2|3|4|5)
            my_cfg_suffix="-${ARG}"
            ;;

        # usage
        --h*|-h*|-?|--?)
            echo "usage: $0 {--cfgprefix <prefix>] {--hostname <hostname>] [a..e]"
            exit 0
            ;;

        *)
            echo "error: invalid parameter \"${ARG}\", try $0 --help"
            exit 1;
            ;;
    esac
done

case "$(uname -s)" in
    Darwin)
        if ! security show-keychain-info > /dev/null 2>&1; then
            echo "Unlocking keychain..."
            security unlock-keychain || exit 2
        fi
        # Recent subversion expects it is set to something
        LANG=C
        export LANG
        ;;
esac

unset TINDERBOX_DIR PERL_CMD USE_NICE USE_AFFINITY USE_XVFB START_WAIT

# Default options for all builds
if [ -f "${my_tinderbox_dir}/client/${my_cfg_prefix}.defaults.opt" ]; then
    . "${my_tinderbox_dir}/client/${my_cfg_prefix}.defaults.opt"
fi
# Specific options for this build box (and suffix)
if [ -f "${my_tinderbox_dir}/client/${my_cfg_prefix}.${my_hostname}${my_cfg_suffix}.opt" ]; then
    . "${my_tinderbox_dir}/client/${my_cfg_prefix}.${my_hostname}${my_cfg_suffix}.opt"
fi

[ -n "${TINDERBOX_DIR}" ] && my_tinderbox_dir="${TINDERBOX_DIR}"

if [ -z "${PERL_CMD}" -a "$(uname -s)" = "Darwin" ]; then
    PERL_CMD="perl -w" # Use perl from macports.
fi

my_cmd_prefix=
[ -n "${USE_NICE}" ] && my_cmd_prefix="nice ${my_cmd_prefix}"
[ -n "${USE_AFFINITY}" ] && my_cmd_prefix="client/affinity.exe ${my_cmd_prefix}"
[ -n "${USE_XVFB}" ] && my_cmd_prefix="xvfb-run ${my_cmd_prefix}"
[ -n "${PERL_CMD}" ] && my_cmd_prefix="${my_cmd_prefix}${PERL_CMD} "

if [ -n "${START_WAIT}" ]; then
    echo
    echo "Press key to start the build, pwd=$PWD"
    read ignored
fi

# tinderdoc: The itirc/itcc Wine tweaks were done without a DISPLAY
# (see tinderdoc housekeeping page / Quirks)
[ "${my_hostname}" = "tinderdoc" ] && unset DISPLAY

# Set custom temp directory (usually ramdisk)
if [ -d "${my_tinderbox_dir}/tmp" ]; then
    export TMP="${my_tinderbox_dir}/tmp"
    export TEMP="${my_tinderbox_dir}/tmp"
    export TMPDIR="${my_tinderbox_dir}/tmp"
fi

# Can't hurt - Windows tends to mess this up.
chmod +x "${my_tinderbox_dir}/client/tinderclient.pl"

cd "${my_tinderbox_dir}"
${my_cmd_prefix}"${my_tinderbox_dir}/client/tinderclient.pl" \
  --config="${my_tinderbox_dir}/client/${my_cfg_prefix}.${my_hostname}${my_cfg_suffix}.cfg" \
  --default_config="${my_tinderbox_dir}/client/${my_cfg_prefix}.defaults.cfg" \

