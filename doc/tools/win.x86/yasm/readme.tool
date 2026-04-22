Yasm git head as per 2016-08-12 (the much wanted -Wno-segreg-in-64bit commit
51af4082cc898b122b88f11fd34033fc00fad81e).  Two set of patches addressing
memory leaks and makefile dependency file generation has been applied (see
below).  These sets have pending pull requests on github.

Built using Visual Studio 2015 sp3, using the Visual C/C++ 2013 toolchain
and DLL CRT, and signed by bird.

Notes about building the solution:
        - Add dummy libyasm-stdint.h that includes stdint.h to the vc14 dir.
        - If failure executing YASM-VERSION-GEN.bat, modify the genversion
          Pre-Build Event of the genversion project to (adjust wrt git location):
              cd $(SolutionDir)..\..\ && "c:\Program Files\Git\bin\bash.exe" -x .\YASM-VERSION-GEN.sh
        - Don't build the whole solution, instead right click on the yasm project
          and build just that. Build it twice to get it without failures (some
          buggy Pre-Event stuff somewhere).

Patches:

diff --git a/Mkfiles/vc14/genmacro/genmacro.vcxproj b/Mkfiles/vc14/genmacro/genmacro.vcxproj
index f4bbc6f..f78b595 100644
--- a/Mkfiles/vc14/genmacro/genmacro.vcxproj
+++ b/Mkfiles/vc14/genmacro/genmacro.vcxproj
@@ -22,6 +22,7 @@
     <ProjectGuid>{225700A5-07B8-434E-AD61-555278BF6733}</ProjectGuid>
     <RootNamespace>genmacro</RootNamespace>
     <Keyword>Win32Proj</Keyword>
+    <WindowsTargetPlatformVersion>8.1</WindowsTargetPlatformVersion>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="Configuration">
@@ -85,7 +86,7 @@
       <PreprocessorDefinitions>WIN32;_DEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <MinimalRebuild>true</MinimalRebuild>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
@@ -112,13 +113,14 @@
       <Optimization>Disabled</Optimization>
       <PreprocessorDefinitions>WIN32;_DEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
       <WarningLevel>Level3</WarningLevel>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
       <CompileAs>Default</CompileAs>
+      <OmitFramePointers>false</OmitFramePointers>
     </ClCompile>
     <Link>
       <OutputFile>$(OutDir)genmacro.exe</OutputFile>
@@ -137,7 +139,7 @@
     <ClCompile>
       <Optimization>Full</Optimization>
       <PreprocessorDefinitions>WIN32;NDEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
@@ -163,7 +165,7 @@
     <ClCompile>
       <Optimization>Full</Optimization>
       <PreprocessorDefinitions>WIN32;NDEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
diff --git a/Mkfiles/vc14/genmodule/genmodule.vcxproj b/Mkfiles/vc14/genmodule/genmodule.vcxproj
index 44f2a00..58c2ea9 100644
--- a/Mkfiles/vc14/genmodule/genmodule.vcxproj
+++ b/Mkfiles/vc14/genmodule/genmodule.vcxproj
@@ -22,6 +22,7 @@
     <ProjectGuid>{F0E8B707-00C5-4FF2-B8EF-7C39817132A0}</ProjectGuid>
     <RootNamespace>genmodule</RootNamespace>
     <Keyword>Win32Proj</Keyword>
+    <WindowsTargetPlatformVersion>8.1</WindowsTargetPlatformVersion>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="Configuration">
@@ -86,7 +87,7 @@
       <PreprocessorDefinitions>WIN32;_DEBUG;_CONSOLE;FILTERMODE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <MinimalRebuild>true</MinimalRebuild>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <AssemblerListingLocation>$(IntDir)</AssemblerListingLocation>
@@ -115,7 +116,7 @@
       <AdditionalIncludeDirectories>%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>WIN32;_DEBUG;_CONSOLE;FILTERMODE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <AssemblerListingLocation>$(IntDir)</AssemblerListingLocation>
@@ -123,6 +124,7 @@
       <WarningLevel>Level3</WarningLevel>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
       <CompileAs>Default</CompileAs>
+      <OmitFramePointers>false</OmitFramePointers>
     </ClCompile>
     <Link>
       <OutputFile>$(OutDir)genmodule.exe</OutputFile>
@@ -142,7 +144,7 @@
       <Optimization>Full</Optimization>
       <AdditionalIncludeDirectories>%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>WIN32;NDEBUG;_CONSOLE;FILTERMODE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <AssemblerListingLocation>$(IntDir)</AssemblerListingLocation>
@@ -170,7 +172,7 @@
       <Optimization>Full</Optimization>
       <AdditionalIncludeDirectories>%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>WIN32;NDEBUG;_CONSOLE;FILTERMODE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <AssemblerListingLocation>$(IntDir)</AssemblerListingLocation>
diff --git a/Mkfiles/vc14/genperf/genperf.vcxproj b/Mkfiles/vc14/genperf/genperf.vcxproj
index 4ccf38a..c6eb5a9 100644
--- a/Mkfiles/vc14/genperf/genperf.vcxproj
+++ b/Mkfiles/vc14/genperf/genperf.vcxproj
@@ -22,6 +22,7 @@
     <ProjectGuid>{C45A8B59-8B59-4D5D-A8E8-FB090F8DD619}</ProjectGuid>
     <RootNamespace>genperf</RootNamespace>
     <Keyword>Win32Proj</Keyword>
+    <WindowsTargetPlatformVersion>8.1</WindowsTargetPlatformVersion>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="Configuration">
@@ -94,7 +95,7 @@
       <PreprocessorDefinitions>WIN32;_DEBUG;_CONSOLE;STDC_HEADERS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <MinimalRebuild>true</MinimalRebuild>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
@@ -132,13 +133,14 @@
       <AdditionalIncludeDirectories>..;../../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>WIN32;_DEBUG;_CONSOLE;STDC_HEADERS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
       <WarningLevel>Level3</WarningLevel>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
       <CompileAs>Default</CompileAs>
+      <OmitFramePointers>false</OmitFramePointers>
     </ClCompile>
     <Link>
       <OutputFile>$(OutDir)genperf.exe</OutputFile>
@@ -168,7 +170,7 @@
       <Optimization>Full</Optimization>
       <AdditionalIncludeDirectories>..;../../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>WIN32;NDEBUG;_CONSOLE;STDC_HEADERS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
@@ -205,7 +207,7 @@
       <Optimization>Full</Optimization>
       <AdditionalIncludeDirectories>..;../../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>WIN32;NDEBUG;_CONSOLE;STDC_HEADERS;%(PreprocessorDefinitions)</PreprocessorDefinitions>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
diff --git a/Mkfiles/vc14/genstring/genstring.vcxproj b/Mkfiles/vc14/genstring/genstring.vcxproj
index 239c8cf..85d42ac 100644
--- a/Mkfiles/vc14/genstring/genstring.vcxproj
+++ b/Mkfiles/vc14/genstring/genstring.vcxproj
@@ -22,6 +22,7 @@
     <ProjectGuid>{021CEB0A-F721-4F59-B349-9CEEAF244459}</ProjectGuid>
     <RootNamespace>genstring</RootNamespace>
     <Keyword>Win32Proj</Keyword>
+    <WindowsTargetPlatformVersion>8.1</WindowsTargetPlatformVersion>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="Configuration">
@@ -85,7 +86,7 @@
       <PreprocessorDefinitions>WIN32;_DEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <MinimalRebuild>true</MinimalRebuild>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
@@ -112,13 +113,14 @@
       <Optimization>Disabled</Optimization>
       <PreprocessorDefinitions>WIN32;_DEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
       <WarningLevel>Level3</WarningLevel>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
       <CompileAs>Default</CompileAs>
+      <OmitFramePointers>false</OmitFramePointers>
     </ClCompile>
     <Link>
       <OutputFile>$(OutDir)genstring.exe</OutputFile>
@@ -137,7 +139,7 @@
     <ClCompile>
       <Optimization>Full</Optimization>
       <PreprocessorDefinitions>WIN32;NDEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
@@ -163,7 +165,7 @@
     <ClCompile>
       <Optimization>Full</Optimization>
       <PreprocessorDefinitions>WIN32;NDEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
diff --git a/Mkfiles/vc14/genversion/genversion.vcxproj b/Mkfiles/vc14/genversion/genversion.vcxproj
index f9a5298..001b853 100644
--- a/Mkfiles/vc14/genversion/genversion.vcxproj
+++ b/Mkfiles/vc14/genversion/genversion.vcxproj
@@ -22,6 +22,7 @@
     <ProjectGuid>{B545983B-8EE0-4A7B-A67A-E749EEAE62A2}</ProjectGuid>
     <RootNamespace>genversion</RootNamespace>
     <Keyword>Win32Proj</Keyword>
+    <WindowsTargetPlatformVersion>8.1</WindowsTargetPlatformVersion>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="Configuration">
@@ -86,7 +87,7 @@
       <PreprocessorDefinitions>WIN32;_DEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <MinimalRebuild>true</MinimalRebuild>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
@@ -108,8 +109,7 @@
       <Command>run.bat "$(TargetPath)"</Command>
     </PostBuildEvent>
     <PreBuildEvent>
-      <Command>cd ..\..\..\
-YASM-VERSION-GEN.bat
+      <Command>cd $(SolutionDir)..\..\ &amp;&amp; "c:\Program Files\Git\bin\bash.exe" -x .\YASM-VERSION-GEN.sh
 </Command>
     </PreBuildEvent>
   </ItemDefinitionGroup>
@@ -119,13 +119,14 @@ YASM-VERSION-GEN.bat
       <AdditionalIncludeDirectories>..\..\vc10;..\..\..\;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>WIN32;_DEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
       <WarningLevel>Level3</WarningLevel>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
       <CompileAs>Default</CompileAs>
+      <OmitFramePointers>false</OmitFramePointers>
     </ClCompile>
     <Link>
       <OutputFile>$(OutDir)genversion.exe</OutputFile>
@@ -140,8 +141,7 @@ YASM-VERSION-GEN.bat
       <Command>run.bat "$(TargetPath)"</Command>
     </PostBuildEvent>
     <PreBuildEvent>
-      <Command>cd ..\..\..\
-YASM-VERSION-GEN.bat
+      <Command>cd $(SolutionDir)..\..\ &amp;&amp; "c:\Program Files\Git\bin\bash.exe" -x .\YASM-VERSION-GEN.sh
 </Command>
     </PreBuildEvent>
   </ItemDefinitionGroup>
@@ -150,7 +150,7 @@ YASM-VERSION-GEN.bat
       <Optimization>Full</Optimization>
       <AdditionalIncludeDirectories>..\..\vc10;..\..\..\;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>WIN32;NDEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
@@ -172,8 +172,7 @@ YASM-VERSION-GEN.bat
       <Command>run.bat "$(TargetPath)"</Command>
     </PostBuildEvent>
     <PreBuildEvent>
-      <Command>cd ..\..\..\
-YASM-VERSION-GEN.bat
+      <Command>cd $(SolutionDir)..\..\ &amp;&amp; "c:\Program Files\Git\bin\bash.exe" -x .\YASM-VERSION-GEN.sh
 </Command>
     </PreBuildEvent>
   </ItemDefinitionGroup>
@@ -182,7 +181,7 @@ YASM-VERSION-GEN.bat
       <Optimization>Full</Optimization>
       <AdditionalIncludeDirectories>..\..\vc10;..\..\..\;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>WIN32;NDEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
@@ -203,8 +202,7 @@ YASM-VERSION-GEN.bat
       <Command>run.bat "$(TargetPath)"</Command>
     </PostBuildEvent>
     <PreBuildEvent>
-      <Command>cd ..\..\..\
-YASM-VERSION-GEN.bat
+      <Command>cd $(SolutionDir)..\..\ &amp;&amp; "c:\Program Files\Git\bin\bash.exe" -x .\YASM-VERSION-GEN.sh
 </Command>
     </PreBuildEvent>
   </ItemDefinitionGroup>
diff --git a/Mkfiles/vc14/libyasm/libyasm.vcxproj b/Mkfiles/vc14/libyasm/libyasm.vcxproj
index 362aa2a..9add7a7 100644
--- a/Mkfiles/vc14/libyasm/libyasm.vcxproj
+++ b/Mkfiles/vc14/libyasm/libyasm.vcxproj
@@ -21,31 +21,32 @@
   <PropertyGroup Label="Globals">
     <ProjectGuid>{29FE7874-1256-4AD6-B889-68E399DC9608}</ProjectGuid>
     <RootNamespace>libyasm</RootNamespace>
+    <WindowsTargetPlatformVersion>5.2</WindowsTargetPlatformVersion>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'" Label="Configuration">
     <ConfigurationType>StaticLibrary</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="Configuration">
     <ConfigurationType>StaticLibrary</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'" Label="Configuration">
     <ConfigurationType>StaticLibrary</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'" Label="Configuration">
     <ConfigurationType>StaticLibrary</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.props" />
   <ImportGroup Label="ExtensionSettings">
@@ -87,7 +88,7 @@
       <AdditionalIncludeDirectories>..;../../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>NDEBUG;WIN32;_LIB;HAVE_CONFIG_H;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <StringPooling>true</StringPooling>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <FunctionLevelLinking>true</FunctionLevelLinking>
       <PrecompiledHeader>
       </PrecompiledHeader>
@@ -118,7 +119,7 @@
       <AdditionalIncludeDirectories>..;../../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>NDEBUG;_LIB;HAVE_CONFIG_H;WIN64;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <StringPooling>true</StringPooling>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <FunctionLevelLinking>true</FunctionLevelLinking>
       <PrecompiledHeader>
       </PrecompiledHeader>
@@ -147,7 +148,7 @@
       <AdditionalIncludeDirectories>..;../../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>_DEBUG;WIN32;_LIB;HAVE_CONFIG_H;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <AssemblerListingLocation>$(IntDir)</AssemblerListingLocation>
@@ -176,7 +177,7 @@
       <AdditionalIncludeDirectories>..;../../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>_DEBUG;_LIB;HAVE_CONFIG_H;WIN64;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <PrecompiledHeaderOutputFile>
@@ -188,6 +189,7 @@
       <SuppressStartupBanner>true</SuppressStartupBanner>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
       <CompileAs>Default</CompileAs>
+      <OmitFramePointers>false</OmitFramePointers>
     </ClCompile>
     <ResourceCompile>
       <PreprocessorDefinitions>_DEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
diff --git a/Mkfiles/vc14/modules/modules.vcxproj b/Mkfiles/vc14/modules/modules.vcxproj
index ceb1411..0a95a57 100644
--- a/Mkfiles/vc14/modules/modules.vcxproj
+++ b/Mkfiles/vc14/modules/modules.vcxproj
@@ -21,31 +21,32 @@
   <PropertyGroup Label="Globals">
     <ProjectGuid>{D715A3D4-EFAA-442E-AD8B-5B4FF64E1DD6}</ProjectGuid>
     <RootNamespace>modules</RootNamespace>
+    <WindowsTargetPlatformVersion>5.2</WindowsTargetPlatformVersion>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'" Label="Configuration">
     <ConfigurationType>StaticLibrary</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="Configuration">
     <ConfigurationType>StaticLibrary</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'" Label="Configuration">
     <ConfigurationType>StaticLibrary</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'" Label="Configuration">
     <ConfigurationType>StaticLibrary</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.props" />
   <ImportGroup Label="ExtensionSettings">
@@ -87,7 +88,7 @@
       <AdditionalIncludeDirectories>..;../../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>NDEBUG;WIN32;_LIB;HAVE_CONFIG_H;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <StringPooling>true</StringPooling>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <FunctionLevelLinking>true</FunctionLevelLinking>
       <PrecompiledHeader>
       </PrecompiledHeader>
@@ -124,7 +125,7 @@
       <AdditionalIncludeDirectories>..;../../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>NDEBUG;_LIB;HAVE_CONFIG_H;WIN64;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <StringPooling>true</StringPooling>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <FunctionLevelLinking>true</FunctionLevelLinking>
       <PrecompiledHeader>
       </PrecompiledHeader>
@@ -153,7 +154,7 @@
       <AdditionalIncludeDirectories>..;../../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>_DEBUG;WIN32;_LIB;HAVE_CONFIG_H;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <PrecompiledHeaderOutputFile>
@@ -184,7 +185,7 @@
       <AdditionalIncludeDirectories>..;../../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>_DEBUG;_LIB;HAVE_CONFIG_H;WIN64;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <PrecompiledHeaderOutputFile>
@@ -196,6 +197,7 @@
       <SuppressStartupBanner>true</SuppressStartupBanner>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
       <CompileAs>Default</CompileAs>
+      <OmitFramePointers>false</OmitFramePointers>
     </ClCompile>
     <ResourceCompile>
       <PreprocessorDefinitions>_DEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
diff --git a/Mkfiles/vc14/re2c/re2c.vcxproj b/Mkfiles/vc14/re2c/re2c.vcxproj
index 135b43b..58c3eb3 100644
--- a/Mkfiles/vc14/re2c/re2c.vcxproj
+++ b/Mkfiles/vc14/re2c/re2c.vcxproj
@@ -22,27 +22,28 @@
     <ProjectGuid>{3C58BE13-50A3-4583-984D-D8902B3D7713}</ProjectGuid>
     <RootNamespace>re2c</RootNamespace>
     <Keyword>Win32Proj</Keyword>
+    <WindowsTargetPlatformVersion>8.1</WindowsTargetPlatformVersion>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.props" />
   <ImportGroup Label="ExtensionSettings">
@@ -86,7 +87,7 @@
       <PreprocessorDefinitions>WIN32;_DEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <MinimalRebuild>true</MinimalRebuild>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
@@ -114,13 +115,14 @@
       <AdditionalIncludeDirectories>..;../../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>WIN32;_DEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
       <WarningLevel>Level3</WarningLevel>
       <CompileAs>Default</CompileAs>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
+      <OmitFramePointers>false</OmitFramePointers>
     </ClCompile>
     <Link>
       <OutputFile>$(OutDir)re2c.exe</OutputFile>
@@ -140,7 +142,7 @@
       <Optimization>Full</Optimization>
       <AdditionalIncludeDirectories>..;../../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>WIN32;NDEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
@@ -167,7 +169,7 @@
       <Optimization>Full</Optimization>
       <AdditionalIncludeDirectories>..;../../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>WIN32;NDEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <ProgramDataBaseFileName>$(IntDir)</ProgramDataBaseFileName>
diff --git a/Mkfiles/vc14/vsyasm.vcxproj b/Mkfiles/vc14/vsyasm.vcxproj
index 98283b1..3e80851 100644
--- a/Mkfiles/vc14/vsyasm.vcxproj
+++ b/Mkfiles/vc14/vsyasm.vcxproj
@@ -21,31 +21,32 @@
   <PropertyGroup Label="Globals">
     <ProjectGuid>{7FDD85BB-CC86-442B-A425-989B5B296ED5}</ProjectGuid>
     <RootNamespace>vsyasm</RootNamespace>
+    <WindowsTargetPlatformVersion>5.2</WindowsTargetPlatformVersion>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.props" />
   <ImportGroup Label="ExtensionSettings">
@@ -95,7 +96,7 @@
       <AdditionalIncludeDirectories>.;../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>_DEBUG;WIN32;_LIB;HAVE_CONFIG_H;VC;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <PrecompiledHeaderOutputFile>
@@ -136,7 +137,7 @@
       <AdditionalIncludeDirectories>.;../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>_DEBUG;_LIB;HAVE_CONFIG_H;VC;WIN64;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <PrecompiledHeaderOutputFile>
@@ -148,6 +149,8 @@
       <SuppressStartupBanner>true</SuppressStartupBanner>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
       <CompileAs>Default</CompileAs>
+      <AdditionalOptions>/FS %(AdditionalOptions)</AdditionalOptions>
+      <OmitFramePointers>false</OmitFramePointers>
     </ClCompile>
     <ResourceCompile>
       <PreprocessorDefinitions>_DEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
@@ -178,7 +181,7 @@
       <AdditionalIncludeDirectories>.;../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>NDEBUG;WIN32;_LIB;HAVE_CONFIG_H;VC;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <StringPooling>true</StringPooling>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <FunctionLevelLinking>true</FunctionLevelLinking>
       <PrecompiledHeader>
       </PrecompiledHeader>
@@ -191,6 +194,7 @@
       <SuppressStartupBanner>true</SuppressStartupBanner>
       <CompileAs>Default</CompileAs>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
+      <AdditionalOptions>/FS %(AdditionalOptions)</AdditionalOptions>
     </ClCompile>
     <ResourceCompile>
       <PreprocessorDefinitions>NDEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
@@ -202,10 +206,13 @@
       <GenerateDebugInformation>true</GenerateDebugInformation>
       <ProgramDatabaseFile>$(OutDir)$(ProjectName).pdb</ProgramDatabaseFile>
       <SubSystem>Console</SubSystem>
-      <RandomizedBaseAddress>false</RandomizedBaseAddress>
+      <RandomizedBaseAddress>true</RandomizedBaseAddress>
       <DataExecutionPrevention>
       </DataExecutionPrevention>
       <TargetMachine>MachineX86</TargetMachine>
+      <OptimizeReferences>true</OptimizeReferences>
+      <SetChecksum>true</SetChecksum>
+      <EnableCOMDATFolding>true</EnableCOMDATFolding>
     </Link>
   </ItemDefinitionGroup>
   <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'">
@@ -221,7 +228,7 @@
       <AdditionalIncludeDirectories>.;../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>NDEBUG;_LIB;HAVE_CONFIG_H;VC;WIN64;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <StringPooling>true</StringPooling>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <FunctionLevelLinking>true</FunctionLevelLinking>
       <PrecompiledHeader>
       </PrecompiledHeader>
@@ -234,6 +241,7 @@
       <SuppressStartupBanner>true</SuppressStartupBanner>
       <CompileAs>Default</CompileAs>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
+      <AdditionalOptions>/FS %(AdditionalOptions)</AdditionalOptions>
     </ClCompile>
     <ResourceCompile>
       <PreprocessorDefinitions>NDEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
@@ -244,11 +252,14 @@
       <SuppressStartupBanner>true</SuppressStartupBanner>
       <ProgramDatabaseFile>$(OutDir)$(TargetName).pdb</ProgramDatabaseFile>
       <SubSystem>Console</SubSystem>
-      <RandomizedBaseAddress>false</RandomizedBaseAddress>
+      <RandomizedBaseAddress>true</RandomizedBaseAddress>
       <DataExecutionPrevention>
       </DataExecutionPrevention>
       <TargetMachine>MachineX64</TargetMachine>
       <GenerateDebugInformation>true</GenerateDebugInformation>
+      <EnableCOMDATFolding>true</EnableCOMDATFolding>
+      <SetChecksum>true</SetChecksum>
+      <OptimizeReferences>true</OptimizeReferences>
     </Link>
   </ItemDefinitionGroup>
   <ItemGroup>
diff --git a/Mkfiles/vc14/yasm.vcxproj b/Mkfiles/vc14/yasm.vcxproj
index 867888b..985adc9 100644
--- a/Mkfiles/vc14/yasm.vcxproj
+++ b/Mkfiles/vc14/yasm.vcxproj
@@ -21,31 +21,32 @@
   <PropertyGroup Label="Globals">
     <ProjectGuid>{34EB1BEB-C2D6-4A52-82B7-7ACD714A30D5}</ProjectGuid>
     <RootNamespace>yasm</RootNamespace>
+    <WindowsTargetPlatformVersion>5.2</WindowsTargetPlatformVersion>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.props" />
   <ImportGroup Label="ExtensionSettings">
@@ -95,7 +96,7 @@
       <AdditionalIncludeDirectories>.;../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>_DEBUG;WIN32;_LIB;HAVE_CONFIG_H;VC;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <PrecompiledHeaderOutputFile>
@@ -136,7 +137,7 @@
       <AdditionalIncludeDirectories>.;../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>_DEBUG;_LIB;HAVE_CONFIG_H;VC;WIN64;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <PrecompiledHeaderOutputFile>
@@ -148,6 +149,8 @@
       <SuppressStartupBanner>true</SuppressStartupBanner>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
       <CompileAs>Default</CompileAs>
+      <AdditionalOptions>/FS %(AdditionalOptions)</AdditionalOptions>
+      <OmitFramePointers>false</OmitFramePointers>
     </ClCompile>
     <ResourceCompile>
       <PreprocessorDefinitions>_DEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
@@ -178,7 +181,7 @@
       <AdditionalIncludeDirectories>.;../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>NDEBUG;WIN32;_LIB;HAVE_CONFIG_H;VC;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <StringPooling>true</StringPooling>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <FunctionLevelLinking>true</FunctionLevelLinking>
       <PrecompiledHeader>
       </PrecompiledHeader>
@@ -191,6 +194,7 @@
       <SuppressStartupBanner>true</SuppressStartupBanner>
       <CompileAs>Default</CompileAs>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
+      <AdditionalOptions>/FS %(AdditionalOptions)</AdditionalOptions>
     </ClCompile>
     <ResourceCompile>
       <PreprocessorDefinitions>NDEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
@@ -202,10 +206,13 @@
       <GenerateDebugInformation>true</GenerateDebugInformation>
       <ProgramDatabaseFile>$(OutDir)$(ProjectName).pdb</ProgramDatabaseFile>
       <SubSystem>Console</SubSystem>
-      <RandomizedBaseAddress>false</RandomizedBaseAddress>
+      <RandomizedBaseAddress>true</RandomizedBaseAddress>
       <DataExecutionPrevention>
       </DataExecutionPrevention>
       <TargetMachine>MachineX86</TargetMachine>
+      <OptimizeReferences>true</OptimizeReferences>
+      <SetChecksum>true</SetChecksum>
+      <EnableCOMDATFolding>true</EnableCOMDATFolding>
     </Link>
   </ItemDefinitionGroup>
   <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'">
@@ -221,7 +228,7 @@
       <AdditionalIncludeDirectories>.;../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>NDEBUG;_LIB;HAVE_CONFIG_H;VC;WIN64;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <StringPooling>true</StringPooling>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <FunctionLevelLinking>true</FunctionLevelLinking>
       <PrecompiledHeader>
       </PrecompiledHeader>
@@ -234,6 +241,7 @@
       <SuppressStartupBanner>true</SuppressStartupBanner>
       <CompileAs>Default</CompileAs>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
+      <AdditionalOptions>/FS %(AdditionalOptions)</AdditionalOptions>
     </ClCompile>
     <ResourceCompile>
       <PreprocessorDefinitions>NDEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
@@ -244,11 +252,14 @@
       <SuppressStartupBanner>true</SuppressStartupBanner>
       <ProgramDatabaseFile>$(OutDir)$(TargetName).pdb</ProgramDatabaseFile>
       <SubSystem>Console</SubSystem>
-      <RandomizedBaseAddress>false</RandomizedBaseAddress>
+      <RandomizedBaseAddress>true</RandomizedBaseAddress>
       <DataExecutionPrevention>
       </DataExecutionPrevention>
       <TargetMachine>MachineX64</TargetMachine>
       <GenerateDebugInformation>true</GenerateDebugInformation>
+      <EnableCOMDATFolding>true</EnableCOMDATFolding>
+      <SetChecksum>true</SetChecksum>
+      <OptimizeReferences>true</OptimizeReferences>
     </Link>
   </ItemDefinitionGroup>
   <ItemGroup>
diff --git a/Mkfiles/vc14/ytasm.vcxproj b/Mkfiles/vc14/ytasm.vcxproj
index aabe801..973fd4d 100644
--- a/Mkfiles/vc14/ytasm.vcxproj
+++ b/Mkfiles/vc14/ytasm.vcxproj
@@ -21,31 +21,32 @@
   <PropertyGroup Label="Globals">
     <ProjectGuid>{2162937B-0DBD-4450-B45F-DF578D8E7508}</ProjectGuid>
     <RootNamespace>ytasm</RootNamespace>
+    <WindowsTargetPlatformVersion>5.2</WindowsTargetPlatformVersion>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|Win32'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|Win32'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|x64'" Label="Configuration">
     <ConfigurationType>Application</ConfigurationType>
     <UseOfMfc>false</UseOfMfc>
     <CharacterSet>MultiByte</CharacterSet>
-    <PlatformToolset>v140</PlatformToolset>
+    <PlatformToolset>v120_xp</PlatformToolset>
   </PropertyGroup>
   <Import Project="$(VCTargetsPath)\Microsoft.Cpp.props" />
   <ImportGroup Label="ExtensionSettings">
@@ -95,7 +96,7 @@
       <AdditionalIncludeDirectories>.;../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>_DEBUG;WIN32;_LIB;HAVE_CONFIG_H;VC;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <PrecompiledHeaderOutputFile>
@@ -136,7 +137,7 @@
       <AdditionalIncludeDirectories>.;../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>_DEBUG;_LIB;HAVE_CONFIG_H;VC;WIN64;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <BasicRuntimeChecks>EnableFastChecks</BasicRuntimeChecks>
-      <RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <PrecompiledHeader>
       </PrecompiledHeader>
       <PrecompiledHeaderOutputFile>
@@ -148,6 +149,8 @@
       <SuppressStartupBanner>true</SuppressStartupBanner>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
       <CompileAs>Default</CompileAs>
+      <AdditionalOptions>/FS %(AdditionalOptions)</AdditionalOptions>
+      <OmitFramePointers>false</OmitFramePointers>
     </ClCompile>
     <ResourceCompile>
       <PreprocessorDefinitions>_DEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
@@ -178,7 +181,7 @@
       <AdditionalIncludeDirectories>.;../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>NDEBUG;WIN32;_LIB;HAVE_CONFIG_H;VC;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <StringPooling>true</StringPooling>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <FunctionLevelLinking>true</FunctionLevelLinking>
       <PrecompiledHeader>
       </PrecompiledHeader>
@@ -191,6 +194,7 @@
       <SuppressStartupBanner>true</SuppressStartupBanner>
       <CompileAs>Default</CompileAs>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
+      <AdditionalOptions>/FS %(AdditionalOptions)</AdditionalOptions>
     </ClCompile>
     <ResourceCompile>
       <PreprocessorDefinitions>NDEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
@@ -202,10 +206,13 @@
       <GenerateDebugInformation>true</GenerateDebugInformation>
       <ProgramDatabaseFile>$(OutDir)$(ProjectName).pdb</ProgramDatabaseFile>
       <SubSystem>Console</SubSystem>
-      <RandomizedBaseAddress>false</RandomizedBaseAddress>
+      <RandomizedBaseAddress>true</RandomizedBaseAddress>
       <DataExecutionPrevention>
       </DataExecutionPrevention>
       <TargetMachine>MachineX86</TargetMachine>
+      <OptimizeReferences>true</OptimizeReferences>
+      <SetChecksum>true</SetChecksum>
+      <EnableCOMDATFolding>true</EnableCOMDATFolding>
     </Link>
   </ItemDefinitionGroup>
   <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'">
@@ -221,7 +228,7 @@
       <AdditionalIncludeDirectories>.;../..;%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
       <PreprocessorDefinitions>NDEBUG;_LIB;HAVE_CONFIG_H;VC;WIN64;%(PreprocessorDefinitions)</PreprocessorDefinitions>
       <StringPooling>true</StringPooling>
-      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
+      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
       <FunctionLevelLinking>true</FunctionLevelLinking>
       <PrecompiledHeader>
       </PrecompiledHeader>
@@ -234,6 +241,7 @@
       <SuppressStartupBanner>true</SuppressStartupBanner>
       <CompileAs>Default</CompileAs>
       <DebugInformationFormat>ProgramDatabase</DebugInformationFormat>
+      <AdditionalOptions>/FS %(AdditionalOptions)</AdditionalOptions>
     </ClCompile>
     <ResourceCompile>
       <PreprocessorDefinitions>NDEBUG;%(PreprocessorDefinitions)</PreprocessorDefinitions>
@@ -244,11 +252,14 @@
       <SuppressStartupBanner>true</SuppressStartupBanner>
       <ProgramDatabaseFile>$(OutDir)$(TargetName).pdb</ProgramDatabaseFile>
       <SubSystem>Console</SubSystem>
-      <RandomizedBaseAddress>false</RandomizedBaseAddress>
+      <RandomizedBaseAddress>true</RandomizedBaseAddress>
       <DataExecutionPrevention>
       </DataExecutionPrevention>
       <TargetMachine>MachineX64</TargetMachine>
       <GenerateDebugInformation>true</GenerateDebugInformation>
+      <EnableCOMDATFolding>true</EnableCOMDATFolding>
+      <SetChecksum>true</SetChecksum>
+      <OptimizeReferences>true</OptimizeReferences>
     </Link>
   </ItemDefinitionGroup>
   <ItemGroup>
diff --git a/YASM-VERSION-GEN.bat b/YASM-VERSION-GEN.bat
index 92bb97e..46e4861 100644
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
diff --git a/frontends/yasm/yasm.c b/frontends/yasm/yasm.c
index 75d9675..a91c0b1 100644
--- a/frontends/yasm/yasm.c
+++ b/frontends/yasm/yasm.c
@@ -70,6 +70,10 @@ static int special_options = 0;
 static int preproc_only = 0;
 static unsigned int force_strict = 0;
 static int generate_make_dependencies = 0;
+static int makedep_with_empty_recipts = 0;
+static int makedep_dos2unix_slash = 0;
+/*@null@*/ /*@only@*/ static const char *makedep_out_filename = NULL;
+/*@null@*/ /*@only@*/ static const char *makedep_target = NULL;
 static int warning_error = 0;   /* warnings being treated as errors */
 static FILE *errfile;
 /*@null@*/ /*@only@*/ static char *error_filename = NULL;
@@ -105,7 +109,11 @@ static int preproc_only_handler(char *cmd, /*@null@*/ char *param, int extra);
 static int opt_include_option(char *cmd, /*@null@*/ char *param, int extra);
 static int opt_preproc_option(char *cmd, /*@null@*/ char *param, int extra);
 static int opt_ewmsg_handler(char *cmd, /*@null@*/ char *param, int extra);
+static int opt_makedep_and_assemble_handler(char *cmd, /*@null@*/ char *param, int extra);
+static int opt_makedep_empty_handler(char *cmd, /*@null@*/ char *param, int extra);
+static int opt_makedep_target_handler(char *cmd, /*@null@*/ char *param, int extra);
 static int opt_makedep_handler(char *cmd, /*@null@*/ char *param, int extra);
+static int opt_makedep_dos2unix_slash_handler(char *cmd, /*@null@*/ char *param, int extra);
 static int opt_prefix_handler(char *cmd, /*@null@*/ char *param, int extra);
 static int opt_suffix_handler(char *cmd, /*@null@*/ char *param, int extra);
 #if defined(CMAKE_BUILD) && defined(BUILD_SHARED_LIBS)
@@ -137,6 +145,10 @@ static void apply_preproc_standard_macros(const yasm_stdmac *stdmacs);
 static void apply_preproc_saved_options(void);
 static void print_list_keyword_desc(const char *name, const char *keyword);
 
+#ifndef MAX
+# define MAX(a, b)  ( ((a) > (b)) ? (a) : (b) )
+#endif
+
 /* values for special_options */
 #define SPECIAL_SHOW_HELP 0x01
 #define SPECIAL_SHOW_VERSION 0x02
@@ -178,8 +190,18 @@ static opt_option options[] =
       N_("inhibits warning messages"), NULL },
     { 'W', NULL, 0, opt_warning_handler, 0,
       N_("enables/disables warning"), NULL },
-    { 'M', NULL, 0, opt_makedep_handler, 0,
+    { 0, "MD", 1, opt_makedep_and_assemble_handler, 0,
+      N_("generate Makefile dependencies and assemble normally"),
+      N_("file")},
+    { 0, "MP", 0, opt_makedep_empty_handler, 0,
+      N_("generate empty Makefile recipts for the include files"), NULL },
+    { 0, "MT", 1, opt_makedep_target_handler, 0,
+      N_("the Makefile target to associate the dependencies with"),
+      N_("target")},
+    { 'M', NULL, 0, opt_makedep_handler, 0, /* -M must come after -MD and -MP'! */
       N_("generate Makefile dependencies on stdout"), NULL },
+    { 0, "makedep-dos2unix-slash", 0, opt_makedep_dos2unix_slash_handler, 0,
+      N_("convert DOS to UNIX slashes in Makefile dependencies file"), NULL },
     { 'Z', NULL, 1, opt_error_file, 0,
       N_("redirect error messages to file"), N_("file") },
     { 's', NULL, 0, opt_error_stdout, 0,
@@ -248,12 +270,129 @@ typedef struct constcharparam {
 
 static constcharparam_head preproc_options;
 
+static char *
+dos2unix_slash(char *path)
+{
+    char *slash = strchr(path, '\\');
+    while (slash) {
+        *slash++ = '/';
+        slash = strchr(slash, '\\');
+    }
+    return path;
+}
+
+static int
+do_generate_make_dependencies(void)
+{
+    size_t empty_recipts_alloc = 0;
+    size_t empty_recipts_len = 0;
+    char *empty_recipts = NULL;
+    char *preproc_buf;
+    size_t linelen;
+    size_t got;
+    FILE *depout = stdout;
+    const char *target;
+
+    /* Open the -MD <file>. */
+    if (   makedep_out_filename != NULL
+        && strcmp(makedep_out_filename, "-") != 0) {
+        depout = open_file(makedep_out_filename, "wt");
+        if (!depout)
+            return EXIT_FAILURE;
+    }
+
+    /* -MT (and later -MQ?) can be used to specify the target name.
+       If not given, fall back on the object file. */
+    target = makedep_target ? makedep_target : obj_filename;
+
+    /* Make sure preproc_buf is large enough for either of the main
+       file names to avoid checking later (very ulikely that it isn't). */
+    linelen = strlen(target);
+    got = strlen(in_filename);
+    preproc_buf = yasm_xmalloc(MAX(PREPROC_BUF_SIZE, MAX(got, linelen) + 1));
+
+    /* The target (the object file) to add the dependencies to. */
+    if (!makedep_dos2unix_slash || makedep_target == NULL)
+        fputs(target, depout);
+    else
+        fputs(dos2unix_slash(memcpy(preproc_buf, target, linelen + 1)),
+              depout);
+
+    /* The source file (no empty rule for it, thus the code duplication). */
+    linelen += 2 + got;
+    if (linelen <= 72)
+        fputs(": ", depout);
+    else {
+        fputs(": \\\n ", depout);
+        linelen = 1 + got;
+    }
+    if (!makedep_dos2unix_slash)
+        fwrite(in_filename, got, 1, depout);
+    else
+        fwrite(dos2unix_slash(memcpy(preproc_buf, in_filename, got + 1)),
+               got, 1, depout);
+
+    /* Now the include files. */
+    while ((got = yasm_preproc_get_included_file(cur_preproc, preproc_buf,
+                                                 PREPROC_BUF_SIZE)) != 0) {
+        linelen += 1 + got;
+        if (linelen <= 72)
+            fputc(' ', depout);
+        else {
+            fputs(" \\\n ", depout);
+            linelen = 1 + got;
+        }
+        if (makedep_dos2unix_slash)
+            dos2unix_slash(preproc_buf);
+        fwrite(preproc_buf, got, 1, depout);
+
+        if (makedep_with_empty_recipts) {
+            /* We only get one shot at each include file, so we generate the
+               dummy recipts in a buffer while we're writing the dependencies
+               for the object file.  (The empty recipts makes make shut up
+               about deleted includes.) */
+            static const char empty_tail[] = ":\n\n";
+            size_t cur_len = empty_recipts_len;
+
+            empty_recipts_len = cur_len + got + sizeof(empty_tail) - 1;
+            if (empty_recipts_len >= empty_recipts_alloc) {
+                if (empty_recipts_alloc == 0)
+                    empty_recipts_alloc = 4096;
+                while (empty_recipts_len >= empty_recipts_alloc)
+                    empty_recipts_alloc *= 2;
+                empty_recipts = yasm_xrealloc(empty_recipts,
+                                              empty_recipts_alloc);
+            }
+
+            memcpy(&empty_recipts[cur_len], preproc_buf, got);
+            cur_len += got;
+            memcpy(&empty_recipts[cur_len], empty_tail, sizeof(empty_tail));
+        }
+    }
+
+    fputc('\n', depout);
+    yasm_xfree(preproc_buf);
+
+    if (empty_recipts) {
+        fputc('\n', depout);
+        fwrite(empty_recipts, empty_recipts_len, 1, depout);
+        yasm_xfree(empty_recipts);
+    }
+
+    if (   depout != stdout
+        && fclose(depout) != 0) {
+        print_error(_("error writing `%s'"), makedep_out_filename);
+        return EXIT_FAILURE;
+    }
+
+    return 0;
+}
+
 static int
 do_preproc_only(void)
 {
     yasm_linemap *linemap;
     char *preproc_buf;
-    size_t got;
     const char *base_filename;
     FILE *out = NULL;
     yasm_errwarns *errwarns = yasm_errwarns_create();
@@ -302,25 +441,7 @@ do_preproc_only(void)
 
     /* Pre-process until done */
     if (generate_make_dependencies) {
-        size_t totlen;
-
-        preproc_buf = yasm_xmalloc(PREPROC_BUF_SIZE);
-
-        fprintf(stdout, "%s: %s", obj_filename, in_filename);
-        totlen = strlen(obj_filename)+2+strlen(in_filename);
-
-        while ((got = yasm_preproc_get_included_file(cur_preproc, preproc_buf,
-                                                     PREPROC_BUF_SIZE)) != 0) {
-            totlen += got;
-            if (totlen > 72) {
-                fputs(" \\\n  ", stdout);
-                totlen = 2;
-            }
-            fputc(' ', stdout);
-            fwrite(preproc_buf, got, 1, stdout);
-        }
-        fputc('\n', stdout);
-        yasm_xfree(preproc_buf);
+        do_generate_make_dependencies();
     } else {
         while ((preproc_buf = yasm_preproc_get_line(cur_preproc)) != NULL) {
             fputs(preproc_buf, out);
@@ -574,12 +695,17 @@ do_assemble(void)
         fclose(list);
     }
 
+    /* Generate make dependency. */
+    if (generate_make_dependencies)
+        do_generate_make_dependencies();
+
     yasm_errwarns_output_all(errwarns, linemap, warning_error,
                              print_yasm_error, print_yasm_warning);
 
     yasm_linemap_destroy(linemap);
     yasm_errwarns_destroy(errwarns);
     cleanup(object);
+    yasm_delete_include_paths();
     return EXIT_SUCCESS;
 }
 
@@ -1171,6 +1297,32 @@ opt_ewmsg_handler(/*@unused@*/ char *cmd, char *param, /*@unused@*/ int extra)
 }
 
 static int
+opt_makedep_and_assemble_handler(/*@unused@*/ char *cmd, char *param,
+                          /*@unused@*/ int extra)
+{
+    generate_make_dependencies = 1;
+    makedep_out_filename = param;
+    return 0;
+}
+
+static int
+opt_makedep_empty_handler(/*@unused@*/ char *cmd, /*@unused@*/ char *param,
+                          /*@unused@*/ int extra)
+{
+    makedep_with_empty_recipts = 1;
+    return 0;
+}
+
+static int
+opt_makedep_target_handler(/*@unused@*/ char *cmd, char *param,
+                          /*@unused@*/ int extra)
+{
+    makedep_target = param;
+    return 0;
+}
+
+
+static int
 opt_makedep_handler(/*@unused@*/ char *cmd, /*@unused@*/ char *param,
                     /*@unused@*/ int extra)
 {
@@ -1182,6 +1334,14 @@ opt_makedep_handler(/*@unused@*/ char *cmd, /*@unused@*/ char *param,
 }
 
 static int
+opt_makedep_dos2unix_slash_handler(/*@unused@*/ char *cmd, /*@unused@*/ char *param,
+                    /*@unused@*/ int extra)
+{
+    makedep_dos2unix_slash = 1;
+    return 0;
+}
+
+static int
 opt_prefix_handler(/*@unused@*/ char *cmd, char *param, /*@unused@*/ int extra)
 {
     if (global_prefix)
diff --git a/modules/dbgfmts/codeview/cv-dbgfmt.c b/modules/dbgfmts/codeview/cv-dbgfmt.c
index 9b06fe3..e39a725 100644
--- a/modules/dbgfmts/codeview/cv-dbgfmt.c
+++ b/modules/dbgfmts/codeview/cv-dbgfmt.c
@@ -71,6 +71,8 @@ cv_dbgfmt_destroy(/*@only@*/ yasm_dbgfmt *dbgfmt)
     for (i=0; i<dbgfmt_cv->filenames_size; i++) {
         if (dbgfmt_cv->filenames[i].pathname)
             yasm_xfree(dbgfmt_cv->filenames[i].pathname);
+        if (dbgfmt_cv->filenames[i].filename)
+            yasm_xfree(dbgfmt_cv->filenames[i].filename);
     }
     yasm_xfree(dbgfmt_cv->filenames);
     yasm_xfree(dbgfmt);
diff --git a/modules/preprocs/nasm/nasm-pp.c b/modules/preprocs/nasm/nasm-pp.c
index 5ea650e..32ebcd0 100644
--- a/modules/preprocs/nasm/nasm-pp.c
+++ b/modules/preprocs/nasm/nasm-pp.c
@@ -2313,6 +2313,9 @@ expand_macros_in_string(char **p)
     Token *line = tokenise(*p);
     line = expand_smacro(line);
     *p = detoken(line, FALSE);
+    do
+        line = delete_Token(line);
+    while (line);
 }
 
 /**
@@ -2732,6 +2735,7 @@ do_directive(Token * tline)
             inc->next = istk;
             inc->conds = NULL;
             inc->fp = inc_fopen(p, &newname);
+            nasm_free(p);
             inc->fname = nasm_src_set_fname(newname);
             inc->lineno = nasm_src_set_linnum(0);
             inc->lineinc = 1;
@@ -5051,6 +5055,7 @@ pp_getline(void)
                 }
                 istk = i->next;
                 list->downlevel(LIST_INCLUDE);
+                nasm_free(i->fname);
                 nasm_free(i);
                 if (!istk)
                     return NULL;
diff --git a/modules/preprocs/nasm/nasm-preproc.c b/modules/preprocs/nasm/nasm-preproc.c
index 0b364b1..ee53b6f 100644
--- a/modules/preprocs/nasm/nasm-preproc.c
+++ b/modules/preprocs/nasm/nasm-preproc.c
@@ -151,7 +151,8 @@ nasm_preproc_create(const char *in_filename, yasm_symtab *symtab,
     nasm_symtab = symtab;
     cur_lm = lm;
     cur_errwarns = errwarns;
-    preproc_deps = NULL;
+    preproc_deps = yasm_xmalloc(sizeof(struct preproc_dep_head));
+    STAILQ_INIT(preproc_deps);
     done_dep_preproc = 0;
     preproc_nasm->line = NULL;
     preproc_nasm->file_name = NULL;
@@ -173,9 +174,17 @@ nasm_preproc_destroy(yasm_preproc *preproc)
         yasm_xfree(preproc_nasm->line);
     if (preproc_nasm->file_name)
         yasm_xfree(preproc_nasm->file_name);
+    if (preproc_nasm->in)
+        fclose(preproc_nasm->in);
     yasm_xfree(preproc);
-    if (preproc_deps)
-        yasm_xfree(preproc_deps);
+    while (!STAILQ_EMPTY(preproc_deps)) {
+        preproc_dep *dep = STAILQ_FIRST(preproc_deps);
+        STAILQ_REMOVE_HEAD(preproc_deps, link);
+        yasm_xfree(dep->name);
+        yasm_xfree(dep);
+    }
+    yasm_xfree(preproc_deps);
+    yasm_xfree(nasm_src_set_fname(NULL));
 }
 
 static char *
@@ -219,10 +228,6 @@ nasm_preproc_add_dep(char *name)
 {
     preproc_dep *dep;
 
-    /* If not processing dependencies, simply return */
-    if (!preproc_deps)
-        return;
-
     /* Save in preproc_deps */
     dep = yasm_xmalloc(sizeof(preproc_dep));
     dep->name = yasm__xstrdup(name);
@@ -233,11 +238,6 @@ static size_t
 nasm_preproc_get_included_file(yasm_preproc *preproc, /*@out@*/ char *buf,
                                size_t max_size)
 {
-    if (!preproc_deps) {
-        preproc_deps = yasm_xmalloc(sizeof(struct preproc_dep_head));
-        STAILQ_INIT(preproc_deps);
-    }
-
     for (;;) {
         char *line;
 
