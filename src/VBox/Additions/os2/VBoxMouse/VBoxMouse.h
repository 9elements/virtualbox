/* $Id: VBoxMouse.h 114089 2026-05-06 13:45:14Z knut.osmundsen@oracle.com $ */
/** @file
 * VBoxMouse - VirtualBox Guest Additions Mouse Driver for OS/2, internal header.
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

#ifndef ___vboxmouse_h___
#define ___vboxmouse_h___

#ifndef __WATCOMC__
# error "Expecting source to be compiled with OpenWatcom"
#endif
#ifndef M_I86
# error "16-bit only!"
#endif
#ifndef __SW_ZU
# error "Must be compiled with the -zu option (SS != DS)!"
#endif

#ifndef OS2_INCLUDED
# define INCL_NOPMAPI
# include <os2.h>
#endif
#include <devhelp.h>

#include <iprt/cdefs.h>
#include <iprt/types.h>

RT_C_DECLS_BEGIN

/* VBoxMouse.c */
void __cdecl VBoxAttachToVBoxGuest(void);
bool __cdecl VBoxMouseSendPacketAbsolute(int16_t x, int16_t y, uint8_t event);
void __cdecl __loadds __far VBoxScreenSizeChange(uint16_t Ssi_Mtype, uint16_t Ssi_TCol_Res, uint16_t Ssi_TRow_Res,
                                                 uint16_t Ssi_GCol_Res, uint16_t Ssi_GRow_Res);
void __cdecl __loadds __far VBoxUpdatePointer(void);


/*
 * Logging (VBoxMouseDebug.c).
 */
void __cdecl VBoxMouseDPrintf(const char RT_FAR *pszFormat, ...);
extern int g_iVBoxDbgLevel;
#ifdef DEBUG
# define dprintf(a)     do { VBoxMouseDPrintf a; } while (0)
# define dprintf2(a)    do { if (g_iDbgLevel >= 2) VBoxMouseDPrintf a; } while (0)
# define dprintf3(a)    do { if (g_iDbgLevel >= 3) VBoxMouseDPrintf a; } while (0)
# define dprintf4(a)    do { if (g_iDbgLevel >= 4) VBoxMouseDPrintf a; } while (0)
# define DebugInt3()    RT_BREAKPOINT()
#else
# define dprintf(a)     do {} while (0)
# define dprintf2(a)    do {} while (0)
# define dprintf3(a)    do {} while (0)
# define dprintf4(a)    do {} while (0)
# define DebugInt3()    do {} while (0)
#endif

RT_C_DECLS_END

#endif

