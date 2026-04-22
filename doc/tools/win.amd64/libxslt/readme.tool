xsltproc from libxslt v1.1.42 and xml tools from libxml2 v2.13.4 w/ 869e3fd421835e4350e920834b8b0a556e06245e.

Downloaded:
 1. https://gitlab.gnome.org/GNOME/libxslt/-/archive/v1.1.42/libxslt-v1.1.42.zip
    md5: 6ed97eafe8df1a84394e712259c202c3
 2. https://gitlab.gnome.org/GNOME/libxml2/-/archive/v2.13.4/libxml2-v2.13.4.zip
    md5: 024d8a12de527911189ec70442f0a70c
 3. https://gitlab.gnome.org/GNOME/libxml2/-/commit/869e3fd421835e4350e920834b8b0a556e06245e.patch
    Fixing validate-sdkref. See https://gitlab.gnome.org/GNOME/libxml2/-/issues/816

Steps to build & pack:
- On a box with Visual Studio 2022 Build Tools and CMake 3.30.5 installed, opened 
  a command  line, loading the VBox trunk environment (around r165721).
- Ran tools\win.x86\sdk\v10.0.22000.0\env-amd64.cmd.
- Unzipped the two in a working directory 'E:\vbox\tools\xsltproc'.
- cd libxml2-v2.13.4
- Applied 869e3fd421835e4350e920834b8b0a556e06245e.patch
- mkdir build
- cd build
- "c:\Program Files\CMake\bin\cmake.exe" -D LIBXML2_WITH_ICONV=OFF -D LIBXML2_WITH_PYTHON=OFF -A x64 -B amd64 ..
- cd amd64
- "c:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe" libxml2.sln -p:Configuration=Release
- "c:\Program Files\CMake\bin\cmake.exe" --install . --prefix "%_CWD\installed" # ASSUMES TCC
- cd ..
- "c:\Program Files\CMake\bin\cmake.exe" -D LIBXML2_WITH_ICONV=OFF -D LIBXML2_WITH_PYTHON=OFF -A ARM64 -B arm64 ..
- cd arm64
- "c:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe" libxml2.sln -p:Configuration=Release
- "c:\Program Files\CMake\bin\cmake.exe" --install . --prefix "%_CWD\installed" # ASSUMES TCC
- cd ..\..\..\libxslt-v1.1.42
- mkdir build
- cd build
- "c:\Program Files\CMake\bin\cmake.exe" -D LIBXSLT_WITH_THREADS=OFF -D LIBXSLT_WITH_PYTHON=OFF -D LibXml2_DIR=E:\vbox\tools\xsltproc\libxml2-v2.13.4\build\amd64\installed\lib\cmake\libxml2-2.13.4 -A x64 -B amd64 ..
- cd amd64
- "c:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe" libxslt1.sln -p:Configuration=Release
- "c:\Program Files\CMake\bin\cmake.exe" --install . --prefix "%_CWD\installed" # ASSUMES TCC
- copy E:\vbox\tools\xsltproc\libxml2-v2.13.4\build\amd64\installed\bin\* installed\bin\
- copy E:\vbox\tools\xsltproc\readme.tool installed\
- cd installed
- zip -9rX E:\vbox\tools\xsltproc\win.amd64.libxslt.10142-p1.zip readme.tool bin
- cd ..\..
- "c:\Program Files\CMake\bin\cmake.exe" -D LIBXSLT_WITH_THREADS=OFF -D LIBXSLT_WITH_PYTHON=OFF -D LibXml2_DIR=E:\vbox\tools\xsltproc\libxml2-v2.13.4\build\arm64\installed\lib\cmake\libxml2-2.13.4 -A ARM64 -B arm64 ..
- cd arm64
- "c:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe" libxslt1.sln -p:Configuration=Release
- "c:\Program Files\CMake\bin\cmake.exe" --install . --prefix "%_CWD\installed" # ASSUMES TCC
- copy E:\vbox\tools\xsltproc\libxml2-v2.13.4\build\arm64\installed\bin\* installed\bin\
- copy E:\vbox\tools\xsltproc\readme.tool installed\
- cd installed
- zip -9rX E:\vbox\tools\xsltproc\win.arm64.libxslt.10142-p1.zip readme.tool bin


xsltproc --version:
Using libxml 21304, libxslt 10142 and libexslt 823
xsltproc was compiled against libxml 21304, libxslt 10142 and libexslt 823
libxslt 10142 was compiled against libxml 21304
libexslt 823 was compiled against libxml 21304

