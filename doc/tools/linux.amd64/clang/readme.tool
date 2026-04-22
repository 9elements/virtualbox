# Building a 20.1.1 clang cross compiler with lld

Host: tinderlin.de.oracle.com

# Building LLVM requires cmake which is installed as a third party program on tinderlin
export PATH=$PATH:/home/vbox/cmake-3.31.6-linux-x86_64/bin

# Download and prepare
curl -O llvmorg-20.1.1.tar.gz https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-20.1.1.tar.gz
tar -xf llvmorg-20.1.1.tar.gz
cd llvm-project-llvmorg-20.1.1
mkdir build
cd build

# Configure, build and install clang + lld
cmake -DCMAKE_BUILD_TYPE=MinSizeRel -DLLVM_ENABLE_PROJECTS="clang;lld" -DLLVM_TARGETS_TO_BUILD="X86;AArch64;ARM;RISCV" ../llvm
cmake --build . --parallel 4
cmake --install . --prefix /home/vbox/linux.amd64.clang

# Remove unnecessary stuff to keep the tools package as small as possible

cd /home/vbox/linux.amd64.clang
rm bin/amdgpu-arch
rm bin/bugpoint
rm bin/c-index-test
rm bin/clang-check
rm bin/clang-extdef-mapping
rm bin/clang-format
rm bin/clang-installapi
rm bin/clang-linker-wrapper
rm bin/clang-nvlink-wrapper
rm bin/clang-offload-bundler
rm bin/clang-offload-packager
rm bin/clang-refactor
rm bin/clang-repl
rm bin/clang-scan-deps
rm bin/clang-sycl-linker
rm bin/clang-tblgen
rm bin/dsymutil
rm bin/git-clang-format
rm bin/hmaptool
rm bin/llc
rm bin/lli
rm bin/llvm-c-test
rm bin/llvm-cat
rm bin/llvm-cfi-verify
rm bin/llvm-debuginfo-analyzer
rm bin/llvm-debuginfod
rm bin/llvm-debuginfod-find
rm bin/llvm-diff
rm bin/llvm-dwarfdump
rm bin/llvm-dwarfutil
rm bin/llvm-dwp
rm bin/llvm-exegesis
rm bin/llvm-gsymutil
rm bin/llvm-ifs
rm bin/llvm-jitlink
rm bin/llvm-lto
rm bin/llvm-lto2
rm bin/llvm-mc
rm bin/llvm-mca
rm bin/llvm-profgen
rm bin/llvm-readtapi
rm bin/llvm-reduce
rm bin/llvm-rtdyld
rm bin/llvm-sim
rm bin/llvm-split
rm bin/llvm-stress
rm bin/llvm-tblgen
rm bin/llvm-tli-checker
rm bin/nvptx-arch
rm bin/opt
rm bin/sancov
rm bin/sanstats
rm bin/verify-uselistorder
rm -rf include
rm -rf lib/cmake
rm lib/*.a
rm lib/*.so*

tar -cf ../linux.amd64.clang.v20.1.1.tar *
cd ..
bzip2 -9 linux.amd64.clang.v20.1.1.tar
