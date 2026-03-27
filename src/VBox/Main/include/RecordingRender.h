/* $Id: RecordingRender.h 113625 2026-03-27 13:46:36Z andreas.loeffler@oracle.com $ */
/** @file
 * Recording rendering backend abstraction.
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

#ifndef MAIN_INCLUDED_src_client_RecordingRender_h
#define MAIN_INCLUDED_src_client_RecordingRender_h
#ifndef RT_WITHOUT_PRAGMA_ONCE
# pragma once
#endif

#include <iprt/cdefs.h>
#include <iprt/types.h>

#include "RecordingContext.h"
#include "RecordingInternals.h"

struct RECORDINGVIDEOFRAME;
typedef RECORDINGVIDEOFRAME *PRECORDINGVIDEOFRAME;

struct RECORDINGFRAME;
typedef struct RECORDINGFRAME *PRECORDINGFRAME;

struct RECORDINGSURFACEINFO;
typedef struct RECORDINGSURFACEINFO *PRECORDINGSURFACEINFO;

struct RECORDINGRENDERER;
typedef RECORDINGRENDERER *PRECORDINGRENDERER;

/**
 * Rendering backend type.
 */
typedef enum RECORDINGRENDERBACKEND
{
    /** Let the renderer choose an appropriate backend. */
    RECORDINGRENDERBACKEND_AUTO       = 0,
    /** Pure software backend. */
    RECORDINGRENDERBACKEND_SOFTWARE   = 1,
    /** SDL-based backend. */
    RECORDINGRENDERBACKEND_SDL        = 2
} RECORDINGRENDERBACKEND;

/**
 * Generic renderer texture reference.
 *
 * This is a lightweight non-owning wrapper that can reference backend-specific
 * texture objects (for example SDL_Texture* in SDL backend, or
 * PRECORDINGVIDEOFRAME in software backend via pvBackend).
 */
typedef struct RECORDINGRENDERTEXTURE
{
    /** Opaque backend-specific texture handle. */
    void                 *pvBackend;
    /** Pointer to surface information describing this texture reference.
     *  Note: Where this points at is up to the backend. Must not be NULL! */
    PRECORDINGSURFACEINFO pInfo;
} RECORDINGRENDERTEXTURE;
/** Pointer to a generic renderer texture reference. */
typedef RECORDINGRENDERTEXTURE *PRECORDINGRENDERTEXTURE;
/** Pointer to a const generic renderer texture reference. */
typedef RECORDINGRENDERTEXTURE const *PCRECORDINGRENDERTEXTURE;

/** No caps defined. */
#define RECORDINGRENDERCAP_F_NONE                0
/** Supports raw blit operation. */
#define RECORDINGRENDERCAP_F_BLIT_RAW            RT_BIT(0)
/** Supports frame-to-frame blit operation. */
#define RECORDINGRENDERCAP_F_BLIT_FRAME          RT_BIT(1)
/** Supports alpha blending operation. */
#define RECORDINGRENDERCAP_F_BLEND_ALPHA         RT_BIT(2)
/** Supports generic color conversion operation. */
#define RECORDINGRENDERCAP_F_CONVERT             RT_BIT(3)
/** Supports resize/scaling operation. */
#define RECORDINGRENDERCAP_F_RESIZE              RT_BIT(4)

/**
 * Renderer-owned parameters for resize / conversion.
 */
typedef struct RECORDINGRENDERPARAMS
{
    /** Surface properties of the renderer output. */
    RECORDINGSURFACEINFO   Info;
    /** Scaling mode to apply. */
    RecordingVideoScalingMode_T
                           enmScalingMode;
    /** Crop/center X origin offset (in pixels).
     *  Set to 0 for most scaling modes. */
    int32_t                iOriginX;
    /** Crop/center Y origin offset (in pixels).
     *  Set to 0 for most scaling modes. */
    int32_t                iOriginY;
} RECORDINGRENDERPARAMS;
/** Pointer to renderer parameters. */
typedef RECORDINGRENDERPARAMS *PRECORDINGRENDERPARMS;
/** Pointer to const renderer parameters. */
typedef RECORDINGRENDERPARAMS const *PCRECORDINGRENDERPARAMS;

typedef const struct RECORDINGRENDERER *PCRECORDINGRENDERER;

/**
 * Rendering backend operations.
 *
 * All operations are optional unless stated otherwise.
 * Falls back to internal software renderer.
 */
typedef struct RECORDINGRENDEROPS
{
    /**
     * Probes backend availability on current host/runtime. Optional.
     *
     * @returns VINF_SUCCESS when backend is available, otherwise a failure code.
     * @param   pRenderer           Renderer instance.
     */
    DECLCALLBACKMEMBER(int, pfnProbe, (PCRECORDINGRENDERER pRenderer));

    /**
     * Initializes backend specific state. Optional.
     *
     * @returns VBox status code.
     * @param   pRenderer           Renderer instance.
     */
    DECLCALLBACKMEMBER(int, pfnInit, (PRECORDINGRENDERER pRenderer));

    /**
     * Destroys backend specific state.
     *
     * @param   pRenderer           Renderer instance.
     */
    DECLCALLBACKMEMBER(void, pfnDestroy, (PRECORDINGRENDERER pRenderer));

    /**
     * Returns backend capabilities (RECORDINGRENDERCAP_*).
     *
     * Must be implemented.
     *
     * @returns Capability flags of type RECORDINGRENDERCAP_F_*.
     * @param   pRenderer           Renderer instance.
     */
    DECLCALLBACKMEMBER(uint64_t, pfnQueryCaps, (PCRECORDINGRENDERER pRenderer));

    /**
     * Creates (or initializes) a backend texture object.
     *
     * @returns VBox status code.
     * @param   pRenderer           Renderer instance.
     * @param   pTexture            Texture handle wrapper to initialize.
     * @param   pInfo               Surface properties for the texture.
     */
    DECLCALLBACKMEMBER(int, pfnTextureCreate, (PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture, PRECORDINGSURFACEINFO pInfo));

    /**
     * Destroys a previously created backend texture object.
     *
     * @param   pRenderer           Renderer instance.
     * @param   pTexture            Texture handle wrapper to destroy/reset.
     */
    DECLCALLBACKMEMBER(void, pfnTextureDestroy, (PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture));

    /**
     * Clears a texture to backend-defined default contents.
     *
     * @param   pRenderer           Renderer instance.
     * @param   pTexture            Texture handle wrapper to clear.
     */
    DECLCALLBACKMEMBER(void, pfnTextureClear, (PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture));

    /**
     * Queries pixel data of a texture.
     *
     * @param   pRenderer           Renderer instance.
     * @param   pTexture            Texture handle wrapper to query pixel data from.
     * @param   ppvBuf              Where to store the pixel data.
     *                              Note! Depending on the backend this might be a direct pointer or an allocated copy of the pixel
     *                                    data. Check the backend to know if the caller needs to use RTMemFree()!
     * @param   pcbBuf              Size (in bytes) of \a ppvBuf.
     *
     * @note    The operation might be (very) slow, depending on how the backend handles the texture data.
     *          For accelerated backends this most probably means a GPU -> CPU copy operation.
     */
    DECLCALLBACKMEMBER(int, pfnTextureQueryPixelData, (PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture, void **ppvBuf, size_t *pcbBuf));

    /**
     * Updates a texture with a given video frame.
     *
     * @returns VBox status code.
     * @param   pRenderer           Renderer instance.
     * @param   pTexture            Texture handle wrapper to update.
     * @param   pFrame              Video frame to use for updating the texture.
     */
    DECLCALLBACKMEMBER(int, pfnTextureUpdate, (PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pTexture, PRECORDINGVIDEOFRAME pFrame));

    /**
     * Blits one backend texture reference into another.
     *
     * @returns VBox status code.
     * @param   pRenderer           Renderer instance.
     * @param   pDstTexture         Destination texture.
     * @param   pDstRect            Destination rectangle.
     * @param   pSrcTexture         Source texture.
     * @param   pSrcRect            Source rectangle.
     */
    DECLCALLBACKMEMBER(int, pfnBlit, (PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pDstTexture, PRTRECT pDstRect, PCRECORDINGRENDERTEXTURE pSrcTexture, PRTRECT pSrcRect));

    /**
     * Alpha blends raw source image data into destination texture reference.
     *
     * @returns VBox status code.
     * @param   pRenderer           Renderer instance.
     * @param   pDstTexture         Destination texture.
     * @param   pSrcRect            Source rectangle.
     * @param   pSrcTexture         Source texture.
     * @param   pDstRect            Destination rectangle.
     */
    DECLCALLBACKMEMBER(int, pfnBlend, (PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pDstTexture, PRTRECT pSrcRect, PRECORDINGRENDERTEXTURE pSrcTexture, PRTRECT pDstRect));

    /**
     * Resizes / crops source image data to a destination texture reference.
     *
     * Backends may choose their own implementation strategy for producing
     * destination data in \a pDstTexture.
     *
     * @returns VBox status code.
     * @param   pRenderer           Renderer instance.
     * @param   pDstTexture         Destination texture.
     * @param   pSrcTexture         Source texture.
     * @param   pResizeParms        Resize parameters and resulting rectangles.
     */
    DECLCALLBACKMEMBER(int, pfnResize, (PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pDstTexture,
                                        PCRECORDINGRENDERTEXTURE pSrcTexture, PRECORDINGRENDERRESIZEPARMS pResizeParms));

    /**
     * Converts source image data to destination image data.
     *
     * @returns VBox status code.
     * @param   pRenderer           Renderer instance.
     * @param   pDstTexture         Destination texture.
     * @param   pSrcTexture         Source texture.
     */
    DECLCALLBACKMEMBER(int, pfnConvert, (PRECORDINGRENDERER pRenderer, PRECORDINGRENDERTEXTURE pDstTexture, PCRECORDINGRENDERTEXTURE pSrcTexture));
} RECORDINGRENDEROPS;

/**
 * Render state enumeration.
 */
typedef enum RECORDINGRENDERSTATE
{
    /** Renderer is idle and ready to begin a new composition pass. */
    RECORDINGRENDERSTATE_IDLE = 0,
    /** Renderer is currently composing the next frame. */
    RECORDINGRENDERSTATE_COMPOSING,
    /** Composition finished and render/convert pass can be performed. */
    RECORDINGRENDERSTATE_DONE,
} RECORDINGRENDERSTATE;

/**
 * Rendering backend instance.
 */
typedef struct RECORDINGRENDERER
{
    /** Backend to use. */
    RECORDINGRENDERBACKEND    enmBackend;
    /** Cached capability flags (RECORDINGRENDERCAP_F_*) of the active backend. */
    uint64_t                  fCaps;
    /** Pointer to operation table for active backend.
     *  Can be NULL if no backend set (yet). */
    const RECORDINGRENDEROPS *pOps;
    /** Backend private data (opaque to callers). */
    void                     *pvBackend;
    /** The current render state. */
    RECORDINGRENDERSTATE      enmState;
    /** Render parameters. */
    RECORDINGRENDERPARAMS     Parms;
    /** Front buffer texture.
     *  Always matches the VM screen's framebuffer size. */
    RECORDINGRENDERTEXTURE    texFront;
    /** Back buffer texture (background for cursor re-render).
     *  Always matches the VM screen's framebuffer size. */
    RECORDINGRENDERTEXTURE    texBack;
    /** Scaled output texture used for resize/scaling pass output. */
    RECORDINGRENDERTEXTURE    texScaled;
    /** Converted output texture used for color conversion pass output. */
    RECORDINGRENDERTEXTURE    texConv;
    /** For composition: Current video frame. */
    RECORDINGRENDERTEXTURE    texVideo;
    /** For composition: Current cursor shape. */
    RECORDINGRENDERTEXTURE    texCursor;
    /** Previous cursor X position. */
    uint32_t                  uCursorOldX;
    /** Previous cursor Y position. */
    uint32_t                  uCursorOldY;
    /** Pass 1 of the pipeline:
     *  Pointer to most recent composite frame (front / back buffer).
     *  Always matches the VM screen's framebuffer size. */
    PRECORDINGRENDERTEXTURE   pTexComposite;
    /** Pass 2 of the pipeline:
     *  Pointer to the resized composite frame.
     *  Might point to \a pFrameComposite if scaling is not active / needed. */
    PRECORDINGRENDERTEXTURE   pTexScaled;
    /** Pass 3 of the pipeline:
     *  Pointer to the converted (color space) scaled frame.
     *  Might point to \a pFrameScaled if conversion is not active / needed. */
    PRECORDINGRENDERTEXTURE   pTexConv;
    /** Timestamp (in ms) of the most recently composed frame.
     *  Set to 0 if no frame was composed yet. */
    uint64_t                  msLastTimestamp;
} RECORDINGRENDERER;
/** Pointer to RECORDINGRENDERER. */
typedef RECORDINGRENDERER *PRECORDINGRENDERER;

int RecordingRenderInit(PRECORDINGRENDERER pRenderer, RECORDINGRENDERBACKEND enmBackend);
void RecordingRenderDestroy(PRECORDINGRENDERER pRenderer);
RECORDINGRENDERBACKEND RecordingRenderGetBackend(PRECORDINGRENDERER pRenderer);
uint64_t RecordingRenderGetCaps(PCRECORDINGRENDERER pRenderer);
int RecordingRenderSetParms(PRECORDINGRENDERER pRenderer, PRECORDINGRENDERPARMS pParms);
int RecordingRenderScreenChange(PRECORDINGRENDERER pRenderer, PRECORDINGSURFACEINFO pInfo);
int RecordingRenderComposeBegin(PRECORDINGRENDERER pRenderer);
int RecordingRenderComposeEnd(PRECORDINGRENDERER pRenderer);
int RecordingRenderComposeAddFrame(PRECORDINGRENDERER pRenderer, PRECORDINGFRAME pFrame);
int RecordingRenderPerform(PRECORDINGRENDERER pRenderer);
int RecordingRenderQueryFrame(PRECORDINGRENDERER pRenderer, PRECORDINGVIDEOFRAME pFrameRendered);

#ifdef TESTCASE
int RecordingRenderSWFrameResizeCropCenter(RECORDINGVIDEOFRAME const *pDstFrame,
                                           RECORDINGVIDEOFRAME const *pSrcFrame,
                                           PRTRECT pDstRect, PRTRECT pSrcRect);
#endif

#endif /* !MAIN_INCLUDED_src_client_RecordingRender_h */
