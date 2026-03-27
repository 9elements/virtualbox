/* $Id: UITranslationEventListener.cpp 113621 2026-03-27 12:48:06Z sergey.dubov@oracle.com $ */
/** @file
 * VBox Qt GUI - UITranslationEventListener class implementation.
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
#include <QApplication>

/* GUI includes: */
#include "UITranslationEventListener.h"
#include "UITranslator.h"

/* Other VBox includes: */
#include "iprt/assert.h"


/* static */
UITranslationEventListener *UITranslationEventListener::s_pInstance = 0;

/* static */
UITranslationEventListener *UITranslationEventListener::instance()
{
    return s_pInstance;
}

/* static */
void UITranslationEventListener::create()
{
    AssertReturnVoid(!s_pInstance);
    new UITranslationEventListener;
    AssertPtrReturnVoid(s_pInstance);
}

/* static */
void UITranslationEventListener::destroy()
{
    AssertPtrReturnVoid(s_pInstance);
    delete s_pInstance;
    AssertReturnVoid(!s_pInstance);
}

bool UITranslationEventListener::eventFilter(QObject *pObject, QEvent *pEvent)
{
    /* Pre-process LanguageChange event: */
    if (   !UITranslator::isTranslationInProgress()
        && pEvent->type() == QEvent::LanguageChange
        && pObject == qApp)
    {
        /* Send translation signal asynchronously: */
        QMetaObject::invokeMethod(this, "sltRetranslateUI", Qt::QueuedConnection);
    }

    /* Call to base-class: */
    return QObject::eventFilter(pObject, pEvent);
}

UITranslationEventListener::UITranslationEventListener()
{
    qApp->installEventFilter(this);
    s_pInstance = this;
}

UITranslationEventListener::~UITranslationEventListener()
{
    s_pInstance = 0;
}
