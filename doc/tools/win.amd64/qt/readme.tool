$Id: readme.tool 113977 2026-04-22 20:32:22Z knut.osmundsen@oracle.com $

Windows Qt v6.8.0 with a bunch of patches,
buildable with Visual C++ 2019 v14.2 and Windows SDK v10.0.22000.0.

- Qt6 being built using cmake and ninja-build tools downloaded from official sources:
  https://cmake.org/download/
  https://github.com/ninja-build/ninja/releases


Creating VirtualBox-compatible Qt builds
========================================

I. Migrate to a new Qt version?

  1. Get one of those qt-everywhere-src-*.tar.xz packages.  Usually you can
     download the one you need from https://download.qt.io/official_releases/qt/ ,
     look for a .tar.xz file in one of subfolders.

  2. Import the unmodified Qt sources into a <vendor branch>.  Proper Qt vendor
     can be found at https://vbox-prj.oracle.com/qt/svn/vendor/Trolltech location.

  3. Remove all the unused modules, look at previous <vendor branch> history if
     unsure or just ask somebody who knows what *is* unused.

  4. Copy the <vendor branch> into a <normal branch>.  Keep the name simple,
     similar to previous <normal branch>.

  5. Apply the patch for the previous version.  This patch contains building scripts
     and various stability and security Qt fixes.  Either use the svn merge command
     to take required changes from svn or take the patch from the previous tool
     zip and apply it using 'svn patch'.  First variant is MUCH MORE appreciated.

  6. Try to build, fix build issues and repeat until it works, commit all the changes,
     finally.

II. Get the Qt sources for building on build-box.

  Checking it out from the <normal branch> of Qt repository is the normal course
  of actions, alternatively you can bring a zip/tar-ball manually.

  On the build box, you shall *always* create a new directory for a new
  build and never touch old builds!  Also, if you have to authenticate any
  access to the subversion server, you *must* use the --no-auth-cache options
  or you will break the builds running on the box.

III. To build a compatible version of Qt/Windows, you need to do the following:

  1. First and most important thing to keep in mind is that to satisfy minimum
     requirements on Windows we are configuring and building Qt v6.8.0 on tinderwin
     using VBox trunk tools such as Visual C++ 2019 v14.2 and Windows SDK v10.0.22000.0.
     Of course you can build this Qt tool for local needs on your local Windows host,
     just make sure you have fetched all the required tools as well, for that
     you will have to request full SDK via following LocalConfig.kmk flag:
       VBOX_WITH_FULL_W10SDK=1
     Also, don't forget to point KBUILD_DEVTOOLS to your local tools directory, e.g.:
       set KBUILD_DEVTOOLS=C:\projects\vbox\trunk\tools

  2. Run vbox-do-it-all.cmd with 'verbose' option, this command will
     configure, build and prepare two final packages (Qt and debugging symbols).
     Build being performed in 'out' folder, packaging being performed in
     'staged-install' folder.  To cleanup remnants of previous build you can
     separately call vbox-clean-all.cmd beforehand or add 'cleanup' option
     to vbox-do-it-all.cmd.
