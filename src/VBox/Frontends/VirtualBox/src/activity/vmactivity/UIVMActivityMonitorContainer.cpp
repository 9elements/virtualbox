/* $Id: UIVMActivityMonitorContainer.cpp 113637 2026-03-30 09:05:06Z serkan.bayraktar@oracle.com $ */
/** @file
 * VBox Qt GUI - UIVMLogViewer class implementation.
 */

/*
 * Copyright (C) 2010-2026 Oracle and/or its affiliates.
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
#include <QApplication>
#include <QCheckBox>
#include <QColor>
#include <QColorDialog>
#include <QHBoxLayout>
#include <QLabel>
#include <QPainter>
#include <QPixmap>
#include <QPlainTextEdit>
#include <QPushButton>
#include <QStyle>
#include <QTabBar>
#include <QTabWidget>

/* GUI includes: */
#include "UIActionPool.h"
#include "UIExtraDataManager.h"
#include "UIGlobalSession.h"
#include "UITranslationEventListener.h"
#include "UIVMActivityMonitor.h"
#include "UIVMActivityMonitorContainer.h"

/* Other includes: */
#include "iprt/assert.h"


/*********************************************************************************************************************************
*   UIVMActivityMonitorPaneContainer implementation.                                                                             *
*********************************************************************************************************************************/


UIVMActivityMonitorPaneContainer::UIVMActivityMonitorPaneContainer(QWidget *pParent)
    : UIPaneContainer(pParent)
    , m_pColorLabel{0, 0}
    , m_pColorChangeButton{0, 0}
    , m_pResetButton(0)
    , m_pPieChartCheckBox(0)
    , m_pDrawAreaChartCheckBox(0)
{
    setSizePolicy(QSizePolicy::Preferred, QSizePolicy::Maximum);
    prepare();
}

void UIVMActivityMonitorPaneContainer::prepare()
{
    QWidget *pContainerWidget = new QWidget(this);
    QGridLayout *pContainerLayout = new QGridLayout(pContainerWidget);
    AssertReturnVoid(pContainerWidget);
    AssertReturnVoid(pContainerLayout);
    insertTab(Tab_Preferences, pContainerWidget, "");
    pContainerWidget->setSizePolicy(QSizePolicy::Preferred, QSizePolicy::Maximum);

    for (int i = 0; i < 2; ++i)
    {
        QHBoxLayout *pColorLayout = new QHBoxLayout;
        AssertReturnVoid(pColorLayout);
        m_pColorLabel[i] = new QLabel(this);
        m_pColorChangeButton[i] = new QPushButton(this);
        AssertReturnVoid(m_pColorLabel[i]);
        AssertReturnVoid(m_pColorChangeButton[i]);
        pColorLayout->addWidget(m_pColorLabel[i]);
        pColorLayout->addWidget(m_pColorChangeButton[i]);
        pColorLayout->addStretch();
        pContainerLayout->addLayout(pColorLayout, i, 0, 1, 1);
        connect(m_pColorChangeButton[i], &QPushButton::pressed,
                this, &UIVMActivityMonitorPaneContainer::sltColorChangeButtonPressed);
    }
    m_pResetButton = new QPushButton(this);
    AssertReturnVoid(m_pResetButton);
    m_pResetButton->setSizePolicy(QSizePolicy::Maximum, QSizePolicy::Preferred);
    connect(m_pResetButton, &QPushButton::pressed,
            this, &UIVMActivityMonitorPaneContainer::sltResetToDefaults);

    pContainerLayout->addWidget(m_pResetButton, 2, 0, 1, 1);
    m_pPieChartCheckBox = new QCheckBox(this);
    AssertReturnVoid(m_pPieChartCheckBox);
    pContainerLayout->addWidget(m_pPieChartCheckBox, 0, 1, 1, 1);

    m_pDrawAreaChartCheckBox = new QCheckBox(this);
    AssertReturnVoid(m_pDrawAreaChartCheckBox);
    pContainerLayout->addWidget(m_pDrawAreaChartCheckBox, 1, 1, 1, 1);

    pContainerLayout->setColumnStretch(0, 0);
    pContainerLayout->setColumnStretch(1, 0);
    pContainerLayout->setColumnStretch(2, 1);
    pContainerLayout->setHorizontalSpacing(12);
    sltRetranslateUI();
    connect(&translationEventListener(), &UITranslationEventListener::sigRetranslateUI,
            this, &UIVMActivityMonitorPaneContainer::sltRetranslateUI);

}

void UIVMActivityMonitorPaneContainer::sltRetranslateUI()
{
    setTabText(Tab_Preferences, QApplication::translate("UIVMActivityMonitorPaneContainer", "Preferences"));

    if (m_pColorLabel[0])
        m_pColorLabel[0]->setText(QApplication::translate("UIVMActivityMonitorPaneContainer", "Data Series 1 Color"));
    if (m_pColorLabel[1])
        m_pColorLabel[1]->setText(QApplication::translate("UIVMActivityMonitorPaneContainer", "Data Series 2 Color"));
    if (m_pResetButton)
        m_pResetButton->setText(QApplication::translate("UIVMActivityMonitorPaneContainer", "Reset to Defaults"));
    if (m_pPieChartCheckBox)
        m_pPieChartCheckBox->setText(QApplication::translate("UIVMActivityMonitorPaneContainer", "Show Pie Charts"));
    if (m_pDrawAreaChartCheckBox)
        m_pDrawAreaChartCheckBox->setText(QApplication::translate("UIVMActivityMonitorPaneContainer", "Draw Area Charts"));
}

void UIVMActivityMonitorPaneContainer::colorPushButtons(QPushButton *pButton, const QColor &color)
{
    AssertReturnVoid(pButton);
    int iSize = qApp->style()->pixelMetric(QStyle::PM_ButtonIconSize);
    QPixmap iconPixmap(iSize, iSize);
    QPainter painter(&iconPixmap);
    painter.setBrush(color);
    painter.drawRect(iconPixmap.rect());
    pButton->setIcon(QIcon(iconPixmap));
}

void UIVMActivityMonitorPaneContainer::setDataSeriesColor(int iIndex, const QColor &color)
{
    if (iIndex == 0 || iIndex == 1)
    {
        if (m_color[iIndex] != color)
        {
            m_color[iIndex] = color;
            colorPushButtons(m_pColorChangeButton[iIndex], color);
            emit sigColorChanged(iIndex, color);
        }
    }
}

QColor UIVMActivityMonitorPaneContainer::dataSeriesColor(int iIndex) const
{
    if (iIndex >= 0 && iIndex < 2)
        return m_color[iIndex];
    return QColor();
}

void UIVMActivityMonitorPaneContainer::sltColorChangeButtonPressed()
{
    int iIndex = -1;
    if (sender() == m_pColorChangeButton[0])
        iIndex = 0;
    else if (sender() == m_pColorChangeButton[1])
        iIndex = 1;
    else
        return;

    QColorDialog colorDialog(m_color[iIndex], this);
    if (colorDialog.exec() == QDialog::Rejected)
        return;
    QColor newColor = colorDialog.selectedColor();
    if (m_color[iIndex] == newColor)
        return;
    m_color[iIndex] = newColor;
    colorPushButtons(m_pColorChangeButton[iIndex], newColor);
    emit sigColorChanged(iIndex, newColor);
}

void UIVMActivityMonitorPaneContainer::sltResetToDefaults()
{
    /* Reset data series colors: */
    setDataSeriesColor(0, QApplication::palette().color(QPalette::LinkVisited));
    setDataSeriesColor(1, QApplication::palette().color(QPalette::Link));
}

/*********************************************************************************************************************************
*   UIVMActivityMonitorContainer implementation.                                                                            *
*********************************************************************************************************************************/

UIVMActivityMonitorContainer::UIVMActivityMonitorContainer(QWidget *pParent, UIActionPool *pActionPool, EmbedTo enmEmbedding)
    :QWidget(pParent)
    , m_pPaneContainer(0)
    , m_pTabWidget(0)
    , m_pExportToFileAction(0)
    , m_pActionPool(pActionPool)
    , m_enmEmbedding(enmEmbedding)
{
    prepare();
    loadSettings();
    sltCurrentTabChanged(0);
}

void UIVMActivityMonitorContainer::removeTabs(const QVector<QUuid> &machineIdsToRemove)
{
    AssertReturnVoid(m_pTabWidget);
    QVector<UIVMActivityMonitor*> removeList;

    for (int i = m_pTabWidget->count() - 1; i >= 0; --i)
    {
        UIVMActivityMonitor *pMonitor = qobject_cast<UIVMActivityMonitor*>(m_pTabWidget->widget(i));
        if (!pMonitor)
            continue;
        if (machineIdsToRemove.contains(pMonitor->machineId()))
        {
            /* If the VM is running just hide the tab hosting the activity monitor: */
            if (pMonitor->isMachineRunning() || pMonitor->isMachinePaused())
            {
                m_pTabWidget->setTabVisible(i, false);
            }
            else
            {
                removeList << pMonitor;
                m_pTabWidget->removeTab(i);
            }
        }
    }
    qDeleteAll(removeList.begin(), removeList.end());
    controlTabBarVisibility();
}

void UIVMActivityMonitorContainer::prepare()
{
    QVBoxLayout *pMainLayout = new QVBoxLayout(this);
    pMainLayout->setContentsMargins(0, 0, 0, 0);

    m_pTabWidget = new QTabWidget(this);
    m_pTabWidget->setTabPosition(QTabWidget::East);
    //m_pTabWidget->setTabBarAutoHide(true);

    m_pPaneContainer = new UIVMActivityMonitorPaneContainer(this);
    m_pPaneContainer->hide();

    pMainLayout->addWidget(m_pTabWidget);
    pMainLayout->addWidget(m_pPaneContainer);

    connect(m_pTabWidget, &QTabWidget::currentChanged,
            this, &UIVMActivityMonitorContainer::sltCurrentTabChanged);
    connect(m_pPaneContainer, &UIVMActivityMonitorPaneContainer::sigColorChanged,
            this, &UIVMActivityMonitorContainer::sltDataSeriesColorChanged);
    m_pExportToFileAction = m_pActionPool->action(UIActionIndex_M_Activity_S_Export);
    if (m_pExportToFileAction)
        connect(m_pExportToFileAction, &QAction::triggered, this, &UIVMActivityMonitorContainer::sltExportToFile);

    if (m_pActionPool->action(UIActionIndex_M_Activity_T_Preferences))
        connect(m_pActionPool->action(UIActionIndex_M_Activity_T_Preferences), &QAction::toggled,
                this, &UIVMActivityMonitorContainer::sltTogglePreferencesPane);
}

void UIVMActivityMonitorContainer::loadSettings()
{
    if (m_pPaneContainer)
    {
        QStringList colorList = gEDataManager->VMActivityMonitorDataSeriesColors();
        if (colorList.size() == 2)
        {
            for (int i = 0; i < 2; ++i)
            {
                QColor color(colorList[i]);
                if (color.isValid())
                    m_pPaneContainer->setDataSeriesColor(i, color);
            }
        }
        if (!m_pPaneContainer->dataSeriesColor(0).isValid())
            m_pPaneContainer->setDataSeriesColor(0, QApplication::palette().color(QPalette::LinkVisited));
        if (!m_pPaneContainer->dataSeriesColor(1).isValid())
            m_pPaneContainer->setDataSeriesColor(1, QApplication::palette().color(QPalette::Link));
    }
}

void UIVMActivityMonitorContainer::saveSettings()
{
    if (m_pPaneContainer)
    {
        QStringList colorList;
        colorList << m_pPaneContainer->dataSeriesColor(0).name(QColor::HexArgb);
        colorList << m_pPaneContainer->dataSeriesColor(1).name(QColor::HexArgb);
        gEDataManager->setVMActivityMonitorDataSeriesColors(colorList);
    }
}

void UIVMActivityMonitorContainer::sltCurrentTabChanged(int iIndex)
{
    AssertReturnVoid(m_pTabWidget);
    Q_UNUSED(iIndex);
    UIVMActivityMonitor *pActivityMonitor = qobject_cast<UIVMActivityMonitor*>(m_pTabWidget->currentWidget());
    if (pActivityMonitor)
    {
        CMachine comMachine = gpGlobalSession->virtualBox().FindMachine(pActivityMonitor->machineId().toString());
        if (!comMachine.isNull())
        {
            setExportActionEnabled(comMachine.GetState() == KMachineState_Running);
        }
    }
}

void UIVMActivityMonitorContainer::sltDataSeriesColorChanged(int iIndex, const QColor &color)
{
    for (int i = m_pTabWidget->count() - 1; i >= 0; --i)
    {
        UIVMActivityMonitor *pMonitor = qobject_cast<UIVMActivityMonitor*>(m_pTabWidget->widget(i));
        if (!pMonitor)
            continue;
        pMonitor->setDataSeriesColor(iIndex, color);
    }
    saveSettings();
}

void UIVMActivityMonitorContainer::setExportActionEnabled(bool fEnabled)
{
    if (m_pExportToFileAction)
        m_pExportToFileAction->setEnabled(fEnabled);
}

void UIVMActivityMonitorContainer::sltExportToFile()
{
    AssertReturnVoid(m_pTabWidget);
    UIVMActivityMonitor *pActivityMonitor = qobject_cast<UIVMActivityMonitor*>(m_pTabWidget->currentWidget());
    if (pActivityMonitor)
        pActivityMonitor->sltExportMetricsToFile();
}

bool UIVMActivityMonitorContainer::makeTabVisibleIfExists(const QUuid &uMachineId)
{
    if (machineIds().contains(uMachineId))
    {
        int iTabIndex = findTabByMachineId(uMachineId);
        if (iTabIndex != -1)
        {
            m_pTabWidget->setTabVisible(iTabIndex, true);
            m_pTabWidget->setCurrentIndex(iTabIndex);
            return true;
        }
    }
    return false;
}

void UIVMActivityMonitorContainer::addLocalMachine(const CMachine &comMachine)
{
    AssertReturnVoid(m_pTabWidget);
    if (!comMachine.isOk() || comMachine.isNull())
        return;
    if (!makeTabVisibleIfExists(comMachine.GetId()))
    {

        UIVMActivityMonitorLocal *pActivityMonitor = new UIVMActivityMonitorLocal(m_enmEmbedding, this, comMachine, m_pActionPool);
        connect(pActivityMonitor, &UIVMActivityMonitorLocal::sigMachineShutDown, this, &UIVMActivityMonitorContainer::sltLocalMachineShutDown);
        if (m_pPaneContainer)
        {
            pActivityMonitor->setDataSeriesColor(0, m_pPaneContainer->dataSeriesColor(0));
            pActivityMonitor->setDataSeriesColor(1, m_pPaneContainer->dataSeriesColor(1));
        }
        int iNewTabIndex = m_pTabWidget->addTab(pActivityMonitor, comMachine.GetName());
        m_pTabWidget->setCurrentIndex(iNewTabIndex);
    }
    controlTabBarVisibility();
}

void UIVMActivityMonitorContainer::addCloudMachine(const CCloudMachine &comMachine)
{
    AssertReturnVoid(m_pTabWidget);
    if (!comMachine.isOk())
        return;
    if (makeTabVisibleIfExists(comMachine.GetId()))
        return;
    UIVMActivityMonitorCloud *pActivityMonitor = new UIVMActivityMonitorCloud(m_enmEmbedding, this, comMachine, m_pActionPool);
    if (m_pPaneContainer)
    {
        pActivityMonitor->setDataSeriesColor(0, m_pPaneContainer->dataSeriesColor(0));
        pActivityMonitor->setDataSeriesColor(1, m_pPaneContainer->dataSeriesColor(1));
    }
    m_pTabWidget->addTab(pActivityMonitor, comMachine.GetName());
    controlTabBarVisibility();
}

void UIVMActivityMonitorContainer::sltTogglePreferencesPane(bool fChecked)
{
    AssertReturnVoid(m_pPaneContainer);
    m_pPaneContainer->setVisible(fChecked);
}

void UIVMActivityMonitorContainer::sltLocalMachineShutDown(QUuid uMachineId)
{
    AssertReturnVoid(m_pTabWidget);
    int iTabIndex = findTabByMachineId(uMachineId);
    if (iTabIndex < 0 || iTabIndex >= m_pTabWidget->count())
        return;
    UIVMActivityMonitor *pMonitor = qobject_cast<UIVMActivityMonitor*>(m_pTabWidget->widget(iTabIndex));
    if (!pMonitor)
        return;
    m_pTabWidget->removeTab(iTabIndex);
    delete pMonitor;
}

QVector<QUuid> UIVMActivityMonitorContainer::machineIds() const
{
    QVector<QUuid> ids;
    for (int i = m_pTabWidget->count() - 1; i >= 0; --i)
    {
        UIVMActivityMonitor *pMonitor = qobject_cast<UIVMActivityMonitor*>(m_pTabWidget->widget(i));
        if (!pMonitor)
            continue;
        ids << pMonitor->machineId();
    }
    return ids;
}

int UIVMActivityMonitorContainer::findTabByMachineId(const QUuid &machineId)
{
    AssertReturn(m_pTabWidget, -1);
    for (int i = 0; i < m_pTabWidget->count(); ++i)
    {
        UIVMActivityMonitor *pMonitor = qobject_cast<UIVMActivityMonitor*>(m_pTabWidget->widget(i));
        if (!pMonitor)
            continue;
        if (pMonitor->machineId() == machineId)
            return i;
    }
    return -1;
}

int UIVMActivityMonitorContainer::visibleTabCount() const
{
    AssertReturn(m_pTabWidget, -1);
    int iCount = 0;
    for (int i = 0; i < m_pTabWidget->count(); ++i)
    {
        if (m_pTabWidget->isTabVisible(i))
            ++iCount;
    }
    return iCount;
}

void UIVMActivityMonitorContainer::controlTabBarVisibility()
{
    AssertReturnVoid(m_pTabWidget);
    AssertReturnVoid(m_pTabWidget->tabBar());
    int iVisibleTabCount = visibleTabCount();
    if (iVisibleTabCount == 1)
        m_pTabWidget->tabBar()->setVisible(false);
    else if (iVisibleTabCount > 1)
        m_pTabWidget->tabBar()->setVisible(true);
}
