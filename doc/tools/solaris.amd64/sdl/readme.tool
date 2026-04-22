This is vanilla libSDL-1.2.13 taken from the SDL website. No changes were necessary and no extra configuration options were needed.

For building on my S10u5 box, only the PATH needed to be updated to reflect the necessary tools; namely:

PATH=$PATH:/usr/sfw/bin:/usr/ccs/bin:/opt/csw/bin
./configure CFLAGS=-m64 LDFLAGS=-m64
make
make install DESTDIR=/prefix

Ramshankar, 20081117


