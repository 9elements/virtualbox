This package contains the glslangValidator binary required to build DXVK on macOS.

Current version is 11.7.0 from https://github.com/KhronosGroup/glslang/tree/11.7.0

It is built on tindermac using the following commands:
    git clone https://github.com/KhronosGroup/glslang/tree/11.7.0
    cd glslang
    mkdir build
    cd build
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$(pwd)/install" -DCMAKE_OSX_ARCHITECTURES="x86_64" ..
    make

The binary will be under StandAlone/glslangValidator.

