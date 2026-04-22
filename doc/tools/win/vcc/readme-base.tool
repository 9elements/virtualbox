Visual Studio Build Tools 2022 v17.11.5 from an AMD64 Windows 10 VM,
installed 2022-10-28 (11.5 was released 2024-08-13), and from an ARM64 Windows
11 VM installed the same day (hopefully).

See https://learn.microsoft.com/en-us/visualstudio/releases/2022/release-notes 
for details on quality-of-life enhancements and how to love this update. ;-)

The initial AMD64 install very minimal: 
{
  "version": "1.0",
  "components": [
    "Microsoft.VisualStudio.Component.Roslyn.Compiler",
    "Microsoft.Component.MSBuild",
    "Microsoft.VisualStudio.Component.CoreBuildTools",
    "Microsoft.VisualStudio.Workload.MSBuildTools",
    "Microsoft.VisualStudio.Component.Windows10SDK",
    "Microsoft.VisualStudio.Component.VC.CoreBuildTools",
    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    "Microsoft.VisualStudio.Component.VC.CMake.Project",
    "Microsoft.VisualStudio.Component.VC.ASAN",
    "Microsoft.VisualStudio.Component.VC.Llvm.Clang",
    "Microsoft.VisualStudio.Component.VC.Tools.ARM64EC",
    "Microsoft.VisualStudio.Component.VC.Tools.ARM64",
    "Microsoft.VisualStudio.Component.VC.Redist.MSM"
  ],
  "extensions": []
}

The AMD64 install was the modified by loading this configuration:
{
  "version": "1.0",
  "components": [
    "Microsoft.VisualStudio.Component.Roslyn.Compiler",
    "Microsoft.Component.MSBuild",
    "Microsoft.VisualStudio.Component.CoreBuildTools",
    "Microsoft.VisualStudio.Workload.MSBuildTools",
    "Microsoft.VisualStudio.Component.Windows10SDK",
    "Microsoft.VisualStudio.Component.VC.CoreBuildTools",
    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    "Microsoft.VisualStudio.Component.VC.Redist.14.Latest",
    "Microsoft.VisualStudio.Component.VC.CMake.Project",
    "Microsoft.VisualStudio.Component.TestTools.BuildTools",
    "Microsoft.VisualStudio.Component.VC.ASAN",
    "Microsoft.VisualStudio.Component.TextTemplating",
    "Microsoft.VisualStudio.Component.VC.CoreIde",
    "Microsoft.VisualStudio.ComponentGroup.NativeDesktop.Core",
    "Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset",
    "Microsoft.VisualStudio.Component.VC.Llvm.Clang",
    "Microsoft.VisualStudio.Workload.VCTools",
    "Microsoft.VisualStudio.Component.VC.Tools.ARM64EC",
    "Microsoft.VisualStudio.Component.VC.Tools.ARM64",
    "Microsoft.VisualStudio.Component.VC.Tools.ARM",
    "Microsoft.VisualStudio.Component.VC.Redist.MSM"
  ],
  "extensions": []
}


Since we only need the missing host binaries from the ARM64 install, it was 
rather limited as well:
{
  "version": "1.0",
  "components": [
    "Microsoft.VisualStudio.Component.Roslyn.Compiler",
    "Microsoft.Component.MSBuild",
    "Microsoft.VisualStudio.Component.CoreBuildTools",
    "Microsoft.VisualStudio.Workload.MSBuildTools",
    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    "Microsoft.VisualStudio.Component.VC.Redist.14.Latest",
    "Microsoft.VisualStudio.Component.VC.CMake.Project",
    "Microsoft.VisualStudio.Component.VC.ASAN",
    "Microsoft.VisualStudio.Component.VC.Tools.ARM64EC",
    "Microsoft.VisualStudio.Component.VC.Tools.ARM64",
    "Microsoft.VisualStudio.Component.VC.Redist.MSM"
  ],
  "extensions": []
}

The AMD64 and ARM64 installation both uses the same installation path, so 
the package all contains files and directories found under
"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\", thus all 
paths given here are relative to that directory.


This base package contains the common bits: include, crt & modules.
7-zip command for base package (on AMD64):
  7z a -mx=9 ^
    -r ^
    win.vcc.v14.3.17.11.5-base.7z ^
    readme-base.tool ^
    readme-llvm-exclude-list.tool ^
    env-amd64.cmd ^
    env-arm64.cmd ^
    env-x86.cmd ^
    Tools\MSVC\14.41.34120\crt\* ^
    Tools\MSVC\14.41.34120\include\* ^
    Tools\MSVC\14.41.34120\modules\*

The target-amd64-x86 package includes the libraries & redistributables for 
AMD64 and x86.  7-zip command for the package (on AMD64):
  7z a -mx=9 ^
    -r ^
    win.vcc.v14.3.17.11.5-target-amd64-x86.7z ^
    -ir-!Tools\MSVC\14.41.34120\lib\x64\* ^
    -xr!Tools\MSVC\14.41.34120\lib\x64\libconcrt* ^
    -xr!Tools\MSVC\14.41.34120\lib\x64\vccorlib* ^
    -xr!Tools\MSVC\14.41.34120\lib\x64\enclave ^
    -xr!Tools\MSVC\14.41.34120\lib\x64\store ^
    -xr!Tools\MSVC\14.41.34120\lib\x64\uwp ^
    -ir-!Tools\MSVC\14.41.34120\lib\x86\* ^
    -xr!Tools\MSVC\14.41.34120\lib\x86\libconcrt* ^
    -xr!Tools\MSVC\14.41.34120\lib\x86\vccorlib* ^
    -xr!Tools\MSVC\14.41.34120\lib\x86\store ^
    -xr!Tools\MSVC\14.41.34120\lib\x86\uwp ^
    Redist\MSVC\14.40.33807\x64\Microsoft.VC143.CRT\* ^
    Redist\MSVC\14.40.33807\x86\Microsoft.VC143.CRT\* ^
    Redist\MSVC\14.40.33807\debug_nonredist\x64\Microsoft.VC143.DebugCRT\* ^
    Redist\MSVC\14.40.33807\debug_nonredist\x86\Microsoft.VC143.DebugCRT\* 

The target-arm64 package includes the libraries & redistributables for ARM64.  
7-zip command for the package (on AMD64):
  7z a -mx=9 ^
    -r ^
    win.vcc.v14.3.17.11.5-target-arm64.7z ^
    -ir-!Tools\MSVC\14.41.34120\lib\arm64\* ^
    -xr!Tools\MSVC\14.41.34120\lib\arm64\libconcrt* ^
    -xr!Tools\MSVC\14.41.34120\lib\arm64\vccorlib* ^
    -xr!Tools\MSVC\14.41.34120\lib\arm64\enclave ^
    -xr!Tools\MSVC\14.41.34120\lib\arm64\store ^
    -xr!Tools\MSVC\14.41.34120\lib\arm64\uwp ^
    Redist\MSVC\14.40.33807\arm64\Microsoft.VC143.CRT\* ^
    Redist\MSVC\14.40.33807\debug_nonredist\arm64\Microsoft.VC143.DebugCRT\*

The amd64 host package includes compilers targeting amd64, arm64, & x86 hosted
on amd64. 7-zip command for the package (on AMD64):
  7z a -mx=9 ^
    -r ^
    win.vcc.v14.3.17.11.5-host-amd64.7z ^
    Tools\MSVC\14.41.34120\bin\Hostx64\arm64\* ^
    Tools\MSVC\14.41.34120\bin\Hostx64\x64\* ^
    Tools\MSVC\14.41.34120\bin\Hostx64\x86\*

The arm64 host package includes compilers targeting amd64, arm64, & x86 hosted
on arm64. 7-zip command for the package (on ARM64):
  7z a -mx=9 ^
    -r ^
    win.vcc.v14.3.17.11.5-host-arm64.7z ^
    Tools\MSVC\14.41.34120\bin\Hostarm64\arm64\* ^
    Tools\MSVC\14.41.34120\bin\Hostarm64\x64\* ^
    Tools\MSVC\14.41.34120\bin\Hostarm64\x86\*


The Llvm stuff is seriously enormous, the Tools\Llvm\x64 sub-tree takes almost 
2.4 GiB of disk space.  There are two reasons for this: 
  1. The brilliant LLVM & M$ guys statically links the content libclang.dll 
     and llvm-c.dll into every tool instead of using the DLLs and doing 
     dynamic linking. 
  2. A few of the core files are symlinked, thus multiplying the hurt the 
     static linking does.   

In addition, the lldb.exe and lldb-vscode.exe binaries actually use dynamic 
linking but the fantastic guys and M$ doesn't ship hte liblldb.dll they require
and have ignored reports about this for years.  OTOH, the lldb-server.exe seems
to work.


So, to avoid wasting GiGs of space on what is chiefly an ARM64 assembler to us, 
the package has been stripped down quite a bit (saving > 1.9GiB per subpackage).

The list of removed files are found in readme-llvm-exclude-list.tool.

When packing, we create the symlink files in a separate tree structure and add 
these to the packages in a 2nd step.  This requires a recent (>23.x) 7-Zip.
Here's the basic bit for creating the symlinks tree:
   setlocal enabledelayedexpansion
   for %%i in (symlinks\Tools\Llvm\bin symlinks\Tools\Llvm\x64\bin symlinks\Tools\Llvm\ARM64\bin) do (
       kmk_mkdir -p "%%i"
       kmk_ln -s clang.exe              "%%i\clang++.exe"          
       kmk_ln -s clang.exe               %%i\clang-cl.exe           
       kmk_ln -s clang.exe               %%i\clang-cpp.exe          
       kmk_ln -s lld.exe                 %%i\ld.lld.exe             
       kmk_ln -s lld.exe                 %%i\ld64.lld.exe           
       kmk_ln -s lld.exe                 %%i\lld-link.exe           
       kmk_ln -s llvm-symbolizer.exe     %%i\llvm-addr2line.exe     
       kmk_ln -s llvm-ar.exe             %%i\llvm-dlltool.exe       
       kmk_ln -s llvm-ar.exe             %%i\llvm-lib.exe           
       kmk_ln -s llvm-objdump.exe        %%i\llvm-otool.exe         
       kmk_ln -s llvm-ar.exe             %%i\llvm-ranlib.exe        
       kmk_ln -s lld.exe                 %%i\wasm-ld.exe            
   )
   endlocal


The llvm amd64 package includes the llvm/x64 tree. 7-zip command for the 
package (on AMD64):
  7z a -mx=9 ^
    -r ^
    win.vcc.v14.3.17.11.5-llvm-amd64.7z ^
    -x@readme-llvm-exclude-list.tool ^
    Tools\Llvm\x64\*
  cd symlinks
  7z.exe a -mx=9 -snl ^
    -r ^
    ../win.vcc.v14.3.17.11.5-llvm-amd64.7z ^
    Tools\Llvm\x64\*


The llvm arm64 package includes the llvm/ARM64 tree. 7-zip command for the 
package (on AMD64):
  7z a -mx=9 ^
    -r ^
    win.vcc.v14.3.17.11.5-llvm-arm64.7z ^
    -x@readme-llvm-exclude-list.tool ^
    Tools\Llvm\ARM64\*
  cd symlinks
  7z.exe a -mx=9 -snl ^
    -r ^
    ../win.vcc.v14.3.17.11.5-llvm-arm64.7z ^
    Tools\Llvm\ARM64\*

The llvm x86 package includes the llvm/bin and llvm/x86 trees. 7-zip command 
for the package (on AMD64):
  7z a -mx=9 ^
    -r ^
    win.vcc.v14.3.17.11.5-llvm-x86.7z ^
    -x@readme-llvm-exclude-list.tool ^
    Tools\Llvm\bin\* ^
    Tools\Llvm\lib\*
  cd symlinks
  7z.exe a -mx=9 -snl ^
    -r ^
    ../win.vcc.v14.3.17.11.5-llvm-x86.7z ^
    Tools\Llvm\bin\*

This package contains an bugfixed env-arm64.cmd:
7-zip command for base package (on AMD64):
  7z a -mx=9 win.vcc.v14.3.17.11.5-env-update-1.7z env-arm64.cmd readme-env-update.tool

