gsoap_2.8.136.zip (sha256=64de6af1f6019810d91ca1497815fdff576e38dc2d9c7e3d3e9e1cbb443aeac3)
Apply patches inside this tools package:
    000-soapcpp2-msvc-mak-r1.patch
    000-stdsoap2-solaris-r1.patch

- Build soapcpp2 and wsdl2h on tinderlin4 (where it was staged, platform linux.amd64):
   o jails/enter-ol8-amd64-jail
   o cd gsoap, unpack, rename, apply patches.
   o ./configure --disable-c-locale --disable-ssl
   o the "--disable-c-locale" switch is needed to make things build on OL5
     since it considers locale_t as a GNU extension, and even newer distros
     consider it just semi-standardized even though it is part of POSIX 2008.
   o the "--disable-ssl" switch is only for disabling SSL support for wsdl2h
   o Make sure that flex and bison are installed.
   o make
   o Stage the base stuff:
     $ ( cd gsoap && rsync -avR bin import/stlvector.h stdsoap2.cpp stdsoap2.h /home/vbox/gsoap-2.8.136-staged/ )
   o rsync -av gsoap/src/soapcpp2 gsoap/wsdl/wsdl2h /home/vbox/gsoap-2.8.136-staged/bin/linux.amd64/
   o strip /home/vbox/gsoap-2.8.136-staged/bin/linux.amd64/*

- Build soapcpp2 and wsdl2h on tindermaca2 (platform linux.arm64):
   o ./configure --disable-c-locale --disable-ssl
   o cd gsoap, unpack, rename, apply patches.
   o the "--disable-c-locale" switch is to keep it compatible with the other UNIX builds
   o Make sure that flex and bison are installed.
   o the "--disable-ssl" switch is only for disabling SSL support for wsdl2h
   o make
   o rsync -av gsoap/src/soapcpp2 gsoap/wsdl/wsdl2h gsoap/bin/linux.arm64/
   o strip gsoap/bin/linux.arm64/*
   o scp -r gsoap/bin/linux.arm64 <user>@tinderlin4.de.oracle.com:/home/vbox/gsoap-2.8.136-staged/bin/

- Build soapcpp2 and wsdl2h on tindersol (platform solaris.x86):
   o cd gsoap, unpack, rename, apply patches.
   o ./configure --disable-c-locale --disable-ssl
   o the "--disable-c-locale" switch is to make things build on Solaris 11.3
     which has extremely outdated locale.h functionality coverage
   o the "--disable-ssl" switch is only for disabling SSL support for wsdl2h
   o Make sure that flex and bison are installed.
   o if 'configure' produces the warning aka 'Something went wrong bootstrapping makefile fragments ....'
   o then try './configure --disable-c-locale --disable-ssl MAKE="gmake" '  
   o Run 'make' or 'gmake' (depends from the previous step with 'configure')
   o rsync -av gsoap/src/soapcpp2 gsoap/wsdl/wsdl2h gsoap/bin/solaris.x86/
   o strip gsoap/bin/solaris.x86/*
   o scp -r gsoap/bin/solaris.x86 <user>@tinderlin4.de.oracle.com:/home/vbox/gsoap-2.8.136-staged/bin/

- Build soapcpp2 and wsdl2h on tindersol2 (platform solaris.amd64):
   o cd gsoap, unpack, rename, apply patches.
   o ./configure --disable-c-locale --disable-ssl
   o the "--disable-c-locale" switch is to make things build on Solaris 11.3
     which has extremely outdated locale.h functionality coverage
   o the "--disable-ssl" switch is only for disabling SSL support for wsdl2h
   o Make sure that flex and bison are installed.
   o Run 'make'.
   o rsync -av gsoap/src/soapcpp2 gsoap/wsdl/wsdl2h gsoap/bin/solaris.amd64/
   o strip gsoap/bin/solaris.amd64/*
   o scp -r gsoap/bin/solaris.amd64 <user>@tinderlin4.de.oracle.com:/home/vbox/gsoap-2.8.136-staged/bin/

- Build soapcpp2 on tinderwin (platform win.amd64):
   o ...\tools\win.x86\sdk\v7.1\env-amd64.cmd
   o ...\tools\win.x86\vcc\v10sp1\env-amd64.cmd
   o cd ...\gsoap\src
   o nmake -f Make_mvc.mak distclean
   o nmake -f Make_mvc.mak soapcpp2.exe
   o Signed it (optional).
   o cp soapcpp2.exe ..\bin\win.amd64\
   o scp ..\bin\win.amd64 <user>@tinderlin4.de.oracle.com:/home/vbox/gsoap-2.8.136-staged/bin/

- Build soapcpp2 & wsdl2h on tindermaca1 (platform darwin.arm64):
   o cd gsoap, unpack, rename, apply patches.
   o ./configure --disable-c-locale --disable-ssl
   o make LDFLAGS="-mmacosx-version-min=12"
   o rsync -av gsoap/src/soapcpp2 gsoap/wsdl/wsdl2h gsoap/bin/darwin.arm64/
   o strip gsoap/bin/darwin.arm64/*
   o scp gsoap/bin/darwin.arm64 <user>@tinderlin4.de.oracle.com:/home/vbox/gsoap-2.8.136-staged/bin/
   
- Build soapcpp2 & wsdl2h on tindermac2 (platform darwin.amd64):
   o cd gsoap, unpack, rename, apply patches.
   o ./configure --disable-c-locale --disable-ssl
   o make LDFLAGS="-mmacosx-version-min=11"
   o rsync -av gsoap/src/soapcpp2 gsoap/wsdl/wsdl2h gsoap/bin/darwin.amd64/
   o strip gsoap/bin/darwin.amd64/*
   o scp gsoap/bin/darwin.amd64 <user>@tinderlin4.de.oracle.com:/home/vbox/gsoap-2.8.136-staged/bin/

- Added this file and the patches.

- zip -r9X ../common.gsoap.v2.8.136-r3.zip .
