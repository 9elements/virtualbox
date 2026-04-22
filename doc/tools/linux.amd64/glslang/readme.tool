This package contains the glslangValidator binary required to build DXVK on linux

Current version is 11.7.0 from https://github.com/KhronosGroup/glslang/tree/11.7.0

It was probably built on tindersomething using the following commands:
    git clone https://github.com/KhronosGroup/glslang/tree/11.7.0
    cd glslang
    mkdir build
    cd build
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$(pwd)/install" ..
    make

The binary will be under StandAlone/glslangValidator. (?)

