/* $Id: mime-type-converter.h 114084 2026-05-06 09:28:40Z vadim.galitsyn@oracle.com $ */
/** @file
 * Mime-type converter for Shared Clipboard and Drag-and-Drop code.
 */

/*
 * Copyright (C) 2006-2025 Oracle and/or its affiliates.
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
 * The contents of this file may alternatively be used under the terms
 * of the Common Development and Distribution License Version 1.0
 * (CDDL), a copy of it is provided in the "COPYING.CDDL" file included
 * in the VirtualBox distribution, in which case the provisions of the
 * CDDL are applicable instead of those of the GPL.
 *
 * You may elect to license modified versions of this file under the
 * terms and conditions of either the GPL or the CDDL or both.
 *
 * SPDX-License-Identifier: GPL-3.0-only OR CDDL-1.0
 */

#ifndef VBOX_INCLUDED_GuestHost_mime_type_converter_h
#define VBOX_INCLUDED_GuestHost_mime_type_converter_h
#ifndef RT_WITHOUT_PRAGMA_ONCE
# pragma once
#endif

#include <iprt/cdefs.h>
#include <VBox/GuestHost/clipboard-helper.h>

/** Mime-type cache handle. */
typedef struct vbox_mime_conv_cache_s
{
    /** Cache lock. */
    RTCRITSECT  CritSect;
    /** Number of elements in cache table. */
    size_t      iCacheElements;
    /** Opaque cache storage. */
    void        *pvCache;
} vbox_mime_conv_cache_t;

/**
 * Mime-type enumeration callback function.
 *
 * Primarily used by VBoxMimeConvEnumerateMimeById when it
 * goes through the list of supported mime-types and passes
 * each of them one by one to this callback.
 *
 * @param   pcszMimeType    String representation of a mime-type.
 * @param   pvData          User data.
 */
typedef DECLCALLBACKTYPE(void, FNVBFMTCONVMIMEBYID, (const char *pcszMimeType, void *pvData));
/** Pointer to a FNVBFMTCONVMIMEBYID. */
typedef FNVBFMTCONVMIMEBYID *PFNVBFMTCONVMIMEBYID;

/**
 * Enumerate list of mime-types by ID mask.
 *
 * This function goes through the list of supported mime-types and
 * triggers given callback function for each of them.
 *
 * @param uFmtVBox      Formats bitmask in VBox representation.
 * @param pfnCb         A callback to trigger.
 * @param pvData        User data.
 */
extern RTDECL(void) VBoxMimeConvEnumerateMimeById(const SHCLFORMAT uFmtVBox, PFNVBFMTCONVMIMEBYID pfnCb,
                                                  void *pvData);

/**
 * Find first matching mime-type by given VBox formats ID.
 *
 * @returns Mime-type as a string or NULL if not found.
 * @param   uFmtVBox    Formats bitmask in VBox representation.
 */
extern RTDECL(const char *) VBoxMimeConvGetMimeById(const SHCLFORMAT uFmtVBox);

/**
 * Find VBox format ID by given mime-type.
 *
 * @returns Format ID in VBox representation.
 * @param   pcszMimeType    Mime-type in string representation.
 */
extern RTDECL(SHCLFORMAT) VBoxMimeConvGetIdByMime(const char *pcszMimeType);

/**
 * Converts data from VBox internal representation into native format.
 *
 * @returns IPRT status code.
 * @param   pcszMimeType    Mime-type in string representation.
 * @param   pvBufIn         Input buffer which contains data in VBox format.
 * @param   cbBufIn         Size of input buffer in bytes.
 * @param   ppvBufOut       Newly allocated output buffer which will contain data
 *                          in specified mime-type format (must be freed by caller).
 * @param   pcbBufOut       Size of output buffer.
 */
extern RTDECL(int) VBoxMimeConvVBoxToNative(const char *pcszMimeType, void *pvBufIn, int cbBufIn,
                                            void **ppvBufOut, size_t *pcbBufOut);

/**
 * Converts data from native format into VBox internal representation.
 *
 * @returns IPRT status code.
 * @param   pcszMimeType    Mime-type in string representation.
 * @param   pvBufIn         Input buffer which contains data in specified mime-type format.
 * @param   cbBufIn         Size of input buffer in bytes.
 * @param   ppvBufOut       Newly allocated output buffer which will contain image data
 *                          in VBox internal representation format (must be freed by caller).
 * @param   pcbBufOut       Size of output buffer.
 */
extern RTDECL(int) VBoxMimeConvNativeToVBox(const char *pcszMimeType, void *pvBufIn, int cbBufIn,
                                            void **ppvBufOut, size_t *pcbBufOut);

/**
 * Initializes mapping table cache.
 *
 * Must be called before any other VBoxMimeConvXXXCacheYYY call.
 *
 * @returns IPRT status code.
 * @param   pCache          Cache handle.
 */
RTDECL(int) VBoxMimeConvInitCache(vbox_mime_conv_cache_t *pCache);

/**
 * Destroys mapping table cache.
 *
 * @returns IPRT status code.
 * @param   pCache          Cache handle.
 */
RTDECL(int) VBoxMimeConvDestroyCache(vbox_mime_conv_cache_t *pCache);

/**
 * Clears mapping table cache.
 *
 * @returns IPRT status code.
 * @param   pCache          Cache handle.
 */
RTDECL(int) VBoxMimeConvClearCache(vbox_mime_conv_cache_t *pCache);

/**
 * Adds data into cache using mime-type as a key.
 *
 * @returns VINF_SUCCESS on success, VERR_NOT_FOUND if given memi-type is unknown or IPRT error code.
 * @param   pCache          Cache handle.
 * @param   pcszMimeType    Mime-type in string representation.
 * @param   pvBuf           Input buffer which contains data in specified mime-type format.
 * @param   cbBuf           Size of input buffer in bytes.
 */
RTDECL(int) VBoxMimeConvSetCacheByMime(vbox_mime_conv_cache_t *pCache, const char *pcszMimeType, void *pvBuf, int cbBuf);

/**
 * Extracts data from cache using mime-type as a key.
 *
 * @returns VINF_SUCCESS on success, VERR_NOT_FOUND if no cache entry corresponds to
 *          given memi-type or IPRT error code.
 * @param   pCache          Cache handle.
 * @param   pcszMimeType    Mime-type in string representation.
 * @param   ppvBufOut       Data which corresponds to given mime-type.
 * @param   pcbBufOut       Size of output buffer.
 */
RTDECL(int) VBoxMimeConvGetCacheByMime(vbox_mime_conv_cache_t *pCache, const char *pcszMimeType, void **ppvBufOut, size_t *pcbBufOut);

/**
 * Extracts data from cache using format ID as a key.
 *
 * @returns VINF_SUCCESS on success, VERR_NOT_FOUND if no cache entry corresponds to
 *          given memi-type or IPRT error code.
 * @param   pCache          Cache handle.
 * @param   uFmtVBox        Format ID in VBox representation.
 * @param   ppvBufOut       Data which corresponds to given mime-type.
 * @param   pcbBufOut       Size of output buffer.
 */
RTDECL(int) VBoxMimeConvGetCacheById(vbox_mime_conv_cache_t *pCache, const SHCLFORMAT uFmtVBox, void **ppvBufOut, size_t *pcbBufOut);

#endif /* !VBOX_INCLUDED_GuestHost_mime_type_converter_h */

