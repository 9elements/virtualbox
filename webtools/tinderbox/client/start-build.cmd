@echo off
rem $Id: start-build.cmd 114033 2026-04-27 09:34:52Z knut.osmundsen@oracle.com $
rem rem @file
rem Starts tinderclient.pl on a tinderbox.
rem

rem
rem Copyright (C) 2008-2026 Oracle and/or its affiliates.
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

if %USERNAME% == Administrator (
    echo Do not run the builds as Administrator!
    echo rdp to the box using: user:vbox pw:********
    exit /b 1
)

rem set myhost=%COMPUTERNAME%
for /f "tokens=*" %%F in ('hostname') do set myhost=%%F
set orig_cd=%CD%

set affinitypref=
if exist .build-affinity set affinitypref=%orig_cd%\client\affinity.exe
set config_suffix=
if exist .build-config-suffix set /p config_suffix=<.build-config-suffix
set config_prefix=vbox
if exist .build-config-prefix set /p config_prefix=<.build-config-prefix
if exist .build-tmp set /p TMP=<.build-tmp
if exist .build-tmp set /p TEMP=<.build-tmp
if exist .build-tmp set /p TMPDIR=<.build-tmp
if exist .build-fetch set /p FETCHDIR=<.build-fetch
if exist .build-fetch (
    if not exist %FETCHDIR%\ (
        echo Tools fetch dir %FETCHDIR% does not exist. Create it before running builds!
        exit /b 1
    )
)
if exist .build-dir set /p build_dir=<.build-dir
if exist .build-dir (
    if not exist %build_dir%\ (
        echo Build dir %build_dir% does not exist. Create it before running builds!
        exit /b 1
    )
    pushd %build_dir%
)

if exist tmp\ (
    set TMP=%CD%\tmp
    set TEMP=%CD%\tmp
    set TMPDIR=%CD%\tmp
)
if exist temp\ (
    set TMP=%CD%\temp
    set TEMP=%CD%\temp
    set TMPDIR=%CD%\temp
)

if exist %orig_cd%\.build-wait (
    echo=
    echo Waiting to start the build at %CD%
    pushd %orig_cd%
    pause
    popd
)

%affinitypref% perl.exe %orig_cd%\client\tinderclient.pl ^
  --config="%orig_cd%\client\%config_prefix%.%myhost%%config_suffix%.cfg" ^
  --default_config="%orig_cd%\client\%config_prefix%.defaults.cfg"

popd
