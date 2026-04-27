/* $Id: affinity.c 114033 2026-04-27 09:34:52Z knut.osmundsen@oracle.com $ */
/** @file
 * Utility to set affinity to CPU0 and execute whatever
 * follows on the command line. Old cygwin workaround.
 */

/*
 * Copyright (C) 2010-2026 Oracle and/or its affiliates.
 *
 * This file is part of VirtualBox base platform packages, as
 * available from https://www.virtualbox.org.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation, in version 3 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <https://www.gnu.org/licenses>.
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */

#include <stdio.h>
#include <process.h>
#include <unistd.h>
#include <errno.h>
#include <windows.h>


int main (int argc, char **argv)
{
    SetProcessAffinityMask(GetCurrentProcess(), 1);
    execvp(argv[1], &argv[1]);
    printf("execvp failed - %d\n", errno);
    return 1;
}
