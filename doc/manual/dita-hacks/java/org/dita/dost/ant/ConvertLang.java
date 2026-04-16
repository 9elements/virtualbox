/* $Id: ConvertLang.java 113897 2026-04-16 08:48:47Z knut.osmundsen@oracle.com $ */
/*! file
 * Replacement ConvertLang for htmlhelp that does nothing.
 *
 * The dita v4.0.2 plugin version of this will convert the output to iso-8859-1,
 * which is unnecessary for Qt and cause our non-breaking-hyphen characters to
 * be turned into question marks.
 */

/*
 * Copyright (C) 2026 Oracle and/or its affiliates.
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

package org.dita.dost.ant;

import org.apache.tools.ant.Task;

public final class ConvertLang extends Task
{
    @Override
    public void execute() { /* dummy */ }

    /* parameters: */
    public void setBasedir(final String basedir)        { /* dummy */ }
    public void setLangcode(final String langcode)      { /* dummy */ }
    public void setMessage(final String message)        { /* dummy */ }
    public void setOutputdir(final String outputdir)    { /* dummy */ }
}

