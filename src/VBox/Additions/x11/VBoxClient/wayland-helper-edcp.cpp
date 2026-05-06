/* $Id: wayland-helper-edcp.cpp 114084 2026-05-06 09:28:40Z vadim.galitsyn@oracle.com $ */
/** @file
 * Guest Additions - Ext Data Control Protocol (EDCP) helper for Wayland.
 *
 * This module implements Shared Clipboard support for Wayland guests
 * using Data Control Protocol interface.
 */

/*
 * Copyright (C) 2006-2026 Oracle and/or its affiliates.
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

#include <errno.h>

#include <iprt/env.h>
#include <iprt/assert.h>
#include <iprt/string.h>
#include <iprt/thread.h>

#include <VBox/GuestHost/mime-type-converter.h>

#include "VBoxClient.h"
#include "clipboard.h"
#include "wayland-helper.h"
#include "wayland-helper-ipc.h"
#include "wayland-helper-xdcp-common.h"

#include "wayland-client-protocol.h"
#include "ext-data-control-v1.h"

/**
 * A set of objects required to handle clipboard sharing over
 * Data Control Protocol. */
typedef struct
{
    vbox_wl_xdcp_base_ctx_t                     BaseCtx;

    /** Wayland Data Device object. */
    struct ext_data_control_device_v1           *pDataDevice;

    /** Wayland Data Control Manager object. */
    struct ext_data_control_manager_v1          *pDataControlManager;
} vbox_wl_edcp_ctx_t;

/** Helper context. */
static vbox_wl_edcp_ctx_t g_EdcpCtx;

static DECLCALLBACK(int) vbcl_wayland_hlp_edcp_clip_hg_report_join2_cb(vbcl_wl_session_type_t enmSessionType, void *pvUser);
static DECLCALLBACK(int) vbcl_wayland_hlp_edcp_clip_hg_report_join3_cb(vbcl_wl_session_type_t enmSessionType, void *pvUser);


/**********************************************************************************************************************************
 * Host Clipboard service callbacks.
 *********************************************************************************************************************************/


/**
 * Session callback: Generic session initializer.
 *
 * This callback starts new session.
 *
 * @returns IPRT status code.
 * @param   enmSessionType      Session type (unused).
 * @param   pvUser              User data.
 */
static DECLCALLBACK(int) vbcl_wayland_hlp_edcp_session_start_generic_cb(
    vbcl_wl_session_type_t enmSessionType, void *pvUser)
{
    vbox_wl_dcp_session_t *pSession = (vbox_wl_dcp_session_t *)pvUser;
    RT_NOREF(enmSessionType);

    VBCL_LOG_CALLBACK;

    AssertPtrReturn(pSession, VERR_INVALID_PARAMETER);
    vbcl_wayland_xdcp_session_prepare(&g_EdcpCtx.BaseCtx);

    return VINF_SUCCESS;
}

/**
 * Wayland registry global handler.
 *
 * This callback is triggered when Wayland Registry listener is registered.
 * Wayland client library will trigger it individually for each available global
 * object.
 *
 * @param pvUser            Context data.
 * @param pRegistry         Wayland Registry object.
 * @param uName             Numeric name of the global object.
 * @param sIface            Name of interface implemented by the object.
 * @param uVersion          Interface version.
 */
static void vbcl_wayland_hlp_edcp_registry_global_handler(
    void *pvUser, struct wl_registry *pRegistry, uint32_t uName, const char *sIface, uint32_t uVersion)
{
    vbox_wl_edcp_ctx_t *pCtx = (vbox_wl_edcp_ctx_t *)pvUser;

    RT_NOREF(pRegistry);
    RT_NOREF(uVersion);

    AssertPtrReturnVoid(pCtx);
    AssertPtrReturnVoid(sIface);

    /* Wrappers around 'if' statement. */
         VBCL_WAYLAND_REGISTRY_ADD_MATCH(pRegistry, sIface, uName, wl_seat_interface,                      pCtx->BaseCtx.pSeat,        struct wl_seat *,                      VBCL_WAYLAND_SEAT_VERSION_MIN)
    else VBCL_WAYLAND_REGISTRY_ADD_MATCH(pRegistry, sIface, uName, ext_data_control_manager_v1_interface,  pCtx->pDataControlManager,  struct ext_data_control_manager_v1 *,  VBCL_WAYLAND_ZWLR_DATA_CONTROL_MANAGER_VERSION_MIN)
    else
        VBClLogVerbose(5, "ignoring Wayland interface %s\n", sIface);
}

/**
 * Wayland registry global remove handler.
 *
 * Triggered when global object is removed from Wayland registry.
 *
 * @param pvUser            Context data.
 * @param pRegistry         Wayland Registry object.
 * @param uName             Numeric name of the global object.
 */
static void vbcl_wayland_hlp_edcp_registry_global_remove_handler(
    void *pvUser, struct wl_registry *pRegistry, uint32_t uName)
{
    RT_NOREF(pvUser);
    RT_NOREF(pRegistry);
    RT_NOREF(uName);
}

/** Wayland global registry callbacks. */
static const struct wl_registry_listener g_vbcl_wayland_hlp_registry_cb =
{
    &vbcl_wayland_hlp_edcp_registry_global_handler,       /* .global */
    &vbcl_wayland_hlp_edcp_registry_global_remove_handler /* .global_remove */
};


/**********************************************************************************************************************************
 * Wayland Data Control Offer callbacks.
 *********************************************************************************************************************************/


/**
 * Session callback: Collect clipboard format advertised by guest.
 *
 * This callback must be executed in context of Wayland event thread
 * in order to be able to access Wayland clipboard content.
 *
 * This callback adds mime-type just advertised by Wayland into a list
 * of mime-types which in turn later will be advertised to the host.
 *
 * @returns IPRT status code.
 * @param   enmSessionType      Session type, must be verified as
 *                              a consistency check.
 * @param   pvUser              User data (Wayland mime-type data).
 */
static DECLCALLBACK(int) vbcl_wayland_hlp_edcp_gh_add_fmt_cb(
    vbcl_wl_session_type_t enmSessionType, void *pvUser)
{
    struct vbcl_wl_dcp_enumerate_ctx *pEnmCtx =
        (struct vbcl_wl_dcp_enumerate_ctx *)pvUser;

    int rc =   (enmSessionType == VBCL_WL_CLIPBOARD_SESSION_TYPE_COPY_TO_HOST)
             ? VINF_SUCCESS : VERR_WRONG_ORDER;

    VBCL_LOG_CALLBACK;

    AssertPtrReturn(pEnmCtx, VERR_INVALID_PARAMETER);

    if (RT_SUCCESS(rc))
        rc = vbcl_wayland_xdcp_add_fmt(pEnmCtx);

    return rc;
}

/**
 * Data Control Offer advertise callback.
 *
 * Triggered when other Wayland client advertises new clipboard content.
 *
 * @param pvUser            Context data.
 * @param pOffer            Wayland Data Control Offer object.
 * @param sMimeType         Mime-type of newly available clipboard data.
 */
static void vbcl_wayland_hlp_edcp_data_control_offer_offer(
    void *pvUser, struct ext_data_control_offer_v1 *pOffer, const char *sMimeType)
{
    int rc;

    vbox_wl_edcp_ctx_t *pCtx = (vbox_wl_edcp_ctx_t *)pvUser;
    struct vbcl_wl_dcp_enumerate_ctx pEnmCtx;
    RT_NOREF(pOffer);

    VBCL_LOG_CALLBACK;

    AssertPtrReturnVoid(sMimeType);

    RT_ZERO(pEnmCtx);
    pEnmCtx.sMimeType = sMimeType;
    pEnmCtx.pSession = &pCtx->BaseCtx.Session;

    rc = vbcl_wayland_session_join(&pCtx->BaseCtx.Session.Base,
                                   &vbcl_wayland_hlp_edcp_gh_add_fmt_cb,
                                   (void *)&pEnmCtx);
    if (RT_FAILURE(rc))
        VBClLogError("cannot save formats announced by the guest, rc=%Rrc\n", rc);
}

/** Wayland Data Control Offer interface callbacks. */
static const struct ext_data_control_offer_v1_listener g_data_control_offer_listener =
{
    &vbcl_wayland_hlp_edcp_data_control_offer_offer,
};


/**********************************************************************************************************************************
 * Wayland Data Control Device callbacks.
 *********************************************************************************************************************************/


/**
 * Read clipboard buffer from Wayland in specified format.
 *
 * @returns IPRT status code.
 * @param   pCtx            DCP context data.
 * @param   pOffer          Data offer object.
 * @param   pszMimeType     Requested mime-type in string representation.
 */
static int vbcl_wayland_hlp_edcp_receive_offer(
    vbox_wl_edcp_ctx_t *pCtx, ext_data_control_offer_v1 *pOffer, char *pszMimeType)
{
    int rc = VERR_PIPE_NOT_CONNECTED;
    int aFds[2];

    AssertPtrReturn(pOffer, VERR_INVALID_PARAMETER);
    AssertPtrReturn(pszMimeType, VERR_INVALID_PARAMETER);

    if (pipe(aFds) == 0)
    {
        ext_data_control_offer_v1_receive(
            (struct ext_data_control_offer_v1 *)pOffer, pszMimeType, aFds[1]);

        close(aFds[1]);
        rc = vbcl_wayland_xdcp_get_guest_clipboard(aFds[0], &pCtx->BaseCtx, pszMimeType);
        close(aFds[0]);
    }
    else
        VBClLogError("cannot read mime-type '%s' from Wayland, rc=%Rrc\n", pszMimeType, rc);

    return rc;
}

/**
 * Convert list of mime-types in string representation into bitmask of VBox formats.
 *
 * @returns Formats bitmask.
 * @param   pList       List of mime-types in string representation.
 * @param   pOffer      Wayland offer.
 */
static SHCLFORMATS vbcl_wayland_hlp_edcp_match_formats(vbox_wl_dcp_mime_t *pList, struct ext_data_control_offer_v1 *pOffer)
{
    SHCLFORMATS fFmts = VBOX_SHCL_FMT_NONE;

    AssertPtrReturn(pList, VBOX_SHCL_FMT_NONE);
    AssertPtrReturn(pOffer, VBOX_SHCL_FMT_NONE);

    if (!RTListIsEmpty(&pList->Node))
    {
        vbox_wl_dcp_mime_t *pEntry;
        RTListForEach(&pList->Node, pEntry, vbox_wl_dcp_mime_t, Node)
        {
            int rc;

            AssertPtrReturn(pEntry, VBOX_SHCL_FMT_NONE);
            AssertPtrReturn(pEntry->pszMimeType, VBOX_SHCL_FMT_NONE);

            VBClLogVerbose(5, "Wayland last offer contains data in format: %s\n", pEntry->pszMimeType);

            fFmts |= VBoxMimeConvGetIdByMime(pEntry->pszMimeType);

            rc = vbcl_wayland_hlp_edcp_receive_offer(&g_EdcpCtx, pOffer, pEntry->pszMimeType);
        }
    }

    return fFmts;
}

/**
 * Session callback: Advertise clipboard to the host.
 *
 * This callback must be executed in context of Wayland event thread
 * in order to be able to access Wayland clipboard content.
 *
 * This callback (1) coverts Wayland clipboard formats into VBox
 * representation, (2) sets formats to the session, (3) waits for
 * host to request clipboard data in certain format, and (4)
 * receives Wayland clipboard in requested format.
 *
 * @returns IPRT status code.
 * @param   enmSessionType      Session type, must be verified as
 *                              a consistency check.
 * @param   pvUser              User data (data offer object).
 */
static DECLCALLBACK(int) vbcl_wayland_hlp_edcp_gh_clip_report_cb(
    vbcl_wl_session_type_t enmSessionType, void *pvUser)
{
    struct ext_data_control_offer_v1 *pOffer = (struct ext_data_control_offer_v1 *)pvUser;
    SHCLFORMATS fFmts = VBOX_SHCL_FMT_NONE;

    int rc = (enmSessionType == VBCL_WL_CLIPBOARD_SESSION_TYPE_COPY_TO_HOST)
             ? VINF_SUCCESS : VERR_WRONG_ORDER;

    VBCL_LOG_CALLBACK;

    AssertPtrReturn(pOffer, VERR_INVALID_PARAMETER);

    if (RT_SUCCESS(rc))
    {
        fFmts = vbcl_wayland_hlp_edcp_match_formats(&g_EdcpCtx.BaseCtx.Session.clip.mimeTypesList, pOffer);
        if (fFmts != VBOX_SHCL_FMT_NONE)
        {
            g_EdcpCtx.BaseCtx.Session.clip.fFmts.set(fFmts);

            if (RT_VALID_PTR(g_EdcpCtx.BaseCtx.pClipboardCtx))
            {
                rc = VbglR3ClipboardReportFormats(g_EdcpCtx.BaseCtx.pClipboardCtx->idClient, fFmts);
                if (RT_FAILURE(rc))
                    VBClLogError("cannot report formats to host, rc=%Rrc\n", rc);
            }
            else
            {
                VBClLogVerbose(2, "cannot announce to guest, no host service connection yet\n");
                rc = VERR_TRY_AGAIN;
            }
        }
        else
            rc = VERR_NO_DATA;

        ext_data_control_offer_v1_destroy((struct ext_data_control_offer_v1 *)pOffer);

        VBClLogVerbose(5, "announcing fFmts=0x%x to host, rc=%Rrc\n", fFmts, rc);
    }

    return rc;
}

/**
 * Data Control Device offer callback.
 *
 * Triggered when other Wayland client advertises new clipboard content.
 * When this callback is triggered, a new ext_data_control_offer_v1 object
 * is created. This callback should setup listener callbacks for this object.
 *
 * @param pvUser            Context data.
 * @param pDevice           Wayland Data Control Device object.
 * @param pOffer            Wayland Data Control Offer object.
 */
static void vbcl_wayland_hlp_edcp_data_device_data_offer(
    void *pvUser, struct ext_data_control_device_v1 *pDevice, struct ext_data_control_offer_v1 *pOffer)
{
    int rc;
    vbox_wl_edcp_ctx_t *pCtx = (vbox_wl_edcp_ctx_t *)pvUser;
    RT_NOREF(pDevice);

    VBCL_LOG_CALLBACK;

    AssertPtrReturnVoid(pCtx);
    AssertPtrReturnVoid(pOffer);

    if (pCtx->BaseCtx.fIngnoreWlClipIn)
    {
        VBClLogVerbose(5, "ignoring Wayland clipboard data offer, we advertising new clipboard ourselves\n");
        return;
    }

    rc = vbcl_wayland_session_end(&pCtx->BaseCtx.Session.Base, NULL, NULL);
    if (RT_SUCCESS(rc))
    {
        rc = vbcl_wayland_session_start(&pCtx->BaseCtx.Session.Base,
                                        VBCL_WL_CLIPBOARD_SESSION_TYPE_COPY_TO_HOST,
                                        &vbcl_wayland_hlp_edcp_session_start_generic_cb,
                                        &pCtx->BaseCtx.Session);
        if (RT_SUCCESS(rc))
        {
            rc = VBoxMimeConvClearCache(&pCtx->BaseCtx.Cache);
            if (RT_FAILURE(rc))
                VBClLogVerbose(5, "unable to clear clipboard cache, rc=%Rrc", rc);

            ext_data_control_offer_v1_add_listener(pOffer, &g_data_control_offer_listener, pvUser);

            /* Receive all the advertised mime types. */
            wl_display_roundtrip(pCtx->BaseCtx.pDisplay);

            /* Try to send an announcement to the host. */
            rc = vbcl_wayland_session_join(&pCtx->BaseCtx.Session.Base,
                                           &vbcl_wayland_hlp_edcp_gh_clip_report_cb,
                                           pOffer);
        }
        else
            VBClLogError("unable to start session, rc=%Rrc\n", rc);
    }
    else
        VBClLogError("unable to start session, previous session is still running, rc=%Rrc\n", rc);
}

/**
 * Data Control Device selection callback.
 *
 * Triggered when Wayland client advertises new clipboard content.
 * In this callback, actual clipboard data is received from Wayland client.
 *
 * @param pvUser            Context data.
 * @param pDevice           Wayland Data Control Device object.
 * @param pOffer            Wayland Data Control Offer object.
 */
static void vbcl_wayland_hlp_edcp_data_device_selection(
    void *pvUser, struct ext_data_control_device_v1 *pDevice, struct ext_data_control_offer_v1 *pOffer)
{
    RT_NOREF(pDevice, pvUser, pOffer);
    VBCL_LOG_CALLBACK;
}

/**
 * Data Control Device finished callback.
 *
 * Triggered when Data Control Device object is no longer valid and
 * needs to be destroyed.
 *
 * @param pvUser            Context data.
 * @param pDevice           Wayland Data Control Device object.
 */
static void vbcl_wayland_hlp_edcp_data_device_finished(
    void *pvUser, struct ext_data_control_device_v1 *pDevice)
{
    vbox_wl_edcp_ctx_t *pCtx = (vbox_wl_edcp_ctx_t *)pvUser;

    VBCL_LOG_CALLBACK;

    AssertPtrReturnVoid(pCtx);
    AssertPtrReturnVoid(pDevice);

    ext_data_control_device_v1_destroy(pDevice);
    pCtx->pDataDevice = NULL;
}

/**
 * Data Control Device primary selection callback.
 *
 * Same as shcl_wl_data_control_device_selection, but triggered for
 * primary selection case.
 *
 * @param pvUser            Context data.
 * @param pDevice           Wayland Data Control Device object.
 * @param pOffer            Wayland Data Control Offer object.
 */
static void vbcl_wayland_hlp_edcp_data_device_primary_selection(
    void *pvUser, struct ext_data_control_device_v1 *pDevice, struct ext_data_control_offer_v1 *pOffer)
{
    RT_NOREF(pDevice, pvUser, pOffer);
    VBCL_LOG_CALLBACK;
}


/** Data Control Device interface callbacks. */
static const struct ext_data_control_device_v1_listener g_data_device_listener =
{
    &vbcl_wayland_hlp_edcp_data_device_data_offer,
    &vbcl_wayland_hlp_edcp_data_device_selection,
    &vbcl_wayland_hlp_edcp_data_device_finished,
    &vbcl_wayland_hlp_edcp_data_device_primary_selection,
};


/**********************************************************************************************************************************
 * Wayland Data Control Source callbacks.
 *********************************************************************************************************************************/


/**
 * Wayland data send callback.
 *
 * Triggered when other Wayland client wants to read clipboard
 * data from us.
 *
 * @param pvUser            VBox private data.
 * @param pDataSource       Wayland Data Control Source object.
 * @param sMimeType         A mime-type of requested data.
 * @param fd                A file descriptor to write clipboard content into.
 */
static void vbcl_wayland_hlp_edcp_data_source_send(
    void *pvUser, struct ext_data_control_source_v1 *pDataSource,
    const char *sMimeType, int32_t fd)
{
    int rc;
    vbox_wl_edcp_ctx_t *pCtx = (vbox_wl_edcp_ctx_t *)pvUser;
    RT_NOREF(pDataSource);

    struct vbcl_wl_dcp_write_ctx priv;

    VBCL_LOG_CALLBACK;

    AssertPtrReturnVoid(pCtx);
    AssertPtrReturnVoid(sMimeType);

    RT_ZERO(priv);
    priv.sMimeType = sMimeType;
    priv.fd = fd;

    rc = vbcl_wayland_session_join(&pCtx->BaseCtx.Session.Base,
                                   &vbcl_wayland_hlp_edcp_clip_hg_report_join3_cb,
                                   &priv);

    VBClLogVerbose(5, "vbcl_wayland_hlp_edcp_data_source_send, rc=%Rrc\n", rc);
    close(fd);
}

/**
 * Wayland data canceled callback.
 *
 * Triggered when data source was replaced by another data source
 * and no longer valid.
 *
 * @param pvData            VBox private data.
 * @param pDataSource       Wayland Data Control Source object.
 */
static void vbcl_wayland_hlp_edcp_data_source_cancelled(
    void *pvData, struct ext_data_control_source_v1 *pDataSource)
{
    RT_NOREF(pvData);
    VBCL_LOG_CALLBACK;
    ext_data_control_source_v1_destroy(pDataSource);
}


/** Wayland Data Control Source interface callbacks. */
static const struct ext_data_control_source_v1_listener g_data_source_listener =
{
    &vbcl_wayland_hlp_edcp_data_source_send,
    &vbcl_wayland_hlp_edcp_data_source_cancelled,
};


/**********************************************************************************************************************************
 * Helper specific code and session callbacks.
 *********************************************************************************************************************************/


/**
 * Setup or reset helper context.
 *
 * This function is used on helper init and termination. In case of
 * init, memory is not initialized yet, so it needs to be zeroed.
 * In case of shutdown, memory is already initialized and previously
 * allocated resources must be freed.
 *
 * @param pCtx              Context data.
 * @param fShutdown         A flag to indicate if session resources
 *                          need to be deallocated.
 */
static void vbcl_wayland_hlp_edcp_reset_ctx(vbox_wl_edcp_ctx_t *pCtx, bool fShutdown)
{
    AssertReturnVoid(pCtx);

    vbcl_wayland_xdcp_reset_ctx(&pCtx->BaseCtx, fShutdown);

    pCtx->pDataDevice = NULL;
    pCtx->pDataControlManager = NULL;
}

/**
 * Disconnect from Wayland compositor.
 *
 * Close connection, release resources and reset context data.
 *
 * @param pCtx              Context data.
 */
static void vbcl_wayland_hlp_edcp_disconnect(vbox_wl_edcp_ctx_t *pCtx)
{
    AssertReturnVoid(pCtx);

    if (RT_VALID_PTR(pCtx->pDataControlManager))
        ext_data_control_manager_v1_destroy(pCtx->pDataControlManager);

    if (RT_VALID_PTR(pCtx->pDataDevice))
        ext_data_control_device_v1_destroy(pCtx->pDataDevice);

    if (RT_VALID_PTR(pCtx->BaseCtx.pSeat))
        wl_seat_destroy(pCtx->BaseCtx.pSeat);

    if (RT_VALID_PTR(pCtx->BaseCtx.pRegistry))
        wl_registry_destroy(pCtx->BaseCtx.pRegistry);

    if (RT_VALID_PTR(pCtx->BaseCtx.pDisplay))
        wl_display_disconnect(pCtx->BaseCtx.pDisplay);

    vbcl_wayland_hlp_edcp_reset_ctx(pCtx, true);
}

/**
 * Connect to Wayland compositor.
 *
 * Establish connection, bind to all required interfaces.
 *
 * @returns TRUE on success, FALSE otherwise.
 * @param   pCtx                Context data.
 */
static bool vbcl_wayland_hlp_edcp_connect(vbox_wl_edcp_ctx_t *pCtx)
{
    const char *csWaylandDisplay = RTEnvGet(VBCL_ENV_WAYLAND_DISPLAY);
    bool fConnected = false;

    AssertPtrReturn(pCtx, false);

    if (RT_VALID_PTR(csWaylandDisplay))
        pCtx->BaseCtx.pDisplay = wl_display_connect(csWaylandDisplay);
    else
        VBClLogError("cannot connect to Wayland compositor "
                     VBCL_ENV_WAYLAND_DISPLAY " environment variable not set\n");

    if (RT_VALID_PTR(pCtx->BaseCtx.pDisplay))
    {
        pCtx->BaseCtx.pRegistry = wl_display_get_registry(pCtx->BaseCtx.pDisplay);
        if (RT_VALID_PTR(pCtx->BaseCtx.pRegistry))
        {
            wl_registry_add_listener(pCtx->BaseCtx.pRegistry, &g_vbcl_wayland_hlp_registry_cb, (void *)pCtx);
            wl_display_roundtrip(pCtx->BaseCtx.pDisplay);

            if (RT_VALID_PTR(pCtx->pDataControlManager))
            {
                if (RT_VALID_PTR(pCtx->BaseCtx.pSeat))
                {
                    pCtx->pDataDevice = ext_data_control_manager_v1_get_data_device(pCtx->pDataControlManager, pCtx->BaseCtx.pSeat);
                    if (RT_VALID_PTR(pCtx->pDataDevice))
                    {
                        if (RT_VALID_PTR(pCtx->pDataControlManager))
                            fConnected = true;
                        else
                            VBClLogError("cannot get Wayland data control manager interface\n");
                    }
                    else
                        VBClLogError("cannot get Wayland data device interface\n");
                }
                else
                    VBClLogError("cannot get Wayland seat interface\n");
            }
            else
                VBClLogError("cannot get Wayland device manager interface\n");
        }
        else
            VBClLogError("cannot connect to Wayland registry\n");
    }
    else
        VBClLogError("cannot connect to Wayland compositor\n");

    if (!fConnected)
        vbcl_wayland_hlp_edcp_disconnect(pCtx);

    return fConnected;
}

/**
 * Main loop for Wayland compositor events.
 *
 * All requests to Wayland compositor must be performed in context
 * of this thread.
 *
 * @returns IPRT status code.
 * @param   hThreadSelf         IPRT thread object.
 * @param   pvUser              Context data.
 */
static DECLCALLBACK(int) vbcl_wayland_hlp_edcp_event_loop(RTTHREAD hThreadSelf, void *pvUser)
{
    vbox_wl_edcp_ctx_t *pCtx = (vbox_wl_edcp_ctx_t *)pvUser;
    int rc = VERR_TRY_AGAIN;

    AssertPtrReturn(pCtx, VERR_INVALID_PARAMETER);

    if (vbcl_wayland_hlp_edcp_connect(pCtx))
    {
        /* Start listening Data Control Device interface. */
        if (ext_data_control_device_v1_add_listener(pCtx->pDataDevice, &g_data_device_listener, (void *)pCtx) == 0)
        {
            /* Tell parent thread we are ready. */
            RTThreadUserSignal(hThreadSelf);

            while (1)
            {
                rc = vbcl_wayland_xdcp_next_event(&pCtx->BaseCtx);
                if (   rc != VERR_TIMEOUT
                    && RT_FAILURE(rc))
                {
                    VBClLogError("cannot read event from Wayland, rc=%Rrc\n", rc);
                }

                if (pCtx->BaseCtx.fSendToGuest.reset())
                {
                    rc = vbcl_wayland_session_join(&pCtx->BaseCtx.Session.Base,
                                                   &vbcl_wayland_hlp_edcp_clip_hg_report_join2_cb,
                                                   NULL);
                }

                /* Handle graceful thread termination. */
                if (pCtx->BaseCtx.fShutdown)
                {
                    rc = VINF_SUCCESS;
                    break;
                }
            }
        }
        else
        {
            rc = VERR_NOT_SUPPORTED;
            VBClLogError("cannot subscribe to Data Control Device events\n");
        }

        vbcl_wayland_hlp_edcp_disconnect(pCtx);
    }

    /* Notify parent thread if we failed to start, so it won't be
     * waiting 30 sec to figure this out. */
    if (RT_FAILURE(rc))
        RTThreadUserSignal(hThreadSelf);

    return rc;
}

/**
 * @interface_method_impl{VBCLWAYLANDHELPER,pfnProbe}
 */
static DECLCALLBACK(int) vbcl_wayland_hlp_edcp_probe(void)
{
    vbox_wl_edcp_ctx_t probeCtx;
    int fCaps = VBOX_WAYLAND_HELPER_CAP_NONE;
    VBGHDISPLAYSERVERTYPE enmDisplayServerType = VBGHDisplayServerTypeDetect();

    vbcl_wayland_hlp_edcp_reset_ctx(&probeCtx, false /* fShutdown */);
    vbcl_wayland_session_init(&probeCtx.BaseCtx.Session.Base);

    if (VBGHDisplayServerTypeIsWaylandAvailable(enmDisplayServerType))
    {
        if (vbcl_wayland_hlp_edcp_connect(&probeCtx))
        {
            fCaps |= VBOX_WAYLAND_HELPER_CAP_CLIPBOARD;
            vbcl_wayland_hlp_edcp_disconnect(&probeCtx);
        }
    }

    return fCaps;
}

/**
 * @interface_method_impl{VBCLWAYLANDHELPER_CLIPBOARD,pfnInit}
 */
RTDECL(int) vbcl_wayland_hlp_edcp_clip_init(void)
{
    vbcl_wayland_hlp_edcp_reset_ctx(&g_EdcpCtx, false /* fShutdown */);
    vbcl_wayland_session_init(&g_EdcpCtx.BaseCtx.Session.Base);

    return vbcl_wayland_thread_start(&g_EdcpCtx.BaseCtx.Thread, vbcl_wayland_hlp_edcp_event_loop, "wl-dcp", &g_EdcpCtx);
}

/**
 * @interface_method_impl{VBCLWAYLANDHELPER_CLIPBOARD,pfnTerm}
 */
RTDECL(int) vbcl_wayland_hlp_edcp_clip_term(void)
{
    int rc;
    int rcThread = 0;

    /* Set termination flag. Wayland event loop should pick it up
     * on the next iteration. */
    g_EdcpCtx.BaseCtx.fShutdown = true;

    /* Wait for Wayland event loop thread to shutdown. */
    rc = RTThreadWait(g_EdcpCtx.BaseCtx.Thread, RT_MS_30SEC, &rcThread);
    if (RT_SUCCESS(rc))
        VBClLogInfo("Wayland event thread exited with status, rc=%Rrc\n", rcThread);
    else
        VBClLogError("unable to stop Wayland event thread, rc=%Rrc\n", rc);

    return rc;
}

/**
 * @interface_method_impl{VBCLWAYLANDHELPER_CLIPBOARD,pfnSetClipboardCtx}
 */
static DECLCALLBACK(void) vbcl_wayland_hlp_edcp_clip_set_ctx(PVBGLR3SHCLCMDCTX pCtx)
{
    g_EdcpCtx.BaseCtx.pClipboardCtx = pCtx;
}

/**
 * @interface_method_impl{VBCLWAYLANDHELPER_CLIPBOARD,pfnPopup}
 */
static DECLCALLBACK(int) vbcl_wayland_hlp_edcp_clip_popup(void)
{
    return VINF_SUCCESS;
}

/**
 * Session callback: Copy clipboard to the guest.
 *
 * This callback must be executed in context of Wayland event thread
 * in order to be able to inject clipboard content into Wayland. It is
 * triggered when Wayland client already decided data in which format
 * it wants to request.
 *
 * This callback (1) sets requested clipboard format to the session,
 * (2) waits for clipboard data to be copied from the host, (3) converts
 * host clipboard data into guest representation, and (4) sends clipboard
 * to the guest by writing given file descriptor.
 *
 * @returns IPRT status code.
 * @param   enmSessionType      Session type, must be verified as
 *                              a consistency check.
 * @param   pvUser              User data (Wayland I/O context).
 */
static DECLCALLBACK(int) vbcl_wayland_hlp_edcp_clip_hg_report_join3_cb(
    vbcl_wl_session_type_t enmSessionType, void *pvUser)
{
    struct vbcl_wl_dcp_write_ctx *pPriv = (struct vbcl_wl_dcp_write_ctx *)pvUser;
    AssertPtrReturn(pPriv, VERR_INVALID_PARAMETER);

    int rc = (enmSessionType == VBCL_WL_CLIPBOARD_SESSION_TYPE_COPY_TO_GUEST)
             ? VINF_SUCCESS : VERR_WRONG_ORDER;

    VBCL_LOG_CALLBACK;

    AssertPtrReturn(pPriv, VERR_INVALID_PARAMETER);

    if (RT_SUCCESS(rc))
    {
        rc = vbcl_wayland_xdcp_set_guest_clipboard(pPriv->fd, &g_EdcpCtx.BaseCtx, pPriv->sMimeType);
        g_EdcpCtx.BaseCtx.fIngnoreWlClipIn = false;
    }

    return rc;
}

/**
 * Enumeration callback used for sending clipboard offers to Wayland client.
 *
 * When host announces its clipboard content, this call back is used in order
 * to send corresponding offers to other Wayland clients.
 *
 * Callback must be executed in context of Wayland event thread.
 *
 * @param   pcszMimeType    Mime-type to advertise.
 * @param   pvUser          User data (DCP data source object).
 */
static DECLCALLBACK(void) vbcl_wayland_hlp_edcp_send_offers(const char *pcszMimeType, void *pvUser)
{
    ext_data_control_source_v1 *pDataSource = (ext_data_control_source_v1 *)pvUser;
    ext_data_control_source_v1_offer(pDataSource, pcszMimeType);
}

/**
 * Session callback: Advertise clipboard to the guest.
 *
 * This callback must be executed in context of Wayland event thread
 * in order to be able to inject clipboard content into Wayland.
 *
 * This callback (1) prevents Wayland event loop from processing
 * incoming clipboard advertisements before sending any data to
 * other Wayland clients (this is needed in order to avoid feedback
 * loop from our own advertisements), (2) waits for the list of clipboard
 * formats available on the host side (set by vbcl_wayland_hlp_edcp_clip_hg_report_join_cb),
 * and (3) sends data offers for available host clipboard to other clients.
 *
 * @returns IPRT status code.
 * @param   enmSessionType      Session type, must be verified as
 *                              a consistency check.
 * @param   pvUser              User data (unused).
 */
static DECLCALLBACK(int) vbcl_wayland_hlp_edcp_clip_hg_report_join2_cb(
    vbcl_wl_session_type_t enmSessionType, void *pvUser)
{
    int rc = (enmSessionType == VBCL_WL_CLIPBOARD_SESSION_TYPE_COPY_TO_GUEST)
             ? VINF_SUCCESS : VERR_WRONG_ORDER;

    RT_NOREF(pvUser);

    VBCL_LOG_CALLBACK;

    if (RT_SUCCESS(rc))
    {
        g_EdcpCtx.BaseCtx.fIngnoreWlClipIn = true;

        SHCLFORMATS fFmts = g_EdcpCtx.BaseCtx.Session.clip.fFmts.wait();
        if (fFmts != g_EdcpCtx.BaseCtx.Session.clip.fFmts.defaults())
        {
            ext_data_control_source_v1 *pDataSource =
                ext_data_control_manager_v1_create_data_source(g_EdcpCtx.pDataControlManager);

            if (RT_VALID_PTR(pDataSource))
            {
                ext_data_control_source_v1_add_listener(
                    (struct ext_data_control_source_v1 *)pDataSource, &g_data_source_listener, &g_EdcpCtx);

                VBoxMimeConvEnumerateMimeById(fFmts,
                                              vbcl_wayland_hlp_edcp_send_offers,
                                              pDataSource);

                ext_data_control_device_v1_set_selection(g_EdcpCtx.pDataDevice, pDataSource);
            }
            else
                rc = VERR_NO_MEMORY;
        }
        else
            rc = VERR_NO_DATA;
    }

    return rc;
}

/**
 * Session callback: Copy clipboard from the host.
 *
 * This callback (1) sets host clipboard formats list to the session,
 * (2) asks Wayland event thread to advertise these formats to the guest,
 * (3) waits for guest to request clipboard in specific format, (4) read
 * host clipboard in this format, and (5) sets clipboard data to the session,
 * so Wayland events thread can inject it into the guest.
 *
 * This callback should not return until clipboard data is read from
 * the host or error occurred. It must block host events loop until
 * current host event is fully processed.
 *
 * @returns IPRT status code.
 * @param   enmSessionType      Session type, must be verified as
 *                              a consistency check.
 * @param   pvUser              User data (host clipboard formats).
 */
static DECLCALLBACK(int) vbcl_wayland_hlp_edcp_clip_hg_report_join_cb(
    vbcl_wl_session_type_t enmSessionType, void *pvUser)
{
    SHCLFORMATS *pfFmts = (SHCLFORMATS *)pvUser;
    AssertPtrReturn(pfFmts, VERR_INVALID_PARAMETER);

    int rc = (enmSessionType == VBCL_WL_CLIPBOARD_SESSION_TYPE_COPY_TO_GUEST)
             ? VINF_SUCCESS : VERR_WRONG_ORDER;

    VBCL_LOG_CALLBACK;

    AssertPtrReturn(pfFmts, VERR_INVALID_PARAMETER);

    if (RT_SUCCESS(rc))
        rc = vbcl_wayland_xdcp_get_host_clipboard(&g_EdcpCtx.BaseCtx, *pfFmts);

    return rc;
}

/**
 * @interface_method_impl{VBCLWAYLANDHELPER_CLIPBOARD,pfnHGClipReport}
 */
static DECLCALLBACK(int) vbcl_wayland_hlp_edcp_clip_hg_report(SHCLFORMATS fFormats)
{
    int rc = VERR_NO_DATA;

    VBCL_LOG_CALLBACK;

    if (fFormats != VBOX_SHCL_FMT_NONE)
    {
        rc = vbcl_wayland_session_end(&g_EdcpCtx.BaseCtx.Session.Base, NULL, NULL);
        if (RT_SUCCESS(rc))
        {
            rc = vbcl_wayland_session_start(&g_EdcpCtx.BaseCtx.Session.Base,
                                            VBCL_WL_CLIPBOARD_SESSION_TYPE_COPY_TO_GUEST,
                                            &vbcl_wayland_hlp_edcp_session_start_generic_cb,
                                            &g_EdcpCtx.BaseCtx.Session);

            if (RT_SUCCESS(rc))
                rc = vbcl_wayland_session_join(&g_EdcpCtx.BaseCtx.Session.Base,
                                               vbcl_wayland_hlp_edcp_clip_hg_report_join_cb,
                                               &fFormats);
        }
        else
            VBClLogError("unable to start session, previous session is still running rc=%Rrc\n", rc);
    }

    return rc;
}

/**
 * Session callback: Copy clipboard to the host.
 *
 * This callback sets clipboard format to the session as requested
 * by host, waits for guest clipboard data in requested format and
 * sends data to the host.
 *
 * This callback should not return until clipboard data is sent to
 * the host or error occurred. It must block host events loop until
 * current host event is fully processed.
 *
 * @returns IPRT status code.
 * @param   enmSessionType      Session type, must be verified as
 *                              a consistency check.
 * @param   pvUser              User data (requested format).
 */
static DECLCALLBACK(int) vbcl_wayland_hlp_edcp_clip_gh_read_join_cb(
    vbcl_wl_session_type_t enmSessionType, void *pvUser)
{
    SHCLFORMAT *puFmt = (SHCLFORMAT *)pvUser;
    AssertPtrReturn(puFmt, VERR_INVALID_PARAMETER);

    int rc = (enmSessionType == VBCL_WL_CLIPBOARD_SESSION_TYPE_COPY_TO_HOST)
             ? VINF_SUCCESS : VERR_WRONG_ORDER;

    VBCL_LOG_CALLBACK;

    AssertPtrReturn(puFmt, VERR_INVALID_PARAMETER);

    if (RT_SUCCESS(rc))
        rc = vbcl_wayland_xdcp_set_host_clipboard(&g_EdcpCtx.BaseCtx, *puFmt);

    return rc;
}

/**
 * @interface_method_impl{VBCLWAYLANDHELPER_CLIPBOARD,pfnGHClipRead}
 */
static DECLCALLBACK(int) vbcl_wayland_hlp_edcp_clip_gh_read(SHCLFORMAT uFmt)
{
    int rc;

    VBCL_LOG_CALLBACK;

    rc = vbcl_wayland_session_join(&g_EdcpCtx.BaseCtx.Session.Base,
                                   &vbcl_wayland_hlp_edcp_clip_gh_read_join_cb,
                                   &uFmt);
    return rc;
}

static const VBCLWAYLANDHELPER_CLIPBOARD g_WaylandHelperEdcpClip =
{
    vbcl_wayland_hlp_edcp_clip_init,             /* .pfnInit */
    vbcl_wayland_hlp_edcp_clip_term,             /* .pfnTerm */
    vbcl_wayland_hlp_edcp_clip_set_ctx,          /* .pfnSetClipboardCtx */
    vbcl_wayland_hlp_edcp_clip_popup,            /* .pfnPopup */
    vbcl_wayland_hlp_edcp_clip_hg_report,        /* .pfnHGClipReport */
    vbcl_wayland_hlp_edcp_clip_gh_read,          /* .pfnGHClipRead */
};

static const VBCLWAYLANDHELPER_DND g_WaylandHelperEdcpDnD =
{
    NULL,                                        /* .pfnInit */
    NULL,                                        /* .pfnTerm */
};

/* Helper callbacks. */
const VBCLWAYLANDHELPER g_WaylandHelperEdcp =
{
    "wayland-ext-dcp",                           /* .pszName */
    vbcl_wayland_hlp_edcp_probe,                 /* .pfnProbe */
    g_WaylandHelperEdcpClip,                     /* .clip */
    g_WaylandHelperEdcpDnD,                      /* .dnd */
};
