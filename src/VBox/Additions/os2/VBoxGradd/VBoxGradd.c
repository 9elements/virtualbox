/** $Id: VBoxGradd.c 114088 2026-05-06 13:44:56Z knut.osmundsen@oracle.com $ */
/** @file
 * VBoxGradd - OS/2 GRADD driver for VirtualBox (replaces gengradd).
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
#define INCL_WIN
#define INCL_GPI
#define INCL_DOS
#define INCL_ERRORS
#include <os2.h>

/* Apply calling convention to the GRADD functions (defaults to _Optlink). */
#ifdef __WATCOMC__
# pragma aux (optlink) VHAllocMem;
# pragma aux (optlink) VHCallForward;
# pragma aux (optlink) VHFreeMem;
# pragma aux (optlink) VHGetVRAMInfo;
# pragma aux (optlink) VHLockMem;
# pragma aux (optlink) VHMap;
# pragma aux (optlink) VHMapVRAM;
# pragma aux (optlink) VHPhysToVirt;
# pragma aux (optlink) VHSetMTRR;
# pragma aux (optlink) VHUnlockMem;
#endif

#include <gradd.h>
#include <svgapmi.h>

#pragma pack(4) /* We're using /Sp1 for some reason */
#include <VBox/log.h> /* LOG_ENABLED */
#include <string.h> /* memcpy */
#include <VBoxVideo.h>
#include <VBox/VMMDev.h>
#pragma pack()
#include <VBox/VBoxGuest.h>


/*********************************************************************************************************************************
*   Defined Constants And Macros                                                                                                 *
*********************************************************************************************************************************/
/** Maximum support X size. */
#define VBOX_MAX_CURSOR_CX              64
/** Maximum support Y size. */
#define VBOX_MAX_CURSOR_CY              64
/** Max core cursor size. */
#define VBOX_MAX_COLOUR_CURSOR_SIZE     (VBOX_MAX_CURSOR_CX * VBOX_MAX_CURSOR_CY * 4)
/** Max full cursor temp buffer size (mask + colour bitmap). */
#define VBOX_MAX_CURSOR_SIZE            (VBOX_MAX_COLOUR_CURSOR_SIZE + VBOX_MAX_COLOUR_CURSOR_SIZE / 8)

/** Out own debug logging. */
#ifdef LOG_ENABLED
# define dprintf(a)                     VBoxDPrintf a
# define dprintf2(a)                    do { if (g_uDbgLevel >= 2) { VBoxDPrintf a; } } while (0)
# define dprintf3(a)                    do { if (g_uDbgLevel >= 3) { VBoxDPrintf a; } } while (0)
# define dprintf4(a)                    do { if (g_uDbgLevel >= 4) { VBoxDPrintf a; } } while (0)
#else
# define dprintf(a)                     ((void)0)
# define dprintf2(a)                    ((void)0)
# define dprintf3(a)                    ((void)0)
# define dprintf4(a)                    ((void)0)
#endif


/*********************************************************************************************************************************
*   Structures and Typedefs                                                                                                      *
*********************************************************************************************************************************/
/** VMAN.VHSetMTRR. */
typedef APIRET _Optlink FNVHSETMTRR(PMTRRIN pMtrr, ULONG fCmd);
/** Pointer to VMAN.VHSetMTRR. */
typedef FNVHSETMTRR *PFNVHSETMTRR;


/*********************************************************************************************************************************
*   Global Variables                                                                                                             *
*********************************************************************************************************************************/
#ifdef __WATCOMC__
# pragma data_seg(DATA_SHARED,DATA_SHARED)
#else
# pragma data_seg(DATA_SHARED)
#endif
extern char     g_StartOfData[];    /* VBoxGradd-begin.asm */

/** The ID associated with this driver instance.
 * Initialied at GHI_CMD_INIT time. */
GID             g_gidVBox     = ~(GID)0;

/** Our Video Adapter structure. */
VIDEO_ADAPTER   g_VBoxAdapter = { 0 };


/** @name Code & data segment locking info (completely unnnecessary).
 * @{ */
ULONG           g_cbCode     = 0;
ULONG           g_cbData     = 0;
ULONG           g_rcLockCode = 0;
ULONG           g_rcLockData = 0;
/** @} */

/** @name Mode Management.
 * @{ */
/** Number of valid entries in g_paVBoxVideoModes. */
ULONG           g_cVBoxVideoModes   = 0;
/** Pointer to an array of valid modes. */
PGDDMODEINFO    g_paVBoxVideoModes  = NULL;

/** The table index of the current mode (into g_paVBoxVideoModes). */
ULONG           g_idxVBoxCurMode    = ~(ULONG)0;
/** The current mode ID. */
MODEID          g_idVBoxCurMode     = ~(MODEID)0;
/** The physical address of the current VRAM aperture. */
ULONG           g_PhysVRam          = ~(ULONG)0;
/** Pointer to the ring-3 VRAM mapping.
 * This is initialized when setting the mode. */
PBYTE           g_pbVRamR3Ptr       = NULL;
/** Pointer to the ring-0 VRAM mapping.
 * This is initialized when setting the mode. */
PBYTE           g_pbVRamR0Ptr       = NULL;
/** Size of the current VRAM aperture. */
ULONG           g_cbVRamAperture    = 0;
/** Size of the MTRR WC region for the current mode. */
ULONG           g_cbVRamMtrr        = 0;
/** @} */

/** @name Cursor Management.
 * @{ */
BOOL            g_fCursorSimulate   = FALSE;
ULONG           g_fCursorStatus     = 0;

/** Temporary cursor storage.
 * We need to temporarily store the cursor data as VBox expects it in a different
 * format than OS/2 provides.  We use global data for it as we may not have
 * enough stack to store it there. */
BYTE            g_abVBoxCursorData[VBOX_MAX_CURSOR_SIZE + 128] = {0};

#ifdef LOG_ENABLED
/** The logging level.   */
unsigned        g_uDbgLevel = 9;//1;
#endif

extern char     g_EndOfData[];      /* VBoxGradd-end.asm */
/** @} */

#pragma data_seg()


/** The VBoxGuest handle (per process). */
HFILE           g_hVBoxDrv          = NULLHANDLE;



/*********************************************************************************************************************************
*   Internal Functions                                                                                                           *
*********************************************************************************************************************************/
#ifdef LOG_ENABLED
static void         VBoxDPrintf(char *pszFormat, ...);
#endif

/* VBoxGradd-begin.asm: */
DECLASM(void)       StartOfCode();

/* VBoxGradd-end.asm: */
DECLASM(void)       EndOfCode();
DECLASM(int)        VBoxBitTest(unsigned char *ptr, unsigned long bit);
DECLASM(unsigned)   VBoxGetCpl(void);
DECLASM(unsigned)   VBoxGetIopl(void);
DECLASM(void)       VBoxOutByteString(RTIOPORT uPort, const char *pachSrc, size_t cchSrc);
DECLASM(void)       VBoxCallRing2OutU8Str(RTIOPORT uDst, const char *pch, size_t cch);


/* VIDEOPMI.DLL (no header. sigh.) */
APIRET VIDEOAPI     VIDEOPMI32Request(PVIDEO_ADAPTER, ULONG, PVOID, PVOID);



/*********************************************************************************************************************************
*   VBoxGuestR3Lib Snippets                                                                                                      *
*********************************************************************************************************************************/

/**
 * Tries to open the VBoxGuest driver in the current process.
 *
 * This is called the GHI_CMD_INITPROC as well as vbglR3DoIOCtl() if the driver
 * open didn't succeed during process init.
 */
static BOOL vboxOpenDriver(void)
{
    ULONG  ulAction = 0;
    HFILE  hf       = NULLHANDLE;
    APIRET rc;

    if (g_hVBoxDrv != NULLHANDLE)
        return TRUE;

    /*
     * We might wish to compile this with Watcom, so stick to
     * the OS/2 APIs all the way. And in any case we have to use
     * DosDevIOCtl for the requests, why not use Dos* for everything.
     */
    rc = DosOpen((PSZ)VBOXGUEST_DEVICE_NAME, &hf, &ulAction, 0, FILE_NORMAL,
                 OPEN_ACTION_OPEN_IF_EXISTS,
                 OPEN_FLAGS_FAIL_ON_ERROR | OPEN_FLAGS_NOINHERIT | OPEN_SHARE_DENYNONE | OPEN_ACCESS_READWRITE,
                 NULL);
    if (rc)
    {
        dprintf2(("GRADD vboxOpenDriver: failed to open VBoxGuest: %d\n", rc)); /** @todo unsafe! */
        return FALSE;
    }

    if (hf < 16)
    {
        HFILE ahfs[16];
        unsigned i;
        for (i = 0; i < RT_ELEMENTS(ahfs); i++)
        {
            ahfs[i] = 0xffffffff;
            rc = DosDupHandle(hf, &ahfs[i]);
            if (rc)
                break;
            if (ahfs[i] >= 16)
            {
                i++;
                break;
            }
        }

        if (i-- > 0)
        {
            ULONG fulState = 0;
            rc = DosQueryFHState(ahfs[i], &fulState);
            if (!rc)
            {
                fulState |= OPEN_FLAGS_NOINHERIT;
                fulState &= OPEN_FLAGS_WRITE_THROUGH | OPEN_FLAGS_FAIL_ON_ERROR | OPEN_FLAGS_NO_CACHE | OPEN_FLAGS_NOINHERIT; /* Turn off non-participating bits. */
                rc = DosSetFHState(ahfs[i], fulState);
            }
            if (!rc)
            {
                rc = DosClose(hf);
                hf = ahfs[i];
            }
            else
                i++;
            while (i-- > 0)
                DosClose(ahfs[i]);
        }
    }
    g_hVBoxDrv = hf;

    dprintf2(("GRADD vboxOpenDriver: opened VBoxGuest fd=%d\n", hf));
    return TRUE;
}


/**
 * Internal wrapper around various OS specific ioctl implemenations.
 *
 * @returns VBox status code as returned by VBoxGuestCommonIOCtl, or
 *          an failure returned by the OS specific ioctl APIs.
 *
 * @param   uFunction   The requested function.
 * @param   pReq        The request (input & output).
 * @param   cbReq       The size of the request.
 *
 * @remark  Exactly how the VBoxGuestCommonIOCtl is ferried back
 *          here is OS specific. On BSD and Darwin we can use errno,
 *          while on OS/2 we use the 2nd buffer of the IOCtl.
 */
static int vbglR3DoIOCtl(unsigned uFunction, PVBGLREQHDR pHdr, size_t cbReq)
{
    ULONG  cbOS2Parm = cbReq;
    APIRET rc;

    if (g_hVBoxDrv == NULLHANDLE)
    {
        vboxOpenDriver();
        if (g_hVBoxDrv == NULLHANDLE)
            return VERR_INTERNAL_ERROR;
    }

    rc = DosDevIOCtl(g_hVBoxDrv, VBGL_IOCTL_CATEGORY, uFunction, pHdr, cbReq, &cbOS2Parm, NULL, 0, NULL);
    if (RT_LIKELY(rc == NO_ERROR))
        return VINF_SUCCESS;
    return RTErrConvertFromOS2(rc);
}


/**
 * Performs a VMMDev request via VBoxGuest.
 */
static int VbglR3GRPerform(VMMDevRequestHeader *pReq)
{
    PVBGLREQHDR    pReqHdr = (PVBGLREQHDR)pReq;
    uint32_t const cbReq   = pReqHdr->cbIn;
    pReqHdr->cbOut = cbReq;
    if (pReq->size < _1K)
        return vbglR3DoIOCtl(VBGL_IOCTL_VMMDEV_REQUEST(cbReq), pReqHdr, cbReq);
    return vbglR3DoIOCtl(VBGL_IOCTL_VMMDEV_REQUEST_BIG, pReqHdr, cbReq);
}



/*********************************************************************************************************************************
*   Logging                                                                                                                      *
*********************************************************************************************************************************/

#ifdef LOG_ENABLED

# define MAX_DPRINTF_REQ_BUF_SIZE    (128U)
# define MAX_DPRINTF_STRING_LENGTH   (MAX_DPRINTF_REQ_BUF_SIZE - RT_UOFFSETOF(VMMDevReqLogString, szString) - 1U)

/**
 * Flushes the log string.
 */
static void vboxDPrintfFlush(VMMDevReqLogString *pReq, size_t cch)
{
    if (cch > 0)
    {
        unsigned const uIopl = VBoxGetIopl();
        if (VBoxGetCpl() <= uIopl)
            VBoxOutByteString(RTLOG_DEBUG_PORT, pReq->szString, cch);
# if defined(LOG_ENABLED) && defined(VBOXGRADD_COMPILED_WITH_WATCOM) /* ilink crashes in thunking code. sigh. */
        else if (uIopl >= 2)
            VBoxCallRing2OutU8Str(RTLOG_DEBUG_PORT, pReq->szString, cch);
# endif
        else
        {
            vmmdevInitRequest(&pReq->header, VMMDevReq_LogString);
            pReq->header.size += cch;
            pReq->szString[cch] = '\0';
            VbglR3GRPerform(&pReq->header);
        }
    }
}


/**
 * Helper that adds a character to the request, optionally flushing it.
 */
static size_t vboxDPrintfPutC(VMMDevReqLogString *pReq, size_t off, char ch)
{
    if (off < MAX_DPRINTF_STRING_LENGTH)
    {
        pReq->szString[off] = ch;
        return off + 1;
    }

    vboxDPrintfFlush(pReq, off);
    pReq->szString[0] = ch;
    return 1;
}


/**
 * Minimal debug printf
 *
 * @note we're not using IPRT here because we do not want the hassle of making
 *       it build with the ancient Visual Age for C++ 3.08 compiler.
 */
static void VBoxDPrintf(char *pszFormat, ...)
{
    static char const s_szDigits[] = "0123456789abcdef";
    union
    {
        VMMDevReqLogString Req;
        uint8_t            ab[MAX_DPRINTF_REQ_BUF_SIZE];
    }            uBuf;
    size_t       off    = 0;
    char         ch;
    unsigned     uValue;
    int          i;
    va_list      va;

    va_start(va, pszFormat);
    while ((ch = *pszFormat++) != '\0')
    {
        if (ch != '%')
            off = vboxDPrintfPutC(&uBuf.Req, off, ch);
        else if ((ch = *pszFormat) != '\0')
        {
            bool fHash = false;
            if (ch != '#' || pszFormat[1] != 'x')
                pszFormat++;
            else
            {
                fHash = true;
                ch    = 'x';
                pszFormat += 2;
            }
            switch (ch)
            {
                case 'x':
                    uValue = va_arg(va, unsigned);
                    if (fHash)
                    {
                        off = vboxDPrintfPutC(&uBuf.Req, off, '0');
                        off = vboxDPrintfPutC(&uBuf.Req, off, 'x');
                    }

                    /* Skip leading zeros. */
                    i = 28;
                    while (i > 0 && !((uValue >> i) & 0xf))
                        i -= 4;

                    /* conver the number. */
                    do
                    {
                        off = vboxDPrintfPutC(&uBuf.Req, off, s_szDigits[(uValue >> i) & 0xf]);
                        i -= 4;
                    } while (i >= 0);
                    break;

                case 'd':
                case 'u':
                {
                    static unsigned const s_auFactors[] =
                    {
                        1,
                        10,
                        100,
                        1000,
                        10000,
                        100000,
                        1000000,
                        10000000,
                        100000000,
                        1000000000,
                    };
                    uValue = va_arg(va, unsigned);

                    /* deal with negative values */
                    if (ch == 'd' && (int)uValue < 0)
                    {
                        uValue = (unsigned)-(int)uValue;
                        off = vboxDPrintfPutC(&uBuf.Req, off, '-');
                    }

                    /* skip leading zeros */
                    i = RT_ELEMENTS(s_auFactors) - 1;
                    while (i > 0 && uValue < s_auFactors[i])
                        i--;

                    /* convert the number */
                    while (i > 0)
                    {
                        ch      = s_szDigits[uValue / s_auFactors[i]];
                        uValue %= s_auFactors[i];
                        off = vboxDPrintfPutC(&uBuf.Req, off, ch);
                        i--;
                    }

                    /* final digit */
                    ch  = s_szDigits[uValue];
                    off = vboxDPrintfPutC(&uBuf.Req, off, ch);
                    break;
                }

                case 's':
                {
                    const char *pszArg = va_arg(va, const char *);
                    while ((ch = *pszArg++) != '\0')
                        off = vboxDPrintfPutC(&uBuf.Req, off, ch);
                    break;
                }

                default:
                    pszFormat--;
                    break;
            }
        }
    }

    /* Flush the reminder. */
    if (off)
        vboxDPrintfFlush(&uBuf.Req, off);

    va_end(va);
}


/**
 * Get the name of a GHI_CMD_XXX value for logging purposes.
 */
const char *VBoxNameGhiCmd(unsigned ulGhiCmd)
{
    switch (ulGhiCmd)
    {
        case GHI_CMD_INIT:       return "INIT";
        case GHI_CMD_TERM:       return "TERM";
        case GHI_CMD_INITPROC:   return "INITPROC";
        case GHI_CMD_TERMPROC:   return "TERMPROC";
        case GHI_CMD_QUERYCAPS:  return "QUERYCAPS";
        case GHI_CMD_QUERYMODES: return "QUERYMODES";
        case GHI_CMD_SETMODE:    return "SETMODE";
        case GHI_CMD_PALETTE:    return "PALETTE";
        case GHI_CMD_BANK:       return "BANK";
        case GHI_CMD_BITBLT:     return "BITBLT";
        case GHI_CMD_LINE:       return "LINE";
        case GHI_CMD_POLYGON:    return "POLYGON";
        case GHI_CMD_SETPTR:     return "SETPTR";
        case GHI_CMD_MOVEPTR:    return "MOVEPTR";
        case GHI_CMD_SHOWPTR:    return "SHOWPTR";
        case GHI_CMD_VRAM:       return "VRAM";
        case GHI_CMD_REQUESTHW:  return "REQUESTHW";
        case GHI_CMD_EVENT:      return "EVENT";
        case GHI_CMD_EXTENSION:  return "EXTENSION";
        case GHI_CMD_TEXT:       return "TEXT";
        case GHI_CMD_USERCAPS:   return "USERCAPS";
    }
    return "??";
}


/** For logging g_VBoxAdapter content. */
void VBoxDPrintfAdapter(void)
{
    VBoxDPrintf("GRADD Adapter: hVideo=%x idAdapter=%x bus=%u idDev=%x idVendor=%x idSlot=%x endian=%u\n",
                g_VBoxAdapter.hvideo,
                g_VBoxAdapter.Adapter.ulAdapterID,
                (unsigned)g_VBoxAdapter.Adapter.bBusType,
                (unsigned)g_VBoxAdapter.Adapter.usDeviceBusID,
                (unsigned)g_VBoxAdapter.Adapter.usVendorBusID,
                (unsigned)g_VBoxAdapter.Adapter.SlotID,
                (unsigned)g_VBoxAdapter.Adapter.SlotID,
                (unsigned)g_VBoxAdapter.Adapter.bEndian);
    VBoxDPrintf("GRADD Adapter: MMIO=%x PIO=%x cbVRAM=%x\n",
                g_VBoxAdapter.Adapter.ulMMIOBaseAddress,
                g_VBoxAdapter.Adapter.ulPIOBaseAddress,
                g_VBoxAdapter.Adapter.ulTotalMemory);
    VBoxDPrintf("GRADD Adapter: OEM='%s'\n", g_VBoxAdapter.Adapter.szOEMString);
    VBoxDPrintf("GRADD Adapter: DAC='%s'\n", g_VBoxAdapter.Adapter.szDACString);
    VBoxDPrintf("GRADD Adapter: REV='%s'\n", g_VBoxAdapter.Adapter.szRevision);
    VBoxDPrintf("GRADD Ad/Mode: id=%x type=%x int10=%x cx=%u cy=%u bpp=%u planes=%u cbScan=%x\n",
                g_VBoxAdapter.ModeInfo.miModeId,
                (unsigned)g_VBoxAdapter.ModeInfo.usType,
                (unsigned)g_VBoxAdapter.ModeInfo.usInt10ModeSet,
                (unsigned)g_VBoxAdapter.ModeInfo.usXResolution,
                (unsigned)g_VBoxAdapter.ModeInfo.usYResolution,
                (unsigned)g_VBoxAdapter.ModeInfo.bBitsPerPixel,
                (unsigned)g_VBoxAdapter.ModeInfo.bBitPlanes,
                (unsigned)g_VBoxAdapter.ModeInfo.usBytesPerScanLine);
    VBoxDPrintf("GRADD Ad/Mode: VRAMPhys=%x cbAperture=%x cbPage=%x cbSave=%x\n",
                g_VBoxAdapter.ModeInfo.ulBufferAddress,
                g_VBoxAdapter.ModeInfo.ulApertureSize,
                g_VBoxAdapter.ModeInfo.ulPageLength,
                g_VBoxAdapter.ModeInfo.ulSaveSize);
    VBoxDPrintf("GRADD Ad/Mode: char: cx=%u cy=%u cTextRows=%u\n",
                (unsigned)g_VBoxAdapter.ModeInfo.bXCharSize,
                (unsigned)g_VBoxAdapter.ModeInfo.bYCharSize,
                (unsigned)g_VBoxAdapter.ModeInfo.usTextRows);
    VBoxDPrintf("GRADD Ad/Mode: bVrtRefresh=%u bHrtRefresh=%u bVrtPolPos=%u bHrtPolPos=%u\n",
                (unsigned)g_VBoxAdapter.ModeInfo.bVrtRefresh,
                (unsigned)g_VBoxAdapter.ModeInfo.bHrtRefresh,
                (unsigned)g_VBoxAdapter.ModeInfo.bVrtPolPos,
                (unsigned)g_VBoxAdapter.ModeInfo.bHrtPolPos);
    VBoxDPrintf("GRADD Ad/Mode: red=%uL%u green=%uL%u blue=%uL%u rsvd=%uL%u colors=%u rsvd=%x,%x,%x\n",
                (unsigned)g_VBoxAdapter.ModeInfo.bRedMaskSize,
                (unsigned)g_VBoxAdapter.ModeInfo.bRedFieldPosition,
                (unsigned)g_VBoxAdapter.ModeInfo.bGreenMaskSize,
                (unsigned)g_VBoxAdapter.ModeInfo.bGreenFieldPosition,
                (unsigned)g_VBoxAdapter.ModeInfo.bBlueMaskSize,
                (unsigned)g_VBoxAdapter.ModeInfo.bBlueFieldPosition,
                (unsigned)g_VBoxAdapter.ModeInfo.bRsvdMaskSize,
                (unsigned)g_VBoxAdapter.ModeInfo.bRsvdFieldPosition,
                (unsigned)g_VBoxAdapter.ModeInfo.ulColors,
                (unsigned)g_VBoxAdapter.ModeInfo.ulReserved[0],
                (unsigned)g_VBoxAdapter.ModeInfo.ulReserved[1],
                (unsigned)g_VBoxAdapter.ModeInfo.ulReserved[2]);
}

#endif /* LOG_ENABLED */


/*********************************************************************************************************************************
*   GHI_CMD_XXX Handlers.                                                                                                        *
*********************************************************************************************************************************/

/**
 * Helper that checks if we can use the host cursor or not.
 *
 * This will update g_fCursorSimulate.
 */
static BOOL vboxCanUseHostCursor(void)
{
    VMMDevReqMouseStatus Req = {0};
    int rc;
    BOOL fRet = FALSE;

    vmmdevInitRequest(&Req.header, VMMDevReq_GetMouseStatus);
    rc = VbglR3GRPerform(&Req.header);
    if (RT_SUCCESS(rc))
        fRet = !!(Req.mouseFeatures & VMMDEV_MOUSE_HOST_WANTS_ABSOLUTE);
    dprintf3(("GRADD GetMouseStatus: rc=%d/%d %x\n", rc, Req.header.rc, Req.mouseFeatures));

    if (!fRet)
        g_fCursorSimulate = TRUE;
    else
        g_fCursorSimulate = FALSE;
    return fRet;
}


/**
 * GHI_CMD_MOVEPTR
 */
static ULONG vboxHWMovePtr(PHWMOVEPTRIN pInput)
{
    if (!g_fCursorSimulate)
    {
        if (g_fCursorStatus & POINTER_VISIBLE)
        {
            /* We don't need to do anything, just check that we still can do hardware cursor. */
            /** @todo do we really need to do this that frequently?!?   */
            if (vboxCanUseHostCursor())
            {
                dprintf(("GRADD vboxHWMovePtr: host\n"));
                return RC_SUCCESS;
            }
        }
        else
        {
            dprintf(("GRADD vboxHWMovePtr: invisible\n"));
            return RC_SUCCESS;
        }
    }
    dprintf(("GRADD vboxHWMovePtr: RC_SIMULATE\n"));
    return RC_SIMULATE;
}


/**
 * GHI_CMD_SHOWPTR
 */
static ULONG vboxHWShowPtr(PHWSHOWPTRIN pInput)
{
    if (!g_fCursorSimulate)
    {
        if (vboxCanUseHostCursor())
        {
            VMMDevReqMousePointer *pReq = (VMMDevReqMousePointer *)g_abVBoxCursorData;
            int                    vrc;
            vmmdevInitRequest(&pReq->header, VMMDevReq_SetPointerShape);
            if (pInput->fShow)
                pReq->fFlags |= VBOX_MOUSE_POINTER_VISIBLE;
            else
                pReq->fFlags &= ~VBOX_MOUSE_POINTER_VISIBLE;
            vrc = VbglR3GRPerform(&pReq->header);
            if (RT_SUCCESS(vrc))
            {
                dprintf(("GRADD vboxHWShowPtr(%s): host\n", pInput->fShow ? "show" : "hide"));
                return RC_SUCCESS;
            }
            dprintf(("GRADD vboxHWShowPtr(%s): vrc=%d\n", pInput->fShow ? "show" : "hide", vrc));
        }
    }
    dprintf(("GRADD vboxHWShowPtr(%s): RC_SIMULATE\n", pInput->fShow ? "show" : "hide"));
    return RC_SIMULATE;
}


/**
 * GHI_CMD_SETPTR
 */
static ULONG vboxHWSetPtr(PHWSETPTRIN pInput, PHWSETPTROUT pOutput)
{
    /* Check max size and color. */
    /** @todo color cursors. */
    if (   pInput->ulWidth  <= VBOX_MAX_CURSOR_CX
        && pInput->ulHeight <= VBOX_MAX_CURSOR_CY
        && pInput->ulBpp    <= 1)
    {
        if (vboxCanUseHostCursor())
        {
            VMMDevReqMousePointer  *pReq         = (VMMDevReqMousePointer *)g_abVBoxCursorData;
            uint8_t                *pbCursorData = &pReq->pointerData[0];
            ULONG                   cbCursorData;
            int                     vrc;

            dprintf(("GRADD vboxHWSetPtr: (%d,%d) bpp=%d hotspot=(%d,%d)\n",
                     pInput->ulWidth, pInput->ulHeight, pInput->ulBpp, pInput->ptlHotspot.x, pInput->ptlHotspot.y));

            //Store AND mask (always 1bpp)
            cbCursorData = (pInput->ulWidth + 7) / 8 * pInput->ulHeight;
            memcpy(pbCursorData, pInput->pbANDMask, cbCursorData);
            pbCursorData += cbCursorData;

            /* align to next 4 byte boundary */
            pbCursorData = RT_ALIGN_P(pbCursorData, 4);

            //Append XOR (1bpp) or color data (>1bpp)
#if 0  /** @todo color cursor */
            if (pInput->ulBpp > 1)
            {
                int depth = (pInput->ulBpp == 15) ? 16 : pInput->ulBpp;

                /** @todo calc correct total lenght of req packet */
                cbCursorData = (pInput->ulWidth * pInput->ulHeight * depth)/8;

                dprintf(("Refused colour cursor!!\n"));
                return FALSE;
            }
            else
#endif
            {
                uint32_t *pu32CursorPixel = (uint32_t *)pbCursorData;
                uint32_t  ulScanLineWidth = ((pInput->ulWidth + 7) / 8) * 8;
                uint32_t  y, x;

                for (y = 0; y < pInput->ulHeight; y++)
                {
                    for (x = 0; x < pInput->ulWidth; x++)
                    {
                        if (VBoxBitTest(pInput->pbXORMask, y * ulScanLineWidth + (x / 8) * 8 + (7 - (x & 7))))
                        {
                            dprintf4(("1"));
                            *pu32CursorPixel = 0x00ffffff;
                        }
                        else
                        {
                            dprintf4(("0"));
                            *pu32CursorPixel = 0;
                        }
                        pu32CursorPixel++;
                    }
                    dprintf4(("\n"));
                }
                cbCursorData = (uint8_t *)pu32CursorPixel - (uint8_t *)g_abVBoxCursorData;
            }

            vmmdevInitRequest(&pReq->header, VMMDevReq_SetPointerShape);
            pReq->xHot   = pInput->ptlHotspot.x;
            pReq->yHot   = pInput->ptlHotspot.y;
            pReq->width  = pInput->ulWidth;
            pReq->height = pInput->ulHeight;
            pReq->fFlags |= VBOX_MOUSE_POINTER_SHAPE | VBOX_MOUSE_POINTER_VISIBLE;
            pReq->header.size = cbCursorData;
            vrc = VbglR3GRPerform(&pReq->header);
            if (RT_SUCCESS(vrc))
            {
                /* Update the status. */
                g_fCursorStatus &= ~(POINTER_SOFTWARE | POINTER_COLOR);
                if (pInput->ulBpp > 1)
                    g_fCursorStatus |= POINTER_COLOR;

                /* Return new status. */
                pOutput->ulStatus = g_fCursorStatus;
                dprintf(("GRADD vboxHWSetPtr: RC_SUCCESS - g_fCursorStatus=%#x\n", g_fCursorStatus));
                return RC_SUCCESS;
            }

            dprintf(("GRADD vboxHWSetPtr: VMMDevReq_SetPointerShape failed %d\n", vrc));
        }
    }
    else
        dprintf(("GRADD vboxHWSetPtr: refused (%d,%d) bpp=%d hotspot=(%d,%d)\n",
                 pInput->ulWidth, pInput->ulHeight, pInput->ulBpp, pInput->ptlHotspot.x, pInput->ptlHotspot.y));

    dprintf(("GRADD vboxHWSetPtr: RC_SIMULATE\n"));
    g_fCursorStatus = POINTER_SOFTWARE;
    return RC_SIMULATE;
}


/**
 * GHI_CMD_BANK - Bank management.
 */
static ULONG vboxHWBank(PHWBANKIN pInput, PHWBANKOUT pOutput)
{
    APIRET   rcApi;
    BANKDATA BankData;
    BankData.miBank = g_idVBoxCurMode;
    if (pInput->ulFlags == BANK_GET)
    {
        BankData.ulBank = 0;
        rcApi = VIDEOPMI32Request(&g_VBoxAdapter, PMIREQUEST_GETBANK, NULL, &BankData);
        dprintf(("GRADD vboxHWBank/GET: rcApi=%u ulBank=%u\n", rcApi, BankData.ulBank));
        if (rcApi == NO_ERROR)
        {
            pOutput->ulLength = sizeof(*pOutput);
            pOutput->ulBank   = BankData.ulBank;
            return RC_SUCCESS;
        }
    }
    else if (pInput->ulFlags == BANK_SET)
    {
        BankData.ulBank = pInput->ulBank;
        rcApi = VIDEOPMI32Request(&g_VBoxAdapter, PMIREQUEST_SETBANK, &BankData, NULL);
        dprintf(("GRADD vboxHWBank/SET: rcApi=%u ulBank=%u\n", rcApi, pInput->ulBank));
        if (rcApi == NO_ERROR)
            return RC_SUCCESS;
    }
    else
        dprintf(("GRADD vboxHWBank: Unknown request: %u\n", pInput->ulFlags));
    return RC_ERROR;
}


/**
 * GHI_CMD_PALETTE - Palette management.
 */
static ULONG vboxHWPalette(PHWPALETTEINFO pInput)
{
    struct
    {
        ULONG cEntriesAndFlags;
        ULONG idxStart;
        ULONG aData[256];
    } ColorLookupTable;
    ULONG const cEntries = pInput->ulNumEntries <= 256 ? pInput->ulNumEntries : 256;
    APIRET      rcApi;
    ULONG       i;

    /* Initialie common request data. */
    ColorLookupTable.cEntriesAndFlags = EIGHT_BIT_DAC | cEntries;
    ColorLookupTable.idxStart         = pInput->ulStartIndex;

    /*
     * PALETTE_GET
     */
    if (pInput->fFlags == PALETTE_GET)
    {
        for (i = 0; i < cEntries; i++)
            ColorLookupTable.aData[i] = 0;

        rcApi = VIDEOPMI32Request(&g_VBoxAdapter, PMIREQUEST_GETCLUT, NULL, &ColorLookupTable);
        dprintf(("GRADD vboxHWPalette/GETCLUT: %u\n", rcApi));
        if (rcApi == NO_ERROR)
        {
            PRGB2 pCurRgb = pInput->pRGBs;
            ULONG i;
            for (i = 0; i < cEntries; i++, pCurRgb++)
            {
                ULONG const uData = ColorLookupTable.aData[i];
                pCurRgb->fcOptions = 0;
                pCurRgb->bRed      =  uData        & 0xff;
                pCurRgb->bGreen    = (uData >>  8) & 0xff;
                pCurRgb->bBlue     = (uData >>  8) & 0xff;
            }

            /* paranoia: */
            for (; i < pInput->ulNumEntries; i++, pCurRgb++)
            {
                pCurRgb->fcOptions = 0;
                pCurRgb->bRed      = 0;
                pCurRgb->bGreen    = 0;
                pCurRgb->bBlue     = 0;
            }
            return RC_SUCCESS;
        }
    }
    /*
     * PALETTE_SET.
     */
    else if (pInput->fFlags == PALETTE_SET)
    {
        PRGB2 pCurRgb = pInput->pRGBs;
        for (i = 0; i < cEntries; i++, pCurRgb++)
            ColorLookupTable.aData[i] = (ULONG)pCurRgb->bRed
                                      | ((ULONG)pCurRgb->bGreen << 8)
                                      | ((ULONG)pCurRgb->bBlue << 24);
        rcApi = VIDEOPMI32Request(&g_VBoxAdapter, PMIREQUEST_SETCLUT, &ColorLookupTable, NULL);
        dprintf(("GRADD vboxHWPalette/SETCLUT: %u\n", rcApi));
        if (rcApi == NO_ERROR)
            return RC_SUCCESS;
    }
    else
        dprintf(("GRADD vboxHWPalette: Unknown request: %u\n", pInput->fFlags));
    /** @todo log errors */
    return RC_ERROR;
}


/**
 * GHI_CMD_SETMODE - set the video mode.
 *
 * @note Padding pidMode as a pointer, as someone could maybe assume it is a
 *       VIDEMODEINFO pointer.
 */
static ULONG vboxHWSetMode(PMODEID pidMode)
{
    /*
     * Check the mode.
     */
    MODEID const idMode = *pidMode;
    ULONG        i = 0;
    while (i < g_cVBoxVideoModes && g_paVBoxVideoModes[i].ulModeId != idMode)
        i++;
    if (i < g_cVBoxVideoModes)
    {
        /*
         * Make the change.
         */
        APIRET rcApi;
        dprintf(("GRADD vboxHWSetMode: idMode=%u i=%u\n", idMode, i));
        dprintf(("GRADD mode: cb=%x bpp=%u cx=%u cy=%u %uHz cbScan=%u (%x) fcc=%x VRAMPhys=%x cbAp=%x cbVRAM=%x cColors=%u\n",
                 g_paVBoxVideoModes[i].ulLength,
                 g_paVBoxVideoModes[i].ulBpp,
                 g_paVBoxVideoModes[i].ulHorizResolution,
                 g_paVBoxVideoModes[i].ulVertResolution,
                 g_paVBoxVideoModes[i].ulRefreshRate,
                 g_paVBoxVideoModes[i].ulScanLineSize,
                 g_paVBoxVideoModes[i].ulScanLineSize,
                 g_paVBoxVideoModes[i].fccColorEncoding,
                 g_paVBoxVideoModes[i].pbVRAMPhys,
                 g_paVBoxVideoModes[i].ulApertureSize,
                 g_paVBoxVideoModes[i].ulTotalVRAMSize,
                 g_paVBoxVideoModes[i].cColors));
#ifdef DEBUG
        VBoxDPrintfAdapter();
#endif
        rcApi = VIDEOPMI32Request(&g_VBoxAdapter, PMIREQUEST_UNLOCKREGISTERS, NULL, NULL);
        if (rcApi == NO_ERROR)
        {
#ifdef DEBUG
        VBoxDPrintfAdapter();
#endif
            rcApi = VIDEOPMI32Request(&g_VBoxAdapter, PMIREQUEST_SETMODE, pidMode, NULL /* No command list */);
            if (rcApi == NO_ERROR)
            {
                ULONG const PhysAperture = (ULONG)g_paVBoxVideoModes[i].pbVRAMPhys;
                ULONG const cbAperture   = g_paVBoxVideoModes[i].ulApertureSize;
                ULONG const cbVisibleFb  = g_paVBoxVideoModes[i].ulVertResolution
                                         * g_paVBoxVideoModes[i].ulHorizResolution /** @todo rounding? */
                                         * (g_paVBoxVideoModes[i].ulBpp >> 3);
                ULONG const cbMtrr       = RT_MIN(cbAperture, g_paVBoxVideoModes[i].ulTotalVRAMSize);
                ULONG       rc;

                /*
                 * Update globals.
                 */
                g_idxVBoxCurMode = i;
                g_idVBoxCurMode  = idMode;
                g_cbVRamAperture = cbAperture;
                g_cbVRamMtrr     = 0;
                g_PhysVRam       = PhysAperture;
                g_pbVRamR3Ptr    = NULL;
                g_pbVRamR0Ptr    = NULL;

                /*
                 * Map the VRAM and set MTRR WC for it, unless it is banked.
                 *
                 * The MTRR API has to be resolved dynamically for backwards
                 * compatiblity reasons.
                 */
                /** @todo why don't we limit the mapping to cbMtrr? */
                rc = VHMapVRAM((ULONG)g_paVBoxVideoModes[i].pbVRAMPhys, cbAperture, &g_pbVRamR3Ptr, &g_pbVRamR0Ptr);
                dprintf(("GRADD vboxHWSetMode: VHMapVRAM -> %u pbR3=%x pbR0=%x\n", rc, g_pbVRamR3Ptr, g_pbVRamR0Ptr));
                (void)rc; /** @todo check VHMapVRAM rc - everyone seems to ignore it... */

                if (cbVisibleFb <= cbMtrr)
                {
                    static PFNVHSETMTRR s_pfnVHSetMTRR = NULL;
                    PFNVHSETMTRR pfnVHSetMTRR = s_pfnVHSetMTRR;
                    if (!pfnVHSetMTRR)
                    {
                        HMODULE hMod = NULLHANDLE;
                        rcApi = DosLoadModule(NULL, 0, "VMAN", &hMod);
                        if (rc == NO_ERROR)
                        {
                            rc = DosQueryProcAddr(hMod, 0 /*ordinal*/, "VHSetMTRR", (PFN *)&pfnVHSetMTRR);
                            DosFreeModule(hMod); /* VMAN must already be loaded since we have several imports from it. */
                            s_pfnVHSetMTRR = pfnVHSetMTRR;
                        }
                    }
                    if (pfnVHSetMTRR)
                    {
                        MTRRIN Mtrr;
                        Mtrr.ulPhysAddr = (ULONG)g_paVBoxVideoModes[i].pbVRAMPhys;
                        rc = pfnVHSetMTRR(&Mtrr, TRUE);
                        dprintf(("GRADD vboxHWSetMode: VHSetMTRR -> %u (cbMtrr=%x)\n", rc, cbMtrr));
                        (void)rc; /** @todo check VHSetMTRR rc - everyone seems to ignore it... */

                        g_cbVRamMtrr = cbMtrr;
                    }
                }

                return RC_SUCCESS;
            }
            dprintf(("GRADD vboxHWSetMode: PMIREQUEST_SETMODE failed! %u\n", rcApi));
        }
        else
            dprintf(("GRADD vboxHWSetMode: PMIREQUEST_UNLOCKREGISTERS failed! %u\n", rcApi));
    }
    else
        dprintf(("GRADD vboxHWSetMode: idMode=%u not found!\n", idMode));
    return RC_ERROR;
}


/**
 * GHI_CMD_QUERYMODES - Mode data query.
 */
static ULONG vboxHWQueryModes(ULONG fQuery, PVOID pvOutput)
{
    switch (fQuery & QUERYMODE_VALID)
    {
        case QUERYMODE_NUM_MODES:
            *(PULONG)pvOutput = g_cVBoxVideoModes;
            return RC_SUCCESS;

        case QUERYMODE_MODE_DATA:
            memcpy(pvOutput, g_paVBoxVideoModes, g_cVBoxVideoModes * sizeof(g_paVBoxVideoModes[0]));
            return RC_SUCCESS;

        default:
            return RC_ERROR;
    }
}


/**
 * GHI_CMD_QUERYCAPS - Capability query.
 */
static ULONG vboxHWQueryCaps(PCAPSINFO pOutput)
{
    /* We only support DS_SIMPLE_LINES. */
    pOutput->ulLength           = sizeof(*pOutput);
    pOutput->pszFunctionClassID = BASE_FUNCTION_CLASS;
    pOutput->ulFCFlags          = DS_SIMPLE_LINES;
    return RC_SUCCESS;
}


/**
 * Helper used by vboxHWInitProc & vboxHWTermProc to update graphic
 * capabilities.
 *
 * @todo why do we do this per process?
 */
static BOOL vboxSetGraphicsCap(BOOL fEnable)
{
    VBGLIOCSETGUESTCAPS Info;
    int rc;

    VBGLREQHDR_INIT(&Info.Hdr, CHANGE_GUEST_CAPABILITIES);
    Info.u.In.fOrMask  = fEnable ? VMMDEV_GUEST_SUPPORTS_GRAPHICS : 0;
    Info.u.In.fNotMask = fEnable ? 0 : VMMDEV_GUEST_SUPPORTS_GRAPHICS;
    rc = vbglR3DoIOCtl(VBGL_IOCTL_CHANGE_GUEST_CAPABILITIES, &Info.Hdr, sizeof(Info));
    if (RT_SUCCESS(rc))
        rc = Info.Hdr.rc;
    if (RT_SUCCESS(rc))
        dprintf(("GRADD: Successfully changed guest capabilities: fEnable=%d\n", fEnable));
    else
        dprintf(("GRADD: Failed to change guest capabilities: fEnable=%d - rc = %d.\n", fEnable, rc));
    return RT_SUCCESS(rc);
}


/**
 * GHI_CMD_TERMPROC - Per process termination.
 */
static ULONG vboxHWTermProc(void)
{
    vboxSetGraphicsCap(FALSE);

    if (g_hVBoxDrv != NULLHANDLE)
    {
        dprintf(("GRADD vboxHWTermProc: closing VBoxGuest fd=%d\n", g_hVBoxDrv));
        DosClose(g_hVBoxDrv);
    }
    g_hVBoxDrv = NULLHANDLE;
    return RC_SUCCESS;
}


/**
 * GHI_CMD_INITPROC - Per process init.
 */
static ULONG vboxHWInitProc(PINITPROCOUT pOutput)
{
   pOutput->ulLength  = sizeof(INITPROCOUT);
   pOutput->ulVRAMVirt = (ULONG)g_pbVRamR3Ptr;

    vboxOpenDriver();
    vboxSetGraphicsCap(TRUE);
/** @todo log error, but don't fail */

   return RC_SUCCESS;
}


/**
 * Helper for vboxHWInit that get the mode data.
 *
 * Caller have to call VHFreeMem on *ppaModes when done.
 */
static APIRET vboxPmiHlpGetModeData(PVIDEOMODEINFO *ppaModes, ULONG *pcModes)
{
    /* Get the table size first. */
    ULONG  cModes = 0;
    APIRET rc = VIDEOPMI32Request(&g_VBoxAdapter, PMIREQUEST_QUERYMAXMODEENTRIES, NULL, &cModes);
    if (rc == NO_ERROR)
    {
        /* Allocate memory. */
        PVIDEOMODEINFO const paModes = (PVIDEOMODEINFO)VHAllocMem(cModes * sizeof(paModes[0]));
        if (paModes)
        {
            /* Query the mode data. */
            rc = VIDEOPMI32Request(&g_VBoxAdapter, PMIREQUEST_QUERYMODEINFODATA, NULL, paModes);
            if (rc == NO_ERROR)
            {
                *pcModes = cModes;
                *ppaModes = paModes;
                return NO_ERROR;
            }
        }
        else
            rc = ERROR_NOT_ENOUGH_MEMORY;
    }
    *ppaModes = NULL;
    *pcModes  = 0;
    return rc;
}


/**
 * Mode info translation helper for vboxHWInit.
 */
static void vboxTranslateVmiModeToGdd(VIDEOMODEINFO const *pSrc, PGDDMODEINFO pDst, ULONG cbTotalVRam)
{
    pDst->ulLength              = sizeof(*pDst);
    pDst->ulModeId              = pSrc->miModeId;
    if (pSrc->usType & MODE_FLAG_LINEAR_BUFFER)
        pDst->ulModeId         |= SET_LINEAR_BUFFER_MODE;
    pDst->ulBpp                 = pSrc->bBitsPerPixel;
    pDst->ulHorizResolution     = pSrc->usXResolution;
    pDst->ulVertResolution      = pSrc->usYResolution;
    pDst->ulRefreshRate         = pSrc->bVrtRefresh;
    pDst->pbVRAMPhys            = (PBYTE)pSrc->ulBufferAddress;
    pDst->ulApertureSize        = pSrc->ulApertureSize;
    pDst->ulScanLineSize        = pSrc->usBytesPerScanLine;
    switch (pSrc->bBitsPerPixel)
    {
        case  8: pDst->fccColorEncoding =                                                        FOURCC_LUT8; break;
        case 16: pDst->fccColorEncoding = pSrc->bRsvdMaskSize == 0               ? FOURCC_R565 : FOURCC_R555; break;
        case 24: pDst->fccColorEncoding = !(pSrc->usType & MODE_FLAG_DIRECT_BGR) ? FOURCC_BGR3 : FOURCC_RGB3; break;
        case 32: pDst->fccColorEncoding = !(pSrc->usType & MODE_FLAG_DIRECT_BGR) ? FOURCC_BGR4 : FOURCC_RGB4; break;
        default: pDst->fccColorEncoding = 0; /* !IMPOSSIBLE!*/ break;
    }
    pDst->cColors               = pSrc->ulColors;
    pDst->ulTotalVRAMSize       = cbTotalVRam;
}


/**
 * Mode selection helper for vboxHWInit.
 */
static BOOL vboxShouldIncludeVmiMode(VIDEOMODEINFO const *pMode, ULONG cbTotalVRam)
{
    if ((pMode->usType & (MODE_FLAG_GRAPHICS | MODE_FLAG_VGA_ENTRY)) != MODE_FLAG_GRAPHICS)
        return FALSE;
    if ((ULONG)pMode->usBytesPerScanLine * pMode->usYResolution > cbTotalVRam)
        return FALSE;
    if (pMode->bBitsPerPixel == 8)
        return TRUE;
    if (pMode->bBitsPerPixel == 16)
        return TRUE;
    if (pMode->bBitsPerPixel == 24)
        return TRUE;
    if (pMode->bBitsPerPixel == 32)
        return TRUE;
    return FALSE;
}


/**
 * GHI_CMD_INIT - Global one time init.
 */
static ULONG vboxHWInit(GID gid, PGDDINITIN pInput, PGDDINITOUT pOutput)
{
    APIRET rcApi;
    ULONG cbToLock;
    RT_NOREF_PV(pInput);

    /*
     * Check that it's hardware we know...
     */
    /** @todo check for VBox graphics device.   */

    /*
     * Lock segments.
     */
    // Data (making it writable, apparently).
    cbToLock = (ULONG)&g_EndOfData[0] - (ULONG)&g_StartOfData[0];
    g_rcLockData   = VHLockMem(&g_StartOfData[0], cbToLock, TRUE /*fData*/);
    g_cbData       = cbToLock;  // Data is Read-Only until after the call

    // Enable interrupt cursor via lock
    g_cbCode = cbToLock = (ULONG)&StartOfCode - (ULONG)&StartOfCode;
    g_rcLockCode = VHLockMem((PVOID)&StartOfCode, cbToLock, FALSE /*fData*/);

    /*
     * Save our ID and use it for checking subsequent calls.
     */
    g_gidVBox = gid;

    /*
     * Try load the PMI and presumably initalize our adapter structure.
     * Then process and save display mode data.
     */
    rcApi = VIDEOPMI32Request(&g_VBoxAdapter, PMIREQUEST_LOADPMIFILE, "\\OS2\\SVGADATA.PMI", NULL);
    if (rcApi == NO_ERROR)
    {
        /* Load the raw info from the pmi file. */
        PVIDEOMODEINFO  paVmiModes = NULL;
        ULONG           cVmiModes  = 0;
        rcApi = vboxPmiHlpGetModeData(&paVmiModes, &cVmiModes);
        if (rcApi == NO_ERROR)
        {
            ULONG const  cbTotalVRam = g_VBoxAdapter.Adapter.ulTotalMemory;
            ULONG        cGddModes   = 0;
            PGDDMODEINFO paGddModes;
            ULONG        i;

            /* Count the modes we can use. */
            for (i = 0; i < cVmiModes; i++)
                if (vboxShouldIncludeVmiMode(&paVmiModes[i], cbTotalVRam))
                    cGddModes++;

            /* Allocate memory for the modes. */
            paGddModes = (PGDDMODEINFO)VHAllocMem(cGddModes * sizeof(paGddModes[0]));
            if (paGddModes)
            {
                /* Transfer the mode info. */
                ULONG iGdd;
                for (iGdd = i = 0; i < cVmiModes; i++)
                    if (vboxShouldIncludeVmiMode(&paVmiModes[i], cbTotalVRam))
                        vboxTranslateVmiModeToGdd(&paVmiModes[i], &paGddModes[iGdd++], cbTotalVRam);
                VHFreeMem(paVmiModes);

                /* Install them. */
                g_paVBoxVideoModes = paGddModes;
                g_cVBoxVideoModes  = cGddModes;

                /*
                 * Successfully initialized.
                 */
                if (pOutput->ulLength >= sizeof(*pOutput))
                    pOutput->cFunctionClasses = 1;
                return RC_SUCCESS;
            }
            VHFreeMem(paVmiModes);
        }
    }

    /** @todo do we need to do any cleanup?   */
    g_gidVBox = ~(GID)0;
    return RC_ERROR;
}


/**
 * Primary entry point.
 */
ULONG EXPENTRY
HWEntry(GID gid, ULONG ulGhiCmd, PVOID pvInput, PVOID pvOutput)
{
    ULONG rc;
#ifdef LOG_ENABLED
    if (g_uDbgLevel >= 2)
    {
        PTIB pTib = NULL;
        PPIB pPib = NULL;
        rc = VBoxGetCpl();
        if (rc == 3)
            DosGetInfoBlocks(&pTib, &pPib);
        dprintf(("GRADD HWEntry: pid=%u tid=%u ring-%u gid=%x cmd=%x/%s\n", pPib ? pPib->pib_ulpid : -1,
                 pTib ? pTib->tib_ordinal : -1, rc, gid, ulGhiCmd, VBoxNameGhiCmd(ulGhiCmd) ));
    }
#endif

    /*
     * Validate gid and handle the requests.
     */
    if (gid == g_gidVBox || ulGhiCmd == GHI_CMD_INIT)
    {
        switch (ulGhiCmd)
        {
            /*
             * One time init/term.
             */
            case GHI_CMD_INIT:
                rc = vboxHWInit(gid, (PGDDINITIN)pvInput, (PGDDINITOUT)pvOutput);
                break;
            case GHI_CMD_TERM:
                rc = RC_UNSUPPORTED;
                break;

            /*
             * Per process init/term.
             */
            case GHI_CMD_INITPROC:
                rc = vboxHWInitProc((PINITPROCOUT)pvOutput);
                break;
            case GHI_CMD_TERMPROC:
                rc = vboxHWTermProc();
                break;

            /*
             * Capabilities and mode managment.
             */
            case GHI_CMD_QUERYCAPS:
                rc = vboxHWQueryCaps((PCAPSINFO)pvOutput);
                break;
            case GHI_CMD_QUERYMODES:
                if (pvInput)
                    rc = vboxHWQueryModes(*(ULONG const *)pvInput, pvOutput);
                else
                    rc = RC_ERROR;
                break;
            case GHI_CMD_SETMODE:
                rc = vboxHWSetMode((PMODEID)pvInput);
                break;
            case GHI_CMD_PALETTE:
                if (pvInput)
                    rc = vboxHWPalette((PHWPALETTEINFO)pvInput);
                else
                    rc = RC_ERROR;
                break;
            case GHI_CMD_BANK:
                rc = vboxHWBank((PHWBANKIN)pvInput, (PHWBANKOUT)pvOutput);
                break;

            /*
             * Hardware blitting and line drawing.
             */
            case GHI_CMD_BITBLT:
                rc = RC_SIMULATE;
                break;
            case GHI_CMD_LINE:
                rc = RC_SIMULATE;
                break;
            case GHI_CMD_POLYGON:
                rc = RC_SIMULATE;
                break;

            /*
             * Cursor managment.
             */
            case GHI_CMD_SETPTR:
                rc = vboxHWSetPtr((PHWSETPTRIN)pvInput, (PHWSETPTROUT)pvOutput);
                break;
            case GHI_CMD_MOVEPTR:
                rc = vboxHWMovePtr((PHWMOVEPTRIN)pvInput);
                break;
            case GHI_CMD_SHOWPTR:
                rc = vboxHWShowPtr((PHWSHOWPTRIN)pvInput);
                break;

            case GHI_CMD_VRAM:
                rc = RC_UNSUPPORTED;
                break;
            case GHI_CMD_REQUESTHW:
                rc = RC_SUCCESS;
                break;
            case GHI_CMD_EVENT:
                rc = RC_UNSUPPORTED;
                break;
            case GHI_CMD_EXTENSION:
                rc = RC_UNSUPPORTED;
                break;

            case GHI_CMD_TEXT:
                rc = RC_UNSUPPORTED;
                break;
            case GHI_CMD_USERCAPS:
                rc = RC_UNSUPPORTED;
                break;
            default:
                rc = RC_ERROR;
                break;
        }
    }
    else
        rc = RC_ERROR;

    dprintf2(("GRADD HWEntry: returns %d (gid=%x cmd=%x)\n", rc, gid, ulGhiCmd));
    return rc;
}

