Open Watcom v1.9 GNU/Linux binaries with stat fix.

This was rebuilt from sources and with the below patch.  In addition to the
patches the lib386/dos directory was copied to ./rel2 to deal with dll
linking issues (codeview.dbg, ++).  Only a selection of the files in binl/
have been included in this update.

The stat, lstat, fstat and access problem is that the stat structure used by
the Open Watcom linux CRT had 32-bit inode and device fields.  The below patch
just uses the 64-bit stat structure instead.  It has 64-bit fields for inodes
and devices.



diff -ru virgin-OW19/bld/clib/linux/c/fstat.c OW19/bld/clib/linux/c/fstat.c
--- virgin-OW19/bld/clib/linux/c/fstat.c	2010-06-02 20:11:55.000000000 +0200
+++ OW19/bld/clib/linux/c/fstat.c	2018-07-13 12:48:28.532908579 +0200
@@ -35,6 +35,7 @@

 _WCRTLINK int fstat( int __fildes, struct stat * __buf )
 {
-    u_long res = sys_call2( SYS_fstat, __fildes, (u_long)__buf );
+    //u_long res = sys_call2( SYS_fstat, __fildes, (u_long)__buf );
+    u_long res = sys_call2( SYS_fstat64, __fildes, (u_long)__buf );
     __syscall_return( int, res );
 }
diff -ru virgin-OW19/bld/clib/linux/c/lstat.c OW19/bld/clib/linux/c/lstat.c
--- virgin-OW19/bld/clib/linux/c/lstat.c	2010-06-02 20:11:55.000000000 +0200
+++ OW19/bld/clib/linux/c/lstat.c	2018-07-13 12:48:28.532908579 +0200
@@ -36,6 +36,7 @@

 _WCRTLINK int lstat( const char *filename, struct stat * __buf )
 {
-    u_long res = sys_call2( SYS_lstat, (u_long)filename, (u_long)__buf );
+    u_long res = sys_call2( SYS_lstat64, (u_long)filename, (u_long)__buf );
+ //   u_long res = sys_call2( SYS_lstat, (u_long)filename, (u_long)__buf );
     __syscall_return( int, res );
 }
diff -ru virgin-OW19/bld/clib/linux/c/stat.c OW19/bld/clib/linux/c/stat.c
--- virgin-OW19/bld/clib/linux/c/stat.c	2010-06-02 20:11:56.000000000 +0200
+++ OW19/bld/clib/linux/c/stat.c	2018-07-13 12:48:28.532908579 +0200
@@ -35,6 +35,7 @@

 _WCRTLINK int stat( const char *filename, struct stat * __buf )
 {
-    u_long res = sys_call2( SYS_stat, (u_long)filename, (u_long)__buf );
+    u_long res = sys_call2( SYS_stat64, (u_long)filename, (u_long)__buf );
+    //u_long res = sys_call2( SYS_stat, (u_long)filename, (u_long)__buf );
     __syscall_return( int, res );
 }
diff -ru virgin-OW19/bld/dip/imp.mif OW19/bld/dip/imp.mif
--- virgin-OW19/bld/dip/imp.mif	2010-06-02 20:13:52.000000000 +0200
+++ OW19/bld/dip/imp.mif	2018-07-13 13:23:18.345195993 +0200
@@ -91,9 +91,9 @@
 !ifeq host_os rdos
         set WLINK_LNK=$(wlink_dir)/prebuild/wlsystem.lnk
 !ifdef __UNIX__
-linker = *$(wlink_dir)/prebuild/wl.exe op quiet
+linker = *$(wlink_dir)/prebuild/wl.exe op verbose
 !else
-linker = *$(wlink_dir)\prebuild\wl.exe op quiet
+linker = *$(wlink_dir)\prebuild\wl.exe op verbose
 !endif
 !endif
 !endif
diff -ru virgin-OW19/bld/hdr/linux/arch/i386/sys/stat.h OW19/bld/hdr/linux/arch/i386/sys/stat.h
--- virgin-OW19/bld/hdr/linux/arch/i386/sys/stat.h	2010-06-02 20:16:31.000000000 +0200
+++ OW19/bld/hdr/linux/arch/i386/sys/stat.h	2018-07-13 12:48:28.532908579 +0200
@@ -1,3 +1,28 @@
+#if 1 /* Same as stat64 */
+struct stat {
+        unsigned long long      st_dev;
+        unsigned char           __pad0[4];
+#define STAT64_HAS_BROKEN_ST_INO        1
+        unsigned long           __st_ino;
+        unsigned int            st_mode;
+        unsigned int            st_nlink;
+        unsigned long           st_uid;
+        unsigned long           st_gid;
+        unsigned long long      st_rdev;
+        unsigned char           __pad3[4];
+        long long               st_size;
+        unsigned long           st_blksize;
+        unsigned long           st_blocks;  /* Number 512-byte blocks allocated. */
+        unsigned long           __pad4;     /* future possible st_blocks high bits */
+        time_t                  st_atime;
+        unsigned long           st_atime_nsec;
+        time_t                  st_mtime;
+        unsigned int            st_mtime_nsec;
+        time_t                  st_ctime;
+        unsigned long           st_ctime_nsec;
+        unsigned long long      st_ino;
+};
+#else
 struct stat {
         unsigned long  st_dev;
         unsigned long  st_ino;
@@ -18,6 +43,7 @@
         unsigned long  __unused4;
         unsigned long  __unused5;
 };
+#endif

 /* This matches struct stat64 in glibc2.1, hence the absolutely
  * insane amounts of padding around dev_t's.
diff -ru virgin-OW19/build.sh OW19/build.sh
--- virgin-OW19/build.sh	2010-06-02 20:31:02.000000000 +0200
+++ OW19/build.sh	2018-07-13 12:49:12.925334628 +0200
@@ -4,11 +4,15 @@
 # using the GNU C/C++ compiler tools. If you already have a working
 # Open Watcom compiler, you do not need to use the bootstrap process

-if [ -f setvars ]; then
-    . setvars
+if [ -f ./setvars ]; then
+    . ./setvars
 else
-    . setvars.sh
+    . ./setvars.sh
 fi
+
+# Adjust PATH and include 32-bit compiler wrappers.
+export PATH=/mnt/scratch/openwatcom/1.9.0/32bit-bin:$PATH
+
 if [ ! -f $DEVDIR/build/binl/wtouch ]; then
     cp -p `which touch` $DEVDIR/build/binl/wtouch
 fi
@@ -19,5 +23,5 @@
 wmake -h -f ../linux386/makefile builder.exe bootstrap=1
 cd ../..
 export BUILDMODE=bootstrap
-builder rel2 os_linux
+builder -i -v -v -v rel2 os_linux
 unset BUILDMODE
diff -ru virgin-OW19/cmnvars.sh OW19/cmnvars.sh
--- virgin-OW19/cmnvars.sh	2010-06-02 20:31:02.000000000 +0200
+++ OW19/cmnvars.sh	2018-07-13 12:52:28.631191886 +0200
@@ -22,7 +22,7 @@
 export RELROOT=$OWROOT/rel2
 export DWATCOM=$WATCOM
 export DOC_ROOT=$OWROOT/docs
-export INCLUDE=$WATCOM/lh
+export INCLUDE=$WATCOM/lh:/mnt/scratch/vbox/svn/trunk/tools/common/openwatcom/v1.9-r2/h/os2:
 export EDPATH=$WATCOM/eddat
 export WIPFC=$WATCOM/wipfc
 export PATH=$OWBINDIR:$OWROOT/bat:$WATCOM/binl:$DOC_ROOT/cmds:$DEFPATH
diff -ru virgin-OW19/setvars.sh OW19/setvars.sh
--- virgin-OW19/setvars.sh	2010-06-02 20:36:48.000000000 +0200
+++ OW19/setvars.sh	2018-07-13 12:48:28.532908579 +0200
@@ -41,4 +41,4 @@
 export PREOBJDIR=prebuild

 # Invoke the script for the common environment
-source $OWROOT/cmnvars.sh
+. $OWROOT/cmnvars.sh

