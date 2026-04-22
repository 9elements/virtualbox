Yasm git head as per 2016-08-15 (the much wanted -Wno-segreg-in-64bit commit
51af4082cc898b122b88f11fd34033fc00fad81e).  Built on S10u11 targeting amd64.

Notes about building:
        - Had to edit YASM-VERSION-GEN.sh to point to /usr/bin/bash
          as /bin/sh had trouble running it.
        - Had to specify -m64 when running configure:
              CFLAGS="-m64" LDFLAGS="-m64" CPPFLAGS="-m64" ./autogen.sh
