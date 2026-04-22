Yasm git head as per 2016-08-17 (the much wanted -Wno-segreg-in-64bit commit
51af4082cc898b122b88f11fd34033fc00fad81e).  Built on centos4u8 targeting amd64,
dynamically linking with libc.

Notes about building:
    - Built python 2.7, autoconf, automake and m4.
    - Ran: ./autogen.sh --disable-nls
