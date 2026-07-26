# Embedded Mihon bridge for iOS

Mangatan embeds M-Extension-Server in the iOS process and runs it on an
OpenJDK Mobile Zero VM bound only to `127.0.0.1`. The generated runtime and
OpenJDK frameworks are intentionally excluded from Git.

Prepare them before an iOS build:

```sh
JAVA_HOME=/path/to/jdk-21 tool/prepare_embedded_mihon_ios.sh
```

The preparation script pins:

- the exact M-Extension-Server commit;
- the custom OpenJDK Mobile iOS 13 runtime release;
- SHA-256 checksums for both OpenJDK downloads.

On macOS, preparation converts the pinned static OpenJDK archive into
`OpenJDKRuntime.framework`. The app embeds but does not link that framework:
the native bridge opens it with `dlopen` on its serial worker only after the
first Mihon request. This separation is required because linking the archive
directly adds thousands of C++ initializers to the app's pre-main launch path.
The release workflow rejects an app executable with more than 64 pre-main
initializers or a hard dependency on `OpenJDKRuntime`.

To update the embedded server later, merge the server changes first, replace
`server_commit` in the script, and rerun the server tests and this preparation
command. To update OpenJDK, dispatch `build-openjdk-ios13.yml`, then replace
both asset URLs and their checksums together. The runtime workflow pins the
OpenJDK and ios-tools source commits and rejects any Mach-O object targeting
newer than iOS 13. The iOS release workflow runs the same preparation script
from a clean checkout.

The embedded VM is interpreter-only and is suspended with the app by iOS.
Extensions that require Android WebView or unsupported native Android
libraries can still use the saved external APKBridge address as a fallback.
