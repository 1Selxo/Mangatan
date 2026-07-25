# Windows release signing

Mangatan's Windows release contains a small native ScreenAI bridge that loads
the Chrome or Edge ScreenAI component already installed on the user's machine.
Unsigned native bridges and unsigned installers can receive generic cloud
heuristic detections even when their source is part of this repository.

The release workflow therefore refuses to publish Windows artifacts unless a
code-signing certificate is configured. Add these GitHub Actions secrets:

- `WINDOWS_SIGNING_CERT_BASE64`: the base64-encoded contents of a trusted PFX
  code-signing certificate.
- `WINDOWS_SIGNING_CERT_PASSWORD`: the PFX password.

On Windows, the first value can be prepared without writing it to the console:

```powershell
[Convert]::ToBase64String(
  [IO.File]::ReadAllBytes('C:\secure\mangatan-signing.pfx')
) | Set-Clipboard
```

The workflow signs every previously unsigned executable and DLL in the
application bundle, verifies the signatures on `mangayomi.exe` and
`screen_ai_bridge.dll`, builds and signs the installer, and publishes
`SHA256SUMS.txt` with the release artifacts.

Signing improves publisher reputation and makes tampering detectable, but no
vendor can guarantee that heuristic engines never produce false positives. If
a correctly signed artifact is still detected, submit that exact release file
and its SHA-256 hash to the antivirus vendor as a false positive.
