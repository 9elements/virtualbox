/* $Id: VBoxMouseDebug.c 114089 2026-05-06 13:45:14Z knut.osmundsen@oracle.com $ */
/** @file
 * VBoxMouse - VirtualBox Guest Additions Mouse Driver for OS/2, Debug Routines.
 */

/*
 * Copyright (C) 2017-2026 Oracle and/or its affiliates.
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


/*********************************************************************************************************************************
*   Header Files                                                                                                                 *
*********************************************************************************************************************************/
#include "VBoxMouse.h"
#include <bs3kit.h>
#include <VBox/log.h>
#include <iprt/asm-amd64-x86.h>

#ifdef DEBUG


/*********************************************************************************************************************************
*   Internal Functions                                                                                                           *
*********************************************************************************************************************************/
static FNBS3STRFORMATOUTPUT vboxDebugOutput;


/*********************************************************************************************************************************
*   Global Variables                                                                                                             *
*********************************************************************************************************************************/
int g_iVBoxDbgLevel = 1;


/**
 * Writes Bs3StrFormat output to the debug port.
 */
static BS3_DECL_CALLBACK(size_t) vboxDebugOutput(char ch, void BS3_FAR *pvUser)
{
    /* Ignore the final '\0' call. */
    if (ch != '\0')
    {
        ASMOutU8(RTLOG_DEBUG_PORT, ch);
        return 1;
    }
    NOREF(pvUser);
    return 0;
}


void __cdecl VBoxMouseDPrintf(const char RT_FAR *pszFormat, ...)
{
    va_list va;
    typedef int SIZE_CHECK_TYPE[sizeof(va) == 4 && sizeof(va[0]) == 4];

    va_start(va, pszFormat);
    Bs3StrFormatV(pszFormat, va, vboxDebugOutput, NULL);
    va_end(va);
}

#endif /* DEBUG */

