Doxygen 1.9.6 for win/amd64, static build using Visual C++ 2019.

0. Loaded trunk build env on Windows.

1. Downloaded https://www.doxygen.nl/files/doxygen-1.9.6.src.tar.gz
(md5: 5f7ab15c8298d013c5ef205a4febc7b4) and unpacked it.

2. Downloaded cmake-3.26.3-windows-x86_64.zip (md5: 7e8db15d4d2c88de26ad4d9c0a95931c) from
https://objects.githubusercontent.com/github-production-release-asset-2e65be/537699/02cc835b-b85d-4d45-9ab4-798142404d5b?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIWNJYAX4CSVEH53A%2F20230509%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20230509T204331Z&X-Amz-Expires=300&X-Amz-Signature=ffd2535631fd4ef202bb0511a1f12ff961678fa02d5ec55487f6304f07509866&X-Amz-SignedHeaders=host&actor_id=15661096&key_id=0&repo_id=537699&response-content-disposition=attachment%3B%20filename%3Dcmake-3.26.3-windows-x86_64.zip&response-content-type=application%2Foctet-stream
and unpacked it.

3. Created a hackbin directory and copied over tools\win.x86\win_flex_bison\v3.7.4\*
(whole tree) and renamed win_flex.exe to flex.exe and win_bison.exe to bison.exe.
Added the hackbin directory to the start of the PATH.

4. cd doxygen-1.9.6

5. mkdir build && cd build

6. ..\..\cmake-3.26.3-windows-x86_64\bin\cmake.exe ^
        -G "Visual Studio 16 2019" ^
        E:\vbox\doxygen\doxygen-1.9.6 ^
        -Dbuild_wizard=NO ^
        -Dbuild_app=NO ^
        -Dbuild_doc=NO ^
        -Dwin_static=ON

   Where 'E:\vbox\doxygen\doxygen-1.9.6' should be replaced with the actual
   doxygen source location.

7. Opened doxygen.sln from the Visual Studio 2019 (Pro) IDE and hit F7 to
   build the solution.

8. Copied the resulting doxygen.exe binary from build\bin\doxygen.exe to
   staging directory together with this file and zipped them up:
        7z a -mx=9 -r ../win.amd64.doxygen.v1.9.6.7z .

9. Bob's your uncle.
