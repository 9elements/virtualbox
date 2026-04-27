#!/bin/sh
# $Id: container_build.sh 114033 2026-04-27 09:34:52Z knut.osmundsen@oracle.com $
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

## @todo bashism yet using /bin/sh.
set -eo pipefail

function at_exit()
{
    rc=$?

    echo "$0: cleaning up"
    rm -rf "$pkg_out_dir"
    rm -rf "$pkg_prebuilt_dir"
    rm -rf "$pkg_artifacts_dir"

    echo "$0: exited with status $rc"
}

trap at_exit EXIT

usage()
{
    echo "$0:"
    echo "$0: $1"
    echo "$0:"
    echo "$0: usage: $0 <distro name> <SVN URL> <SVN revision> <containers home dir> <artifacts out dir>"
    echo "$0:"
    echo "$0: In order to use custom revisions for VBoxEfiFirmware, VBoxGuestAdditions and VBoxDocumentation pre-built"
    echo "$0: archives, one or more of correponding environment variables can be set prior to running this script:"
    echo "$0: VBOX_EFI_REV, VBOX_ADD_REV and VBOX_DOC_REV. Note, revision should be specified as number without"
    echo "$0: leading 'r' character. Corresponding pre-built archive will be taken from a location on the build server"
    echo "$0: which corresponds to a branch which <SVN URL> points to."
    echo "$0: Set VBOX_NO_LOCAL_CLEANUP environment variable in order to prevent "
    echo "$0: 'svn cleanup --remove-unversioned --remove-ignored' on local copy."
    echo "$0: Set VBOX_KEEP_LOCAL_CHANGES environment variable in order to prevent 'svn revert -R .' on local copy"
    exit 1
}

[ $# != 5 ] && usage "incomplete command line"

VBOX_DISTRO="$1"
VBOX_SVN_URL="$2"
VBOX_SVN_REV="$3"
VBOX_CONTAINERS_RW_DIR="$4"
VBOX_ARTIFACTS_OUT_DIR="$5"

[ -z "$VBOX_DISTRO"  ] && usage "no distro specified"

[ -z "$VBOX_SVN_URL" ] && usage "no svn url"
[ -z "$VBOX_SVN_REV" ] && usage "no svn revision"

[ -z "$VBOX_CONTAINERS_RW_DIR" ]       && usage "no output dir"
[[ ! "$VBOX_CONTAINERS_RW_DIR" = /* ]] && usage "output dir cannot be specified as a relative path"

[ -z "$VBOX_ARTIFACTS_OUT_DIR" ]       && usage "no artefacts output dir"
[[ ! "$VBOX_ARTIFACTS_OUT_DIR" = /* ]] && usage "artefacts output dir cannot be specified as a relative path"

branch=$(basename $VBOX_SVN_URL)
[ -z "$branch"  ] && usage "no svn branch detected out of URL $VBOX_SVN_URL"

pkg_rw_dir="$VBOX_CONTAINERS_RW_DIR/build-$branch"
pkg_out_dir="$pkg_rw_dir/out"
pkg_svn_dir="$pkg_rw_dir/svn"
pkg_prebuilt_dir="$pkg_svn_dir/prebuild"
pkg_artifacts_dir="$pkg_rw_dir/artifacts"

efi_rev=$VBOX_SVN_REV
add_rev=$VBOX_SVN_REV
doc_rev=$VBOX_SVN_REV

[ -n "$VBOX_EFI_REV" ] && efi_rev="$VBOX_EFI_REV"
[ -n "$VBOX_ADD_REV" ] && add_rev="$VBOX_ADD_REV"
[ -n "$VBOX_DOC_REV" ] && doc_rev="$VBOX_DOC_REV"

[ -z "$efi_rev" ] && usage "no EFI revision specified"
[ -z "$add_rev" ] && usage "no Additions revision specified"
[ -z "$doc_rev" ] && usage "no Documantation revision specified"

init_work_dir()
{
    rm -rf "$pkg_out_dir"
    rm -rf "$pkg_prebuilt_dir"
    rm -rf "$pkg_artifacts_dir"

    [ -d "$pkg_rw_dir"        ] || mkdir -p "$pkg_rw_dir"
    [ -d "$pkg_out_dir"       ] || mkdir -p "$pkg_out_dir"
    [ -d "$pkg_svn_dir"       ] || mkdir -p "$pkg_svn_dir"
    [ -d "$pkg_prebuilt_dir"  ] || mkdir -p "$pkg_prebuilt_dir"
    [ -d "$pkg_artifacts_dir" ] || mkdir -p "$pkg_artifacts_dir"

    [ -d "$VBOX_ARTIFACTS_OUT_DIR" ] || mkdir -p "$VBOX_ARTIFACTS_OUT_DIR"
}

svn_checkout()
{
    echo "$0: ==="
    echo "$0: checking out $VBOX_SVN_URL @ r$VBOX_SVN_REV into $pkg_svn_dir"
    echo "$0: ==="

    svn checkout -r "$VBOX_SVN_REV" "$VBOX_SVN_URL" "$pkg_svn_dir"

    [ -n "$VBOX_NO_LOCAL_CLEANUP" ]     || ( cd "$pkg_svn_dir" && svn cleanup --remove-unversioned --remove-ignored )
    [ -n "$VBOX_KEEP_LOCAL_CHANGES" ]   || ( cd "$pkg_svn_dir" && svn revert -R . )

    ( cd "$pkg_svn_dir" && svn update -r "$VBOX_SVN_REV" )

    (
        cd "$pkg_svn_dir"
        PATH="$pkg_svn_dir/kBuild/bin/linux.amd64:$PATH"
        kmk VBOX_WITH_TOOLS_QT_LINUX=1 -C tools fetch

        # Generate SVN_REVISION -- deb/rpm build system will pick it up and put revision into
        # package version and name string.
        LC_ALL=C svn info | sed -e "s/^Last Changed Rev: \(.*\)/svn_revision := \1/;t;d" > SVN_REVISION
    )

    echo "$0: ==="
    echo "$0: checking out $VBOX_SVN_URL @ r$VBOX_SVN_REV into $pkg_svn_dir completed"
    echo "$0: ==="
}

get_prebuilt()
{
    echo "$0: ==="
    echo "$0: downloading prebuilt content from the build server into $pkg_prebuilt_dir"
    echo "$0: ==="

    [ -d "$pkg_prebuilt_dir" ]  || mkdir -p "$pkg_prebuilt_dir"

    dl_prefix="https://tindertux.de.oracle.com/builds-auto-download"
    for dl_url in \
        "$dl_prefix/efi/$branch/VBoxEfiFirmware-r$efi_rev.zip" \
        "$dl_prefix/add/$branch/VBoxGuestAdditions-r$add_rev.zip" \
        "$dl_prefix/doc/$branch/VBoxDocumentation-r$doc_rev.zip";
    do
        dl_local_file=$pkg_prebuilt_dir/$(basename "$dl_url")
        echo "  Downloading $dl_url into $dl_local_file..."
        wget -nv -O $dl_local_file "$dl_url"
        ( cd "$pkg_prebuilt_dir"; unzip "$dl_local_file" )
    done

    echo "$0: ==="
    echo "$0: downloading prebuilt content from the build server into $pkg_prebuilt_dir completed"
    echo "$0: ==="
}

case "$VBOX_DISTRO" in
    *-i386)
        prefix=/usr/bin/linux32
        ;;
esac

if which podman &>/dev/null; then
    docker=podman
elif which docker &>/dev/null; then
    docker=docker
else
    echo "$0: neither podman nor docker environment found, exiting"
    exit 1
fi

init_work_dir

export LANG=C
export LC_ALL=C

if pidof Xvfb > /dev/null; then
    passdisplay="export DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY;"
fi

image="vbox-build-$VBOX_DISTRO:latest"
container="vbox-build-$VBOX_DISTRO"

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

    echo "$0: ==="
    echo "$0: starting container $image"
    echo "$0: ==="

    # open file descriptor used for locking
    exec 9>"/tmp/$VBOX_DISTRO"

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
                -v "$VBOX_CONTAINERS_RW_DIR":"$VBOX_CONTAINERS_RW_DIR":z \
                -v /home/vbox/tinderout:/home/vbox/tinderout:z \
                --tmpfs /tmp:rw,mode=1777 \
                --cap-add=SYS_PTRACE \
                --name "$container"  \
                --entrypoint /bin/bash \
                "localhost/$image" >/dev/null
            else
                "$docker" start -i "$container"
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

    echo "$0: ==="
    echo "$0: starting container $image completed"
    echo "$0: ==="
fi

BUILD_CMD="
    set -eo pipefail;
    cd \"$pkg_svn_dir/src/VBox/Installer/linux\"; export PATH_OUT_BASE=\"$pkg_out_dir\";
        if which dpkg > /dev/null 2>&1; then \
            fakeroot debian/rules clean;
            fakeroot debian/rules binary NODOCS=1 STAGEDISO=\"$pkg_prebuilt_dir\" PKGDIR=\"$pkg_artifacts_dir\" QUIET=;
        else
            rpm/rules clean;
            rpm/rules binary             NODOCS=1 STAGEDISO=\"$pkg_prebuilt_dir\" PKGDIR=\"$pkg_artifacts_dir\" QUIET=;
        fi
"

if [ "$cstatus" = "running" ]; then
    svn_checkout
    get_prebuilt

    # run build task in container
    "$docker" exec -u "$USER" -w "$PWD" "$container" $prefix /bin/bash -lc "$passdisplay $BUILD_CMD"

    #### Copy just built artifacts to the specified output directory.
    echo "$0: copy rtifacts from $pkg_artifacts_dir to $VBOX_ARTIFACTS_OUT_DIR"
    find "$pkg_artifacts_dir" -name '*.rpm' -exec cp {} "$VBOX_ARTIFACTS_OUT_DIR" \;
    find "$pkg_artifacts_dir" -name '*.deb' -exec cp {} "$VBOX_ARTIFACTS_OUT_DIR" \;
else
    echo "Error: container $container not running: $cstatus" >&2
    exit 1
fi
