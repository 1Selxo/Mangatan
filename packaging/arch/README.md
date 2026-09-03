# AUR publishing

Each successful stable Mangatan release publishes two AUR packages. Private and
prerelease releases are excluded.

| Package | Template | Versioned by |
| --- | --- | --- |
| `mangatan-bin` | `PKGBUILD.template` | the Mangatan release tag |
| `mangatan-extension-server` | `PKGBUILD-extension-server.template` | the latest stable [M-Extension-Server](https://github.com/1Selxo/M-Extension-Server) tag |

`mangatan-extension-server` is an `optdepends` of `mangatan-bin`: it provides
Mihon extension support (the "Mihon bridge") and is not needed to read local or
Mangayomi-sourced content. Installing it means the bridge works with no trip
through Settings, because Mangatan discovers
`/usr/share/mangatan/extension_server` on startup.

It carries only the ~100 MiB server JAR and depends on `jre21-openjdk` rather
than vendoring the ~135 MiB JRE that upstream's bundle ships. The JAR is
byte-identical across upstream's Linux, macOS and Windows bundles and contains
JNI natives for every architecture, so the package is `arch=any` — which also
makes the bridge available on aarch64, where the in-app download has no asset.

Two naming constraints are load-bearing and will silently break detection if
changed: the installed JAR must keep the `MExtensionServer-` prefix with a `.jar`
suffix, and must retain a parseable `vX.Y.Z` in its basename or the app reports
version `1.0.0` and offers a perpetual bogus update. The `java` symlink must sit
at exactly `jre/jre/bin/java` under the server directory, mirroring the layout of
the bundle the app would otherwise download.

## One-time setup

1. Create or sign in to an AUR account.
2. Generate a dedicated, unencrypted SSH key:

   ```sh
   ssh-keygen -t ed25519 -N '' -f mangatan-aur -C 'Mangatan AUR automation'
   ```

3. Add `mangatan-aur.pub` to the SSH public keys in the AUR account.
4. Add the contents of `mangatan-aur` to the GitHub repository secret
   `AUR_SSH_PRIVATE_KEY`.
5. Delete both local key files after storing the private key somewhere secure,
   or retain them in a password manager for recovery.

6. Register both package bases on the AUR. The workflow pushes to existing
   repositories and does not create them.

The next stable release will update both AUR repositories. To publish an
existing release without rebuilding Mangatan, run the `Publish AUR package`
workflow manually. Leave a tag blank for the latest stable release, or enter one
such as `v1.0.9`; the two tags are independent.

## What the workflow does

The `publish` job downloads `SHA256SUMS-linux.txt` from the GitHub release,
renders `PKGBUILD.template`, and fetches checksums for the tagged desktop file
and license. The `publish-extension-server` job resolves the latest stable
M-Extension-Server release and renders
`PKGBUILD-extension-server.template`, hashing the bundle in-flight because
upstream publishes no checksum asset. Both then generate `.SRCINFO` with the
current Arch `makepkg` and push only `PKGBUILD`, `.SRCINFO`, and the 0BSD
packaging license.

Because the server versions independently of the app, its job normally finds the
AUR already up to date and exits without pushing.

Note that `.SRCINFO` generation runs `makepkg --printsrcinfo`, which does **not**
download sources, so CI cannot catch a wrong checksum — only users can. Both
render scripts therefore compute checksums from the live release rather than
accepting a hand-copied value. `pkgrel` is hardcoded to `1`; bump it in the
template when packaging changes without a version change, or the push is a no-op.

To inspect the rendered packages locally:

```sh
scripts/render_aur_package.sh \
  v1.0.9 \
  SHA256SUMS-linux.txt \
  /tmp/mangatan-aur

scripts/render_aur_extension_server.sh \
  v1.0.6.0 \
  /tmp/mangatan-extension-server-aur
```
