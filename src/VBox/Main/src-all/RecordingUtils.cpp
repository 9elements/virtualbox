/* $Id: RecordingUtils.cpp 113695 2026-03-31 09:30:05Z andreas.loeffler@oracle.com $ */
/** @file
 * Recording utility code.
 */

/*
 * Copyright (C) 2012-2026 Oracle and/or its affiliates.
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

#include <VBox/com/VirtualBox.h>

#include "RecordingUtils.h"

#include <iprt/asm.h>
#include <iprt/assert.h>
#include <iprt/critsect.h>
#include <iprt/path.h>
#include <iprt/semaphore.h>
#include <iprt/thread.h>
#include <iprt/time.h>

#ifdef DEBUG
#include <iprt/file.h>
#include <iprt/formats/bmp.h>
#include <iprt/mem.h>
#endif

#include <iprt/errcore.h>
#define LOG_GROUP LOG_GROUP_RECORDING
#include <VBox/log.h>


#ifndef IN_VBOXSVC /* Code only used in VBoxC. */
/**
 * Translates a recording frame type to a string.
 *
 * @returns Recording frame type as a string.
 * @param   enmType             The frame type to translate.
 */
const char *RecordingUtilsFrameTypeToStr(RECORDINGFRAME_TYPE enmType)
{
    switch (enmType)
    {
        RT_CASE_RET_STR(RECORDINGFRAME_TYPE_INVALID);
        RT_CASE_RET_STR(RECORDINGFRAME_TYPE_AUDIO);
        RT_CASE_RET_STR(RECORDINGFRAME_TYPE_VIDEO);
        RT_CASE_RET_STR(RECORDINGFRAME_TYPE_CURSOR_SHAPE);
        RT_CASE_RET_STR(RECORDINGFRAME_TYPE_CURSOR_POS);
        RT_CASE_RET_STR(RECORDINGFRAME_TYPE_SCREEN_CHANGE);
        default: break;
    }
    AssertFailedReturn("Unknown");
}

/**
 * Translates a recording render backend enum value to a readable string.
 *
 * @returns Recording backend as a string.
 * @param   enmBackend          Render backend to convert to a string.
 */
const char *RecordingUtilsRenderBackendToStr(RECORDINGRENDERBACKEND enmBackend)
{
    switch (enmBackend)
    {
        case RECORDINGRENDERBACKEND_AUTO:     return "auto";
        case RECORDINGRENDERBACKEND_SOFTWARE: return "software";
        case RECORDINGRENDERBACKEND_SDL:      return "sdl";
        default:                              break;
    }

    AssertFailedReturn("<invalid>");
}

/**
 * Calculates frame/queue capacity from FPS and latency budget.
 *
 * @returns Number of frame slots to allocate, clamped to [uMinFPS, uMaxFPS].
 * @param   uFPS                Target frame rate in frames per second.
 *                              If 0, a default of 25 FPS is assumed.
 * @param   msLatencyBudget     Target latency budget (in ms).
 * @param   uMinFPS             Minimum number of frame slots.
 * @param   uMaxFPS             Maximum number of frame slots.
 */
size_t RecordingUtilsCalcCapacityFromFpsAndLatency(size_t uFPS, RTMSINTERVAL msLatencyBudget,
                                                   size_t uMinFPS, size_t uMaxFPS)
{
    if (uFPS == 0)
        uFPS = 25;

    uint64_t const msBudget = RT_MAX((uint64_t)msLatencyBudget, UINT64_C(1));
    uint64_t       cFrames  = (uFPS * (msBudget * 2) + 999) / 1000; /* ~2x latency budget. */
    cFrames += 2;           /* Scheduling jitter headroom. */
    cFrames  = cFrames * 3; /* Safety factor 3x. */

    cFrames = RT_MAX(cFrames, (uint64_t)uMinFPS);
    cFrames = RT_MIN(cFrames, (uint64_t)uMaxFPS);
    return (size_t)cFrames;
}

/**
 * Calculates a frame pool slot count from a latency budget.
 *
 * @returns Number of frame slots to allocate, clamped to [cMin, cMax].
 * @param   msLatencyBudget     Target latency budget (in ms).
 * @param   msPerFrame          Expected frame duration (in ms).
 * @param   cMin                Minimum number of frame slots.
 * @param   cMax                Maximum number of frame slots.
 */
size_t RecordingUtilsCalcCapacityFromLatency(RTMSINTERVAL msLatencyBudget, size_t msPerFrame, size_t cMin, size_t cMax)
{
    AssertReturn(msPerFrame > 0, cMin);

    uint64_t const msBudget = RT_MAX((uint64_t)msLatencyBudget, UINT64_C(1));
    uint64_t       cFrames  = (msBudget * 2 + msPerFrame - 1) / msPerFrame; /* Buffer at least ~2x budget. */
    cFrames += 2; /* Wake-up / scheduling jitter. */
    cFrames *= 3; /* Safety factor. */

    cFrames = RT_MAX(cFrames, (uint64_t)cMin);
    cFrames = RT_MIN(cFrames, (uint64_t)cMax);
    return (size_t)cFrames;
}

# ifdef DEBUG
DECLINLINE(int) recordingUtilsDbgDumpBRGA32Frame(const uint8_t *pu8RGBBuf, size_t cbRGBBuf,
                                                 const char *pszPath, const char *pszWhat,
                                                 uint32_t uX, uint32_t uY, uint32_t uWidth, uint32_t uHeight,
                                                 uint32_t uBytesPerLine, uint8_t uBPP, uint64_t msTimestamp);

/**
 * Dumps a YUVI420 frame by converting it to BRGA32 first.
 *
 * @returns VBox status code.
 * @param   pFrame              YUVI420 frame to dump.
 * @param   pszPath             Absolute path to dump file to. Must exist.
 *                              Specify NULL to use the system's temp directory as output directory.
 * @param   pszWhat             Hint of what to dump. Optional and can be NULL.
 * @param   msTimestamp         Timestamp (PTS, absolute) of the frame.
 */
DECLINLINE(int) recordingUtilsDbgDumpYUVI420Frame(const PRECORDINGVIDEOFRAME pFrame, const char *pszPath,
                                                  const char *pszWhat, uint64_t msTimestamp)
{
    AssertPtrReturn(pFrame, VERR_INVALID_POINTER);
    AssertPtrReturn(pFrame->pau8Buf, VERR_INVALID_POINTER);

    uint32_t const uWidth  = pFrame->Info.uWidth;
    uint32_t const uHeight = pFrame->Info.uHeight;
    if (!uWidth || !uHeight)
        return VINF_SUCCESS;

    /* I420/YUVI420 is 4:2:0 and therefore uses even dimensions. */
    AssertReturn((uWidth & 1) == 0, VERR_INVALID_PARAMETER);
    AssertReturn((uHeight & 1) == 0, VERR_INVALID_PARAMETER);

    size_t const cbLumaPlane   = (size_t)uWidth * uHeight;
    size_t const cbChromaPlane = cbLumaPlane / 4;
    size_t const cbYUVI420     = cbLumaPlane + cbChromaPlane * 2;
    AssertReturn(pFrame->cbBuf >= cbYUVI420, VERR_INVALID_PARAMETER);

    size_t const cbBGRAStride = (size_t)uWidth * 4;
    size_t const cbBGRA       = cbBGRAStride * uHeight;

    uint8_t *pu8BGRA = (uint8_t *)RTMemAlloc(cbBGRA);
    AssertPtrReturn(pu8BGRA, VERR_NO_MEMORY);

    uint8_t const *pu8Y = pFrame->pau8Buf;
    uint8_t const *pu8U = pu8Y + cbLumaPlane;
    uint8_t const *pu8V = pu8U + cbChromaPlane;

    for (uint32_t y = 0; y < uHeight; y++)
    {
        size_t const offY  = (size_t)y * uWidth;
        size_t const offUV = (size_t)(y / 2) * (uWidth / 2);
        uint8_t *pu8DstLine = pu8BGRA + (size_t)y * cbBGRAStride;

        for (uint32_t x = 0; x < uWidth; x++)
        {
            int32_t const iY = pu8Y[offY + x];
            int32_t const iU = (int32_t)pu8U[offUV + (x / 2)] - 128;
            int32_t const iV = (int32_t)pu8V[offUV + (x / 2)] - 128;

            int32_t const iR = iY + ((359 * iV + 128) >> 8);
            int32_t const iG = iY - ((88 * iU + 183 * iV + 128) >> 8);
            int32_t const iB = iY + ((454 * iU + 128) >> 8);

            uint8_t *pu8Dst = pu8DstLine + (size_t)x * 4;
            pu8Dst[0] = RT_CLAMP(iB, 0, UINT8_MAX);
            pu8Dst[1] = RT_CLAMP(iG, 0, UINT8_MAX);
            pu8Dst[2] = RT_CLAMP(iR, 0, UINT8_MAX);
            pu8Dst[3] = 0xff;
        }
    }

    int const vrc = recordingUtilsDbgDumpBRGA32Frame(pu8BGRA, cbBGRA,
                                                      pszPath, pszWhat,
                                                      0, 0, uWidth, uHeight,
                                                      (uint32_t)cbBGRAStride, 32 /* uBPP */, msTimestamp);

    RTMemFree(pu8BGRA);
    return vrc;
}

/**
 * Dumps image data to a bitmap (BMP) file, inline version.
 *
 * @returns VBox status code.
 * @param   pu8RGBBuf           Pointer to actual RGB image data.
 *                              Must point right to the beginning of the pixel data (offset, if any).
 * @param   cbRGBBuf            Size (in bytes) of \a pu8RGBBuf.
 * @param   pszPath             Absolute path to dump file to. Must exist.
 *                              Specify NULL to use the system's temp directory as output directory.
 *                              Existing files will be overwritten.
 * @param   pszWhat             Hint of what to dump. Optional and can be NULL.
 * @param   uX                  Column to start X reading within \a pu8RGBBuf.
 * @param   uY                  Row to start reading within \a pu8RGBBuf.
 * @param   uWidth              Width (in pixel) to write.
 * @param   uHeight             Height (in pixel) to write.
 * @param   uBytesPerLine       Bytes per line (stride).
 * @param   uBPP                Bits in pixel.
 * @param   msTimestamp         Timestamp (PTS, absolute) of the frame.
 */
DECLINLINE(int) recordingUtilsDbgDumpBRGA32Frame(const uint8_t *pu8RGBBuf, size_t cbRGBBuf, const char *pszPath, const char *pszWhat,
                                               uint32_t uX, uint32_t uY, uint32_t uWidth, uint32_t uHeight, uint32_t uBytesPerLine,
                                               uint8_t uBPP, uint64_t msTimestamp)
{
    const uint8_t uBytesPerPixel = uBPP / 8 /* Bits */;
    const size_t  cbData         = uWidth * uHeight * uBytesPerPixel;

    Log3Func(("pu8RGBBuf=%p, cbRGBBuf=%zu, uX=%RU32, uY=%RU32, uWidth=%RU32, uHeight=%RU32, uBytesPerLine=%RU32, uBPP=%RU8, ts=%RU64\n",
              pu8RGBBuf, cbRGBBuf, uX, uY, uWidth, uHeight, uBytesPerLine, uBPP, msTimestamp));

    if (!cbData) /* No data to write? Bail out early. */
        return VINF_SUCCESS;

    BMPFILEHDR fileHdr;
    RT_ZERO(fileHdr);

    BMPWINV4INFOHDR infoHdr;
    RT_ZERO(infoHdr);

    fileHdr.uType      = BMP_HDR_MAGIC;
    fileHdr.cbFileSize = (uint32_t)(sizeof(BMPFILEHDR) + sizeof(BMPWINV4INFOHDR) + cbData);
    fileHdr.offBits    = (uint32_t)(sizeof(BMPFILEHDR) + sizeof(BMPWINV4INFOHDR));

    infoHdr.cbSize         = sizeof(BMPWINV4INFOHDR);
    infoHdr.cx             = (int32_t)uWidth;
    infoHdr.cy             = -(int32_t)uHeight;
    infoHdr.cBits          = uBPP;
    infoHdr.cPlanes        = 1;
    infoHdr.cbImage        = (uint32_t)cbData;
    infoHdr.cXPelsPerMeter = 2835;
    infoHdr.cYPelsPerMeter = 2835;
    infoHdr.fRedMask       = 0x00ff0000;
    infoHdr.fGreenMask     = 0x0000ff00;
    infoHdr.fBlueMask      = 0x000000ff;
    infoHdr.fAlphaMask     = 0xff000000;
#ifdef RT_OS_WINDOWS
    infoHdr.enmCSType      = LCS_WINDOWS_COLOR_SPACE;
#endif

    static uint64_t s_cRecordingUtilsBmpsDumped = 0;

    /* Hardcoded path for now. */
    char szPath[RTPATH_MAX];
    if (!pszPath)
    {
        int vrc2 = RTPathTemp(szPath, sizeof(szPath));
        if (RT_FAILURE(vrc2))
            return vrc2;
    }

    char szFileName[RTPATH_MAX];
    if (RTStrPrintf2(szFileName, sizeof(szFileName), "%s/RecDump-%06RU64-%06RU64-%s-w%RU32h%RU32bpp%RU8.bmp",
                     pszPath ? pszPath : szPath, s_cRecordingUtilsBmpsDumped, msTimestamp,
                     pszWhat ? pszWhat : "Frame", uWidth, uHeight, uBPP) <= 0)
        return VERR_BUFFER_OVERFLOW;

    s_cRecordingUtilsBmpsDumped++;

    RTFILE fh;
    int vrc = RTFileOpen(&fh, szFileName,
                         RTFILE_O_CREATE_REPLACE | RTFILE_O_WRITE | RTFILE_O_DENY_NONE);
    if (RT_SUCCESS(vrc))
    {
        RTFileWrite(fh, &fileHdr, sizeof(fileHdr), NULL);
        RTFileWrite(fh, &infoHdr, sizeof(infoHdr), NULL);

        size_t offSrc = (uY * uBytesPerLine) + (uX * uBytesPerPixel);
        size_t offDst = 0;
        size_t const cbSrcStride = uBytesPerLine;
        size_t const cbDstStride = uWidth * uBytesPerPixel;

        /* Do the copy. */
        while (offDst < cbData)
        {
            vrc = RTFileWrite(fh, pu8RGBBuf + offSrc, cbDstStride, NULL);
            AssertRCBreak(vrc);
            offSrc += cbSrcStride;
            offDst += cbDstStride;
        }
        Assert(offDst == cbData);

        int vrc2 = RTFileClose(fh);
        if (RT_SUCCESS(vrc))
            vrc = vrc2;
    }

    return vrc;
}

/**
 * Dumps image data to a bitmap (BMP) file.
 *
 * @returns VBox status code.
 * @param   pu8RGBBuf           Pointer to actual RGB image data.
 *                              Must point right to the beginning of the pixel data (offset, if any).
 * @param   cbRGBBuf            Size (in bytes) of \a pu8RGBBuf.
 * @param   pszPath             Absolute path to dump file to. Must exist.
 *                              Specify NULL to use the system's temp directory as output directory.
 *                              Existing files will be overwritten.
 * @param   pszWhat             Hint of what to dump. Optional and can be NULL.
 * @param   uX                  Column to start X reading within \a pu8RGBBuf.
 * @param   uY                  Row to start reading within \a pu8RGBBuf.
 * @param   uWidth              Width (in pixel) to write.
 * @param   uHeight             Height (in pixel) to write.
 * @param   uBytesPerLine       Bytes per line (stride).
 * @param   uBPP                Bits in pixel.
 * @param   msTimestamp         Timestamp (PTS, absolute) of the frame.
 */
int RecordingDbgDumpImageData(const uint8_t *pu8RGBBuf, size_t cbRGBBuf, const char *pszPath, const char *pszWhat,
                                   uint32_t uX, uint32_t uY, uint32_t uWidth, uint32_t uHeight, uint32_t uBytesPerLine,
                                   uint8_t uBPP, uint64_t msTimestamp)
{
    return recordingUtilsDbgDumpBRGA32Frame(pu8RGBBuf, cbRGBBuf, pszPath, pszWhat,
                                            uX, uY, uWidth, uHeight, uBytesPerLine, uBPP, msTimestamp);
}

/**
 * Dumps a video recording frame to a bitmap (BMP) file, extended version.
 *
 * @returns VBox status code.
 * @param   pFrame              Video frame to dump.
 * @param   pszPath             Output directory.
 *                              Specify NULL to use the system's temp directory as output directory.
 * @param   pszWhat             Hint of what to dump. Optional and can be NULL.
 * @param   msTimestamp         Timestamp (PTS, absolute) of the frame.
 */
int RecordingDbgDumpVideoFrameEx(const PRECORDINGVIDEOFRAME pFrame, const char *pszPath, const char *pszWhat, uint64_t msTimestamp)
{
    switch (pFrame->Info.enmPixelFmt)
    {
        case RECORDINGPIXELFMT_BRGA32:
            return recordingUtilsDbgDumpBRGA32Frame(pFrame->pau8Buf, pFrame->cbBuf,
                                                    pszPath, pszWhat,
                                                    0, 0, pFrame->Info.uWidth, pFrame->Info.uHeight,
                                                    pFrame->Info.uBytesPerLine, pFrame->Info.uBPP, msTimestamp);

        case RECORDINGPIXELFMT_YUVI420:
            return recordingUtilsDbgDumpYUVI420Frame(pFrame, pszPath, pszWhat, msTimestamp);

        default:
            break;
    }

    AssertFailedReturn(VERR_NOT_IMPLEMENTED);
}

/**
 * Dumps a video recording frame to a bitmap (BMP) file.
 *
 * @returns VBox status code.
 * @param   pFrame              Video frame to dump.
 * @param   pszWhat             Hint of what to dump. Optional and can be NULL.
 * @param   msTimestamp         Timestamp (PTS, absolute) of the frame.
 */
int RecordingDbgDumpVideoFrame(const PRECORDINGVIDEOFRAME pFrame, const char *pszWhat, uint64_t msTimestamp)
{
    return RecordingDbgDumpVideoFrameEx(pFrame, NULL /* Use temp directory */, pszWhat, msTimestamp);
}

/**
 * Logs a recording frame.
 *
 * @param   pFrame              Recording frame to log.
 */
void RecordingDbgLogFrame(PRECORDINGFRAME pFrame)
{
    Log3(("id=%RU16, type=%s (%#x), ts=%RU64", pFrame->idStream,
          RecordingUtilsFrameTypeToStr(pFrame->enmType), pFrame->enmType, pFrame->msTimestamp));
    switch (pFrame->enmType)
    {
        case RECORDINGFRAME_TYPE_VIDEO:
            Log3((", w=%RU32, h=%RU32\n", pFrame->u.Video.Info.uWidth, pFrame->u.Video.Info.uHeight));
            break;
        case RECORDINGFRAME_TYPE_CURSOR_SHAPE:
            Log3((", w=%RU32, h=%RU32\n", pFrame->u.CursorShape.Info.uWidth, pFrame->u.CursorShape.Info.uHeight));
            break;
        case RECORDINGFRAME_TYPE_CURSOR_POS:
            Log3((", x=%RU32, y=%RU32\n", pFrame->u.Cursor.Pos.x, pFrame->u.Cursor.Pos.y));
            break;
        case RECORDINGFRAME_TYPE_SCREEN_CHANGE:
            Log3((", w=%RU32, h=%RU32\n", pFrame->u.ScreenInfo.uWidth, pFrame->u.ScreenInfo.uHeight));
            break;
        default:
            Log3(("\n"));
            break;
    }
}

/**
 * Draws a thick red border into a tile buffer for visual debugging.
 */
void RecordingDbgAddVideoFrameBorder(PRECORDINGVIDEOFRAME pFrame)
{
    AssertPtrReturnVoid(pFrame);
    AssertPtrReturnVoid(pFrame->pau8Buf);

    uint32_t const cx = pFrame->Info.uWidth;
    uint32_t const cy = pFrame->Info.uHeight;
    if (!cx || !cy)
        return;

    uint32_t const cbBytesPerPixel = RT_MAX((uint32_t)(pFrame->Info.uBPP / 8), (uint32_t)1);
    if (cbBytesPerPixel < 3)
        return;

    uint32_t const cbStrideMin = cx * cbBytesPerPixel;
    uint32_t const cbStride = pFrame->Info.uBytesPerLine ? pFrame->Info.uBytesPerLine : cbStrideMin;
    if (cbStride < cbStrideMin)
        return;

    uint32_t const cBorder = RT_MIN((uint32_t)1 /* Thickness */,
                                    RT_MIN(cx, cy));

    for (uint32_t y = 0; y < cy; y++)
    {
        bool const fBorderY = y < cBorder || y >= cy - cBorder;
        uint8_t *pu8Line = pFrame->pau8Buf + (size_t)y * cbStride;

        for (uint32_t x = 0; x < cx; x++)
        {
            if (   fBorderY
                || x < cBorder
                || x >= cx - cBorder)
            {
                uint8_t *pu8Pixel = pu8Line + (size_t)x * cbBytesPerPixel;

                /* BGRA: pure opaque red. */
                pu8Pixel[0] = 0x00;
                pu8Pixel[1] = 0x00;
                pu8Pixel[2] = 0xFF;
                if (cbBytesPerPixel >= 4)
                    pu8Pixel[3] = 0xFF;
            }
        }
    }
}
# endif /* DEBUG */
#endif  /* !IN_VBOXSVC */

/**
 * Converts an audio codec to a serializable string.
 *
 * @returns Recording audio codec as a string.
 * @param   enmCodec            Codec to convert to a string.
 *
 * @note    Warning! Do not change these values unless you know what you're doing.
 *                   Those values are being used for serializing the settings.
 */
const char *RecordingUtilsAudioCodecToStr(RecordingAudioCodec_T enmCodec)
{
    switch (enmCodec)
    {
        case RecordingAudioCodec_None:      return "none";
        case RecordingAudioCodec_WavPCM:    return "wav";
        case RecordingAudioCodec_MP3:       return "mp3";
        case RecordingAudioCodec_Opus:      return "opus";
        case RecordingAudioCodec_OggVorbis: return "vorbis";
        default:                            break;
    }

    AssertFailedReturn("<invalid>");
}

/**
 * Converts a video codec to a serializable string.
 *
 * @returns Recording video codec as a string.
 * @param   enmCodec            Codec to convert to a string.
 *
 * @note    Warning! Do not change these values unless you know what you're doing.
 *                   Those values are being used for serializing the settings.
 */
const char *RecordingUtilsVideoCodecToStr(RecordingVideoCodec_T enmCodec)
{
    switch (enmCodec)
    {
        case RecordingVideoCodec_None:  return "none";
        case RecordingVideoCodec_MJPEG: return "MJPEG";
        case RecordingVideoCodec_H262:  return "H262";
        case RecordingVideoCodec_H264:  return "H264";
        case RecordingVideoCodec_H265:  return "H265";
        case RecordingVideoCodec_H266:  return "H266";
        case RecordingVideoCodec_VP8:   return "VP8";
        case RecordingVideoCodec_VP9:   return "VP9";
        case RecordingVideoCodec_AV1:   return "AV1";
        case RecordingVideoCodec_Other: return "other";
        default:                        break;
    }

    AssertFailedReturn("<invalid>");
}

/**
 * Converts a video scaling mode to a string.
 *
 * @returns Recording video scaling mode as a string.
 * @param   enmMode             Video scaling mode to convert.
 */
const char *RecordingUtilsVideoScalingModeToStr(RecordingVideoScalingMode_T enmMode)
{
    switch (enmMode)
    {
        case RecordingVideoScalingMode_None:            return "none";
        case RecordingVideoScalingMode_NearestNeighbor: return "nearest neighbor";
        case RecordingVideoScalingMode_Bilinear:        return "bilinear";
        case RecordingVideoScalingMode_Bicubic:         return "bicubic";
        default:                                        break;
    }

    AssertFailedReturn("<invalid>");
}

