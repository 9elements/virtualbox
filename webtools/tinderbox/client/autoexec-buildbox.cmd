@echo off
REM $Id: autoexec-buildbox.cmd 114033 2026-04-27 09:34:52Z knut.osmundsen@oracle.com $
REM REM @file
REM

REM
REM Copyright (C) 2006-2026 Oracle and/or its affiliates.
REM
REM This file is part of VirtualBox base platform packages, as
REM available from https://www.virtualbox.org.
REM
REM This program is free software; you can redistribute it and/or
REM modify it under the terms of the GNU General Public License
REM as published by the Free Software Foundation, in version 3 of the
REM License.
REM
REM This program is distributed in the hope that it will be useful, but
REM WITHOUT ANY WARRANTY; without even the implied warranty of
REM MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
REM General Public License for more details.
REM
REM You should have received a copy of the GNU General Public License
REM along with this program; if not, see <https://www.gnu.org/licenses>.
REM
REM SPDX-License-Identifier: GPL-3.0-only
REM

@echo on

set RAMDRIVE=R:

REM Take presence of imdisk.exe as order to test in ramdisk.
if exist %SystemRoot%\System32\aim_ll.exe (
    set RAMEXE=aim
) else if exist %SystemRoot%\System32\imdisk.exe (
    set RAMEXE=imdisk
) else goto failed

REM imdisk -a -s 16GB -m %RAMDRIVE% -p "/fs:ntfs /q /y" -o "awe"
if %RAMEXE% == aim (
    aim_ll -a -t vm -s 128G -m %RAMDRIVE% -p "/fs:ntfs /q /y /v:RAMDRIVE"
) else if %RAMEXE% == imdisk (
    imdisk -D -m %RAMDRIVE%
    rem imdisk -a -f \\.\awealloc -s 128G -m %RAMDRIVE% -p "/fs:ntfs /q /y /v:RAMDRIVE" -o awe
    imdisk -a -s 128G -t vm -m %RAMDRIVE% -p "/fs:ntfs /q /y /v:RAMDRIVE"
) else goto failed

mkdir %RAMDRIVE%\tinderbox
if not exist %RAMDRIVE%\tinderbox (
    format %RAMDRIVE% /q
    mkdir %RAMDRIVE%\tinderbox
)

if not exist %RAMDRIVE%\tinderbox goto failed
set TMP=%RAMDRIVE%\temp
mkdir %TMP%
set TEMP=%TMP%
set TEMPDIR=%TMP%

goto defaulttasks

:failed
echo "Failed to create a RAM drive"
pause

:defaulttasks
REM pause
