/* $Id: pcnet.h 114041 2026-04-28 12:05:18Z knut.osmundsen@oracle.com $ */
/** @file
 * PXE - PCNet Driver Header.
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

#ifndef VBOX_INCLUDED_SRC_PC_PXE_client_pcnet_pcnet_h
#define VBOX_INCLUDED_SRC_PC_PXE_client_pcnet_pcnet_h
#ifndef RT_WITHOUT_PRAGMA_ONCE
# pragma once
#endif

#include <inttypes.h>

#define AssertCompileSize(type, size)   extern int AssertA[sizeof(type) == size]

#define PACKED

#define PCNET_IOPORT_SIZE               0x20
#define PCNET_PNPMMIO_SIZE              0x20

/* Control/status registers and bits */
#define PCNET_CSR0                      0
#define PCNET_C0_ERR            0x8000  /* error summary */
#define PCNET_C0_BABL           0x4000  /* transmitter timeout error */
#define PCNET_C0_CERR           0x2000  /* collision */
#define PCNET_C0_MISS           0x1000  /* missed a packet */
#define PCNET_C0_MERR           0x0800  /* memory error */
#define PCNET_C0_RINT           0x0400  /* receiver interrupt */
#define PCNET_C0_TINT           0x0200  /* transmitter interrupt */
#define PCNET_C0_IDON           0x0100  /* initialization done */
#define PCNET_C0_INTR           0x0080  /* interrupt condition */
#define PCNET_C0_INEA           0x0040  /* interrupt enable - also spelled as IENA */
#define PCNET_C0_RXON           0x0020  /* receiver on */
#define PCNET_C0_TXON           0x0010  /* transmitter on */
#define PCNET_C0_TDMD           0x0008  /* transmit demand */
#define PCNET_C0_STOP           0x0004  /* disable all external activity */
#define PCNET_C0_STRT           0x0002  /* enable external activity */
#define PCNET_C0_INIT           0x0001  /* begin initialization */

#define PCNET_CSR1                      1
#define PCNET_CSR2                      2

#define PCNET_CSR3                      3
#define PCNET_C3_BABLM          0x4000  /* babble mask */
#define PCNET_C3_MISSM          0x1000  /* missed frame mask */
#define PCNET_C3_MERRM          0x0800  /* memory error mask */
#define PCNET_C3_RINTM          0x0400  /* receive interrupt mask */
#define PCNET_C3_TINTM          0x0200  /* transmit interrupt mask */
#define PCNET_C3_IDONM          0x0100  /* initialization done mask */
#define PCNET_C3_DXSUFLO        0x0040  /* disable tx stop on underflow */
#define PCNET_C3_LAPPEN         0x0020  /* look ahead packet processing enable */
#define PCNET_C3_DXMT2PD        0x0010  /* disable tx two part deferral */
#define PCNET_C3_EMBA           0x0008  /* enable modified backoff algorithm */
#define PCNET_C3_BSWP           0x0004  /* byte swap */
#define PCNET_C3_ACON           0x0002  /* ALE control */
#define PCNET_C3_BCON           0x0001  /* byte control */

#define PCNET_CSR4                      4
#define PCNET_C4_EN124          0x8000  /* enable CSR124 */
#define PCNET_C4_DMAPLUS        0x4000  /* always set (PCnet-PCI) */
#define PCNET_C4_TIMER          0x2000  /* enable bus activity timer */
#define PCNET_C4_TXDPOLL        0x1000  /* disable transmit polling */
#define PCNET_C4_APAD_XMT       0x0800  /* auto pad transmit */
#define PCNET_C4_ASTRP_RCV      0x0400  /* auto strip receive */
#define PCNET_C4_MFCO           0x0200  /* missed frame counter overflow */
#define PCNET_C4_MFCOM          0x0100  /* missed frame coutner overflow mask */
#define PCNET_C4_UINTCMD        0x0080  /* user interrupt command */
#define PCNET_C4_UINT           0x0040  /* user interrupt */
#define PCNET_C4_RCVCCO         0x0020  /* receive collision counter overflow */
#define PCNET_C4_RCVCCOM        0x0010  /* receive collision counter overflow mask */
#define PCNET_C4_TXSTRT         0x0008  /* transmit start status */
#define PCNET_C4_TXSTRTM        0x0004  /* transmit start mask */

#define PCNET_CSR5                      5
#define PCNET_C5_TOKINTD        0x8000  /* transmit ok interrupt disable */
#define PCNET_C5_LTINTEN        0x4000  /* last transmit interrupt enable */
#define PCNET_C5_SINT           0x0800  /* system interrupt */
#define PCNET_C5_SINTE          0x0400  /* system interrupt enable */
#define PCNET_C5_EXDINT         0x0080  /* excessive deferral interrupt */
#define PCNET_C5_EXDINTE        0x0040  /* excessive deferral interrupt enable */
#define PCNET_C5_MPPLBA         0x0020  /* magic packet physical logical broadcast accept */
#define PCNET_C5_MPINT          0x0010  /* magic packet interrupt */
#define PCNET_C5_MPINTE         0x0008  /* magic packet interrupt enable */
#define PCNET_C5_MPEN           0x0004  /* magic packet enable */
#define PCNET_C5_MPMODE         0x0002  /* magic packet mode */
#define PCNET_C5_SPND           0x0001  /* suspend */

/* CSR8-11 is LADRF */
#define PCNET_CSR8                      8
#define PCNET_CSR9                      9
#define PCNET_CSR10                     10
#define PCNET_CSR11                     11

/* CSR12-14 is PADR */
#define PCNET_CSR12                     12
#define PCNET_CSR13                     13
#define PCNET_CSR14                     14

#define PCNET_CSR15                     15
#define PCNET_C15_PROM          0x8000  /* promiscuous mode */

#define PCNET_CSR58                     58
#define PCNET_C58_SWSTYLE_ISA   0x0000  /* PCnet-ISA style */
#define PCNET_C58_SWSTYLE_ILACC 0x0001  /* ILACC style */
#define PCNET_C58_SWSTYLE_PCI   0x0002  /* PCnet-PCI II style */
#define PCNET_C58_SWSTYLE_PCI2  0x0003  /* PCnet-PCI II controller style */
#define PCNET_C58_SSIZE32       0x0100  /* 32-bit software size */
#define PCNET_C58_CSRPCNET      0x0200  /* CSR PCnet-ISA configuration  */
#define PCNET_C58_APERREN       0x0400  /* advanced parity error handling */

/* Offsets valid for 16-bit I/O resource mappings only! */
#define PCNET_RAP                       0x12
#define PCNET_RDP                       0x10

#pragma pack(1)

/** Transmit Message Descriptor, 32-bit */
typedef struct TMD32
{
    struct
    {
        uint32_t tbadr;         /**< transmit buffer address */
    } tmd0;
    struct PACKED
    {
        uint32_t bcnt:12;       /**< buffer byte count (two's complement) */
        uint32_t ones:4;        /**< must be 1111b */
        uint32_t res:7;         /**< reserved */
        uint32_t bpe:1;         /**< bus parity error */
        uint32_t enp:1;         /**< end of packet */
        uint32_t stp:1;         /**< start of packet */
        uint32_t def:1;         /**< deferred */
        uint32_t one:1;         /**< exactly one retry was needed to transmit a frame */
        uint32_t ltint:1;       /**< suppress interrupts after successful transmission */
        uint32_t nofcs:1;       /**< when set, the state of DXMTFCS is ignored and
                                     transmitter FCS generation is activated. */
        uint32_t err:1;         /**< error occurred */
        uint32_t own:1;         /**< 0=owned by guest driver, 1=owned by controller */
    } tmd1;
    struct PACKED
    {
        uint32_t trc:4;         /**< transmit retry count */
        uint32_t res:12;        /**< reserved */
        uint32_t tdr:10;        /**< time domain reflectometer (useless) */
        uint32_t rtry:1;        /**< retry error */
        uint32_t lcar:1;        /**< loss of carrier */
        uint32_t lcol:1;        /**< late collision */
        uint32_t exdef:1;       /**< excessive deferral */
        uint32_t uflo:1;        /**< underflow error */
        uint32_t buff:1;        /**< out of buffers (ENP not found) */
    } tmd2;
    struct
    {
        uint32_t res;           /**< reserved for user defined space */
    } tmd3;
} TMD32;
AssertCompileSize(TMD32, 16);

/** Transmit Message Descriptor, 16-bit */
typedef struct TMD16
{
    struct
    {
        uint16_t tbadr_lo;      /**< transmit buffer address 15:0 */
    } tmd0;
    struct PACKED
    {
        uint16_t tbadr_hi:8;    /**< transmit buffer address 23:16 */
        uint16_t enp:1;         /**< end of packet */
        uint16_t stp:1;         /**< start of packet */
        uint16_t def:1;         /**< deferred */
        uint16_t one:1;         /**< exactly one retry was needed to transmit a frame */
        uint16_t more:1;        /**< more than one retry was needed to transmit a frame */
        uint16_t nofcs:1;       /**< when set, the state of DXMTFCS is ignored and
                                     transmitter FCS generation is activated. */
        uint16_t err:1;         /**< error occurred */
        uint16_t own:1;         /**< 0=owned by guest driver, 1=owned by controller */
    } tmd1;
    struct PACKED
    {
        uint16_t bcnt:12;       /**< buffer byte count (two's complement) */
        uint16_t ones:4;        /**< must be 1111b */
    } tmd2;
    struct
    {
        uint16_t tdr:10;        /**< time domain reflectometer (useless) */
        uint16_t rtry:1;        /**< retry error */
        uint16_t lcar:1;        /**< loss of carrier */
        uint16_t lcol:1;        /**< late collision */
        uint16_t exdef:1;       /**< excessive deferral */
        uint16_t uflo:1;        /**< underflow error */
        uint16_t buff:1;        /**< out of buffers (ENP not found) */
    } tmd3;
} TMD16;
AssertCompileSize(TMD16, 8);

/** Receive Message Descriptor, 32-bit */
typedef struct RMD32
{
    struct
    {
        uint32_t rbadr;         /**< receive buffer address */
    } rmd0;
    struct PACKED
    {
        uint32_t bcnt:12;       /**< buffer byte count (two's complement) */
        uint32_t ones:4;        /**< must be 1111b */
        uint32_t res:4;         /**< reserved */
        uint32_t bam:1;         /**< broadcast address match */
        uint32_t lafm:1;        /**< logical filter address match */
        uint32_t pam:1;         /**< physical address match */
        uint32_t bpe:1;         /**< bus parity error */
        uint32_t enp:1;         /**< end of packet */
        uint32_t stp:1;         /**< start of packet */
        uint32_t buff:1;        /**< buffer error */
        uint32_t crc:1;         /**< crc error on incoming frame */
        uint32_t oflo:1;        /**< overflow error (lost all or part of incoming frame) */
        uint32_t fram:1;        /**< frame error */
        uint32_t err:1;         /**< error occurred */
        uint32_t own:1;         /**< 0=owned by guest driver, 1=owned by controller */
    } rmd1;
    struct PACKED
    {
        uint32_t mcnt:12;       /**< message byte count */
        uint32_t zeros:4;       /**< 0000b */
        uint32_t rpc:8;         /**< receive frame tag */
        uint32_t rcc:8;         /**< receive frame tag + reserved */
    } rmd2;
    struct
    {
        uint32_t res;           /**< reserved for user defined space */
    } rmd3;
} RMD32;
AssertCompileSize(RMD32, 16);

/** Receive Message Descriptor, 16-bit */
typedef struct RMD16
{
    struct
    {
        uint16_t rbadr_lo;      /**< receive buffer address 15:0 */
    } rmd0;
    struct PACKED
    {
        uint16_t rbadr_hi:8;    /**< receive buffer address 23:16 */
        uint16_t enp:1;         /**< end of packet */
        uint16_t stp:1;         /**< start of packet */
        uint16_t buff:1;        /**< buffer error */
        uint16_t crc:1;         /**< crc error on incoming frame */
        uint16_t oflo:1;        /**< overflow error (lost all or part of incoming frame) */
        uint16_t fram:1;        /**< frame error */
        uint16_t err:1;         /**< error occurred */
        uint16_t own:1;         /**< 0=owned by guest driver, 1=owned by controller */
    } rmd1;
    struct PACKED
    {
        uint16_t bcnt:12;       /**< buffer byte count (two's complement) */
        uint16_t ones:4;        /**< must be 1111b */
    } rmd2;
    struct
    {
        uint16_t mcnt:12;       /**< message byte count */
        uint16_t zeros:4;       /**< 0000b */
    } rmd3;
} RMD16;
AssertCompileSize(RMD16, 8);

/** Initialization block, 32-bit */
typedef struct PACKED INITBLK32
{
    uint16_t mode;      /**< copied into csr15 */
    uint16_t res1:4;    /**< reserved */
    uint16_t rlen:4;    /**< number of receive descriptor ring entries */
    uint16_t res2:4;    /**< reserved */
    uint16_t tlen:4;    /**< number of transmit descriptor ring entries */
    uint16_t padr1;     /**< MAC  0..15 */
    uint16_t padr2;     /**< MAC 16..31 */
    uint16_t padr3;     /**< MAC 32..47 */
    uint16_t res3;      /**< reserved */
    uint16_t ladrf1;    /**< logical address filter  0..15 */
    uint16_t ladrf2;    /**< logical address filter 16..31 */
    uint16_t ladrf3;    /**< logibal address filter 32..47 */
    uint16_t ladrf4;    /**< logical address filter 48..63 */
    uint32_t rdra;      /**< address of receive descriptor ring */
    uint32_t tdra;      /**< address of transmit descriptor ring */
} INITBLK32;
AssertCompileSize(INITBLK32, 28);

/** Initialization block, 16-bit */
typedef struct PACKED INITBLK16
{
    uint16_t mode;      /**< copied into csr15 */
    uint16_t padr1;     /**< MAC  0..15 */
    uint16_t padr2;     /**< MAC 16..31 */
    uint16_t padr3;     /**< MAC 32..47 */
    uint16_t ladrf1;    /**< logical address filter  0..15 */
    uint16_t ladrf2;    /**< logical address filter 16..31 */
    uint16_t ladrf3;    /**< logibal address filter 32..47 */
    uint16_t ladrf4;    /**< logical address filter 48..63 */
    uint16_t rdra_lo;   /**< address of receive descriptor ring 15:0*/
    uint16_t rdra_hi:8; /**< address of receive descriptor ring 23:16*/
    uint16_t res1:4;    /**< reserved */
    uint16_t rlen:4;    /**< number of receive descriptor ring entries */
    uint16_t tdra_lo;   /**< address of transmit descriptor ring 15:0 */
    uint16_t tdra_hi:8; /**< address of transmit descriptor ring 23:16 */
    uint16_t res2:4;    /**< reserved */
    uint16_t tlen:4;    /**< number of transmit descriptor ring entries */
} INITBLK16;
AssertCompileSize(INITBLK16, 24);

#pragma pack()

typedef struct {
    uint16_t        bus_dev_fnc;
    uint16_t        iobase;
    uint8_t         irq_line;
    uint16_t        mac_addr[3];    /* 6-byte MAC address */
    TMD16 FAR       *tx_current;
    RMD16 FAR       *rx_current;
    uint8_t FAR     *rx_buf_va;     /* 16-bit seg:off address of RX packet buffer */
    uint32_t        rx_buf_pa;      /* 32-bit physical address of RX packet buffer */
    uint8_t FAR     *tx_buf_va;     /* 16-bit seg:off address of TX packet buffer */
    uint32_t        tx_buf_pa;      /* 32-bit physical address of TX packet buffer */
    INITBLK16 FAR   *init_va;       /* 16-bit seg:off address of init block */
    uint32_t        init_pa;        /* 32-bit physical address of init block */
    TMD16 FAR       *tdra_va;       /* 16-bit seg:off address of Transmit Descriptor Ring */
    uint32_t        tdra_pa;        /* 32-bit physical address of Transmit Descriptor Ring */
    RMD16 FAR       *rdra_va;       /* 16-bit seg:off address of Receive Descriptor Ring */
    uint32_t        rdra_pa;        /* 32-bit physical address of Receive Descriptor Ring */
} ADAPTER;

#endif /* !VBOX_INCLUDED_SRC_PC_PXE_client_pcnet_pcnet_h */
