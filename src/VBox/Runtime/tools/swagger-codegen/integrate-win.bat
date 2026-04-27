rem $Id: integrate-win.bat 114031 2026-04-27 08:07:08Z knut.osmundsen@oracle.com $
rem rem @file
rem Script for running the swagger code generator, building it if necessary.
rem

rem
rem Copyright (C) 2018-2026 Oracle and/or its affiliates.
rem
rem This file is part of VirtualBox base platform packages, as
rem available from https://www.virtualbox.org.
rem
rem This program is free software; you can redistribute it and/or
rem modify it under the terms of the GNU General Public License
rem as published by the Free Software Foundation, in version 3 of the
rem License.
rem
rem This program is distributed in the hope that it will be useful, but
rem WITHOUT ANY WARRANTY; without even the implied warranty of
rem MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
rem General Public License for more details.
rem
rem You should have received a copy of the GNU General Public License
rem along with this program; if not, see <https://www.gnu.org/licenses>.
rem
rem The contents of this file may alternatively be used under the terms
rem of the Common Development and Distribution License Version 1.0
rem (CDDL), a copy of it is provided in the "COPYING.CDDL" file included
rem in the VirtualBox distribution, in which case the provisions of the
rem CDDL are applicable instead of those of the GPL.
rem
rem You may elect to license modified versions of this file under the
rem terms and conditions of either the GPL or the CDDL or both.
rem
rem SPDX-License-Identifier: GPL-3.0-only OR CDDL-1.0
rem

@setlocal
set THIS=%1
set TREE=%2
if not exist "%THIS%\patch.diff" goto syntax
if not exist "%TREE%\modules\swagger-codegen\src\main\java\io\swagger\codegen\DefaultCodegen.java" goto syntax

kmk_ln -s "%THIS%/java/io/swagger/codegen/languages/IprtClientCodegen.java" "%TREE%/./modules/swagger-codegen/src/main/java/io/swagger/codegen/languages/IprtClientCodegen.java"
kmk_ln -s "%THIS%/resources/iprt-client/"                                  "%TREE%/modules/swagger-codegen/src/main/resources/iprt-client"
kmk_ln -s "%THIS%/bin/iprt-client-petstore.sh"                             "%TREE%/bin/iprt-client-petstore.sh"
kmk_ln -s "%THIS%/bin/windows/iprt-client-petstore.bat"                    "%TREE%/bin/windows/iprt-client-petstore.bat"
( cd "%TREE%" && git apply -p1 "%THIS%/patch.diff" )
goto end

:syntax
@echo usage: %0 {iprt-swagger-dir} {swagger-codegen-tree}
:end
@endlocal

