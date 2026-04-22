NASM git nasm-2.16.xx (branch) b9528913aa7e8aa8a2ae93065d22bbd12fe7b4fd with
the patches below applied.

Requires perl and git in the PATH.

Sketchy build steps for amd64:

  pushd e:/vbox/svn/trunk
  "tools/env.cmd"
  popd
  "e:/vbox/svn/trunk/tools/win/vcc/v14.3.17.11.5/env-amd64.cmd"
  "e:/vbox/svn/trunk/tools/win/sdk/v10.0.26100.0/env-amd64.cmd" --ucrt

  git clone https://github.com/netwide-assembler/nasm.git git-nasm-2.16.03-amd64
  cd git-nasm-2.16.03-arm64
  git checkout nasm-2.16.03

  git apply --stat E:\vbox\nasm\2024-11\readme.tool
  git apply --check --verbose E:\vbox\nasm\2024-11\readme.tool
  for %i in (1 2 3 4 5) do kmk_sed -ne "/^---patch-000%i/,/^---patch/{/^---patch/d;p}" E:\vbox\nasm\2024-11\readme.tool > vbox-000%i.patch
  for %i in (1 2 3 4 5) do git am --signoff vbox-000%i.patch

  kmk_touch config\config.h.in
  kmk_touch config\unconfig.h

  cmd /c nmake /f Mkfiles/msvc.mak EMPTY=kmk_touch

  zip -9Xj ..\win.amd64.nasm.v2.16.03-p1.zip nasm.exe ndisasm.exe E:\vbox\nasm\2024-11\readme.tool

Sketchy build steps for arm64:

  pushd e:/vbox/svn/trunk
  "tools/env.cmd"
  popd
  "e:/vbox/svn/trunk/tools/win/vcc/v14.3.17.11.5/env-arm64.cmd"
  "e:/vbox/svn/trunk/tools/win/sdk/v10.0.26100.0/env-arm64.cmd" --ucrt

  git clone https://github.com/netwide-assembler/nasm.git git-nasm-2.16.03-arm64
  cd git-nasm-2.16.03-arm64
  git checkout nasm-2.16.03

  git apply --stat E:\vbox\nasm\2024-11\readme.tool
  git apply --check --verbose E:\vbox\nasm\2024-11\readme.tool
  for %i in (1 2 3 4 5) do kmk_sed -ne "/^---patch-000%i/,/^---patch/{/^---patch/d;p}" E:\vbox\nasm\2024-11\readme.tool > vbox-000%i.patch
  for %i in (1 2 3 4 5) do git am --signoff vbox-000%i.patch

  kmk_touch config\config.h.in
  kmk_touch config\unconfig.h

  cmd /c nmake /f Mkfiles/msvc.mak EMPTY=kmk_touch

  zip -9Xj ..\win.arm64.nasm.v2.16.03-p1.zip nasm.exe ndisasm.exe E:\vbox\nasm\2024-11\readme.tool

Sketchy build steps for x86:

  pushd e:/vbox/svn/trunk
  "tools/env.cmd"
  popd
  "e:/vbox/svn/trunk/tools/win/vcc/v14.3.17.11.5/env-x86.cmd"
  "e:/vbox/svn/trunk/tools/win/sdk/v10.0.26100.0/env-x86.cmd" --ucrt

  git clone https://github.com/netwide-assembler/nasm.git git-nasm-2.16.03-x86
  cd git-nasm-2.16.03-x86
  git checkout nasm-2.16.03

  git apply --stat E:\vbox\nasm\2025-04\readme.tool
  git apply --check --verbose E:\vbox\nasm\2025-04\readme.tool
  for %i in (1 2 3 4 5) do kmk_sed -ne "/^---patch-000%i/,/^---patch/{/^---patch/d;p}" E:\vbox\nasm\2025-04\readme.tool > vbox-000%i.patch
  for %i in (1 2 3 4 5) do git am --signoff vbox-000%i.patch

  kmk_touch config\config.h.in
  kmk_touch config\unconfig.h

  cmd /c nmake /f Mkfiles/msvc.mak EMPTY=kmk_touch

  zip -9Xj ..\win.x86.nasm.v2.16.03-p1.zip nasm.exe ndisasm.exe E:\vbox\nasm\2025-04\readme.tool

---patch-0001

From 39efc5e6553ac6f4f86152f3d7e640ff52e7685e Mon Sep 17 00:00:00 2001
From: Alexander Eichner <Alexander.Eichner@oracle.com>
Date: Tue, 18 Apr 2023 08:23:45 +0200
Subject: [PATCH 1/5] msvc.mak: Fixes for to make it work with nmake, use CRT DLL.

Signed-off-by: knut st. osmundsen <bird-nasm@anduin.net>
---
 Mkfiles/msvc.mak | 7 ++++---
 1 file changed, 4 insertions(+), 3 deletions(-)

diff --git a/Mkfiles/msvc.mak b/Mkfiles/msvc.mak
index 49678935..eabab83b 100644
--- a/Mkfiles/msvc.mak
+++ b/Mkfiles/msvc.mak
@@ -40,7 +40,7 @@ INTERNAL_CFLAGS = /I$(srcdir) /I. \
 		  /I$(srcdir)/output /I./output
 ALL_CFLAGS	= $(BUILD_CFLAGS) $(INTERNAL_CFLAGS)
 MANIFEST_FLAGS  = /MANIFEST:EMBED /MANIFESTINPUT:$(MANIFEST)
-ALL_LDFLAGS	= /link $(LDFLAGS) $(MANIFEST_FLAGS) /SUBSYSTEM:CONSOLE /RELEASE
+ALL_LDFLAGS	= /link $(LDFLAGS) $(MANIFEST_FLAGS) /SUBSYSTEM:CONSOLE /RELEASE /FIXED:NO /DYNAMICBASE
 LIBS		=
 
 PERL		= perl
@@ -314,7 +314,7 @@ asm\directbl.c: asm\directiv.dat nasmlib\perfhash.pl perllib\phash.ph
 # Emacs token files
 misc\nasmtok.el: misc\emacstbl.pl asm\tokhash.c asm\pptok.c \
 		 asm\directiv.dat version
-	$(RUNPERL) $< $@ "$(srcdir)" "$(objdir)"
+	$(RUNPERL) misc\emacstbl.pl misc\nasmtok.el "$(srcdir)" "$(objdir)"
 
 #-- End Generated File Rules --#
 
@@ -251,11 +251,11 @@ x86\regs.h: x86\regs.dat x86\regs.pl
 .PHONY: warnings
 warnings: dirs
 	$(RM_F) $(WARNFILES) $(WARNTIMES) asm\warnings.time
-	$(MAKE) asm\warnings.time
+	$(MAKE) /f Mkfiles/msvc.mak asm\warnings.time
 
 asm\warnings.time: $(WARNSRCS) asm\warnings.pl
 	$(EMPTY) asm\warnings.time
-	$(MAKE) $(WARNTIMES)
+	$(MAKE) /f Mkfiles/msvc.mak $(WARNTIMES)
 
 asm\warnings_c.h.time: asm\warnings.pl asm\warnings.time
 	$(RUNPERL) $(srcdir)\asm\warnings.pl c asm\warnings_c.h $(srcdir)
-- 
2.25.1.windows.1

---patch-0002

From 8ff97ec566bf0708b64161e7e8adffca2062a9e8 Mon Sep 17 00:00:00 2001
From: Alexander Eichner <Alexander.Eichner@oracle.com>
Date: Tue, 18 Apr 2023 08:25:15 +0200
Subject: [PATCH 2/5] preproc.c: Using fgetc_nolock instead of fgetc speeds up
 parsing noticeably

Signed-off-by: knut st. osmundsen <bird-nasm@anduin.net>
---
 asm/preproc.c | 5 +++++
 1 file changed, 5 insertions(+)

diff --git a/asm/preproc.c b/asm/preproc.c
index ae1ef5ca..bf2568ee 100644
--- a/asm/preproc.c
+++ b/asm/preproc.c
@@ -64,6 +64,11 @@
 
 #include "nctype.h"
 
+/* This is measurably faster. */
+#if defined(_MSC_VER) && defined(_fgetc_nolock) && !defined(DEBUG)
+# define fgetc _fgetc_nolock
+#endif
+
 #include "nasm.h"
 #include "nasmlib.h"
 #include "error.h"
-- 
2.25.1.windows.1

---patch-0003

From 48f68ac81614168128b93ca73d35be70bae291a4 Mon Sep 17 00:00:00 2001
From: Alexander Eichner <Alexander.Eichner@oracle.com>
Date: Tue, 18 Apr 2023 08:26:55 +0200
Subject: [PATCH 3/5] nasm.c: Increase the output file buffer size to 64KB to
 avoid a few kernel calls

Signed-off-by: knut st. osmundsen <bird-nasm@anduin.net>
---
 asm/nasm.c | 3 +++
 1 file changed, 3 insertions(+)

diff --git a/asm/nasm.c b/asm/nasm.c
index 97d926fc..6776582f 100644
--- a/asm/nasm.c
+++ b/asm/nasm.c
@@ -641,6 +641,9 @@ int main(int argc, char **argv)
                 if (!ofile)
                     nasm_fatal("unable to open output file `%s'", outname);
                 out = ofile;
+#ifdef _MSC_VER /* Semi agressive buffering. */
+                setvbuf(ofile, NULL, _IOFBF, 0x10000);
+#endif
             } else {
                 ofile = NULL;
                 out = stdout;
-- 
2.25.1.windows.1

---patch-0004

From 8ab46e901fe22bfe569fd8a01b6b40b6f7b7becd Mon Sep 17 00:00:00 2001
From: Alexander Eichner <Alexander.Eichner@oracle.com>
Date: Tue, 18 Apr 2023 08:28:04 +0200
Subject: [PATCH 4/5] listing.c: Agressively buffer the list file stream to
 avoid lots of kernel calls

Signed-off-by: knut st. osmundsen <bird-nasm@anduin.net>
---
 asm/listing.c | 4 ++++
 1 file changed, 4 insertions(+)

diff --git a/asm/listing.c b/asm/listing.c
index 186b8b4e..01fbb4e5 100644
--- a/asm/listing.c
+++ b/asm/listing.c
@@ -153,6 +153,10 @@ static void list_init(const char *fname)
         nasm_nonfatal("unable to open listing file `%s'", fname);
         return;
     }
+#ifdef _MSC_VER
+    /* list files grow large. */
+    setvbuf(listfp, NULL, _IOFBF, 0x20000);
+#endif
 
     active_list_options = list_options | 1;
 
-- 
2.25.1.windows.1

---patch-0005

From 5351ad1346ff538a1a438ab169bf8a022712d897 Mon Sep 17 00:00:00 2001
From: bird <bird-nasm@anduin.net>
Date: Wed, 12 Jul 2023 22:05:12 +0200
Subject: [PATCH 5/5] preproc: Fix makefile dependencies for included files.

A bug in 169ac7c152ee13ed0c470ceb3371e9afb10e9a60 caused inc_fopen to
not add included files to the dependency list when using the -MD file
option.  The reason is that the included files would only be added to
the list on a hash table miss, but since the dependency list is generated
in the final pass when the hash table is already fully populated, no
include files would actually be added.

The fix is to always add an included file to the dependency list,
regardless of the hash table hit status.

Signed-off-by: knut st. osmundsen <bird-nasm@anduin.net>
---
 asm/preproc.c | 10 +++++-----
 1 file changed, 5 insertions(+), 5 deletions(-)

diff --git a/asm/preproc.c b/asm/preproc.c
index bf2568ee..3cee539f 100644
--- a/asm/preproc.c
+++ b/asm/preproc.c
@@ -2369,13 +2369,13 @@ static FILE *inc_fopen(const char *file,
                 fhe->full = full;
             }
         }
-
-        /*
-         * Add file to dependency path.
-         */
-        strlist_add(dhead, path ? path : file);
     }
 
+    /*
+     * Add file to dependency path.
+     */
+    strlist_add(dhead, path ? path : file);
+
     if (path && !fp && omode != INC_PROBE)
         fp = nasm_open_read(path, fmode);
 
-- 
2.25.1.windows.1

---patch-end

