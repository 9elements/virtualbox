/* $Id: net.c 114041 2026-04-28 12:05:18Z knut.osmundsen@oracle.com $ */
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

#include "common.h"
#include "nic_api.h"
#include "net.h"
//#include "e1000.h"
//#include "lsa_mem.h"
#include "lsa_io.h"
//#include "lsa_misc.h"
//#include "debug.h"

extern int nic_init_pcnet(nic_type_t *nic_type, uint8_t bus, uint8_t dev, uint8_t fun, uint8_t irq);
extern int nic_init_e1000(nic_type_t *nic_type, uint8_t bus, uint8_t dev, uint8_t fun, uint8_t irq);

uint8_t      RxBuffer[2048];
uint8_t      TxBuffer[2048];

void (*pf_nic_cleanup)(void);
int  (*pf_nic_setup)(void);
void (*pf_nic_open)(void);
void (*pf_nic_close)(void);
void (*pf_nic_send)(unsigned frag_cnt, nic_frag_t FAR *frags);
int  (*pf_nic_have_received)(void);
unsigned (*pf_nic_receive)(uint8_t FAR * FAR *pbuf);
void (*pf_nic_receive_done)(uint8_t FAR *buf);
int  (*pf_nic_int_check)(void);
void (*pf_nic_int_disable)(void);
void (*pf_nic_int_enable)(void);
void (*pf_nic_int_force)(void);
void (*pf_nic_int_clear)(void);
void (*pf_nic_get_info)(nic_info_t FAR *info);
void (*pf_nic_get_type)(nic_type_t FAR *type);
uint8_t FAR * (*pf_get_mac_ptr)(void);

/** @todo Sort out conio.h incompatibility */
_WCIRTLINK extern unsigned inp(unsigned __port);
_WCIRTLINK extern unsigned outp(unsigned __port, unsigned __value);
#pragma intrinsic(inp,inpw,outp,outpw)

/* Read a byte from the second CMOS bank. */
uint8_t cmos2_read(uint8_t offset)
{
    outp(0x72, offset);
    return inp(0x73);
}

int nic_detect(void)
{
    /* Static because SS != DS, just a quick hack. */
    static uint8_t  bus, fun, dev, irq;
    static uint16_t iobase;
    static uint16_t busdevfn;

    /* Read the bus/dev/fn from second CMOS bank. See DevPcBios for
     * CMOS layout information.
     */
    busdevfn  = cmos2_read(0);
    busdevfn |= cmos2_read(1) << 8;

    /* All bits set or clear are invalid values indicating fallback to
     * old method. If invalid bus/dev/fn is passed in CMOS, the boot
     * will fail.
     */
    if (busdevfn != 0xffff && busdevfn != 0)
    {
        bus = busdevfn >> 8;
        dev = (busdevfn & 0xff) >> 3;
        fun = busdevfn & 0x7;
    }
    else
    {
        if (!pci_find_class(2, 0, 0, 0, &bus, &dev, &fun))
        {
            bus = dev = fun = 0;
        }
    }
    if (bus + dev + fun != 0)
    {
        static nic_type_t nic_type;
        /* Read Vendor ID */
        pci_read_config_word(bus, dev, fun, 0x00, &nic_type.vid);
        /* Read Device ID */
        pci_read_config_word(bus, dev, fun, 0x02, &nic_type.did);
        /* Read Revision */
        pci_read_config_byte(bus, dev, fun, 0x08, &nic_type.rev);
        /* Read Prog Intf */
        pci_read_config_byte(bus, dev, fun, 0x09, &nic_type.pif);
        /* Read Sub Class */
        pci_read_config_byte(bus, dev, fun, 0x0A, &nic_type.scls);
        /* Read Base Class */
        pci_read_config_byte(bus, dev, fun, 0x0B, &nic_type.bcls);
        /* Read Subsystem Vendor ID */
        pci_read_config_word(bus, dev, fun, 0x2C, &nic_type.svid);
        /* Read Subsystem ID */
        pci_read_config_word(bus, dev, fun, 0x2E, &nic_type.sdid);
        nic_type.bdf = ((uint16_t)bus << 8) | (dev << 3) | fun;
        /* Read IRQ line */
        pci_read_config_byte(bus, dev, fun, 0x3C, &irq);

        if (   nic_type.vid == PCNET_VENDOR_ID
            && nic_type.did == PCNET_DEVICE_ID)
        {
            if (nic_init_pcnet(&nic_type, bus, dev, fun, irq))
                return -1;
        }
        else if (   nic_type.vid == E1K_VENDOR_ID
                 && (   nic_type.did == E1K_DEVICE_ID_82540EM
                     || nic_type.did == E1K_DEVICE_ID_82543GC
                     || nic_type.did == E1K_DEVICE_ID_82545EM))
        {
            if (nic_init_e1000(&nic_type, bus, dev, fun, irq))
                return -1;
        }
        else
        {
            puts("\r\nUnknown Ethernet controller! Aborting PXE boot...");
            return -1;
        }

        return 0;
    }
    puts("\r\nNo Ethernet controllers found! Aborting PXE boot...");
    return -1;
}

void nic_cleanup(void)
{
    if (pf_nic_cleanup)
        pf_nic_cleanup();
}

int nic_setup(void)
{
    if (pf_nic_setup)
        return pf_nic_setup();
    return -1;
}

void nic_open(void)
{
    if (pf_nic_open)
        pf_nic_open();
}

void nic_close(void)
{
    if (pf_nic_close)
        pf_nic_close();
}

void nic_send(unsigned frag_cnt, nic_frag_t FAR *frags)
{
    if (pf_nic_send)
        pf_nic_send(frag_cnt, frags);
}

int nic_have_received(void)
{
    if (pf_nic_have_received)
        return pf_nic_have_received();
    return 0;
}

unsigned nic_receive(uint8_t FAR * FAR *pbuf)
{
    if (pf_nic_receive)
        return pf_nic_receive(pbuf);
    return 0;
}

void nic_receive_done(uint8_t FAR *buf)
{
    if (pf_nic_receive_done)
        pf_nic_receive_done(buf);
}

int nic_int_check(void)
{
    if (pf_nic_int_check)
        return pf_nic_int_check();
    return 0;
}

void nic_int_disable(void)
{
    if (pf_nic_int_disable)
        pf_nic_int_disable();
}

void nic_int_enable(void)
{
    if (pf_nic_int_enable)
        pf_nic_int_enable();
}
void nic_int_force(void)
{
    if (pf_nic_int_force)
        pf_nic_int_force();
}
void nic_int_clear(void)
{
    if (pf_nic_int_clear)
        pf_nic_int_clear();
}
void nic_get_info(nic_info_t FAR *info)
{
    if (pf_nic_get_info)
        pf_nic_get_info(info);
}
void nic_get_type(nic_type_t FAR *type)
{
    if (pf_nic_get_type)
        pf_nic_get_type(type);
}

uint8_t FAR * get_mac_ptr(void)
{
    if (pf_get_mac_ptr)
        return pf_get_mac_ptr();
    return 0;
}

