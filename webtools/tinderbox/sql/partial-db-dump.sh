#!/bin/bash
# $Id: partial-db-dump.sh 114033 2026-04-27 09:34:52Z knut.osmundsen@oracle.com $
## @file
# Performs a partial tinderbox database dump.
#

#
# Copyright (C) 2020-2026 Oracle and/or its affiliates.
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

# Stop on failures.
set -e

#
# Parse arguments.
#
my_dstdir="/tmp"
my_days_to_dump="14"
my_database="--dbname=tbox"
my_username=""

while [ $# -gt 0 ];
do
    case "$1" in
        --days-to-dump)
            my_days_to_dump="$2"
            if ! [[ "${my_days_to_dump}" =~ ^[0-9]+$ ]]; then
                echo "$0: syntax error: --days-to-dump value must be an integer" >&2;
                exit 2;
            fi
            shift
            ;;
        --dst|--dst-dir|--destination)
            my_dstdir="$2"
            if [ -z "${my_dstdir}" ]; then
                echo "$0: syntax error: Empty destination dir." >&2;
                exit 2;
            fi
            my_dstdir="$(readlink -f "${my_dstdir}")"
            shift
            ;;
        --username)
            if [ -z "$2" ]; then
                my_username=""
            else
                my_username="--username=$2"
            fi
            shift
            ;;
        --database)
            if [ -z "$2" ]; then
                my_database=""
            else
                my_database="--dbname=$2"
            fi
            shift
            ;;
        -h|--help)
            echo "usage: $0 [--days-to-dump <N>] [--dst <dir>] [--username <user>] [--database <db>]"
            exit 0
            ;;
        *)
            echo "syntax error: Invalid argument: $1" >&2
            exit 2
            ;;
    esac
    shift
done

## Uses psql to COPY a table.
# @param $1    The table
# @param $2    WHERE... (optional)
my_copy_table()
{
    if [ -n "$2" ]; then
        my_file="${my_dstdir}/$1.partial.sql"
    else
        my_file="${my_dstdir}/$1.full.sql"
    fi
    echo "Dumping $1..."
    if ! psql -t ${my_database} ${my_username} \
              -c "COPY (SELECT * FROM $1 $2) TO STDOUT WITH (FORMAT TEXT)" > "${my_file}"; then
        echo "Error dumping table $1" >&2;
        exit 1
    fi
}


#
# Make sure the destination directory exists and is a directory.
#
mkdir -p "${my_dstdir}"
test -d "${my_dstdir}"

#
# Dump the tables.
# Note! Using CURRENT_DATE here, assuming the script isn't run just before midnight.
#
my_copy_table tbox_build_field "WHERE build_time >= (CURRENT_DATE - '${my_days_to_dump} days'::INTERVAL)"
my_copy_table tbox_build       "WHERE build_time >= (CURRENT_DATE - '${my_days_to_dump} days'::INTERVAL)"

my_copy_table tbox_bonsai
my_copy_table tbox_bonsai_cache
my_copy_table tbox_build_comment
my_copy_table tbox_initial_machine_config
my_copy_table tbox_machine
my_copy_table tbox_machine_config
my_copy_table tbox_patch
my_copy_table tbox_session
my_copy_table tbox_tree

exit 0
