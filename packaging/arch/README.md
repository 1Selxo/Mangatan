# AUR publishing

Each successful stable Mangatan release publishes the self-contained
`mangatan-bin` package. Private and prerelease releases are excluded.

The package installs the complete Linux release archive, including the Mihon
extension-server JAR and portable Java runtime built from Mangatan's vendored
server source. Users do not need `mangatan-extension-server`, a system JRE, or a
manual download through Settings.

The workflow still maintains the legacy `mangatan-extension-server` package for
older Mangatan releases that did not bundle the bridge. It is no longer an
`optdepends` of current `mangatan-bin` packages.

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

The next stable release updates `mangatan-bin`. To publish an existing release
without rebuilding Mangatan, run the `Publish AUR package` workflow manually.
Leave the Mangatan tag blank for the latest stable release, or enter one such as
`v1.0.9`.

## What the workflow does

The `publish` job downloads `SHA256SUMS-linux.txt` from the GitHub release,
renders `PKGBUILD.template`, and fetches checksums for the tagged desktop file
and license. The release archive already contains the server and JRE.

The `publish-extension-server` job is retained only for backwards compatibility
and renders `PKGBUILD-extension-server.template` from a stable historical
M-Extension-Server release. Both jobs generate `.SRCINFO` with the current Arch
`makepkg` and push only `PKGBUILD`, `.SRCINFO`, and the 0BSD packaging license.

`.SRCINFO` generation runs `makepkg --printsrcinfo`, which does **not** download
sources, so CI cannot catch a wrong checksum. The render scripts therefore use
checksums from release sources rather than accepting hand-copied values.
`pkgrel` is hardcoded to `1`; bump it in the template when packaging changes
without a version change, or the push is a no-op.

To inspect the rendered packages locally:

```sh
scripts/render_aur_package.sh \
  v1.0.9 \
  SHA256SUMS-linux.txt \
  /tmp/mangatan-aur

# Legacy package for older Mangatan releases only:
scripts/render_aur_extension_server.sh \
  v1.0.6.0 \
  /tmp/mangatan-extension-server-aur
```
