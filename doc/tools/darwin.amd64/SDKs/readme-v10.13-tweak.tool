MacOS SDK for v10.13 from /Library/Developer/CommandLineTools/SDKs/.
This is taken from Command Line Tools for Xcode 9.4.1.
Newer Xcode insists having SDKSettings.json at the top level (otherwise
produces binaries which will not be considered validly signed by amfid when
there are privileged entitlements needing a provisioning profile), so this
file was created by using
$ plutil -convert json -o SDKSettings.json SDKSettings.plist
