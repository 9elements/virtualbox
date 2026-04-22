Taken from the Windows 11 Enterprise Windows Driver Kit (EWDK), March 14 2025.
EWDK_ge_release_svc_prod3_26100_250220-1537.iso
with SHA256=eea0eb5756ed7a8d24ecc1ba3c87c7880be60287d93175083afd07e7db325171.

Note: v10.0.26100.3323 contains important bugfixes which v10.0.26100.0 did
      not have, although MS also named v10.0.26100.3323 as v10.0.26100.0.

Copied "M:\Program Files\Windows Kits\10\" over to a temporary directory so
additional files like the readme*.tool and such could be added.

The tool is split up into several zip files to avoid wasting space and
time downloading them.  Here is the planned split (please note that we're
skipping a number of directories):

- win.sdk.v10.0.26100.3323-base.7z:
    * Include\10.0.26100.0\shared\
    * Include\10.0.26100.0\um\
    * Licenses\
    * SDKManifest.xml
    * VBox specific: env-x86.cmd
    * VBox specific: env-amd64.cmd
    * VBox specific: env-arm64.cmd
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-base.7z readme.tool Include\10.0.26100.0\shared\ Include\10.0.26100.0\um\ Licenses\ SDKManifest.xml env-*.cmd

- win.sdk.v10.0.26100.3323-bin-x86.7z:
    * bin\10.0.26100.0\x86\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-bin-x86.7z readme-bin-x86.tool bin\10.0.26100.0\x86\

- win.sdk.v10.0.26100.3323-bin-amd64.7z:
    * bin\10.0.26100.0\x64\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-bin-amd64.7z readme-bin-amd64.tool bin\10.0.26100.0\x64\

- win.sdk.v10.0.26100.3323-bin-arm64.7z:
    * bin\10.0.26100.0\arm64\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-bin-arm64.7z readme-bin-arm64.tool bin\10.0.26100.0\arm64\

- win.sdk.v10.0.26100.3323-lib-um-x86.7z:
    * Lib\10.0.26100.0\um\x86\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-lib-um-x86.7z readme-lib-um-x86.tool Lib\10.0.26100.0\um\x86\

- win.sdk.v10.0.26100.3323-lib-um-amd64.7z:
    * Lib\10.0.26100.0\um\x64\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-lib-um-amd64.7z readme-lib-um-amd64.tool Lib\10.0.26100.0\um\x64\ 

- win.sdk.v10.0.26100.3323-lib-um-arm64.7z:
    * Lib\10.0.26100.0\um\arm64\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-lib-um-arm64.7z readme-lib-um-arm64.tool Lib\10.0.26100.0\um\arm64\ 

- win.sdk.v10.0.26100.3323-ucrt.7z:
    * Include\10.0.26100.0\ucrt\
    * Source\10.0.26100.0\ucrt\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-ucrt.7z readme-ucrt.tool Include\10.0.26100.0\ucrt\ Source\10.0.26100.0\ucrt\

- win.sdk.v10.0.26100.3323-lib-ucrt-x86.7z:
    * Lib\10.0.26100.0\ucrt\x86\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-lib-ucrt-x86.7z readme-lib-ucrt-x86.tool Lib\10.0.26100.0\ucrt\x86\

- win.sdk.v10.0.26100.3323-lib-ucrt-amd64.7z:
    * Lib\10.0.26100.0\ucrt\x64\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-lib-ucrt-amd64.7z readme-lib-ucrt-amd64.tool Lib\10.0.26100.0\ucrt\x64\

- win.sdk.v10.0.26100.3323-lib-ucrt-arm64.7z:
    * Lib\10.0.26100.0\ucrt\arm64\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-lib-ucrt-arm64.7z readme-lib-ucrt-arm64.tool Lib\10.0.26100.0\ucrt\arm64\

- win.sdk.v10.0.26100.3323-winrt.7z:
    * Include\10.0.26100.0\cppwinrt\
    * Include\10.0.26100.0\winrt\
    * DesignTime\
    * Platforms\UAP\10.0.26100.0\
    * References\10.0.26100.0\
    * UnionMetadata\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-winrt.7z readme-winrt.tool Include\10.0.26100.0\cppwinrt\ Include\10.0.26100.0\winrt\ DesignTime\ Platforms\UAP\10.0.26100.0\ References\10.0.26100.0\ UnionMetadata\

- win.sdk.v10.0.26100.3323-km.7z:
    * Include\10.0.26100.0\km\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-km.7z readme-km.tool Include\10.0.26100.0\km\

- win.sdk.v10.0.26100.3323-lib-km-amd64.7z:
    * Lib\10.0.26100.0\km\x64\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-lib-km-amd64.7z readme-lib-km-amd64.tool Lib\10.0.26100.0\km\x64\

- win.sdk.v10.0.26100.3323-lib-km-arm64.7z:
    * Lib\10.0.26100.0\km\arm64\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-lib-km-arm64.7z readme-lib-km-arm64.tool Lib\10.0.26100.0\km\arm64\

- win.sdk.v10.0.26100.3323-debuggers-x86.7z:
    * Debuggers\x86\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-debuggers-x86.7z readme-debugger-x86.tool Debuggers\x86\

- win.sdk.v10.0.26100.3323-debuggers-amd64.7z:
    * Debuggers\x64\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-debuggers-amd64.7z readme-debugger-amd64.tool Debuggers\x64\

- win.sdk.v10.0.26100.3323-debuggers-arm64.7z:
    * Debuggers\x64\
    7z a -mx=9 -r win.sdk.v10.0.26100.3323-debuggers-arm64.7z readme-debugger-arm64.tool Debuggers\arm64\


When preparing the individual packages, the individual readmes where
just symlinked (kmk_ln -s readme.tool readme-<package>.tool) to this one.


Zipping it up:
    kmk_sed -e "/^ *7z a/!d" -e "s/$/ \&\& ^/" -e "/readme.tool/d" -e "s/^.* \(readme-[^ ]*.tool\) .*$/kmk_ln -s readme.tool \1/" readme.tool > symlink-readmes.cmd
    kmk_sed -e "/^ *7z a/!d" -e "s/$/ \&\& ^/" readme.tool > zip-it-up.cmd
    symlink-readmes.cmd
    zip-it-up.cmd

Checksumming it (in tcc):
    for %i in (*.7z) do ( echo %i_SIZE         := %@FILESIZE[%i]& echo %i_MD5           := %@WORD[0,%@EXECSTR[kmk_md5sum -b %i]] )
