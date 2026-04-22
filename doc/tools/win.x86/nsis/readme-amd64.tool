NSIS (Nullsoft Installation Script) 3.10 (amd64 addendum)

Downloaded:
 1. https://prdownloads.sourceforge.net/nsis/nsis-3.10-src.tar.bz2?download
    md5: dec8094892b881f8bed0a170feee3200 size: 1813470


Environment
-----------

- Python 3.12.7 + SCons 4.8.1 (python -m pip install scons)
- VBox trunk (r166371).
    - VBox zlib v1.2.13.
    - VBox tools must be fetched without disabling docs (VBOX_WITH_DOCS), so
      the help compiler is present.
- Renamed "Microsoft Visual Studio", "Microsoft Visual Studio 14.0" and 
  "Windows Kits" to "xxx-%name%-xxx" under "C:\Program Files (x86)".


Steps to build and pack
-----------------------

- Load the VBox trunk build environment (tools/env.cmd).
- Do a amd64 release build: kmk KBUILD_TARGET_ARCH=amd64 KBUILD_TYPE=release
  (Only really need zlib and VBoxSetPeVersion.exe, but building everything is
  simpler.)
- run: SET MY_VBOX_ROOT=%CD%
- run: SET MY_VBOX_PE_SET_VERSION=%MY_VBOX_ROOT%\out\win.x86\release\obj\VBoxPeSetVersion\VBoxPeSetVersion.exe
- Make sure the utility exists: run: DIR %MY_VBOX_PE_SET_VERSION%
- Load the amd64 compiler and sdk:
    - run: %MY_VBOX_ROOT%\tools\win\vcc\v14.3.17.11.5\env-amd64.cmd
    - run: %MY_VBOX_ROOT%\tools\win\sdk\v10.0.26100.0\env-amd64.cmd --ucrt

- mkdir & cd <somewhere else> - run: kmk_mkdir -p e:\vbox\tools\nsis && cd e:\vbox\tools\nsis
- run: tar xf nsis-3.10-src.tar.bz2
- run: ren nsis-3.10-src nsis-3.10-amd64
- run: cd nsis-3.10-amd64
- Apply the patch attached to this file: 
    - run: patch -p1 < ..\readme-amd64.tool
- run: kmk_redirect -A "Path=;%MY_VBOX_ROOT%\tools\win.x86\HTML_Help_Workshop\v1.3" -E SCONS_MSCOMMON_DEBUG=%CD%\scons-mscommon.log ^
        -- cmd.exe /c C:\Python312\scripts\scons.exe MSVC_USE_SCRIPT=None MSTOOLKIT=yes MSVS_VERSION=14.3 TARGET_ARCH=amd64 ^
        UNICODE=yes SKIPUTILS="NSIS Menu" SKIPTESTS=all STRIP=1 STRIP_W32=1 NSIS_CONFIG_LOG=1 ^
        ZLIB_W32=%MY_VBOX_ROOT%/out/win.amd64/release/nsis-zlib/ dist |& tee bld-1.log
- run: cd .instdist
- run: copy ..\..\readme-amd64.tool
- Check that OS and subsys versions are 5.02:
    - run: dumpbin /HEADERS Plugins\amd64-unicode\nsExec.dll | grep -i version
    - run: dumpbin /HEADERS Stubs\zlib-amd64-unicode | grep -i version
- run: zip -r9X ..\..\win.amd64.nsis.v3.10-log-r1-target.zip readme-amd64.tool Plugins Stubs -x Stubs\uninst
- run: zip -r9X ..\..\win.amd64.nsis.v3.10-log-r1-rest.zip * -x makensisw.exe -x NSIS.chm -x Examples\* -x Docs\* -x Plugins\* -x Stubs\* -x readme-amd64.tool
- run: zip -r9X ..\..\win.amd64.nsis.v3.10-log-r1-rest.zip Stubs\uninst


SED
---

SED script for extracting the 'run' commands above: kmk_sed -nf below-script.sed readme.tool
:again
/\^$/!bdone
N
b again
:done
/^.* run: /!bend
s/^.* run: *//
a\
IF NOT ERRORLEVEL 0 GOTO :EOF
p
:end


Remarks
-------

- SCons is very puristsic and will not use anything (much) from the environment
  it is started in.  Instead it will try detect installed compilers and SDKs.
  We work around this by specifying MSVC_USE_SCRIPT=None and MSTOOLKIT=yes on 
  the command line.  These are NSIS specific hacks, but seems to do the job.
  That said, temporarily renaming any "Microsoft Visual Studio" directories in 
  "C:\Program Files (x86)" may be a good precaution to ensure build consistency.

- The 'config.log' file may contain clues about early build failures.
- Got files access / creation issues?  Try delete .sconsign.dblite file and the
  .sconf_temp directory.

- Using the dist-zip target doesn't work, as we'd have to unzip the zip file to
  repackage it.  The dist (dist-installer) rule leaves the .instdist directory
  behind and is thus easier to use.


--- nsis-3.10-src-1/SConstruct	2022-09-02 23:02:06.000000000 +0200
+++ nsis-3.10-src/SConstruct	2024-12-16 17:09:01.790405100 +0100
@@ -171,7 +171,7 @@
 opts.Add(('PATH', 'A colon-separated list of system paths instead of the default - TEMPORARY AND MAY DEPRECATE', None))
 opts.Add(('TOOLSET', 'A comma-separated list of specific tools used for building instead of the default', None))
 opts.Add(BoolVariable('MSTOOLKIT', 'Use Microsoft Visual C++ Toolkit', 'no'))
+opts.Add(EnumVariable('MSVS_VERSION', 'MS Visual C++ version', os.environ.get('MSVS_VERSION'), allowed_values=('6.0', '7.0', '7.1', '8.0', '8.0Exp', '9.0', '9.0Exp', '10.0', '10.0Exp', '14.3')))
-opts.Add(EnumVariable('MSVS_VERSION', 'MS Visual C++ version', os.environ.get('MSVS_VERSION'), allowed_values=('6.0', '7.0', '7.1', '8.0', '8.0Exp', '9.0', '9.0Exp', '10.0', '10.0Exp')))
 opts.Add(EnumVariable('TARGET_ARCH', 'Target processor architecture', 'x86', allowed_values=('x86', 'amd64', 'arm64')))
 opts.Add(ListVariable('DOCTYPES', 'A list of document types that will be built', default_doctype, doctypes))
 opts.Add(('CC', 'Override C compiler', None))
@@ -449,6 +449,12 @@
 			a = defenv.Action('$CODESIGNER "%s"' % t.path)
 			defenv.AddPostAction(t, a)
 
+def VBoxPeSetVersion(aoTargets, oEnv = defenv): # vbox
+	sVBoxSetPeVersion = os.environ.get('MY_VBOX_PE_SET_VERSION', 'VBoxPeSetVersion.exe');
+	for oTarget in aoTargets:
+		oAction = defenv.Action(sVBoxSetPeVersion + ' --w2k3 "%s"' % (oTarget.path,))
+		oEnv.AddPostAction(oTarget, oAction)
+
 Import('SilentActionEcho IsPEExecutable SetPESecurityFlagsWorker MakeReproducibleAction')
 def SetPESecurityFlagsAction(target, source, env):
 	for t in target:
@@ -655,6 +661,7 @@
 
 	target = defenv.SConscript(dirs = 'Source/exehead', variant_dir = build_dir, duplicate = False, exports = exports)
 	env.SideEffect('%s/stub_%s.map' % (build_dir, stub), target)
+	VBoxPeSetVersion(target, env); # vbox
 
 	env.MakeReproducible(target)
 	env.DistributeStubs(target, names=compression+suffix)
@@ -727,6 +734,7 @@
 
 	defenv.SetPESecurityFlags(plugin)
 	defenv.MakeReproducible(plugin)
+	VBoxPeSetVersion(plugin, defenv); # vbox
 	defenv.Sign(plugin)
 
 	CleanMap(env, plugin, target)
