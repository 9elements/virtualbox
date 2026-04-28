/* $Id: debug.h 114041 2026-04-28 12:05:18Z knut.osmundsen@oracle.com $ */
/** @file
 * PXE - Debug header for backdoor logging (VBox specific).
 *
 * Basic idea:
 *   - If RELEASE_DEBUG is not defined, debug output gets macroed away
 *   - If RELEASE_DEBUG is defined, we have two types of output:
 *     - Informational (to INFO_PORT), always logged. This must be limited
 *       in quantity and should only log essential information. Could
 *       include information that might help troubleshoot PXE setup.
 *     - Debugging (to DEBUG_PORT), logged on demand. Should be verbose
 *       to aid diagnostics.
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

#ifndef VBOX_INCLUDED_SRC_PC_PXE_include_debug_h
#define VBOX_INCLUDED_SRC_PC_PXE_include_debug_h
#ifndef RT_WITHOUT_PRAGMA_ONCE
# pragma once
#endif

void dputc(char c, UINT16 type);
void dputs(char far *s, UINT16 type);
void dputh1(UINT8 n, UINT16 type);
void dputh2(UINT8 n, UINT16 type);
void dputh4(UINT16 n, UINT16 type);
void dputh8(UINT32 n, UINT16 type);
void dputu16(UINT16 n, UINT16 type);
void dputu32(UINT32 n, UINT16 type);

/* stolen from rombios.c */
#define PANIC_PORT  0x400
#define PANIC_PORT2 0x401
#define INFO_PORT   0x504
#define DEBUG_PORT  0x403

#ifndef RELEASE_DEBUG
    #define diputs(a)
    #define diputc(a)
    #define diputh2(a)
    #define diputh4(a)
    #define diputh8(a)
    #define diputu16(a)
    #define diputu32(a)
    #define diputip(a)
    #define ddputs(a)
    #define ddputc(a)
    #define ddputh2(a)
    #define ddputh4(a)
    #define ddputh8(a)
    #define ddputu16(a)
    #define ddputu32(a)
    #define ddputip(a)
#else
    #define diputs(a)   dputs(a, INFO_PORT)
    #define diputc(a)   dputc(a, INFO_PORT)
    #define diputh2(a)  dputh2(a, INFO_PORT)
    #define diputh4(a)  dputh4(a, INFO_PORT)
    #define diputh8(a)  dputh8(a, INFO_PORT)
    #define diputu16(a) dputu16(a, INFO_PORT)
    #define diputu32(a) dputu32(a, INFO_PORT)
    #define diputip(a)  dputip(a, INFO_PORT)

    #define ddputs(a)   dputs(a, DEBUG_PORT)
    #define ddputc(a)   dputc(a, DEBUG_PORT)
    #define ddputh2(a)  dputh2(a, DEBUG_PORT)
    #define ddputh4(a)  dputh4(a, DEBUG_PORT)
    #define ddputh8(a)  dputh8(a, DEBUG_PORT)
    #define ddputu16(a) dputu16(a, DEBUG_PORT)
    #define ddputu32(a) dputu32(a, DEBUG_PORT)
    #define ddputip(a)  dputip(a, DEBUG_PORT)
#endif

#endif /* !VBOX_INCLUDED_SRC_PC_PXE_include_debug_h */
