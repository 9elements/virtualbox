Solaris 10u11 build of nasm v2.16.03 tarball (nasm-2.16.03.tar.gz, md5:
128ad3b6194226562d7e6240de9f0a5e) with github pull request 80 applied 
(attached below) targeting amd64.

Had to run configure like this to get a amd64 build:
    CFLAGS="-m64" LDFLAGS="-m64" CPPFLAGS="-m64" ./configure

No make arguments. Debug info not stripped.

------------------------------------------------------------------------

From b4170a555924ef2dddd1e7464352511cf723d697 Mon Sep 17 00:00:00 2001
From: bird <bird-nasm@anduin.net>
Date: Wed, 12 Jul 2023 22:05:12 +0200
Subject: [PATCH] preproc: Fix makefile dependencies for included files.

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
index ac42131e..a52bb26a 100644
--- a/asm/preproc.c
+++ b/asm/preproc.c
@@ -2360,13 +2360,13 @@ static FILE *inc_fopen(const char *file,
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
 

