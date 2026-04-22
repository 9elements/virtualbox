# Packaging the metal and metallib tools

Download XCode 14.3.1 xip https://xcodereleases.com/ and extract it

Copy the following files and directories over from Xcode.app:
    Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/metal/bin/metal    -> bin/metal
    Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/metal/bin/metallib -> bin/metallib
    Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/metal/lib/clang    -> lib/clang

tar -cf ../darwin.metal.v14.3.1.tar *
cd ..
bzip2 -9 darwin.metal.v14.3.1.tar
