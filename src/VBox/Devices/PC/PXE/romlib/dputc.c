/* $Id: dputc.c 114041 2026-04-28 12:05:18Z knut.osmundsen@oracle.com $ */
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
#include <stddef.h>

/** @todo Sort out conio.h incompatibility */
_WCIRTLINK extern unsigned inp(unsigned __port);
_WCIRTLINK extern unsigned inpw(unsigned __port);
_WCIRTLINK extern unsigned outp(unsigned __port, unsigned __value);
_WCIRTLINK extern unsigned outpw(unsigned __port,unsigned __value);
#pragma intrinsic(inp,inpw,outp,outpw)

/* Debug Logging */

static int log_opt = -1;

void dputc(char c, UINT16 dtype)
{
    if (log_opt == -1)
    {
        outp(0x70, 0x3f);   /* Read PXE debug setting from  our CMOS offset */
        log_opt = inp(0x71);
    }
    /* Write everything to release log, but only if PXE debugging was enabled */
    if (log_opt > 0)
        outp(INFO_PORT, c);
}
