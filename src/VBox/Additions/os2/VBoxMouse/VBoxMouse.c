/* $Id: VBoxMouse.c 114089 2026-05-06 13:45:14Z knut.osmundsen@oracle.com $ */
/** @file
 * VBoxMouse - VirtualBox Guest Additions Mouse Driver for OS/2, internal header.
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


/*********************************************************************************************************************************
*   Header Files                                                                                                                 *
*********************************************************************************************************************************/
#include "VBoxMouse.h"

#define INCL_ALLTYPE 1
#include "dd.h"
#include "mou.h"

#include <VBox/VBoxGuest.h>
#include <VBox/VMMDev.h>
#include <iprt/errcore.h>

#include "vdm.h"
#include "sgcb.h"


/*********************************************************************************************************************************
*   Global Variables                                                                                                             *
*********************************************************************************************************************************/
/** The name of the VBoxGuest device. (must be in DSEG) */
char                g_szVBoxGuestName[9] = VBOXGUEST_DEVICE_NAME_SHORT;
/** 0 if not connected, 1 if connected. */
char                g_fConnected = 0;
/** The AttachDD data returned by DevHelp_AttachDD. (must be in DSEG) */
ATTACHDD            g_VBoxGuestDD = { 0, 0, 0, 0 };
/** The VBoxGuest IDC connection data. */
VBGLOS2ATTACHDD     g_VBoxGuestIDC = { 0, 0, 0, 0, 0 };


// Various variables from assembly files that we need.
extern SGCB far *FgndCB;
#pragma aux FgndCB "*";

extern USHORT VDM_Cols;
#pragma aux VDM_Cols "*";

extern USHORT VDM_Rows;
#pragma aux VDM_Rows "*";

extern BYTE FgndSessn;
#pragma aux FgndSessn "*";

extern BYTE Num_Grps;
#pragma aux Num_Grps "*";

extern USHORT VDM_Flags;
#pragma aux VDM_Flags "*";


/*********************************************************************************************************************************
*   Internal Functions                                                                                                           *
*********************************************************************************************************************************/
// assembler function, tell compiler to not decorate function name
void __cdecl Process_Absolute(void);


/**
 * INITCOMPLETE worker that attaches to VBoxGuest.sys.
 *
 * This sets the g_VBoxGuestDD, g_VBoxGuestIDC and g_fConnected globals.
 *
 * (The __cdecl is there because we're called from assembly.)
 */
void __cdecl VBoxAttachToVBoxGuest(void)
{
    int rc;

    /*
     * Attach to VBoxGuest.sys.
     * (See kbd.c for a similar attach dd example...)
     */
    dprintf(("VBoxAttachToVBoxGuest: calling AttachDD..."));
    rc = DevHelp_AttachDD(g_szVBoxGuestName, (NPBYTE)&g_VBoxGuestDD);
    if (rc == 0)
    {
        PFNVBGLOS2ATTACHDD pfnAttach = (PFNVBGLOS2ATTACHDD)g_VBoxGuestDD.protentry;
        dprintf(("VBoxAttachToVBoxGuest: returned entrypoint=%lx pfn=%lx\n", g_VBoxGuestDD.protentry, pfnAttach));

        (pfnAttach)(&g_VBoxGuestIDC);

        dprintf(("VBoxAttachToVBoxGuest: u32Version=%RX32 u32Session=%RX32 pfnServiceEP=%RX32\n",
                 g_VBoxGuestIDC.u32Version, g_VBoxGuestIDC.u32Session, g_VBoxGuestIDC.pfnServiceEP, 0));
        dprintf(("VBoxAttachToVBoxGuest: fpfnServiceEP=%p fpfnServiceAsmEP=%p\n",
                  g_VBoxGuestIDC.fpfnServiceEP, g_VBoxGuestIDC.fpfnServiceAsmEP, 0));
        if (   g_VBoxGuestIDC.u32Version == VBGL_IOC_VERSION
            && g_VBoxGuestIDC.fpfnServiceEP != NULL)
        {
            union
            {
                VBGLIOCIDCCONNECT       IdcConnect;
                VBGLIOCIDCDISCONNECT    IdcDisconnect;
                VBGLIOCSETMOUSESTATUS   SetStatus;
                VBGLIOCCHANGEFILTERMASK InfoFlt;
                VBGLIOCWAITFOREVENTS    WaitInfo;
                VMMDevReqMouseStatus    Status;
            } u;
            VBGLREQHDR_INIT(&u.IdcConnect.Hdr, IDC_CONNECT);
            u.IdcConnect.u.In.u32MagicCookie = VBGL_IOCTL_IDC_CONNECT_MAGIC_COOKIE;
            u.IdcConnect.u.In.uReqVersion    = VBGL_IOC_VERSION;
            u.IdcConnect.u.In.uMinVersion    = VBGL_IOC_VERSION;
            u.IdcConnect.u.In.uReserved      = 0;
            rc = g_VBoxGuestIDC.fpfnServiceEP(g_VBoxGuestIDC.u32Session, VBGL_IOCTL_IDC_CONNECT,
                                              &u.IdcConnect.Hdr, sizeof(u.IdcConnect));
            if (rc >= 0 && u.IdcConnect.Hdr.rc >= 0)
            {

                /*
                 * Try switch to absolute mode.
                 *
                 * We need to enable the mouse capabilities changed event before doing
                 * so in case we need to wait for the GUI to say it wish to use absolute
                 * mouse too.
                 */
                /* Enable the event - just ignore failures. */
                VBGLREQHDR_INIT(&u.InfoFlt.Hdr, CHANGE_FILTER_MASK);
                u.InfoFlt.u.In.fOrMask = VMMDEV_EVENT_MOUSE_CAPABILITIES_CHANGED;
                u.InfoFlt.u.In.fNotMask = 0;
                rc = g_VBoxGuestIDC.fpfnServiceEP(g_VBoxGuestIDC.u32Session, VBGL_IOCTL_CHANGE_FILTER_MASK,
                                                  &u.InfoFlt.Hdr, sizeof(u.InfoFlt));
                if (rc < 0 || u.InfoFlt.Hdr.rc < 0)
                    dprintf(("VBoxAttachToVBoxGuest: CtlGuestFilterMask failed; rc=%d + %ld\n", rc, u.InfoFlt.Hdr.rc));

                /* Set mouse status. */
                VBGLREQHDR_INIT(&u.SetStatus.Hdr, SET_MOUSE_STATUS);
                u.SetStatus.u.In.fStatus = VMMDEV_MOUSE_GUEST_CAN_ABSOLUTE;
                rc = g_VBoxGuestIDC.fpfnServiceEP(g_VBoxGuestIDC.u32Session, VBGL_IOCTL_SET_MOUSE_STATUS,
                                                  &u.SetStatus.Hdr, sizeof(u.SetStatus));
                if (rc >= 0 && u.SetStatus.Hdr.rc >= 0)
                {
                    /* Get the new mouse status and look for guest+host can abs. */
                    VMMDEV_REQ_HDR_INIT(&u.Status.header, sizeof(u.Status), VMMDevReq_GetMouseStatus);
                    u.Status.mouseFeatures = 0;
                    u.Status.pointerXPos = -1;
                    u.Status.pointerYPos = -1;
                    rc = g_VBoxGuestIDC.fpfnServiceEP(g_VBoxGuestIDC.u32Session, VBGL_IOCTL_VMMDEV_REQUEST(sizeof(u.Status)),
                                                      (PVBGLREQHDR)&u.Status.header, sizeof(u.Status));
                    if (rc >= 0 && u.Status.header.rc >= 0)
                    {
                        if (    (u.Status.mouseFeatures & (VMMDEV_MOUSE_GUEST_CAN_ABSOLUTE | VMMDEV_MOUSE_HOST_WANTS_ABSOLUTE))
                            ==  VMMDEV_MOUSE_GUEST_CAN_ABSOLUTE)
                        {
                            /* Wait a bit to give the GUI a chance to respond to our query. */
                            VBGLREQHDR_INIT(&u.WaitInfo.Hdr, WAIT_FOR_EVENTS);
                            u.WaitInfo.u.In.cMsTimeOut = 5*1000; /* 5 seconds. */
                            u.WaitInfo.u.In.fEvents    = VMMDEV_EVENT_MOUSE_CAPABILITIES_CHANGED;
                            rc = g_VBoxGuestIDC.fpfnServiceEP(g_VBoxGuestIDC.u32Session, VBGL_IOCTL_WAIT_FOR_EVENTS,
                                                              &u.WaitInfo.Hdr, sizeof(u.WaitInfo));
                            dprintf(("VBoxAttachToVBoxGuest: waited 5 seconds (%d + %ld)\n", rc, u.WaitInfo.Hdr.rc));

                            /* query the features again. */
                            VMMDEV_REQ_HDR_INIT(&u.Status.header, sizeof(u.Status), VMMDevReq_GetMouseStatus);
                            u.Status.mouseFeatures = 0;
                            u.Status.pointerXPos = -1;
                            u.Status.pointerYPos = -1;
                            rc = g_VBoxGuestIDC.fpfnServiceEP(g_VBoxGuestIDC.u32Session,
                                                              VBGL_IOCTL_VMMDEV_REQUEST(sizeof(u.Status)),
                                                              (PVBGLREQHDR)&u.Status.header, sizeof(u.Status));
                        }
                    }

                    if (rc >= 0 && u.Status.header.rc >= 0)
                    {
                        if (    (u.Status.mouseFeatures & (VMMDEV_MOUSE_GUEST_CAN_ABSOLUTE | VMMDEV_MOUSE_HOST_WANTS_ABSOLUTE))
                            ==  (VMMDEV_MOUSE_GUEST_CAN_ABSOLUTE | VMMDEV_MOUSE_HOST_WANTS_ABSOLUTE))
                        {
                            dprintf(("VBoxAttachToVBoxGuest: Successfully attached (mouseFeatures=%#lx x=%ld y=%ld)\n",
                                     u.Status.mouseFeatures, u.Status.pointerXPos, u.Status.pointerYPos));
                            g_fConnected = TRUE;
                            return;
                        }

                        /* bailout */
                        dprintf(("VBoxAttachToVBoxGuest: failed to switch to abs mode (mouseFeatures=%#lx)\n", u.Status.mouseFeatures));
                    }
                    else
                        dprintf(("VBoxAttachToVBoxGuest: GetMouseStatus failed -> %d + %ld\n", rc, u.Status.header.rc));

                    VBGLREQHDR_INIT(&u.SetStatus.Hdr, SET_MOUSE_STATUS);
                    u.SetStatus.u.In.fStatus = 0;
                    g_VBoxGuestIDC.fpfnServiceEP(g_VBoxGuestIDC.u32Session, VBGL_IOCTL_SET_MOUSE_STATUS,
                                                 &u.SetStatus.Hdr, sizeof(u.SetStatus));
                }
                else
                    dprintf(("VBoxAttachToVBoxGuest: SetMouseStatus failed -> %d + %ld\n", rc, u.SetStatus.Hdr.rc));
            }
            else
                dprintf(("VBoxAttachToVBoxGuest: IDC connect failed -> %d + %ld\n", rc, u.IdcConnect.Hdr.rc));

            /*
             * Disconnect.
             */
            VBGLREQHDR_INIT(&u.IdcDisconnect.Hdr, IDC_DISCONNECT);
            u.IdcDisconnect.u.In.pvSession = g_VBoxGuestIDC.u32Session;
            g_VBoxGuestIDC.fpfnServiceEP(g_VBoxGuestIDC.u32Session, VBGL_IOCTL_IDC_DISCONNECT,
                                         &u.IdcDisconnect.Hdr, sizeof(u.IdcDisconnect));
        }
        else
            dprintf(("VBoxAttachToVBoxGuest: Version check failed!\n"));
        g_VBoxGuestIDC.u32Version    = 0;
        g_VBoxGuestIDC.u32Session    = 0;
        g_VBoxGuestIDC.fpfnServiceEP = NULL;
    }
    else
        dprintf(("VBoxAttachToVBoxGuest: AttachDD failed, rc=%d\n", rc));
}


/**
 * Gets the absolute mouse coordinates.
 *
 * @returns boolean success indicator.
 * @param   pX      Where to put the X coordinate. Only set on success.
 * @param   pY      Where to put the Y coording. Only set on success.
 */
int VBoxGetAbsMouseCoords(PULONG pX, PULONG pY)
{
    if (g_fConnected)
    {
        static unsigned long s_cErrors = 0;
        VMMDevReqMouseStatus Req;
        int rc;

        VMMDEV_REQ_HDR_INIT(&Req.header, sizeof(Req), VMMDevReq_GetMouseStatus);
        Req.mouseFeatures = 0;
        Req.pointerXPos = 0;
        Req.pointerYPos = 0;

        rc = g_VBoxGuestIDC.fpfnServiceEP(g_VBoxGuestIDC.u32Session, VBGL_IOCTL_VMMDEV_REQUEST(sizeof(Req)),
                                          (PVBGLREQHDR)&Req.header, sizeof(Req));
        if (    rc >= 0
            &&  Req.header.rc >= 0
            &&  (Req.mouseFeatures & VMMDEV_MOUSE_HOST_WANTS_ABSOLUTE))
        {
            dprintf(("VBoxGetAbsMouseCoords: %ld,%ld\n", (long)Req.pointerXPos, (long)Req.pointerYPos));
            *pX = Req.pointerXPos;
            *pY = Req.pointerYPos;
            return TRUE;
        }
        if (s_cErrors++ < 32)
            dprintf(("VBoxGetAbsMouseCoords: failed - %d + %ld\n", rc, Req.header.rc));
    }
    return FALSE;
}


/**
 * Hook we've inserted into SendPacket for trying to do things with absolute
 * coordinates.
 *
 * @returns true if handled, false if not.
 */
bool __cdecl VBoxMouseSendPacketAbsolute(int16_t x, int16_t y, uint8_t event)
{
    /*
     * Send absolute mouse packet if we can.
     */
    ULONG xCoord = -1;
    ULONG yCoord = -1;
    if (VBoxGetAbsMouseCoords(&xCoord, &yCoord))
    {
        DevStatus &= ~gREADENABLE;

        /*
         * Put data into the global structure for absolute positions.
         *
         * The input coordinates are in a 0xffff by 0xffff format, we have
         * to convert it to something that'll fit into a signed short world.
         */
        xCoord /= 2;
        if (xCoord > 0x7FFE)
            Int_Packet.X_Pos = 0x7FFE;
        else
            Int_Packet.X_Pos = (USHORT)xCoord;

        yCoord /= 2;
        if (yCoord > 0x7FFE)
            Int_Packet.Y_Pos = 0x7FFE;
        else
            Int_Packet.Y_Pos = (USHORT)yCoord;

        Int_Packet.X_Size = 0x7FFE;
        Int_Packet.Y_Size = 0x7FFE;

        Int_Packet.Event = event;

        if (FgndSessn < Num_Grps && !(VDM_Flags & VDMXMOUSEMODE))
            // PM, fullscreen OS/2 or windowed VDM session
            dprintf(("Fgnd Screen resolution type %d (%d,%d) (%d,%d)\n",
                     (USHORT)FgndCB->Mtype, FgndCB->GCol_Res, FgndCB->GRow_Res, FgndCB->TCol_Res, FgndCB->TRow_Res));
        else
            dprintf(("VDM Screen resolution (%d,%d) FgndSessn %d Num_Grps %d VDM_Flags %x\n",
                     VDM_Cols, VDM_Rows, (USHORT)FgndSessn, (USHORT)Num_Grps, (USHORT)VDM_Flags));
        dprintf(("VBox mouse position (%d,%d) %x\n", (int)Int_Packet.X_Pos, (int)Int_Packet.Y_Pos, (int)event));

        STI();
        // save our stack and call ASM function to process the packet
        _asm
        {
           push ss
           push bp
           push sp
           call Process_Absolute
           pop sp
           pop bp
           pop ss
        };
        CLI();
        DevStatus |= gREADENABLE;

        return true;
    }
    return false;
}


/**
 * This is for debugging, see vdm.asm.
 */
void __cdecl __loadds __far VBoxScreenSizeChange(uint16_t Ssi_Mtype, uint16_t Ssi_TCol_Res, uint16_t Ssi_TRow_Res,
                                                 uint16_t Ssi_GCol_Res, uint16_t Ssi_GRow_Res)
{
    dprintf(("VBoxScreenSizeChange type %d (%d,%d) (%d,%d)\n", Ssi_Mtype, Ssi_TCol_Res, Ssi_TRow_Res, Ssi_GCol_Res, Ssi_GRow_Res));
}


/**
 * We must force a mouse pointer update as the moving the mouse pointer in
 * the gradd driver doesn't work.
 */
void __cdecl __loadds __far VBoxUpdatePointer(void)
{
    dprintf(("VBoxUpdatePointer: end of session switch -> force mouse pointer update\n"));
#if 0
//This (sometimes) causes the mouse to not respond when switching back and forth
//between a full screen OS/2 session & PM
//Might need to delay this to get rid of the sync problem
//(switch to FS winos2 session, move mouse, exit winos2, RMB click (don't move mouse)
// -> popup menu at the wrong coordinates)
    SendPacket(0,0,1);
#endif
}

