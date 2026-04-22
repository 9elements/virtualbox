From https://nsis.sourceforge.io/AccessControl_plug-in downloaded: 
 1. https://nsis.sourceforge.io/mediawiki/images/4/4a/AccessControl.zip
    version: 1.0.8.3 (20210224)  md5: 6788149dcf34e89257d8d43b2a3aaa21  size: 50104

Environment
-----------

- VBox trunk (r166371).


Steps to build and pack
-----------------------

- Load the VBox trunk build environment (tools/env.cmd).
  (Only need VBoxSetPeVersion.exe, but building everything is simpler.)
- run: SET MY_VBOX_ROOT=%CD%
- run: SET MY_VBOX_PE_SET_VERSION=%MY_VBOX_ROOT%\out\win.x86\release\obj\VBoxPeSetVersion\VBoxPeSetVersion.exe
- Make sure the utility exists: 
    - run: DIR %MY_VBOX_PE_SET_VERSION%
- Load the x86 compiler and sdk:
    - run: %MY_VBOX_ROOT%\tools\win\vcc\v14.3.17.11.5\env-x86.cmd
    - run: %MY_VBOX_ROOT%\tools\win\sdk\v10.0.26100.0\env-x86.cmd --ucrt
- All the above is the same as for the NSIS package.

- The NSIS source we're building the plugin for: 
    - run: SET MY_NSIS_SRC=e:\vbox\tools\nsis\nsis-3.10-r1

- mkdir & cd <somewhere else>; run: kmk_mkdir -p e:\vbox\tools\nsis && cd e:\vbox\tools\nsis
- run: mkdir accesscontrol-r1
- run: cd accesscontrol-r1
- run: unzip <dlpath>\AccessControl.zip
- The zip file contains libraries and headers from the NSIS distribution, so 
  nuke these as well as any pre-build files:
    - run: kmk_rm -Rf Plugins Contrib\AccessControl\nsis_unicode Contrib\AccessControl\nsis_ansi
- run: mkdir Plugins Plugins\x86-unicode build build\x86-unicode
- run: cd build\x86-unicode
- run: kmk_ln -s %MY_NSIS_SRC%\Contrib\ExDLL\ nsis_unicode
- run: cl /Zi /LD /W3 /O1 /GF /Gz /GS- /GR- /GL /Zl /Osy /Ogsy /arch:IA32 /DUNICODE /D_UNICODE ^
        /I../../Contrib/AccessControl ^
        /I%MY_NSIS_SRC%\Source\exehead /I%MY_NSIS_SRC%\Contrib\ExDLL /I. /FI%MY_NSIS_SRC%\Contrib\ExDLL\pluginapi.c ^
        ../../Contrib/AccessControl/AccessControl.cpp ^
        /FeAccessControl.dll /Fm ^
        /link /OPT:REF /OPT:ICF,99 /MERGE:.rdata=.text /MAP /NODEFAULTLIB kernel32.lib user32.lib advapi32.lib
- run: %MY_VBOX_PE_SET_VERSION% --nt4 AccessControl.dll
- run: RTLdrCheckImports -p %MY_VBOX_ROOT%\tools\win.x86\exports\nt4 AccessControl.dll
- run: copy AccessControl.dll ..\..\Plugins\x86-unicode
- run: copy AccessControl.pdb ..\..\Plugins\x86-unicode
- run: cd ..\..
- run: copy ..\readme-AccessControl.tool
- run: zip -9Xr ..\win.x86.nsis.v3.10-log-AccessControl-v1.0.8.3.zip Plugins Docs readme-AccessControl.tool

