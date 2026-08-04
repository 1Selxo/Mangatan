# Desktop install guide

Mangatan ships prebuilt desktop apps on the
[releases page](https://github.com/1Selxo/Mangatan/releases). Download the
asset that matches your operating system, then follow the run step below. Each
platform's release also includes a `SHA256SUMS` file you can use to verify the
download.

## Windows

1. On the [latest release](https://github.com/1Selxo/Mangatan/releases/latest),
   download **either**:
   - `Mangatan-<version>-windows.exe` — the installer (recommended), or
   - `Mangatan-<version>-windows.zip` — a portable build.
2. Installer: run the `.exe` and follow the prompts.
   Portable: extract the `.zip` and run `mangayomi.exe` from the extracted
   folder.

## macOS

1. Download `Mangatan-<version>-macos-arm64.dmg` (Apple Silicon).
2. Open the `.dmg` and drag **Mangatan** into your **Applications** folder.
3. The build is unsigned, so the first launch is blocked by Gatekeeper.
   Right-click **Mangatan** → **Open**, then confirm **Open** in the dialog (or
   allow it under **System Settings → Privacy & Security**).

## Linux

1. Download `Mangatan-<version>-linux-x86_64.tar.gz`.
2. Extract it, then run the `mangayomi` binary from the extracted folder:

   ```sh
   tar -xzf Mangatan-<version>-linux-x86_64.tar.gz
   cd Mangatan-<version>-linux-x86_64
   ./mangayomi
   ```

   Arch Linux users can instead install the `mangatan-bin` package from the AUR
   (see [`packaging/arch/README.md`](../packaging/arch/README.md)).

## Android

The Android version lives in a separate project — see
[Chimahon](https://github.com/sohilsayed/chimahon).

## iOS

iOS is sideloaded from the unsigned IPA. See the **iOS Sideloading Sources**
section of the [README](../README.md).
