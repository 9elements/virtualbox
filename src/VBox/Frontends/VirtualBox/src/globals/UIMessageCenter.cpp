/* $Id: UIMessageCenter.cpp 113937 2026-04-17 09:26:37Z sergey.dubov@oracle.com $ */
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

/* Qt includes: */
#include <QThread>

/* GUI includes: */
#include "QIMessageBox.h"
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

int UIMessageCenter::message(QWidget *pParent, MessageType enmType,
                             const QString &strMessage,
                             const QString &strDetails,
                             const char *pcszAutoConfirmId /* = 0 */,
                             int iButton1 /* = 0 */,
                             int iButton2 /* = 0 */,
                             int iButton3 /* = 0 */,
                             const QString &strButtonText1 /* = QString() */,
                             const QString &strButtonText2 /* = QString() */,
                             const QString &strButtonText3 /* = QString() */,
                             const QString &strHelpKeyword /* = QString() */) const
{
    /* If this is NOT a GUI thread: */
    if (thread() != QThread::currentThread())
    {
        /* We have to throw a blocking signal
         * to show a message-box in the GUI thread: */
        emit sigToShowMessageBox(pParent, enmType,
                                 strMessage, strDetails,
                                 iButton1, iButton2, iButton3,
                                 strButtonText1, strButtonText2, strButtonText3,
                                 QString(pcszAutoConfirmId), strHelpKeyword);
        // Inter-thread communications are not yet implemented, so
        // we are not returning effective value, but zero otherwise.
        return 0;
    }

    /* In usual case we can chow a message-box directly: */
    return showMessageBox(pParent, enmType,
                          strMessage, strDetails,
                          iButton1, iButton2, iButton3,
                          strButtonText1, strButtonText2, strButtonText3,
                          QString(pcszAutoConfirmId), strHelpKeyword);
}

void UIMessageCenter::error(QWidget *pParent, MessageType enmType,
                           const QString &strMessage,
                           const QString &strDetails,
                           const char *pcszAutoConfirmId /* = 0 */,
                           const QString &strHelpKeyword /* = QString() */) const
{
    message(pParent, enmType, strMessage, strDetails, pcszAutoConfirmId,
            AlertButton_Ok | AlertButtonOption_Default | AlertButtonOption_Escape, 0 /* Button 2 */, 0 /* Button 3 */,
            QString() /* strButtonText1 */, QString() /* strButtonText2 */, QString() /* strButtonText3 */, strHelpKeyword);
}

void UIMessageCenter::alert(QWidget *pParent, MessageType enmType,
                           const QString &strMessage,
                           const char *pcszAutoConfirmId /* = 0 */,
                           const QString &strHelpKeyword /* = QString() */) const
{
    error(pParent, enmType, strMessage, QString(), pcszAutoConfirmId, strHelpKeyword);
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

void UIMessageCenter::sltShowMessageBox(QWidget *pParent,
                                        MessageType enmType,
                                        const QString &strMessage,
                                        const QString &strDetails,
                                        int iButton1,
                                        int iButton2,
                                        int iButton3,
                                        const QString &strButtonText1,
                                        const QString &strButtonText2,
                                        const QString &strButtonText3,
                                        const QString &strAutoConfirmId,
                                        const QString &strHelpKeyword) const
{
    /* Now we can show a message-box directly: */
    showMessageBox(pParent, enmType,
                   strMessage, strDetails,
                   iButton1, iButton2, iButton3,
                   strButtonText1, strButtonText2, strButtonText3,
                   strAutoConfirmId, strHelpKeyword);
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
    connect(this, &UIMessageCenter::sigToShowMessageBox,
            this, &UIMessageCenter::sltShowMessageBox,
            Qt::BlockingQueuedConnection);

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

int UIMessageCenter::showMessageBox(QWidget *pParent,
                                    MessageType enmType,
                                    const QString &strMessage,
                                    const QString &strDetails,
                                    int iButton1,
                                    int iButton2,
                                    int iButton3,
                                    const QString &strButtonText1,
                                    const QString &strButtonText2,
                                    const QString &strButtonText3,
                                    const QString &strAutoConfirmId,
                                    const QString &strHelpKeyword) const
{
    /* Choose the 'default' button: */
    if (iButton1 == 0 && iButton2 == 0 && iButton3 == 0)
        iButton1 = AlertButton_Ok | AlertButtonOption_Default;

    /* Check if message-box was auto-confirmed before: */
    QStringList confirmedMessageList;
    if (!strAutoConfirmId.isEmpty())
    {
        const QUuid uID = uiCommon().uiType() == UIType_RuntimeUI
                        ? uiCommon().managedVMUuid()
                        : UIExtraDataManager::GlobalID;
        confirmedMessageList = gEDataManager->suppressedMessages(uID);
        if (   confirmedMessageList.contains(strAutoConfirmId)
            || confirmedMessageList.contains("allMessageBoxes")
            || confirmedMessageList.contains("all") )
        {
            int iResultCode = AlertOption_AutoConfirmed;
            if (iButton1 & AlertButtonOption_Default)
                iResultCode |= (iButton1 & AlertButtonMask);
            if (iButton2 & AlertButtonOption_Default)
                iResultCode |= (iButton2 & AlertButtonMask);
            if (iButton3 & AlertButtonOption_Default)
                iResultCode |= (iButton3 & AlertButtonMask);
            return iResultCode;
        }
    }

    /* Choose title and icon: */
    QString title;
    AlertIconType icon;
    switch (enmType)
    {
        default:
        case MessageType_Question:
            title = tr("VirtualBox - Question", "msg box title");
            icon = AlertIconType_Question;
            break;
        case MessageType_Warning:
            title = tr("VirtualBox - Warning", "msg box title");
            icon = AlertIconType_Warning;
            break;
        case MessageType_Error:
            title = tr("VirtualBox - Error", "msg box title");
            icon = AlertIconType_Critical;
            break;
        case MessageType_Critical:
            title = tr("VirtualBox - Critical Error", "msg box title");
            icon = AlertIconType_Critical;
            break;
    }

    /* Create message-box: */
    QWidget *pMessageBoxParent = windowManager().realParentWindow(pParent ? pParent : windowManager().mainWindowShown());
    const QString strHackValue = gEDataManager->extraDataString("GUI/Hack/MakeMessageBoxParentless");
    QPointer<QIMessageBox> pMessageBox = new QIMessageBox(title, strMessage, icon,
                                                          iButton1, iButton2, iButton3,
                                                          strHackValue == "true" ? 0 : pMessageBoxParent,
                                                          strHelpKeyword);
    windowManager().registerNewParent(pMessageBox, pMessageBoxParent);

    /* Prepare auto-confirmation check-box: */
    if (!strAutoConfirmId.isEmpty())
    {
        pMessageBox->setFlagText(tr("Do not show this message again", "msg box flag"));
        pMessageBox->setFlagChecked(false);
    }

    /* Configure details: */
    if (!strDetails.isEmpty())
        pMessageBox->setDetailsText(strDetails);

    /* Configure button-text: */
    if (!strButtonText1.isNull())
        pMessageBox->setButtonText(0, strButtonText1);
    if (!strButtonText2.isNull())
        pMessageBox->setButtonText(1, strButtonText2);
    if (!strButtonText3.isNull())
        pMessageBox->setButtonText(2, strButtonText3);

    /* Show message-box: */
    int iResultCode = pMessageBox->exec();

    /* Make sure message-box still valid: */
    if (!pMessageBox)
        return iResultCode;

    /* Remember auto-confirmation check-box value: */
    if (!strAutoConfirmId.isEmpty())
    {
        if (pMessageBox->flagChecked())
        {
            confirmedMessageList << strAutoConfirmId;
            gEDataManager->setSuppressedMessages(confirmedMessageList);
        }
    }

    /* Delete message-box: */
    delete pMessageBox;

    /* Return result-code: */
    return iResultCode;
}
