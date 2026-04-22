Yasm git head as per 2016-08-16 (the much wanted -Wno-segreg-in-64bit commit
0efd093199b725ede61737d19f4a411ed310a3aa).  Built on rhel3u5 targetting x86,
dynamically linked libc.

Notes about building:
    - Ran: ./autogen.sh --disable-nls
    - Had to build latest m4, autoconf, automake, and python 2.7 to
      get it configured and built on rhel3u5.
