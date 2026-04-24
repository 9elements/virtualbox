/* $Id: tstDevRss.cpp 114004 2026-04-24 06:45:59Z aleksey.ilyushin@oracle.com $ */
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

/*********************************************************************************************************************************
*   Global Variables                                                                                                             *
*********************************************************************************************************************************/
static int      g_cErrors = 0;

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
