/** $Id: DevE1000Rss.h 114003 2026-04-24 06:30:09Z aleksey.ilyushin@oracle.com $ */
/** @file
 * DevE1000Rss - Intel 82547L Ethernet Controller RSS, Header.
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

#ifndef VBOX_INCLUDED_SRC_Network_DevE1000Rss_h
#define VBOX_INCLUDED_SRC_Network_DevE1000Rss_h
#ifndef RT_WITHOUT_PRAGMA_ONCE
# pragma once
#endif

#define E1K_HASH_TCP_IPV4     0x0001  // MRQC_RSS_TCP_IPV4
#define E1K_HASH_IPV4         0x0002  // MRQC_RSS_IPV4
#define E1K_HASH_TCP_IPV6     0x0004  // MRQC_RSS_TCP_IPV6
#define E1K_HASH_IPV6EX       0x0008  // MRQC_RSS_IPV6EX
#define E1K_HASH_IPV6         0x0010  // MRQC_RSS_IPV6

enum
{
    E1K_RSS_NONE     = 0,
    E1K_RSS_TCP_IPV4 = 1,
    E1K_RSS_IPV4     = 2,
    E1K_RSS_TCP_IPV6 = 3,
    E1K_RSS_IPV6EX   = 4,
    E1K_RSS_IPV6     = 5
};

uint32_t e1kRssComputeHash(uint8_t *pchBytes, uint32_t cBytes, uint8_t *pchKey);
uint32_t e1kRssComputeHash__(uint8_t *pchBytes, uint32_t cBytes, uint8_t *pchKey);
uint32_t e1kRssPacketHash(uint32_t uHashType, uint8_t *pchPacket, uint32_t cbPacket, uint8_t *pchKey);

typedef struct E1kPacketInfo_st
{
    uint8_t  uPacketType;
    uint8_t  uL4ProtocolType;
    uint16_t uL3Offset;
    uint16_t uL4Offset;
    uint16_t uIpv6HomeAddrOffset;
    uint16_t uIpv6Rh2Offset;
} E1kPacketInfo;

uint32_t e1kRssPacketHashNew(uint32_t uHashType, uint8_t *pFrame, uint32_t cbFrame, uint8_t *pchKey, E1kPacketInfo *pInfo);
bool e1kParseEthernetPacket(const uint8_t *pFrame, size_t uFrameLen, E1kPacketInfo *pInfo);
const char *e1kPacketTypeToString(uint8_t uPacketType);
DECLINLINE(const char *)e1kL4PType2Str(uint8_t uL4ProtocolType)
{ return uL4ProtocolType == RTNETIPV4_PROT_TCP ? "TCP" : (uL4ProtocolType == RTNETIPV4_PROT_UDP ? "UDP" : "Unknown"); }

enum
{
    E1K_PKTTYPE_ETH = 0,
    E1K_PKTTYPE_IPV4 = 1,
    E1K_PKTTYPE_IPV4_L4 = 2,
    E1K_PKTTYPE_IPV6 = 3,
    E1K_PKTTYPE_IPV6_L4 = 4
};

#define E1K_IPV6_NH_HOP_BY_HOP  0
#define E1K_IPV6_NH_ROUTING     43
#define E1K_IPV6_NH_FRAGMENT    44
#define E1K_IPV6_NH_AH          51
#define E1K_IPV6_NH_DEST_OPTS   60

#define E1K_OFFSET_NOT_PRESENT  0xFFFFu

#endif /* !VBOX_INCLUDED_SRC_Network_DevE1000Rss_h */

