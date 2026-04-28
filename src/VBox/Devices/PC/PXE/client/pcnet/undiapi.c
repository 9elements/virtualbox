/* $Id: undiapi.c 114041 2026-04-28 12:05:18Z knut.osmundsen@oracle.com $ */
/** @file
 * PXE - UNDI API Implementation.
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

#include "undi_api.h"
#include "lsa_io.h"
#include "lsa_mem.h"
#include "nic_api.h"
#include "net.h"

#include "pcnet/pcnet.h"

#define UNDIAPI     __cdecl

/* MAC type name we report to NDIS */
#define UNDI_NDIS_TYPE      "DIX+802.3"

extern  uint16_t    undi_state;
#pragma aux undi_state "*";

#if DEBUG
    #define dputs(a)    puts(a)
    #define dputh2(a)   puth2(a)
    #define dputh4(a)   puth4(a)
#else
    #define dputs(a)
    #define dputh2(a)
    #define dputh4(a)
#endif

/** @todo Consider moving the tail code into functions that can be shared.
 *        Should be smaller in debug builds if not also release builds. */
#define CHECK_OPENED(u)     if (undi_state != PXENV_UNDI_OPENED) {                      \
                                dputs("\r\ninvalid state (not opened)");                \
                                u->Status = PXENV_STATUS_UNDI_INVALID_STATE;            \
                                return PXENV_EXIT_FAILURE;                              \
                            }

#define CHECK_INITED(u)     if (undi_state != PXENV_UNDI_INITIALIZED) {                 \
                                dputs("\r\ninvalid state (not inited)");                \
                                u->Status = PXENV_STATUS_UNDI_INVALID_STATE;            \
                                return PXENV_EXIT_FAILURE;                              \
                            }

#define CHECK_STARTED(u)    if (undi_state != PXENV_UNDI_STARTED)     {                 \
                                dputs("\r\ninvalid state (not started)");               \
                                u->Status = PXENV_STATUS_UNDI_INVALID_STATE;            \
                                return PXENV_EXIT_FAILURE;                              \
                            }

#define CHECK_OPENED_INITED(u)                                                          \
        if (undi_state != PXENV_UNDI_OPENED && undi_state != PXENV_UNDI_INITIALIZED) {  \
            dputs("\r\ninvalid state (not opened or inited)");                          \
            undi->Status = PXENV_STATUS_UNDI_INVALID_STATE;                             \
            return PXENV_EXIT_FAILURE;                                                  \
        }

#define CHECK_NOT_STOPPED(u) if (undi_state == PXENV_UNDI_STOPPED) {                    \
                                dputs("\r\ninvalid state (stopped)");                   \
                                u->Status = PXENV_STATUS_UNDI_INVALID_STATE;            \
                                return PXENV_EXIT_FAILURE;                              \
                            }

/* Ethernet broadcast MAC address */
static uint8_t bcast_addr[] = { 0xff, 0xff, 0xff, 0xff, 0xff, 0xff };

/* Buffer for received packets. Needed because UNDI only returns
 * a pointer to packet data.
 */
static uint8_t undi_pktbuf[1600];

/* Initialize UNDI code/data segments for proper operation. Must be
 * called before any other UNDI APIs.
 * Real mode only.
 */
PXENV_EXIT UNDIAPI NICStartUp(t_PXENV_UNDI_STARTUP FAR *undi)
{
    /// @todo
    // set all the local/global variables with default values

    // do all the one time initializations
    // collect/store all the data that cannot be accessed while in protected mode
    // read the node address (and other initial values) from the NIC

    dputs("\r\nNICStartUp()");
    if (nic_detect() != 0)
    {
        undi->Status = PXENV_STATUS_UNDI_CANNOT_INITIALIZE_NIC;
        return PXENV_EXIT_FAILURE;
    }
    undi->Status = PXENV_STATUS_SUCCESS;
    return PXENV_EXIT_SUCCESS;
}

/* Prepare NIC driver for unloading. No other UNDI APIs may be called after
 * this one.
 * Real mode only.
 */
PXENV_EXIT UNDIAPI NICCleanUp(t_PXENV_UNDI_CLEANUP FAR *undi)
{
    dputs("\r\nNICCleanUp()");
    nic_cleanup();
    undi->Status = PXENV_STATUS_SUCCESS;
    return PXENV_EXIT_SUCCESS;
}

/* Reset and initialize NIC, but do not enable send & receive. Don't
 * enable interrupts.
 */
PXENV_EXIT UNDIAPI NICInitialize(t_PXENV_UNDI_INITIALIZE FAR *undi)
{
    dputs("\r\nNICInitialize()");
    CHECK_STARTED(undi);

    nic_setup();

    undi_state = PXENV_UNDI_INITIALIZED;
    undi->Status = PXENV_STATUS_SUCCESS;

    return PXENV_EXIT_SUCCESS;
}

/* Reset the NIC.
 */
PXENV_EXIT UNDIAPI NICResetMAC(t_PXENV_UNDI_RESET FAR *undi)
{
    /// @todo
    dputs("\r\nNICResetMAC()");
    CHECK_INITED(undi);

    undi->Status = PXENV_STATUS_SUCCESS;
    return PXENV_EXIT_SUCCESS;
}

/* Reset the NIC and leave it in a state safe for another driver to program.
 */
PXENV_EXIT UNDIAPI NICShutDown(t_PXENV_UNDI_SHUTDOWN FAR *undi)
{
    dputs("\r\nNICShutDown()");
    CHECK_INITED(undi);

    nic_cleanup();
    undi_state = PXENV_UNDI_STARTED;
    undi->Status = PXENV_STATUS_SUCCESS;
    return PXENV_EXIT_SUCCESS;
}

/* Enable the NIC for transmit & receive.
 */
PXENV_EXIT UNDIAPI NICOpenAdapter(t_PXENV_UNDI_OPEN FAR *undi)
{
    /// @todo
    dputs("\r\nNICOpenAdapter()");
    CHECK_INITED(undi);

    nic_open();
    nic_int_enable();

    undi_state = PXENV_UNDI_OPENED;
    undi->Status = PXENV_STATUS_SUCCESS;
    return PXENV_EXIT_SUCCESS;
}

/* Disable the NIC transmit & receive functions.
 */
PXENV_EXIT UNDIAPI NICCloseAdapter(t_PXENV_UNDI_CLOSE FAR *undi)
{
    dputs("\r\nNICCloseAdapter()");
    CHECK_OPENED(undi);

    nic_int_disable();
    nic_close();

    undi_state = PXENV_UNDI_INITIALIZED;
    undi->Status = PXENV_STATUS_SUCCESS;
    return PXENV_EXIT_SUCCESS;
}

/* Max number of fragments (10 should be enough; 1 + 1 + 8) */
#define MAX_FRAGS       10

/* Send out a data packet.
 * Notes: If packet type is P_UNKNOWN, the media header is already built and supplied
 * as part of the packet data. Otherwise we have to build the media header given the
 * destination address and protocol type; we know the souce address. For P_UNKNOWN
 * protocol, XmitFlag/DestAddr is ignored.
 * The immediate part of the buffer may be empty; if there is an immediate buffer, there
 * may still be TBDs following.
 */
PXENV_EXIT UNDIAPI NICTransmit(t_PXENV_UNDI_TRANSMIT FAR *undi)
{
    t_PXENV_UNDI_TBD FAR    *tbd;
    const uint8_t FAR       *data;
    const uint8_t FAR       *dest_addr;
    uint16_t                ptype;
    ETLAYER                 ethdr;
    nic_frag_t              frags[MAX_FRAGS];
    unsigned                length;
    unsigned                num_frags;
    int                     build_media_hdr;
    int                     i;

    dputs("\r\nNICTransmit()");
    CHECK_OPENED(undi);

    tbd = MK_FP(undi->TBDSegment, undi->TBDOffset);
    data = MK_FP(tbd->XmitSegment, tbd->XmitOffset);
    length = tbd->ImmedLength;

    /* For P_UNKNOWN packet type, use the provided media header;
     * otherwise build our own.
     */
    build_media_hdr = 1;
    switch (undi->Protocol) {
    case P_UNKNOWN:
        dputs(" unknown protocol");
        build_media_hdr = 0;
        break;
    case P_IP:
        ptype = EIP;
        break;
    case P_ARP:
        ptype = EARP;
        break;
    case P_RARP:
        ptype = ERARP;
        break;
    default:
        dputs(" unsupported protocol!");
        undi->Status = PXENV_STATUS_UNDI_INVALID_PARAMETER;
        return PXENV_EXIT_FAILURE;
    }
    /* Build media header if one wasn't provided */
    if (build_media_hdr) {
        /* Use either user-supplied or broadcast destination MAC address. */
        if (undi->XmitFlag == XMT_BROADCAST) {
            dest_addr = bcast_addr;
        } else {
            dest_addr = MK_FP(undi->DestAddrSegment, undi->DestAddrOffset);
        }
        _fmemcpy(ethdr.dest, dest_addr, DADDLEN);
        _fmemcpy(ethdr.source, get_mac_ptr(), DADDLEN);
        ethdr.type = INTSWAP(ptype);
    }

    /* Build the fragment descriptors */
    num_frags = 0;
    if (build_media_hdr) {
        frags[num_frags].len = sizeof(ETLAYER);
        frags[num_frags].ptr = &ethdr;
        ++num_frags;
    }
    if (length) {
        frags[num_frags].len = length;
        frags[num_frags].ptr = data;
        ++num_frags;
    }
    for (i = 0; i < tbd->DataBlkCount; ++i) {
        frags[num_frags].len = tbd->DataBlock[i].TDDataLen;
        frags[num_frags].ptr = (void FAR *)tbd->DataBlock[i].TDDataPtr;
        ++num_frags;
    }

    /* Send the packet */
    nic_send(num_frags, &frags);

    dputs(" xmit done");
    undi->Status = PXENV_STATUS_SUCCESS;
    return PXENV_EXIT_SUCCESS;
}

/* Program the NIC to receive multicast packets.
 */
PXENV_EXIT UNDIAPI NICSetMcstAddr(t_PXENV_UNDI_SET_MCAST_ADDR FAR *undi)
{
    /// @todo
    dputs("\r\nNICSetMcstAddr()");
    CHECK_OPENED(undi);

    undi->Status = PXENV_STATUS_UNSUPPORTED;
    return PXENV_EXIT_FAILURE;
}

/* Program the NIC's MAC address.
 */
PXENV_EXIT UNDIAPI NICSetStationAddress(t_PXENV_UNDI_SET_STATION_ADDR FAR *undi)
{
    /// @todo
    dputs("\r\nNICSetStationAddress()");
    CHECK_INITED(undi);

    undi->Status = PXENV_STATUS_SUCCESS;
    return PXENV_EXIT_SUCCESS;
}

/* Program the NIC's packet filter.
 */
PXENV_EXIT UNDIAPI NICSetPacketFilter(t_PXENV_UNDI_SET_PACKET_FILTER FAR *undi)
{
    /// @todo
    dputs("\r\nNICSetPacketFilter()");
    CHECK_OPENED(undi);

    undi->Status = PXENV_STATUS_SUCCESS;
    return PXENV_EXIT_SUCCESS;
}

/* Get NIC information (MAC address is the most important).
 */
PXENV_EXIT UNDIAPI NICGetInfo(t_PXENV_UNDI_GET_INFORMATION FAR *undi)
{
    nic_info_t      info;

    dputs("\r\nNICGetInfo()");
    CHECK_OPENED_INITED(undi);

    /* Note that much of the following is hardcoded for Ethernet. */
    nic_get_info(&info);
    undi->Status = PXENV_STATUS_SUCCESS;
    undi->BaseIo = info.iobase;
    undi->IntNumber = info.irq;
    undi->MaxTranUnit = 1500;
    undi->HwType = ETHER_TYPE;
    undi->HwAddrLen = DADDLEN;
    _fmemcpy(undi->CurrentNodeAddress, info.curr_addr, DADDLEN);
    _fmemcpy(undi->PermNodeAddress, info.perm_addr, DADDLEN);
    undi->ROMAddress = 0;
    undi->RxBufCt = info.rx_bufs;
    undi->TxBufCt = info.tx_bufs;
    return PXENV_EXIT_SUCCESS;
}

/* Read statistical information from the adapter.
 */
PXENV_EXIT UNDIAPI NICGetAdapterStats(t_PXENV_UNDI_GET_STATISTICS FAR *undi)
{
    /// @todo
    dputs("\r\nNICGetAdapterStats()");
    CHECK_OPENED_INITED(undi);

    undi->Status = PXENV_STATUS_UNSUPPORTED;
    return PXENV_EXIT_FAILURE;
}

/* Clear the statistical information from the adapter.
 */
PXENV_EXIT UNDIAPI NICClearStats(t_PXENV_UNDI_CLEAR_STATISTICS FAR *undi)
{
    /// @todo
    dputs("\r\nNICClearStats()");
    CHECK_OPENED_INITED(undi);

    undi->Status = PXENV_STATUS_UNSUPPORTED;
    return PXENV_EXIT_FAILURE;
}

/* Initiate run-time diagnostics. Whatever that might mean.
 */
PXENV_EXIT UNDIAPI NICInitDiags(t_PXENV_UNDI_INITIATE_DIAGS FAR *undi)
{
    /// @todo
    dputs("\r\nNICInitDiags()");
    CHECK_OPENED_INITED(undi);

    undi->Status = PXENV_STATUS_UNSUPPORTED;
    return PXENV_EXIT_FAILURE;
}

/* Force a NIC interrupt.
 */
PXENV_EXIT UNDIAPI NICForceInterrupt(t_PXENV_UNDI_GET_NIC_TYPE FAR *undi)
{
    dputs("\r\nNICForceInterrupt()");
    CHECK_OPENED_INITED(undi);

    nic_int_force();

    undi->Status = PXENV_STATUS_SUCCESS;
    return PXENV_EXIT_SUCCESS;
}

/* Convert the given IP multicast address to a hardware multicast address.
 */
PXENV_EXIT UNDIAPI NICGetMcstAddr(t_PXENV_UNDI_GET_MCAST_ADDR FAR *undi)
{
    dputs("\r\nNICGetMcstAddr()");
    CHECK_NOT_STOPPED(undi);

    /* See RFC1112, section 6.4. The three low-order bytes of multicast IP address are
     * combined with 01-00-5E, three high-order bytes of Ethernet multicast address.
     */
    undi->Status = PXENV_STATUS_SUCCESS;
    undi->MediaAddr[0] = 0x01;
    undi->MediaAddr[1] = 0x00;
    undi->MediaAddr[2] = 0x5E;
    undi->MediaAddr[3] = undi->InetAddr >> 8;   /* InetAddr is in network order! */
    undi->MediaAddr[4] = undi->InetAddr >> 16;
    undi->MediaAddr[5] = undi->InetAddr >> 24;

    return PXENV_EXIT_SUCCESS;
}

/* Get NIC hardware information. Returns information needed to locate
 * a driver for the NIC. Used by Windows RIS.
 */
PXENV_EXIT UNDIAPI NICGetNICType(t_PXENV_UNDI_GET_NIC_TYPE FAR *undi)
{
    nic_type_t      type;

    dputs("\r\nNICGetNICType()");
    CHECK_OPENED_INITED(undi);

    /* Hardcoded for PCI. Not an unreasonable assumption. */
    nic_get_type(&type);
    undi->Status = PXENV_STATUS_SUCCESS;
    undi->NicType = PCI_NIC;
    undi->pci_pnp_info.pci.Vendor_ID = type.vid;
    undi->pci_pnp_info.pci.Dev_ID = type.did;
    undi->pci_pnp_info.pci.Base_Class = type.bcls;
    undi->pci_pnp_info.pci.Sub_Class = type.scls;
    undi->pci_pnp_info.pci.Prog_Intf = type.pif;
    undi->pci_pnp_info.pci.Rev = type.rev;
    undi->pci_pnp_info.pci.BusDevFunc = type.bdf;
    undi->pci_pnp_info.pci.SubVendor_ID = type.svid;
    undi->pci_pnp_info.pci.SubDevice_ID = type.sdid;

    return PXENV_EXIT_SUCCESS;
}

/* Return information for NDIS stack. The PXE spec is amazingly vague about this.
 */
PXENV_EXIT UNDIAPI NICGetNDISInfo(t_PXENV_UNDI_GET_NDIS_INFO FAR *undi)
{
    nic_type_t      type;

    dputs("\r\nNICGetNDISInfo()");
    CHECK_OPENED_INITED(undi);

    /* We could perhaps report actual link speed... some other day.
     * The ServiceFlags contents are semi-informed guesswork.
     */
    undi->Status = PXENV_STATUS_SUCCESS;
    _fmemcpy(undi->IfaceType, UNDI_NDIS_TYPE, sizeof(UNDI_NDIS_TYPE));
    undi->LinkSpeed = 100000000;    /* 100 Mbps */
    undi->ServiceFlags = 0x0001     /* broadcast supported */
                       | 0x0002     /* multicast supported */
                       | 0x0010     /* software settable station address */
                       | 0x0400     /* reset MAC supported */
                       | 0x0800     /* open/close adapter supported */
                       | 0x1000     /* interrupt request supported */
                       ;
    undi->Reserved[0] = undi->Reserved[1] = undi->Reserved[2] = undi->Reserved[3] = 0;

    return PXENV_EXIT_SUCCESS;
}

/* Return the current UNDI engine state.
 */
PXENV_EXIT UNDIAPI NICGetState(t_PXENV_UNDI_GET_STATE FAR *undi)
{
    undi->Status = PXENV_STATUS_SUCCESS;
    undi->UNDI_State = undi_state;
    return PXENV_EXIT_SUCCESS;
}

/* Process interrupts possibly generated by the NIC.
 */
PXENV_EXIT UNDIAPI NICProcessInt(t_PXENV_UNDI_ISR FAR *undi)
{
    ETLAYER                 *media_hdr;
    unsigned                pkt_len;
    uint8_t FAR             *packet;
    static uint8_t FAR      *prev_packet;

//    dputs("\r\nNICProcessInt()");
    CHECK_OPENED_INITED(undi);

    undi->Status = PXENV_STATUS_SUCCESS;
    switch (undi->FuncFlag) {
    case PXENV_UNDI_ISR_IN_START:
        /* Check if our NIC interrupted us, if not, pass it on to the previous handler.
         * Disable the interrupts on the NIC. ACK the interrupt at NIC level if needed.
         * Note: nic_int_check() calls nic_int_disable() and nic_int_clear() if necessary.
         */
        if (nic_int_check()) {
            dputs("\r\ninterrupt detected");
            undi->FuncFlag = PXENV_UNDI_ISR_OUT_OURS;
        } else {
            undi->FuncFlag = PXENV_UNDI_USR_OUT_NOT_OURS;
        }
        break;
    case PXENV_UNDI_ISR_IN_PROCESS:
        /* Check for receive, if there is a valid packet return with its ptr
         * in param block; do not remove the received packet from the queue here,
         * will be done in rcv_cleanup.
         * Check Transmit interrupt, clean up transmit queues if needed;
         * if no more interrupts pending, call nic_int_end here.
         */
        if (!nic_have_received())
            break;
        /* else fall through */
    case PXENV_UNDI_ISR_IN_GET_NEXT:
        /* If caller consumed a packet, free the receive buffer. */
        if (prev_packet) {
            nic_receive_done(prev_packet);
            prev_packet = NULL;
        }
        /* Process next received packet, if one is available. */
        if (nic_have_received()) {
            /* if (undi->FuncFlag == PXENV_UNDI_ISR_IN_GET_NEXT) */
            /*     puts("\r\nGot packet in PXENV_UNDI_ISR_IN_GET_NEXT!"); */
            pkt_len = nic_receive(&packet);
            dputs("\r\nreceived packet");
            if (pkt_len > sizeof(undi_pktbuf)) {
                /* We're in trouble... */
                undi->FuncFlag = PXENV_UNDI_ISR_OUT_DONE;
                undi->Status   = PXENV_STATUS_UNDI_OUT_OF_RESOURCES;
                return PXENV_EXIT_FAILURE;
            }
            _fmemcpy(undi_pktbuf, packet, pkt_len);
            undi->FuncFlag = PXENV_UNDI_ISR_OUT_RECEIVE;
            undi->BufferLength = pkt_len;
            undi->FrameLength  = pkt_len;
            undi->FrameHeaderLength = sizeof(ETLAYER);
            undi->FrameOffset = (uint16_t)(void NEAR *)&undi_pktbuf;
            undi->FrameSegSel = ((uint32_t)(void FAR *)&undi_pktbuf) >> 16;

            media_hdr = (ETLAYER *)undi_pktbuf;
            switch (INTSWAP(media_hdr->type)) {
            case EIP:   undi->ProtType = P_IP;      break;
            case EARP:  undi->ProtType = P_ARP;     break;
            case ERARP: undi->ProtType = P_RARP;    break;
            default:    undi->ProtType = P_UNKNOWN;
            }
            if (_fmemcmp(media_hdr->dest, bcast_addr, sizeof(bcast_addr))) {
                undi->PktType = XMT_BROADCAST;
            } else {
                undi->PktType = XMT_DESTADDR;
            }
            prev_packet = packet;
        } else {
            undi->FuncFlag = PXENV_UNDI_ISR_OUT_DONE;
            nic_int_enable();
        }
        break;
    default:
        undi->FuncFlag = PXENV_UNDI_ISR_OUT_DONE;
        undi->Status   = PXENV_STATUS_UNDI_INVALID_PARAMETER;
        return PXENV_EXIT_FAILURE;
    }
    return PXENV_EXIT_SUCCESS;
}
