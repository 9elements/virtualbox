/* $Id: pcnet.c 114041 2026-04-28 12:05:18Z knut.osmundsen@oracle.com $ */
/** @file
 * PXE - PCNet Driver.
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
#include "pcnet.h"
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

/* Functions to disable interrupts and restore previous state. */
uint16_t int_disable( void );
void int_restore( uint16_t prev );

#pragma aux int_disable =   \
    "pushf"                 \
    "pop    ax"             \
    "cli"

#pragma aux int_restore =   \
    "push   ax"             \
    "popf"

#if DEBUG
    #define duputs(a)    puts(a)
    #define duputh1(a)   puth1(a)
    #define duputh2(a)   puth2(a)
    #define duputh4(a)   puth4(a)
#else
    #define duputs(a)
    #define duputh1(a)
    #define duputh2(a)
    #define duputh4(a)
#endif

/* Driver "instance". Not likely we'd need more than one. */
static ADAPTER      Adapter;

/* The following data blocks are used for communicating with hardware. We need to know
 * their physical addresses.
 */
static INITBLK16    InitBlock;  /* Must be word aligned. */
static struct {
    RMD16        Rmd;        /* Must be 8-byte aligned. */
    TMD16        Tmd;        /* Must be 8-byte aligned. */
    uint8_t      Pad[8];     /* If TMD/RMD need aligning, this will add some slack. */
} Desc;

/// @todo This method won't work in protected mode
static uint32_t get_phys(void FAR *addr)
{
    return (((uint32_t)FP_SEG(addr)) << 4) + FP_OFF(addr);
}

static uint16_t PCnetReadCSR(ADAPTER *adapter, uint16_t csr)
{
    outpw(adapter->iobase + PCNET_RAP, csr);
    return inpw(adapter->iobase + PCNET_RDP);
}

static void PCnetWriteCSR(ADAPTER *adapter, uint16_t csr, uint16_t val)
{
    outpw(adapter->iobase + PCNET_RAP, csr);
    outpw(adapter->iobase + PCNET_RDP, val);
}

/* Clean up before unloading driver. */
void nic_cleanup_pcnet(void)
{
    ADAPTER     *adapter = &Adapter;

    /* Stop the adapter. Potentially we might need to do more here so that
     * other people's drivers can load.
     */
    PCnetWriteCSR(adapter, PCNET_CSR0, PCNET_C0_STOP);
}

int nic_setup_pcnet(void)
{
    ADAPTER     *adapter = &Adapter;

    uint16_t    csr0;
    RMD16 FAR   *rmd;
    uint32_t    buf_pa;

    /* Set up the device structure */
    adapter->init_va = &InitBlock;
    adapter->init_pa = get_phys(adapter->init_va);
    adapter->tdra_va = &Desc.Tmd;
    adapter->tdra_va = (void __far *)(((uint32_t)adapter->tdra_va + 7) & ~7UL); /* Force alignment.*/
    adapter->tdra_pa = get_phys(adapter->tdra_va);
    adapter->rdra_va = &Desc.Rmd;
    adapter->rdra_va = (void __far *)(((uint32_t)adapter->rdra_va + 7) & ~7UL); /* Force alignment. */
    adapter->rdra_pa = get_phys(adapter->rdra_va);
    adapter->tx_buf_va = &TxBuffer;
    adapter->tx_buf_pa = get_phys(adapter->tx_buf_va);
    adapter->rx_buf_va = &RxBuffer;
    adapter->rx_buf_pa = get_phys(adapter->rx_buf_va);

    adapter->tx_current = adapter->tdra_va;
    adapter->rx_current = adapter->rdra_va;

    /* Set up the init block */
    adapter->init_va->mode = 0;     /* Normal mode */
    adapter->init_va->padr1 = adapter->mac_addr[0];
    adapter->init_va->padr2 = adapter->mac_addr[1];
    adapter->init_va->padr3 = adapter->mac_addr[2];
    adapter->init_va->ladrf1 = adapter->init_va->ladrf2 =
    adapter->init_va->ladrf3 = adapter->init_va->ladrf4 = ~0;   /* Turn off filter */
    adapter->init_va->rdra_lo = (uint16_t)adapter->rdra_pa;
    adapter->init_va->rdra_hi = (uint8_t)(adapter->rdra_pa >> 16);
    adapter->init_va->rlen = 0; /* One receive descriptor */
    adapter->init_va->tdra_lo = (uint16_t)adapter->tdra_pa;
    adapter->init_va->tdra_hi = (uint8_t)(adapter->tdra_pa >> 16);
    adapter->init_va->tlen = 0; /* One transmit descriptor */

    /* Load init block into the NIC */
    PCnetWriteCSR(adapter, PCNET_CSR0, PCNET_C0_STOP);
    PCnetWriteCSR(adapter, PCNET_CSR1, (uint16_t)adapter->init_pa);
    PCnetWriteCSR(adapter, PCNET_CSR2, (uint16_t)(adapter->init_pa >> 16));
    PCnetWriteCSR(adapter, PCNET_CSR0, PCNET_C0_INIT);
    do {
        csr0 = PCnetReadCSR(adapter, PCNET_CSR0);
    } while (!(csr0 & PCNET_C0_IDON));

    /* Turn on the NIC, don't enable interrupts yet */
    PCnetWriteCSR(adapter, PCNET_CSR0, PCNET_C0_STRT);

    return 0;
}

void nic_open_pcnet(void)
{
    ADAPTER     *adapter = &Adapter;
    uint16_t    val;
    uint32_t    buf_pa;
    RMD16 FAR   *rmd;

    adapter->rx_current = adapter->rdra_va;

    /* Set up the receive ring - fill out RDTEs */
    rmd = adapter->rx_current;
    buf_pa = adapter->rx_buf_pa;
    rmd->rmd0.rbadr_lo = (uint16_t)buf_pa;
    rmd->rmd1.rbadr_hi = (uint8_t)(buf_pa >> 16);
    rmd->rmd2.bcnt = -(int16_t)sizeof(RxBuffer);
    rmd->rmd2.ones = -1;
    rmd->rmd1.own = 1;      /* Buffer is owned by the NIC now. */

    /* Start the adapter in case it's stopped */
    val = PCnetReadCSR(adapter, PCNET_CSR0);
    val &= ~PCNET_C0_STOP;
    PCnetWriteCSR(adapter, PCNET_CSR0, val | PCNET_C0_STRT);
}

/* Stop the transmit/receive functionality. */
void nic_close_pcnet(void)
{
    ADAPTER     *adapter = &Adapter;
    uint16_t    val;

    val = PCnetReadCSR(adapter, PCNET_CSR0);
    val &= ~PCNET_C0_STRT;
    PCnetWriteCSR(adapter, PCNET_CSR0, val | PCNET_C0_STOP);
}

/* Send out a packet composed of a number of fragments. */
void nic_send_pcnet(unsigned frag_cnt, nic_frag_t FAR *frags)
{
    ADAPTER         *adapter = &Adapter;
    uint32_t        buf_pa;
    uint16_t        length;
    uint8_t FAR     *buf_ptr;
    TMD16 FAR       *tmd;
    int             i;
    unsigned        wait_count = 100;
    uint16_t        flags;

    tmd = adapter->tx_current;

    // assert(tmd->tmd1.own == 0);

    /* Copy packet data into send buffer */
    buf_pa = adapter->tx_buf_pa;
    buf_ptr = adapter->tx_buf_va;
    for (length = i = 0; i < frag_cnt; ++i) {
        _fmemcpy(buf_ptr, frags[i].ptr, frags[i].len);
        buf_ptr += frags[i].len;
        length  += frags[i].len;
    }

    /* Fill out TDTE */
    tmd->tmd0.tbadr_lo = (uint16_t)buf_pa;
    tmd->tmd1.tbadr_hi = (uint8_t)(buf_pa >> 16);
    tmd->tmd1.stp = 1;
    tmd->tmd1.enp = 1;
    tmd->tmd2.bcnt = -(int16_t)length;
    tmd->tmd2.ones = -1;
    tmd->tmd1.own = 1;      /* Buffer is owned by the NIC now. */

//    puts("\r\nsend length: "); puth4(length);
    /* We need to disable interrupts because if we don't, it is possible that the interrupt
     * is raised immediately after writing CSR0 and the interrupt handler will clear TINT before
     * we've had a chance to see it.
     */
    flags = int_disable();
    /* Kick off transmit by writing Transmit Demand (TDMD) bit. */
    PCnetWriteCSR(adapter, PCNET_CSR0, PCNET_C0_TDMD | PCNET_C0_RINT | PCNET_C0_TINT | PCNET_C0_INEA);
    /* Wait for TX done */
    while (wait_count && !(PCnetReadCSR(adapter, PCNET_CSR0) & PCNET_C0_TINT))
        --wait_count;
    int_restore(flags);

#if DEBUG
    if(!wait_count && adapter->tx_current->tmd1.own)
        puts("\r\nSend timed out!");
#endif
}

/* Check if a frame was received, return non-zero if so. */
int nic_have_received_pcnet(void)
{
    ADAPTER         *adapter = &Adapter;
    RMD16 FAR       *rmd;
    uint8_t         status;

    rmd = adapter->rx_current;

    /* Check if we own the buffer, STP and ENP is set, and there is no error */
    status = ((uint8_t *)rmd)[3];
//    puts("\r\nreceive status: "); puth2(status);
    if (status == 0x03)
        return 1;
    else
        return 0;
}

/* Receive a frame. Return frame length and fill out pointer to buffer. */
unsigned nic_receive_pcnet(uint8_t FAR * FAR *pbuf)
{
    ADAPTER         *adapter = &Adapter;
    RMD16 FAR       *rmd;
    unsigned        len;

    rmd = adapter->rx_current;

    /* Assuming that nic_have_received has been called and returned non-zero,
     * ie. a frame has indeed been received.
     */

    len = rmd->rmd3.mcnt;
    *pbuf = adapter->rx_buf_va;

//    puts("\r\nreceived frame, length "); puth2(len);

    return len;
}

/* Free up a receive buffer. */
void nic_receive_done_pcnet(uint8_t FAR *buf)
{
    ADAPTER         *adapter = &Adapter;
    RMD16 FAR       *rmd;
    uint8_t FAR     *prmd;

    /* Since we know there's just one buffer, we cheat and ignore the argument. */
    rmd = adapter->rx_current;
    prmd = (uint8_t FAR *)rmd;
    prmd[3] = 0;        /* Clear all status bits */
    rmd->rmd2.bcnt = -(int16_t)sizeof(RxBuffer);
    rmd->rmd2.ones = -1;
    rmd->rmd1.own = 1;  /* Return RMD to NIC */
}

void nic_int_disable_pcnet(void)
{
    ADAPTER     *adapter = &Adapter;

    PCnetWriteCSR(adapter, PCNET_CSR0, PCnetReadCSR(adapter, PCNET_CSR0) & ~PCNET_C0_INEA);
}

void nic_int_enable_pcnet(void)
{
    ADAPTER     *adapter = &Adapter;

    PCnetWriteCSR(adapter, PCNET_CSR0, PCnetReadCSR(adapter, PCNET_CSR0) | PCNET_C0_INEA);
}

void nic_int_force_pcnet(void)
{
    ADAPTER     *adapter = &Adapter;

    /* Make sure interrupts are enabled */
    PCnetWriteCSR(adapter, PCNET_CSR0, PCnetReadCSR(adapter, PCNET_CSR0) | PCNET_C0_INEA);
    PCnetWriteCSR(adapter, PCNET_CSR4, PCNET_C4_UINTCMD);
}

// NB: This perhaps ought to return the currently active interrupt causes
void nic_int_clear_pcnet(void)
{
    ADAPTER     *adapter = &Adapter;
    uint16_t    reg;

    // Clear interrupt causes in CSR0 and CSR4
    reg = PCnetReadCSR(adapter, PCNET_CSR0);
    PCnetWriteCSR(adapter, PCNET_CSR0, reg);
    reg = PCnetReadCSR(adapter, PCNET_CSR4);
    PCnetWriteCSR(adapter, PCNET_CSR4, reg);
}

int nic_int_check_pcnet(void)
{
    ADAPTER     *adapter = &Adapter;
    UINT16      status;
    UINT16      saved_rap;

    /* This function is called from the interrupt handler.
     * Save the current RAP because the interrupt may occur
     * when the ROM code has just written a new RAP value
     * but has not accessed CSR. Otherwise this function
     * will leave 4 in the RAP, causing the interrupted code
     * to access the wrong CSR.
     */
    saved_rap = inpw(adapter->iobase + PCNET_RAP);

    status = PCnetReadCSR(adapter, PCNET_CSR0) & PCNET_C0_INTR;
    if (status)
    {
        nic_int_disable_pcnet();
        nic_int_clear_pcnet();
    }

    outpw(adapter->iobase + PCNET_RAP, saved_rap);

    return status;
}

void nic_get_info_pcnet(nic_info_t FAR *info)
{
    ADAPTER     *adapter = &Adapter;

    info->iobase = adapter->iobase;
    info->irq = adapter->irq_line;
    info->rx_bufs = 1;
    info->tx_bufs = 1;
    _fmemcpy(info->perm_addr, adapter->mac_addr, DADDLEN);
    _fmemcpy(info->curr_addr, adapter->mac_addr, DADDLEN);
}

void nic_get_type_pcnet(nic_type_t FAR *type)
{
    ADAPTER     *adapter = &Adapter;

    type->vid = PCNET_VENDOR_ID;
    type->did = PCNET_DEVICE_ID;
    type->svid = type->sdid = 0;    /* At this point, anyway */
    type->bdf = adapter->bus_dev_fnc;
    type->bcls = 2;     /* 2:0:0 is Ethernet */
    type->scls = 0;
    type->pif = 0;
    type->rev = 0;
}

/* Return a pointer to the 6-byte MAC address. */
uint8_t FAR *get_mac_ptr_pcnet(void)
{
    ADAPTER     *adapter = &Adapter;

    return (uint8_t FAR *)adapter->mac_addr;
}

void nic_init_fn_pointers_pcnet()
{
    pf_nic_cleanup = nic_cleanup_pcnet;
    pf_nic_setup = nic_setup_pcnet;
    pf_nic_open = nic_open_pcnet;
    pf_nic_close = nic_close_pcnet;
    pf_nic_send = nic_send_pcnet;
    pf_nic_have_received = nic_have_received_pcnet;
    pf_nic_receive = nic_receive_pcnet;
    pf_nic_receive_done = nic_receive_done_pcnet;
    pf_nic_int_check = nic_int_check_pcnet;
    pf_nic_int_disable = nic_int_disable_pcnet;
    pf_nic_int_enable = nic_int_enable_pcnet;
    pf_nic_int_force = nic_int_force_pcnet;
    pf_nic_int_clear = nic_int_clear_pcnet;
    pf_nic_get_info = nic_get_info_pcnet;
    pf_nic_get_type = nic_get_type_pcnet;
    pf_get_mac_ptr = get_mac_ptr_pcnet;
}

int nic_init_pcnet(nic_type_t *nic_type, uint8_t bus, uint8_t dev, uint8_t fun, uint8_t irq)
{
    ADAPTER     *adapter = &Adapter;

    adapter->bus_dev_fnc = nic_type->bdf;
    duputs("\r\nAMD PCnet-PCI II detected: bus "); duputh1(nic_type->bdf>>8);
    duputs(", device: "); duputh1((nic_type->bdf>>3) & 0x1F);
    duputs(", function "); duputh1(nic_type->bdf & 7);

    /* Read IO base */
    pci_read_config_word(bus, dev, fun, 0x10, &adapter->iobase);
    adapter->iobase &= ~1;
    duputs("\r\nIO base: "); duputh4(adapter->iobase);
    adapter->irq_line = irq;
    duputs(" IRQ: "); duputh2(adapter->irq_line);

    /* Enable bus mastering */
    pci_write_config_byte(bus, dev, fun, 0x4, PCI_CMD_BUS_MASTER | PCI_CMD_MEMORY_SPACE | PCI_CMS_IO_SPACE);

    /* Read the burned-in MAC address */
    adapter->mac_addr[0] = PCnetReadCSR(adapter, PCNET_CSR12);
    adapter->mac_addr[1] = PCnetReadCSR(adapter, PCNET_CSR13);
    adapter->mac_addr[2] = PCnetReadCSR(adapter, PCNET_CSR14);
    duputs(" MAC address: "); duputh4(INTSWAP(adapter->mac_addr[0]));
    duputh4(INTSWAP(adapter->mac_addr[1])); duputh4(INTSWAP(adapter->mac_addr[2]));

    nic_init_fn_pointers_pcnet();

    return 0;
}

