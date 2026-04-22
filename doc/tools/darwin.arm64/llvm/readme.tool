# Building a 15.0.7 LLVM for the Shader transpiler in DXMT

Host: tindermaca2.de.oracle.com

# Building LLVM requires cmake which is installed as a third party program on tindermaca2
export PATH=$PATH:/Applications/CMake.app/Contents/bin

# Download and prepare
curl -O llvmorg-15.0.7.tar.gz https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-15.0.7.tar.gz
tar -xf llvmorg-15.0.7.tar.gz
cd llvm-project-llvmorg-15.0.7
mkdir build

# Configure, build and install clang + lld
cmake -B ./build -S ./llvm \
  -DCMAKE_INSTALL_PREFIX="/Users/vbox/darwin.arm64.llvm" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DLLVM_HOST_TRIPLE=arm64-apple-darwin \
  -DLLVM_ENABLE_ASSERTIONS=Off \
  -DLLVM_ENABLE_ZSTD=Off \
  -DLLVM_ENABLE_TERMINFO=Off \
  -DLLVM_ENABLE_LIBXML2=Off \
  -DLLVM_ENABLE_ZLIB=Off \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_TARGETS_TO_BUILD="" \
  -DLLVM_BUILD_TOOLS=Off \
  -DBUG_REPORT_URL="https://github.com/VirtualBox/virtualbox" \
  -DPACKAGE_VENDOR="Oracle" \
  -DLLVM_VERSION_PRINTER_SHOW_HOST_TARGET_INFO=Off \
  -G Ninja
cmake --build . --parallel 4
cmake --install . --prefix /Users/vbox/darwin.arm64.llvm

# Remove unnecessary stuff to keep the tools package as small as possible

cd /Users/vbox/darwin.arm64.llvm
rm -rf share
rm -rf bin
rm -rf lib/cmake
rm lib/*.dylib

tar -cf ../darwin.arm64.llvm.v15.0.7.tar *
cd ..
bzip2 -9 darwin.arm64.clang.v15.0.7.tar
