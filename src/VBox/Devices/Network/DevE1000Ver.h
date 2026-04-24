/** $Id: DevE1000Ver.h 114026 2026-04-24 18:41:25Z aleksey.ilyushin@oracle.com $ */
/** @file
 * DevE1000Ver - Intel 82540EM Ethernet Controller saved state versions, Header.
 */

/*
 * Copyright (C) 2007-2026 Oracle and/or its affiliates.
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

#ifndef VBOX_INCLUDED_SRC_Network_DevE1000Ver_h
#define VBOX_INCLUDED_SRC_Network_DevE1000Ver_h
#ifndef RT_WITHOUT_PRAGMA_ONCE
# pragma once
#endif

/** The current Saved state version. */
# define E1K_SAVEDSTATE_VERSION               E1K_SAVEDSTATE_VERSION_82574
/** Saved state version at the introduction of 82574 support. */
# define E1K_SAVEDSTATE_VERSION_82574         7
/** Saved state version for struct versioning support. */
# define E1K_SAVEDSTATE_VERSION_82583V_struct 6
/** Saved state version at the introduction of 82583V support. */
# define E1K_SAVEDSTATE_VERSION_82583V        5
/** Saved state version before the introduction of 82583V support. */
# define E1K_SAVEDSTATE_VERSION_PRE_82583V    4
/** Saved state version for VirtualBox 4.2 with VLAN tag fields.  */
# define E1K_SAVEDSTATE_VERSION_VBOX_42_VTAG  3
/** Saved state version for VirtualBox 4.1 and earlier.
 * These did not include VLAN tag fields.  */
#define E1K_SAVEDSTATE_VERSION_VBOX_41  2
/** Saved state version for VirtualBox 3.0 and earlier.
 * This did not include the configuration part nor the E1kEEPROM.  */
#define E1K_SAVEDSTATE_VERSION_VBOX_30  1

#endif /* !VBOX_INCLUDED_SRC_Network_DevE1000Ver_h */

