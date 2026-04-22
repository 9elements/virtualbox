$Id: readme.tool 113977 2026-04-22 20:32:22Z knut.osmundsen@oracle.com $

Linux Qt v6.8.0 with a bunch of patches,
buildable with gcc 10 under OL8.0 amd64 environment.

- OL8.0 by default goes with gcc 8. To have gcc 10 we had to install it
  within Devtoolset-10 Software Collection Library.
  `sudo yum --enablerepo=ol8_software_collections install devtoolset-10-gcc \
                                                          devtoolset-10-gcc-c++`
  // devtoolset-10-gcc (at least v10+), devtoolset-10-gcc-c++ (at least v10+)

- Besides that, Qt6 being built using cmake3 and ninja-build tools:
  `sudo yum --enablerepo=ol8_epel install cmake3 ninja-build`
  // cmake3 (at least v3.21.1), ninja-build

- Platform plugin (XCB/XKB) requires following development packages missed in 8.0:
  `sudo yum --enablerepo=ol8_latest install libxkbcommon-devel`
  `sudo yum --enablerepo=ol8_optional_latest install libxkbcommon-x11-devel \
                                                     xcb-util-wm-devel \
                                                     xcb-util-devel \
                                                     xcb-util-image-devel \
                                                     xcb-util-keysyms-devel \
                                                     xcb-util-renderutil-devel \
                                                     xcb-util-cursor-devel`
  // libxkbcommon-devel, libxkbcommon-x11-devel
  // xcb-util-wm-devel, xcb-util-devel, xcb-util-image-devel
  // xcb-util-keysyms-devel, xcb-util-renderutil-devel, xcb-util-cursor-devel

- GTK3 plugin requires following development packages to be installed:
  `sudo yum install gtk3-devel`
  // gtk3-devel


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

III. To build a compatible version of Qt/Linux, you need to do the following:

  1. First and most important thing to keep in mind is that to satisfy minimum
     requirements on Linux we are configuring, building and packaging Qt v6.8.0
     on tinderlin using qt6-ol8.0-amd64 podman container.  Container name passed
     in the tinderbox script isn't used at all, required name is hardcoded in the
     main script.  Of course you can build this Qt tool for local needs on your
     local Linux host, there is no need to have corresponding chroot there, only
     other prerequisites.

  2. Run vbox-do-it-all-linux.sh with -v (or --verbose) option, this command will
     configure, build and prepare two final packages (Qt and debugging symbols).
     Build being performed in 'out' folder, packaging being performed in
     'staged-install' folder.  To cleanup remnants of previous build you can
     separately call vbox-clean-all.sh beforehand or add -c (or --clean) option
     to vbox-do-it-all-linux.sh.
