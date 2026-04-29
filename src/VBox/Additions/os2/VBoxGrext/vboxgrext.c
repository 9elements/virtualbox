/* $Id: vboxgrext.c 114044 2026-04-29 08:38:05Z knut.osmundsen@oracle.com $ */
/** @file
 * VBoxGrExt - GRADD Extension.
 *
 * This overrides EN_QUERY_DEV_SURFACE font sizes and some of the queries via
 * GreQueryDevResource2/RT_DISPLAYINFO.
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
#define INCL_DOS
#define INCL_DOSERRORS
#define INCL_GRE_DEVICE
#define INCL_WIN
#define INCL_GPI
#include <os2.h>

#define INCL_VMANDDI
#define VMANDDI_INCLUDED
#include <gradd.h>
#include <pmddi.h>

/*
 * Internal GRE/PM/whatever stuff w/o headers:
 */
#define EN_FILL_LDB             1       /**< DRV_ENABLE subfunction for filling LDBs. */
#define EN_QUERY_DEV_SURFACE    14      /**< DRV_ENABLE subfunction for query device surface info. */

#define GRE_QUERY_DEV_RESOURCE  0xd4    /**< Function table entry for GreQueryDevResource2 (see NGreQueryDevResource2). */

/** EN_FILL_LDB parameter 1. */
typedef struct
{
    ULONG   Version;
    USHORT  TableSize;                  /**< Number of entries in FLReturnsLst::DispTab. */
} FLParamsLst, *pFLParamsLst;

/** EN_FILL_LDB parameter 2. */
typedef struct
{
    PUSHORT Flags;
    PFN    *DispTab;
} FLReturnsLst, *pFLReturnsLst;


/*********************************************************************************************************************************
*   Defined Constants And Macros                                                                                                 *
*********************************************************************************************************************************/
/** Enables loading settings from the INI_APP profile. */
#define GUI_SIZE_SELECT

/** The profile to load GUI settings from. */
#define INI_APP         "OS2 Additions"

/* FontSize values */
#define FONT_SMALL      0
#define FONT_MEDIUM     1
#define FONT_LARGE      2

/* IconSize values / icon IDs in RESOURCE_DLL */
#define HI_RES_ICON_ID  1
#define LO_RES_ICON_ID  2

#define RESOURCE_DLL    "dspres"


/*********************************************************************************************************************************
*   Structures and Typedefs                                                                                                      *
*********************************************************************************************************************************/
typedef APIRET APIENTRY FNQUERYDEVRESOURCE(HDC, ULONG, ULONG, void *, ULONG);
typedef FNQUERYDEVRESOURCE *PFNQUERYDEVRESOURCE;

typedef LONG EXPENTRY FNOS2PMDRVENABLE(ULONG subfunc, PVOID param1, PVOID param2);
typedef FNOS2PMDRVENABLE *PFNOS2PMDRVENABLE;


/*********************************************************************************************************************************
*   Global Variables                                                                                                             *
*********************************************************************************************************************************/
/** Pointer to the original OS2_PM_DRV_ENABLE function. */
PFNOS2PMDRVENABLE   g_pfnOrgDrvEnable = NULL;
/** Pointer to the original QueryDevResource function. */
PFNQUERYDEVRESOURCE g_pfnOrgQueryDevResource = NULL;

/** HI_RES_ICON_ID, LO_RES_ICON_ID or -1. */
int g_idResIconSize = -1;
/** FONT_SMALL, FONT_MEDIUM, FONT_LARGE or -1. */
int g_iFontSize = -1;
/** The font DPI (120, 96, -1, ...). */
int g_iFontDPI = -1;


/*
 * Hook function.
 */
static APIRET APIENTRY vbox_QueryDevResource(HDC hdc, ULONG ArgTypeID, ULONG ArgNameID, void *pdcArg, ULONG FunN)
{
    // upon requests for DisplayInfo, return the desired icon size
    // resource ID 1 is 40x40 and ID 2 is 32x32
    if (ArgTypeID == RT_DISPLAYINFO && g_idResIconSize != -1)
    {
        CHAR achFailName[128];
        HMODULE hModule = NULLHANDLE;

        if (DosLoadModule(achFailName, sizeof(achFailName), RESOURCE_DLL, &hModule) == NO_ERROR)
        {
            PVOID pvAddress = NULL;
            if (DosGetResource(hModule, ArgTypeID, g_idResIconSize, &pvAddress) == NO_ERROR)
            {
                DosFreeModule(hModule);
                return (ULONG)pvAddress;
            }
            DosFreeModule(hModule);
        }
    }

    // fall through to default handler
    return g_pfnOrgQueryDevResource(hdc, ArgTypeID, ArgNameID, pdcArg, FunN);
}


/**
 * Hook function.
 */
LONG EXPENTRY OS2_PM_DRV_ENABLE(ULONG subfunc, PVOID param1, PVOID param2)
{
    // call into original entry point first
    LONG rc = g_pfnOrgDrvEnable(subfunc, param1, param2);

    // check which function is being called
    switch (subfunc)
    {
        case EN_QUERY_DEV_SURFACE:
        {
            if (param1)
            {
                PDEVICESURFACE pDS = (PDEVICESURFACE)param1;

                if (g_iFontSize == FONT_SMALL)
                {
                    pDS->DevCaps[CAPS_CHAR_WIDTH]           =  8;
                    pDS->DevCaps[CAPS_CHAR_HEIGHT]          = 14;
                    pDS->DevCaps[CAPS_SMALL_CHAR_WIDTH]     =  8;
                    pDS->DevCaps[CAPS_SMALL_CHAR_HEIGHT]    =  8;
                    pDS->DevCaps[CAPS_GRAPHICS_CHAR_WIDTH]  = 13;
                    pDS->DevCaps[CAPS_GRAPHICS_CHAR_HEIGHT] = 13;
                }
                else if (g_iFontSize == FONT_MEDIUM)
                {
                    pDS->DevCaps[CAPS_CHAR_WIDTH]           = 12;
                    pDS->DevCaps[CAPS_CHAR_HEIGHT]          = 22;
                    pDS->DevCaps[CAPS_SMALL_CHAR_WIDTH]     =  8;
                    pDS->DevCaps[CAPS_SMALL_CHAR_HEIGHT]    =  8;
                    pDS->DevCaps[CAPS_GRAPHICS_CHAR_WIDTH]  = 16;
                    pDS->DevCaps[CAPS_GRAPHICS_CHAR_HEIGHT] = 16;

                }
                else if (g_iFontSize == FONT_LARGE)
                {
                    pDS->DevCaps[CAPS_CHAR_WIDTH]           = 12;
                    pDS->DevCaps[CAPS_CHAR_HEIGHT]          = 22;
                    pDS->DevCaps[CAPS_SMALL_CHAR_WIDTH]     =  8;
                    pDS->DevCaps[CAPS_SMALL_CHAR_HEIGHT]    = 14;
                    pDS->DevCaps[CAPS_GRAPHICS_CHAR_WIDTH]  = 20;
                    pDS->DevCaps[CAPS_GRAPHICS_CHAR_HEIGHT] = 20;

                }

                if (g_iFontDPI != -1)
                {
                    pDS->DevCaps[CAPS_HORIZONTAL_FONT_RES]  = g_iFontDPI;
                    pDS->DevCaps[CAPS_VERTICAL_FONT_RES]    = g_iFontDPI;
                }

                pDS->DevCaps[CAPS_WIDTH_IN_CHARS]  = pDS->DevCaps[CAPS_WIDTH]  / pDS->DevCaps[CAPS_CHAR_WIDTH];
                pDS->DevCaps[CAPS_HEIGHT_IN_CHARS] = pDS->DevCaps[CAPS_HEIGHT] / pDS->DevCaps[CAPS_CHAR_HEIGHT];
            }
            break;
        }

        case EN_FILL_LDB:
        {
            if (param1 && param2 && !g_pfnOrgQueryDevResource)
            {
                // replace GreQueryDevResource with ours
                pFLParamsLst  pFLPL = (pFLParamsLst)param1;
                if (GRE_QUERY_DEV_RESOURCE < pFLPL->TableSize)
                {
                    pFLReturnsLst pFLRL = (pFLReturnsLst)param2;
                    g_pfnOrgQueryDevResource = (PFNQUERYDEVRESOURCE)pFLRL->DispTab[GRE_QUERY_DEV_RESOURCE];
                    pFLRL->DispTab[GRE_QUERY_DEV_RESOURCE] = (PFN)vbox_QueryDevResource;
                }
            }
            break;
        }
    }
    return rc;
}


/** Simple stricmp replacement. */
static int MyStrICmp(const char *psz1, const char *psz2)
{
    for (;;)
    {
        char ch1 = *psz1++;
        char ch2 = *psz2++;
        if (ch1 != ch2)
        {
            ch1 = ch1 >= 'A' && ch1 <= 'Z' ? ch1 + ('a' - 'A') : ch1;
            ch2 = ch2 >= 'A' && ch2 <= 'Z' ? ch2 + ('a' - 'A') : ch2;
            if (ch1 != ch2)
                return ch1 < ch2 ? -1 : 1;
        }
        if (!ch1)
            return 0;
    }
}


/** Simple atoi replacement. */
static int MyAToI(const char *psz)
{
    int iValue = 0;
    char ch;
    while ((ch = *psz) == ' ' || ch == '\t' || ch == '\n' || ch == '\r')
        psz++;
    if (ch == '0' && (psz[1] == 'x' || psz[1] == 'X'))
    {
        psz += 2;
        for (;;)
        {
            ch = *psz;
            if (ch >= '0' && ch <= '9')
                iValue = (iValue << 4) + (ch - '0');
            else if (ch >= 'A' && ch <= 'F')
                iValue = (iValue << 4) + (ch - 'A' + 10);
            else if (ch >= 'a' && ch <= 'f')
                iValue = (iValue << 4) + (ch - 'a' + 10);
            else
                break;
        }
    }
    else
        for (;;)
        {
            ch = *psz;
            if (ch >= '0' && ch <= '9')
                iValue = iValue * 10 + (ch - '0');
            else
                break;
        }
    return iValue;
}


// exported function
LONG EXPENTRY OS2_PM_DRV_GREHOOK(PFN *OS2_PM_DRV, ULONG TableSize)
{
    static BOOL s_fHooked = FALSE;
    PSZ env;
#ifdef GUI_SIZE_SELECT
    ULONG ulValue;
    ULONG ulBufferMax;
    BOOL rc;
#endif

    /*
     * Make sure we only hook the entry point once.
     */
    if (s_fHooked)
        return 0;
    s_fHooked = TRUE;

    /*
     * Query the settings from the environment first.
     */
    // determine font size
    if (DosScanEnv("VBOXFONTSIZE", &env) == NO_ERROR)
    {
        if (MyStrICmp(env, "medium") == 0)
            g_iFontSize = FONT_MEDIUM;
        else if (MyStrICmp(env, "large") == 0)
            g_iFontSize = FONT_LARGE;
        else if (MyStrICmp(env, "small") == 0)
            g_iFontSize = FONT_SMALL;
    }

    // determine font dpi value
    if (DosScanEnv("VBOXFONTDPI", &env) == NO_ERROR)
    {
        int iValue = MyAToI(env);
        if (iValue == 120 || iValue == 96)
            g_iFontDPI = iValue;
    }

    // determine icon size
    if (DosScanEnv("VBOXICONS", &env) == NO_ERROR)
    {
        if (MyStrICmp(env, "large") == 0)
            g_idResIconSize = HI_RES_ICON_ID;
        else if (MyStrICmp(env, "small") == 0)
            g_idResIconSize = LO_RES_ICON_ID;
    }

#ifdef GUI_SIZE_SELECT
    /*
     * Query settings from the application profile.
     */
    // determine font size
    ulValue = 0;
    ulBufferMax = sizeof(ulValue);
    rc = PrfQueryProfileData(HINI_PROFILE, INI_APP,
                             "FontSize",
                             &ulValue, &ulBufferMax);
    if (rc == TRUE)
        g_iFontSize = ulValue;

    // determine font dpi value
    ulValue = 0;
    ulBufferMax = sizeof(ulValue);
    rc = PrfQueryProfileData(HINI_PROFILE, INI_APP,
                             "FontDPI",
                             &ulValue, &ulBufferMax);
    if (rc == TRUE)
        g_iFontDPI = ulValue;

    // determine icon size
    ulValue = 0;
    ulBufferMax = sizeof(ulValue);
    rc = PrfQueryProfileData(HINI_PROFILE, INI_APP,
                             "IconSize",
                             &ulValue, &ulBufferMax);
    if (rc == TRUE)
        g_idResIconSize = ulValue;
#endif

    /*
     * Install the hook.
     */
    // save the original entry point
    g_pfnOrgDrvEnable = (PFNOS2PMDRVENABLE)OS2_PM_DRV[0];

    // hook replacement entry point
    OS2_PM_DRV[0] = (PFN)OS2_PM_DRV_ENABLE;

    return 0;
}
