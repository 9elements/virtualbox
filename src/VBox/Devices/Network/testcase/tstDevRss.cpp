/* $Id: tstDevRss.cpp 114003 2026-04-24 06:30:09Z aleksey.ilyushin@oracle.com $ */
/** @file
 * RSS hash unit tests.
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


/*********************************************************************************************************************************
*   Header Files                                                                                                                 *
*********************************************************************************************************************************/
#include <iprt/asm.h>
#include <iprt/cdefs.h>
#include <iprt/err.h>
#include <iprt/initterm.h>
#include <iprt/net.h>
#include <iprt/stream.h>
#include <iprt/string.h>
#include "../DevE1000Rss.h"

DECLINLINE(const char *) vboxEthTypeStr(uint16_t uType)
{
    switch (uType)
    {
        case RTNET_ETHERTYPE_IPV4: return "IP";
        case RTNET_ETHERTYPE_IPV6: return "IPv6";
        case RTNET_ETHERTYPE_ARP:  return "ARP";
    }
    return "unknown";
}


DECLINLINE(void) vboxEthPacketDump(const char *pcszInstance, const char *pcszText, const uint8_t *pcPacket, uint32_t cb)
{
    AssertReturnVoid(cb >= 14);

    const uint8_t *pHdr = pcPacket;
    const uint8_t *pEnd = pcPacket + cb;
    AssertReturnVoid(pEnd - pHdr >= 14);
    uint16_t uEthType = RT_N2H_U16(*(uint16_t*)(pHdr+12));
    RTPrintf("%s: %s (%d bytes), %RTmac => %RTmac, EthType=%s(0x%x)\n", pcszInstance,
          pcszText, cb, pHdr+6, pHdr, vboxEthTypeStr(uEthType), uEthType);
    pHdr += sizeof(RTNETETHERHDR);
    if (uEthType == RTNET_ETHERTYPE_VLAN)
    {
        AssertReturnVoid(pEnd - pHdr >= 4);
        uEthType = RT_N2H_U16(*(uint16_t*)(pHdr+2));
        RTPrintf(" + VLAN: id=%d EthType=%s(0x%x)\n", RT_N2H_U16(*(uint16_t*)(pHdr)) & 0xFFF,
              vboxEthTypeStr(uEthType), uEthType);
        pHdr += 2 * sizeof(uint16_t);
    }
    uint8_t uProto = 0xFF;
    switch (uEthType)
    {
        case RTNET_ETHERTYPE_IPV6:
            AssertReturnVoid(pEnd - pHdr >= 40);
            uProto = pHdr[6];
            RTPrintf(" + IPv6: %RTnaipv6 => %RTnaipv6\n", pHdr+8, pHdr+24);
            pHdr += 40;
            break;
        case RTNET_ETHERTYPE_IPV4:
            AssertReturnVoid(pEnd - pHdr >= 20);
            uProto = pHdr[9];
            RTPrintf(" + IP: %RTnaipv4 => %RTnaipv4\n", *(uint32_t*)(pHdr+12), *(uint32_t*)(pHdr+16));
            pHdr += (pHdr[0] & 0xF) * 4;
            break;
        case RTNET_ETHERTYPE_ARP:
            AssertReturnVoid(pEnd - pHdr >= 28);
            AssertReturnVoid(RT_N2H_U16(*(uint16_t*)(pHdr+2)) == RTNET_ETHERTYPE_IPV4);
            switch (RT_N2H_U16(*(uint16_t*)(pHdr+6)))
            {
                case 1: /* ARP request */
                    RTPrintf(" + ARP-REQ: who-has %RTnaipv4 tell %RTnaipv4\n",
                          *(uint32_t*)(pHdr+24), *(uint32_t*)(pHdr+14));
                    break;
                case 2: /* ARP reply */
                    RTPrintf(" + ARP-RPL: %RTnaipv4 is-at %RTmac\n",
                          *(uint32_t*)(pHdr+14), pHdr+8);
                    break;
                default:
                    RTPrintf(" + ARP: unknown op %d\n", RT_N2H_U16(*(uint16_t*)(pHdr+6)));
                    break;
            }
            break;
        /* There is no default case as uProto is initialized with 0xFF */
    }
    while (uProto != 0xFF)
    {
        switch (uProto)
        {
            case 0:  /* IPv6 Hop-by-Hop option*/
            case 60: /* IPv6 Destination option*/
            case 43: /* IPv6 Routing option */
            case 44: /* IPv6 Fragment option */
                RTPrintf(" + IPv6 option (%d): <not implemented>\n", uProto);
                uProto = pHdr[0];
                pHdr += pHdr[1] * 8 + 8; /* Skip to the next extension/protocol */
                break;
            case 51: /* IPv6 IPsec AH */
                RTPrintf(" + IPv6 IPsec AH: <not implemented>\n");
                uProto = pHdr[0];
                pHdr += (pHdr[1] + 2) * 4; /* Skip to the next extension/protocol */
                break;
            case 50: /* IPv6 IPsec ESP */
                /* Cannot decode IPsec, fall through */
                RTPrintf(" + IPv6 IPsec ESP: <not implemented>\n");
                uProto = 0xFF;
                break;
            case 59: /* No Next Header */
                RTPrintf(" + IPv6 No Next Header\n");
                uProto = 0xFF;
                break;
            case 58: /* IPv6-ICMP */
                switch (pHdr[0])
                {
                    case 1:   RTPrintf(" + IPv6-ICMP: destination unreachable, code %d\n", pHdr[1]); break;
                    case 128: RTPrintf(" + IPv6-ICMP: echo request\n"); break;
                    case 129: RTPrintf(" + IPv6-ICMP: echo reply\n"); break;
                    default:  RTPrintf(" + IPv6-ICMP: unknown type %d, code %d\n", pHdr[0], pHdr[1]); break;
                }
                uProto = 0xFF;
                break;
            case 1: /* ICMP */
                switch (pHdr[0])
                {
                    case 0:  RTPrintf(" + ICMP: echo reply\n"); break;
                    case 8:  RTPrintf(" + ICMP: echo request\n"); break;
                    case 3:  RTPrintf(" + ICMP: destination unreachable, code %d\n", pHdr[1]); break;
                    default: RTPrintf(" + ICMP: unknown type %d, code %d\n", pHdr[0], pHdr[1]); break;
                }
                uProto = 0xFF;
                break;
            case 6: /* TCP */
                RTPrintf(" + TCP: src=%d dst=%d seq=%x ack=%x\n",
                      RT_N2H_U16(*(uint16_t*)(pHdr)), RT_N2H_U16(*(uint16_t*)(pHdr+2)),
                      RT_N2H_U32(*(uint32_t*)(pHdr+4)), RT_N2H_U32(*(uint32_t*)(pHdr+8)));
                uProto = 0xFF;
                break;
            case 17: /* UDP */
                RTPrintf(" + UDP: src=%d dst=%d\n",
                      RT_N2H_U16(*(uint16_t*)(pHdr)), RT_N2H_U16(*(uint16_t*)(pHdr+2)));
                uProto = 0xFF;
                break;
            default:
                RTPrintf(" + Unknown: proto=0x%x\n", uProto);
                uProto = 0xFF;
                break;
        }
    }
    RTPrintf("%.*Rhxd\n", cb, pcPacket);
}


/*********************************************************************************************************************************
*   Global Variables                                                                                                             *
*********************************************************************************************************************************/
static int      g_cErrors = 0;

    //uint32_t uHashType;
struct TestCaseParams
{
    const char *pcszDestAddr;
    uint16_t uDestPort;
    const char *pcszSrcAddr;
    uint16_t uSrcPort;
    uint32_t uIpOnly;
    uint32_t uIpTcp;
};

struct TestCaseParams testCaseIPv4[] = 
{
    {"161.142.100.80", 1766, "66.9.149.187",    2794, 0x323e8fc2, 0x51ccc178},
    {"65.69.140.83",   4739, "199.92.111.2",   14230, 0xd718262a, 0xc626b0ea},
    {"12.22.207.184", 38024, "24.19.198.95",   12898, 0xd2d0a5de, 0x5c2b394a},
    {"209.142.163.6",  2217, "38.27.205.30",   48228, 0x82989176, 0xafc7327f},
    {"202.188.127.2",  1303, "153.39.163.191", 44251, 0x5d1809c5, 0x10e828a2}
};

struct TestCaseParams testCaseIPv6[] = 
{
    {"3ffe:2501:200:3::1",        1766, "3ffe:2501:200:1fff::7",                2794, 0x2cc18cd5, 0x40207d3d},
    {"ff02::1",                   4739, "3ffe:501:8::260:97ff:fe40:efab",      14230, 0x0f0c461c, 0xdde51bbf},
    {"fe80::200:f8ff:fe21:67cf", 38024, "3ffe:1900:4545:3:200:f8ff:fe21:67cf", 44251, 0x4b61e985, 0x02d1feef}
};

#pragma pack(1)
struct TestPacketIPv4
{
    RTNETETHERHDR eth;
    RTNETIPV4     ip;
    RTNETTCP      tcp;
};

struct TestPacketIPv6
{
    RTNETETHERHDR eth;
    RTNETIPV6     ip;
    RTNETTCP      tcp;
};
#pragma pack()


#if 0
/**
 * Error reporting wrapper.
 *
 * @param   pErrStrm        The stream to write the error message to. Can be NULL.
 * @param   pszFormat       The message format string.
 * @param   ...             Format arguments.
 */
static void tstIntNetError(PRTSTREAM pErrStrm, const char *pszFormat, ...)
{
    if (!pErrStrm)
        pErrStrm = g_pStdOut;

    va_list va;
    va_start(va, pszFormat);
    RTStrmPrintf(pErrStrm, "tstIntNet-1: ERROR - ");
    RTStrmPrintfV(pErrStrm, pszFormat, va);
    va_end(va);

    g_cErrors++;
}
#endif


/**
 *  Entry point.
 */
extern "C" DECLEXPORT(int) TrustedMain(int argc, char **argv, char **envp)
{
    RT_NOREF(envp);
    unsigned i;
    uint32_t uHash;

    /*
     * Init the runtime and parse the arguments.
     */
    RTR3InitExe(argc, &argv, 0);

    RTPrintf("tstDevRss: TESTING...\n");

    uint8_t pchKey[40] = {
        0x6d, 0x5a, 0x56, 0xda, 0x25, 0x5b, 0x0e, 0xc2,
        0x41, 0x67, 0x25, 0x3d, 0x43, 0xa3, 0x8f, 0xb0,
        0xd0, 0xca, 0x2b, 0xcb, 0xae, 0x7b, 0x30, 0xb4,
        0x77, 0xcb, 0x2d, 0xa3, 0x80, 0x30, 0xf2, 0x0c,
        0x6a, 0x42, 0xb7, 0x3b, 0xbe, 0xac, 0x01, 0xfa
    };

    TestPacketIPv4 tstPkt4;
    RT_BZERO(&tstPkt4, sizeof(tstPkt4));
    tstPkt4.eth.EtherType = RT_H2N_U16(RTNET_ETHERTYPE_IPV4);
    tstPkt4.ip.ip_v  = 4;    // version 4
    tstPkt4.ip.ip_hl = sizeof(tstPkt4.ip) / sizeof(uint32_t);    // IP header length + one option
    tstPkt4.ip.ip_p = RTNETIPV4_PROT_TCP;

    for (i = 0; i < RT_ELEMENTS(testCaseIPv4); i++)
    {
        /*
         * Prepare a test packet.
         */
        RTNETADDRIPV4 tmpAddr;
        int rc = RTNetStrToIPv4Addr(testCaseIPv4[i].pcszDestAddr, &tmpAddr);
        if (RT_FAILURE(rc))
        {
            RTPrintf("tstDevRss: failed to convert \"%s\" to RTNETADDRIPV4\n", testCaseIPv4[i].pcszDestAddr);
            g_cErrors++;
        }
        tstPkt4.ip.ip_dst  = tmpAddr;
        tstPkt4.tcp.th_dport = RT_H2N_U16(testCaseIPv4[i].uDestPort);

        rc = RTNetStrToIPv4Addr(testCaseIPv4[i].pcszSrcAddr, &tmpAddr);
        if (RT_FAILURE(rc))
        {
            RTPrintf("tstDevRss: failed to convert \"%s\" to RTNETADDRIPV4\n", testCaseIPv4[i].pcszSrcAddr);
            g_cErrors++;
        }
        tstPkt4.ip.ip_src  = tmpAddr;
        tstPkt4.tcp.th_sport = RT_H2N_U16(testCaseIPv4[i].uSrcPort);

        RTPrintf("tstDevRss: testing hash for %RTnaipv4:%u <= %RTnaipv4:%u...\n",
                 tstPkt4.ip.ip_dst, RT_N2H_U16(tstPkt4.tcp.th_dport),
                 tstPkt4.ip.ip_src, RT_N2H_U16(tstPkt4.tcp.th_sport));

        E1kPacketInfo info;
        if (!e1kParseEthernetPacket((uint8_t*)&tstPkt4, sizeof(tstPkt4), &info))
        {
            RTPrintf("tstDevRss: failed to parse test IPv4 packet\n");
            g_cErrors++;
            continue;
        }

        // uHash = e1kRssPacketHash(E1K_HASH_IPV4, (uint8_t*)&tstPkt4.ip, sizeof(tstPkt4)-sizeof(tstPkt4.eth), pchKey);
        uHash = e1kRssPacketHashNew(E1K_RSS_IPV4, (uint8_t*)&tstPkt4, sizeof(tstPkt4), pchKey, &info);
        if (uHash != testCaseIPv4[i].uIpOnly)
        {
            RTPrintf("tstDevRss: packet hash without TCP (0x%x) is not equal to verification hash (0x%x)\n",
                     uHash, testCaseIPv4[i].uIpOnly);
            g_cErrors++;
        }
        // uHash = e1kRssPacketHash(E1K_HASH_TCP_IPV4, (uint8_t*)&tstPkt4.ip, sizeof(tstPkt4)-sizeof(tstPkt4.eth), pchKey);
        uHash = e1kRssPacketHashNew(E1K_RSS_TCP_IPV4, (uint8_t*)&tstPkt4, sizeof(tstPkt4), pchKey, &info);
        if (uHash != testCaseIPv4[i].uIpTcp)
        {
            RTPrintf("tstDevRss: packet hash with TCP (0x%x) is not equal to verification hash (0x%x)\n",
                     uHash, testCaseIPv4[i].uIpTcp);
            g_cErrors++;
        }
    }

    TestPacketIPv6 tstPkt6;
    RT_BZERO(&tstPkt6, sizeof(tstPkt6));
    tstPkt6.eth.EtherType = RT_H2N_U16(RTNET_ETHERTYPE_IPV6);
    tstPkt6.ip.ip6_vfc  = 0x60;    // version 6
    tstPkt6.ip.ip6_plen = sizeof(tstPkt6.tcp);    // TCP header length, no options
    tstPkt6.ip.ip6_nxt = RTNETIPV4_PROT_TCP;

    for (i = 0; i < RT_ELEMENTS(testCaseIPv6); i++)
    {
        /*
         * Prepare a test packet.
         */
        char *pszZone = NULL;
        RTNETADDRIPV6 tmpAddr;
        int rc = RTNetStrToIPv6Addr(testCaseIPv6[i].pcszDestAddr, &tmpAddr, &pszZone);
        if (RT_FAILURE(rc))
        {
            RTPrintf("tstDevRss: failed to convert \"%s\" to RTNETADDRIPV6\n", testCaseIPv6[i].pcszDestAddr);
            g_cErrors++;
        }
        tstPkt6.ip.ip6_dst   = tmpAddr;
        tstPkt6.tcp.th_dport = RT_H2N_U16(testCaseIPv6[i].uDestPort);

        rc = RTNetStrToIPv6Addr(testCaseIPv6[i].pcszSrcAddr, &tmpAddr, &pszZone);
        if (RT_FAILURE(rc))
        {
            RTPrintf("tstDevRss: failed to convert \"%s\" to RTNETADDRIPV6\n", testCaseIPv6[i].pcszSrcAddr);
            g_cErrors++;
        }
        tstPkt6.ip.ip6_src   = tmpAddr;
        tstPkt6.tcp.th_sport = RT_H2N_U16(testCaseIPv6[i].uSrcPort);

        RTPrintf("tstDevRss: testing hash for %RTnaipv6:%u <= %RTnaipv6:%u...\n",
                 tstPkt6.ip.ip6_dst, RT_N2H_U16(tstPkt6.tcp.th_dport),
                 tstPkt6.ip.ip6_src, RT_N2H_U16(tstPkt6.tcp.th_sport));

        E1kPacketInfo info;
        if (!e1kParseEthernetPacket((uint8_t*)&tstPkt6, sizeof(tstPkt6), &info))
        {
            RTPrintf("tstDevRss: failed to parse test IPv6 packet\n");
            g_cErrors++;
            continue;
        }
        // uHash = e1kRssPacketHash(E1K_HASH_IPV6, (uint8_t*)&tstPkt6.ip, sizeof(tstPkt6)-sizeof(tstPkt6.eth), pchKey);
        uHash = e1kRssPacketHashNew(E1K_RSS_IPV6, (uint8_t*)&tstPkt6, sizeof(tstPkt6), pchKey, &info);
        if (uHash != testCaseIPv6[i].uIpOnly)
        {
            RTPrintf("tstDevRss: packet hash without TCP (0x%x) is not equal to verification hash (0x%x)\n",
                     uHash, testCaseIPv6[i].uIpOnly);
            g_cErrors++;
        }
        // uHash = e1kRssPacketHash(E1K_HASH_TCP_IPV6, (uint8_t*)&tstPkt6.ip, sizeof(tstPkt6)-sizeof(tstPkt6.eth), pchKey);
        uHash = e1kRssPacketHashNew(E1K_RSS_TCP_IPV6, (uint8_t*)&tstPkt6, sizeof(tstPkt6), pchKey, &info);
        if (uHash != testCaseIPv6[i].uIpTcp)
        {
            RTPrintf("tstDevRss: packet hash with TCP (0x%x) is not equal to verification hash (0x%x)\n",
                     uHash, testCaseIPv6[i].uIpTcp);
            g_cErrors++;
        }
    }

    /*
     * Summary.
     */
    if (!g_cErrors)
        RTPrintf("tstDevRss: SUCCESS\n");
    else
        RTPrintf("tstDevRss: FAILURE - %d errors\n", g_cErrors);

    return !!g_cErrors;
}


#if !defined(VBOX_WITH_HARDENING) || !defined(RT_OS_WINDOWS)
/**
 * Main entry point.
 */
int main(int argc, char **argv, char **envp)
{
    return TrustedMain(argc, argv, envp);
}
#endif
