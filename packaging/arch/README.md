# AUR publishing

Each successful stable Mangatan release publishes `mangatan-bin` to the AUR.
Private and prerelease releases are excluded.

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

The next stable release will update the `mangatan-bin` AUR repository. To
publish an existing release without rebuilding Mangatan, run the
`Publish AUR package` workflow manually. Leave the tag blank for the latest
stable release or enter a tag such as `v1.0.9`.

## What the workflow does

The workflow downloads `SHA256SUMS-linux.txt` from the GitHub release, renders
`PKGBUILD.template`, fetches checksums for the tagged desktop file and license,
generates `.SRCINFO` with the current Arch `makepkg`, and pushes only
`PKGBUILD`, `.SRCINFO`, and the 0BSD packaging license to the AUR.

To inspect the rendered package locally:

```sh
scripts/render_aur_package.sh \
  v1.0.9 \
  SHA256SUMS-linux.txt \
  /tmp/mangatan-aur
```
