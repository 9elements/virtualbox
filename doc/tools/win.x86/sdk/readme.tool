Taken from the Windows 11 Enterprise Windows Driver Kit (EWDK),
en-us_windows_11_enterprise_windows_driver_kit_x64_x86_arm64arm32_dvd_7decf3fb.iso
with SHA256=EE452896A70425179A93A89BCA33CDB51D52250601EE6BF5EB93E504F9ACE792.

Copied "L:\Program Files\Windows Kits\10\" over to a temporary directory so
additional files like the readme*.tool and such could be added.

The tool is split up into several zip files to avoid wasting space and
time downloading them.  Here is the planned split (please note that we're
skipping a number of directories):

- win.x86.sdk.v10.0.22000.0-base.7z:
    * Include\10.0.22000.0\shared\
    * Include\10.0.22000.0\um\
    * Licenses\
    * SDKManifest.xml
    * VBox specific: env-x86.cmd
    * VBox specific: env-amd64.cmd
    7z a -mx=9 -r win.x86.sdk.v10.0.22000.0-base.7z readme.tool Include\10.0.22000.0\shared\ Include\10.0.22000.0\um\ Licenses\ SDKManifest.xml env-*.cmd

- win.x86.sdk.v10.0.22000.0-bin.7z:
    * bin\10.0.22000.0\x64\
    * bin\10.0.22000.0\x86\
    7z a -mx=9 -r win.x86.sdk.v10.0.22000.0-bin.7z readme-bin.tool bin\10.0.22000.0\x64\ bin\10.0.22000.0\x86\

- win.x86.sdk.v10.0.22000.0-lib.7z:
    * Lib\10.0.22000.0\um\x64\
    * Lib\10.0.22000.0\um\x86\
    7z a -mx=9 -r win.x86.sdk.v10.0.22000.0-lib.7z readme-lib.tool Lib\10.0.22000.0\um\x64\ Lib\10.0.22000.0\um\x86\

- win.x86.sdk.v10.0.22000.0-ucrt.7z:
    * Include\10.0.22000.0\ucrt\
    * Lib\10.0.22000.0\ucrt\x64\
    * Lib\10.0.22000.0\ucrt\x86\
    * Source\10.0.22000.0\ucrt\
    * Redist\10.0.22000.0\ucrt\DLLS\x64\
    * Redist\10.0.22000.0\ucrt\DLLS\x86\
    7z a -mx=9 -r win.x86.sdk.v10.0.22000.0-ucrt.7z readme-ucrt.tool  Include\10.0.22000.0\ucrt\ Lib\10.0.22000.0\ucrt\x64\ Lib\10.0.22000.0\ucrt\x86\ Source\10.0.22000.0\ucrt\ Redist\10.0.22000.0\ucrt\DLLS\x64\ Redist\10.0.22000.0\ucrt\DLLS\x86\

- win.x86.sdk.v10.0.22000.0-winrt.7z:
    * Include\10.0.22000.0\cppwinrt\
    * Include\10.0.22000.0\winrt\
    * DesignTime\
    * Platforms\UAP\10.0.22000.0\
    * References\10.0.22000.0\
    * UnionMetadata\
    7z a -mx=9 -r win.x86.sdk.v10.0.22000.0-winrt.7z readme-winrt.tool Include\10.0.22000.0\cppwinrt\ Include\10.0.22000.0\winrt\ DesignTime\ Platforms\UAP\10.0.22000.0\ References\10.0.22000.0\ UnionMetadata\

- win.x86.sdk.v10.0.22000.0-km.7z:
    * Include\10.0.22000.0\km\
    * Lib\10.0.22000.0\km\x64\
    * Lib\10.0.22000.0\km\x86\
    * Lib\win7\
    * Lib\win8\km\x64\
    * Lib\win8\km\x86\
    * Lib\winv6.3\km\x64\
    * Lib\winv6.3\km\x86\
    7z a -mx=9 -r win.x86.sdk.v10.0.22000.0-km.7z readme-km.tool Include\10.0.22000.0\km\ Lib\10.0.22000.0\km\x64\ Lib\10.0.22000.0\km\x86\ Lib\win7\ Lib\win8\km\x64\ Lib\win8\km\x86\ Lib\winv6.3\km\x64\ Lib\winv6.3\km\x86\

- win.x86.sdk.v10.0.22000.0-debuggers-amd64.7z:
    * Debuggers\x64\
    7z a -mx=9 -r win.x86.sdk.v10.0.22000.0-debuggers-amd64.7z readme-debugger-amd64.tool Debuggers\x64\

- win.x86.sdk.v10.0.22000.0-debuggers-x86.7z:
    * Debuggers\x86\
    7z a -mx=9 -r win.x86.sdk.v10.0.22000.0-debuggers-x86.7z readme-debugger-x86.tool Debuggers\x86\


Note. The Windows performance toolkit and application certification kit are not included in
      the EWDK, so unlike the 18362.1 SDK there are no win.x86.sdk.v10.0.22000.0-perf.7z
      or win.x86.sdk.v10.0.22000.0-appcert.7z files.


When preparing the individual packages, the individual readmes where
just symlinked (kmk_ln -s readme.tool readme-<package>.tool) to this one.


Zipping it up:
    kmk_sed -e "/^ *7z a/!d" -e "s/$/ \&\& ^/" readme.tool > zip-it-up.cmd
    zip-it-up.cmd

Checksumming it:
    for %i in (*.7z) do ( echo %i_SIZE         := %@FILESIZE[%i]& echo %i_MD5           := %@WORD[0,%@EXECSTR[kmk_md5sum -b %i]] )
