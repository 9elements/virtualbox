/* $Id: RecordingRender.cpp 113708 2026-04-02 09:19:01Z andreas.loeffler@oracle.com $ */
/** @file
 * Recording rendering implementation.
 *
 * The recording renderer takes care of composing frames which gets sent to the
 * codec for encoding. This includes blitting, scaling and other operations which
 * are needed in order to compose the final frames. The renderer internally works
 * in BRGA32 mode (as this is what the native framebuffer in VirtualBox looks
 * like) and handles conversions to other formats (i.e. YUVI420 for VPX).
 *
 * Renderer backends can make use of accelerated GPU features / advanced APIs.
 * A pure software fallback is provided if probing selected backends fail.
 */

/*
 * Copyright (C) 2026 Oracle and/or its affiliates.
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

#ifdef LOG_GROUP
# undef LOG_GROUP
#endif
#define LOG_GROUP LOG_GROUP_RECORDING
#include "LoggingNew.h"

#include "RecordingRender.h"
#include "RecordingInternals.h"
#include "RecordingUtils.h"

#include <iprt/ldr.h>
#include <iprt/mem.h>

#ifdef VBOX_WITH_RECORDING_SDL_BACKEND
# include <SDL.h>
#endif


/*********************************************************************************************************************************
 * Software renderer backend                                                                                                     *
 ********************************************************************************************************************************/

/**
 * SW backend private state.
 */
typedef struct RECORDINGRENDERSW
{
} RECORDINGRENDERSW;

#if 0 /* Unused */
/**
 * Wraps a software RECORDINGVIDEOFRAME into a generic renderer texture.
 *
 * @param   pTexture            Texture wrapper to initialize.
 * @param   pFrame              Software frame backing the texture.
 */
DECLINLINE(void) recRenderSWFrm2Tex(PRECORDINGRENDERTEXTURE pTexture, PRECORDINGVIDEOFRAME pFrame)
{
#ifdef VBOX_STRICT
    AssertPtrReturnVoid(pTexture);
    AssertPtrReturnVoid(pFrame);
#endif

    pTexture->pvBackend = pFrame;
    pTexture->pInfo     = &pFrame->Info;
}
#endif

/**
 * Resolves generic renderer texture reference to a software RECORDINGVIDEOFRAME.
 *
 * @returns Software frame backing @a pTexture, or NULL on invalid input.
 * @param   pTexture            Texture wrapper to resolve.
 */
DECLINLINE(PRECORDINGVIDEOFRAME) recRenderSWTex2Frm(PRECORDINGRENDERTEXTURE pTexture)
{
#ifdef VBOX_STRICT
    AssertPtrReturn(pTexture, NULL);
#endif
    return (PRECORDINGVIDEOFRAME)pTexture->pvBackend;
}

/**
 * Resolves generic renderer texture reference to a const software RECORDINGVIDEOFRAME.
 *
 * @returns Const software frame backing @a pTexture, or NULL on invalid input.
 * @param   pTexture            Texture wrapper to resolve.
 */
DECLINLINE(RECORDINGVIDEOFRAME const *) recRenderSWTex2FrmC(PCRECORDINGRENDERTEXTURE pTexture)
{
#ifdef VBOX_STRICT
    AssertPtrReturn(pTexture, NULL);
#endif
    return (RECORDINGVIDEOFRAME const *)pTexture->pvBackend;
}

#if 0 /* Unused */
/**
 * Nearest-neighbor resize helper for BGRA32 source frames.
 *
 * @returns VBox status code.
 * @param   pSrcFrame           Source frame.
 * @param   pRenderParms        Renderer parameters.
 * @param   ppu8Tmp             Where to return allocated resized frame buffer.
 * @param   pcbTmp              Where to return size of @a *ppu8Tmp.
 * @param   pResizeInfo         Where to return source/destination resize rectangles.
 */
DECLINLINE(int) recRenderSWFrameResizeNNeighbor(RECORDINGVIDEOFRAME const *pSrcFrame,
                                                PRECORDINGRENDERPARMS pRenderParms,
                                                uint8_t **ppu8Tmp, size_t *pcbTmp,
                                                RECORDINGRENDERRESIZEPARMS *pResizeInfo)
{
#ifdef VBOX_STRICT /* Skip in release builds for speed reasons. */
    AssertPtrReturn(pSrcFrame, VERR_INVALID_POINTER);
    AssertPtrReturn(pRenderParms, VERR_INVALID_POINTER);
    AssertPtrReturn(ppu8Tmp, VERR_INVALID_POINTER);
    AssertPtrReturn(pcbTmp, VERR_INVALID_POINTER);
    AssertPtrReturn(pResizeInfo, VERR_INVALID_POINTER);

    if (pSrcFrame->Info.uBPP != 32)
        return VERR_NOT_SUPPORTED;
#endif

    uint32_t const uSrcW = pSrcFrame->Info.uWidth;
    uint32_t const uSrcH = pSrcFrame->Info.uHeight;
    uint32_t const uDstW = pRenderParms->Info.uWidth;
    uint32_t const uDstH = pRenderParms->Info.uHeight;

#ifdef VBOX_STRICT /* Ditto. */
    if (!uSrcW || !uSrcH || !uDstW || !uDstH)
        return VERR_INVALID_PARAMETER;
#endif

    size_t const cbTmp = (size_t)uDstW * uDstH * 4;
    uint8_t *pu8Tmp = (uint8_t *)RTMemAlloc(cbTmp);
    AssertPtrReturn(pu8Tmp, VERR_NO_MEMORY);

    uint32_t const cbSrcStride = pSrcFrame->Info.uBytesPerLine;
    uint32_t const cbDstStride = uDstW * 4;

    /*
     * Map each destination pixel to nearest source pixel.
     *
     * Use edge-aligned endpoint mapping with rounding so that:
     *   - the first destination pixel maps to the first source pixel,
     *   - the last destination pixel maps to the last source pixel,
     * while avoiding the top-left bias of plain floor(x * src / dst).
     */
    for (uint32_t yDst = 0; yDst < uDstH; yDst++)
    {
        uint32_t const ySrc = uSrcH > 1 && uDstH > 1
                            ? (uint32_t)((((uint64_t)yDst * (uSrcH - 1)) + ((uDstH - 1) / 2)) / (uDstH - 1))
                            : 0;
        uint8_t const *pu8SrcLine = pSrcFrame->pau8Buf + (size_t)ySrc * cbSrcStride;
        uint8_t       *pu8DstLine = pu8Tmp + (size_t)yDst * cbDstStride;

        for (uint32_t xDst = 0; xDst < uDstW; xDst++)
        {
            uint32_t const xSrc = uSrcW > 1 && uDstW > 1
                                ? (uint32_t)((((uint64_t)xDst * (uSrcW - 1)) + ((uDstW - 1) / 2)) / (uDstW - 1))
                                : 0;
            uint8_t const *pu8Src = pu8SrcLine + (size_t)xSrc * 4;
            uint8_t       *pu8Dst = pu8DstLine + (size_t)xDst * 4;

            pu8Dst[0] = pu8Src[0];
            pu8Dst[1] = pu8Src[1];
            pu8Dst[2] = pu8Src[2];
            pu8Dst[3] = pu8Src[3];
        }
    }

    *ppu8Tmp = pu8Tmp;
    *pcbTmp  = cbTmp;

    pResizeInfo->srcRect.xLeft   = 0;
    pResizeInfo->srcRect.yTop    = 0;
    pResizeInfo->srcRect.xRight  = (int32_t)uDstW;
    pResizeInfo->srcRect.yBottom = (int32_t)uDstH;
    pResizeInfo->dstRect.xLeft   = 0;
    pResizeInfo->dstRect.yTop    = 0;
    pResizeInfo->dstRect.xRight  = (int32_t)uDstW;
    pResizeInfo->dstRect.yBottom = (int32_t)uDstH;

    return VINF_SUCCESS;
}
#endif

/**
 * Renderer-local crop/center calculation independent from codec internals.
 *
 * @returns VBox status code.
 * @param   pDstFrame           Destination frame that will receive the copied region.
 * @param   pSrcFrame           Source frame that may be cropped or centered.
 * @param   pDstRect            Returns destination placement rectangle in @a pDstFrame.
 * @param   pSrcRect            Returns source crop rectangle in @a pSrcFrame.
 */
DECLINLINE(int) recRenderSWFrameResizeCropCenter(RECORDINGVIDEOFRAME const *pDstFrame,
                                                 RECORDINGVIDEOFRAME const *pSrcFrame,
                                                 PRTRECT pDstRect, PRTRECT pSrcRect)
{
#ifdef VBOX_STRICT /* Skip in release builds for speed reasons. */
    AssertPtrReturn(pDstFrame, VERR_INVALID_POINTER);
    AssertPtrReturn(pSrcFrame, VERR_INVALID_POINTER);
    AssertPtrReturn(pDstRect,  VERR_INVALID_POINTER);
    AssertPtrReturn(pSrcRect,  VERR_INVALID_POINTER);
#endif

    int32_t const cxSrc = (int32_t)pSrcFrame->Info.uWidth;
    int32_t const cySrc = (int32_t)pSrcFrame->Info.uHeight;
    int32_t const cxDst = (int32_t)pDstFrame->Info.uWidth;
    int32_t const cyDst = (int32_t)pDstFrame->Info.uHeight;

    pSrcRect->xLeft = pSrcRect->yTop = pSrcRect->xRight = pSrcRect->yBottom = 0;
    pDstRect->xLeft = pDstRect->yTop = pDstRect->xRight = pDstRect->yBottom = 0;

    if (   cxSrc <= 0
        || cySrc <= 0
        || cxDst <= 0
        || cyDst <= 0)
        return VWRN_RECORDING_ENCODING_SKIPPED;

    int32_t const cxCopy = RT_MIN(cxSrc, cxDst);
    int32_t const cyCopy = RT_MIN(cySrc, cyDst);
    if (   cxCopy <= 0
        || cyCopy <= 0)
        return VWRN_RECORDING_ENCODING_SKIPPED;

    pSrcRect->xLeft   = RT_MAX((cxSrc - cxDst) / 2, 0);
    pSrcRect->yTop    = RT_MAX((cySrc - cyDst) / 2, 0);
    pSrcRect->xRight  = pSrcRect->xLeft + cxCopy;
    pSrcRect->yBottom = pSrcRect->yTop  + cyCopy;

    pDstRect->xLeft   = RT_MAX((cxDst - cxSrc) / 2, 0);
    pDstRect->yTop    = RT_MAX((cyDst - cySrc) / 2, 0);
    pDstRect->xRight  = pDstRect->xLeft + cxCopy;
    pDstRect->yBottom = pDstRect->yTop  + cyCopy;

    Log3Func(("Crop/Center: src=%RU32x%RU32 dst=%RU32x%RU32 -> srcRect={%RI32,%RI32,%RI32,%RI32} dstRect={%RI32,%RI32,%RI32,%RI32}\n",
              pSrcFrame->Info.uWidth, pSrcFrame->Info.uHeight,
              pDstFrame->Info.uWidth, pDstFrame->Info.uHeight,
              pSrcRect->xLeft, pSrcRect->yTop, pSrcRect->xRight, pSrcRect->yBottom,
              pDstRect->xLeft, pDstRect->yTop, pDstRect->xRight, pDstRect->yBottom));

    return VINF_SUCCESS;
}

/**
 * Renderer-local nearest-neighbor resize independent from codec internals.
 *
 * @returns VBox status code.
 * @param   pDstFrame           Destination frame that will receive the scaled region.
 * @param   pSrcFrame           Source frame to scale from.
 * @param   pDstRect            Destination rectangle in @a pDstFrame.
 * @param   pSrcRect            Source rectangle in @a pSrcFrame.
 */
DECLINLINE(int) recRenderSWFrameResizeNearestNeighbor(PRECORDINGVIDEOFRAME pDstFrame,
                                                      RECORDINGVIDEOFRAME const *pSrcFrame,
                                                      RTRECT const *pDstRect,
                                                      RTRECT const *pSrcRect)
{
#ifdef VBOX_STRICT /* Skip in release builds for speed reasons. */
    AssertPtrReturn(pDstFrame, VERR_INVALID_POINTER);
    AssertPtrReturn(pSrcFrame, VERR_INVALID_POINTER);
    AssertPtrReturn(pDstRect,  VERR_INVALID_POINTER);
    AssertPtrReturn(pSrcRect,  VERR_INVALID_POINTER);
#endif

    int32_t const sx = pSrcRect->xLeft;
    int32_t const sy = pSrcRect->yTop;
    int32_t const sw = pSrcRect->xRight  - pSrcRect->xLeft;
    int32_t const sh = pSrcRect->yBottom - pSrcRect->yTop;
    int32_t const dx = pDstRect->xLeft;
    int32_t const dy = pDstRect->yTop;
    int32_t const dw = pDstRect->xRight  - pDstRect->xLeft;
    int32_t const dh = pDstRect->yBottom - pDstRect->yTop;

#ifdef VBOX_STRICT /* Ditto. */
    AssertReturn(sw > 0 && sh > 0 && dw > 0 && dh > 0, VERR_INVALID_PARAMETER);
    AssertReturn((uint32_t)(dx + dw) <= pDstFrame->Info.uWidth, VERR_INVALID_PARAMETER);
    AssertReturn((uint32_t)(dy + dh) <= pDstFrame->Info.uHeight, VERR_INVALID_PARAMETER);
    AssertReturn((uint32_t)(sx + sw) <= pSrcFrame->Info.uWidth, VERR_INVALID_PARAMETER);
    AssertReturn((uint32_t)(sy + sh) <= pSrcFrame->Info.uHeight, VERR_INVALID_PARAMETER);
#endif

    uint32_t const cbPixel = RT_MAX((uint32_t)pSrcFrame->Info.uBPP / 8, 1U);
    uint32_t const uSw = (uint32_t)sw;
    uint32_t const uSh = (uint32_t)sh;
    uint32_t const uDw = (uint32_t)dw;
    uint32_t const uDh = (uint32_t)dh;

    for (uint32_t yDst = 0; yDst < (uint32_t)dh; yDst++)
    {
        uint32_t const ySrc = (uint32_t)sy
                            + (   uSh > 1
                               && uDh > 1
                               ? (uint32_t)((((uint64_t)yDst * (uSh - 1)) + ((uDh - 1) / 2)) / (uDh - 1))
                               : 0);
        uint8_t const *pu8SrcLine = pSrcFrame->pau8Buf + (size_t)ySrc * pSrcFrame->Info.uBytesPerLine;
        uint8_t       *pu8DstLine = pDstFrame->pau8Buf
                                  + ((size_t)dy + yDst) * pDstFrame->Info.uBytesPerLine
                                  + (size_t)dx * cbPixel;

        for (uint32_t xDst = 0; xDst < (uint32_t)dw; xDst++)
        {
            uint32_t const xSrc = (uint32_t)sx
                                + (   uSw > 1
                                   && uDw > 1
                                   ? (uint32_t)((((uint64_t)xDst * (uSw - 1)) + ((uDw - 1) / 2)) / (uDw - 1))
                                   : 0);
            uint8_t const *pu8Src = pu8SrcLine + (size_t)xSrc * cbPixel;
            uint8_t       *pu8Dst = pu8DstLine + (size_t)xDst * cbPixel;
            memcpy(pu8Dst, pu8Src, cbPixel);
        }
    }

    return VINF_SUCCESS;
}

#ifdef TESTCASE
/**
 * TESTCASE wrapper exposing crop/center rectangle computation.
 *
 * @returns VBox status code.
 * @param   pDstFrame           Destination frame definition.
 * @param   pSrcFrame           Source frame definition.
 * @param   pDstRect            Receives destination rectangle.
 * @param   pSrcRect            Receives source rectangle.
 */
int RecordingRenderSWFrameResizeCropCenter(RECORDINGVIDEOFRAME const *pDstFrame,
                                           RECORDINGVIDEOFRAME const *pSrcFrame,
                                           PRTRECT pDstRect, PRTRECT pSrcRect)
{
    return recRenderSWFrameResizeCropCenter(pDstFrame, pSrcFrame, pDstRect, pSrcRect);
}
#endif

/** @copydoc RECORDINGRENDEROPS::pfnInit */
static DECLCALLBACK(int) recRenderSWInit(PRECORDINGRENDERER pRenderer, const void *pvBackend)
{
    RT_NOREF(pRenderer, pvBackend);
    return VINF_SUCCESS;
}

/** @copydoc RECORDINGRENDEROPS::pfnDestroy */
static DECLCALLBACK(void) recRenderSWDestroy(PRECORDINGRENDERER pRenderer)
{
    RT_NOREF(pRenderer);
}

/** @copydoc RECORDINGRENDEROPS::pfnQueryCaps */
static DECLCALLBACK(uint64_t) recRenderSWQueryCaps(PCRECORDINGRENDERER pRenderer)
{
    RT_NOREF(pRenderer);
    return   RECORDINGRENDERCAP_F_BLIT_RAW
           | RECORDINGRENDERCAP_F_BLIT_FRAME
           | RECORDINGRENDERCAP_F_BLEND_ALPHA
           | RECORDINGRENDERCAP_F_RESIZE
           | RECORDINGRENDERCAP_F_CONVERT;
}

/** @copydoc RECORDINGRENDEROPS::pfnTextureCreate */
static DECLCALLBACK(int) recRenderSWTextureCreate(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture,
                                                  PRECORDINGSURFACEINFO pInfo)
{
    RT_NOREF(pRenderer);

    PRECORDINGVIDEOFRAME pFrame = RecordingVideoFrameAlloc();
    AssertPtrReturn(pFrame, VERR_NO_MEMORY);

    int vrc = RecordingVideoFrameInit(pFrame, RECORDINGVIDEOFRAME_F_VISIBLE,
                                      pInfo->uWidth, pInfo->uHeight, 0, 0,
                                      pInfo->uBPP, pInfo->enmPixelFmt);
    if (RT_SUCCESS(vrc))
    {
        pTexture->pvBackend = pFrame;
        pTexture->pInfo     = &pFrame->Info;
    }

    return vrc;
}

/** @copydoc RECORDINGRENDEROPS::pfnTextureDestroy */
static DECLCALLBACK(void) recRenderSWTextureDestroy(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture)
{
    RT_NOREF(pRenderer);

    PRECORDINGVIDEOFRAME pFrame = (PRECORDINGVIDEOFRAME)pTexture->pvBackend;
    RecordingVideoFrameFree(pFrame);
    pTexture->pvBackend = NULL;
}

/** @copydoc RECORDINGRENDEROPS::pfnTextureClear */
static DECLCALLBACK(void) recRenderSWTextureClear(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture)
{
    RT_NOREF(pRenderer);

    PRECORDINGVIDEOFRAME const pFrame = (PRECORDINGVIDEOFRAME)pTexture->pvBackend;
    RT_BZERO(pFrame->pau8Buf, pFrame->cbBuf);
}

/** @copydoc RECORDINGRENDEROPS::pfnTextureQueryPixelData */
static DECLCALLBACK(int) recRenderSWTextureQueryPixelData(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture,
                                                          void **ppvBuf, size_t *pcbBuf)
{
    RT_NOREF(pRenderer);

    PRECORDINGVIDEOFRAME pFrame = recRenderSWTex2Frm(pTexture);

    *ppvBuf = pFrame->pau8Buf;
    *pcbBuf = pFrame->cbBuf;

#ifdef VBOX_RECORDING_DEBUG_DUMP_FRAMES
    RecordingDbgDumpVideoFrame(pFrame, "render-sw-tex-query-pixeldata", 0);
#endif

    return VINF_SUCCESS;
}

/** @copydoc RECORDINGRENDEROPS::pfnTextureUpdate */
static DECLCALLBACK(int) recRenderSWTextureUpdate(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture,
                                                  PRECORDINGVIDEOFRAME pFrame)
{
    RT_NOREF(pRenderer);

    PRECORDINGVIDEOFRAME pFrameToUpdate = recRenderSWTex2Frm(pTexture);
    AssertPtr(pFrameToUpdate);

    /* For this software backend we already use RECORDINGVIDEOFRAME as a backend storage, so just (shallow) copy the data over. */
    memcpy(pFrameToUpdate, pFrame, sizeof(RECORDINGVIDEOFRAME));
    pFrameToUpdate->fFlags |= RECORDINGVIDEOFRAME_F_NO_DESTROY;

    return VINF_SUCCESS;
}

/** @copydoc RECORDINGRENDEROPS::pfnBlit */
static DECLCALLBACK(int) recRenderSWBlit(PRECORDINGRENDERER pRenderer,
                                         PRECORDINGRENDERTEXTURE pDstTexture, PRTRECT pDstRect,
                                         PCRECORDINGRENDERTEXTURE pSrcTexture, PRTRECT pSrcRect)
{
    RT_NOREF(pRenderer);

    PRECORDINGVIDEOFRAME pDstFrame = recRenderSWTex2Frm(pDstTexture);
    RECORDINGVIDEOFRAME const *pSrcFrame = recRenderSWTex2FrmC(pSrcTexture);

    uint32_t const uSrcX = pSrcRect ? (uint32_t)RT_MAX(pSrcRect->xLeft, 0) : 0;
    uint32_t const uSrcY = pSrcRect ? (uint32_t)RT_MAX(pSrcRect->yTop,  0) : 0;
    uint32_t const uDstX = pDstRect ? (uint32_t)RT_MAX(pDstRect->xLeft, 0) : 0;
    uint32_t const uDstY = pDstRect ? (uint32_t)RT_MAX(pDstRect->yTop,  0) : 0;

    uint32_t const uSrcWidth  = pSrcRect ? (uint32_t)RT_MAX(pSrcRect->xRight  - pSrcRect->xLeft, 0)
                                         : pSrcFrame->Info.uWidth;
    uint32_t const uSrcHeight = pSrcRect ? (uint32_t)RT_MAX(pSrcRect->yBottom - pSrcRect->yTop,  0)
                                         : pSrcFrame->Info.uHeight;

    Assert(pSrcFrame->Info.enmPixelFmt == pDstFrame->Info.enmPixelFmt);
    Assert(pSrcFrame->Info.uBPP == pDstFrame->Info.uBPP);

    if (   uSrcX >= pSrcFrame->Info.uWidth
        || uSrcY >= pSrcFrame->Info.uHeight
        || uDstX >= pDstFrame->Info.uWidth
        || uDstY >= pDstFrame->Info.uHeight)
        return VINF_SUCCESS;

    uint32_t const cbPixel = RT_MAX((uint32_t)pSrcFrame->Info.uBPP / 8, 1U);
    uint32_t const cx = RT_MIN(uSrcWidth,  pSrcFrame->Info.uWidth  - uSrcX);
    uint32_t const cy = RT_MIN(uSrcHeight, pSrcFrame->Info.uHeight - uSrcY);
    uint32_t const cxDst = RT_MIN(cx, pDstFrame->Info.uWidth  - uDstX);
    uint32_t const cyDst = RT_MIN(cy, pDstFrame->Info.uHeight - uDstY);
    size_t   const cbRow = (size_t)cxDst * cbPixel;

    for (uint32_t y = 0; y < cyDst; y++)
    {
        size_t const offSrc = ((size_t)uSrcY + y) * pSrcFrame->Info.uBytesPerLine + (size_t)uSrcX * cbPixel;
        size_t const offDst = ((size_t)uDstY + y) * pDstFrame->Info.uBytesPerLine + (size_t)uDstX * cbPixel;

        memcpy(&pDstFrame->pau8Buf[offDst], &pSrcFrame->pau8Buf[offSrc], cbRow);
    }

#ifdef VBOX_RECORDING_DEBUG_DUMP_FRAMES
    RecordingDbgDumpVideoFrame(pDstFrame, "render-sw-blit", 0);
#endif

    return VINF_SUCCESS;
}

/** @copydoc RECORDINGRENDEROPS::pfnBlend */
static DECLCALLBACK(int) recRenderSWBlend(PRECORDINGRENDERER pRenderer,
                                          PRECORDINGRENDERTEXTURE pDstTexture, PRTRECT pSrcRect,
                                          PRECORDINGRENDERTEXTURE pSrcTexture, PRTRECT pDstRect)
{
    PRECORDINGVIDEOFRAME pDstFrame = recRenderSWTex2Frm(pDstTexture);
    RECORDINGVIDEOFRAME const *pSrcFrame = recRenderSWTex2FrmC(pSrcTexture);

    RT_NOREF(pRenderer);

    uint32_t const uSrcX = pSrcRect ? (uint32_t)RT_MAX(pSrcRect->xLeft, 0) : 0;
    uint32_t const uSrcY = pSrcRect ? (uint32_t)RT_MAX(pSrcRect->yTop,  0) : 0;
    uint32_t const uDstX = pDstRect ? (uint32_t)RT_MAX(pDstRect->xLeft, 0) : 0;
    uint32_t const uDstY = pDstRect ? (uint32_t)RT_MAX(pDstRect->yTop,  0) : 0;
    uint32_t const uSrcWidth  = pSrcRect ? (uint32_t)RT_MAX(pSrcRect->xRight  - pSrcRect->xLeft, 0)
                                         : pSrcFrame->Info.uWidth;
    uint32_t const uSrcHeight = pSrcRect ? (uint32_t)RT_MAX(pSrcRect->yBottom - pSrcRect->yTop,  0)
                                         : pSrcFrame->Info.uHeight;

    AssertReturn(pSrcFrame->Info.enmPixelFmt == RECORDINGPIXELFMT_BRGA32, VERR_INVALID_PARAMETER);
    AssertReturn(pDstFrame->Info.enmPixelFmt == RECORDINGPIXELFMT_BRGA32, VERR_INVALID_PARAMETER);
    AssertReturn(pSrcFrame->Info.uBPP == 32, VERR_INVALID_PARAMETER);
    AssertReturn(pDstFrame->Info.uBPP == 32, VERR_INVALID_PARAMETER);

    if (   uSrcX >= pSrcFrame->Info.uWidth
        || uSrcY >= pSrcFrame->Info.uHeight
        || uDstX >= pDstFrame->Info.uWidth
        || uDstY >= pDstFrame->Info.uHeight)
        return VINF_SUCCESS;

    uint32_t const cx = RT_MIN(uSrcWidth,  pSrcFrame->Info.uWidth  - uSrcX);
    uint32_t const cy = RT_MIN(uSrcHeight, pSrcFrame->Info.uHeight - uSrcY);
    uint32_t const cxDst = RT_MIN(cx, pDstFrame->Info.uWidth  - uDstX);
    uint32_t const cyDst = RT_MIN(cy, pDstFrame->Info.uHeight - uDstY);

    for (uint32_t y = 0; y < cyDst; y++)
    {
        size_t const offSrc = ((size_t)uSrcY + y) * pSrcFrame->Info.uBytesPerLine + (size_t)uSrcX * 4;
        size_t const offDst = ((size_t)uDstY + y) * pDstFrame->Info.uBytesPerLine + (size_t)uDstX * 4;

        uint8_t const *pu8Src = &pSrcFrame->pau8Buf[offSrc];
        uint8_t       *pu8Dst = &pDstFrame->pau8Buf[offDst];
        for (uint32_t x = 0; x < cxDst; x++)
        {
            uint8_t const uAlpha = pu8Src[3];
            if (uAlpha == 255)
            {
                pu8Dst[0] = pu8Src[0];
                pu8Dst[1] = pu8Src[1];
                pu8Dst[2] = pu8Src[2];
                pu8Dst[3] = pu8Src[3];
            }
            else if (uAlpha != 0)
            {
                uint32_t const uInvAlpha = 255 - uAlpha;
                pu8Dst[0] = (uint8_t)((pu8Src[0] * uAlpha + pu8Dst[0] * uInvAlpha) / 255);
                pu8Dst[1] = (uint8_t)((pu8Src[1] * uAlpha + pu8Dst[1] * uInvAlpha) / 255);
                pu8Dst[2] = (uint8_t)((pu8Src[2] * uAlpha + pu8Dst[2] * uInvAlpha) / 255);
                pu8Dst[3] = (uint8_t)((pu8Src[3] * uAlpha + pu8Dst[3] * uInvAlpha) / 255);
            }

            pu8Src += 4;
            pu8Dst += 4;
        }
    }

    return VINF_SUCCESS;
}

/** @copydoc RECORDINGRENDEROPS::pfnResize */
static DECLCALLBACK(int) recRenderSWResize(PRECORDINGRENDERER pRenderer,
                                           PRECORDINGRENDERTEXTURE pDstTexture,
                                           PCRECORDINGRENDERTEXTURE pSrcTexture,
                                           PRECORDINGRENDERRESIZEPARMS pResizeParms)
{
    RECORDINGVIDEOFRAME const *pSrcFrame = recRenderSWTex2FrmC(pSrcTexture);
    PRECORDINGVIDEOFRAME pDstFrame = recRenderSWTex2Frm(pDstTexture);

    /* Default source geometry is the full input frame. */
    int32_t sx = 0;
    int32_t sy = 0;
    int32_t sw = (int32_t)pSrcFrame->Info.uWidth;
    int32_t sh = (int32_t)pSrcFrame->Info.uHeight;
    int32_t dx = 0;
    int32_t dy = 0;
    int32_t dw = sw;
    int32_t dh = sh;

    int vrc = VINF_SUCCESS;

    switch (pResizeParms->enmMode)
    {
        case RecordingVideoScalingMode_NearestNeighbor:
        {
            dw = pRenderer->Parms.Info.uWidth;
            dh = pRenderer->Parms.Info.uHeight;
            break;
        }

        /* Other scaling methods are not implemented yet, so default to cropping / centering. */
        case RecordingVideoScalingMode_None:
        default:
        {
            RTRECT DstRect;
            RTRECT SrcRect;
            vrc = recRenderSWFrameResizeCropCenter(pDstFrame, pSrcFrame, &DstRect, &SrcRect);
            if (RT_SUCCESS(vrc))
            {
                sx = SrcRect.xLeft;
                sy = SrcRect.yTop;
                sw = SrcRect.xRight  - SrcRect.xLeft;
                sh = SrcRect.yBottom - SrcRect.yTop;

                dx = DstRect.xLeft;
                dy = DstRect.yTop;
                dw = DstRect.xRight  - DstRect.xLeft;
                dh = DstRect.yBottom - DstRect.yTop;
            }
            break;
        }
    }

    pResizeParms->srcRect.xLeft   = sx;
    pResizeParms->srcRect.yTop    = sy;
    pResizeParms->srcRect.xRight  = sx + sw;
    pResizeParms->srcRect.yBottom = sy + sh;
    pResizeParms->dstRect.xLeft   = dx;
    pResizeParms->dstRect.yTop    = dy;
    pResizeParms->dstRect.xRight  = dx + dw;
    pResizeParms->dstRect.yBottom = dy + dh;

    if (RT_FAILURE(vrc))
        return vrc;

    if (vrc == VWRN_RECORDING_ENCODING_SKIPPED)
        return vrc;

#ifdef VBOX_STRICT
    AssertReturn(pSrcFrame->Info.enmPixelFmt == pDstFrame->Info.enmPixelFmt, VERR_INVALID_PARAMETER);
    AssertReturn(pSrcFrame->Info.uBPP == pDstFrame->Info.uBPP, VERR_INVALID_PARAMETER);
    AssertReturn(sw > 0 && sh > 0 && dw > 0 && dh > 0, VERR_INVALID_PARAMETER);
    AssertReturn((uint32_t)(dx + dw) <= pDstFrame->Info.uWidth, VERR_INVALID_PARAMETER);
    AssertReturn((uint32_t)(dy + dh) <= pDstFrame->Info.uHeight, VERR_INVALID_PARAMETER);
    AssertReturn((uint32_t)(sx + sw) <= pSrcFrame->Info.uWidth, VERR_INVALID_PARAMETER);
    AssertReturn((uint32_t)(sy + sh) <= pSrcFrame->Info.uHeight, VERR_INVALID_PARAMETER);
    AssertReturn(pDstFrame != pSrcFrame, VERR_INVALID_PARAMETER);
#endif

    RecordingVideoFrameClear(pDstFrame);

    uint32_t const cbPixel = RT_MAX((uint32_t)pSrcFrame->Info.uBPP / 8, 1U);

    if (pResizeParms->enmMode == RecordingVideoScalingMode_NearestNeighbor)
    {
        vrc = recRenderSWFrameResizeNearestNeighbor(pDstFrame, pSrcFrame,
                                                    &pResizeParms->dstRect, &pResizeParms->srcRect);
        AssertRC(vrc);
        if (RT_FAILURE(vrc))
            return vrc;
    }
    else
    {
        size_t const cbCopy = (size_t)sw * cbPixel;
        for (uint32_t y = 0; y < (uint32_t)sh; y++)
        {
            uint8_t const *pu8Src = pSrcFrame->pau8Buf
                                   + ((size_t)sy + y) * pSrcFrame->Info.uBytesPerLine
                                   + (size_t)sx * cbPixel;
            uint8_t       *pu8Dst = pDstFrame->pau8Buf
                                   + ((size_t)dy + y) * pDstFrame->Info.uBytesPerLine
                                   + (size_t)dx * cbPixel;
            memcpy(pu8Dst, pu8Src, cbCopy);
        }
    }

#ifdef VBOX_RECORDING_DEBUG_DUMP_FRAMES
    RecordingDbgDumpVideoFrame(pDstFrame, "render-sw-resized", pRenderer->msLastRenderedTS);
#endif

    return VINF_SUCCESS;
}

/**
 * Converts a part of a RGB BGRA32 buffer to a YUV I420 buffer.
 *
 * @param   paDst               Pointer to destination buffer.
 * @param   uDstX               X destination position (in pixel).
 * @param   uDstY               Y destination position (in pixel).
 * @param   uDstWidth           Width (X, in pixel) of destination buffer.
 * @param   uDstHeight          Height (Y, in pixel) of destination buffer.
 * @param   paSrc               Pointer to source buffer.
 * @param   uSrcX               X source position (in pixel).
 * @param   uSrcY               Y source position (in pixel).
 * @param   uSrcWidth           Width (X, in pixel) of source buffer.
 * @param   uSrcHeight          Height (Y, in pixel) of source buffer.
 * @param   uSrcStride          Stride (in bytes) of source buffer.
 * @param   uSrcBPP             Bits per pixel of source buffer.
 */
DECLINLINE(void) recRenderSWConvertBGRA32ToYUVI420(uint8_t *paDst, uint32_t uDstX, uint32_t uDstY, uint32_t uDstWidth, uint32_t uDstHeight,
                                                   uint8_t *paSrc, uint32_t uSrcX, uint32_t uSrcY, uint32_t uSrcWidth, uint32_t uSrcHeight,
                                                   uint32_t uSrcStride, uint8_t uSrcBPP)
{
#ifdef VBOX_STRICT
    AssertReturnVoid(uDstX < uDstWidth);
    AssertReturnVoid(uDstX + uSrcWidth <= uDstWidth);
    AssertReturnVoid(uDstY < uDstHeight);
    AssertReturnVoid(uDstY + uSrcHeight <= uDstHeight);
    AssertReturnVoid(uSrcBPP % 8 == 0);
    AssertReturnVoid(uSrcWidth);
    AssertReturnVoid(uSrcHeight);
    AssertReturnVoid((uDstWidth & 1) == 0);
    AssertReturnVoid((uDstHeight & 1) == 0);
#endif

#define CALC_Y(r, g, b) \
    (66 * r + 129 * g + 25 * b) >> 8
#define CALC_U(r, g, b) \
    ((-38 * r + -74 * g + 112 * b) >> 8) + 128
#define CALC_V(r, g, b) \
    ((112 * r + -94 * g + -18 * b) >> 8) + 128

    const unsigned uSrcBytesPerPixel = uSrcBPP / 8;
    size_t const cbDstLumaPlane = (size_t)uDstWidth * uDstHeight;
    uint8_t *const pu8DstY = paDst;
    uint8_t *const pu8DstU = paDst + cbDstLumaPlane;
    uint8_t *const pu8DstV = pu8DstU + cbDstLumaPlane / 4;
    uint32_t const uDstChromaWidth  = uDstWidth / 2;
    uint32_t const uDstChromaHeight = uDstHeight / 2;

    /*
     * Fast single-pass 2x2 conversion for the common full-frame path.
     *
     * For unaligned sub-rectangles, keep a generic fallback below.
     */
    bool const fAligned2x2Path =    (uDstX & 1) == 0
                                 && (uDstY & 1) == 0
                                 && (uSrcX & 1) == 0
                                 && (uSrcY & 1) == 0;

    if (fAligned2x2Path)
    {
        uint32_t const uSrcXLast = uSrcX + uSrcWidth  - 1;
        uint32_t const uSrcYLast = uSrcY + uSrcHeight - 1;

        for (uint32_t y = 0; y < uSrcHeight; y += 2)
        {
            uint32_t const uY0Src = uSrcY + y;
            uint32_t const uY1Src = RT_MIN(uY0Src + 1, uSrcYLast);
            uint32_t const uY0Dst = uDstY + y;
            uint32_t const uYDstChroma = uY0Dst / 2;
            if (uYDstChroma >= uDstChromaHeight)
                break;

            uint8_t const *pu8SrcRow0 = paSrc + (size_t)uY0Src * uSrcStride;
            uint8_t const *pu8SrcRow1 = paSrc + (size_t)uY1Src * uSrcStride;

            uint8_t *pu8DstYRow0 = pu8DstY + (size_t)uY0Dst * uDstWidth + uDstX;
            uint8_t *pu8DstYRow1 = NULL;
            if (y + 1 < uSrcHeight)
                pu8DstYRow1 = pu8DstY + (size_t)(uY0Dst + 1) * uDstWidth + uDstX;

            uint8_t *pu8DstURow = pu8DstU + (size_t)uYDstChroma * uDstChromaWidth;
            uint8_t *pu8DstVRow = pu8DstV + (size_t)uYDstChroma * uDstChromaWidth;

            for (uint32_t x = 0; x < uSrcWidth; x += 2)
            {
                uint32_t const uX0Src = uSrcX + x;
                uint32_t const uX1Src = RT_MIN(uX0Src + 1, uSrcXLast);
                uint32_t const uXDstChroma = (uDstX + x) / 2;
                if (uXDstChroma >= uDstChromaWidth)
                    break;

                uint8_t const *pu8Src00 = pu8SrcRow0 + (size_t)uX0Src * uSrcBytesPerPixel;
                uint8_t const *pu8Src01 = pu8SrcRow0 + (size_t)uX1Src * uSrcBytesPerPixel;
                uint8_t const *pu8Src10 = pu8SrcRow1 + (size_t)uX0Src * uSrcBytesPerPixel;
                uint8_t const *pu8Src11 = pu8SrcRow1 + (size_t)uX1Src * uSrcBytesPerPixel;

                int32_t const iY00 = (int32_t)CALC_Y(pu8Src00[2], pu8Src00[1], pu8Src00[0]);
                int32_t const iY01 = (int32_t)CALC_Y(pu8Src01[2], pu8Src01[1], pu8Src01[0]);
                int32_t const iY10 = (int32_t)CALC_Y(pu8Src10[2], pu8Src10[1], pu8Src10[0]);
                int32_t const iY11 = (int32_t)CALC_Y(pu8Src11[2], pu8Src11[1], pu8Src11[0]);

                pu8DstYRow0[x] = (uint8_t)RT_MIN(RT_MAX(iY00, 0), 255);
                if (x + 1 < uSrcWidth)
                    pu8DstYRow0[x + 1] = (uint8_t)RT_MIN(RT_MAX(iY01, 0), 255);
                if (pu8DstYRow1)
                {
                    pu8DstYRow1[x] = (uint8_t)RT_MIN(RT_MAX(iY10, 0), 255);
                    if (x + 1 < uSrcWidth)
                        pu8DstYRow1[x + 1] = (uint8_t)RT_MIN(RT_MAX(iY11, 0), 255);
                }

                int32_t const iBAvg = (int32_t)(  (pu8Src00[0]
                                                  + pu8Src01[0]
                                                  + pu8Src10[0]
                                                  + pu8Src11[0]
                                                  + 2) / 4);
                int32_t const iGAvg = (int32_t)(  (pu8Src00[1]
                                                  + pu8Src01[1]
                                                  + pu8Src10[1]
                                                  + pu8Src11[1]
                                                  + 2) / 4);
                int32_t const iRAvg = (int32_t)(  (pu8Src00[2]
                                                  + pu8Src01[2]
                                                  + pu8Src10[2]
                                                  + pu8Src11[2]
                                                  + 2) / 4);

                int32_t const iU = (int32_t)CALC_U(iRAvg, iGAvg, iBAvg);
                int32_t const iV = (int32_t)CALC_V(iRAvg, iGAvg, iBAvg);

                pu8DstURow[uXDstChroma] = (uint8_t)RT_MIN(RT_MAX(iU, 0), 255);
                pu8DstVRow[uXDstChroma] = (uint8_t)RT_MIN(RT_MAX(iV, 0), 255);
            }
        }
    }
    else
    {
        /*
         * Fallback for odd-aligned source/destination rectangles.
         */
        for (uint32_t y = 0; y < uSrcHeight; y++)
        {
            uint32_t const uDstYCur = uDstY + y;
            size_t const offSrcRow = (size_t)(uSrcY + y) * uSrcStride + (size_t)uSrcX * uSrcBytesPerPixel;
            size_t const offDstYRow = (size_t)uDstYCur * uDstWidth + uDstX;

            for (uint32_t x = 0; x < uSrcWidth; x++)
            {
                size_t const offBGR = offSrcRow + (size_t)x * uSrcBytesPerPixel;

                uint8_t const b = paSrc[offBGR + 0];
                uint8_t const g = paSrc[offBGR + 1];
                uint8_t const r = paSrc[offBGR + 2];

                int32_t const iY = (int32_t)CALC_Y(r, g, b);
                pu8DstY[offDstYRow + x] = (uint8_t)RT_MIN(RT_MAX(iY, 0), 255);
            }
        }

        if (uDstChromaWidth && uDstChromaHeight)
        {
            uint32_t const uSrcXLast = uSrcX + uSrcWidth  - 1;
            uint32_t const uSrcYLast = uSrcY + uSrcHeight - 1;

            for (uint32_t y = 0; y < uSrcHeight; y += 2)
            {
                uint32_t const uY0Src = uSrcY + y;
                uint32_t const uY1Src = RT_MIN(uY0Src + 1, uSrcYLast);
                uint32_t const uY0Dst = uDstY + y;
                uint32_t const uYDstChroma = uY0Dst / 2;
                if (uYDstChroma >= uDstChromaHeight)
                    break;

                uint8_t const *pu8SrcRow0 = paSrc + (size_t)uY0Src * uSrcStride;
                uint8_t const *pu8SrcRow1 = paSrc + (size_t)uY1Src * uSrcStride;

                for (uint32_t x = 0; x < uSrcWidth; x += 2)
                {
                    uint32_t const uX0Src = uSrcX + x;
                    uint32_t const uX1Src = RT_MIN(uX0Src + 1, uSrcXLast);
                    uint32_t const uX0Dst = uDstX + x;
                    uint32_t const uXDstChroma = uX0Dst / 2;
                    if (uXDstChroma >= uDstChromaWidth)
                        break;

                    uint8_t const *pu8Src00 = pu8SrcRow0 + (size_t)uX0Src * uSrcBytesPerPixel;
                    uint8_t const *pu8Src01 = pu8SrcRow0 + (size_t)uX1Src * uSrcBytesPerPixel;
                    uint8_t const *pu8Src10 = pu8SrcRow1 + (size_t)uX0Src * uSrcBytesPerPixel;
                    uint8_t const *pu8Src11 = pu8SrcRow1 + (size_t)uX1Src * uSrcBytesPerPixel;

                    int32_t const iBAvg = (int32_t)(  (pu8Src00[0]
                                                      + pu8Src01[0]
                                                      + pu8Src10[0]
                                                      + pu8Src11[0]
                                                      + 2) / 4);
                    int32_t const iGAvg = (int32_t)(  (pu8Src00[1]
                                                      + pu8Src01[1]
                                                      + pu8Src10[1]
                                                      + pu8Src11[1]
                                                      + 2) / 4);
                    int32_t const iRAvg = (int32_t)(  (pu8Src00[2]
                                                      + pu8Src01[2]
                                                      + pu8Src10[2]
                                                      + pu8Src11[2]
                                                      + 2) / 4);

                    int32_t const iU = (int32_t)CALC_U(iRAvg, iGAvg, iBAvg);
                    int32_t const iV = (int32_t)CALC_V(iRAvg, iGAvg, iBAvg);

                    size_t const offDstUV = (size_t)uYDstChroma * uDstChromaWidth + uXDstChroma;
                    pu8DstU[offDstUV] = (uint8_t)RT_MIN(RT_MAX(iU, 0), 255);
                    pu8DstV[offDstUV] = (uint8_t)RT_MIN(RT_MAX(iV, 0), 255);
                }
            }
        }
    }

#undef CALC_Y
#undef CALC_U
#undef CALC_V
}

/** @copydoc RECORDINGRENDEROPS::pfnConvert */
static DECLCALLBACK(int) recRenderSWConvert(PRECORDINGRENDERER pRenderer,
                                            PRECORDINGRENDERTEXTURE pDstTexture,
                                            PCRECORDINGRENDERTEXTURE pSrcTexture)
{
    /* No conversion necessary? */
    if (pDstTexture->pInfo->enmPixelFmt == pSrcTexture->pInfo->enmPixelFmt)
        return VINF_SUCCESS;

    RECORDINGVIDEOFRAME const *pSrcFrame = recRenderSWTex2FrmC(pSrcTexture);
    PRECORDINGVIDEOFRAME pDstFrame = recRenderSWTex2Frm(pDstTexture);

    RT_NOREF(pRenderer);

    Assert(pSrcFrame->Info.enmPixelFmt == RECORDINGPIXELFMT_BRGA32);
    Assert(pDstFrame->Info.enmPixelFmt == RECORDINGPIXELFMT_YUVI420);

    uint32_t const uSrcWidth  = RT_MIN(pSrcFrame->Info.uWidth,  pDstFrame->Info.uWidth);
    uint32_t const uSrcHeight = RT_MIN(pSrcFrame->Info.uHeight, pDstFrame->Info.uHeight);

    recRenderSWConvertBGRA32ToYUVI420(pDstFrame->pau8Buf,
                                      0 /* uDstX */, 0 /* uDstY */, pDstFrame->Info.uWidth, pDstFrame->Info.uHeight,
                                      pSrcFrame->pau8Buf,
                                      0 /* uSrcX */, 0 /* uSrcY */, uSrcWidth, uSrcHeight,
                                      pSrcFrame->Info.uBytesPerLine, pSrcFrame->Info.uBPP);

#ifdef VBOX_RECORDING_DEBUG_DUMP_FRAMES
    RecordingDbgDumpVideoFrame(pDstFrame, "render-sw-convert", pRenderer->msLastRenderedTS);
#endif

    return VINF_SUCCESS;
}

/**
 * Software renderer operation table.
 */
static const RECORDINGRENDEROPS g_RecordingRenderOpsSoftware =
{
    NULL /* pfnProbe */,
    recRenderSWInit,
    recRenderSWDestroy,
    recRenderSWQueryCaps,
    recRenderSWTextureCreate,
    recRenderSWTextureDestroy,
    recRenderSWTextureClear,
    recRenderSWTextureQueryPixelData,
    recRenderSWTextureUpdate,
    recRenderSWBlit,
    recRenderSWBlend,
    recRenderSWResize,
    recRenderSWConvert
};


/*********************************************************************************************************************************
 * Output target renderer backend                                                                                                *
 ********************************************************************************************************************************/

/**
 * Output target backend private state.
 */
typedef struct RECORDINGRENDEROUTTGT
{
    /** Copy of output target description from Main to use. */
    PDMDISPLAYOUTPUTTARGETDESC TgtDesc;
    /** Surface information of the output target description.
     *  Used when the renderer queries the pixel data. */
    RECORDINGSURFACEINFO       SurfaceInfo;
} RECORDINGRENDEROUTTGT;
/** Pointer to output target backend private state. */
typedef RECORDINGRENDEROUTTGT *PRECORDINGRENDEROUTTGT;
/** Pointer to const output target backend private state. */
typedef RECORDINGRENDEROUTTGT const *PCRECORDINGRENDEROUTTGT;

/** @copydoc RECORDINGRENDEROPS::pfnProbe */
static DECLCALLBACK(int) recRenderOutTgtProbe(PCRECORDINGRENDERER pRenderer)
{
    RT_NOREF(pRenderer);
    return VINF_SUCCESS;
}

/** @copydoc RECORDINGRENDEROPS::pfnInit */
static DECLCALLBACK(int) recRenderOutTgtInit(PRECORDINGRENDERER pRenderer, const void *pvBackend)
{
    AssertPtr(pvBackend);

    PRECORDINGRENDEROUTTGT pOutTgt = (PRECORDINGRENDEROUTTGT)RTMemAllocZ(sizeof(RECORDINGRENDEROUTTGT));
    AssertPtrReturn(pOutTgt, VERR_NO_MEMORY);

    memcpy(&pOutTgt->TgtDesc, pvBackend, sizeof(PDMDISPLAYOUTPUTTARGETDESC));

    pOutTgt->SurfaceInfo.enmPixelFmt   = pOutTgt->TgtDesc.enmFormat == PDMDISPLAYOUTPUTTARGETFORMAT_YUVI420
                                       ? RECORDINGPIXELFMT_YUVI420 : RECORDINGPIXELFMT_UNKNOWN;
    pOutTgt->SurfaceInfo.uBPP          = 32;
    pOutTgt->SurfaceInfo.uWidth        = pOutTgt->TgtDesc.cWidth;
    pOutTgt->SurfaceInfo.uHeight       = pOutTgt->TgtDesc.cHeight;
    pOutTgt->SurfaceInfo.uBytesPerLine = 0; /* Unused */

    /* Attach backend state early so all failure paths can use one cleanup routine. */
    pRenderer->pvBackend = pOutTgt;

    return VINF_SUCCESS;
}

/** @copydoc RECORDINGRENDEROPS::pfnDestroy */
static DECLCALLBACK(void) recRenderOutTgtDestroy(PRECORDINGRENDERER pRenderer)
{
    PRECORDINGRENDEROUTTGT pOutTgt = (PRECORDINGRENDEROUTTGT)pRenderer->pvBackend;
    if (!pOutTgt)
        return;

    RTMemFree(pOutTgt);
    pRenderer->pvBackend = NULL;
}

/** @copydoc RECORDINGRENDEROPS::pfnQueryCaps */
static DECLCALLBACK(uint64_t) recRenderOutTgtQueryCaps(PCRECORDINGRENDERER pRenderer)
{
    RT_NOREF(pRenderer);
    return RECORDINGRENDERCAP_F_NONE;
}

/** @copydoc RECORDINGRENDEROPS::pfnTextureCreate */
static DECLCALLBACK(int) recRenderOutTgtTextureCreate(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture,
                                                      PRECORDINGSURFACEINFO pInfo)
{
    RT_NOREF(pRenderer, pTexture, pInfo);
    return VINF_SUCCESS;
}

/** @copydoc RECORDINGRENDEROPS::pfnTextureDestroy */
static DECLCALLBACK(void) recRenderOutTgtTextureDestroy(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture)
{
    RT_NOREF(pRenderer, pTexture);
}

/** @copydoc RECORDINGRENDEROPS::pfnTextureClear */
static DECLCALLBACK(void) recRenderOutTgtTextureClear(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture)
{
    RT_NOREF(pRenderer, pTexture);
}

/** @copydoc RECORDINGRENDEROPS::pfnTextureQueryPixelData */
static DECLCALLBACK(int) recRenderOutTgtTextureQueryPixelData(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture,
                                                              void **ppvBuf, size_t *pcbBuf)
{
    RT_NOREF(pTexture);

    PRECORDINGRENDEROUTTGT pOutTgt = (PRECORDINGRENDEROUTTGT)pRenderer->pvBackend;
    AssertPtr(pOutTgt);

    *ppvBuf = pOutTgt->TgtDesc.pvOutputBuffer;
    *pcbBuf = pOutTgt->TgtDesc.cbOutputBuffer;

    pTexture->pInfo = &pOutTgt->SurfaceInfo;

    return VINF_SUCCESS;
}

/** @copydoc RECORDINGRENDEROPS::pfnTextureUpdate */
static DECLCALLBACK(int) recRenderOutTgtTextureUpdate(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture,
                                                      PRECORDINGVIDEOFRAME pFrame)
{
    RT_NOREF(pRenderer, pTexture, pFrame);
    return VINF_SUCCESS;
}

/** @copydoc RECORDINGRENDEROPS::pfnBlit */
static DECLCALLBACK(int) recRenderOutTgtBlit(PRECORDINGRENDERER pRenderer,
                                             PRECORDINGRENDERTEXTURE pDstTexture, PRTRECT pDstRect,
                                             PCRECORDINGRENDERTEXTURE pSrcTexture, PRTRECT pSrcRect)
{
    RT_NOREF(pRenderer, pDstTexture, pDstRect, pSrcTexture, pSrcRect);
    return VINF_SUCCESS;
}

/** @copydoc RECORDINGRENDEROPS::pfnBlend */
static DECLCALLBACK(int) recRenderOutTgtBlend(PRECORDINGRENDERER pRenderer,
                                              PRECORDINGRENDERTEXTURE pDstTexture, PRTRECT pDstRect,
                                              PRECORDINGRENDERTEXTURE pSrcTexture, PRTRECT pSrcRect)
{
    RT_NOREF(pRenderer, pDstTexture, pDstRect, pSrcTexture, pSrcRect);
    return VINF_SUCCESS;
}

/** @copydoc RECORDINGRENDEROPS::pfnResize */
static DECLCALLBACK(int) recRenderOutTgtResize(PRECORDINGRENDERER pRenderer,
                                               PRECORDINGRENDERTEXTURE pDstTexture,
                                               PCRECORDINGRENDERTEXTURE pSrcTexture,
                                               PRECORDINGRENDERRESIZEPARMS pResizeParms)
{
    RT_NOREF(pRenderer, pDstTexture, pSrcTexture, pResizeParms);
    return VINF_SUCCESS;
}

/** @copydoc RECORDINGRENDEROPS::pfnConvert */
static DECLCALLBACK(int) recRenderOutTgtConvert(PRECORDINGRENDERER pRenderer,
                                                PRECORDINGRENDERTEXTURE pDstTexture,
                                                PCRECORDINGRENDERTEXTURE pSrcTexture)
{
    RT_NOREF(pRenderer, pDstTexture, pSrcTexture);
    return VINF_SUCCESS;
}

/**
 * Output-target renderer operations table.
 */
static const RECORDINGRENDEROPS g_RecordingRenderOpsOutTgt =
{
    recRenderOutTgtProbe,
    recRenderOutTgtInit,
    recRenderOutTgtDestroy,
    recRenderOutTgtQueryCaps,
    recRenderOutTgtTextureCreate,
    recRenderOutTgtTextureDestroy,
    recRenderOutTgtTextureClear,
    recRenderOutTgtTextureQueryPixelData,
    recRenderOutTgtTextureUpdate,
    recRenderOutTgtBlit,
    recRenderOutTgtBlend,
    recRenderOutTgtResize,
    recRenderOutTgtConvert
};


/*********************************************************************************************************************************
 * SDL renderer backend                                                                                                          *
 ********************************************************************************************************************************/

#ifdef VBOX_WITH_RECORDING_SDL_BACKEND
/** Pointer to SDL_WasInit. */
typedef Uint32 (SDLCALL *PFNRECRENDERSDLWASINIT)(Uint32 flags);
/** Pointer to SDL_InitSubSystem. */
typedef int (SDLCALL *PFNRECRENDERSDLINITSUBSYSTEM)(Uint32 flags);
/** Pointer to SDL_QuitSubSystem. */
typedef void (SDLCALL *PFNRECRENDERSDLQUITSUBSYSTEM)(Uint32 flags);
/** Pointer to SDL_GetError. */
typedef const char *(SDLCALL *PFNRECRENDERSDLGETERROR)(void);
/** Pointer to SDL_CreateWindow. */
typedef SDL_Window *(SDLCALL *PFNRECRENDERSDLCREATEWINDOW)(const char *title, int x, int y, int w, int h, Uint32 flags);
/** Pointer to SDL_DestroyWindow. */
typedef void (SDLCALL *PFNRECRENDERSDLDESTROYWINDOW)(SDL_Window *window);
/** Pointer to SDL_CreateRenderer. */
typedef SDL_Renderer *(SDLCALL *PFNRECRENDERSDLCREATERENDERER)(SDL_Window *window, int index, Uint32 flags);
/** Pointer to SDL_DestroyRenderer. */
typedef void (SDLCALL *PFNRECRENDERSDLDESTROYRENDERER)(SDL_Renderer *renderer);
/** Pointer to SDL_GetRendererInfo. */
typedef int (SDLCALL *PFNRECRENDERSDLGETRENDERERINFO)(SDL_Renderer *renderer, SDL_RendererInfo *info);
/** Pointer to SDL_CreateTexture. */
typedef SDL_Texture *(SDLCALL *PFNRECRENDERSDLCREATETEXTURE)(SDL_Renderer *renderer, Uint32 format, int access, int w, int h);
/** Pointer to SDL_DestroyTexture. */
typedef void (SDLCALL *PFNRECRENDERSDLDESTROYTEXTURE)(SDL_Texture *texture);
/** Pointer to SDL_QueryTexture. */
typedef int (SDLCALL *PFNRECRENDERSDLQUERYTEXTURE)(SDL_Texture *texture, Uint32 *format, int *access, int *w, int *h);
/** Pointer to SDL_SetTextureBlendMode. */
typedef int (SDLCALL *PFNRECRENDERSDLSETTEXTUREBLENDMODE)(SDL_Texture *texture, SDL_BlendMode blendMode);
/** Pointer to SDL_UpdateTexture. */
typedef int (SDLCALL *PFNRECRENDERSDLUPDATETEXTURE)(SDL_Texture *texture, const SDL_Rect *rect, const void *pixels, int pitch);
/** Pointer to SDL_LockTexture. */
typedef int (SDLCALL *PFNRECRENDERSDLLOCKTEXTURE)(SDL_Texture *texture, const SDL_Rect *rect, void **pixels, int *pitch);
/** Pointer to SDL_UnlockTexture. */
typedef void (SDLCALL *PFNRECRENDERSDLUNLOCKTEXTURE)(SDL_Texture *texture);
/** Pointer to SDL_GetRenderTarget. */
typedef SDL_Texture *(SDLCALL *PFNRECRENDERSDLGETRENDERTARGET)(SDL_Renderer *renderer);
/** Pointer to SDL_SetRenderTarget. */
typedef int (SDLCALL *PFNRECRENDERSDLSETRENDERTARGET)(SDL_Renderer *renderer, SDL_Texture *texture);
/** Pointer to SDL_SetRenderDrawColor. */
typedef int (SDLCALL *PFNRECRENDERSDLSETRENDERDRAWCOLOR)(SDL_Renderer *renderer, Uint8 r, Uint8 g, Uint8 b, Uint8 a);
/** Pointer to SDL_RenderClear. */
typedef int (SDLCALL *PFNRECRENDERSDLRENDERCLEAR)(SDL_Renderer *renderer);
/** Pointer to SDL_RenderCopy. */
typedef int (SDLCALL *PFNRECRENDERSDLRENDERCOPY)(SDL_Renderer *renderer, SDL_Texture *texture,
                                                 const SDL_Rect *srcrect, const SDL_Rect *dstrect);
/** Pointer to SDL_RenderReadPixels. */
typedef int (SDLCALL *PFNRECRENDERSDLRENDERREADPIXELS)(SDL_Renderer *renderer, const SDL_Rect *rect,
                                                        Uint32 format, void *pixels, int pitch);
/** Pointer to SDL_SetRenderDrawBlendMode. */
typedef int (SDLCALL *PFNRECRENDERSDLSETRENDERDRAWBLENDMODE)(SDL_Renderer *renderer, SDL_BlendMode blendMode);
/** Pointer to SDL_ConvertPixels. */
typedef int (SDLCALL *PFNRECRENDERSDLCONVERTPIXELS)(int width, int height,
                                                     Uint32 src_format, const void *src, int src_pitch,
                                                     Uint32 dst_format, void *dst, int dst_pitch);
/**
 * SDL backend private state.
 */
typedef struct RECORDINGRENDERSDL
{
    /** SDL shared library module handle. */
    RTLDRMOD      hLdrModSDL;
    /** Whether this backend initialized the SDL video subsystem itself. */
    bool          fOwnVideoSubSys;
    /** SDL_WasInit */
    PFNRECRENDERSDLWASINIT pfnWasInit;
    /** SDL_InitSubSystem */
    PFNRECRENDERSDLINITSUBSYSTEM pfnInitSubSystem;
    /** SDL_QuitSubSystem */
    PFNRECRENDERSDLQUITSUBSYSTEM pfnQuitSubSystem;
    /** SDL_GetError */
    PFNRECRENDERSDLGETERROR pfnGetError;
    /** SDL_CreateWindow */
    PFNRECRENDERSDLCREATEWINDOW pfnCreateWindow;
    /** SDL_DestroyWindow */
    PFNRECRENDERSDLDESTROYWINDOW pfnDestroyWindow;
    /** SDL_CreateRenderer */
    PFNRECRENDERSDLCREATERENDERER pfnCreateRenderer;
    /** SDL_DestroyRenderer */
    PFNRECRENDERSDLDESTROYRENDERER pfnDestroyRenderer;
    /** SDL_GetRendererInfo (lazily resolved). */
    PFNRECRENDERSDLGETRENDERERINFO pfnGetRendererInfo;
    /** SDL_CreateTexture */
    PFNRECRENDERSDLCREATETEXTURE pfnCreateTexture;
    /** SDL_DestroyTexture */
    PFNRECRENDERSDLDESTROYTEXTURE pfnDestroyTexture;
    /** SDL_QueryTexture */
    PFNRECRENDERSDLQUERYTEXTURE pfnQueryTexture;
    /** SDL_SetTextureBlendMode */
    PFNRECRENDERSDLSETTEXTUREBLENDMODE pfnSetTextureBlendMode;
    /** SDL_UpdateTexture */
    PFNRECRENDERSDLUPDATETEXTURE pfnUpdateTexture;
    /** SDL_LockTexture */
    PFNRECRENDERSDLLOCKTEXTURE pfnLockTexture;
    /** SDL_UnlockTexture */
    PFNRECRENDERSDLUNLOCKTEXTURE pfnUnlockTexture;
    /** SDL_GetRenderTarget */
    PFNRECRENDERSDLGETRENDERTARGET pfnGetRenderTarget;
    /** SDL_SetRenderTarget */
    PFNRECRENDERSDLSETRENDERTARGET pfnSetRenderTarget;
    /** SDL_SetRenderDrawColor */
    PFNRECRENDERSDLSETRENDERDRAWCOLOR pfnSetRenderDrawColor;
    /** SDL_RenderClear */
    PFNRECRENDERSDLRENDERCLEAR pfnRenderClear;
    /** SDL_RenderCopy */
    PFNRECRENDERSDLRENDERCOPY pfnRenderCopy;
    /** SDL_RenderReadPixels */
    PFNRECRENDERSDLRENDERREADPIXELS pfnRenderReadPixels;
    /** SDL_SetRenderDrawBlendMode */
    PFNRECRENDERSDLSETRENDERDRAWBLENDMODE pfnSetRenderDrawBlendMode;
    /** SDL_ConvertPixels */
    PFNRECRENDERSDLCONVERTPIXELS pfnConvertPixels;
    /** Hidden helper window required by SDL_Renderer. */
    SDL_Window   *pWindow;
    /** SDL renderer (accelerated if available, software fallback otherwise). */
    SDL_Renderer *pRenderer;
} RECORDINGRENDERSDL;
/** Pointer to SDL backend private state. */
typedef RECORDINGRENDERSDL *PRECORDINGRENDERSDL;
/** Pointer to const SDL backend private state. */
typedef RECORDINGRENDERSDL const *PCRECORDINGRENDERSDL;

/**
 * Native SDL texture wrapper referenced by RECORDINGRENDERTEXTURE::pvBackend.
 */
typedef struct RECORDINGRENDERSDLTEXTURE
{
    /** Surface information associated with this texture. */
    RECORDINGSURFACEINFO Info;
    /** SDL texture handle. */
    SDL_Texture         *pTexture;
} RECORDINGRENDERSDLTEXTURE;
/** Pointer to native SDL texture wrapper. */
typedef RECORDINGRENDERSDLTEXTURE *PRECORDINGRENDERSDLTEXTURE;
/** Pointer to const native SDL texture wrapper. */
typedef RECORDINGRENDERSDLTEXTURE const *PCRECORDINGRENDERSDLTEXTURE;

/**
 * Loads and resolves all required SDL symbols.
 */
static int recRenderSDLResolveSymbols(PRECORDINGRENDERSDL pSDL)
{
    static const char * const s_apszLibs[] =
    {
#ifdef RT_OS_WINDOWS
        "SDL2.dll",
#elif defined(RT_OS_DARWIN)
        "libSDL2-2.0.0.dylib",
        "libSDL2.dylib",
#else
        "libSDL2.so.0",
        "libSDL2.so",
#endif
    };

    int vrc = VERR_NOT_SUPPORTED;
    for (uint32_t i = 0; i < RT_ELEMENTS(s_apszLibs); i++)
    {
        vrc = RTLdrLoadSystem(s_apszLibs[i], false /* fNoUnload */, &pSDL->hLdrModSDL);
        if (RT_SUCCESS(vrc))
            break;
    }
    if (RT_FAILURE(vrc))
        return vrc;

#define REC_RENDER_SDL_RESOLVE(a_Name, a_Field) \
    vrc = RTLdrGetSymbol(pSDL->hLdrModSDL, a_Name, (void **)&pSDL->a_Field); if (RT_FAILURE(vrc)) break;

    for (;;)
    {
        REC_RENDER_SDL_RESOLVE("SDL_WasInit",               pfnWasInit);
        REC_RENDER_SDL_RESOLVE("SDL_InitSubSystem",         pfnInitSubSystem);
        REC_RENDER_SDL_RESOLVE("SDL_QuitSubSystem",         pfnQuitSubSystem);
        REC_RENDER_SDL_RESOLVE("SDL_GetError",              pfnGetError);
        REC_RENDER_SDL_RESOLVE("SDL_CreateWindow",          pfnCreateWindow);
        REC_RENDER_SDL_RESOLVE("SDL_LockTexture",           pfnLockTexture);
        REC_RENDER_SDL_RESOLVE("SDL_UnlockTexture",         pfnUnlockTexture);
        REC_RENDER_SDL_RESOLVE("SDL_DestroyWindow",         pfnDestroyWindow);
        REC_RENDER_SDL_RESOLVE("SDL_CreateRenderer",        pfnCreateRenderer);
        REC_RENDER_SDL_RESOLVE("SDL_DestroyRenderer",       pfnDestroyRenderer);
        REC_RENDER_SDL_RESOLVE("SDL_CreateTexture",         pfnCreateTexture);
        REC_RENDER_SDL_RESOLVE("SDL_DestroyTexture",        pfnDestroyTexture);
        REC_RENDER_SDL_RESOLVE("SDL_QueryTexture",          pfnQueryTexture);
        REC_RENDER_SDL_RESOLVE("SDL_SetTextureBlendMode",   pfnSetTextureBlendMode);
        REC_RENDER_SDL_RESOLVE("SDL_UpdateTexture",         pfnUpdateTexture);
        REC_RENDER_SDL_RESOLVE("SDL_GetRendererInfo",       pfnGetRendererInfo);
        REC_RENDER_SDL_RESOLVE("SDL_GetRenderTarget",       pfnGetRenderTarget);
        REC_RENDER_SDL_RESOLVE("SDL_SetRenderTarget",       pfnSetRenderTarget);
        REC_RENDER_SDL_RESOLVE("SDL_SetRenderDrawColor",    pfnSetRenderDrawColor);
        REC_RENDER_SDL_RESOLVE("SDL_RenderClear",           pfnRenderClear);
        REC_RENDER_SDL_RESOLVE("SDL_RenderCopy",            pfnRenderCopy);
        REC_RENDER_SDL_RESOLVE("SDL_RenderReadPixels",      pfnRenderReadPixels);
        REC_RENDER_SDL_RESOLVE("SDL_SetRenderDrawBlendMode",pfnSetRenderDrawBlendMode);
        REC_RENDER_SDL_RESOLVE("SDL_ConvertPixels",         pfnConvertPixels);
        break;
    }
#undef REC_RENDER_SDL_RESOLVE

    if (RT_FAILURE(vrc))
    {
        RTLdrClose(pSDL->hLdrModSDL);
        pSDL->hLdrModSDL = NIL_RTLDRMOD;
    }

    return vrc;
}

/**
 * Logs SDL renderer details for diagnostics.
 *
 * @param   pSDL                SDL backend private state.
 */
static void recRenderSDLLogRendererInfo(PRECORDINGRENDERSDL pSDL)
{
    SDL_RendererInfo Info;
    RT_ZERO(Info);

    int const vrcSDL = pSDL->pfnGetRendererInfo(pSDL->pRenderer, &Info);
    if (vrcSDL != 0)
    {
        LogRel2(("Recording: SDL_GetRendererInfo failed: %s\n", pSDL->pfnGetError()));
        return;
    }

    Uint32 const fKnownFlags = SDL_RENDERER_SOFTWARE
                             | SDL_RENDERER_ACCELERATED
                             | SDL_RENDERER_PRESENTVSYNC
                             | SDL_RENDERER_TARGETTEXTURE;
    Uint32 const fUnknownFlags = Info.flags & ~fKnownFlags;

    LogRel2(("Recording: SDL renderer details:\n"));
    LogRel2(("Recording:   - Name: %s\n", Info.name ? Info.name : "<unknown>"));
    LogRel2(("Recording:   - Flags: %#x\n", Info.flags));
    LogRel2(("Recording:     * Software:      %s\n", (Info.flags & SDL_RENDERER_SOFTWARE)      ? "yes" : "no"));
    LogRel2(("Recording:     * Accelerated:   %s\n", (Info.flags & SDL_RENDERER_ACCELERATED)   ? "yes" : "no"));
    LogRel2(("Recording:     * PresentVSync:  %s\n", (Info.flags & SDL_RENDERER_PRESENTVSYNC)  ? "yes" : "no"));
    LogRel2(("Recording:     * TargetTexture: %s\n", (Info.flags & SDL_RENDERER_TARGETTEXTURE) ? "yes" : "no"));
    if (fUnknownFlags)
        LogRel2(("Recording:     * Unknown bits: %#x\n", fUnknownFlags));
    LogRel2(("Recording:   - Max texture size: %d x %d\n", Info.max_texture_width, Info.max_texture_height));
    LogRel2(("Recording:   - Texture formats (%u):\n", Info.num_texture_formats));
}


/**
 * SDL backend destroy callback (forward declaration for init-time cleanup).
 *
 * @param   pRenderer           Renderer instance.
 */
static DECLCALLBACK(void) recRenderSDLDestroy(PRECORDINGRENDERER pRenderer);

/**
 * SDL backend probe callback.
 *
 * @returns VBox status code.
 * @param   pRenderer           Renderer instance.
 */
static DECLCALLBACK(int) recRenderSDLProbe(PCRECORDINGRENDERER pRenderer)
{
    RT_NOREF(pRenderer);

    RECORDINGRENDERSDL SDL;
    RT_ZERO(SDL);

    int const vrc = recRenderSDLResolveSymbols(&SDL);
    if (   RT_SUCCESS(vrc)
        && SDL.hLdrModSDL != NIL_RTLDRMOD)
        RTLdrClose(SDL.hLdrModSDL);

    return RT_SUCCESS(vrc) ? VINF_SUCCESS : VERR_RECORDING_BACKEND_NOT_SUPPORTED; /* Good enough for now. */
}

/**
 * Maps recording pixel formats to SDL pixel formats.
 *
 * @returns SDL pixel format identifier, or SDL_PIXELFORMAT_UNKNOWN if unsupported.
 * @param   enmFmt              Recording pixel format.
 * @param   uBPP                Bits per pixel.
 */
DECLINLINE(Uint32) recRenderSDLPixelFmtFromRec(RECORDINGPIXELFMT enmFmt, uint8_t uBPP)
{
    RT_NOREF(uBPP);

    switch (enmFmt)
    {
        case RECORDINGPIXELFMT_BRGA32:  return SDL_PIXELFORMAT_BGRA8888;
        case RECORDINGPIXELFMT_YUVI420: return SDL_PIXELFORMAT_IYUV;
        default:                        break;
    }

    return SDL_PIXELFORMAT_UNKNOWN;
}

/**
 * Returns default stride for a surface if not explicitly supplied.
 */
DECLINLINE(uint32_t) recRenderSDLDefaultStride(RECORDINGSURFACEINFO const *pInfo)
{
    if (pInfo->uBytesPerLine)
        return pInfo->uBytesPerLine;
    if (pInfo->enmPixelFmt == RECORDINGPIXELFMT_YUVI420)
        return pInfo->uWidth;
    return pInfo->uWidth * RT_MAX((uint32_t)pInfo->uBPP / 8, 1U);
}

/**
 * Resolves a generic texture reference to a native SDL texture wrapper.
 */
DECLINLINE(PRECORDINGRENDERSDLTEXTURE) recRenderSDLTexFromRef(PRECORDINGRENDERTEXTURE pTexture)
{
    if (   !pTexture
        || !pTexture->pvBackend)
        return NULL;

    return (PRECORDINGRENDERSDLTEXTURE)pTexture->pvBackend;
}

/**
 * Resolves a const generic texture reference to a native SDL texture wrapper.
 */
DECLINLINE(PCRECORDINGRENDERSDLTEXTURE) recRenderSDLTexFromRefC(PCRECORDINGRENDERTEXTURE pTexture)
{
    if (   !pTexture
        || !pTexture->pvBackend)
        return NULL;

    return (PCRECORDINGRENDERSDLTEXTURE)pTexture->pvBackend;
}

#ifdef VBOX_RECORDING_DEBUG_DUMP_FRAMES
/**
 * Dumps an SDL BGRA32 texture by reading it back into a temporary framebuffer.
 *
 * @param   pSDL                SDL backend state.
 * @param   pTexture            Texture to read back.
 * @param   cx                  Texture width in pixels.
 * @param   cy                  Texture height in pixels.
 * @param   msTimestamp         Frame timestamp to tag the dump with.
 * @param   pszWhat             Dump label.
 */
static void recRenderSDLDbgDumpBGRATexture(PRECORDINGRENDERSDL pSDL, SDL_Texture *pTexture,
                                           uint32_t cx, uint32_t cy, uint64_t msTimestamp,
                                           const char *pszWhat)
{
    AssertPtrReturnVoid(pSDL);
    AssertPtrReturnVoid(pTexture);
    AssertReturnVoid(cx);
    AssertReturnVoid(cy);

    uint32_t const cbStride = cx * 4;
    size_t const cbBuf = (size_t)cbStride * cy;
    uint8_t *pu8Buf = (uint8_t *)RTMemAlloc(cbBuf);
    AssertPtrReturnVoid(pu8Buf);

    SDL_Texture *pOldTarget = pSDL->pfnGetRenderTarget(pSDL->pRenderer);
    int vrcSDL = pSDL->pfnSetRenderTarget(pSDL->pRenderer, pTexture);
    if (vrcSDL == 0)
        vrcSDL = pSDL->pfnRenderReadPixels(pSDL->pRenderer, NULL /* pRect */, SDL_PIXELFORMAT_BGRA8888, pu8Buf, (int)cbStride);

    int const rcRestore = pSDL->pfnSetRenderTarget(pSDL->pRenderer, pOldTarget);
    Assert(rcRestore == 0); RT_NOREF(rcRestore);

    if (vrcSDL == 0)
    {
        RECORDINGVIDEOFRAME DbgFrame;
        RT_ZERO(DbgFrame);
        DbgFrame.Info.uWidth        = cx;
        DbgFrame.Info.uHeight       = cy;
        DbgFrame.Info.uBPP          = 32;
        DbgFrame.Info.enmPixelFmt   = RECORDINGPIXELFMT_BRGA32;
        DbgFrame.Info.uBytesPerLine = cbStride;
        DbgFrame.pau8Buf            = pu8Buf;
        DbgFrame.cbBuf              = cbBuf;

        RecordingDbgDumpVideoFrame(&DbgFrame, pszWhat, msTimestamp);
    }

    RTMemFree(pu8Buf);
}
#endif

/** @copydoc RECORDINGRENDEROPS::pfnQueryCaps */
static DECLCALLBACK(uint64_t) recRenderSDLQueryCaps(PCRECORDINGRENDERER pRenderer)
{
    RT_NOREF(pRenderer);
    return   RECORDINGRENDERCAP_F_BLIT_RAW
           | RECORDINGRENDERCAP_F_BLIT_FRAME
           | RECORDINGRENDERCAP_F_BLEND_ALPHA
           | RECORDINGRENDERCAP_F_RESIZE
           | RECORDINGRENDERCAP_F_CONVERT;
}

/** @copydoc RECORDINGRENDEROPS::pfnTextureCreate */
static DECLCALLBACK(int) recRenderSDLTextureCreate(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture,
                                                   PRECORDINGSURFACEINFO pInfo)
{
    PRECORDINGRENDERSDL pSDL = (PRECORDINGRENDERSDL)pRenderer->pvBackend;

    AssertReturn(pTexture->pvBackend == NULL, VERR_INVALID_STATE);

    Uint32 const uFmt = recRenderSDLPixelFmtFromRec(pInfo->enmPixelFmt, pInfo->uBPP);
    AssertReturn(uFmt != SDL_PIXELFORMAT_UNKNOWN, VERR_NOT_SUPPORTED);

    PRECORDINGRENDERSDLTEXTURE pTex = (PRECORDINGRENDERSDLTEXTURE)RTMemAllocZ(sizeof(RECORDINGRENDERSDLTEXTURE));
    AssertPtrReturn(pTex, VERR_NO_MEMORY);

    int const fAccess = uFmt == SDL_PIXELFORMAT_IYUV
                      ? SDL_TEXTUREACCESS_STREAMING : SDL_TEXTUREACCESS_TARGET;

    pTex->pTexture = pSDL->pfnCreateTexture(pSDL->pRenderer, uFmt, fAccess, (int)pInfo->uWidth, (int)pInfo->uHeight);
    if (!pTex->pTexture)
    {
        RTMemFree(pTex);
        return VERR_NO_MEMORY;
    }

    pTex->Info = *pInfo;
    pTex->Info.uBytesPerLine = recRenderSDLDefaultStride(pInfo);

    if (uFmt != SDL_PIXELFORMAT_IYUV)
        pSDL->pfnSetTextureBlendMode(pTex->pTexture, SDL_BLENDMODE_BLEND);

    pTexture->pvBackend = pTex;
    pTexture->pInfo     = &pTex->Info;

    return VINF_SUCCESS;
}

/** @copydoc RECORDINGRENDEROPS::pfnTextureDestroy */
static DECLCALLBACK(void) recRenderSDLTextureDestroy(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture)
{
    PRECORDINGRENDERSDL pSDL = (PRECORDINGRENDERSDL)pRenderer->pvBackend;

    if (   !pTexture
        || !pTexture->pvBackend)
        return;

    PRECORDINGRENDERSDLTEXTURE pTex = recRenderSDLTexFromRef(pTexture);
    if (pTex)
    {
        if (pTex->pTexture)
            pSDL->pfnDestroyTexture(pTex->pTexture);
        pTex->pTexture = NULL;
        RTMemFree(pTex);
    }
    else
    {
        PRECORDINGVIDEOFRAME pFrame = (PRECORDINGVIDEOFRAME)pTexture->pvBackend;
        if (   pTexture->pInfo
            && pTexture->pInfo == &pFrame->Info)
            RecordingVideoFrameFree(pFrame);
    }

    pTexture->pvBackend = NULL;
    pTexture->pInfo     = NULL;
}

/** @copydoc RECORDINGRENDEROPS::pfnTextureClear */
static DECLCALLBACK(void) recRenderSDLTextureClear(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture)
{
    PRECORDINGRENDERSDL pSDL = (PRECORDINGRENDERSDL)pRenderer->pvBackend;

    PRECORDINGRENDERSDLTEXTURE pTex = recRenderSDLTexFromRef(pTexture);
    if (!pTex)
    {
        PRECORDINGVIDEOFRAME pFrame = (PRECORDINGVIDEOFRAME)pTexture->pvBackend;
        if (   pFrame
            && pTexture->pInfo
            && pTexture->pInfo == &pFrame->Info
            && pFrame->pau8Buf)
            RT_BZERO(pFrame->pau8Buf, pFrame->cbBuf);
        return;
    }

    Uint32 const uFmt = recRenderSDLPixelFmtFromRec(pTex->Info.enmPixelFmt, pTex->Info.uBPP);
    if (uFmt == SDL_PIXELFORMAT_IYUV)
    {
        uint32_t const uW = pTex->Info.uWidth;
        uint32_t const uH = pTex->Info.uHeight;
        size_t const cbBuf = (size_t)uW * uH * 3 / 2;
        uint8_t *pu8Buf = (uint8_t *)RTMemAlloc(cbBuf);
        AssertPtrReturnVoid(pu8Buf);

        uint8_t *pu8Y = pu8Buf;
        uint8_t *pu8U = pu8Y + (size_t)uW * uH;
        uint8_t *pu8V = pu8U + (size_t)(uW / 2) * (uH / 2);

        memset(pu8Y, 0x00, (size_t)uW * uH);
        memset(pu8U, 0x80, (size_t)(uW / 2) * (uH / 2));
        memset(pu8V, 0x80, (size_t)(uW / 2) * (uH / 2));

        pSDL->pfnUpdateTexture(pTex->pTexture, NULL, pu8Buf, (int)uW);
        RTMemFree(pu8Buf);
        return;
    }

    SDL_Texture *pOldTarget = pSDL->pfnGetRenderTarget(pSDL->pRenderer);
    int vrcSDL = pSDL->pfnSetRenderTarget(pSDL->pRenderer, pTex->pTexture);
    if (vrcSDL == 0)
    {
        pSDL->pfnSetRenderDrawColor(pSDL->pRenderer, 0, 0, 0, 255);
        vrcSDL = pSDL->pfnRenderClear(pSDL->pRenderer);
    }
    RT_NOREF(vrcSDL);

    int const rcRestore = pSDL->pfnSetRenderTarget(pSDL->pRenderer, pOldTarget);
    Assert(rcRestore == 0); RT_NOREF(rcRestore);
}

/** @copydoc RECORDINGRENDEROPS::pfnTextureQueryPixelData */
static DECLCALLBACK(int) recRenderSDLTextureQueryPixelData(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture,
                                                           void **ppvBuf, size_t *pcbBuf)
{
    PRECORDINGRENDERSDL pSDL = (PRECORDINGRENDERSDL)pRenderer->pvBackend;
    PRECORDINGRENDERSDLTEXTURE pTex = recRenderSDLTexFromRef(pTexture);

    int w, h;
    int vrcSDL = pSDL->pfnQueryTexture(pTex->pTexture, NULL, NULL, &w, &h);
    Assert(vrcSDL == 0);

    Uint32 const outFmt         = SDL_PIXELFORMAT_BGRA8888;
    int    const uBPP           = 4 /* 32 bit */;
    int    const cbBytesPerLine = w * uBPP;
    size_t const cbBuf          = cbBytesPerLine * h;

    uint8_t *pvBuf = (uint8_t *)RTMemAlloc(cbBuf);
    AssertPtrReturn(pvBuf, VERR_NO_MEMORY);

    SDL_Texture *pTexPrev = pSDL->pfnGetRenderTarget(pSDL->pRenderer);
    if (pTexPrev)
    {
        vrcSDL = pSDL->pfnSetRenderTarget(pSDL->pRenderer, pTex->pTexture);
        if (vrcSDL == 0)
            vrcSDL = pSDL->pfnRenderReadPixels(pSDL->pRenderer,
                                               NULL,
                                               outFmt,
                                               pvBuf,
                                               cbBytesPerLine);

        pSDL->pfnSetRenderTarget(pSDL->pRenderer, pTexPrev);
    }
    else
        AssertFailedStmt(vrcSDL = -1);

    if (vrcSDL == 0)
    {
        *ppvBuf = pvBuf;
        *pcbBuf = cbBuf;
    }
    else
        RTMemFree(pvBuf);

    return vrcSDL == 0 ? VINF_SUCCESS : VERR_RECORDING_BACKEND_ERROR;
}

/** @copydoc RECORDINGRENDEROPS::pfnTextureUpdate */
static DECLCALLBACK(int) recRenderSDLTextureUpdate(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture,
                                                   PRECORDINGVIDEOFRAME pFrame)
{
    RT_NOREF(pRenderer);

    PRECORDINGRENDERSDL pSDL        = (PRECORDINGRENDERSDL)pRenderer->pvBackend;
    PRECORDINGRENDERSDLTEXTURE pTex = (PRECORDINGRENDERSDLTEXTURE)pTexture->pvBackend;

    SDL_Rect const rectUpdate = { (int)pFrame->Pos.x, (int)pFrame->Pos.y, (int)pFrame->Info.uWidth, (int)pFrame->Info.uHeight };

    int const vrcSDL = pSDL->pfnUpdateTexture(pTex->pTexture, &rectUpdate, pFrame->pau8Buf, pFrame->Info.uBytesPerLine);
    Assert(vrcSDL == 0);

    pTex->Info = pFrame->Info;
    pTexture->pInfo = &pTex->Info;

#ifdef VBOX_RECORDING_DEBUG_DUMP_FRAMES
    recRenderSDLDbgDumpBGRATexture(pSDL, pTex->pTexture,
                                   pTex->Info.uWidth, pTex->Info.uHeight,
                                   pRenderer->msLastRenderedTS, "render-sdl-tex-update");
#endif

    return VINF_SUCCESS;
}

/** @copydoc RECORDINGRENDEROPS::pfnBlit */
static DECLCALLBACK(int) recRenderSDLBlit(PRECORDINGRENDERER pRenderer,
                                          PRECORDINGRENDERTEXTURE pDstTexture, PRTRECT pDstRect,
                                          PCRECORDINGRENDERTEXTURE pSrcTexture, PRTRECT pSrcRect)
{
    PRECORDINGRENDERSDL pSDL = (PRECORDINGRENDERSDL)pRenderer->pvBackend;

    PRECORDINGRENDERSDLTEXTURE pDstTex = recRenderSDLTexFromRef(pDstTexture);

    RECORDINGSURFACEINFO const *pDstInfo = &pDstTex->Info;
    RECORDINGSURFACEINFO const *pSrcInfo = pSrcTexture->pInfo;

#ifdef VBOX_STRICT
    AssertReturn(pDstInfo->enmPixelFmt == RECORDINGPIXELFMT_BRGA32, VERR_NOT_SUPPORTED);
    AssertReturn(pSrcInfo->enmPixelFmt == RECORDINGPIXELFMT_BRGA32, VERR_NOT_SUPPORTED);
    AssertReturn(pDstInfo->uBPP == 32, VERR_NOT_SUPPORTED);
    AssertReturn(pSrcInfo->uBPP == 32, VERR_NOT_SUPPORTED);
#endif

    uint32_t const uSrcX = pSrcRect ? (uint32_t)RT_MAX(pSrcRect->xLeft, 0) : 0;
    uint32_t const uSrcY = pSrcRect ? (uint32_t)RT_MAX(pSrcRect->yTop,  0) : 0;
    uint32_t const uDstX = pDstRect ? (uint32_t)RT_MAX(pDstRect->xLeft, 0) : 0;
    uint32_t const uDstY = pDstRect ? (uint32_t)RT_MAX(pDstRect->yTop,  0) : 0;
    uint32_t const uSrcW = pSrcRect ? (uint32_t)RT_MAX(pSrcRect->xRight  - pSrcRect->xLeft, 0)
                                    : pSrcInfo->uWidth;
    uint32_t const uSrcH = pSrcRect ? (uint32_t)RT_MAX(pSrcRect->yBottom - pSrcRect->yTop,  0)
                                    : pSrcInfo->uHeight;

    if (   uSrcX >= pSrcInfo->uWidth
        || uSrcY >= pSrcInfo->uHeight
        || uDstX >= pDstInfo->uWidth
        || uDstY >= pDstInfo->uHeight)
        return VINF_SUCCESS;

    uint32_t const cxSrc = RT_MIN(uSrcW, pSrcInfo->uWidth - uSrcX);
    uint32_t const cySrc = RT_MIN(uSrcH, pSrcInfo->uHeight - uSrcY);
    uint32_t const cxDst = RT_MIN(cxSrc, pDstInfo->uWidth - uDstX);
    uint32_t const cyDst = RT_MIN(cySrc, pDstInfo->uHeight - uDstY);
    if (!cxDst || !cyDst)
        return VINF_SUCCESS;

    SDL_Texture *pSvrcSDLTex = NULL;
    PCRECORDINGRENDERSDLTEXTURE pSrcTex = recRenderSDLTexFromRefC(pSrcTexture);
    if (pSrcTex)
        pSvrcSDLTex = pSrcTex->pTexture;
    AssertPtr(pSvrcSDLTex);

    SDL_Rect const SrcRect = { (int)uSrcX, (int)uSrcY, (int)cxDst, (int)cyDst };
    SDL_Rect const DstRect = { (int)uDstX, (int)uDstY, (int)cxDst, (int)cyDst };

    int vrcSDL = pSDL->pfnSetRenderTarget(pSDL->pRenderer, pDstTex->pTexture);
    if (vrcSDL == 0)
    {
        vrcSDL = pSDL->pfnSetTextureBlendMode(pSvrcSDLTex, SDL_BLENDMODE_NONE);
        if (vrcSDL == 0)
            vrcSDL = pSDL->pfnRenderCopy(pSDL->pRenderer, pSvrcSDLTex, &SrcRect, &DstRect);
    }
    AssertStmt(vrcSDL == 0, LogFunc(("%s\n", pSDL->pfnGetError())));

#ifdef VBOX_RECORDING_DEBUG_DUMP_FRAMES
    recRenderSDLDbgDumpBGRATexture(pSDL, pDstTex->pTexture,
                                   pDstInfo->uWidth, pDstInfo->uHeight,
                                   pRenderer->msLastRenderedTS, "render-sdl-blit");
#endif

    return vrcSDL == 0 ? VINF_SUCCESS : VERR_RECORDING_BACKEND_ERROR;
}

/** @copydoc RECORDINGRENDEROPS::pfnBlend */
static DECLCALLBACK(int) recRenderSDLBlend(PRECORDINGRENDERER pRenderer,
                                           PRECORDINGRENDERTEXTURE pDstTexture, PRTRECT pSrcRect,
                                           PRECORDINGRENDERTEXTURE pSrcTexture, PRTRECT pDstRect)
{
    PRECORDINGRENDERSDL pSDL = (PRECORDINGRENDERSDL)pRenderer->pvBackend;

    PRECORDINGRENDERSDLTEXTURE pDstTex = recRenderSDLTexFromRef(pDstTexture);

    RECORDINGSURFACEINFO const *pDstInfo = &pDstTex->Info;
    RECORDINGSURFACEINFO const *pSrcInfo = pSrcTexture->pInfo;

#ifdef VBOX_STRICT
    AssertReturn(pSrcInfo->enmPixelFmt == RECORDINGPIXELFMT_BRGA32, VERR_NOT_SUPPORTED);
    AssertReturn(pDstInfo->enmPixelFmt == RECORDINGPIXELFMT_BRGA32, VERR_NOT_SUPPORTED);
    AssertReturn(pSrcInfo->uBPP == 32, VERR_NOT_SUPPORTED);
    AssertReturn(pDstInfo->uBPP == 32, VERR_NOT_SUPPORTED);
#endif

    uint32_t const uSrcX = pSrcRect ? (uint32_t)RT_MAX(pSrcRect->xLeft, 0) : 0;
    uint32_t const uSrcY = pSrcRect ? (uint32_t)RT_MAX(pSrcRect->yTop,  0) : 0;
    uint32_t const uDstX = pDstRect ? (uint32_t)RT_MAX(pDstRect->xLeft, 0) : 0;
    uint32_t const uDstY = pDstRect ? (uint32_t)RT_MAX(pDstRect->yTop,  0) : 0;
    uint32_t const uSrcW = pSrcRect ? (uint32_t)RT_MAX(pSrcRect->xRight  - pSrcRect->xLeft, 0)
                                    : pSrcInfo->uWidth;
    uint32_t const uSrcH = pSrcRect ? (uint32_t)RT_MAX(pSrcRect->yBottom - pSrcRect->yTop,  0)
                                    : pSrcInfo->uHeight;

    if (   uSrcX >= pSrcInfo->uWidth
        || uSrcY >= pSrcInfo->uHeight
        || uDstX >= pDstInfo->uWidth
        || uDstY >= pDstInfo->uHeight)
        return VINF_SUCCESS;

    uint32_t const cx = RT_MIN(uSrcW, pSrcInfo->uWidth - uSrcX);
    uint32_t const cy = RT_MIN(uSrcH, pSrcInfo->uHeight - uSrcY);
    uint32_t const cxDst = RT_MIN(cx, pDstInfo->uWidth - uDstX);
    uint32_t const cyDst = RT_MIN(cy, pDstInfo->uHeight - uDstY);
    if (!cxDst || !cyDst)
        return VINF_SUCCESS;

    SDL_Texture *pSvrcSDLTex = NULL;
    PCRECORDINGRENDERSDLTEXTURE pSrcTex = recRenderSDLTexFromRefC(pSrcTexture);
    if (pSrcTex)
        pSvrcSDLTex = pSrcTex->pTexture;
    AssertPtr(pSvrcSDLTex);

    SDL_Rect const SrcRect = { (int)uSrcX, (int)uSrcY, (int)cxDst, (int)cyDst };
    SDL_Rect const DstRect = { (int)uDstX, (int)uDstY, (int)cxDst, (int)cyDst };

    SDL_Texture *pOldTarget = pSDL->pfnGetRenderTarget(pSDL->pRenderer);
    int vrcSDL = pSDL->pfnSetRenderTarget(pSDL->pRenderer, pDstTex->pTexture);
    if (vrcSDL == 0)
    {
        pSDL->pfnSetTextureBlendMode(pSvrcSDLTex, SDL_BLENDMODE_BLEND);
        vrcSDL = pSDL->pfnRenderCopy(pSDL->pRenderer, pSvrcSDLTex, &SrcRect, &DstRect);
    }

    int const rcRestore = pSDL->pfnSetRenderTarget(pSDL->pRenderer, pOldTarget);
    Assert(rcRestore == 0); RT_NOREF(rcRestore);

    return vrcSDL == 0 ? VINF_SUCCESS : VERR_RECORDING_BACKEND_ERROR;
}

/** @copydoc RECORDINGRENDEROPS::pfnResize */
static DECLCALLBACK(int) recRenderSDLResize(PRECORDINGRENDERER pRenderer,
                                            PRECORDINGRENDERTEXTURE pDstTexture,
                                            PCRECORDINGRENDERTEXTURE pSrcTexture,
                                            PRECORDINGRENDERRESIZEPARMS pResizeParms)
{
    PRECORDINGRENDERSDL pSDL = (PRECORDINGRENDERSDL)pRenderer->pvBackend;

    PRECORDINGRENDERSDLTEXTURE pDstTex = recRenderSDLTexFromRef(pDstTexture);

    RECORDINGSURFACEINFO const *pSrcInfo = pSrcTexture->pInfo;
    RECORDINGSURFACEINFO const *pDstInfo = &pDstTex->Info;

#ifdef VBOX_STRICT
    AssertReturn(pSrcInfo->enmPixelFmt == RECORDINGPIXELFMT_BRGA32, VERR_NOT_SUPPORTED);
    AssertReturn(pDstInfo->enmPixelFmt == RECORDINGPIXELFMT_BRGA32, VERR_NOT_SUPPORTED);
    AssertReturn(pSrcInfo->uBPP == 32, VERR_NOT_SUPPORTED);
    AssertReturn(pDstInfo->uBPP == 32, VERR_NOT_SUPPORTED);
#endif

    int32_t sx = 0;
    int32_t sy = 0;
    int32_t sw = (int32_t)pSrcInfo->uWidth;
    int32_t sh = (int32_t)pSrcInfo->uHeight;
    int32_t dx = 0;
    int32_t dy = 0;
    int32_t dw = sw;
    int32_t dh = sh;

    switch (pResizeParms->enmMode)
    {
        case RecordingVideoScalingMode_NearestNeighbor:
            dw = (int32_t)pRenderer->Parms.Info.uWidth;
            dh = (int32_t)pRenderer->Parms.Info.uHeight;
            break;

        case RecordingVideoScalingMode_None:
        default:
        {
            RECORDINGVIDEOFRAME SrcFrame;
            RECORDINGVIDEOFRAME DstFrame;
            RT_ZERO(SrcFrame);
            RT_ZERO(DstFrame);
            SrcFrame.Info = *pSrcInfo;
            DstFrame.Info = *pDstInfo;

            RTRECT DstRect;
            RTRECT SrcRect;
            int const vrc = recRenderSWFrameResizeCropCenter(&DstFrame, &SrcFrame, &DstRect, &SrcRect);
            if (RT_SUCCESS(vrc))
            {
                sx = SrcRect.xLeft;
                sy = SrcRect.yTop;
                sw = SrcRect.xRight  - SrcRect.xLeft;
                sh = SrcRect.yBottom - SrcRect.yTop;

                dx = DstRect.xLeft;
                dy = DstRect.yTop;
                dw = DstRect.xRight  - DstRect.xLeft;
                dh = DstRect.yBottom - DstRect.yTop;
            }
            else
                return vrc;
            break;
        }
    }

    pResizeParms->srcRect.xLeft   = sx;
    pResizeParms->srcRect.yTop    = sy;
    pResizeParms->srcRect.xRight  = sx + sw;
    pResizeParms->srcRect.yBottom = sy + sh;
    pResizeParms->dstRect.xLeft   = dx;
    pResizeParms->dstRect.yTop    = dy;
    pResizeParms->dstRect.xRight  = dx + dw;
    pResizeParms->dstRect.yBottom = dy + dh;

    if (   sw <= 0
        || sh <= 0
        || dw <= 0
        || dh <= 0)
        return VWRN_RECORDING_ENCODING_SKIPPED;

    SDL_Texture *pSvrcSDLTex = NULL;
    PCRECORDINGRENDERSDLTEXTURE pSrcTex = recRenderSDLTexFromRefC(pSrcTexture);
    if (pSrcTex)
        pSvrcSDLTex = pSrcTex->pTexture;
    AssertPtr(pSvrcSDLTex);

    SDL_Texture *pOldTarget = pSDL->pfnGetRenderTarget(pSDL->pRenderer);
    int vrcSDL = pSDL->pfnSetRenderTarget(pSDL->pRenderer, pDstTex->pTexture);
    if (vrcSDL == 0)
    {
        pSDL->pfnSetRenderDrawColor(pSDL->pRenderer, 0, 0, 0, 255);
        vrcSDL = pSDL->pfnRenderClear(pSDL->pRenderer);
    }
    if (vrcSDL == 0)
    {
        SDL_Rect const SrcRect = { sx, sy, sw, sh };
        SDL_Rect const DstRect = { dx, dy, dw, dh };
        pSDL->pfnSetTextureBlendMode(pSvrcSDLTex, SDL_BLENDMODE_NONE);
        vrcSDL = pSDL->pfnRenderCopy(pSDL->pRenderer, pSvrcSDLTex, &SrcRect, &DstRect);
    }

    int const rcRestore = pSDL->pfnSetRenderTarget(pSDL->pRenderer, pOldTarget);
    Assert(rcRestore == 0); RT_NOREF(rcRestore);

    if (vrcSDL != 0)
        return VERR_RECORDING_BACKEND_ERROR;

#ifdef VBOX_RECORDING_DEBUG_DUMP_FRAMES
    recRenderSDLDbgDumpBGRATexture(pSDL, pDstTex->pTexture,
                                   pDstInfo->uWidth, pDstInfo->uHeight,
                                   pRenderer->msLastRenderedTS, "render-sdl-resized");
#endif

    return VINF_SUCCESS;
}

/** @copydoc RECORDINGRENDEROPS::pfnConvert */
static DECLCALLBACK(int) recRenderSDLConvert(PRECORDINGRENDERER pRenderer,
                                             PRECORDINGRENDERTEXTURE pDstTexture,
                                             PCRECORDINGRENDERTEXTURE pSrcTexture)
{
    PRECORDINGRENDERSDL pSDL = (PRECORDINGRENDERSDL)pRenderer->pvBackend;

    PRECORDINGRENDERSDLTEXTURE pDstTex = recRenderSDLTexFromRef(pDstTexture);

    RECORDINGSURFACEINFO const *pDstInfo = &pDstTex->Info;
    RECORDINGSURFACEINFO const *pSrcInfo = pSrcTexture->pInfo;

    if (pDstInfo->enmPixelFmt == pSrcInfo->enmPixelFmt)
        return VINF_SUCCESS;

    RECORDINGPIXELFMT const enmDstFmt = pDstInfo->enmPixelFmt;
    RECORDINGPIXELFMT const enmSrcFmt = pSrcInfo->enmPixelFmt;
    uint8_t const           uSrcBPP   = pSrcInfo->uBPP;

    Assert(enmDstFmt == RECORDINGPIXELFMT_YUVI420);
    Assert(enmSrcFmt == RECORDINGPIXELFMT_BRGA32);
    Assert(uSrcBPP == 32);

    uint32_t const uSrcX      = 0;
    uint32_t const uSrcY      = 0;
    uint32_t const uDstX      = 0;
    uint32_t const uDstY      = 0;
    uint32_t const uSrcWidth  = RT_MIN(pSrcInfo->uWidth,  pDstInfo->uWidth);
    uint32_t const uSrcHeight = RT_MIN(pSrcInfo->uHeight, pDstInfo->uHeight);
    uint32_t const uSrcStride = uSrcWidth * 4;
    uint32_t const uDstWidth  = pDstInfo->uWidth;
    uint32_t const uDstHeight = pDstInfo->uHeight;

    size_t const cbSrc = (size_t)uSrcStride * uSrcHeight;
    uint8_t *pu8Src = (uint8_t *)RTMemAlloc(cbSrc);
    AssertPtrReturn(pu8Src, VERR_NO_MEMORY);

    PCRECORDINGRENDERSDLTEXTURE pSrcTex = recRenderSDLTexFromRefC(pSrcTexture);
    if (pSrcTex)
    {
        SDL_Texture *pOldTarget = pSDL->pfnGetRenderTarget(pSDL->pRenderer);
        int vrcSDL = pSDL->pfnSetRenderTarget(pSDL->pRenderer, pSrcTex->pTexture);
        if (vrcSDL == 0)
            vrcSDL = pSDL->pfnRenderReadPixels(pSDL->pRenderer, NULL, SDL_PIXELFORMAT_BGRA8888, pu8Src, (int)uSrcStride);

        int const rcRestore = pSDL->pfnSetRenderTarget(pSDL->pRenderer, pOldTarget);
        Assert(rcRestore == 0); RT_NOREF(rcRestore);

        if (vrcSDL != 0)
        {
            RTMemFree(pu8Src);
            return VERR_RECORDING_BACKEND_ERROR;
        }
    }
    else
    {
        RECORDINGVIDEOFRAME const *pSrcFrame = (RECORDINGVIDEOFRAME const *)pSrcTexture->pvBackend;
        AssertPtrReturnStmt(pSrcFrame, RTMemFree(pu8Src), VERR_INVALID_POINTER);
        AssertPtrReturnStmt(pSrcFrame->pau8Buf, RTMemFree(pu8Src), VERR_INVALID_POINTER);

        for (uint32_t y = 0; y < uSrcHeight; y++)
        {
            memcpy(pu8Src + (size_t)y * uSrcStride,
                   pSrcFrame->pau8Buf + (size_t)(uSrcY + y) * pSrcInfo->uBytesPerLine + (size_t)uSrcX * 4,
                   uSrcStride);
        }
    }

#ifdef VBOX_RECORDING_DEBUG_DUMP_FRAMES
    {
        RECORDINGVIDEOFRAME DbgFrame;
        RT_ZERO(DbgFrame);
        DbgFrame.Info.uWidth        = uSrcWidth;
        DbgFrame.Info.uHeight       = uSrcHeight;
        DbgFrame.Info.uBPP          = 32;
        DbgFrame.Info.enmPixelFmt   = RECORDINGPIXELFMT_BRGA32;
        DbgFrame.Info.uBytesPerLine = uSrcStride;
        DbgFrame.pau8Buf            = pu8Src;
        DbgFrame.cbBuf              = cbSrc;

        RecordingDbgDumpVideoFrame(&DbgFrame, "render-sdl-convert", pRenderer->msLastRenderedTS);
    }
#endif

    size_t const cbSrcYuv = (size_t)uSrcWidth * uSrcHeight * 3 / 2;
    uint8_t *pu8SrcYuv = (uint8_t *)RTMemAlloc(cbSrcYuv);
    AssertPtrReturnStmt(pu8SrcYuv, RTMemFree(pu8Src), VERR_NO_MEMORY);

    int const vrcSDL = pSDL->pfnConvertPixels((int)uSrcWidth, (int)uSrcHeight,
                                              SDL_PIXELFORMAT_BGRA8888, pu8Src, (int)uSrcStride,
                                              SDL_PIXELFORMAT_IYUV, pu8SrcYuv, (int)uSrcWidth);
    if (vrcSDL < 0)
    {
        RTMemFree(pu8SrcYuv);
        RTMemFree(pu8Src);
        return VERR_RECORDING_BACKEND_ERROR;
    }

    size_t const cbDst = (size_t)uDstWidth * uDstHeight * 3 / 2;
    uint8_t *pu8Dst = (uint8_t *)RTMemAlloc(cbDst);
    AssertPtrReturnStmt(pu8Dst, RTMemFree(pu8SrcYuv); RTMemFree(pu8Src), VERR_NO_MEMORY);

    uint8_t *pu8DstY = pu8Dst;
    uint8_t *pu8DstU = pu8DstY + (size_t)uDstWidth * uDstHeight;
    uint8_t *pu8DstV = pu8DstU + (size_t)(uDstWidth / 2) * (uDstHeight / 2);

    memset(pu8DstY, 0x00, (size_t)uDstWidth * uDstHeight);
    memset(pu8DstU, 0x80, (size_t)(uDstWidth / 2) * (uDstHeight / 2));
    memset(pu8DstV, 0x80, (size_t)(uDstWidth / 2) * (uDstHeight / 2));

    uint8_t const *pu8SrcY = pu8SrcYuv;
    uint8_t const *pu8SrcU = pu8SrcY + (size_t)uSrcWidth * uSrcHeight;
    uint8_t const *pu8SrcV = pu8SrcU + (size_t)(uSrcWidth / 2) * (uSrcHeight / 2);

    uint32_t const cyY = (uDstY < uDstHeight) ? RT_MIN(uSrcHeight, uDstHeight - uDstY) : 0;
    uint32_t const cxY = (uDstX < uDstWidth)  ? RT_MIN(uSrcWidth,  uDstWidth  - uDstX) : 0;
    for (uint32_t y = 0; y < cyY; y++)
    {
        memcpy(pu8DstY + (size_t)(uDstY + y) * uDstWidth + uDstX,
               pu8SrcY + (size_t)y * uSrcWidth,
               cxY);
    }

    uint32_t const uDstUVWidth  = uDstWidth  / 2;
    uint32_t const uDstUVHeight = uDstHeight / 2;
    uint32_t const uSrcUVWidth  = uSrcWidth  / 2;
    uint32_t const uSrcUVHeight = uSrcHeight / 2;
    uint32_t const uDstUVX      = uDstX / 2;
    uint32_t const uDstUVY      = uDstY / 2;
    uint32_t const cyUV = (uDstUVY < uDstUVHeight) ? RT_MIN(uSrcUVHeight, uDstUVHeight - uDstUVY) : 0;
    uint32_t const cxUV = (uDstUVX < uDstUVWidth)  ? RT_MIN(uSrcUVWidth,  uDstUVWidth  - uDstUVX) : 0;
    for (uint32_t y = 0; y < cyUV; y++)
    {
        memcpy(pu8DstU + (size_t)(uDstUVY + y) * uDstUVWidth + uDstUVX,
               pu8SrcU + (size_t)y * uSrcUVWidth,
               cxUV);
        memcpy(pu8DstV + (size_t)(uDstUVY + y) * uDstUVWidth + uDstUVX,
               pu8SrcV + (size_t)y * uSrcUVWidth,
               cxUV);
    }

    int const rcUpdate = pSDL->pfnUpdateTexture(pDstTex->pTexture, NULL, pu8Dst, (int)uDstWidth);

    RTMemFree(pu8Dst);
    RTMemFree(pu8SrcYuv);
    RTMemFree(pu8Src);

    return rcUpdate == 0 ? VINF_SUCCESS : VERR_RECORDING_BACKEND_ERROR;
}

/** @copydoc RECORDINGRENDEROPS::pfnInit */
static DECLCALLBACK(int) recRenderSDLInit(PRECORDINGRENDERER pRenderer, void *pvBackend)
{
    RT_NOREF(pvBackend);

    PRECORDINGRENDERSDL pSDL = (PRECORDINGRENDERSDL)RTMemAllocZ(sizeof(RECORDINGRENDERSDL));
    AssertPtrReturn(pSDL, VERR_NO_MEMORY);

    /* Attach backend state early so all failure paths can use one cleanup routine. */
    pRenderer->pvBackend = pSDL;

    int vrc = recRenderSDLResolveSymbols(pSDL);
    if (RT_FAILURE(vrc))
    {
        recRenderSDLDestroy(pRenderer);
        return VERR_RECORDING_BACKEND_INIT_FAILED;
    }

    if (!(pSDL->pfnWasInit(SDL_INIT_VIDEO) & SDL_INIT_VIDEO))
    {
        if (pSDL->pfnInitSubSystem(SDL_INIT_VIDEO) != 0)
        {
            recRenderSDLDestroy(pRenderer);
            return VERR_RECORDING_BACKEND_INIT_FAILED;
        }
        pSDL->fOwnVideoSubSys = true;
    }

    pSDL->pWindow = pSDL->pfnCreateWindow("VBoxRecSDLWnd",
                                          SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
                                          1, 1, SDL_WINDOW_HIDDEN);
    if (!pSDL->pWindow)
    {
        recRenderSDLDestroy(pRenderer);
        return VERR_RECORDING_BACKEND_INIT_FAILED;
    }

    pSDL->pRenderer = pSDL->pfnCreateRenderer(pSDL->pWindow, -1,
                                              SDL_RENDERER_ACCELERATED | SDL_RENDERER_TARGETTEXTURE);
    if (!pSDL->pRenderer)
    {
        LogRel(("Recording: SDL backend is unable to provide hardware acceleration, falling back to software renderer\n"));
        pSDL->pRenderer = pSDL->pfnCreateRenderer(pSDL->pWindow, -1,
                                                 SDL_RENDERER_SOFTWARE | SDL_RENDERER_TARGETTEXTURE);
    }

    if (!pSDL->pRenderer)
    {
        recRenderSDLDestroy(pRenderer);
        return VERR_RECORDING_BACKEND_INIT_FAILED;
    }

    recRenderSDLLogRendererInfo(pSDL);

   /* Ensure predictable alpha behavior for cursor blending related operations. */
    pSDL->pfnSetRenderDrawBlendMode(pSDL->pRenderer, SDL_BLENDMODE_BLEND);

    return VINF_SUCCESS;
}

/**
 * SDL backend destroy callback.
 *
 * @param   pRenderer           Renderer instance.
 */
static DECLCALLBACK(void) recRenderSDLDestroy(PRECORDINGRENDERER pRenderer)
{
    PRECORDINGRENDERSDL pSDL = (PRECORDINGRENDERSDL)pRenderer->pvBackend;
    if (!pSDL)
        return;

    if (pSDL->pRenderer)
        pSDL->pfnDestroyRenderer(pSDL->pRenderer);
    if (pSDL->pWindow)
        pSDL->pfnDestroyWindow(pSDL->pWindow);
    pSDL->pRenderer = NULL;
    pSDL->pWindow   = NULL;

    if (pSDL->fOwnVideoSubSys)
        pSDL->pfnQuitSubSystem(SDL_INIT_VIDEO);

    if (pSDL->hLdrModSDL != NIL_RTLDRMOD)
    {
        RTLdrClose(pSDL->hLdrModSDL);
        pSDL->hLdrModSDL = NIL_RTLDRMOD;
    }

    RTMemFree(pSDL);
    pRenderer->pvBackend = NULL;
}

/**
 * SDL renderer operation table.
 */
static const RECORDINGRENDEROPS g_RecordingRenderOpsSDL =
{
    recRenderSDLProbe,
    recRenderSDLInit,
    recRenderSDLDestroy,
    recRenderSDLQueryCaps,
    recRenderSDLTextureCreate,
    recRenderSDLTextureDestroy,
    recRenderSDLTextureClear,
    recRenderSDLTextureQueryPixelData,
    recRenderSDLTextureUpdate,
    recRenderSDLBlit,
    recRenderSDLBlend,
    recRenderSDLResize,
    recRenderSDLConvert
};
#endif /* VBOX_WITH_RECORDING_SDL_BACKEND */


/*********************************************************************************************************************************
 * Recording renderer API                                                                                                        *
 ********************************************************************************************************************************/

/**
 * Selects backend operation table and marks active backend.
 *
 * @returns VBox status code.
 * @param   pRenderer           Renderer instance.
 * @param   enmBackend          Backend to select.
 */
static int recordingRenderBackendSelect(PRECORDINGRENDERER pRenderer, RECORDINGRENDERBACKEND enmBackend)
{
    AssertPtrReturn(pRenderer, VERR_INVALID_POINTER);

    switch (enmBackend)
    {
        case RECORDINGRENDERBACKEND_AUTO:
#ifdef VBOX_WITH_RECORDING_SDL_BACKEND
            /* Prefer SDL in auto mode when compiled in; probe/init fallback handles failures. */
            pRenderer->enmBackend = RECORDINGRENDERBACKEND_SDL;
            pRenderer->pOps       = &g_RecordingRenderOpsSDL;
#endif
            RT_FALL_THROUGH();

#ifdef VBOX_WITH_RECORDING_SDL_BACKEND
        case RECORDINGRENDERBACKEND_SDL:
            pRenderer->enmBackend = RECORDINGRENDERBACKEND_SDL;
            pRenderer->pOps       = &g_RecordingRenderOpsSDL;
            break;
#endif
        case RECORDINGRENDERBACKEND_SOFTWARE:
            pRenderer->enmBackend = RECORDINGRENDERBACKEND_SOFTWARE;
            pRenderer->pOps       = &g_RecordingRenderOpsSoftware;
            break;

        case RECORDINGRENDERBACKEND_OUTTGT:
            pRenderer->enmBackend = RECORDINGRENDERBACKEND_OUTTGT;
            pRenderer->pOps       = &g_RecordingRenderOpsOutTgt;
            break;

        default:
            return VERR_NOT_SUPPORTED;
    }

    LogRel2(("Recording: Selected backend '%s'\n", RecordingUtilsRenderBackendToStr(pRenderer->enmBackend)));
    return VINF_SUCCESS;
}

/**
 * Initializes renderer-common state shared by all backends.
 *
 * @returns VBox status code.
 * @param   pRenderer           Renderer instance.
 */
static int recRenderInitCommon(PRECORDINGRENDERER pRenderer)
{
    RT_ZERO(pRenderer->texFront);
    RT_ZERO(pRenderer->texBack);
    RT_ZERO(pRenderer->texScaled);
    RT_ZERO(pRenderer->texConv);
    RT_ZERO(pRenderer->texVideo);
    RT_ZERO(pRenderer->texCursor);

    pRenderer->enmState = RECORDINGRENDERSTATE_IDLE;

    RT_ZERO(pRenderer->Parms);

    /* The renderer works with BRGA32 by default. */
    pRenderer->Parms.Info.enmPixelFmt = RECORDINGPIXELFMT_BRGA32;

    pRenderer->uCursorOldX = 0;
    pRenderer->uCursorOldY = 0;

    pRenderer->pTexComposite = &pRenderer->texFront;
    pRenderer->pTexScaled    = pRenderer->pTexComposite;
    pRenderer->pTexConv      = pRenderer->pTexScaled;

    pRenderer->msLastRenderedTS = 0;

    return VINF_SUCCESS;
}

/**
 * Initializes a rendering backend.
 *
 * @returns VBox status code.
 * @param   pRenderer           Renderer instance.
 * @param   enmBackend          Preferred backend.
 * @param   pvBackend           Opaque data pointer to pass to the backend's initialization function.
 *                              Optional and might be NULL.
 */
int RecordingRenderInitEx(PRECORDINGRENDERER pRenderer, RECORDINGRENDERBACKEND enmBackend, const void *pvBackend)
{
    AssertPtrReturn(pRenderer, VERR_INVALID_POINTER);

    RT_ZERO(*pRenderer);

    LogRel2(("Recording: Using backend '%s'\n", RecordingUtilsRenderBackendToStr(enmBackend)));

    int vrc = recordingRenderBackendSelect(pRenderer, enmBackend);
    if (RT_FAILURE(vrc))
        return vrc;

    AssertPtrReturn(pRenderer->pOps, VERR_NOT_SUPPORTED);

    bool fFallback = false; /* Whether to fall back to the software backend. */

    if (pRenderer->pOps->pfnProbe)
    {
        LogRel2(("Recording: Probing backend '%s' ...\n", RecordingUtilsRenderBackendToStr(pRenderer->enmBackend)));

        vrc = pRenderer->pOps->pfnProbe(pRenderer);
        if (RT_FAILURE(vrc))
            fFallback = true;
        else
            LogRel2(("Recording: Probing backend '%s' successful\n", RecordingUtilsRenderBackendToStr(pRenderer->enmBackend)));
    }

    if (   RT_SUCCESS(vrc)
        && pRenderer->pOps->pfnInit)
    {
        LogRel2(("Recording: Initializing backend '%s' ...\n", RecordingUtilsRenderBackendToStr(pRenderer->enmBackend)));

        vrc = pRenderer->pOps->pfnInit(pRenderer, pvBackend);
        if (RT_FAILURE(vrc))
        {
            LogRel(("Recording: Rendering backend '%s' init failed (%Rrc), falling back to software backend\n",
                    RecordingUtilsRenderBackendToStr(enmBackend), vrc));

            fFallback = true;

            if (pRenderer->pOps->pfnDestroy)
                pRenderer->pOps->pfnDestroy(pRenderer);
        }
    }

    if (RT_SUCCESS(vrc))
    {
        LogRel(("Recording: Backend '%s' successfully initialized\n", RecordingUtilsRenderBackendToStr(pRenderer->enmBackend)));
    }
    else if (fFallback)
    {
        if (RT_FAILURE(vrc))
            LogRel(("Recording: Probing rendering backend '%s' failed (%Rrc), falling back to software backend\n",
                    RecordingUtilsRenderBackendToStr(pRenderer->enmBackend), vrc));

        vrc = recordingRenderBackendSelect(pRenderer, RECORDINGRENDERBACKEND_SOFTWARE);
        AssertRCReturn(vrc, vrc);

        if (pRenderer->pOps->pfnProbe)
        {
            vrc = pRenderer->pOps->pfnProbe(pRenderer);
            AssertRCReturn(vrc, vrc);
        }

        if (pRenderer->pOps->pfnInit)
        {
            vrc = pRenderer->pOps->pfnInit(pRenderer, pvBackend);
            AssertRCReturn(vrc, vrc);
        }
    }
    else
        AssertFailed(); /* Must never happen. */

    AssertPtrReturn(pRenderer->pOps->pfnQueryCaps, VERR_INVALID_PARAMETER); /* Render backends must implement this. */
    pRenderer->fCaps = pRenderer->pOps->pfnQueryCaps(pRenderer);

    LogRel(("Recording: Using rendering backend '%s' (caps %#RX64)\n",
            RecordingUtilsRenderBackendToStr(pRenderer->enmBackend), pRenderer->fCaps));

    return recRenderInitCommon(pRenderer);
}

int RecordingRenderInit(PRECORDINGRENDERER pRenderer, RECORDINGRENDERBACKEND enmBackend)
{
    return RecordingRenderInitEx(pRenderer, enmBackend, NULL /* pvBackend */);
}

/**
 * Destroys a rendering backend.
 *
 * @param   pRenderer           Renderer instance. Can be NULL.
 */
void RecordingRenderDestroy(PRECORDINGRENDERER pRenderer)
{
    if (!pRenderer)
        return;

    pRenderer->pOps->pfnTextureDestroy(pRenderer, &pRenderer->texFront);
    pRenderer->pOps->pfnTextureDestroy(pRenderer, &pRenderer->texBack);
    pRenderer->pOps->pfnTextureDestroy(pRenderer, &pRenderer->texScaled);
    pRenderer->pOps->pfnTextureDestroy(pRenderer, &pRenderer->texConv);
    pRenderer->pOps->pfnTextureDestroy(pRenderer, &pRenderer->texVideo);
    pRenderer->pOps->pfnTextureDestroy(pRenderer, &pRenderer->texCursor);

    if (pRenderer->pOps->pfnDestroy)
        pRenderer->pOps->pfnDestroy(pRenderer);

    RT_ZERO(*pRenderer);
}

/**
 * Returns capabilities of an initialized renderer.
 *
 * @returns Capability flags of type RECORDINGRENDERCAP_F_*.
 * @param   pRenderer           Renderer instance.
 */
uint64_t RecordingRenderGetCaps(PCRECORDINGRENDERER pRenderer)
{
    if (!pRenderer->pOps->pfnQueryCaps)
        AssertFailedReturn(RECORDINGRENDERCAP_F_NONE); /* Must be implemented. */
    return pRenderer->pOps->pfnQueryCaps(pRenderer);
}

/**
 * Returns the render backend.
 *
 * @returns The render backend.
 * @param   pRenderer       Renderer instance.
 */
RECORDINGRENDERBACKEND RecordingRenderGetBackend(PRECORDINGRENDERER pRenderer)
{
    return pRenderer->enmBackend;
}

/**
 * Applies a screen change to renderer-owned composition state.
 *
 * @returns VBox status code.
 * @param   pRenderer           Renderer instance.
 * @param   pInfo               New screen surface information.
 */
int RecordingRenderScreenChange(PRECORDINGRENDERER pRenderer,
                                PRECORDINGSURFACEINFO pInfo)
{
    LogRel2(("Recording: Renderer got screen change notification (%RU16x%RU16, %RU8 BPP)\n",
             pInfo->uWidth, pInfo->uHeight, pInfo->uBPP));

    AssertMsgReturn(pInfo->enmPixelFmt == RECORDINGPIXELFMT_BRGA32,
                    ("BRGA32 is the only supported pixel format right now"), VERR_INVALID_PARAMETER);

    pRenderer->pOps->pfnTextureDestroy(pRenderer, &pRenderer->texFront);
    pRenderer->pOps->pfnTextureCreate(pRenderer, &pRenderer->texFront, pInfo);
    pRenderer->pOps->pfnTextureClear(pRenderer, &pRenderer->texFront);

    pRenderer->pOps->pfnTextureDestroy(pRenderer, &pRenderer->texBack);
    pRenderer->pOps->pfnTextureCreate(pRenderer, &pRenderer->texBack, pInfo);
    pRenderer->pOps->pfnTextureClear(pRenderer, &pRenderer->texBack);

    pRenderer->pOps->pfnTextureDestroy(pRenderer, &pRenderer->texVideo);
    pRenderer->pOps->pfnTextureCreate(pRenderer, &pRenderer->texVideo, pInfo);
    pRenderer->pOps->pfnTextureClear(pRenderer, &pRenderer->texVideo);

    pRenderer->pOps->pfnTextureDestroy(pRenderer, &pRenderer->texCursor);
    pRenderer->pOps->pfnTextureCreate(pRenderer, &pRenderer->texCursor, pInfo);
    pRenderer->pOps->pfnTextureClear(pRenderer, &pRenderer->texCursor);

    pRenderer->pTexComposite = NULL;

    if (pRenderer->Parms.Info.uWidth == 0)
        pRenderer->Parms.Info.uWidth = pInfo->uWidth;
    if (pRenderer->Parms.Info.uHeight == 0)
        pRenderer->Parms.Info.uHeight = pInfo->uHeight;

    pRenderer->Parms.iOriginX = ((int32_t)pRenderer->Parms.Info.uWidth  - (int32_t)pInfo->uWidth)  / 2;
    pRenderer->Parms.iOriginY = ((int32_t)pRenderer->Parms.Info.uHeight - (int32_t)pInfo->uHeight) / 2;

    Assert(pRenderer->Parms.Info.uWidth);
    Assert(pRenderer->Parms.Info.uHeight);

    pRenderer->pTexComposite = &pRenderer->texFront;

    return VINF_SUCCESS;
}

/**
 * Starts a composition pass.
 *
 * @returns VBox status code.
 * @param   pRenderer           Renderer instance.
 */
int RecordingRenderComposeBegin(PRECORDINGRENDERER pRenderer)
{
    LogFlowFuncEnter();

    Assert(pRenderer->enmState == RECORDINGRENDERSTATE_IDLE);
    pRenderer->enmState = RECORDINGRENDERSTATE_COMPOSING;

    return VINF_SUCCESS;
}

/**
 * Ends a composition pass.
 *
 * @returns VBox status code.
 * @param   pRenderer           Renderer instance.
 */
int RecordingRenderComposeEnd(PRECORDINGRENDERER pRenderer)
{
    LogFlowFuncEnter();

    Assert(pRenderer->enmState == RECORDINGRENDERSTATE_COMPOSING);
    pRenderer->enmState = RECORDINGRENDERSTATE_DONE;

    pRenderer->msLastRenderedTS = RTTimeMilliTS();

    return VINF_SUCCESS;
}

/**
 * Drops a composition pass unconditionally.
 *
 * @param   pRenderer           Renderer instance.
 */
void RecordingRenderComposeDrop(PRECORDINGRENDERER pRenderer)
{
    LogFlowFuncEnter();

    pRenderer->enmState = RECORDINGRENDERSTATE_IDLE;
}

/**
 * Adds a frame to the compositor and uses it for composing the next frame to render.
 *
 * @returns VBox status code.
 * @param   pRenderer           Renderer instance.
 * @param   pFrame              Frame to compose.
 */
int RecordingRenderComposeAddFrame(PRECORDINGRENDERER pRenderer, PRECORDINGFRAME pFrame)
{
    LogFlowFuncEnter();

#ifdef VBOX_STRICT
    AssertPtrReturn(pRenderer, VERR_INVALID_POINTER);
    AssertPtrReturn(pFrame, VERR_INVALID_POINTER);
    AssertReturn(pRenderer->enmState == RECORDINGRENDERSTATE_COMPOSING, VERR_INVALID_STATE);
#endif

    PRECORDINGRENDERTEXTURE pTexFront = &pRenderer->texFront;
    PRECORDINGRENDERTEXTURE pTexBack  = &pRenderer->texBack;

    int vrc = VINF_SUCCESS;

    int32_t sx = 0;
    int32_t sy = 0;
    int32_t sw = 0;
    int32_t sh = 0;
    int32_t dx = 0;
    int32_t dy = 0;

    switch (pFrame->enmType)
    {
        case RECORDINGFRAME_TYPE_VIDEO:
        {
            PRECORDINGVIDEOFRAME pFrameSrc = &pFrame->u.Video;

            vrc = pRenderer->pOps->pfnTextureUpdate(pRenderer, &pRenderer->texVideo, pFrameSrc);
            AssertRCBreak(vrc);

            RTRECT SrcRect;
            SrcRect.xLeft   = 0;
            SrcRect.yTop    = 0;
            SrcRect.xRight  = (int32_t)pFrameSrc->Info.uWidth;
            SrcRect.yBottom = (int32_t)pFrameSrc->Info.uHeight;

            RTRECT DstRect;
            DstRect.xLeft   = (int32_t)pFrameSrc->Pos.x;
            DstRect.yTop    = (int32_t)pFrameSrc->Pos.y;
            DstRect.xRight  = DstRect.xLeft + SrcRect.xRight;
            DstRect.yBottom = DstRect.yTop  + SrcRect.yBottom;

            vrc = pRenderer->pOps->pfnBlit(pRenderer, pTexFront, &DstRect, &pRenderer->texVideo, &SrcRect);
            if (RT_FAILURE(vrc))
                break;

            vrc = pRenderer->pOps->pfnBlit(pRenderer, pTexBack, &DstRect, &pRenderer->texVideo, &SrcRect);
            if (RT_FAILURE(vrc))
                break;

            sw = pFrameSrc->Info.uWidth;
            sh = pFrameSrc->Info.uHeight;
            sx = pFrameSrc->Pos.x;
            sy = pFrameSrc->Pos.y;

            dx = pFrameSrc->Pos.x;
            dy = pFrameSrc->Pos.y;

            PRECORDINGRENDERTEXTURE pTexCursor = &pRenderer->texCursor;
            if (pTexCursor->pvBackend)
            {
                uint32_t const uCurX = pRenderer->uCursorOldX;
                uint32_t const uCurY = pRenderer->uCursorOldY;
                if (   uCurX < pTexFront->pInfo->uWidth
                    && uCurY < pTexFront->pInfo->uHeight)
                {
                    uint32_t const uCurW = RT_MIN(pTexCursor->pInfo->uWidth,  pTexFront->pInfo->uWidth  - uCurX);
                    uint32_t const uCurH = RT_MIN(pTexCursor->pInfo->uHeight, pTexFront->pInfo->uHeight - uCurY);
                    if (uCurW && uCurH)
                    {
                        uint64_t const uUpdX0 = pFrameSrc->Pos.x;
                        uint64_t const uUpdY0 = pFrameSrc->Pos.y;
                        uint64_t const uUpdX1 = uUpdX0 + pFrameSrc->Info.uWidth;
                        uint64_t const uUpdY1 = uUpdY0 + pFrameSrc->Info.uHeight;
                        uint64_t const uCurX0 = uCurX;
                        uint64_t const uCurY0 = uCurY;
                        uint64_t const uCurX1 = uCurX0 + uCurW;
                        uint64_t const uCurY1 = uCurY0 + uCurH;

                        bool const fIntersects =    uUpdX0 < uCurX1
                                                 && uUpdX1 > uCurX0
                                                 && uUpdY0 < uCurY1
                                                 && uUpdY1 > uCurY0;
                        if (fIntersects)
                        {
                            RTRECT SrcRectCursor;
                            RTRECT DstRectCursor;
                            SrcRectCursor.xLeft   = (int32_t)uCurX;
                            SrcRectCursor.yTop    = (int32_t)uCurY;
                            SrcRectCursor.xRight  = (int32_t)(uCurX + uCurW);
                            SrcRectCursor.yBottom = (int32_t)(uCurY + uCurH);
                            DstRectCursor = SrcRectCursor;

                            vrc = pRenderer->pOps->pfnBlit(pRenderer,
                                                           pTexFront, &DstRectCursor,
                                                           pTexBack,  &SrcRectCursor);
                            if (RT_SUCCESS(vrc))
                            {
                                RTRECT SrcRectBlend;
                                RTRECT DstRectBlend;
                                SrcRectBlend.xLeft   = 0;
                                SrcRectBlend.yTop    = 0;
                                SrcRectBlend.xRight  = (int32_t)uCurW;
                                SrcRectBlend.yBottom = (int32_t)uCurH;
                                DstRectBlend.xLeft   = (int32_t)uCurX;
                                DstRectBlend.yTop    = (int32_t)uCurY;
                                DstRectBlend.xRight  = DstRectBlend.xLeft + SrcRectBlend.xRight;
                                DstRectBlend.yBottom = DstRectBlend.yTop  + SrcRectBlend.yBottom;

                                vrc = pRenderer->pOps->pfnBlend(pRenderer,
                                                                pTexFront, &SrcRectBlend,
                                                                pTexCursor, &DstRectBlend);
                            }
                        }
                    }
                }
            }
            break;
        }

        case RECORDINGFRAME_TYPE_CURSOR_SHAPE:
        {
            vrc = pRenderer->pOps->pfnTextureUpdate(pRenderer, &pRenderer->texCursor, &pFrame->u.CursorShape);
            AssertRCBreak(vrc);

            RT_FALL_THROUGH(); /* Re-render cursor with new shape below. */
        }

        case RECORDINGFRAME_TYPE_CURSOR_POS:
        {
            PRECORDINGRENDERTEXTURE pTexCursor = &pRenderer->texCursor;
            if (!pTexCursor->pInfo) /* Some backends might not have cursor support. */
                break;

            RECORDINGPOS PosNew;
            if (pFrame->enmType == RECORDINGFRAME_TYPE_CURSOR_POS)
                PosNew = pFrame->u.Cursor.Pos;
            else
            {
                PosNew.x = pRenderer->uCursorOldX;
                PosNew.y = pRenderer->uCursorOldY;
            }

            sx = RT_MIN(PosNew.x, pRenderer->uCursorOldX);
            sy = RT_MIN(PosNew.y, pRenderer->uCursorOldY);
            sw = (  PosNew.x > pRenderer->uCursorOldX
                  ? PosNew.x - pRenderer->uCursorOldX
                  : pRenderer->uCursorOldX - PosNew.x) + pTexCursor->pInfo->uWidth;
            sh = (  PosNew.y > pRenderer->uCursorOldY
                  ? PosNew.y - pRenderer->uCursorOldY
                  : pRenderer->uCursorOldY - PosNew.y) + pTexCursor->pInfo->uHeight;

            if (sx + sw >= (int32_t)pTexFront->pInfo->uWidth)
                sw = pTexFront->pInfo->uWidth - sx;
            if (sy + sh >= (int32_t)pTexFront->pInfo->uHeight)
                sh = pTexFront->pInfo->uHeight - sy;

            pRenderer->uCursorOldX = PosNew.x;
            pRenderer->uCursorOldY = PosNew.y;

            dx = sx;
            dy = sy;

            if (             sw <= 0
                ||           sh <= 0
                || (uint32_t)sx > pTexBack->pInfo->uWidth
                || (uint32_t)sy > pTexBack->pInfo->uHeight)
                break;

            RTRECT SrcRectMove;
            RTRECT DstRectMove;
            SrcRectMove.xLeft   = sx;
            SrcRectMove.yTop    = sy;
            SrcRectMove.xRight  = sx + sw;
            SrcRectMove.yBottom = sy + sh;
            DstRectMove.xLeft   = dx;
            DstRectMove.yTop    = dy;
            DstRectMove.xRight  = dx + sw;
            DstRectMove.yBottom = dy + sh;

            vrc = pRenderer->pOps->pfnBlit(pRenderer,
                                           pTexFront, &DstRectMove,
                                           pTexBack,  &SrcRectMove);

            if (RT_SUCCESS(vrc))
            {
                RTRECT SrcRectCursor;
                RTRECT DstRectCursor;
                SrcRectCursor.xLeft   = 0;
                SrcRectCursor.yTop    = 0;
                SrcRectCursor.xRight  = (int32_t)pTexCursor->pInfo->uWidth;
                SrcRectCursor.yBottom = (int32_t)pTexCursor->pInfo->uHeight;
                DstRectCursor.xLeft   = (int32_t)PosNew.x;
                DstRectCursor.yTop    = (int32_t)PosNew.y;
                DstRectCursor.xRight  = DstRectCursor.xLeft + SrcRectCursor.xRight;
                DstRectCursor.yBottom = DstRectCursor.yTop  + SrcRectCursor.yBottom;

                vrc = pRenderer->pOps->pfnBlend(pRenderer,
                                                pTexFront, &SrcRectCursor,
                                                pTexCursor, &DstRectCursor);
            }
            break;
        }

        default:
            AssertFailed();
            vrc = VERR_INVALID_PARAMETER;
            break;

    }

    if (RT_FAILURE(vrc))
        return vrc;

    if (   sw == 0
        || sh == 0)
        return VWRN_RECORDING_ENCODING_SKIPPED;

    pRenderer->pTexComposite = pTexFront;

    return VINF_SUCCESS;
}

/**
 * Performs resize/scaling and conversion passes for the current composed frame.
 *
 * @returns VBox status code.
 * @param   pRenderer           Renderer instance.
 */
int RecordingRenderPerform(PRECORDINGRENDERER pRenderer)
{
    Assert(pRenderer->enmState == RECORDINGRENDERSTATE_DONE);
    AssertPtr(pRenderer->pTexComposite);
    AssertPtr(pRenderer->pTexScaled);
    AssertPtr(pRenderer->pTexConv);

    int vrc = VINF_SUCCESS;

    RECORDINGRENDERRESIZEPARMS ResizeParms;
    RT_ZERO(ResizeParms);
    ResizeParms.enmMode = pRenderer->Parms.enmScalingMode;

    if (pRenderer->pOps->pfnResize)
    {
        vrc = pRenderer->pOps->pfnResize(pRenderer,
                                         pRenderer->pTexScaled, pRenderer->pTexComposite,
                                         &ResizeParms);
        AssertRC(vrc);
    }

    if (pRenderer->pOps->pfnConvert)
    {
        vrc = pRenderer->pOps->pfnConvert(pRenderer, pRenderer->pTexConv, pRenderer->pTexScaled);
        AssertRC(vrc);
    }

    pRenderer->enmState = RECORDINGRENDERSTATE_IDLE;

    return VINF_SUCCESS;
}

/**
 * Queries the pixel data from the currently composed frame.
 *
 * @returns VBox status code.
 * @param   pRenderer           Renderer instance.
 * @param   pFrame              Where to store the pixel data.
 *                              Note! The frame flags might be updated on return.
 */
int RecordingRenderQueryFrame(PRECORDINGRENDERER pRenderer, PRECORDINGVIDEOFRAME pFrame)
{
    PRECORDINGRENDERTEXTURE pTexSrc = pRenderer->pTexConv;
    AssertPtr(pTexSrc);

    int vrc = pRenderer->pOps->pfnTextureQueryPixelData(pRenderer, pTexSrc,
                                                        (void **)&pFrame->pau8Buf,
                                                        &pFrame->cbBuf);
    if (RT_FAILURE(vrc))
        return vrc;

    /* Use pointer of the the pass 3 texture to get the final frame (original / resized / converted). */
    AssertPtr(pTexSrc->pInfo);
    pFrame->Info = *pTexSrc->pInfo;

    /* Instead of copying the pixel data over to pFrame, backends only sets the pointer to the data.
     * In that case the backend texture remains the owner of the pixel data and thus pFrame isn't allowed to destroy it. */
    if (   pRenderer->enmBackend == RECORDINGRENDERBACKEND_SOFTWARE
        || pRenderer->enmBackend == RECORDINGRENDERBACKEND_OUTTGT)
        pFrame->fFlags |= RECORDINGVIDEOFRAME_F_NO_DESTROY;

    return vrc;
}

/**
 * Sets renderer-owned resize / conversion parameters.
 *
 * @returns VBox status code.
 * @param   pRenderer           Renderer instance.
 * @param   pParms              Rendering output parameters to set.
 */
int RecordingRenderSetParms(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERPARMS pParms)
{
    AssertReturn(pParms->Info.uHeight, VERR_INVALID_PARAMETER);
    AssertReturn(pParms->Info.uWidth, VERR_INVALID_PARAMETER);
    AssertReturn(pParms->Info.enmPixelFmt != RECORDINGPIXELFMT_UNKNOWN, VERR_INVALID_PARAMETER);
    AssertReturn(pParms->Info.uBPP, VERR_INVALID_PARAMETER);
    AssertReturn(pParms->Info.uBPP % 8 == 0, VERR_INVALID_PARAMETER);

    LogRel2(("Recording: Rendering parameters:\n"));
    LogRel2(("Recording:   - Scaling mode: %s\n", RecordingUtilsVideoScalingModeToStr(pParms->enmScalingMode)));
    LogRel2(("Recording:   - Scaling size: %u x %u\n", pParms->Info.uWidth, pParms->Info.uHeight));
    LogRel2(("Recording:   - Pixel format: %#x (%u BPP)\n", pParms->Info.enmPixelFmt, pParms->Info.uBPP));

    /*
     * Keep crop/center origin in sync when parameters are updated after
     * the framebuffer is already known.
     */
    if (   pRenderer->texFront.pvBackend
        && pRenderer->texFront.pInfo->uWidth
        && pRenderer->texFront.pInfo->uHeight
        && pRenderer->Parms.Info.uWidth
        && pRenderer->Parms.Info.uHeight
        && pParms->iOriginX == 0
        && pParms->iOriginY == 0)
    {
        pRenderer->Parms.iOriginX = ((int32_t)pRenderer->Parms.Info.uWidth  - (int32_t)pRenderer->texFront.pInfo->uWidth)  / 2;
        pRenderer->Parms.iOriginY = ((int32_t)pRenderer->Parms.Info.uHeight - (int32_t)pRenderer->texFront.pInfo->uHeight) / 2;
    }

    int vrc = VINF_SUCCESS;

    /* Parameters not set? Use the renderer's parameters. */
    if (pParms->Info.uBPP == 0)
        pParms->Info.uBPP = pRenderer->Parms.Info.uBPP;

    /* Save the pixel format which we need for the conversion texture only.
     * Internally the renderer always works with BRGA32. */
    RECORDINGPIXELFMT const enmConvPixelFmt = pParms->Info.enmPixelFmt == RECORDINGPIXELFMT_UNKNOWN
                                            ? RECORDINGPIXELFMT_BRGA32  : pParms->Info.enmPixelFmt;
    pParms->Info.enmPixelFmt = pRenderer->Parms.Info.enmPixelFmt;

    /*
     * Pass 1 of the pipeline: Composition
     */
    /* Already done via RecordingRenderPerform(). */

    /*
     * Pass 2 of the pipeline: Scaling
     */
    uint32_t const uDstWidth  = pParms->Info.uWidth
                              ? pParms->Info.uWidth  : pRenderer->Parms.Info.uWidth;
    uint32_t const uDstHeight = pParms->Info.uHeight
                              ? pParms->Info.uHeight : pRenderer->Parms.Info.uHeight;

    if (   uDstWidth  != pRenderer->Parms.Info.uWidth
        || uDstHeight != pRenderer->Parms.Info.uHeight)
    {
        /* Some render backends require a scaled destination texture. */
        pRenderer->pOps->pfnTextureDestroy(pRenderer, &pRenderer->texScaled);
        vrc = pRenderer->pOps->pfnTextureCreate(pRenderer, &pRenderer->texScaled, &pParms->Info);
        if (RT_SUCCESS(vrc))
            pRenderer->pTexScaled = &pRenderer->texScaled;
    }
    else
        pRenderer->pTexScaled = pRenderer->pTexComposite;

    if (RT_FAILURE(vrc))
        return vrc;

    /*
     * Pass 3 of the pipeline: Conversion
     */
    if (enmConvPixelFmt != pRenderer->Parms.Info.enmPixelFmt)
    {
        pParms->Info.enmPixelFmt = enmConvPixelFmt;

        /* Some render backends require a (pre-)converted destination texture. */
        pRenderer->pOps->pfnTextureDestroy(pRenderer, &pRenderer->texConv);
        vrc = pRenderer->pOps->pfnTextureCreate(pRenderer, &pRenderer->texConv, &pParms->Info);
        if (RT_SUCCESS(vrc))
            pRenderer->pTexConv = &pRenderer->texConv;
    }
    else /* No conversion -- point to the scaled texture (if any). */
        pRenderer->pTexConv = pRenderer->pTexScaled;

    /* Sanity. */
    AssertPtr(pRenderer->pTexComposite);
    AssertPtr(pRenderer->pTexConv);
    AssertPtr(pRenderer->pTexScaled);

    pRenderer->Parms = *pParms;

    return vrc;
}

