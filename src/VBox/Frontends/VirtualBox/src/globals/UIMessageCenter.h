/* $Id: UIMessageCenter.h 113938 2026-04-17 09:37:43Z sergey.dubov@oracle.com $ */
/** @file
 * VBox Qt GUI - UIMessageCenter class declaration.
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

#ifndef FEQT_INCLUDED_SRC_globals_UIMessageCenter_h
#define FEQT_INCLUDED_SRC_globals_UIMessageCenter_h
#ifndef RT_WITHOUT_PRAGMA_ONCE
# pragma once
#endif

/* Qt includes: */
#include <QObject>

/* GUI includes: */
#include "UILibraryDefs.h"

/** Possible message types. */
enum MessageType
{
    MessageType_Question = 1,
    MessageType_Warning,
    MessageType_Error,
    MessageType_Critical
};
Q_DECLARE_METATYPE(MessageType);

/** Singleton QObject extension
  * providing GUI with corresponding messages. */
class SHARED_LIBRARY_STUFF UIMessageCenter : public QObject
{
    Q_OBJECT;

public:

    /** Creates message-center singleton. */
    static void create();
    /** Destroys message-center singleton. */
    static void destroy();

public slots:

    /* Handlers: Help menu stuff: */
    void sltShowHelpWebDialog();
    void sltShowBugTracker();
    void sltShowForums();
    void sltShowOracle();
    void sltShowOnlineDocumentation();
    void sltShowHelpAboutDialog();
    void sltResetSuppressedMessages();

private:

    /** Constructs message-center. */
    UIMessageCenter();
    /** Destructs message-center. */
    virtual ~UIMessageCenter() RT_OVERRIDE RT_FINAL;

    /** Prepares all. */
    void prepare();

    /** Holds the singleton message-center instance. */
    static UIMessageCenter *s_pInstance;
    /** Returns the singleton message-center instance. */
    static UIMessageCenter *instance();
    /** Allows for shortcut access. */
    friend UIMessageCenter &msgCenter();
};

/** Singleton Message Center 'official' name. */
inline UIMessageCenter &msgCenter() { return *UIMessageCenter::instance(); }

#endif /* !FEQT_INCLUDED_SRC_globals_UIMessageCenter_h */
