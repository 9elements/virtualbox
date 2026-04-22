From https://nsis.sourceforge.io/NsProcess_plugin downloaded: 
 1. https://nsis.sourceforge.io/mediawiki/images/1/18/NsProcess.zip
    version: 1.6 (NSIS UNICODE support, by brainsucker, rename nsProcessW.dll)
    md5: 5764989c655d44efbf99d951193f4107  size: 15207

Environment
-----------

- VBox trunk (r166371).


Steps to build and pack
-----------------------

- Load the VBox trunk build environment (tools/env.cmd).
  (Only need VBoxSetPeVersion.exe, but building everything is simpler.)
- run: SET MY_VBOX_ROOT=%CD%
- run: SET MY_VBOX_PE_SET_VERSION=%MY_VBOX_ROOT%\out\win.x86\release\obj\VBoxPeSetVersion\VBoxPeSetVersion.exe
- Make sure the utility exists: run: DIR %MY_VBOX_PE_SET_VERSION%
- Load the x86 compiler and sdk:
    - run: %MY_VBOX_ROOT%\tools\win\vcc\v14.3.17.11.5\env-x86.cmd
    - run: %MY_VBOX_ROOT%\tools\win\sdk\v10.0.26100.0\env-x86.cmd --ucrt
- All the above is the same as for the NSIS package.

- The NSIS source we're building the plugin for: 
    - run: SET MY_NSIS_SRC=e:\vbox\tools\nsis\nsis-3.10-r1

- mkdir & cd <somewhere else>; run: kmk_mkdir -p e:\vbox\tools\nsis && cd e:\vbox\tools\nsis
- All the above is the same as for the AccessControl package.
- run: mkdir nsProcess-r1
- run: cd nsProcess-r1
- run: 7z x <dlpath>\nsProcess.zip
- The zip file contains source files and headers from the NSIS distribution, so
  nuke these as well as any pre-build files:
    - run: kmk_rm -Rf Plugin Plugins Source\nsis_tchar.h Source\api.h Source\pluginapi.c Source\pluginapi.h
- run: mkdir Plugins Plugins\x86-unicode build build\x86-unicode
- run: cd build\x86-unicode
- run: cl /Zi /LD /W3 /O1 /GF /GS- /GR- /GL /Zl /Osy /Ogsy /arch:IA32 /DUNICODE /D_UNICODE ^
        /I../../Source ^
        /I%MY_NSIS_SRC%\Source\exehead /I%MY_NSIS_SRC%\Contrib\ExDLL /I. /FI%MY_NSIS_SRC%\Contrib\ExDLL\pluginapi.c ^
        ../../Source/nsProcess.c ^
        /FensProcess.dll /Fm ^
        /link /Entry:DllMain /OPT:REF /OPT:ICF,99 /MERGE:.rdata=.text /MAP /NODEFAULTLIB kernel32.lib user32.lib
- run: %MY_VBOX_PE_SET_VERSION% --nt4 nsProcess.dll
- run: RTLdrCheckImports -p %MY_VBOX_ROOT%\tools\win.x86\exports\nt4 nsProcess.dll
- run: copy nsProcess.dll ..\..\Plugins\x86-unicode
- run: copy nsProcess.pdb ..\..\Plugins\x86-unicode
- run: cd ..\..\
- run: mkdir Docs Docs\NsProcess
- run: copy Readme.txt Docs\NsProcess
- run: copy ..\readme-NsProcess.tool
- run: zip -9Xr ..\win.x86.nsis.v3.10-log-NsProcess-v1.6.zip Plugins Include Docs readme-NsProcess.tool

