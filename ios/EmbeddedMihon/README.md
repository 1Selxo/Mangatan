# Embedded Mihon bridge for iOS

Mangatan embeds M-Extension-Server in the iOS process and runs it on an
OpenJDK Mobile Zero VM bound only to `127.0.0.1`. The generated runtime and
OpenJDK XCFramework are intentionally excluded from Git.

Prepare them before an iOS build:

```sh
JAVA_HOME=/path/to/jdk-21 tool/prepare_embedded_mihon_ios.sh
```

The preparation script pins:

- the exact M-Extension-Server commit;
- the OpenJDK Mobile snapshot asset URLs;
- SHA-256 checksums for both OpenJDK downloads.

To update the embedded server later, merge the server changes first, replace
`server_commit` in the script, and rerun the server tests and this preparation
command. To update OpenJDK, replace both asset URLs and their checksums
together. The iOS release workflow runs the same script from a clean checkout.

The embedded VM is interpreter-only and is suspended with the app by iOS.
Extensions that require Android WebView or unsupported native Android
libraries can still use the saved external APKBridge address as a fallback.
