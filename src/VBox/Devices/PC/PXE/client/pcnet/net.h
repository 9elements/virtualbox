/* $Id: net.h 114041 2026-04-28 12:05:18Z knut.osmundsen@oracle.com $ */
/** @file
 * PXE - Device detection.
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

#ifndef VBOX_INCLUDED_SRC_PC_PXE_client_pcnet_net_h
#define VBOX_INCLUDED_SRC_PC_PXE_client_pcnet_net_h
#ifndef RT_WITHOUT_PRAGMA_ONCE
# pragma once
#endif

#define PCNET_VENDOR_ID          0x1022  /* AMD */
#define PCNET_DEVICE_ID          0x2000  /* Am79C970A */

#define E1K_VENDOR_ID            0x8086  /* Intel */
#define E1K_DEVICE_ID_82540EM    0x100E  /* 82540EM-A */
#define E1K_DEVICE_ID_82543GC    0x1004  /* 82543GC (Server) */
#define E1K_DEVICE_ID_82545EM    0x100F  /* 82545EM-A */

extern uint8_t      RxBuffer[2048];
extern uint8_t      TxBuffer[2048];

//extern int    nic_detect(void);
extern void (*pf_nic_cleanup)(void);
extern int  (*pf_nic_setup)(void);
extern void (*pf_nic_open)(void);
extern void (*pf_nic_close)(void);
extern void (*pf_nic_send)(unsigned frag_cnt, nic_frag_t FAR *frags);
extern int  (*pf_nic_have_received)(void);
extern unsigned (*pf_nic_receive)(uint8_t FAR * FAR *pbuf);
extern void (*pf_nic_receive_done)(uint8_t FAR *buf);
extern int  (*pf_nic_int_check)(void);
extern void (*pf_nic_int_disable)(void);
extern void (*pf_nic_int_enable)(void);
extern void (*pf_nic_int_force)(void);
extern void (*pf_nic_int_clear)(void);
extern void (*pf_nic_get_info)(nic_info_t FAR *info);
extern void (*pf_nic_get_type)(nic_type_t FAR *type);
extern uint8_t FAR * (*pf_get_mac_ptr)(void);

#endif /* !VBOX_INCLUDED_SRC_PC_PXE_client_pcnet_net_h */
