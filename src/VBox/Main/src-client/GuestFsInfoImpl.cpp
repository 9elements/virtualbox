/* $Id: GuestFsInfoImpl.cpp 114011 2026-04-24 10:14:36Z andreas.loeffler@oracle.com $ */
/** @file
 * VirtualBox Main - Guest file system information handling.
 */

/*
 * Copyright (C) 2023-2026 Oracle and/or its affiliates.
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
#define LOG_GROUP LOG_GROUP_MAIN_GUESTFSINFO
#include "LoggingNew.h"

#ifndef VBOX_WITH_GUEST_CONTROL
# error "VBOX_WITH_GUEST_CONTROL must defined in this file"
#endif
#include "GuestFsInfoImpl.h"
#include "GuestCtrlImplPrivate.h"

#include "Global.h"
#include "AutoCaller.h"

#include <VBox/com/array.h>



// constructor / destructor
/////////////////////////////////////////////////////////////////////////////

DEFINE_EMPTY_CTOR_DTOR(GuestFsInfo)

/**
 * Called by the COM class factory after construction.
 *
 * @returns COM status code.
 */
HRESULT GuestFsInfo::FinalConstruct(void)
{
    LogFlowThisFuncEnter();
    return BaseFinalConstruct();
}

/**
 * Called by the COM runtime before object destruction.
 */
void GuestFsInfo::FinalRelease(void)
{
    LogFlowThisFuncEnter();
    uninit();
    BaseFinalRelease();
    LogFlowThisFuncLeave();
}

// public initializer/uninitializer for internal purposes only
/////////////////////////////////////////////////////////////////////////////

/**
 * Initializes this guest file system information object.
 *
 * @returns VBox status code.
 * @param   pFsInfo             Pointer to the source file system information.
 */
int GuestFsInfo::init(PCGSTCTLFSINFO pFsInfo)
{
    AssertPtrReturn(pFsInfo, VERR_INVALID_POINTER);

    LogFlowThisFuncEnter();

    /* Enclose the state transition NotReady->InInit->Ready. */
    AutoInitSpan autoInitSpan(this);
    AssertReturn(autoInitSpan.isOk(), VERR_OBJECT_DESTROYED);

    mData = *pFsInfo;

    /* Confirm a successful initialization when it's the case. */
    autoInitSpan.setSucceeded();

    return VINF_SUCCESS;
}

/**
 * Uninitializes the instance.
 * Called from FinalRelease().
 */
void GuestFsInfo::uninit(void)
{
    /* Enclose the state transition Ready->InUninit->NotReady. */
    AutoUninitSpan autoUninitSpan(this);
    if (autoUninitSpan.uninitDone())
        return;

    LogFlowThisFuncEnter();
}

// implementation of wrapped private getters/setters for attributes
/////////////////////////////////////////////////////////////////////////////

/**
 * Returns the free size of the guest file system.
 *
 * @returns COM status code.
 * @param   aFreeSize           Where to return the free size in bytes.
 */
HRESULT GuestFsInfo::getFreeSize(LONG64 *aFreeSize)
{
    *aFreeSize = mData.cbFree;
    return S_OK;
}

/**
 * Returns the total size of the guest file system.
 *
 * @returns COM status code.
 * @param   aTotalSize          Where to return the total size in bytes.
 */
HRESULT GuestFsInfo::getTotalSize(LONG64 *aTotalSize)
{
    *aTotalSize = mData.cbTotalSize;
    return S_OK;
}

/**
 * Returns the file system block size.
 *
 * @returns COM status code.
 * @param   aBlockSize          Where to return the block size in bytes.
 */
HRESULT GuestFsInfo::getBlockSize(ULONG *aBlockSize)
{
    *aBlockSize = mData.cbBlockSize;
    return S_OK;
}

/**
 * Returns the physical sector size.
 *
 * @returns COM status code.
 * @param   aSectorSize         Where to return the sector size in bytes.
 */
HRESULT GuestFsInfo::getSectorSize(ULONG *aSectorSize)
{
    *aSectorSize = mData.cbSectorSize;
    return S_OK;
}

/**
 * Returns the file system serial number.
 *
 * @returns COM status code.
 * @param   aSerialNumber       Where to return the serial number.
 */
HRESULT GuestFsInfo::getSerialNumber(ULONG *aSerialNumber)
{
    *aSerialNumber = mData.uSerialNumber;
    return S_OK;
}

/**
 * Returns whether the file system is remote.
 *
 * @returns COM status code.
 * @param   aIsRemote           Where to return whether the file system is remote.
 */
HRESULT GuestFsInfo::getIsRemote(BOOL *aIsRemote)
{
    *aIsRemote = mData.fFlags & GSTCTLFSINFO_F_IS_REMOTE;
    return S_OK;
}

/**
 * Returns whether the file system is case-sensitive.
 *
 * @returns COM status code.
 * @param   aIsCaseSensitive    Where to return the case-sensitivity flag.
 */
HRESULT GuestFsInfo::getIsCaseSensitive(BOOL *aIsCaseSensitive)
{
    *aIsCaseSensitive = mData.fFlags & GSTCTLFSINFO_F_IS_CASE_SENSITIVE;
    return S_OK;
}

/**
 * Returns whether the file system is read-only.
 *
 * @returns COM status code.
 * @param   aIsReadOnly         Where to return the read-only flag.
 */
HRESULT GuestFsInfo::getIsReadOnly(BOOL *aIsReadOnly)
{
    *aIsReadOnly = mData.fFlags & GSTCTLFSINFO_F_IS_READ_ONLY;
    return S_OK;
}

/**
 * Returns whether the file system itself is compressed.
 *
 * @returns COM status code.
 * @param   aIsCompressed       Where to return the compression flag.
 */
HRESULT GuestFsInfo::getIsCompressed(BOOL *aIsCompressed)
{
    *aIsCompressed = mData.fFlags & GSTCTLFSINFO_F_IS_COMPRESSED;
    return S_OK;
}

/**
 * Returns whether per-file compression is supported by this file system.
 *
 * @returns COM status code.
 * @param   aSupportsFileCompression  Where to return the feature support flag.
 */
HRESULT GuestFsInfo::getSupportsFileCompression(BOOL *aSupportsFileCompression)
{
    *aSupportsFileCompression = mData.fFeatures & GSTCTLFSINFO_FEATURE_F_FILE_COMPRESSION;
    return S_OK;
}

/**
 * Returns the maximum length of a single path component.
 *
 * @returns COM status code.
 * @param   aMaxComponent       Where to return the maximum component length.
 */
HRESULT GuestFsInfo::getMaxComponent(ULONG *aMaxComponent)
{
    *aMaxComponent = mData.cMaxComponent;
    return S_OK;
}

/**
 * Returns the file system type name.
 *
 * @returns COM status code.
 * @param   aType               Where to return the UTF-8 file system type name.
 */
HRESULT GuestFsInfo::getType(com::Utf8Str &aType)
{
    aType = mData.szName;
    return S_OK;
}

/**
 * Returns the file system label.
 *
 * @returns COM status code.
 * @param   aLabel              Where to return the UTF-8 file system label.
 */
HRESULT GuestFsInfo::getLabel(com::Utf8Str &aLabel)
{
    aLabel = mData.szLabel;
    return S_OK;
}

/**
 * Returns the file system mount point.
 *
 * @returns COM status code.
 * @param   aMountPoint         Where to return the UTF-8 mount point.
 */
HRESULT GuestFsInfo::getMountPoint(com::Utf8Str &aMountPoint)
{
    /* The mount point string is optional and only valid if the reported length is non-zero. */
    if (mData.cbMountpoint)
        aMountPoint.assignEx(mData.szMountpoint, mData.cbMountpoint);
    return S_OK;
}


