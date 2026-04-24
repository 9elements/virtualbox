/** $Id: DevE1000Rss.cpp 114019 2026-04-24 14:25:35Z aleksey.ilyushin@oracle.com $ */
/** @file
 * DevE1000Phy - Intel 82540EM Ethernet Controller Internal PHY Emulation.
 *
 * Implemented in accordance with the specification:
 *      PCI/PCI-X Family of Gigabit Ethernet Controllers Software Developer's
 *      Manual 82540EP/EM, 82541xx, 82544GC/EI, 82545GM/EM, 82546GB/EB, and
 *      82547xx
 *
 *      317453-002 Revision 3.5
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

#include <iprt/asm.h>
#include <iprt/cdefs.h>
#include <iprt/net.h>
#include <iprt/string.h>
#include "DevE1000Rss.h"


/* Internals */
#define E1K_RSS_KEY_SIZE 40
uint32_t e1kRssComputeHash(uint8_t *pchBytes, uint32_t cBytes, uint8_t *pchKey)
{
    uint32_t uResult = 0;
    uint64_t uKey = ((uint64_t)RT_H2N_U32(*(uint32_t*)pchKey)) << 8;

    for (uint32_t i = 0; i < cBytes; i++)
    {
        uint8_t uByte = pchBytes[i];
        uKey |= pchKey[(i + 4) % E1K_RSS_KEY_SIZE];  // Get the next byte of the key
        for (uint8_t mask = 0x80; mask; mask >>= 1)
        {
            if (uByte & mask)
                uResult ^= (uint32_t)(uKey >> 8);
            uKey <<= 1;
        }
    }
    return uResult;
}


uint32_t e1kRssPacketHashNew(uint32_t uHashType, uint8_t *pFrame, uint32_t cbFrame, uint8_t *pchKey, E1kPacketInfo *pInfo)
{
    uint8_t auBuffer[36];
    uint32_t uHashSize = 0;

    if (pFrame == NULL || pchKey == NULL || pInfo == NULL)
        return 0;

#define E1K_RSS_VALID_RANGE(a_off, a_len) ((uint32_t)(a_off) <= cbFrame && (uint32_t)(a_len) <= cbFrame - (uint32_t)(a_off))

    switch (uHashType)
    {
        case E1K_RSS_TCP_IPV4:
            if (   E1K_RSS_VALID_RANGE((uint32_t)pInfo->uL3Offset + 12u, 8u)
                && pInfo->uL4Offset != E1K_OFFSET_NOT_PRESENT
                && E1K_RSS_VALID_RANGE(pInfo->uL4Offset, 4u))
            {
                memcpy(&auBuffer[0], &pFrame[(uint32_t)pInfo->uL3Offset + 12u], 8u);
                memcpy(&auBuffer[8], &pFrame[pInfo->uL4Offset], 4u);
                uHashSize = 12u;
            }
            else
                uHashType = E1K_RSS_IPV4;
            break;

        case E1K_RSS_IPV4:
            if (E1K_RSS_VALID_RANGE((uint32_t)pInfo->uL3Offset + 12u, 8u))
            {
                memcpy(&auBuffer[0], &pFrame[(uint32_t)pInfo->uL3Offset + 12u], 8u);
                uHashSize = 8u;
            }
            break;

        case E1K_RSS_TCP_IPV6:
        {
            bool fHasHomeAddr = pInfo->uIpv6HomeAddrOffset != E1K_OFFSET_NOT_PRESENT
                             && E1K_RSS_VALID_RANGE(pInfo->uIpv6HomeAddrOffset, 16u);
            bool fHasRh2 = pInfo->uIpv6Rh2Offset != E1K_OFFSET_NOT_PRESENT
                        && E1K_RSS_VALID_RANGE(pInfo->uIpv6Rh2Offset, 16u);
            if (   E1K_RSS_VALID_RANGE((uint32_t)pInfo->uL3Offset + 8u, 32u)
                && pInfo->uL4Offset != E1K_OFFSET_NOT_PRESENT
                && E1K_RSS_VALID_RANGE(pInfo->uL4Offset, 4u))
            {
                memcpy(&auBuffer[0], &pFrame[(uint32_t)pInfo->uL3Offset + 8u], 32u);
                memcpy(&auBuffer[32], &pFrame[pInfo->uL4Offset], 4u);
                uHashSize = 36u;
            }
            else
                uHashType = (fHasHomeAddr || fHasRh2) ? E1K_RSS_IPV6EX : E1K_RSS_IPV6;
            break;
        }

        case E1K_RSS_IPV6EX:
            if (E1K_RSS_VALID_RANGE((uint32_t)pInfo->uL3Offset + 8u, 32u))
            {
                const uint8_t *pbSrc = &pFrame[(uint32_t)pInfo->uL3Offset + 8u];
                const uint8_t *pbDst = &pFrame[(uint32_t)pInfo->uL3Offset + 24u];
                if (   pInfo->uIpv6HomeAddrOffset != E1K_OFFSET_NOT_PRESENT
                    && E1K_RSS_VALID_RANGE(pInfo->uIpv6HomeAddrOffset, 16u))
                    pbSrc = &pFrame[pInfo->uIpv6HomeAddrOffset];
                if (   pInfo->uIpv6Rh2Offset != E1K_OFFSET_NOT_PRESENT
                    && E1K_RSS_VALID_RANGE(pInfo->uIpv6Rh2Offset, 16u))
                    pbDst = &pFrame[pInfo->uIpv6Rh2Offset];
                memcpy(&auBuffer[0], pbSrc, 16u);
                memcpy(&auBuffer[16], pbDst, 16u);
                uHashSize = 32u;
            }
            break;

        case E1K_RSS_IPV6:
            if (E1K_RSS_VALID_RANGE((uint32_t)pInfo->uL3Offset + 8u, 32u))
            {
                memcpy(&auBuffer[0], &pFrame[(uint32_t)pInfo->uL3Offset + 8u], 32u);
                uHashSize = 32u;
            }
            break;

        default:
            break;
    }

    if (uHashSize == 0)
    {
        if (uHashType == E1K_RSS_IPV4)
        {
            if (E1K_RSS_VALID_RANGE((uint32_t)pInfo->uL3Offset + 12u, 8u))
            {
                memcpy(&auBuffer[0], &pFrame[(uint32_t)pInfo->uL3Offset + 12u], 8u);
                uHashSize = 8u;
            }
        }
        else if (uHashType == E1K_RSS_IPV6EX)
        {
            if (E1K_RSS_VALID_RANGE((uint32_t)pInfo->uL3Offset + 8u, 32u))
            {
                const uint8_t *pbSrc = &pFrame[(uint32_t)pInfo->uL3Offset + 8u];
                const uint8_t *pbDst = &pFrame[(uint32_t)pInfo->uL3Offset + 24u];
                if (   pInfo->uIpv6HomeAddrOffset != E1K_OFFSET_NOT_PRESENT
                    && E1K_RSS_VALID_RANGE(pInfo->uIpv6HomeAddrOffset, 16u))
                    pbSrc = &pFrame[pInfo->uIpv6HomeAddrOffset];
                if (   pInfo->uIpv6Rh2Offset != E1K_OFFSET_NOT_PRESENT
                    && E1K_RSS_VALID_RANGE(pInfo->uIpv6Rh2Offset, 16u))
                    pbDst = &pFrame[pInfo->uIpv6Rh2Offset];
                memcpy(&auBuffer[0], pbSrc, 16u);
                memcpy(&auBuffer[16], pbDst, 16u);
                uHashSize = 32u;
            }
        }
        else if (uHashType == E1K_RSS_IPV6)
        {
            if (E1K_RSS_VALID_RANGE((uint32_t)pInfo->uL3Offset + 8u, 32u))
            {
                memcpy(&auBuffer[0], &pFrame[(uint32_t)pInfo->uL3Offset + 8u], 32u);
                uHashSize = 32u;
            }
        }
    }

#undef E1K_RSS_VALID_RANGE

    if (uHashSize == 0)
        return 0;
    return e1kRssComputeHash(auBuffer, uHashSize, pchKey);
}

const char *g_aszPktType[] =
{
    "Eth",
    "IPv4",
    "IPv4-TCP/UDP",
    "IPv6",
    "IPv6-TCP/UDP"
};

const char *e1kPacketTypeToString(uint8_t uPacketType)
{
    return uPacketType <= E1K_PKTTYPE_IPV6_L4 ? g_aszPktType[uPacketType] : "unknown";
}

bool e1kParseEthernetPacket(const uint8_t *pFrame, size_t uFrameLen, E1kPacketInfo *pInfo)
{
    uint16_t uEthType;
    size_t uL3Offset;
    uint16_t uTmpNet;

    if (pFrame == NULL || pInfo == NULL)
    {
        return false;
    }

    pInfo->uPacketType = E1K_PKTTYPE_ETH;
    pInfo->uL4ProtocolType = 0;
    pInfo->uL3Offset = E1K_OFFSET_NOT_PRESENT;
    pInfo->uL4Offset = E1K_OFFSET_NOT_PRESENT;
    pInfo->uIpv6HomeAddrOffset = E1K_OFFSET_NOT_PRESENT;
    pInfo->uIpv6Rh2Offset = E1K_OFFSET_NOT_PRESENT;

    if (uFrameLen < 14u)
    {
        return false;
    }

    memcpy(&uTmpNet, pFrame + 12u, sizeof(uTmpNet));
    uEthType = RT_N2H_U16(uTmpNet);
    uL3Offset = 14u;

    if (uEthType == RTNET_ETHERTYPE_VLAN)
    {
        if (uFrameLen < 18u)
        {
            return false;
        }
        memcpy(&uTmpNet, pFrame + 16u, sizeof(uTmpNet));
        uEthType = RT_N2H_U16(uTmpNet);
        uL3Offset = 18u;
    }

    pInfo->uL3Offset = (uint16_t)uL3Offset;

    if (uEthType != RTNET_ETHERTYPE_IPV4 && uEthType != RTNET_ETHERTYPE_IPV6)
    {
        return true;
    }

    if (uEthType == RTNET_ETHERTYPE_IPV4)
    {
        uint8_t uVersionIhl;
        uint8_t uVersion;
        uint8_t uIhlWords;
        size_t uIpv4Hlen;
        uint16_t uFragField;
        bool fIsFragmented;
        uint8_t uProto;
        size_t uL4Offset;

        pInfo->uPacketType = E1K_PKTTYPE_IPV4;

        if (uL3Offset + 20u > uFrameLen)
        {
            return false;
        }

        uVersionIhl = pFrame[uL3Offset];
        uVersion = (uint8_t)(uVersionIhl >> 4);
        uIhlWords = (uint8_t)(uVersionIhl & 0x0Fu);
        uIpv4Hlen = (size_t)uIhlWords * 4u;

        if (uVersion != 4u || uIpv4Hlen < 20u)
        {
            return false;
        }
        if (uL3Offset + uIpv4Hlen > uFrameLen)
        {
            return false;
        }

        memcpy(&uTmpNet, pFrame + uL3Offset + 6u, sizeof(uTmpNet));
        uFragField = RT_N2H_U16(uTmpNet);
        fIsFragmented = ((uFragField & 0x2000u) != 0u) || ((uFragField & 0x1FFFu) != 0u);
        if (fIsFragmented)
        {
            return true;
        }

        uProto = pFrame[uL3Offset + 9u];
        if (uProto == RTNETIPV4_PROT_TCP || uProto == RTNETIPV4_PROT_UDP)
        {
            uL4Offset = uL3Offset + uIpv4Hlen;
            if (uL4Offset >= uFrameLen)
            {
                return false;
            }
            pInfo->uPacketType = E1K_PKTTYPE_IPV4_L4;
            pInfo->uL4ProtocolType = uProto;
            pInfo->uL4Offset = (uint16_t)uL4Offset;
        }

        return true;
    }


    {
        uint8_t uNextHeader;
        size_t uCursor;
        bool fHasFragment;

        pInfo->uPacketType = E1K_PKTTYPE_IPV6;

        if (uL3Offset + 40u > uFrameLen)
        {
            return false;
        }
        if ((pFrame[uL3Offset] >> 4) != 6u)
        {
            return false;
        }

        uNextHeader = pFrame[uL3Offset + 6u];
        uCursor = uL3Offset + 40u;
        fHasFragment = false;

        while (uNextHeader == E1K_IPV6_NH_HOP_BY_HOP ||
               uNextHeader == E1K_IPV6_NH_ROUTING ||
               uNextHeader == E1K_IPV6_NH_FRAGMENT ||
               uNextHeader == E1K_IPV6_NH_DEST_OPTS ||
               uNextHeader == E1K_IPV6_NH_AH)
        {
            uint8_t uThisHeader = uNextHeader;
            size_t uHdrStart = uCursor;
            size_t uHdrLen = 0u;
            uint8_t uFollowingNext;

            if (uCursor + 2u > uFrameLen)
            {
                return false;
            }

            uFollowingNext = pFrame[uCursor];

            if (uThisHeader == E1K_IPV6_NH_FRAGMENT)
            {
                uHdrLen = 8u;
            }
            else if (uThisHeader == E1K_IPV6_NH_AH)
            {
                uHdrLen = (size_t)(pFrame[uCursor + 1u] + 2u) * 4u;
            }
            else
            {
                uHdrLen = ((size_t)pFrame[uCursor + 1u] + 1u) * 8u;
            }

            if (uHdrLen < 2u)
            {
                return false;
            }
            if (uCursor + uHdrLen > uFrameLen)
            {
                return false;
            }

            if (uThisHeader == E1K_IPV6_NH_FRAGMENT)
            {
                fHasFragment = true;
            }
            else if (uThisHeader == E1K_IPV6_NH_ROUTING)
            {
                if (uHdrLen < 8u)
                {
                    return false;
                }
                if (pInfo->uIpv6Rh2Offset == E1K_OFFSET_NOT_PRESENT && pFrame[uCursor + 2u] == 2u)
                {
                    if (uHdrLen >= 24u)
                        pInfo->uIpv6Rh2Offset = (uint16_t)(uHdrStart + 8u);
                }
            }
            else if (uThisHeader == E1K_IPV6_NH_DEST_OPTS)
            {
                size_t uOpt = uCursor + 2u;
                size_t uEnd = uCursor + uHdrLen;

                while (uOpt < uEnd)
                {
                    uint8_t uOptType = pFrame[uOpt];

                    if (uOptType == 0u)
                    {
                        uOpt += 1u;
                        continue;
                    }

                    if (uOpt + 2u > uEnd)
                    {
                        return false;
                    }

                    {
                        uint8_t uOptLen = pFrame[uOpt + 1u];
                        size_t uTotalOptLen = (size_t)uOptLen + 2u;

                        if (uOpt + uTotalOptLen > uEnd)
                        {
                            return false;
                        }

                        if (   uOptType == 0xC9u
                            && pInfo->uIpv6HomeAddrOffset == E1K_OFFSET_NOT_PRESENT
                            && uOptLen >= 16u)
                        {
                            pInfo->uIpv6HomeAddrOffset = (uint16_t)(uOpt + 2u);
                        }

                        uOpt += uTotalOptLen;
                    }
                }
            }

            uNextHeader = uFollowingNext;
            uCursor += uHdrLen;
        }

        if (!fHasFragment && (uNextHeader == RTNETIPV4_PROT_TCP || uNextHeader == RTNETIPV4_PROT_UDP))
        {
            if (uCursor >= uFrameLen)
            {
                return false;
            }
            pInfo->uPacketType = E1K_PKTTYPE_IPV6_L4;
            pInfo->uL4ProtocolType = uNextHeader;
            pInfo->uL4Offset = (uint16_t)uCursor;
        }

        return true;
    }
}
