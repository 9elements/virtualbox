Building DITA-OT v4.0.2 with updated com.elovirta.pdf, a couple of fixes
and the removal of plugins org.dita.eclipsehelp, org.lwdita, org.dita.pdf2.xep
and org.dita.pdf2.axf removed.


Using Windows, as it has the lower chance of accidental poisioning the result
by installed something already installed on the system:
  0. Be on the oracle network (VPN or at the office).
  1. Enter the vbox trunk environment.
  2. Create an empty working directory and enter it.
  3. Put the associated dita-ot-bld.cmd, dita-ot-bld.sh and
     dita-ot-bld-single-html-optimization-v0.diff files in it.
  4. Run (takes 11-12 min):
        cmd /c dita-ot-bld.cmd
  5. If all goes well, a common.dita-ot.v4.0.2-r1.7z file will be created.

