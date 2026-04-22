This package contains the MoltenVK library to support the Vulkan API on macOS
which supports on Metal natively. Vulkan is required for the dxvk DirectX -> Vulkan
translation layer used by the new 3D support.

Current version is 1.2.9 from https://github.com/KhronosGroup/MoltenVK/tree/v1.2.9

To build it do the following on tindermac:
    git clone https://github.com/KhronosGroup/MoltenVK/tree/v1.2.9
    cd MoltenVK
    sh fetchDependencies --macos
    make macos

The library will be in Package/Release/MoltenVK/dylib/macOS/libMoltenVK.dylib (we don't use the framework), it
will be a fat universal binary containing both x86_64 and arm64 architectures. In order to save space extract the
architectures for each package using lipo and pack the results along with this readme:
    * x86_64: lipo -thin x86_64 -output libMoltenVK.dylib Package/Release/MoltenVK/dylib/macOS/libMoltenVK.dylib
    * arm64:  lipo -thin arm64  -output libMoltenVK.dylib Package/Release/MoltenVK/dylib/macOS/libMoltenVK.dylib

