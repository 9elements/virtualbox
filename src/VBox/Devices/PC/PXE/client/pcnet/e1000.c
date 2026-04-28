/* $Id: e1000.c 114041 2026-04-28 12:05:18Z knut.osmundsen@oracle.com $ */
/** @file
 * PXE - E1000 Driver.
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

/* Comment out WDS_WORKAROUND to advance RDT immediately after release of
 * previous buffer. With WDS_WORKAROUND defined, RDT advance will be postponed
 * until the next receive poll (nic_have_received_e1000), preventing packet
 * loss. See @bugref{9850} for details.
 */
#define WDS_WORKAROUND 1

#include "common.h"
#include "nic_api.h"
#include "e1000.h"
#include "lsa_mem.h"
#include "lsa_io.h"
#include "lsa_misc.h"
#include "debug.h"
#include "net.h"

/* So that we can use inlined in/out instructions */
#include <stddef.h>
_WCIRTLINK extern unsigned outpw(unsigned __port,unsigned __value);
_WCIRTLINK extern unsigned inpw(unsigned __port);
#pragma intrinsic(inp,inpw,outp,outpw)

#ifdef FIX_BUGBUG /* BUGBUG - Watcom throws an error because DEBUG is already defined. Please figure out what is wanted! */
    #undef DEBUG
#endif
#define DEBUG 0
#if DEBUG
    #define duputs(a)    puts(a)
    #define duputh1(a)   puth1(a)
    #define duputh2(a)   puth2(a)
    #define duputh4(a)   puth4(a)
    #define duputh8(a)   puth8(a)
#else
    #define duputs(a)
    #define duputh1(a)
    #define duputh2(a)
    #define duputh4(a)
    #define duputh8(a)
#endif
#undef DEBUG

/* So that we can use inlined in/out instructions */
#include <stddef.h>
_WCIRTLINK extern unsigned outpd(unsigned __port,unsigned __value);
_WCIRTLINK extern unsigned inpd(unsigned __port);
#pragma intrinsic(inp,inpw,outp,outpw)


/* Driver "instance". Not likely we'd need more than one. */
static ADAPTER      Adapter;

/* The following data blocks are used for communicating with hardware. We need to know
 * their physical addresses.
 *
 * NOTE that all eight RX descriptors will share the same RX buffer! The same goes for TX.
 * We can get away with it because we are adding active descriptors to RX/TX rings one by one,
 * ensuring that niether ring will have more than one active descriptor at any time.
 */
#define NUM_RXD     8
#define NUM_TXD     8
static E1KRD        RxD[NUM_RXD];
static E1KTD        TxD[NUM_TXD];

/// @todo This method won't work in protected mode
static uint32_t getPhysAddr(void FAR *addr)
{
    return (((uint32_t)FP_SEG(addr)) << 4) + FP_OFF(addr);
}


static uint32_t readAddr(void)
{
    ADAPTER     *adapter = &Adapter;
    uint16_t     iobase  = adapter->iobase;
    _asm {
        mov dx, iobase
        in  eax, dx
        mov edx, eax
        shr edx, 16
    };
}

static void writeAddr(uint32_t u32Offset)
{
    ADAPTER     *adapter = &Adapter;
    uint16_t     iobase  = adapter->iobase;
    _asm {
        mov dx, iobase
        mov eax, u32Offset
        out dx, eax
    };
}

static uint32_t readReg(uint32_t u32Offset)
{
    ADAPTER     *adapter = &Adapter;
    uint16_t     iobase  = adapter->iobase;
    _asm {
        mov dx, iobase
        mov eax, u32Offset
        out dx, eax
        add dx, 4
        in  eax, dx
        mov edx, eax
        shr edx, 16
    };
}


static void writeReg(uint32_t u32Offset, uint32_t u32Value)
{
    ADAPTER     *adapter = &Adapter;
    uint16_t     iobase  = adapter->iobase;
    _asm {
        mov dx, iobase
        mov eax, u32Offset
        out dx, eax
        add dx, 4
        mov eax, u32Value
        out dx, eax
    };
}

/**
 *  shiftOutBits - Shift data bits our to the EEPROM
 *  @hw: pointer to the EEPROM object
 *  @data: data to send to the EEPROM
 *  @count: number of bits to shift out
 *
 *  We need to shift 'count' bits out to the EEPROM.  So, the value in the
 *  "data" parameter will be shifted out to the EEPROM one bit at a time.
 *  In order to do this, "data" must be broken down into bits.
 **/
void eeprom_shiftOutBits(uint16_t data, uint16_t count) {
    uint32_t wires = readReg(E1000_EECD);
    uint32_t mask;

    mask = 0x01 << (count - 1);
    wires &= ~DO;

    do {
        wires &= ~DI;

        if (data & mask)
            wires |= DI;

        writeReg(E1000_EECD, wires);

        // Raise clock
        writeReg(E1000_EECD, wires |= SK);
        // Lower clock
        writeReg(E1000_EECD, wires &= ~SK);

        mask >>= 1;
    } while (mask);

    wires &= ~DI;
    writeReg(E1000_EECD, wires);
}

/**
 *  shiftInBits - Shift data bits in from the EEPROM
 *  @param      count   number of bits to shift in
 *
 *  In order to read a register from the EEPROM, we need to shift 'count' bits
 *  in from the EEPROM.  Bits are "shifted in" by raising the clock input to
 *  the EEPROM (setting the SK bit), and then reading the value of the data out
 *  "DO" bit.  During this "shifting in" process the data in "DI" bit should
 *  always be clear.
 **/
uint16_t eeprom_shiftInBits(uint16_t count)
{
    uint32_t wires;
    uint32_t i;
    uint16_t data;

    wires = readReg(E1000_EECD);

    wires &= ~(DO | DI);
    data = 0;

    for (i = 0; i < count; i++) {
        data <<= 1;
        // Raise clock
        writeReg(E1000_EECD, wires |= SK);

        wires = readReg(E1000_EECD);

        wires &= ~DI;
        if (wires & DO)
            data |= 1;

        // Lower clock
        writeReg(E1000_EECD, wires &= ~SK);
    }

    return data;
}

/**
 *  getReady - Prepares EEPROM for read/write
 *
 *  Setups the EEPROM for reading and writing.
 **/
void eeprom_getReady()
{
    unsigned wires = readReg(E1000_EECD);
    /* Clear SK and DI */
    writeReg(E1000_EECD, wires &= ~(DI | SK));
    /* Set CS */
    writeReg(E1000_EECD, wires | CS);
}

/**
 *  stop - Terminate EEPROM command
 *
 *  Terminates the current command by inverting the EEPROM's chip select pin.
 **/
void eeprom_stop()
{
    unsigned wires = readReg(E1000_EECD);

    writeReg(E1000_EECD, wires &= ~(CS | DI));
    // Raise clock
    writeReg(E1000_EECD, wires |= SK);
    // Lower clock
    writeReg(E1000_EECD, wires &= ~SK);
}

/**
 *  readAt - Read a word at specified address
 *  @params     addr    address to read
 *
 *  Returns the value of the word specified in 'addr' parameter.
 **/
uint16_t eeprom_readAt(uint16_t addr)
{
    uint16_t value;

    eeprom_getReady();
    eeprom_shiftOutBits(READ_OPCODE, READ_OPCODE_BITS);
    eeprom_shiftOutBits(addr, READ_ADDR_BITS);

    value = eeprom_shiftInBits(DATA_BITS);
    eeprom_stop();

    return value;
}

bool eeprom_acquire()
{
    uint32_t eecd = readReg(E1000_EECD);

    eecd |= E1000_EECD_EE_REQ;
    writeReg(E1000_EECD, eecd);
    eecd = readReg(E1000_EECD);
    return eecd & E1000_EECD_EE_GNT;
}

void eeprom_release()
{
    writeReg(E1000_EECD, readReg(E1000_EECD) & ~E1000_EECD_EE_REQ);
}

/* Clean up before unloading driver. */
void nic_cleanup_e1000(void)
{
    ADAPTER     *adapter = &Adapter;

    /* Stop the adapter. Potentially we might need to do more here so that
     * other people's drivers can load.
     */
}

int nic_setup_e1000(void)
{
    ADAPTER     *adapter = &Adapter;
    E1KRAU       ra;
    int          i;

    adapter->aTd_va      = TxD;
    adapter->u32Td_pa    = getPhysAddr(adapter->aTd_va);
    adapter->aRd_va      = RxD;
    adapter->u32Rd_pa    = getPhysAddr(adapter->aRd_va);
    adapter->au8TxBuf_va = &TxBuffer;
    adapter->u32TxBuf_pa = getPhysAddr(adapter->au8TxBuf_va);
    adapter->au8RxBuf_va = &RxBuffer;
    adapter->u32RxBuf_pa = getPhysAddr(adapter->au8RxBuf_va);

    adapter->u8TdCurrent = 0;
    adapter->u8RdCurrent = 0;

    /*
     * Init Receive Address table.
     * RAL[0]/RAH[0] should always be used to store the Individual Ethernet
     * MAC address of the Ethernet controller.
     */
    ra.fields.au16Addr[0] = adapter->mac_addr[0];
    ra.fields.au16Addr[1] = adapter->mac_addr[1];
    ra.fields.au16Addr[2] = adapter->mac_addr[2];
    ra.fields.u16Ctl      = E1000_RA_CTL_AV; /* Address valid, Destination */
    writeReg(E1000_RAL, ra.au32[0]);
    writeReg(E1000_RAH, ra.au32[1]);
    for (i = 8; i < 128; i+=4)
        writeReg(E1000_RAL + i, 0);
    /* Init Multicast Table Array */
    for (i = 0; i < 128; i++)
        writeReg(E1000_MTA + i * 4, 0);
    /* Init Receive Descriptor ring */
    for (i = 0; i < NUM_RXD; ++i)
        adapter->aRd_va[i].u32BufAddrLo = adapter->u32RxBuf_pa;
        adapter->aRd_va[i].u32BufAddrHi = 0;
        *(uint16_t*)&adapter->aRd_va[i].status = 0;
    writeReg(E1000_RDBAL, adapter->u32Rd_pa);
    writeReg(E1000_RDBAH, 0);
    writeReg(E1000_RDLEN, sizeof(RxD));
    writeReg(E1000_RDH, 0);
    writeReg(E1000_RDT, 1);
    /* Init Transmit Descriptor ring */
    writeReg(E1000_TDBAL, adapter->u32Td_pa);
    writeReg(E1000_TDBAH, 0);
    writeReg(E1000_TDLEN, sizeof(TxD));
    writeReg(E1000_TDH, 0);
    writeReg(E1000_TDT, 0);
    return 0;
}

void nic_open_e1000(void)
{
    ADAPTER     *adapter = &Adapter;
    uint32_t rctl, tctl;
    adapter->adv_rdt = 0;
    /* Enable Receive operation */
    rctl = readReg(E1000_RCTL);
    rctl |= E1000_RCTL_EN | E1000_RCTL_BAM;
    writeReg(E1000_RCTL, rctl);
    /* Enable Transmit operation */
    tctl = readReg(E1000_TCTL);
    tctl |= E1000_TCTL_EN;
    writeReg(E1000_TCTL, tctl);
    /* Bring up the link */
    writeReg(E1000_CTRL, readReg(E1000_CTRL) | E1000_CTRL_SLU);
}

/* Stop the transmit/receive functionality. */
void nic_close_e1000(void)
{
    ADAPTER     *adapter = &Adapter;
    uint32_t rctl, tctl;
    /* Bring down the link */
    writeReg(E1000_CTRL, readReg(E1000_CTRL) & ~E1000_CTRL_SLU);
    /* Disable Receive operation */
    rctl = readReg(E1000_RCTL);
    rctl &= ~E1000_RCTL_EN;
    writeReg(E1000_RCTL, rctl);
    /* Disable Transmit operation */
    tctl = readReg(E1000_TCTL);
    tctl &= ~E1000_TCTL_EN;
    writeReg(E1000_TCTL, tctl);
}

/* Send out a packet composed of a number of fragments. */
void nic_send_e1000(unsigned frag_cnt, nic_frag_t FAR *frags)
{
    ADAPTER         *adapter = &Adapter;
    E1KTD FAR       *td;
    uint32_t        u32Buf_pa;
    uint16_t        u16Length;
    uint8_t FAR     *ptr;
    int             i;

    /* Copy packet data into send buffer */
    ptr = adapter->au8TxBuf_va;
    for (u16Length = i = 0; i < frag_cnt; ++i) {
        _fmemcpy(ptr, frags[i].ptr, frags[i].len);
        ptr       += frags[i].len;
        u16Length += frags[i].len;
    }

    /* Fill out transmit descriptor */
    td = adapter->aTd_va + adapter->u8TdCurrent;
    _fmemset(td, 0, sizeof(E1KTD));
    td->u32BufAddrLo = adapter->u32TxBuf_pa;
    td->u32BufAddrHi = 0;
    td->u16Length    = u16Length;
    td->cmd.fEOP     = 1;
    td->cmd.fRS      = 1;

    adapter->u8TdCurrent = (adapter->u8TdCurrent + 1) % NUM_TXD; /* Wrap around */
    duputs("\r\nnic_send: TDT="); duputh4(adapter->u8TdCurrent);
    writeReg(E1000_TDT, adapter->u8TdCurrent);
}

/* Check if a frame was received, return non-zero if so. */
int nic_have_received_e1000(void)
{
    ADAPTER         *adapter = &Adapter;
#ifdef WDS_WORKAROUND
    if (adapter->adv_rdt)
    {
        /* RDT must point past the current descriptor */
        writeReg(E1000_RDT, (adapter->u8RdCurrent + 1) % NUM_RXD);
        adapter->adv_rdt = 0;
        return 0;
    }
#endif /* WDS_WORKAROUND */
    /* Poll the state of current RX descriptor. */
    return adapter->aRd_va[adapter->u8RdCurrent].status.fDD;
}

/* Receive a frame. Return frame length and fill out pointer to buffer. */
unsigned nic_receive_e1000(uint8_t FAR * FAR *pbuf)
{
    ADAPTER         *adapter = &Adapter;
    *pbuf = adapter->au8RxBuf_va;
    duputs("\r\nnic_receive: return "); duputh4(adapter->aRd_va[adapter->u8RdCurrent].u16Length);
    return adapter->aRd_va[adapter->u8RdCurrent].u16Length;
}

/* Free up a receive buffer. */
void nic_receive_done_e1000(uint8_t FAR *buf)
{
    ADAPTER         *adapter = &Adapter;
    duputs("\r\nnic_receive_done: descriptor "); duputh1(adapter->u8RdCurrent);
    /* Mark the current RX descriptor as empty and move the pointer to the next descriptor in the ring. */
    *(uint16_t*)&adapter->aRd_va[adapter->u8RdCurrent].status = 0;
    adapter->u8RdCurrent = (adapter->u8RdCurrent + 1) % NUM_RXD;
#ifdef WDS_WORKAROUND
    /* Note that we do not move RDT yet in order to prevent skipping a packet on buffer recycle. */
    adapter->adv_rdt = 1;
#else /* !WDS_WORKAROUND */
    /* RDT must point past the current descriptor */
    writeReg(E1000_RDT, (adapter->u8RdCurrent + 1) % NUM_RXD);
#endif /* !WDS_WORKAROUND */
}

void nic_int_disable_e1000(void)
{
    ADAPTER     *adapter = &Adapter;
    duputs("\r\nnic_int_disable");
    writeReg(E1000_IMC, 0xFFFFFFFF);
}

void nic_int_enable_e1000(void)
{
    ADAPTER     *adapter = &Adapter;
    duputs("\r\nnic_int_enable");
    writeReg(E1000_IMS, E1000_ICR_RXT0);
}

void nic_int_force_e1000(void)
{
    ADAPTER     *adapter = &Adapter;
    nic_int_enable_e1000();
    duputs("\r\nnic_int_force");
    writeReg(E1000_ICS, E1000_ICR_RXT0);
}

// NB: This perhaps ought to return the currently active interrupt causes
void nic_int_clear_e1000(void)
{
    ADAPTER     *adapter = &Adapter;
    duputs("\r\nnic_int_clear");
    readReg(E1000_ICR);
}

int nic_int_check_e1000(void)
{
    ADAPTER     *adapter = &Adapter;
    uint32_t    status, saved_adr;

    duputs("\r\nnic_int_check");

    /* This function is called from the interrupt handler.
     * Save the current address because the interrupt may occur
     * when the ROM code has just written a new address value
     * but has not accessed the data.
     */
    saved_adr = readAddr();
    status = !!readReg(E1000_ICR);
    if (status)
    {
        nic_int_disable_e1000();
        /* nic_int_clear_e1000(); this is redundant */
    }
    writeAddr(saved_adr);

    return status;
}

void nic_get_info_e1000(nic_info_t FAR *info)
{
    ADAPTER     *adapter = &Adapter;

    info->iobase = adapter->iobase;
    info->irq = adapter->irq_line;
    info->rx_bufs = 1;
    info->tx_bufs = 1;
    _fmemcpy(info->perm_addr, adapter->mac_addr, DADDLEN);
    _fmemcpy(info->curr_addr, adapter->mac_addr, DADDLEN);
}

void nic_get_type_e1000(nic_type_t FAR *type)
{
    ADAPTER     *adapter = &Adapter;

    *type = adapter->nic_type;
}

/* Return a pointer to the 6-byte MAC address. */
uint8_t FAR *get_mac_ptr_e1000(void)
{
    ADAPTER     *adapter = &Adapter;

    return (uint8_t FAR *)adapter->mac_addr;
}

void nic_init_fn_pointers_e1000()
{
    pf_nic_cleanup = nic_cleanup_e1000;
    pf_nic_setup = nic_setup_e1000;
    pf_nic_open = nic_open_e1000;
    pf_nic_close = nic_close_e1000;
    pf_nic_send = nic_send_e1000;
    pf_nic_have_received = nic_have_received_e1000;
    pf_nic_receive = nic_receive_e1000;
    pf_nic_receive_done = nic_receive_done_e1000;
    pf_nic_int_check = nic_int_check_e1000;
    pf_nic_int_disable = nic_int_disable_e1000;
    pf_nic_int_enable = nic_int_enable_e1000;
    pf_nic_int_force = nic_int_force_e1000;
    pf_nic_int_clear = nic_int_clear_e1000;
    pf_nic_get_info = nic_get_info_e1000;
    pf_nic_get_type = nic_get_type_e1000;
    pf_get_mac_ptr = get_mac_ptr_e1000;
}

int nic_init_e1000(nic_type_t *nic_type, uint8_t bus, uint8_t dev, uint8_t fun, uint8_t irq)
{
    ADAPTER     *adapter = &Adapter;

    adapter->nic_type = *nic_type;
    duputs("\r\nIntel PRO/1000 ");
    switch (adapter->nic_type.did)
    {
        case E1K_DEVICE_ID_82540EM:
            duputs("MT Desktop");
            break;
        case E1K_DEVICE_ID_82543GC:
            duputs("T Server");
            break;
        case E1K_DEVICE_ID_82545EM:
            duputs("MT Server");
            break;
    }
    duputs(" detected: bus "); duputh1(nic_type->bdf>>8);
    duputs(", device: "); duputh1((nic_type->bdf>>3) & 0x1F);
    duputs(", function "); duputh1(nic_type->bdf & 7);

    /* Read IO base */
    pci_read_config_word(bus, dev, fun, 0x18, &adapter->iobase);
    adapter->iobase &= ~1;
    duputs("\r\nIO base: "); duputh4(adapter->iobase);
    adapter->irq_line = irq;
    duputs(" IRQ: "); duputh2(adapter->irq_line);

    /* Enable bus mastering */
    pci_write_config_byte(bus, dev, fun, 0x4, PCI_CMD_BUS_MASTER | PCI_CMD_MEMORY_SPACE | PCI_CMS_IO_SPACE);

    /* Read the burned-in MAC address */
    if (!eeprom_acquire())
    {
        puts("\r\nCould not acquire access to NIC's EEPROM! Aborting PXE boot...");
        return -1;
    }
    adapter->mac_addr[0] = eeprom_readAt(0);
    adapter->mac_addr[1] = eeprom_readAt(1);
    adapter->mac_addr[2] = eeprom_readAt(2);
    eeprom_release();
    duputs(" MAC address: "); duputh4(INTSWAP(adapter->mac_addr[0]));
    duputh4(INTSWAP(adapter->mac_addr[1])); duputh4(INTSWAP(adapter->mac_addr[2]));

    nic_init_fn_pointers_e1000();

    return 0;
}

