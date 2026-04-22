NASM git nasm-2.16.xx (branch) b9528913aa7e8aa8a2ae93065d22bbd12fe7b4fd with
the patches below applied.

Crossbuilt on a Windows host. Requires perl and git in the PATH.

Approximate build steps:

  pushd e:/vbox/svn/trunk
  "tools/env.cmd"
  popd
  set PATH=e:\vbox\svn\trunk\tools\common\openwatcom\v1.9-r2\binnt;%PATH%
  set WATCOM=e:\vbox\svn\trunk\tools\common\openwatcom\v1.9-r2

  git clone https://github.com/netwide-assembler/nasm.git git-nasm-2.16.03-os2
  cd git-nasm-2.16.03-os2
  git checkout nasm-2.16.03

  git apply --stat E:\vbox\nasm\2025-04\readme-os2.tool
  git apply --check --verbose E:\vbox\nasm\2025-04\readme-os2.tool
  for %i in (1 2) do kmk_sed -ne "/^---patch-000%i/,/^---patch/{/^---patch/d;p}" E:\vbox\nasm\2025-04\readme-os2.tool > vbox-000%i.patch
  for %i in (1 2) do git am --signoff vbox-000%i.patch

  kmk_touch config\config.h.in
  kmk_touch config\unconfig.h

  cmd /c wmake -f Mkfiles/openwcom.mak os2

  copy E:\vbox\nasm\2025-04\readme-os2.tool readme.tool
  zip -9Xj ..\os2.x86.nasm.v2.16.03-p1.zip nasm.exe ndisasm.exe readme.tool

---patch-0001

From 2b61b76438d14e2c587b51ac70af33d9d11cf7c2 Mon Sep 17 00:00:00 2001
From: "knut st. osmundsen" <bird-nasm@anduin.net>
Date: Tue, 15 Apr 2025 18:26:23 +0200
Subject: [PATCH] Makefile fixes addressing various blind/untested file edits
 by upstream.

---
 Mkfiles/openwcom.mak | 28 ++++++++++++++++------------
 1 file changed, 16 insertions(+), 12 deletions(-)

diff --git a/Mkfiles/openwcom.mak b/Mkfiles/openwcom.mak
index 91c606be..07216302 100644
--- a/Mkfiles/openwcom.mak
+++ b/Mkfiles/openwcom.mak
@@ -6,6 +6,7 @@
 
 top_srcdir  = .
 srcdir      = .
+objdir      = .
 VPATH       = $(srcdir)\asm;$(srcdir)\x86;asm;x86;$(srcdir)\macros;macros;$(srcdir)\output;$(srcdir)\lib;$(srcdir)\common;$(srcdir)\stdlib;$(srcdir)\nasmlib;$(srcdir)\disasm
 prefix      = C:\Program Files\NASM
 exec_prefix = $(prefix)
@@ -28,7 +29,8 @@ PERL		= perl
 PERLFLAGS	= -I$(srcdir)\perllib -I$(srcdir)
 RUNPERL         = $(PERL) $(PERLFLAGS)
 
-EMPTY		= $(RUNPERL) -e ""
+#EMPTY		= $(RUNPERL) -e ""
+EMPTY		= wtouch
 
 MAKENSIS        = makensis
 
@@ -145,7 +147,7 @@ linux386:   .SYMBOLIC
     @%make all
 
 all: perlreq nasm$(X) ndisasm$(X) .SYMBOLIC
-#   cd rdoff && $(MAKE) all
+#   cd rdoff && $(MAKE) -f MkFiles\openwcom.mak all
 
 NASMLIB = nasm.lib
 
@@ -160,7 +162,8 @@ nasm.lib: $(LIBOBJ)
 
 # These are specific to certain Makefile syntaxes (what are they
 # actually supposed to look like for wmake?)
-WARNTIMES = $(WARNFILES:=.time)
+#WARNTIMES = $(WARNFILES:=.time) # bird - doesn't work, so do it manually:
+WARNTIMES = asm\warnings_c.h.time include\warnings.h.time doc\warnings.src.time
 WARNSRCS  = $(LIBOBJ_NW:.obj=.c)
 
 #-- Begin Generated File Rules --#
@@ -261,35 +264,35 @@ x86\regs.h: x86\regs.dat x86\regs.pl
 # reasonable, but doesn't update the time stamp if the files aren't
 # changed, to avoid rebuilding everything every time. Track the actual
 # dependency by the empty file asm\warnings.time.
-.PHONY: warnings
+#.PHONY: warnings - bird no .PHONY in my wmake (it warns about it).
 warnings: dirs
 	$(RM_F) $(WARNFILES) $(WARNTIMES) asm\warnings.time
-	$(MAKE) asm\warnings.time
+	$(MAKE) -f MkFiles\openwcom.mak asm\warnings.time
 
 asm\warnings.time: $(WARNSRCS) asm\warnings.pl
 	$(EMPTY) asm\warnings.time
-	$(MAKE) $(WARNTIMES)
+	$(MAKE) -f MkFiles\openwcom.mak $(WARNTIMES)
 
 asm\warnings_c.h.time: asm\warnings.pl asm\warnings.time
 	$(RUNPERL) $(srcdir)\asm\warnings.pl c asm\warnings_c.h $(srcdir)
 	$(EMPTY) asm\warnings_c.h.time
 
 asm\warnings_c.h: asm\warnings_c.h.time
-	@: Side effect
+	@rem Side effect
 
 include\warnings.h.time: asm\warnings.pl asm\warnings.time
 	$(RUNPERL) $(srcdir)\asm\warnings.pl h include\warnings.h $(srcdir)
 	$(EMPTY) include\warnings.h.time
 
 include\warnings.h: include\warnings.h.time
-	@: Side effect
+	@rem Side effect
 
 doc\warnings.src.time: asm\warnings.pl asm\warnings.time
 	$(RUNPERL) $(srcdir)\asm\warnings.pl doc doc\warnings.src $(srcdir)
 	$(EMPTY) doc\warnings.src.time
 
 doc\warnings.src : doc\warnings.src.time
-	@: Side effect
+	@rem Side effect
 
 # Assembler token hash
 asm\tokhash.c: x86\insns.dat x86\insnsn.c asm\tokens.dat asm\tokhash.pl &
@@ -327,7 +330,8 @@ asm\directbl.c: asm\directiv.dat nasmlib\perfhash.pl perllib\phash.ph
 # Emacs token files
 misc\nasmtok.el: misc\emacstbl.pl asm\tokhash.c asm\pptok.c &
 		 asm\directiv.dat version
-	$(RUNPERL) $< $@ "$(srcdir)" "$(objdir)"
+	$(RUNPERL) misc\emacstbl.pl $@ "$(srcdir)" "$(objdir)"
+#	$(RUNPERL) $< $@ "$(srcdir)" "$(objdir)" - wrong $< is the whole list, not the first.
 
 #-- End Generated File Rules --#
 
@@ -371,7 +375,7 @@ cleaner: clean .SYMBOLIC
     rm -f $(PERLREQ)
     rm -f *.man
     rm -f nasm.spec
-#   cd doc && $(MAKE) clean
+#   cd doc && $(MAKE) -f MkFiles\openwcom.mak clean
 
 spotless: distclean cleaner .SYMBOLIC
     rm -f doc\Makefile doc\*~ doc\*.bak
@@ -380,7 +384,7 @@ strip: .SYMBOLIC
     $(STRIP) *.exe
 
 doc:
-#   cd doc && $(MAKE) all
+#   cd doc && $(MAKE) -f MkFiles\openwcom.mak all
 
 everything: all doc
 
-- 
2.47.0.windows.2


---patch-0002

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

