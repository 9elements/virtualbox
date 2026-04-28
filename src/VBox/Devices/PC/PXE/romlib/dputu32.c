/* $Id: dputu32.c 114041 2026-04-28 12:05:18Z knut.osmundsen@oracle.com $ */
/** @file
 * PXE - Debug backdoor logging (VBox).
 */

/*
 * Copyright (C) 2008-2026 Oracle and/or its affiliates.
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

#include "pxe_cmn.h"
#include "lsa_io.h"
#include "debug.h"

/* Debug Logging */

void dputu32(UINT32 n, UINT16 dtype)
{
    UINT32 const n2 = n / 10;
    n %= 10;
    if (n2 != 0)
        dputu32(n2, dtype);
    dputc('0' + (char)n, dtype);
}
