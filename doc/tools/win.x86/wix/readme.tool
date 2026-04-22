This is the self-built package for Windows Installer Toolset (WIX) v4.0.5.

Sources taken from the tags/4.0.5 branch as of 2024/04/22.
git branch hash: b9b2f1b4c69a1b509d487dc950b30b4ec9b0d040
Only contains the x86/x64 binaries (ARM support left out).

#### Build instructions

* Install git for Windows
* Install the Visual Studio 2022 Community: https://visualstudio.microsoft.com/downloads/
* In the Visual Studio Installer for Visual Studio 2022, click on "Change" and import "wix-4.0.5-vs2022.vsconfig"
* For manually installing stuff, install the following workloads / components:
  * **Workloads**
    - ASP.NET and web development
    - .NET desktop development
    - Desktop development with C++
  * **Individual Components**
    -  .NET Framework 4.7.2 SDK
    - .NET Framework 4.7.2 targeting pack
    - MSVC v141 - VS 2017 C++ ARM64 build tools (v14.16)
    - MSVC v141 - VS 2017 C++ x64/x86 build tools (v14.16)
    - MSVC v143 - VS 2022 C++ ARM64 build tools (Latest)
    - MSVC v143 - VS 2022 C++ x64/x86 build tools (Latest)
    - Node.js development tools
 * Open "Developer Command Prompt for VS 2022"
* List available tags (pinned releases) via `git tag`
* Clone WIX toolset from github: `git clone https://github.com/orgs/wixtoolset/` -- this must be done, as otherwise installing stuff via devbuild.cmd later won't work!
* Checkout wanted release by using the tag, e.g. `git checkout v4.0.5`
* If needed, edit SfxCA.vcxproj:
```  <ItemGroup>
    <ResourceCompile Include="SfxCA.rc" >
        <Culture>0x0409</Culture>
    </ResourceCompile>
  </ItemGroup>
```
* Build WIX toolset via `devbuild.cmd inc release`
