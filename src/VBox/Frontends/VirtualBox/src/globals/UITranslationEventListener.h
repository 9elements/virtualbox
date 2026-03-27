/* $Id: UITranslationEventListener.h 113621 2026-03-27 12:48:06Z sergey.dubov@oracle.com $ */
/** @file
 * VBox Qt GUI - UITranslationEventListener class declaration.
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

#ifndef FEQT_INCLUDED_SRC_globals_UITranslationEventListener_h
#define FEQT_INCLUDED_SRC_globals_UITranslationEventListener_h
#ifndef RT_WITHOUT_PRAGMA_ONCE
# pragma once
#endif

/* Qt includes: */
#include <QObject>

/* GUI includes: */
#include "UILibraryDefs.h"

/** QObject extension catching application-wide LanguageChange event and broadcasting
  * all the subscribed listeners corresponding sigRetranslateUI signal to handle. */
class SHARED_LIBRARY_STUFF UITranslationEventListener : public QObject
{
    Q_OBJECT;

signals:

    /** Notifies listeners about application-wide LanguageChange event. */
    void sigRetranslateUI();

public:

    /** Returns the singleton instance. */
    static UITranslationEventListener *instance();
    /** Creates message-center singleton. */
    static void create();
    /** Destroys message-center singleton. */
    static void destroy();

protected:

    /** Preprocesses any Qt @a pEvent for passed @a pObject. */
    virtual bool eventFilter(QObject *pObject, QEvent *pEvent) RT_OVERRIDE RT_FINAL;

private slots:

    /** Broadcasts signals about application-wide LanguageChange event. */
    void sltRetranslateUI() { emit sigRetranslateUI(); }

private:

    /** Constructs translation event listener. */
    UITranslationEventListener();
    /** Destructs translation event listener. */
    virtual ~UITranslationEventListener() RT_OVERRIDE RT_FINAL;

    /** Holds the singleton instance. */
    static UITranslationEventListener *s_pInstance;

    /** Allows for shortcut access. */
    friend UITranslationEventListener &translationEventListener();
};

inline UITranslationEventListener &translationEventListener() { return *UITranslationEventListener::instance(); }

#endif /* !FEQT_INCLUDED_SRC_globals_UITranslationEventListener_h */
