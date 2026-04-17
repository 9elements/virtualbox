/* $Id: UIMessageCenter.cpp 113938 2026-04-17 09:37:43Z sergey.dubov@oracle.com $ */
/** @file
 * VBox Qt GUI - UIMessageCenter class implementation.
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

/* GUI includes: */
#include "UICommon.h"
#include "UIExtraDataManager.h"
#include "UIGlobalSession.h"
#include "UIMessageCenter.h"
#include "UIModalWindowManager.h"
#include "UIVersion.h"
#include "VBoxAboutDlg.h"

/* COM includes: */
#include "CVirtualBox.h"

/* Other VBox includes: */
#include <VBox/version.h>


/* static */
UIMessageCenter *UIMessageCenter::s_pInstance = 0;
UIMessageCenter *UIMessageCenter::instance() { return s_pInstance; }

/* static */
void UIMessageCenter::create()
{
    /* Make sure instance is NOT created yet: */
    if (s_pInstance)
    {
        AssertMsgFailed(("UIMessageCenter instance is already created!"));
        return;
    }

    /* Create instance: */
    new UIMessageCenter;
    /* Prepare instance: */
    s_pInstance->prepare();
}

/* static */
void UIMessageCenter::destroy()
{
    /* Make sure instance is NOT destroyed yet: */
    if (!s_pInstance)
    {
        AssertMsgFailed(("UIMessageCenter instance is already destroyed!"));
        return;
    }

    /* Destroy instance: */
    delete s_pInstance;
}

void UIMessageCenter::sltShowHelpWebDialog()
{
    uiCommon().openURL("https://www.virtualbox.org");
}

void UIMessageCenter::sltShowBugTracker()
{
    uiCommon().openURL("https://github.com/VirtualBox/virtualbox/issues");
}

void UIMessageCenter::sltShowForums()
{
    uiCommon().openURL("https://forums.virtualbox.org/");
}

void UIMessageCenter::sltShowOracle()
{
    uiCommon().openURL("https://www.oracle.com/us/technologies/virtualization/virtualbox/overview/index.html");
}

void UIMessageCenter::sltShowOnlineDocumentation()
{
    QString strUrl = QString("https://docs.oracle.com/en/virtualization/virtualbox/%1.%2/user/index.html")
                             .arg(VBOX_VERSION_MAJOR).arg(VBOX_VERSION_MINOR);
    uiCommon().openURL(strUrl);
}

void UIMessageCenter::sltShowHelpAboutDialog()
{
    CVirtualBox vbox = gpGlobalSession->virtualBox();
    const QString strFullVersion = UIVersionInfo::brandingIsActive()
                                 ? QString("%1 r%2 - %3").arg(vbox.GetVersion())
                                                         .arg(vbox.GetRevision())
                                                         .arg(UIVersionInfo::brandingGetKey("Name"))
                                 : QString("%1 r%2").arg(vbox.GetVersion())
                                                    .arg(vbox.GetRevision());
    (new VBoxAboutDlg(windowManager().mainWindowShown(), strFullVersion))->show();
}

void UIMessageCenter::sltResetSuppressedMessages()
{
    /* Nullify suppressed message list: */
    gEDataManager->setSuppressedMessages(QStringList());
}

UIMessageCenter::UIMessageCenter()
{
    /* Assign instance: */
    s_pInstance = this;
}

UIMessageCenter::~UIMessageCenter()
{
    /* Unassign instance: */
    s_pInstance = 0;
}

void UIMessageCenter::prepare()
{
    /* Prepare interthread connection: */
    qRegisterMetaType<MessageType>();

    /* Translations for Main.
     * Please make sure they corresponds to the strings coming from Main one-by-one symbol! */
    tr("Could not load the Host USB Proxy Service (VERR_FILE_NOT_FOUND). "
       "The service might not be installed on the host computer");
    tr("VirtualBox is not currently allowed to access USB devices.  "
       "You can change this by adding your user to the 'vboxusers' group.  "
       "Please see the user guide for a more detailed explanation");
    tr("VirtualBox is not currently allowed to access USB devices.  "
       "You can change this by allowing your user to access the 'usbfs' folder and files.  "
       "Please see the user guide for a more detailed explanation");
    tr("The USB Proxy Service has not yet been ported to this host");
    tr("Could not load the Host USB Proxy service");
}
