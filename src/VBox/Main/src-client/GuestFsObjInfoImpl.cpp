/* $Id: GuestFsObjInfoImpl.cpp 114011 2026-04-24 10:14:36Z andreas.loeffler@oracle.com $ */
/** @file
 * VirtualBox Main - Guest file system object information handling.
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


/*********************************************************************************************************************************
*   Header Files                                                                                                                 *
*********************************************************************************************************************************/
#define LOG_GROUP LOG_GROUP_MAIN_GUESTFSOBJINFO
#include "LoggingNew.h"

#ifndef VBOX_WITH_GUEST_CONTROL
# error "VBOX_WITH_GUEST_CONTROL must defined in this file"
#endif
#include "GuestFsObjInfoImpl.h"
#include "GuestCtrlImplPrivate.h"

#include "Global.h"
#include "AutoCaller.h"

#include <VBox/com/array.h>



// constructor / destructor
/////////////////////////////////////////////////////////////////////////////

DEFINE_EMPTY_CTOR_DTOR(GuestFsObjInfo)

/**
 * Called by the COM class factory after construction.
 *
 * @returns COM status code.
 */
HRESULT GuestFsObjInfo::FinalConstruct(void)
{
    LogFlowThisFuncEnter();
    return BaseFinalConstruct();
}

/**
 * Called by the COM runtime before object destruction.
 */
void GuestFsObjInfo::FinalRelease(void)
{
    LogFlowThisFuncEnter();
    uninit();
    BaseFinalRelease();
    LogFlowThisFuncLeave();
}

// public initializer/uninitializer for internal purposes only
/////////////////////////////////////////////////////////////////////////////

/**
 * Initializes this guest file system object information instance.
 *
 * @returns VBox status code.
 * @param   objData             Source object information to copy.
 */
int GuestFsObjInfo::init(const GuestFsObjData &objData)
{
    LogFlowThisFuncEnter();

    /* Enclose the state transition NotReady->InInit->Ready. */
    AutoInitSpan autoInitSpan(this);
    AssertReturn(autoInitSpan.isOk(), VERR_OBJECT_DESTROYED);

    mData = objData;

    /* Confirm a successful initialization when it's the case. */
    autoInitSpan.setSucceeded();

    return VINF_SUCCESS;
}

/**
 * Uninitializes the instance.
 * Called from FinalRelease().
 */
void GuestFsObjInfo::uninit(void)
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
 * Returns the last access time.
 *
 * @returns COM status code.
 * @param   aAccessTime         Where to return the access time.
 */
HRESULT GuestFsObjInfo::getAccessTime(LONG64 *aAccessTime)
{
    *aAccessTime = mData.mAccessTime;

    return S_OK;
}

/**
 * Returns the allocated size on disk.
 *
 * @returns COM status code.
 * @param   aAllocatedSize      Where to return the allocated size in bytes.
 */
HRESULT GuestFsObjInfo::getAllocatedSize(LONG64 *aAllocatedSize)
{
    *aAllocatedSize = mData.mAllocatedSize;

    return S_OK;
}

/**
 * Returns the object creation (birth) time.
 *
 * @returns COM status code.
 * @param   aBirthTime          Where to return the birth time.
 */
HRESULT GuestFsObjInfo::getBirthTime(LONG64 *aBirthTime)
{
    *aBirthTime = mData.mBirthTime;

    return S_OK;
}

/**
 * Returns the metadata change time.
 *
 * @returns COM status code.
 * @param   aChangeTime         Where to return the change time.
 */
HRESULT GuestFsObjInfo::getChangeTime(LONG64 *aChangeTime)
{
    *aChangeTime = mData.mChangeTime;

    return S_OK;
}



/**
 * Returns the device number for special files.
 *
 * @returns COM status code.
 * @param   aDeviceNumber       Where to return the device number.
 */
HRESULT GuestFsObjInfo::getDeviceNumber(ULONG *aDeviceNumber)
{
    *aDeviceNumber = mData.mDeviceNumber;

    return S_OK;
}

/**
 * Returns platform-specific file attributes as a string.
 *
 * @returns COM status code.
 * @param   aFileAttributes     Where to return the UTF-8 attribute string.
 */
HRESULT GuestFsObjInfo::getFileAttributes(com::Utf8Str &aFileAttributes)
{
    aFileAttributes = mData.mFileAttrs;

    return S_OK;
}

/**
 * Returns the generation identifier.
 *
 * @returns COM status code.
 * @param   aGenerationId       Where to return the generation ID.
 */
HRESULT GuestFsObjInfo::getGenerationId(ULONG *aGenerationId)
{
    *aGenerationId = mData.mGenerationID;

    return S_OK;
}

/**
 * Returns the group identifier.
 *
 * @returns COM status code.
 * @param   aGID                Where to return the group ID.
 */
HRESULT GuestFsObjInfo::getGID(LONG *aGID)
{
    *aGID = mData.mGID;

    return S_OK;
}

/**
 * Returns the group name.
 *
 * @returns COM status code.
 * @param   aGroupName          Where to return the UTF-8 group name.
 */
HRESULT GuestFsObjInfo::getGroupName(com::Utf8Str &aGroupName)
{
    aGroupName = mData.mGroupName;

    return S_OK;
}

/**
 * Returns the hard link count.
 *
 * @returns COM status code.
 * @param   aHardLinks          Where to return the hard link count.
 */
HRESULT GuestFsObjInfo::getHardLinks(ULONG *aHardLinks)
{
    *aHardLinks = mData.mNumHardLinks;

    return S_OK;
}

/**
 * Returns the content modification time.
 *
 * @returns COM status code.
 * @param   aModificationTime   Where to return the modification time.
 */
HRESULT GuestFsObjInfo::getModificationTime(LONG64 *aModificationTime)
{
    *aModificationTime = mData.mModificationTime;

    return S_OK;
}

/**
 * Returns the object name.
 *
 * @returns COM status code.
 * @param   aName               Where to return the UTF-8 object name.
 */
HRESULT GuestFsObjInfo::getName(com::Utf8Str &aName)
{
    aName = mData.mName;

    return S_OK;
}

/**
 * Returns the file-system node identifier.
 *
 * @returns COM status code.
 * @param   aNodeId             Where to return the node ID.
 */
HRESULT GuestFsObjInfo::getNodeId(LONG64 *aNodeId)
{
    *aNodeId = mData.mNodeID;

    return S_OK;
}

/**
 * Returns the device identifier associated with the node ID.
 *
 * @returns COM status code.
 * @param   aNodeIdDevice       Where to return the node-ID device value.
 */
HRESULT GuestFsObjInfo::getNodeIdDevice(ULONG *aNodeIdDevice)
{
    *aNodeIdDevice = mData.mNodeIDDevice;

    return S_OK;
}

/**
 * Returns the logical object size.
 *
 * @returns COM status code.
 * @param   aObjectSize         Where to return the object size in bytes.
 */
HRESULT GuestFsObjInfo::getObjectSize(LONG64 *aObjectSize)
{
    *aObjectSize = mData.mObjectSize;

    return S_OK;
}

/**
 * Returns the file system object type.
 *
 * @returns COM status code.
 * @param   aType               Where to return the object type.
 */
HRESULT GuestFsObjInfo::getType(FsObjType_T *aType)
{
    *aType = mData.mType;

    return S_OK;
}

/**
 * Returns the user identifier.
 *
 * @returns COM status code.
 * @param   aUID                Where to return the user ID.
 */
HRESULT GuestFsObjInfo::getUID(LONG *aUID)
{
    *aUID = mData.mUID;

    return S_OK;
}

/**
 * Returns user-defined flags.
 *
 * @returns COM status code.
 * @param   aUserFlags          Where to return the user flags.
 */
HRESULT GuestFsObjInfo::getUserFlags(ULONG *aUserFlags)
{
    *aUserFlags = mData.mUserFlags;

    return S_OK;
}

/**
 * Returns the user name.
 *
 * @returns COM status code.
 * @param   aUserName           Where to return the UTF-8 user name.
 */
HRESULT GuestFsObjInfo::getUserName(com::Utf8Str &aUserName)
{
    aUserName = mData.mUserName;

    return S_OK;
}
