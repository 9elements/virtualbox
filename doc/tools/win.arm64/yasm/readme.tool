Yasm v1.3.0.91.g06ed9 - git head as per 2024-11-04 with some patches.

We only patch the code to fix a tiny leak now, hack YASM-VERSION-GEN.bat so it
can find 'sh' on my system, and some annoying cmake hacking to make it
crossbuild win.arm64 on win.amd64.

Building is done using cmake and with Visual Studio 2022 Build Tools.

- mkdir build
- cd build
- "c:\Program Files\CMake\bin\cmake.exe" -D ENABLE_NLS=OFF -D BUILD_SHARED_LIBS=OFF -A x64 -B amd64 ..
- cd amd64
- "c:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe" yasm.sln -p:Configuration=RelWithDebInfo
- "c:\Program Files\CMake\bin\cmake.exe" --install . --prefix "%CD\installed" --config RelWithDebInfo
- cd installed\bin
- copy E:\vbox\yasm\readme.tool
- zip -9X E:\vbox\yasm\win.amd64.yasm.v1.3.0.91.g06ed9.zip yasm.exe readme.tool
- cd ..\..\..
- "c:\Program Files\CMake\bin\cmake.exe" -D ENABLE_NLS=OFF -D BUILD_SHARED_LIBS=OFF -D re2c_DIR=E:\vbox\yasm\yasm-2024-11.git\build\amd64 -D genmacro_DIR=E:\vbox\yasm\yasm-2024-11.git\build\amd64 -D genperf_DIR=E:\vbox\yasm\yasm-2024-11.git\build\amd64 -D genversion_DIR=E:\vbox\yasm\yasm-2024-11.git\build\amd64 -D CMAKE_SYSTEM_NAME=Windows -D CMAKE_SYSTEM_VERSION=10     -A ARM64 -B arm64 ..
  Note! Setting CMAKE_SYSTEM_NAME & CMAKE_SYSTEM_VERSION triggers setting of CMAKE_CROSSCOMPILING, which
        is necessary for proper cross building. No idea how to tell cmake we're just targeting a different
         architecture for the same OS.
- cd arm64
- "c:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe" yasm.sln -p:Configuration=RelWithDebInfo
- "c:\Program Files\CMake\bin\cmake.exe" --install . --prefix "%CD\installed" --config RelWithDebInfo
- cd installed\bin
- copy E:\vbox\yasm\readme.tool
- zip -9X E:\vbox\yasm\win.arm64.yasm.v1.3.0.91.g06ed9.zip yasm.exe readme.tool


Patches:

From 044cefca5d2f9995489a17f2cceef6cfde76f6dd Mon Sep 17 00:00:00 2001
From: "knut st. osmundsen" <bird-nasm@anduin.net>
Date: Mon, 4 Nov 2024 21:49:44 +0100
Subject: [PATCH 1/4] Leak and a build hack.

---
 YASM-VERSION-GEN.bat                 | 30 ++++++++++++++++++++++++----
 modules/preprocs/nasm/nasm-preproc.c |  1 +
 2 files changed, 27 insertions(+), 4 deletions(-)

diff --git a/YASM-VERSION-GEN.bat b/YASM-VERSION-GEN.bat
index 92bb97e6..46e4861b 100644
--- a/YASM-VERSION-GEN.bat
+++ b/YASM-VERSION-GEN.bat
@@ -1,19 +1,37 @@
 @echo off
+setlocal ENABLEEXTENSIONS
+setlocal
+
+rem switch to script directory
+set MY_DIR=%~dp0
+cd %MY_DIR%
+
 if exist version goto haveversion
 
 set errorlevel=0
 set _my_=
+
 for /f "usebackq tokens=1*" %%f in (`reg query HKCU\Software\TortoiseGit /v MSysGit`) do (set _my_=%%f %%g)
-if %errorlevel% neq 0 goto notfound
-if "%_my_%" == "" goto notfound
+if %errorlevel% neq 0 goto notfound1
+if "%_my_%" == "" goto notfound1
+goto ok
+
+rem hack for my rig.
+:notfound1
+set _gitbin_=C:\Program Files\Git\usr\bin
+goto :got_git_bin
 
 rem Using the shell script version (calling Git) ...
+:ok
 set _gitbin_=%_my_:*REG_SZ=%
 for /f "tokens=* delims= " %%a in ("%_gitbin_%") do set _gitbin_=%%a
+:got_git_bin
 set OLDPATH=%PATH%
 set PATH=%_gitbin_%;%PATH%
-"%_gitbin_%\sh" YASM-VERSION-GEN.sh "%_gitbin_%"
+"%_gitbin_%\sh" -x YASM-VERSION-GEN.sh "%_gitbin_%"
 set PATH=%OLDPATH%
+endlocal
+endlocal
 exit /b
 
 :notfound
@@ -30,9 +48,13 @@ goto output
 :output
 set /p _oldver_=<YASM-VERSION-FILE
 set _oldver_=%_oldver_:~,-1%
-if "%_ver_%" == "%_oldver_%" exit /b
+if "%_ver_%" == "%_oldver_%" goto end_success
 echo %_ver_%
 echo %_ver_% > YASM-VERSION-FILE
 echo #define PACKAGE_STRING "yasm %_ver_%" > YASM-VERSION.h
 echo #define PACKAGE_VERSION "%_ver_%" >> YASM-VERSION.h
 
+:end_success
+endlocal
+endlocal
+exit /b 0
diff --git a/modules/preprocs/nasm/nasm-preproc.c b/modules/preprocs/nasm/nasm-preproc.c
index 75e60157..ee53b6fc 100644
--- a/modules/preprocs/nasm/nasm-preproc.c
+++ b/modules/preprocs/nasm/nasm-preproc.c
@@ -183,6 +183,7 @@ nasm_preproc_destroy(yasm_preproc *preproc)
         yasm_xfree(dep->name);
         yasm_xfree(dep);
     }
+    yasm_xfree(preproc_deps);
     yasm_xfree(nasm_src_set_fname(NULL));
 }
 
-- 
2.25.1.windows.1


From 433da46795dcfbff5c45037f3a6eaa03a529ecbe Mon Sep 17 00:00:00 2001
From: "knut st. osmundsen" <bird-nasm@anduin.net>
Date: Mon, 4 Nov 2024 22:22:01 +0100
Subject: [PATCH 2/4] Slim the stuff down, checksum the file and allow it to be
 randomly placed

---
 CMakeLists.txt | 5 +++++
 1 file changed, 5 insertions(+)

diff --git a/CMakeLists.txt b/CMakeLists.txt
index 8df871cf..0e5b966f 100644
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -31,6 +31,11 @@ VERSION_GEN(PACKAGE_VERSION "${CMAKE_BINARY_DIR}/YASM-VERSION-FILE" "1.3.0")
 
 set (PACKAGE_STRING "yasm ${PACKAGE_VERSION}")
 
+# bird: slim the crap down.
+if (MSVC)
+    add_compile_options(-Gy -O2)
+    add_link_options(-Opt:Ref -Opt:Icf -Release -Map)
+endif()
 INCLUDE_DIRECTORIES(AFTER ${CMAKE_BINARY_DIR} ${yasm_SOURCE_DIR})
 
 INCLUDE(ConfigureChecks.cmake)
-- 
2.25.1.windows.1


From 079b0f4e8f246b262eb775bcb624239e94b36482 Mon Sep 17 00:00:00 2001
From: "knut st. osmundsen" <bird-nasm@anduin.net>
Date: Tue, 5 Nov 2024 00:22:46 +0100
Subject: [PATCH 3/4] Slim the stuff down, checksum the file and allow it to be
 randomly placed

---
 CMakeLists.txt | 4 ++--
 1 file changed, 2 insertions(+), 2 deletions(-)

diff --git a/CMakeLists.txt b/CMakeLists.txt
index 0e5b966f..b27771e1 100644
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -31,10 +31,10 @@ VERSION_GEN(PACKAGE_VERSION "${CMAKE_BINARY_DIR}/YASM-VERSION-FILE" "1.3.0")
 
 set (PACKAGE_STRING "yasm ${PACKAGE_VERSION}")
 
-# bird: slim the crap down.
+# bird: slim the stuff down, checksum the file and allow it to be randomly placed.
 if (MSVC)
     add_compile_options(-Gy -O2)
-    add_link_options(-Opt:Ref -Opt:Icf -Release -Map)
+    add_link_options(-Opt:Ref -Opt:Icf -Release -Map -HighEntropyVA)
 endif()
 INCLUDE_DIRECTORIES(AFTER ${CMAKE_BINARY_DIR} ${yasm_SOURCE_DIR})
 
-- 
2.25.1.windows.1


From 06ed9cdbc4d3f8870f0ad85fe1f84eaed5b623ac Mon Sep 17 00:00:00 2001
From: "knut st. osmundsen" <bird-nasm@anduin.net>
Date: Tue, 5 Nov 2024 00:23:35 +0100
Subject: [PATCH 4/4] Cross building win.arm64

---
 cmake/modules/YasmMacros.cmake       | 26 ++++++++++++++++----------
 modules/preprocs/nasm/CMakeLists.txt | 13 +++++++++----
 tools/genmacro/CMakeLists.txt        |  6 ++++++
 tools/genperf/CMakeLists.txt         | 22 ++++++++++++++--------
 tools/re2c/CMakeLists.txt            | 28 +++++++++++++++++-----------
 5 files changed, 62 insertions(+), 33 deletions(-)

diff --git a/cmake/modules/YasmMacros.cmake b/cmake/modules/YasmMacros.cmake
index ab1be00e..64068c2b 100644
--- a/cmake/modules/YasmMacros.cmake
+++ b/cmake/modules/YasmMacros.cmake
@@ -58,31 +58,37 @@ macro (YASM_ADD_MODULE _module_NAME)
 endmacro (YASM_ADD_MODULE)
 
 macro (YASM_GENPERF _in_NAME _out_NAME)
-    get_target_property(_tmp_GENPERF_EXE genperf LOCATION)
+    if(CMAKE_CROSSCOMPILING)
+       find_package(genperf)
+    endif()
     add_custom_command(
         OUTPUT ${_out_NAME}
-        COMMAND ${_tmp_GENPERF_EXE} ${_in_NAME} ${_out_NAME}
-        DEPENDS ${_tmp_GENPERF_EXE}
+        COMMAND $<TARGET_FILE:genperf> ${_in_NAME} ${_out_NAME}
+        DEPENDS $<TARGET_FILE:genperf>
         MAIN_DEPENDENCY ${_in_NAME}
         )
 endmacro (YASM_GENPERF)
 
-macro (YASM_RE2C _in_NAME _out_NAME)
-    get_target_property(_tmp_RE2C_EXE re2c LOCATION)
+    macro (YASM_RE2C _in_NAME _out_NAME)
+        if(CMAKE_CROSSCOMPILING)
+           find_package(re2c)
+        endif()
     add_custom_command(
         OUTPUT ${_out_NAME}
-        COMMAND ${_tmp_RE2C_EXE} ${ARGN} -o ${_out_NAME} ${_in_NAME}
-        DEPENDS ${_tmp_RE2C_EXE}
+        COMMAND $<TARGET_FILE:re2c> ${ARGN} -o ${_out_NAME} ${_in_NAME}
+        DEPENDS $<TARGET_FILE:re2c>
         MAIN_DEPENDENCY ${_in_NAME}
         )
 endmacro (YASM_RE2C)
 
 macro (YASM_GENMACRO _in_NAME _out_NAME _var_NAME)
-    get_target_property(_tmp_GENMACRO_EXE genmacro LOCATION)
+    if(CMAKE_CROSSCOMPILING)
+        find_package(genmacro)
+    endif()
     add_custom_command(
         OUTPUT ${_out_NAME}
-        COMMAND ${_tmp_GENMACRO_EXE} ${_out_NAME} ${_var_NAME} ${_in_NAME}
-        DEPENDS ${_tmp_GENMACRO_EXE}
+        COMMAND $<TARGET_FILE:genmacro> ${_out_NAME} ${_var_NAME} ${_in_NAME}
+        DEPENDS $<TARGET_FILE:genmacro>
         MAIN_DEPENDENCY ${_in_NAME}
         )
 endmacro (YASM_GENMACRO)
diff --git a/modules/preprocs/nasm/CMakeLists.txt b/modules/preprocs/nasm/CMakeLists.txt
index e10a9dd1..e4e89c67 100644
--- a/modules/preprocs/nasm/CMakeLists.txt
+++ b/modules/preprocs/nasm/CMakeLists.txt
@@ -1,9 +1,14 @@
-add_executable(genversion preprocs/nasm/genversion.c)
-get_target_property(_tmp_GENVERSION_EXE genversion LOCATION)
+if(CMAKE_CROSSCOMPILING)
+    find_package(genversion)
+else()
+    add_executable(genversion preprocs/nasm/genversion.c)
+    export(TARGETS genversion FILE
+        "${CMAKE_BINARY_DIR}/genversion-config.cmake")
+endif()
 add_custom_command(
     OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/version.mac
-    COMMAND ${_tmp_GENVERSION_EXE} ${CMAKE_CURRENT_BINARY_DIR}/version.mac
-    DEPENDS ${_tmp_GENVERSION_EXE}
+    COMMAND $<TARGET_FILE:genversion> ${CMAKE_CURRENT_BINARY_DIR}/version.mac
+    DEPENDS $<TARGET_FILE:genversion>
     )
 
 YASM_GENMACRO(
diff --git a/tools/genmacro/CMakeLists.txt b/tools/genmacro/CMakeLists.txt
index 27ba5996..e22fd16c 100644
--- a/tools/genmacro/CMakeLists.txt
+++ b/tools/genmacro/CMakeLists.txt
@@ -1,3 +1,9 @@
+if(CMAKE_CROSSCOMPILING)
+   find_package(genmacro)
+else()
 add_executable(genmacro
     genmacro.c
     )
+   export(TARGETS genmacro FILE
+       "${CMAKE_BINARY_DIR}/genmacro-config.cmake")
+endif()
diff --git a/tools/genperf/CMakeLists.txt b/tools/genperf/CMakeLists.txt
index 6f50989e..18b0110b 100644
--- a/tools/genperf/CMakeLists.txt
+++ b/tools/genperf/CMakeLists.txt
@@ -1,8 +1,14 @@
-add_executable(genperf
-    genperf.c
-    perfect.c
-    ../../libyasm/phash.c
-    ../../libyasm/xmalloc.c
-    ../../libyasm/xstrdup.c
-    )
-set_target_properties(genperf PROPERTIES COMPILE_FLAGS -DYASM_LIB_DECL=)
+if(CMAKE_CROSSCOMPILING)
+    find_package(genperf)
+else()
+    add_executable(genperf
+        genperf.c
+        perfect.c
+        ../../libyasm/phash.c
+        ../../libyasm/xmalloc.c
+        ../../libyasm/xstrdup.c
+        )
+    set_target_properties(genperf PROPERTIES COMPILE_FLAGS -DYASM_LIB_DECL=)
+    export(TARGETS genperf FILE
+        "${CMAKE_BINARY_DIR}/genperf-config.cmake")
+endif()
diff --git a/tools/re2c/CMakeLists.txt b/tools/re2c/CMakeLists.txt
index 7125d496..420ce717 100644
--- a/tools/re2c/CMakeLists.txt
+++ b/tools/re2c/CMakeLists.txt
@@ -1,11 +1,17 @@
-add_executable(re2c
-    main.c
-    code.c
-    dfa.c
-    parser.c
-    actions.c
-    scanner.c
-    mbo_getopt.c
-    substr.c
-    translate.c
-    )
+if(CMAKE_CROSSCOMPILING)
+    find_package(re2c)
+else()
+    add_executable(re2c
+        main.c
+        code.c
+        dfa.c
+        parser.c
+        actions.c
+        scanner.c
+        mbo_getopt.c
+        substr.c
+        translate.c
+        )
+       export(TARGETS re2c FILE
+              "${CMAKE_BINARY_DIR}/re2c-config.cmake")
+endif()
-- 
2.25.1.windows.1

