Doxygen 1.9.6 for linux/amd64, minimal static build in WSL 1 (ubuntu 18.04,
linux 4.4).

1. Downloaded https://www.doxygen.nl/files/doxygen-1.9.6.src.tar.gz
(md5: 5f7ab15c8298d013c5ef205a4febc7b4) and unpacked it.

2. cd doxygen-1.9.6

3. mkdir build && cd build

4. cmake -G "Unix Makefiles" \
        -Dbuild_wizard=NO \
        -Dbuild_app=NO \
        -Dbuild_doc=NO \
        -DCMAKE_BUILD_TYPE=Release \
        "-DCMAKE_FIND_LIBRARY_SUFFIXES=.a" \
        "-ldl;-lz;-lpthread" \
        /mnt/e/vbox/doxygen/lnx/doxygen-1.9.6

   Where '/mnt/e/vbox/doxygen/lnx/doxygen-1.9.6' should be replaced with the
   actual doxygen source location.

5. Tweak the linking command to make it truely static:
      sed -e "s/-rdynamic/-rdynamic -static -Wl,--require-defined=pthread_self,--whole-archive -lpthread -lc -lstdc++ -Wl,--no-whole-archive/" \
         -i src/CMakeFiles/doxygen.dir/link.txt

   Note! The whole pthread is linked in to prevent calling a missing weak symbol
         reference in std::conditional_variable::wait().  Found this suggestion
         in https://gcc.gnu.org/bugzilla/show_bug.cgi?id=58909 which is the same
         or a related issue.

   Note! Unforuntately pthread_self is in libc.a rather than libpthread.a, so to
         avoid another crash calling a weak-symbol in Portable::system()/mutex
         code, the whole of libc.a is included as well.  And just to avoid more
         trouble, link in all of libstdc++.a as well.  It just costs ~2MB extra
         space, which isn't much of a difference for a 28MB binary.

6. make -j64

7. cd build/bin and copied in this file, then zipped it all up:
        ../../../../../svn/trunk/tools/linux.amd64/7zip/v22.01/7zz \
            a -mx=9 linux.amd64.doxygen.v1.9.6-r2.7z doxygen readme.tool

8. Done.
