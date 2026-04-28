# Intel PXE + VBox PCnet-PCI & E1000 UNDI drivers

## Usage hints

DHCP discovery and TFTP download may be interrupted by pressing Esc. The
PXE code will exit and further devices in boot list will be tried.


## Design notes

The ROM image is a LOM-style binary containing both PXE base code (BC) and
UNDI. The base code could be part of system BIOS, but that wouldn't gain
anything and this way the entire ROM can be ignored unless booting from LAN.

The PCnet driver is very simple. Because buffers cannot be dynamically
allocated, only a single transmit and single receive buffer is used. For
transmit this is unlikely to be a problem, but receive could possibly benefit
from multiple buffers. Unfortunately each additional buffer means 1.5KB less
conventional memory for UNDI clients.

The entire ROM is currently about 36KB large. The UNDI driver steals 12KB
of conventional memory, ie. DOS boots using NDIS.DOS will only see 628KB
total of conventional memory. It is unlikely that the memory requirements
could be significantly reduced.


## Intel PXE

This is based on the Intel PXE 2.0 SDK build 083 release.  This used to be
available to download from intel.com (https://developer.intel.com/ial/WfM/tools/pxesdk20/index.htm)
back in the day.  It can still be found in various place, including
https://archive.org/details/pxe20-sdk-3.0.083.


### vbox-to-sdk-mapping.txt

This file maps VBox files to the SDK files.

The lines containing actual mappings have exactly two words in them, i.e. the
VBox filename followed by the SDK filename.  All other lines must have a
different word count.  This allows for simple loop usage in JP Soft's TCC.EXE:

    for %i in (@vbox-to-sdk-mapping.txt) do if %@WORDS[%i] EQU 2 (
        echo sdk=%@WORD[1,%i] vbox=%@WORD[0,%i]
    )

For instance, populating the directory with files from the SDK:

    for %i in (@vbox-to-sdk-mapping.txt) do if %@WORDS[%i] EQU 2 copy %PXESDK%\%@WORD[1,%i] %@WORD[0,%i]

Then apply the patch:

    patch -l -p1 -i .\vbox-pxe.patch

Create virgin tree for diffing:

    kmk_mkdir -p ../PXE-Org/client ../PXE-Org/include ../PXE-Org/romlib ../PXE-Org/tools/makerom ../PXE-Org/tools/romcksum
    for %i in (@vbox-to-sdk-mapping.txt) do if %@WORDS[%i] EQU 2 copy %PXESDK%\%@WORD[1,%i] ..\PXE-Org\%@WORD[0,%i]

Or re-generate the patch:

    (cd .. && for %i in (@PXE\vbox-to-sdk-mapping.txt) do if %@WORDS[%i] EQU 2 diff -wU1 PXE-Org/%@WORD[0,%i] PXE/%@WORD[0,%i]) > .\PXE\vbox-pxe.patch


## Building

### wmake

The build system is temporary. The required tools are Open Watcom 1.7
(available from http://www.openwatcom.org/) and Microsoft MASM 6.11 (only
ML.EXE is needed from the MASM package). Building on non-Windows hosts is
not likely to be easy at this point.

The makefiles assume that Open Watcom tools and MASM are installed and
the environment is set up appropriately (especially PATH). To build the
ROM, run `wmake` in the following directories:

tools/makerom
tools/romcksum
romlib
client

The `client` directory must be built last, otherwise the build order doesn't
matter. The finished ROM image will be in client/pxenic.bin.

It is possible to run `wmake DEBUG=1` in `romlib` and `client` directories.
This will include a number of debug printouts into the ROM.


### kBuild

With ml.exe in the PATH and open watcom in tools/common, it can be built by
setting `PXE_EXPERIMENTAL_BUILD_SETUP=1`. For example:

    kmk PXE_EXPERIMENTAL_BUILD_SETUP=1

