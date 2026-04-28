/* $Id: e1000.h 114041 2026-04-28 12:05:18Z knut.osmundsen@oracle.com $ */
/** @file
 * PXE - E1000 Driver Header.
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

#ifndef VBOX_INCLUDED_SRC_PC_PXE_client_pcnet_e1000_h
#define VBOX_INCLUDED_SRC_PC_PXE_client_pcnet_e1000_h
#ifndef RT_WITHOUT_PRAGMA_ONCE
# pragma once
#endif

#include <inttypes.h>

#define AssertCompileSize(type, size)   extern int AssertA[sizeof(type) == size]

#define PACKED

#define E1000_IOPORT_SIZE               0x20
#define E1000_PNPMMIO_SIZE              0x20

#define E1000_CTRL                      0x00000
#define E1000_EECD                      0x00010

#define E1000_ICR                       0x000C0
#define E1000_ICS                       0x000C8
#define E1000_IMS                       0x000D0
#define E1000_IMC                       0x000D8

#define E1000_RCTL                      0x00100

#define E1000_TCTL                      0x00400

#define E1000_RDBAL                     0x02800
#define E1000_RDBAH                     0x02804
#define E1000_RDLEN                     0x02808
#define E1000_RDH                       0x02810
#define E1000_RDT                       0x02818

#define E1000_TDBAL                     0x03800
#define E1000_TDBAH                     0x03804
#define E1000_TDLEN                     0x03808
#define E1000_TDH                       0x03810
#define E1000_TDT                       0x03818

#define E1000_RAL                       0x05400
#define E1000_RAH                       0x05404
#define E1000_MTA                       0x05200

#define E1000_CTRL_SLU                  0x00000040

#define E1000_EECD_EE_REQ               0x00000040
#define E1000_EECD_EE_GNT               0x00000080

#define E1000_TCTL_EN                   0x00000002
#define E1000_TCTL_PSP                  0x00000008

#define E1000_ICR_TXDW                  0x00000001
#define E1000_ICR_TXQE                  0x00000002
#define E1000_ICR_LSC                   0x00000004
#define E1000_ICR_RXDMT0                0x00000010
#define E1000_ICR_RXT0                  0x00000080
#define E1000_ICR_TXD_LOW               0x00008000

#define E1000_RCTL_EN                   0x00000002
#define E1000_RCTL_UPE                  0x00000008
#define E1000_RCTL_MPE                  0x00000010
#define E1000_RCTL_LPE                  0x00000020
#define E1000_RCTL_LBM_MASK             0x000000C0
#define E1000_RCTL_LBM_SHIFT            6
#define E1000_RCTL_RDMTS_MASK           0x00000300
#define E1000_RCTL_RDMTS_SHIFT          8
#define E1000_RCTL_LBM_TCVR             3
#define E1000_RCTL_MO_MASK              0x00003000
#define E1000_RCTL_MO_SHIFT             12
#define E1000_RCTL_BAM                  0x00008000
#define E1000_RCTL_BSIZE_MASK           0x00030000
#define E1000_RCTL_BSIZE_SHIFT          16
#define E1000_RCTL_VFE                  0x00040000
#define E1000_RCTL_BSEX                 0x02000000
#define E1000_RCTL_SECRC                0x04000000

#define E1000_RA_CTL_AS                 0x0003
#define E1000_RA_CTL_AV                 0x8000

enum EeepromWires
{
    SK=1,
    CS=2,
    DI=4,
    DO=8
};

enum OpCodes
{
    READ_OPCODE  = 0x6,
    WRITE_OPCODE = 0x5,
    ERASE_OPCODE = 0x7,
    EWDS_OPCODE  = 0x10, // erase/write disable
    WRAL_OPCODE  = 0x11, // write all
    ERAL_OPCODE  = 0x12, // erase all
    EWEN_OPCODE  = 0x13  // erase/write enable
};

enum BitWidths
{
    READ_OPCODE_BITS  =  3,
    WRITE_OPCODE_BITS =  3,
    ERASE_OPCODE_BITS =  3,
    EWDS_OPCODE_BITS  =  5,
    WRAL_OPCODE_BITS  =  5,
    ERAL_OPCODE_BITS  =  5,
    EWEN_OPCODE_BITS  =  5,
    READ_ADDR_BITS    =  6,
    WRITE_ADDR_BITS   =  6,
    ERASE_ADDR_BITS   =  6,
    EWDS_ADDR_BITS    =  4,
    WRAL_ADDR_BITS    =  4,
    ERAL_ADDR_BITS    =  4,
    EWEN_ADDR_BITS    =  4,
    DATA_BITS         = 16
};

#pragma pack(1)

#if defined(__386__)
qwe
#endif

#pragma pack()

#define E1K_CHIP_82540EM 0
#define E1K_CHIP_82543GC 1
#define E1K_CHIP_82545EM 2

struct E1kTxD
{
    uint32_t u32BufAddrLo;                     /**< Address of data buffer */
    uint32_t u32BufAddrHi;                     /**< Address of data buffer */
    uint16_t u16Length;
    struct TDCmd_st
    {
        unsigned u8CSO     : 8;
        /* CMD field       : 8 */
        unsigned fEOP      : 1;
        unsigned fIFCS     : 1;
        unsigned fIC       : 1;
        unsigned fRS       : 1;
        unsigned fRSV      : 1;
        unsigned fDEXT     : 1;
        unsigned fVLE      : 1;
        unsigned fIDE      : 1;
    } cmd;
    struct TDSta_st
    {
        /* STA field */
        unsigned fDD       : 1;
        unsigned fEC       : 1;
        unsigned fLC       : 1;
        unsigned fTURSV    : 1;
        /* RSV field */
        unsigned u4RSV     : 4;
        /* CSS field */
        unsigned u8CSS     : 8;
    } status;
    /* Special field*/
    struct TDSpe_st
    {
        unsigned u12VLAN   : 12;
        unsigned fCFI      : 1;
        unsigned u3PRI     : 3;
    } special;
};
typedef struct E1kTxD E1KTD;
AssertCompileSize(E1KTD, 16);

struct E1kRxD
{
    uint32_t u32BufAddrLo;                      /**< Address of data buffer */
    uint32_t u32BufAddrHi;                      /**< Address of data buffer */
    uint16_t u16Length;                       /**< Length of data in buffer */
    uint16_t u16Checksum;                              /**< Packet checksum */
    struct E1kRxDStatus
    {
        /* Status field */
        unsigned fDD     : 1;
        unsigned fEOP    : 1;
        unsigned fIXSM   : 1;
        unsigned fVP     : 1;
        unsigned         : 1;
        unsigned fTCPCS  : 1;
        unsigned fIPCS   : 1;
        unsigned fPIF    : 1;
        /* Errors field */
        unsigned fCE     : 1;
        unsigned         : 4;
        unsigned fTCPE   : 1;
        unsigned fIPE    : 1;
        unsigned fRXE    : 1;
    } status;
    struct E1kRxDSpecial
    {
        /* Special field */
        unsigned u12VLAN : 12;
        unsigned fCFI    : 1;
        unsigned u3PRI   : 3;
    } special;
};
typedef struct E1kRxD E1KRD;
AssertCompileSize(E1KRD, 16);

struct E1kRxAddr
{
    uint16_t au16Addr[3];
    uint16_t u16Ctl;
};
typedef struct E1kRxAddr E1KRA;
AssertCompileSize(E1KRA, 8);

union E1kRAUnion
{
    uint32_t au32[2];
    E1KRA    fields;
};
typedef union E1kRAUnion E1KRAU;
AssertCompileSize(E1KRAU, 8);

typedef struct
{
    nic_type_t      nic_type;
    uint32_t        mmiobase;
    uint16_t        iobase;
    uint8_t         irq_line;
    uint8_t         adv_rdt;
    uint16_t        mac_addr[3];    /* 6-byte MAC address */
    uint8_t         u8TdCurrent;
    uint8_t         u8RdCurrent;
    uint8_t FAR     *au8RxBuf_va;     /* 16-bit seg:off address of RX packet buffer */
    uint32_t        u32RxBuf_pa;      /* 32-bit physical address of RX packet buffer */
    uint8_t FAR     *au8TxBuf_va;     /* 16-bit seg:off address of TX packet buffer */
    uint32_t        u32TxBuf_pa;      /* 32-bit physical address of TX packet buffer */
    E1KTD FAR       *aTd_va;          /* 16-bit seg:off address of Transmit Descriptor Ring */
    uint32_t        u32Td_pa;         /* 32-bit physical address of Transmit Descriptor Ring */
    E1KRD FAR       *aRd_va;          /* 16-bit seg:off address of Receive Descriptor Ring */
    uint32_t        u32Rd_pa;         /* 32-bit physical address of Receive Descriptor Ring */
} ADAPTER;

#endif /* !VBOX_INCLUDED_SRC_PC_PXE_client_pcnet_e1000_h */
