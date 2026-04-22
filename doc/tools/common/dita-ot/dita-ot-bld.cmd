rem $Id: dita-ot-bld.cmd 113977 2026-04-22 20:32:22Z knut.osmundsen@oracle.com $
rem rem @file
rem Batch script to build dita-ot and the necessary dependencies.
rem
rem This sets up the basic environment and kicks of dita-ot-bld.sh since
rem it's easier to do this kind of work in bourne shell with 'set -e -x'.
rem
rem We deliberately set up things here you might think were better done in
rem dita-ot-bld.sh, but is to make it easy to try out things on the command
rem line. This is also why there is no setlocal/endlocal wrappings.
rem

rem
rem Copyright (C) 2023-2026 Oracle and/or its affiliates.
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

set       MY_BLD_DIR=%~dp0
set      MY_7ZIP_DIR=%KBUILD_DEVTOOLS:/=\%\win.amd64\7zip\v19.00
set        JAVA_HOME=%KBUILD_DEVTOOLS:/=\%\win.amd64\jdk\v17.0.7
set GRADLE_USER_HOME=%MY_BLD_DIR:\=/%/user-home-gradle
set    MY_GRADLE_DIR=%MY_BLD_DIR%\gradle-8.1.1
set     MY_MAVEN_DIR=%MY_BLD_DIR%\apache-maven-3.9.1
set       MAVEN_HOME=%MY_MAVEN_DIR:\=/%
set          M2_HOME=%MAVEN_HOME%
set          M3_HOME=%MAVEN_HOME%

call :strStartsWith "%Path%" "%MY_7ZIP_DIR%;%MY_GRADLE_DIR%\bin;%MY_MAVEN_DIR%\bin;"
if ERRORLEVEL 1          PATH=%MY_7ZIP_DIR%;%MY_GRADLE_DIR%\bin;%MY_MAVEN_DIR%\bin;%PATH%

set MY_NOPROXY=
if "%1%" == "--no-proxy" set MY_NOPROXY=1

rem Java proxy settings.
rem seems java.net.useSystemProxies doesn't really work.
set "JAVA_TOOL_OPTIONS=-Djava.net.useSystemProxies=true"
if NOT ".%MY_NOPROXY%" == "." goto java_tool_options_no_proxy
set "JAVA_TOOL_OPTIONS=%JAVA_TOOL_OPTIONS% -Dhttp.proxyHost=www-proxy-ams.nl.oracle.com -Dhttp.proxyPort=80"
set "JAVA_TOOL_OPTIONS=%JAVA_TOOL_OPTIONS% -Dhttps.proxyHost=www-proxy-ams.nl.oracle.com -Dhttps.proxyPort=80"
set "JAVA_TOOL_OPTIONS=%JAVA_TOOL_OPTIONS% -Dhttp.nonProxyHosts=*.oraclecorp.com|*.de.oracle.com|localhost"
:java_tool_options_no_proxy

rem check environment.
if exist "%MY_7ZIP_DIR%\7z.exe" goto ok_7z
echo Not found: "%MY_7ZIP_DIR%\7z.exe"
exit /b 1
:ok_7z

if exist "%JAVA_HOME%\bin\javac.exe" goto ok_javac
echo Not found: "%JAVA_HOME%\bin\javac.exe"
exit /b 1
:ok_javac

rem Invoke the bourne shell script.
kmk_ash.exe %MY_BLD_DIR%\dita-ot-bld.sh %*
exit /b


:strStartsWith
setlocal
set "MY_HAYSTACK=%~1"
set "MY_NEEDLE=%~2"
call set "MY_TMP_STR=%MY_NEEDLE%%%MY_HAYSTACK:*%MY_NEEDLE%=%%"

echo MY_NEEDLE:   %MY_NEEDLE%
echo MY_HAYSTACK: %MY_HAYSTACK%
echo MY_TMP_STR:  %MY_TMP_STR%

if /i "%MY_HAYSTACK%" NEQ "%MY_TMP_STR%" exit /b 1
exit /b 0

