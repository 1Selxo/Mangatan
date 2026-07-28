# Mangatan iOS development notes

## Scope

This fork adds a sideloadable iOS build while preserving normal Mangayomi
features and easy upstream updates. Keep fixes cross-platform unless the code
is inherently iOS-specific.

## Repository and upstream

- Work on `main`.
- `origin` is the user's fork.
- Preserve the configured upstream remote and rebase or merge upstream changes
  without dropping fork-specific fixes.
- Resolve generated-file conflicts from their source inputs, not by keeping
  stale generated output.
- Bump the build number in `pubspec.yaml` for every device-testable IPA.

## On-device Mihon architecture

The iOS Mihon path is:

1. Flutter calls `lib/services/m_extension_server.dart`.
2. The service invokes the `mangatan/embedded_mihon` method channel.
3. `ios/Runner/MihonEmbeddedBridge.mm` starts a dedicated native worker.
4. That worker lazily loads `OpenJDKRuntime.framework` with
   `RTLD_NOW | RTLD_GLOBAL`.
5. OpenJDK Mobile Zero starts without JIT.
6. `MExtensionServer.jar` binds to an ephemeral `127.0.0.1` port.
7. Flutter uses the returned loopback URL for Mihon extension requests.

Never preload or directly link `OpenJDKRuntime.framework` into the Runner
launch image. Thousands of OpenJDK C++ initializers can crash the app before
Flutter starts. The runtime may start only when the first Mihon source needs
it.

Do not restore a silent `127.0.0.1:8080` fallback on iOS. If the embedded
bridge fails, surface the native startup error before making HTTP requests.
The embedded loopback address is process-wide. Keep it independently of
auto-disposed Riverpod providers: a source provider may be disposed while the
native VM is still starting, and its `Ref` must never be read after that async
gap.

### iOS suspension and thermal behavior

The iOS OpenJDK port's blocking `accept()` can spin after device sleep. On the
test device this changed an idle bridge from approximately 0% CPU to one full
core, heated the phone, and left the loopback port unable to serve requests.

- Begin stopping the Java loopback listener in native
  `applicationWillResignActive`, then mirror the state in
  `AppLifecycleState.inactive`, before iOS suspends the process.
- Restart it on `AppLifecycleState.resumed`, preferring the previous port so
  existing image and media proxy URLs stay valid.
- Keep loaded extension instances while the listener is paused. Re-converting
  each APK on every unlock is slow and wastes battery.
- A native `isRunning` result does not prove HTTP health after device sleep.
  If `/capabilities` fails while native status is true, stop the stale listener
  before starting it again.
- Do not keep the bridge running in the background. iOS suspends ordinary
  sideloaded apps, so this cannot provide a reliable background server.

## iOS runtime constraints

- The normal sideload build must not require JIT, unsigned executable memory,
  TrollStore, a debugger, or a special Apple entitlement.
- Use the OpenJDK Zero interpreter for ordinary signed device builds.
- Keep all OpenJDK native objects compatible with iOS 13 or earlier.
- Amethyst-iOS demonstrates a different JIT-enabled launcher model. It is
  useful research, but its entitlement and debugger requirements are not
  acceptable defaults for this app.
- Real iPhones differ from simulators: simulator success does not validate
  dynamic code, entitlements, loader scope, or device signing.

## Runtime sources of truth

- `tool/prepare_embedded_mihon_ios.sh` pins all downloadable runtime assets and
  SHA-256 values.
- `tool/build_lazy_openjdk_ios.sh` creates the lazy dynamic framework from the
  pinned static archive.
- `tool/openjdk/*.patch` contains the iOS OpenJDK source changes.
- `.github/workflows/build-openjdk-ios13.yml` builds and publishes the pinned
  OpenJDK release.
- `.github/workflows/ios-sideload.yml` prepares, builds, verifies, and uploads
  the unsigned IPA.
- `ios/EmbeddedMihon/README.md` documents operator-facing preparation.

The generated directories `ios/EmbeddedMihon/runtime`,
`ios/Frameworks/OpenJDK.xcframework`, and
`ios/Frameworks/OpenJDKRuntime.framework` are build products. Do not commit
them.

The framework-local `java.home` must contain both `lib/modules` and the
matching OpenJDK `conf` tree. In particular, Java security initialization
requires `conf/security/java.security`; a trust store alone is insufficient.
It also needs matching non-module runtime data, especially `lib/tzdb.dat` and
the `lib/security` data files. Do not package only the module image.

When publishing a new runtime:

1. Keep the OpenJDK Mobile and ios-tools commits pinned.
2. Apply every patch with `git apply --check` before building.
3. Publish under a new immutable release tag.
4. Download both release ZIP files and calculate their SHA-256 values.
5. Update both URLs and both hashes in
   `tool/prepare_embedded_mihon_ios.sh` together.
6. Build the IPA from a clean checkout.

## Native loader rules

The Zero VM and libjava both need global lookup visibility because the runtime
framework is loaded after process launch.

- HotSpot uses `RTLD_DEFAULT` through `tool/openjdk/ios-zero-runtime.patch`.
- libjava uses `RTLD_DEFAULT` through
  `tool/openjdk/ios-libjava-global-symbols.patch`.
- Do not replace either iOS path with macOS `RTLD_FIRST`.
- Keep the `JIMAGE_*` and `JDK_Canonicalize` visibility checks in
  `MihonEmbeddedBridge.mm`.
- Keep `libverify.a` in the static runtime and verify that
  `VerifyClassForMajorVersion` is exported. Dex2jar output can require the
  legacy verifier even when ordinary app classes use the split verifier.
- Keep JNI boundary logs until the server starts reliably on physical devices.

## Testing

Before pushing:

```sh
dart format --output=none --set-exit-if-changed \
  test/services/m_extension_server_test.dart
flutter test test/services/m_extension_server_test.dart
git diff --check
```

The CI verifier must also confirm:

- Runner has no hard dependency on `OpenJDKRuntime`.
- the lazy runtime is embedded and signed;
- its module image and server JAR are present;
- native symbols required by OpenJDK are exported;
- every Mach-O object meets the minimum iOS target;
- the IPA contains no private signing material.

Device testing must use a physical iPhone. Capture logs from process launch
through one source selection. A useful startup sequence includes:

```text
calling JNI_CreateJavaVM
JNI_CreateJavaVM returned 0
EmbeddedBridge class lookup succeeded
calling EmbeddedBridge.start
```

The build 144 trace proved the VM and JNI bridge work. Its remaining failure
was:

```text
java.lang.UnsatisfiedLinkError: no jimage in system library path
```

That fault came from libjava caching a macOS `RTLD_FIRST` process handle, not
from missing JRE files or an iOS JIT restriction.

## Signing and device safety

- Never commit certificates, private keys, provisioning profiles, passwords,
  device UDIDs, signed IPAs, or raw user device logs.
- Keep local signing work outside the repository.
- Sign every embedded framework before signing Runner.
- Install only the exact IPA produced from the tested commit.
- Record the commit, version, artifact SHA-256, and observed device result in
  the task handoff, not in source control.

## Extension compatibility

Mihon extensions are Android-oriented. The embedded server emulates their JVM
and Android API surface; it does not provide Android WebView or arbitrary
Android native libraries. Keep external APKBridge support as an explicit
fallback for extensions that genuinely require unsupported Android features.

For HTTP and media regressions, compare request URL, headers, cookies,
redirects, range behavior, and response content type with native Mihon before
adding source-specific workarounds.

The pinned OpenJDK runtime currently emits class-file major version 71
(Java 27). Dex2jar hierarchy analysis must therefore resolve a coherent ASM
toolchain that supports `Opcodes.V27`. Keep the server regression test and the
preparation-time `javap` check when updating either OpenJDK or the extension
server.
