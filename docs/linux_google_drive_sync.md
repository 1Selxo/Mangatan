# Linux Google Drive sync requirements

Mangatan uses the same Chimahon-compatible sync path on macOS, Windows, and
Linux. Linux-specific code is limited to browser callback registration and
refresh-token storage.

Build hosts need the libsecret development headers:

- Debian/Ubuntu: `libsecret-1-dev`
- Fedora: `libsecret-devel`
- Arch: `libsecret`

Runtime hosts need `libsecret`, `xdg-utils`, a desktop D-Bus session, and an
available Secret Service implementation such as GNOME Keyring or KDE Wallet.
The Debian package declares `libsecret-1-0` and `xdg-utils`; other package
formats must provide the equivalent distro packages.

The Linux secure-storage plugin uses its application-level Secret Service
collection label and does not expose Mangatan's per-token macOS Keychain label.
Any unlock prompt is therefore supplied and worded by the desktop keyring.

The desktop package advertises both `mangayomi:` and
`app.chimahon.google.oauth:` URI schemes. AppImage users must allow desktop
association so the browser can route the OAuth callback back to Mangatan;
Mangatan can install its own ownership-marked per-user association when doing
so will not replace another application's default handler. Third-party
AppImage integration may rename the desktop ID, so verify both scheme defaults
with `xdg-mime query default` after integration.

## Packaging an AppImage

Do not use Fastforge 0.6.9's generated AppImage `AppRun` for Mangatan. It does
not forward command-line arguments, so an integrated AppImage opens without
delivering the OAuth or diagnostic URI to the Flutter process.

Build the Flutter Linux bundle separately, provide an existing `appimagetool`,
and package that bundle with the repository helper:

```sh
./scripts/package_linux_appimage.sh \
  --bundle build/linux/x64/release/bundle \
  --output dist/Mangatan-linux-x86_64.AppImage \
  --appimagetool /path/to/appimagetool
```

The helper neither runs Flutter nor downloads tools. It creates a temporary
AppDir, uses the tracked `linux/packaging/appimage/AppRun` that preserves every
argument with `"$@"`, installs the URI-aware desktop entry, invokes the supplied
tool, and removes the temporary AppDir. It refuses to overwrite an existing
output. It deliberately accepts only `x86_64`: the repository's tracked
`libmtorrentserver.so` is x86-64, so Linux ARM64 packages are not yet supported.

A locked keyring can show the desktop environment's normal unlock prompt. A
headless session without D-Bus and a Secret Service cannot persist the refresh
token securely.
