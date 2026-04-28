/* $Id: nic_api.h 114041 2026-04-28 12:05:18Z knut.osmundsen@oracle.com $ */
/** @file
 * PXE - Device detection and driver abstraction.
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

#ifndef VBOX_INCLUDED_SRC_PC_PXE_include_nic_api_h
#define VBOX_INCLUDED_SRC_PC_PXE_include_nic_api_h
#ifndef RT_WITHOUT_PRAGMA_ONCE
# pragma once
#endif

#include <inttypes.h>

#define AVL         /* to get Ethernet media header definition */
#include "cdefs.h"

#define FAR         __far
#define NEAR        __near

typedef struct {
    uint16_t        len;
    const void FAR  *ptr;
} nic_frag_t;

typedef struct {
    uint8_t         perm_addr[DADDLEN];
    uint8_t         curr_addr[DADDLEN];
    uint16_t        iobase;
    uint8_t         irq;
    uint8_t         rx_bufs;
    uint8_t         tx_bufs;
} nic_info_t;

typedef struct {
    uint16_t        vid;
    uint16_t        did;
    uint16_t        svid;
    uint16_t        sdid;
    uint16_t        bdf;
    uint8_t         bcls;
    uint8_t         scls;
    uint8_t         pif;
    uint8_t         rev;
} nic_type_t;

int         nic_detect(void);
void        nic_cleanup(void);
int         nic_setup(void);
void        nic_open(void);
void        nic_close(void);
void        nic_send(unsigned frag_cnt, nic_frag_t FAR *frags);
int         nic_have_received(void);
unsigned    nic_receive(uint8_t FAR * FAR *pbuf);
void        nic_receive_done(uint8_t FAR *buf);
void        nic_int_disable(void);
void        nic_int_enable(void);
void        nic_int_force(void);
int         nic_int_check(void);
void        nic_int_clear(void);
void        nic_get_info(nic_info_t FAR *info);
void        nic_get_type(nic_type_t FAR *type);
uint8_t FAR *get_mac_ptr(void);

#endif /* !VBOX_INCLUDED_SRC_PC_PXE_include_nic_api_h */
