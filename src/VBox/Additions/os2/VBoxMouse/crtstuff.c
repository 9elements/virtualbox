/* $Id: crtstuff.c 114089 2026-05-06 13:45:14Z knut.osmundsen@oracle.com $ */
/** @file
 * Avoid dragging in libc bits.
 */

/*
 * Copyright (C) 2006-2026 Oracle and/or its affiliates.
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
#include <string.h>


/*********************************************************************************************************************************
*   Global Variables                                                                                                             *
*********************************************************************************************************************************/
/** Some absolute symbol to force in the right libc, I think. */
int small_code_ = 0;


_WCIRTLINK size_t _fstrlen(const char _far *psz)
{
    size_t cch = 0;
    while (*psz)
    {
        cch++;
        psz++;
    }
    return cch;
}


_WCIRTLINK void _far *_fmemcpy(void _far *pvDst, const void _far *pvSrc, size_t cb)
{
    const unsigned char _far *pbSrc = (const unsigned char _far *)pvSrc;
    unsigned char _far       *pbDst = (unsigned char _far *)pvDst;
    while (cb-- > 0)
        *pbDst++ = *pbSrc++;
    return pvDst;
}


_WCRTLINK int _fstrnicmp(const char _far *psz1, const char _far *psz2, size_t cchMax)
{
    while (cchMax-- > 0)
    {
        char ch1 = *psz1++;
        char ch2 = *psz2++;
        if (ch1 != ch2)
        {
            int iDiff = ch1 - ch2;
            if (ch1 >= 'a' && ch1 <= 'z')
                ch1 -= 'a' - 'A';
            if (ch2 >= 'a' && ch2 <= 'z')
                ch2 -= 'a' - 'A';
            if (ch1 != ch2)
                return iDiff;
        }
    }
    return 0;
}

