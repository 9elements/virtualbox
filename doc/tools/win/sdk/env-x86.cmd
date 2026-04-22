@echo off
rem $Id: env-x86.cmd 113977 2026-04-22 20:32:22Z knut.osmundsen@oracle.com $
rem rem @file
rem usage: env-x86.cmd [--ucrt]
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

set MYSDKVER=10.0.26100.0
if not exist "%~dp0\Include\%MYSDKVER%\um\WinBase.h" goto error_no_bearings
set MYSDK=%~dp0

:remainder
set PATH=%MYSDK%\Bin\x86;%MYSDK%\Bin\%MYSDKVER%\x86;%MYSDK%\Bin\x86;%MYSDK%\Bin\%MYSDKVER%\x86;%PATH%
if "%1"=="--ucrt" set INCLUDE=%MYSDK%\Include\%MYSDKVER%\ucrt;%INCLUDE%
if "%1"=="--ucrt" set LIB=%MYSDK%\Lib\%MYSDKVER%\ucrt\x86;%LIB%
set INCLUDE=%MYSDK%\Include\%MYSDKVER%\um;%MYSDK%\Include\%MYSDKVER%\shared;%INCLUDE%
set LIB=%MYSDK%\Lib\%MYSDKVER%\um\x86;%LIB%
goto end

:error_no_bearings
@echo ERROR: Cannot figure out where the %MYSDKVER% WDK is...

:end
set MYSDKVER=
set MYSDK=

