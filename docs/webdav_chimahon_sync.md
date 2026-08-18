# WebDAV Chimahon sync

Mangatan can use a WebDAV collection as a desktop Chimahon-compatible sync
provider on macOS, Windows, and Linux. Mobile paths are intentionally not
changed.

## Remote files

Mangatan writes the normal Chimahon payload as gzip-protobuf:

- `Chimahon_sync.proto.gz`

The Chimahon protobuf schema is unchanged. WebDAV is only a transport.

When EPUB file transfer is enabled by normal sync, WebDAV also implements the
provider-neutral Mangatan sidecar protocol documented in
[`docs/mangatan_epub_blob_protocol.md`](mangatan_epub_blob_protocol.md):

- `Mangatan_epub_manifest_v1.json`
- `mangatan-epub-blobs/<sha256>.epub`

Chimahon clients ignore these sidecar files.

## Supported authentication

The first implementation supports HTTP Basic authentication over the WebDAV
URL supplied by the user. Use HTTPS whenever the server is not strictly local.
Some providers call app passwords or access tokens "passwords"; those work as
long as the server accepts them through Basic auth.

The WebDAV URL is stored in local preferences. The username and password/token
are stored in the desktop secure credential store through the same secure
backend used by Google Drive credentials. Credentials are not exported to Isar
backups, sync payloads, logs, or Chimahon protobuf data.

## Safety requirements

Mangatan refuses blind last-writer-wins WebDAV uploads.

The server must:

- accept `If-None-Match: *` for creating new files;
- accept `If-Match: "<etag>"` for updating existing files;
- return a strong quoted `ETag` after successful GET/HEAD/PUT operations;
- preserve normal WebDAV paths and redirects for the configured collection.

If any of these checks fail, Mangatan stops and reports that WebDAV could not
verify safe conditional sync. This is deliberate: syncing without reliable
conditional writes could overwrite another device's changes.

## Server behavior and limitations

- Mangatan attempts `MKCOL` for the configured collection and the EPUB blob
  subcollection. Existing collections may return `405 Method Not Allowed`,
  which is treated as success.
- Redirects are followed for sync requests.
- The configured collection should be private to this Mangatan/Chimahon sync
  account.
- Servers that omit ETags after PUT, return weak ETags, or do not enforce
  preconditions are unsupported.
- Explicit EPUB deletion UI is not part of this protocol revision. A missing
  local EPUB never deletes a remote blob or manifest entry.
