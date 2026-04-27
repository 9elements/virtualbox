#!/bin/sh
# $Id: jail.sh 114033 2026-04-27 09:34:52Z knut.osmundsen@oracle.com $
## @file
# Tinderclient helper script.
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

if [ $# -lt 2 ]; then
    echo "$0: insufficient parameters"
    exit 1
fi

jailname="$1"
shift

case "$jailname" in
    *-i386)
        prefix=/usr/bin/linux32
        ;;
esac

if [ -f "/etc/dchroot.conf" ]; then
    chrootpath=`cat /etc/dchroot.conf|sed -e 's/^'$jailname' *\(.*\)/\1/;t;d'`
elif [ -f "/etc/schroot/schroot.conf" ]; then
    chrootpath=`cat /etc/schroot/schroot.conf|sed -e 's/^directory=\(.*'$jailname'\)/\1/;t;d'`
elif which linux-user-chroot 2>/dev/null; then
    chrootpath="$HOME/jails/$jailname"
elif which podman &>/dev/null; then
    docker=podman
elif which docker &>/dev/null; then
    docker=docker
fi

export LANG=C
export LC_ALL=C

if pidof Xvfb > /dev/null; then
   passdisplay="export DISPLAY=$DISPLAY XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority};"
fi

if [ -n "$chrootpath" ]; then
    myhost="$(hostname)"
    case "$myhost" in
        *.*)
            myhost="$(echo "$myhost" | sed -e 's/^\([^.]*\)\..*$/\1/')"
            # 'hostname' on Solaris does not know option -s.
            ;;
    esac

    # more directories to mount on tinderlin*
    case "$myhost" in
        tinderlin*|vbox-srv*)
            mount|grep -q "$chrootpath/proc" || \
                sudo mount -v -t proc -o nodev,noexec,nosuid proc "$chrootpath/proc"
            mount|grep -q "$chrootpath/home" || \
                sudo mount -v -o noatime --bind /home/vbox/jails/jail_vbox "$chrootpath/home"
            mount|grep -q "$chrootpath/tmp" || \
                sudo mount -v --bind /tmp "$chrootpath/tmp"
        ;;
    esac

    tinderboxdir="$(dirname "$PWD")"
    mount|grep -q "$chrootpath$tinderboxdir" || \
        sudo mount -v --bind "$tinderboxdir" "$chrootpath$tinderboxdir"
    mount|grep -q "$chrootpath/dev/pts" || \
        sudo mount -v -t devpts -o nosuid,noexec devpts "$chrootpath/dev/pts"
fi

if [ -n "$chrootpath" ]; then
    if [ -f "/etc/dchroot.conf" -o -f "/etc/schroot/schroot.conf" ]; then
        dchroot --quiet --directory "$PWD" --chroot "$jailname" -- $passdisplay $prefix "bash -lc \"$@\""
    else
        linux-user-chroot --chdir "$PWD" "$chrootpath" $prefix /bin/bash -lc "$passdisplay$*"
    fi
else
    image="vbox-build-$jailname:latest"
    container="vbox-build-$jailname"

    # check if image is present
    if [ -z "$("$docker" images -n "$image")" ]; then
       echo "Error: container image $image not found" >&2
       exit 1
    fi

    # check container status
    cstatus="not-existing"
    if [ -n "$("$docker" ps -q -f "name=$container")" ]; then
       cstatus="running"
    elif [ "$("$docker" container inspect -f "{{.State.Status}}" "$container" 2>/dev/null)" = "exited" ]; then
       cstatus="stopped"
    elif [ "$("$docker" container inspect -f "{{.State.Status}}" "$container" 2>/dev/null)" = "created" ]; then
       cstatus="stopped"
    fi

    if [ "$cstatus" != "running" ]; then
        # try running the container, dealing with other processes doing the same

        # open file descriptor used for locking
        exec 9>"/tmp/$jailname"

        # wait container is starting form other job
        iterations=0
        max_iterations=20
        while true; do
            if [ $((iterations++)) -gt $max_iterations ]; then
                cstatus="start-timeout"
                break
            fi

            # check file lock
            flock -n 9
            if [ $? -ne 0 ]; then
                # lock failed, wait a little
                sleep 2
                # is container already running?
                if [ -n "$("$docker" ps -q -f "name=$container")" ]; then
                    cstatus="running"
                    break
                fi
            else
                # have the lock, run the container
                if [ "$cstatus" = "not-existing" ]; then
                    "$docker" run \
                    -itd \
                    --userns keep-id \
                    -u $USER \
                    -v /home/vbox/tinderbox:/home/vbox/tinderbox:z \
                    -v /home/vbox/tinderout:/home/vbox/tinderout:z \
                    --tmpfs /tmp:rw,mode=1777 \
                    --cap-add=SYS_PTRACE \
                    --pids-limit=4096 \
                    --name "$container"  \
                    --entrypoint /bin/bash \
                    "localhost/$image" >/dev/null
                else
                    "$docker" start "$container"
                fi

                # wait until container started
                iterations=0
                while true; do
                    if [ $((iterations++)) -gt $max_iterations ]; then
                        cstatus="wait-timeout"
                        break
                    fi
                    sleep 2
                    if [ -n "$("$docker" ps -q -f "name=$container")" ]; then
                        cstatus="running"
                        break
                    fi
                done
                break
            fi
        done

        exec 9>&- #close fd 9, and release lock
    fi

    if [ "$cstatus" = "running" ]; then
       # run build task in container
       "$docker" exec -u "$USER" -w "$PWD" "$container" $prefix /bin/bash -lc "$passdisplay$*"
    else
       echo "Error: container $container not running: $cstatus" >&2
       exit 1
    fi
fi
