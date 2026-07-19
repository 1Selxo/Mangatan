# Mangatan EPUB blob protocol v1

Mangatan transfers EPUB bytes outside Chimahon's `Chimahon_sync.proto.gz`
payload. The Chimahon protobuf and gzip file remain unchanged; Chimahon clients
do not understand, upload, download, or delete these sidecar files.

## Objects

Providers expose a small content-addressed blob API:

- `Mangatan_epub_manifest_v1.json`: UTF-8 JSON manifest.
- Immutable EPUB blobs addressed by lowercase SHA-256 hex and byte size.

Google Drive stores both in `appDataFolder`. WebDAV stores the manifest in the
configured collection and blobs under `mangatan-epub-blobs/`. Future providers
should use the same logical API even if their paths differ.

## Manifest

The manifest is provider-neutral JSON:

```json
{
  "protocolVersion": 1,
  "generatedAtUtc": "2026-07-19T00:00:00.000Z",
  "deviceId": "opaque-device-id",
  "entries": [
    {
      "stableNovelId": "chimahon-md5-or-retained-id",
      "sha256": "64 lowercase hex characters",
      "sizeBytes": 12345,
      "fileName": "Book.epub",
      "title": "Book",
      "author": "Author",
      "lang": "en",
      "updatedAtUtc": "2026-07-19T00:00:00.000Z"
    }
  ]
}
```

`stableNovelId` is the same stable identity used by Mangatan's Chimahon novel
adapter: the Chimahon normalized `title|author` MD5, or the retained Chimahon
book ID for empty metadata. Filesystem paths are never serialized.

## Rules

- Blobs are immutable. If an EPUB changes, Mangatan uploads a new SHA-256 blob
  and points the manifest entry at it.
- Providers should deduplicate by SHA-256. Re-uploading an existing blob is a
  no-op.
- Manifest writes must be conditional on the revision that was read. Conflicts
  are retried by re-reading and merging.
- A missing local EPUB path is not a deletion signal. Mangatan keeps the remote
  manifest entry unless a future explicit-delete UI writes `deleted: true`.
- Downloads are verified by both `sizeBytes` and SHA-256 before materializing.
  Partial downloads use a temporary `.part` file and are renamed only after
  verification.
- A verified download is imported through Mangatan's Chimahon novel
  materializer path, preserving identity, progress, statistics, categories and
  metadata while replacing only the device-local file association.
- Quota and provider errors surface as sync storage exceptions. Retrying the
  normal sync action resumes from already-uploaded immutable blobs.
