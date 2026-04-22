@echo off
rem $Id: env-x86.cmd 113977 2026-04-22 20:32:22Z knut.osmundsen@oracle.com $
rem rem @file
rem usage: env-x86.cmd
rem

rem
rem Copyright (C) 2006-2026 Oracle and/or its affiliates.
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
rem SPDX-License-Identifier: GPL-3.0-only
rem

if not exist "%~dp0\Tools\MSVC\14.41.34120\include\stdarg.h" goto complicated

set VCINSTALLDIR=%~dp0\Tools\MSVC\14.41.34120
set VCREDISTDIR=%~dp0\Redist\MSVC\14.40.33807
:have_vcinstalldir
if "%PROCESSOR_ARCHITECTURE%"=="AMD64"   set PATH=%VCINSTALLDIR%\bin\Hostx64\x86;%VCINSTALLDIR%\bin\Hostx64\x64;%PATH%
if "%PROCESSOR_ARCHITECTURE%"=="AMD64"   goto done_path
if not "%PROCESSOR_ARCHITECTURE%"=="x86" set PATH=%VCINSTALLDIR%\bin\Host%PROCESSOR_ARCHITECTURE%\x86;%VCINSTALLDIR%\bin\Host%PROCESSOR_ARCHITECTURE%\%PROCESSOR_ARCHITECTURE%;%PATH%
if "%PROCESSOR_ARCHITECTURE%"=="x86"     set PATH=%VCINSTALLDIR%\bin\Hostx86\x86;%PATH%
:done_path
set INCLUDE=%VCINSTALLDIR%\include;%VCINSTALLDIR%\atlmfc\include;%INCLUDE%
set     LIB=%VCINSTALLDIR%\lib\x86;%VCINSTALLDIR%\atlmfc\lib\x86;%LIB%
set LIBPATH=%VCINSTALLDIR%\lib\x86;%VCINSTALLDIR%\atlmfc\lib\x86;%LIBPATH%
goto end

:complicated
if "%KBUILD_DEVTOOLS%"=="" goto error_no_bearings
set VCINSTALLDIR=%KBUILD_DEVTOOLS%\win\vcc\v14.3\Tools\MSVC\14.41.34120
set  VCREDISTDIR=%KBUILD_DEVTOOLS%\win\vcc\v14.3\Redist\MSVC\14.40.33807
goto have_vcinstalldir

:error_no_bearings
echo ERROR: The KBUILD_DEVTOOLS variable is not set.

:end

