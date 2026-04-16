/* $Id: tstRecording.cpp 113911 2026-04-16 15:19:16Z andreas.loeffler@oracle.com $ */
/** @file
 * Recording testcases.
 */

/*
 * Copyright (C) 2024-2026 Oracle and/or its affiliates.
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
#include <iprt/test.h>
#include <iprt/rand.h>
#include <iprt/dir.h>
#include <iprt/file.h>
#include <iprt/formats/bmp.h>
#include <iprt/log.h>
#include <iprt/message.h>

#include <VBox/err.h>
#include <VBox/log.h>

#include "RecordingInternals.h"
#include "RecordingRender.h"
#include "RecordingUtils.h"
#include "WebMWriter.h"

#include <string.h>
#include <vector>

/** The release logger. */
static PRTLOGGER    g_pRelLogger;

#ifdef TESTCASE
int RecordingRenderSWFrameResizeCropCenter(RECORDINGVIDEOFRAME const *pDstFrame,
                                           RECORDINGVIDEOFRAME const *pSrcFrame,
                                           PRTRECT pDstRect, PRTRECT pSrcRect);
#endif


static void tstRecRenderCropCenter(RTTEST hTest)
{
    RTTestSub(hTest, "Renderer: crop/center geometry");

#ifdef TESTCASE
    RECORDINGVIDEOFRAME SrcFrame;
    RECORDINGVIDEOFRAME DstFrame;
    RT_ZERO(SrcFrame);
    RT_ZERO(DstFrame);

# define TEST_CROP_CENTER(aSrcW, aSrcH, aDstW, aDstH, \
                          aExpSrcL, aExpSrcT, aExpSrcR, aExpSrcB, \
                          aExpDstL, aExpDstT, aExpDstR, aExpDstB, aExpRc) \
    do { \
        SrcFrame.Info.uWidth  = (aSrcW); \
        SrcFrame.Info.uHeight = (aSrcH); \
        DstFrame.Info.uWidth  = (aDstW); \
        DstFrame.Info.uHeight = (aDstH); \
        RTRECT SrcRect; \
        RTRECT DstRect; \
        int const rc2 = RecordingRenderSWFrameResizeCropCenter(&DstFrame, &SrcFrame, &DstRect, &SrcRect); \
        RTTEST_CHECK_RC(hTest, rc2, (aExpRc)); \
        RTTEST_CHECK_MSG(hTest, SrcRect.xLeft   == (aExpSrcL), (hTest, "SrcRect.xLeft: expected %RI32 got %RI32\n", (int32_t)(aExpSrcL), SrcRect.xLeft)); \
        RTTEST_CHECK_MSG(hTest, SrcRect.yTop    == (aExpSrcT), (hTest, "SrcRect.yTop: expected %RI32 got %RI32\n", (int32_t)(aExpSrcT), SrcRect.yTop)); \
        RTTEST_CHECK_MSG(hTest, SrcRect.xRight  == (aExpSrcR), (hTest, "SrcRect.xRight: expected %RI32 got %RI32\n", (int32_t)(aExpSrcR), SrcRect.xRight)); \
        RTTEST_CHECK_MSG(hTest, SrcRect.yBottom == (aExpSrcB), (hTest, "SrcRect.yBottom: expected %RI32 got %RI32\n", (int32_t)(aExpSrcB), SrcRect.yBottom)); \
        RTTEST_CHECK_MSG(hTest, DstRect.xLeft   == (aExpDstL), (hTest, "DstRect.xLeft: expected %RI32 got %RI32\n", (int32_t)(aExpDstL), DstRect.xLeft)); \
        RTTEST_CHECK_MSG(hTest, DstRect.yTop    == (aExpDstT), (hTest, "DstRect.yTop: expected %RI32 got %RI32\n", (int32_t)(aExpDstT), DstRect.yTop)); \
        RTTEST_CHECK_MSG(hTest, DstRect.xRight  == (aExpDstR), (hTest, "DstRect.xRight: expected %RI32 got %RI32\n", (int32_t)(aExpDstR), DstRect.xRight)); \
        RTTEST_CHECK_MSG(hTest, DstRect.yBottom == (aExpDstB), (hTest, "DstRect.yBottom: expected %RI32 got %RI32\n", (int32_t)(aExpDstB), DstRect.yBottom)); \
    } while (0)

    /* Same size -> full-frame copy at origin. */
    TEST_CROP_CENTER(1024, 768, 1024, 768,
                     0, 0, 1024, 768,
                     0, 0, 1024, 768, VINF_SUCCESS);

    /* Source larger than destination -> centered crop source. */
    TEST_CROP_CENTER(2048, 1536, 1024, 768,
                     512, 384, 1536, 1152,
                     0, 0, 1024, 768, VINF_SUCCESS);

    /* Source smaller than destination -> centered source in destination. */
    TEST_CROP_CENTER(1024, 768, 2048, 1536,
                     0, 0, 1024, 768,
                     512, 384, 1536, 1152, VINF_SUCCESS);

    /* Mixed axes: crop horizontally, center vertically. */
    TEST_CROP_CENTER(1200, 600, 800, 800,
                     200, 0, 1000, 600,
                     0, 100, 800, 700, VINF_SUCCESS);

    /* Mixed axes: center horizontally, crop vertically. */
    TEST_CROP_CENTER(800, 800, 1200, 600,
                     0, 100, 800, 700,
                     200, 0, 1000, 600, VINF_SUCCESS);

    /* Empty source -> nothing to encode. */
    TEST_CROP_CENTER(0, 768, 1200, 600,
                     0, 0, 0, 0,
                     0, 0, 0, 0, VWRN_RECORDING_ENCODING_SKIPPED);

# undef TEST_CROP_CENTER
#else
    RT_NOREF(hTest);
#endif
}

static void tstRecCircBufSingleUse(RTTEST hTest)
{
    RTTestSub(hTest, "RecCircBuf: Single use");

    RECORDINGCIRCBUF Buf;
    RTTESTI_CHECK_RC(RecordingCircBufCreate(&Buf, 64), VINF_SUCCESS);

    uint32_t id = 0;
    RTTESTI_CHECK_RC(RecordingCircBufAddReader(&Buf, &id), VINF_SUCCESS);

    static const uint8_t s_abMsg[] = { 'h','e','l','l','o',0 };

    void  *pvW = NULL;
    size_t cbW = 0;
    RTTESTI_CHECK_RC(RecordingCircBufAcquireWrite(&Buf, sizeof(s_abMsg), &pvW, &cbW), VINF_SUCCESS);
    RTTESTI_CHECK(cbW >= sizeof(s_abMsg));
    memcpy(pvW, s_abMsg, sizeof(s_abMsg));
    RTTESTI_CHECK_RC(RecordingCircBufReleaseWrite(&Buf, sizeof(s_abMsg)), VINF_SUCCESS);

    const void *pvR = NULL;
    size_t cbR = 0;
    RTTESTI_CHECK_RC(RecordingCircBufAcquireRead(&Buf, id, sizeof(s_abMsg), &pvR, &cbR), VINF_SUCCESS);
    RTTESTI_CHECK(cbR >= sizeof(s_abMsg));
    RTTESTI_CHECK(memcmp(pvR, s_abMsg, sizeof(s_abMsg)) == 0);
    RTTESTI_CHECK_RC(RecordingCircBufReleaseRead(&Buf, id, sizeof(s_abMsg)), VINF_SUCCESS);

    RecordingCircBufDestroy(&Buf);
}

static void tstRecCircBufUnderflow(RTTEST hTest)
{
    RTTestSub(hTest, "RecCircBuf: Underflow (no data)");

    RECORDINGCIRCBUF Buf;
    RTTESTI_CHECK_RC(RecordingCircBufCreate(&Buf, 32), VINF_SUCCESS);

    uint32_t id = 0;
    RTTESTI_CHECK_RC(RecordingCircBufAddReader(&Buf, &id), VINF_SUCCESS);

    const void *pvR = (const void *)(uintptr_t)1;
    size_t cbR = 123;
    int rc = RecordingCircBufAcquireRead(&Buf, id, 8, &pvR, &cbR);
    RTTESTI_CHECK_RC(rc, VERR_TRY_AGAIN);
    RTTESTI_CHECK(pvR == NULL);
    RTTESTI_CHECK(cbR == 0);

    RecordingCircBufDestroy(&Buf);
}

static void tstRecCircBufMultiFanoutAndReclaim(RTTEST hTest)
{
    RTTestSub(hTest, "RecCircBuf: Multi reader (fanout + reclaim)");

    RECORDINGCIRCBUF Buf;
    RTTESTI_CHECK_RC(RecordingCircBufCreate(&Buf, 64), VINF_SUCCESS);

    uint32_t idA = 0, idB = 0;
    RTTESTI_CHECK_RC(RecordingCircBufAddReader(&Buf, &idA), VINF_SUCCESS);
    RTTESTI_CHECK_RC(RecordingCircBufAddReader(&Buf, &idB), VINF_SUCCESS);
    RTTESTI_CHECK(idA != idB);

    uint8_t abW[20];
    for (unsigned i = 0; i < sizeof(abW); i++) abW[i] = (uint8_t)i;

    void  *pvW = NULL;
    size_t cbW = 0;
    RTTESTI_CHECK_RC(RecordingCircBufAcquireWrite(&Buf, sizeof(abW), &pvW, &cbW), VINF_SUCCESS);
    RTTESTI_CHECK(cbW >= sizeof(abW));
    memcpy(pvW, abW, sizeof(abW));
    RTTESTI_CHECK_RC(RecordingCircBufReleaseWrite(&Buf, sizeof(abW)), VINF_SUCCESS);

    /* A reads all. */
    const void *pvR = NULL;
    size_t cbR = 0;
    RTTESTI_CHECK_RC(RecordingCircBufAcquireRead(&Buf, idA, sizeof(abW), &pvR, &cbR), VINF_SUCCESS);
    RTTESTI_CHECK(cbR >= sizeof(abW));
    RTTESTI_CHECK(memcmp(pvR, abW, sizeof(abW)) == 0);
    RTTESTI_CHECK_RC(RecordingCircBufReleaseRead(&Buf, idA, sizeof(abW)), VINF_SUCCESS);

    /* B reads (up to) multiple chunks (handles wrap-boundary limiting). */
    uint8_t abB[20];
    size_t cbDone = 0;
    while (cbDone < sizeof(abB))
    {
        RTTESTI_CHECK_RC(RecordingCircBufAcquireRead(&Buf, idB, sizeof(abB) - cbDone, &pvR, &cbR), VINF_SUCCESS);
        RTTESTI_CHECK(cbR > 0);

        size_t cbTake = cbR;
        if (cbTake > sizeof(abB) - cbDone)
            cbTake = sizeof(abB) - cbDone;

        memcpy(&abB[cbDone], pvR, cbTake);
        RTTESTI_CHECK_RC(RecordingCircBufReleaseRead(&Buf, idB, cbTake), VINF_SUCCESS);
        cbDone += cbTake;
    }
    RTTESTI_CHECK(memcmp(abB, abW, sizeof(abW)) == 0);

    /* Underflow for both. */
    int rc = RecordingCircBufAcquireRead(&Buf, idA, 1, &pvR, &cbR);
    RTTESTI_CHECK_RC(rc, VERR_TRY_AGAIN);

    rc = RecordingCircBufAcquireRead(&Buf, idB, 1, &pvR, &cbR);
    RTTESTI_CHECK_RC(rc, VERR_TRY_AGAIN);

    RecordingCircBufDestroy(&Buf);
}

static void tstRecCircBufOverflowSlowReader(RTTEST hTest)
{
    RTTestSub(hTest, "RecCircBuf: Overflow (slow reader prevents reclaim)");

    RECORDINGCIRCBUF Buf;
    RTTESTI_CHECK_RC(RecordingCircBufCreate(&Buf, 8), VINF_SUCCESS);

    uint32_t idFast = 0, idSlow = 0;
    RTTESTI_CHECK_RC(RecordingCircBufAddReader(&Buf, &idFast), VINF_SUCCESS);
    RTTESTI_CHECK_RC(RecordingCircBufAddReader(&Buf, &idSlow), VINF_SUCCESS);
    RTTESTI_CHECK(idFast != idSlow);

    uint8_t abW1[8] = {0,1,2,3,4,5,6,7};

    void  *pvW = NULL;
    size_t cbW = 0;
    RTTESTI_CHECK_RC(RecordingCircBufAcquireWrite(&Buf, sizeof(abW1), &pvW, &cbW), VINF_SUCCESS);
    RTTESTI_CHECK(cbW >= sizeof(abW1));
    memcpy(pvW, abW1, sizeof(abW1));
    RTTESTI_CHECK_RC(RecordingCircBufReleaseWrite(&Buf, sizeof(abW1)), VINF_SUCCESS);

    /* Still full: extra write should fail. */
    int rc = RecordingCircBufAcquireWrite(&Buf, 1, &pvW, &cbW);
    RTTESTI_CHECK_RC(rc, VERR_TRY_AGAIN);

    /* Fast consumes all; slow doesn't => still full. */
    const void *pvR = NULL;
    size_t cbR = 0;
    RTTESTI_CHECK_RC(RecordingCircBufAcquireRead(&Buf, idFast, 8, &pvR, &cbR), VINF_SUCCESS);
    RTTESTI_CHECK(cbR == 8);
    RTTESTI_CHECK(memcmp(pvR, abW1, 8) == 0);
    RTTESTI_CHECK_RC(RecordingCircBufReleaseRead(&Buf, idFast, 8), VINF_SUCCESS);

    rc = RecordingCircBufAcquireWrite(&Buf, 1, &pvW, &cbW);
    RTTESTI_CHECK(pvW == NULL);
    RTTESTI_CHECK(cbW == 0);
    RTTESTI_CHECK_RC(rc, VERR_TRY_AGAIN);

    /* Slow consumes all; next acquire-write can reclaim and succeed. */
    RTTESTI_CHECK_RC(RecordingCircBufAcquireRead(&Buf, idSlow, 8, &pvR, &cbR), VINF_SUCCESS);
    RTTESTI_CHECK(cbR == 8);
    RTTESTI_CHECK(memcmp(pvR, abW1, 8) == 0);
    RTTESTI_CHECK_RC(RecordingCircBufReleaseRead(&Buf, idSlow, 8), VINF_SUCCESS);

    rc = RecordingCircBufAcquireWrite(&Buf, 1, &pvW, &cbW);
    RTTESTI_CHECK_RC(rc, VINF_SUCCESS);
    RTTESTI_CHECK_RETV(cbW == 1);
    *(uint8_t *)pvW = 0xaa;
    RTTESTI_CHECK_RC(RecordingCircBufReleaseWrite(&Buf, 1), VINF_SUCCESS);

    /* Both see the new byte. */
    RTTESTI_CHECK_RC(RecordingCircBufAcquireRead(&Buf, idFast, 1, &pvR, &cbR), VINF_SUCCESS);
    RTTESTI_CHECK(cbR == 1);
    RTTESTI_CHECK(*(uint8_t const *)pvR == 0xaa);
    RTTESTI_CHECK_RC(RecordingCircBufReleaseRead(&Buf, idFast, 1), VINF_SUCCESS);

    RTTESTI_CHECK_RC(RecordingCircBufAcquireRead(&Buf, idSlow, 1, &pvR, &cbR), VINF_SUCCESS);
    RTTESTI_CHECK(cbR == 1);
    RTTESTI_CHECK(*(uint8_t const *)pvR == 0xaa);
    RTTESTI_CHECK_RC(RecordingCircBufReleaseRead(&Buf, idSlow, 1), VINF_SUCCESS);

    RecordingCircBufDestroy(&Buf);
}

static void tstRecCircBufOverflowResolvedByRemovingSlow(RTTEST hTest)
{
    RTTestSub(hTest, "RecCircBuf: Overflow resolved by removing slow reader");

    RECORDINGCIRCBUF Buf;
    RTTESTI_CHECK_RC(RecordingCircBufCreate(&Buf, 8), VINF_SUCCESS);

    uint32_t idFast = 0, idSlow = 0;
    RTTESTI_CHECK_RC(RecordingCircBufAddReader(&Buf, &idFast), VINF_SUCCESS);
    RTTESTI_CHECK_RC(RecordingCircBufAddReader(&Buf, &idSlow), VINF_SUCCESS);

    uint8_t abW1[8] = { 10,11,12,13,14,15,16,17 };

    void  *pvW = NULL;
    size_t cbW = 0;
    RTTESTI_CHECK_RC(RecordingCircBufAcquireWrite(&Buf, 8, &pvW, &cbW), VINF_SUCCESS);
    RTTESTI_CHECK(cbW >= 8);
    memcpy(pvW, abW1, 8);
    RTTESTI_CHECK_RC(RecordingCircBufReleaseWrite(&Buf, 8), VINF_SUCCESS);

    /* Fast consumes all. */
    const void *pvR = NULL;
    size_t cbR = 0;
    RTTESTI_CHECK_RC(RecordingCircBufAcquireRead(&Buf, idFast, 8, &pvR, &cbR), VINF_SUCCESS);
    RTTESTI_CHECK(cbR == 8);
    RTTESTI_CHECK_RC(RecordingCircBufReleaseRead(&Buf, idFast, 8), VINF_SUCCESS);

    /* Still full (slow hasn't consumed). */
    int rc = RecordingCircBufAcquireWrite(&Buf, 1, &pvW, &cbW);
    RTTESTI_CHECK_RC(rc, VERR_TRY_AGAIN);

    /* Remove slow => writer can reclaim and proceed. */
    RTTESTI_CHECK_RC(RecordingCircBufRemoveReader(&Buf, idSlow), VINF_SUCCESS);

    rc = RecordingCircBufAcquireWrite(&Buf, 1, &pvW, &cbW);
    RTTESTI_CHECK_RETV(cbW == 1);
    RTTESTI_CHECK_RC(rc, VINF_SUCCESS);
    *(uint8_t *)pvW = 0xbb;
    RTTESTI_CHECK_RC(RecordingCircBufReleaseWrite(&Buf, 1), VINF_SUCCESS);

    /* Fast reads the new byte. */
    RTTESTI_CHECK_RC(RecordingCircBufAcquireRead(&Buf, idFast, 1, &pvR, &cbR), VINF_SUCCESS);
    RTTESTI_CHECK(cbR == 1);
    RTTESTI_CHECK(*(uint8_t const *)pvR == 0xbb);
    RTTESTI_CHECK_RC(RecordingCircBufReleaseRead(&Buf, idFast, 1), VINF_SUCCESS);

    RecordingCircBufDestroy(&Buf);
}

static void tstRecCircBufRecFrames(RTTEST hTest)
{
    RTTestSub(hTest, "RecCircBuf: Recording frames");

    for (int t = 0; t < 32; t++)
    {
        size_t const cbFrame = sizeof(RECORDINGFRAME) + RTRandU32Ex(0, _4K);
        size_t const cFrames = RTRandU32Ex(1, 1024);

        RTTestPrintf(hTest, RTTESTLVL_ALWAYS, "Testing %zu frames, each %zu bytes (%zu bytes total)\n",
                     cFrames, cbFrame, cFrames * cbFrame);

        RECORDINGCIRCBUF Buf;
        RTTESTI_CHECK_RC_RETV(RecordingCircBufCreate(&Buf, cFrames * cbFrame), VINF_SUCCESS);
        RTTESTI_CHECK((RecordingCircBufSize(&Buf) % cbFrame) == 0); /* Size must be an integral of cbFrame. */
        uint32_t idRdrA, idRdrB;
        RTTESTI_CHECK_RC_RETV(RecordingCircBufAddReader(&Buf, &idRdrA), VINF_SUCCESS);
        RTTESTI_CHECK_RC_RETV(RecordingCircBufAddReader(&Buf, &idRdrB), VINF_SUCCESS);

        size_t cOverwriteOldStuff = RTRandU32Ex(1, 4);

        size_t cToWrite = cFrames * cOverwriteOldStuff;
        size_t cWrittenTotal = 0;
        size_t cToReadA = cFrames * cOverwriteOldStuff;
        size_t cReadTotalA = 0;
        size_t cToReadB = cFrames * cOverwriteOldStuff;
        size_t cReadTotalB = 0;
        while (cToWrite || cToReadA || cToReadB)
        {
            size_t const cCurToWrite = RTRandU32Ex(0, (uint32_t)cToWrite);
            RTTestPrintf(hTest, RTTESTLVL_ALWAYS, "Writing %zu frames (cWrittenTotal=%zu)\n", cCurToWrite, cWrittenTotal);
            size_t cWritten = 0;
            for (size_t i = 0; i < cCurToWrite; i++)
            {
                void  *pvW = NULL;
                size_t cbW = 0;
                int rc = RecordingCircBufAcquireWrite(&Buf, cbFrame, &pvW, &cbW);
                if (RT_SUCCESS(rc))
                {
                    RTTESTI_CHECK_MSG_RETV(cbW == cbFrame, ("\tFrame: #%zu: Written %zu, expected %zu\n", i, cbW, cbFrame));
                    RTTESTI_CHECK_RC_RETV(rc, VINF_SUCCESS);
                    RTTESTI_CHECK_RC_RETV(RecordingCircBufReleaseWrite(&Buf, cbW), VINF_SUCCESS);
                    cWritten++;
                }
                else
                {
                    if (rc == VERR_TRY_AGAIN)
                        RTTestPrintf(hTest, RTTESTLVL_ALWAYS, "\tFrame: #%zu: Buffer full, skipping\n", i);
                    break;
                }
            }
            cToWrite -= cWritten;
            cWrittenTotal += cWritten;

            RTTESTI_CHECK((RecordingCircBufUsed(&Buf) % cbFrame) == 0); /* Writes must be an integral of cbFrame. */

            /* Reader A */
            size_t cCurToRead = RTRandU32Ex(0, (uint32_t)cToReadA);
                   cCurToRead = RT_MIN(cCurToRead, cWrittenTotal - cReadTotalA);
            size_t cRead = 0;
            for (size_t i = 0; i < cCurToRead; i++)
            {
                const void *pvR;
                size_t      cbR;
                int rc = RecordingCircBufAcquireRead(&Buf, idRdrA, cbFrame, &pvR, &cbR);
                if (RT_SUCCESS(rc))
                {
                    RTTESTI_CHECK_MSG_RETV(cbR == cbFrame, ("\tA: Frame #%zu: Got %zu bytes, expected %zu\n", i, cbR, cbFrame));
                    RecordingCircBufReleaseRead(&Buf, idRdrA, cbR);
                    cRead++;
                }
                else
                {
                    if (rc == VERR_TRY_AGAIN)
                        RTTestPrintf(hTest, RTTESTLVL_ALWAYS, "\tA: Frame: #%zu: Buffer empty, skipping\n", i);
                    break;
                }
            }
            cToReadA -= cRead;
            cReadTotalA += cRead;
            RTTestPrintf(hTest, RTTESTLVL_ALWAYS, "\tA: Read %zu frames (cReadTotal=%zu)\n", cRead, cReadTotalA);

            /* Reader B */
            cCurToRead = RTRandU32Ex(0, (uint32_t)cToReadB);
            cCurToRead = RT_MIN(cCurToRead, cWrittenTotal - cReadTotalB);
            cRead      = 0;
            for (size_t i = 0; i < cCurToRead; i++)
            {
                const void *pvR;
                size_t      cbR;
                int rc = RecordingCircBufAcquireRead(&Buf, idRdrB, cbFrame, &pvR, &cbR);
                if (RT_SUCCESS(rc))
                {
                    RTTESTI_CHECK_MSG_RETV(cbR == cbFrame, ("\tB: Frame #%zu: Got %zu bytes, expected %zu\n", i, cbR, cbFrame));
                    RecordingCircBufReleaseRead(&Buf, idRdrB, cbR);
                    cRead++;
                }
                else
                {
                    if (rc == VERR_TRY_AGAIN)
                        RTTestPrintf(hTest, RTTESTLVL_ALWAYS, "\tB: Frame: #%zu: Buffer empty, skipping\n", i);
                    break;
                }
            }
            cToReadB -= cCurToRead;
            cReadTotalB += cCurToRead;
            RTTestPrintf(hTest, RTTESTLVL_ALWAYS, "\tB: Read %zu frames (cReadTotal=%zu)\n", cRead, cReadTotalB);
        }

        RTTESTI_CHECK(cWrittenTotal == cReadTotalA);
        RTTESTI_CHECK(cWrittenTotal == cReadTotalB);
        RecordingCircBufDestroy(&Buf);
    }
}

static void tstRecRenderer(RTTEST hTest)
{
    RTTestSub(hTest, "Renderer");

    RECORDINGRENDERER Renderer;
    RT_ZERO(Renderer);

    int rc = RecordingRenderInit(&Renderer, RECORDINGRENDERBACKEND_AUTO);
    RTTESTI_CHECK_RC_RETV(rc, VINF_SUCCESS);

    /*
     * Create test pattern frame.
     */
    RECORDINGSURFACEINFO ScreenParms;
    RT_ZERO(ScreenParms);
    ScreenParms.uWidth        = 640;
    ScreenParms.uHeight       = 480;
    ScreenParms.uBPP          = 32;
    ScreenParms.enmPixelFmt   = RECORDINGPIXELFMT_BRGA32;
    ScreenParms.uBytesPerLine = ScreenParms.uWidth * 4;

    RECORDINGRENDERPARMS RenderParms;
    RT_ZERO(RenderParms);
    RenderParms.Info = ScreenParms;

    rc = RecordingRenderSetParms(&Renderer, &RenderParms);
    RTTESTI_CHECK_RC_RETV(rc, VINF_SUCCESS);

    rc = RecordingRenderScreenChange(&Renderer, &ScreenParms);
    RTTESTI_CHECK_RC_RETV(rc, VINF_SUCCESS);

    RECORDINGFRAME FrameVideo;
    RT_ZERO(FrameVideo);
    FrameVideo.enmType = RECORDINGFRAME_TYPE_VIDEO;
    rc = RecordingVideoFrameInit(&FrameVideo.u.Video, RECORDINGVIDEOFRAME_F_VISIBLE,
                                 ScreenParms.uWidth, ScreenParms.uHeight,
                                 0 /* uPosX */, 0 /* uPosY */,
                                 ScreenParms.uBPP, ScreenParms.enmPixelFmt);
    RTTESTI_CHECK_RC_RETV(rc, VINF_SUCCESS);

    for (uint32_t y = 0; y < ScreenParms.uHeight; y++)
    {
        for (uint32_t x = 0; x < ScreenParms.uWidth; x++)
        {
            uint8_t *pu8Pixel = &FrameVideo.u.Video.pau8Buf[(size_t)y * FrameVideo.u.Video.Info.uBytesPerLine + (size_t)x * 4];

            uint8_t const uX = (uint8_t)((x * 255U) / (ScreenParms.uWidth  - 1));
            uint8_t const uY = (uint8_t)((y * 255U) / (ScreenParms.uHeight - 1));

            /* Gradient background to detect axis swaps. */
            pu8Pixel[0] = (uint8_t)(0x20 + (uX >> 1));
            pu8Pixel[1] = (uint8_t)(0x20 + (uY >> 1));
            pu8Pixel[2] = (uint8_t)(0x20 + ((uX ^ uY) >> 2));
            pu8Pixel[3] = 0xff;

            /* White center cross. */
            if (   x == ScreenParms.uWidth / 2
                || y == ScreenParms.uHeight / 2)
            {
                pu8Pixel[0] = 0xff;
                pu8Pixel[1] = 0xff;
                pu8Pixel[2] = 0xff;
            }

            /* Blue 1:1 square marker to catch ratio errors. */
            uint32_t const uSquare = RT_MIN(ScreenParms.uWidth, ScreenParms.uHeight);
            uint32_t const uSqX0   = (ScreenParms.uWidth  - uSquare) / 2;
            uint32_t const uSqY0   = (ScreenParms.uHeight - uSquare) / 2;
            uint32_t const uSqX1   = uSqX0 + uSquare - 1;
            uint32_t const uSqY1   = uSqY0 + uSquare - 1;
            if (   (x >= uSqX0 && x <= uSqX1 && (y == uSqY0 || y == uSqY1))
                || (y >= uSqY0 && y <= uSqY1 && (x == uSqX0 || x == uSqX1)))
            {
                pu8Pixel[0] = 0xff;
                pu8Pixel[1] = 0x40;
                pu8Pixel[2] = 0x40;
            }

            /* Red border to ensure full frame area is handled. */
            if (   x == 0
                || y == 0
                || x == ScreenParms.uWidth  - 1
                || y == ScreenParms.uHeight - 1)
            {
                pu8Pixel[0] = 0x00;
                pu8Pixel[1] = 0x00;
                pu8Pixel[2] = 0xff;
            }
        }
    }

    /*
     * Create test cursor frame.
     */
    RECORDINGFRAME FrameCursorShape;
    RT_ZERO(FrameCursorShape);
    FrameCursorShape.enmType = RECORDINGFRAME_TYPE_CURSOR_SHAPE;
    rc = RecordingVideoFrameInit(&FrameCursorShape.u.CursorShape, RECORDINGVIDEOFRAME_F_VISIBLE,
                                 12 /* uWidth */, 10 /* uHeight */,
                                 0 /* uPosX */, 0 /* uPosY */,
                                 32 /* uBPP */, RECORDINGPIXELFMT_BRGA32);
    RTTESTI_CHECK_RC_RETV(rc, VINF_SUCCESS);

    for (uint32_t y = 0; y < FrameCursorShape.u.CursorShape.Info.uHeight; y++)
    {
        for (uint32_t x = 0; x < FrameCursorShape.u.CursorShape.Info.uWidth; x++)
        {
            uint8_t *pu8Pixel = &FrameCursorShape.u.CursorShape.pau8Buf[(size_t)y * FrameCursorShape.u.CursorShape.Info.uBytesPerLine + (size_t)x * 4];

            /* Transparent background. */
            pu8Pixel[0] = 0x00;
            pu8Pixel[1] = 0x00;
            pu8Pixel[2] = 0x00;
            pu8Pixel[3] = 0x00;

            /* White plus sign. */
            if (x == 5 || y == 4)
            {
                pu8Pixel[0] = 0xff;
                pu8Pixel[1] = 0xff;
                pu8Pixel[2] = 0xff;
                pu8Pixel[3] = 0xff;
            }
        }
    }

    RECORDINGFRAME FrameCursorPos;
    RT_ZERO(FrameCursorPos);
    FrameCursorPos.enmType        = RECORDINGFRAME_TYPE_CURSOR_POS;
    FrameCursorPos.u.Cursor.Pos.x = 128;
    FrameCursorPos.u.Cursor.Pos.y = 128;

    /*
     * Render original size test frame.
     */
    RTTESTI_CHECK_RC_RETV(RecordingRenderComposeBegin(&Renderer), VINF_SUCCESS);
    RTTESTI_CHECK_RC_RETV(RecordingRenderComposeAddFrame(&Renderer, &FrameVideo), VINF_SUCCESS);
    RTTESTI_CHECK_RC_RETV(RecordingRenderComposeAddFrame(&Renderer, &FrameCursorShape), VINF_SUCCESS);
    RTTESTI_CHECK_RC_RETV(RecordingRenderComposeAddFrame(&Renderer, &FrameCursorPos), VINF_SUCCESS);
    RTTESTI_CHECK_RC_RETV(RecordingRenderComposeEnd(&Renderer), VINF_SUCCESS);
    RTTESTI_CHECK_RC_RETV(RecordingRenderPerform(&Renderer), VINF_SUCCESS);

    FrameCursorPos.u.Cursor.Pos.x = 28;
    FrameCursorPos.u.Cursor.Pos.y = 18;

    /*
     * Cropping / Scaling tests.
     */
    static struct SCALINGTEST
    {
        uint32_t                    uWidth;
        uint32_t                    uHeight;
        RECORDINGPIXELFMT           enmPixelFmt;
        RecordingVideoScalingMode_T enmMode;
    } s_aScalingTests[] =
    {
        /* Test cropping. */
        { 320, 200, RECORDINGPIXELFMT_BRGA32, RecordingVideoScalingMode_None },
        /* Test cropping. */
        { 1024, 768, RECORDINGPIXELFMT_BRGA32, RecordingVideoScalingMode_None },
        /* Test nearest-neighbor downscaling. */
        { 320, 200, RECORDINGPIXELFMT_BRGA32, RecordingVideoScalingMode_NearestNeighbor },
        /* Test nearest-neighbor fractional downscaling. */
        { 123, 456, RECORDINGPIXELFMT_BRGA32, RecordingVideoScalingMode_NearestNeighbor },
        /* Test nearest-neighbor upscaling. */
        { 1600, 1200, RECORDINGPIXELFMT_BRGA32, RecordingVideoScalingMode_NearestNeighbor },
        /* Test bilinear downscaling. */
        { 320, 200, RECORDINGPIXELFMT_BRGA32, RecordingVideoScalingMode_Bilinear },
        /* Test nearest-neighbor fractional downscaling. */
        { 123, 456, RECORDINGPIXELFMT_BRGA32, RecordingVideoScalingMode_Bilinear },
        /* Test bilinear upscaling. */
        { 1600, 1200, RECORDINGPIXELFMT_BRGA32, RecordingVideoScalingMode_Bilinear },
        /* Test bicubic downscaling. */
        { 320, 200, RECORDINGPIXELFMT_BRGA32, RecordingVideoScalingMode_Bicubic },
        /* Test bicubic fractional downscaling. */
        { 123, 456, RECORDINGPIXELFMT_BRGA32, RecordingVideoScalingMode_Bicubic },
        /* Test bicubic upscaling. */
        { 1600, 1200, RECORDINGPIXELFMT_BRGA32, RecordingVideoScalingMode_Bicubic }
    };

    for (size_t t = 0; t < RT_ELEMENTS(s_aScalingTests); t++)
    {
        RT_ZERO(RenderParms);
        RenderParms.Info.uWidth      = s_aScalingTests[t].uWidth;
        RenderParms.Info.uHeight     = s_aScalingTests[t].uHeight;
        RenderParms.Info.uBPP        = 32;
        RenderParms.Info.enmPixelFmt = s_aScalingTests[t].enmPixelFmt;
        RenderParms.enmScalingMode   = s_aScalingTests[t].enmMode;

        RTTESTI_CHECK_RC_RETV(RecordingRenderSetParms(&Renderer, &RenderParms), VINF_SUCCESS);

        RTTESTI_CHECK_RC_RETV(RecordingRenderComposeBegin(&Renderer), VINF_SUCCESS);
        RTTESTI_CHECK_RC_RETV(RecordingRenderComposeAddFrame(&Renderer, &FrameVideo), VINF_SUCCESS);
        RTTESTI_CHECK_RC_RETV(RecordingRenderComposeAddFrame(&Renderer, &FrameCursorPos), VINF_SUCCESS);
        RTTESTI_CHECK_RC_RETV(RecordingRenderComposeEnd(&Renderer), VINF_SUCCESS);
        RTTESTI_CHECK_RC_RETV(RecordingRenderPerform(&Renderer), VINF_SUCCESS);
    }

    /*
     * Query last rendered frame (+ dump it).
     */
    RECORDINGVIDEOFRAME FrameQueried;
    RTTESTI_CHECK_RC_RETV(RecordingRenderQueryFrame(&Renderer, &FrameQueried), VINF_SUCCESS);
#ifdef VBOX_RECORDING_DEBUG_DUMP_FRAMES
    RecordingDbgDumpVideoFrame(&FrameQueried, "tstRecordingRenderFrameQueried", 0 /* Timestamp */);
#endif
    RecordingVideoFrameDestroy(&FrameQueried);

    /*
     * YUV I420 conversion.
     */
    ScreenParms.uWidth        = 640;
    ScreenParms.uHeight       = 480;
    ScreenParms.uBPP          = 32;
    ScreenParms.enmPixelFmt   = RECORDINGPIXELFMT_BRGA32;
    ScreenParms.uBytesPerLine = ScreenParms.uWidth * 4;

    RenderParms.Info.uWidth      = 640;
    RenderParms.Info.uHeight     = 480;
    RenderParms.Info.uBPP        = 32;
    RenderParms.Info.enmPixelFmt = RECORDINGPIXELFMT_YUVI420;
    RenderParms.enmScalingMode   = RecordingVideoScalingMode_None;

    RTTESTI_CHECK_RC_RETV(RecordingRenderSetParms(&Renderer, &RenderParms), VINF_SUCCESS);
    RTTESTI_CHECK_RC_RETV(RecordingRenderComposeBegin(&Renderer), VINF_SUCCESS);
    RTTESTI_CHECK_RC_RETV(RecordingRenderComposeAddFrame(&Renderer, &FrameVideo), VINF_SUCCESS);
    RTTESTI_CHECK_RC_RETV(RecordingRenderComposeAddFrame(&Renderer, &FrameCursorPos), VINF_SUCCESS);
    RTTESTI_CHECK_RC_RETV(RecordingRenderComposeEnd(&Renderer), VINF_SUCCESS);
    RTTESTI_CHECK_RC(RecordingRenderPerform(&Renderer), VINF_SUCCESS);

    RTTESTI_CHECK_RC_RETV(RecordingRenderQueryFrame(&Renderer, &FrameQueried), VINF_SUCCESS);
#ifdef VBOX_RECORDING_DEBUG_DUMP_FRAMES
    RecordingDbgDumpVideoFrame(&FrameQueried, "tstRecordingRenderYUVI420", 0 /* Timestamp */);
#endif
    RecordingVideoFrameDestroy(&FrameQueried);

    /*
     * Clean up.
     */
    RecordingFrameDestroy(&FrameCursorShape);
    RecordingFrameDestroy(&FrameVideo);
    RecordingRenderDestroy(&Renderer);
}

static void tstRecWebMWriterSimpleBlockPool(RTTEST hTest)
{
    RTTestSub(hTest, "WebMWriter: simple block / payload pool");

    typedef WebMWriter::WebMSimpleBlock WebMSimpleBlock;
    typedef WebMWriter::WebMTrack       WebMTrack;
    typedef WebMWriter::WebMTimecodeAbs WebMTimecodeAbs;
    typedef WebMWriter::WebMBlockFlags  WebMBlockFlags;

    static size_t const s_cMaxBlocks         = 4096;
    static size_t const s_cbMaxRetainedBytes = 32U * _1M;

    WebMWriter::WebMBlockPool BlockPool;

    uint8_t abPayload1[_1K + 256];
    RT_ZERO(abPayload1);

    WebMSimpleBlock *pBlock1 = NULL;
    WebMSimpleBlock *pBlock2 = NULL;

    try
    {
        pBlock1 = BlockPool.allocBlock((WebMTrack *)NULL /* pTrack */, (WebMTimecodeAbs)42 /* tcAbsPTSMs */,
                                       &abPayload1[0], sizeof(abPayload1), (WebMBlockFlags)VBOX_WEBM_BLOCK_FLAG_KEY_FRAME);
    }
    catch (std::bad_alloc &)
    {
        RTTestFailed(hTest, "Out of memory allocating first pool block");
        return;
    }

    RTTESTI_CHECK_RETV(pBlock1 != NULL);
    RTTESTI_CHECK_RETV(pBlock1->Data.cb == sizeof(abPayload1));
    RTTESTI_CHECK_RETV(pBlock1->Data.pv != NULL);
    RTTESTI_CHECK_RETV(pBlock1->cbBacking >= pBlock1->Data.cb);

    void * const pvFirstPayload = pBlock1->Data.pv;

    BlockPool.freeBlock(pBlock1);
    pBlock1 = NULL;

    RTTESTI_CHECK_RETV(BlockPool.freeBlockCount() == 1);

    uint8_t abPayload2[_1K + 128];
    RT_ZERO(abPayload2);

    try
    {
        pBlock2 = BlockPool.allocBlock((WebMTrack *)NULL /* pTrack */, (WebMTimecodeAbs)43 /* tcAbsPTSMs */,
                                       &abPayload2[0], sizeof(abPayload2), (WebMBlockFlags)VBOX_WEBM_BLOCK_FLAG_NONE);
    }
    catch (std::bad_alloc &)
    {
        RTTestFailed(hTest, "Out of memory allocating second pool block");
        return;
    }

    RTTESTI_CHECK_RETV(pBlock2 != NULL);
    RTTESTI_CHECK_RETV(pBlock2->Data.cb == sizeof(abPayload2));
    RTTESTI_CHECK_RETV(pBlock2->Data.pv == pvFirstPayload);

    BlockPool.freeBlock(pBlock2);
    pBlock2 = NULL;

    RTTESTI_CHECK_RETV(BlockPool.freeBlockCount() == 1);

    std::vector<WebMSimpleBlock *> vecBlocks;

    try
    {
        vecBlocks.reserve(s_cMaxBlocks + 64);

        uint8_t abSmall[_1K];
        memset(&abSmall[0], 0xa5, sizeof(abSmall));

        for (size_t i = 0; i < s_cMaxBlocks + 64; i++)
        {
            WebMSimpleBlock *pBlock = BlockPool.allocBlock((WebMTrack *)NULL /* pTrack */, (WebMTimecodeAbs)i,
                                                           &abSmall[0], sizeof(abSmall),
                                                           (WebMBlockFlags)VBOX_WEBM_BLOCK_FLAG_NONE);
            RTTESTI_CHECK_RETV(pBlock != NULL);
            vecBlocks.push_back(pBlock);
        }

        for (size_t i = 0; i < vecBlocks.size(); i++)
            BlockPool.freeBlock(vecBlocks[i]);
        vecBlocks.clear();

        RTTESTI_CHECK_RETV(BlockPool.freeBlockCount() <= s_cMaxBlocks);
        RTTESTI_CHECK_RETV(BlockPool.retainedPayloadBytes() <= s_cbMaxRetainedBytes);

        std::vector<uint8_t> abLarge(_1M);
        memset(&abLarge[0], 0x5a, abLarge.size());

        size_t const cLargeBlocks = s_cbMaxRetainedBytes / _1M + 16;
        vecBlocks.reserve(cLargeBlocks);

        for (size_t i = 0; i < cLargeBlocks; i++)
        {
            WebMSimpleBlock *pBlock = BlockPool.allocBlock((WebMTrack *)NULL /* pTrack */, (WebMTimecodeAbs)(10000 + i),
                                                           &abLarge[0], _1M,
                                                           (WebMBlockFlags)VBOX_WEBM_BLOCK_FLAG_NONE);
            RTTESTI_CHECK_RETV(pBlock != NULL);
            vecBlocks.push_back(pBlock);
        }

        for (size_t i = 0; i < vecBlocks.size(); i++)
            BlockPool.freeBlock(vecBlocks[i]);
        vecBlocks.clear();
    }
    catch (std::bad_alloc &)
    {
        for (size_t i = 0; i < vecBlocks.size(); i++)
            BlockPool.freeBlock(vecBlocks[i]);
        RTTestFailed(hTest, "Out of memory while stress-testing simple block pool limits");
        return;
    }

    RTTESTI_CHECK_RETV(BlockPool.freeBlockCount() <= s_cMaxBlocks);
    RTTESTI_CHECK_RETV(BlockPool.retainedPayloadBytes() <= s_cbMaxRetainedBytes);

    BlockPool.clear();

    RTTESTI_CHECK_RETV(BlockPool.freeBlockCount() == 0);
    RTTESTI_CHECK_RETV(BlockPool.retainedPayloadBytes() == 0);
}

int main()
{
    RTTEST     hTest;
    RTEXITCODE rcExit = RTTestInitAndCreate("tstRecording", &hTest);
    if (rcExit != RTEXITCODE_SUCCESS)
        return rcExit;

    /*
     * Configure release logging to go to stdout.
     */
    RTUINT fFlags = RTLOGFLAGS_PREFIX_THREAD | RTLOGFLAGS_PREFIX_TIME_PROG;
#if defined(RT_OS_WINDOWS) || defined(RT_OS_OS2)
    fFlags |= RTLOGFLAGS_USECRLF;
#endif
    static const char * const s_apszLogGroups[] = VBOX_LOGGROUP_NAMES;
    int rc = RTLogCreate(&g_pRelLogger, fFlags, "all.e.l", "TST_RECORDING_RELEASE_LOG",
                     RT_ELEMENTS(s_apszLogGroups), s_apszLogGroups, RTLOGDEST_STDOUT, NULL);
    if (RT_SUCCESS(rc))
    {
        RTLogSetDefaultInstance(g_pRelLogger);
        rc = RTLogGroupSettings(g_pRelLogger, "recording.e.l.l2.l3");
        if (RT_FAILURE(rc))
            RTMsgError("Setting debug logging failed: %Rrc\n", rc);
    }
    else
        RTMsgWarning("Failed to create release logger: %Rrc", rc);

    RTTestBanner(hTest);

    tstRecCircBufSingleUse(hTest);
    tstRecCircBufUnderflow(hTest);
    tstRecCircBufMultiFanoutAndReclaim(hTest);
    tstRecCircBufOverflowSlowReader(hTest);
    tstRecCircBufOverflowResolvedByRemovingSlow(hTest);
    tstRecCircBufRecFrames(hTest);
    tstRecRenderCropCenter(hTest);
    tstRecRenderer(hTest);
    tstRecWebMWriterSimpleBlockPool(hTest);

    return RTTestSummaryAndDestroy(hTest);
}

