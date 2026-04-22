osxfuse-3.10.3.dmg from https://osxfuse.gitgub.io

- install it (can be limited to Core bits)
- copy /usr/local/include/osxfuse to include
- copy /usr/local/lib/*osxfuse* /usr/local/lib/pkgconfig/osxfuse.pc to lib
- extract content of overall osxfuse installer:
  $ pkgutil --expand .../FUSE\ for\ macOS.pkg ~/tmposxfuse
  copy Core.pkg to tool root
