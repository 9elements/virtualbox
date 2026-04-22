Code signing tools from WDK 6000 (vista) assembled when we starting signing
drivers.  Contains bin/SelfSign/* in the root plus a few kernel cross-signing
certificate files downloaded from the microsoft webside in separate zip files.

Not entirely sure where exactly this came from, but the files seems all to be
present on en_windows_vista_windows_driver_kit_dvd_x13-31670.iso available on
my visual studio / msdn (md5: a2c23e36dba2d328f8644dbee22d5e36).  However,
the Inf2Cat.exe, WST.* and Microsoft.Whos.Winqual.Submissions.SubmissionBuilder.dll
probably came from WDK 6001 or some other update, as they have newer dates
in 2007, but it is too much work to track down tonight.

Current content:
182183  64%  10/10/06 17:20  2429cbcf  capicom.dll
 22914  61%  18/09/06 13:17  05ca3bda  certmgr.exe
 46187  53%  18/09/06 13:37  8096470c  FileSignatureInfoLib.dll
 24925  11%  18/09/06 13:37  adec72f7  image001.jpg
 26141  10%  18/09/06 13:37  151ab6b4  image002.jpg
 25450  10%  18/09/06 13:37  c5a1fc5e  image003.jpg
 26764  10%  18/09/06 13:37  fcd881e7  image004.jpg
 18379  18%  18/09/06 13:37  6075494c  image005.jpg
 16133  20%  18/09/06 13:37  4928dd44  image006.jpg
 13174  24%  18/09/06 13:37  cdc7aff8  image007.jpg
 18545  22%  18/09/06 13:37  4844f9db  image008.jpg
  6196  75%  21/02/07 08:51  8bed1b33  Inf2Cat.exe
  7900  52%  02/11/06 00:17  6692ceca  makecat.exe
 18167  54%  02/11/06 00:17  dd2e13ee  makecert.exe
 92867  63%  18/09/06 13:37  a6458e8e  mercclient.dll
  5056  75%  18/09/06 13:37  684f79e1  mercprog.exe
 21810  69%  25/05/06 14:10  4173213d  Microsoft.Whos.Shared.IO.Cabinets.dll
  7404  74%  04/10/06 12:17  b7527f14  Microsoft.Whos.Shared.IO.Catalogs.dll
  5512  78%  13/07/05 14:55  9a1049ae  Microsoft.Whos.Shared.Xml.InfReader.dll
 53684  77%  04/04/07 10:53  57a6685a  Microsoft.Whos.Winqual.Submissions.SubmissionBuilder.dll
  5806  76%  18/03/05 07:57  4bdfd5ad  Microsoft.Whos.Xml.NonXmlDataReader.dll
334581  48%  18/09/06 13:37  7f9c4233  MsComCt2.ocx
502788  53%  18/09/06 13:37  8c0878a3  MsComCtl.ocx
  1484  26%  08/06/06 21:36  922b550d  MSCV-BCyberTrust.cer
  1340  26%  23/05/06 11:29  cdec229e  MSCV-EquifaxSecure.cer
  1457  26%  23/05/06 11:29  6aafd299  MSCV-GeoTrust.cer
  1469  27%  08/06/06 21:37  f063778a  MSCV-GlobalSign.cer
  1380  26%  08/06/06 21:37  9d352949  MSCV-GTECyberTrust.cer
  1340  27%  23/05/06 11:29  d96126ee  MSCV-VSClass3.cer
 10004  60%  02/11/06 00:00  d9e86774  PEINFO.dll
  1519  69%  18/09/06 13:37  7256baf1  peinfo.tlb
  9523  50%  01/11/06 23:43  89c4d392  pvk2pfx.exe
  2422  72%  18/09/06 13:37  d63666e5  selfsign_example.cmd
 14001  83%  18/09/06 13:37  1e86cfed  selfsign_readme.htm
 17423  72%  18/09/06 13:37  e40fe1de  signability.exe
 41021  60%  01/11/06 23:43  c479136d  signtool.exe
160466  80%  18/09/06 13:37  fc045824  wfp.dat
 11529  50%  02/11/06 00:00  8dd038c5  whqlcab.dll
  7697   0%  04/04/07 12:26  c712a55e  wst.dat
 62614  76%  04/04/07 12:26  d22364fc  WST.exe
   165  34%  04/04/07 12:26  bc4fcd24  WST.exe.config
    20  23%  04/04/07 12:26  f4fd714a  wst_log.xml
     0   0%  29/03/07 02:20  00000000  _from_WDK_6000
    78  13%  16/05/07 21:24  4d45b83e  _pluss_winqual_submission_tool_2007-05-16

