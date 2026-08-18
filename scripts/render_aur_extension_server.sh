#!/usr/bin/env bash

set -euo pipefail

usage() {
  printf 'Usage: %s <extension-server-release-tag> <output-directory>\n' \
    "${0##*/}" >&2
}

if (( $# != 2 )); then
  usage
  exit 2
fi

release_tag=$1
output_dir=$2

# M-Extension-Server uses four-component tags such as v1.0.6.0, and publishes
# ios-runtime-vN prereleases from the same repository. Only stable numeric tags
# are packageable.
if [[ ! $release_tag =~ ^v[0-9]+([.][0-9]+)*$ ]]; then
  printf 'Expected a stable vX.Y.Z-style extension server tag, got: %s\n' \
    "$release_tag" >&2
  exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
template="$repo_root/packaging/arch/PKGBUILD-extension-server.template"
package_license="$repo_root/packaging/arch/LICENSE"
pkgver=${release_tag#v}
server_repo="https://github.com/1Selxo/M-Extension-Server"

# Upstream publishes no checksum asset for the stable bundles, so hash the
# bundle in-flight rather than trusting a hand-copied value. This streams ~135
# MiB and never stores it.
checksum_url() {
  curl --fail --location --silent --show-error "$1" |
    sha256sum |
    awk '{ print $1 }'
}

bundle_url="$server_repo/releases/download/$release_tag/linux-x64-bundle.zip"
license_url="https://raw.githubusercontent.com/1Selxo/M-Extension-Server/$release_tag/LICENSE"
bundle_checksum=$(checksum_url "$bundle_url")
license_checksum=$(checksum_url "$license_url")

for checksum in "$bundle_checksum" "$license_checksum"; do
  if [[ ! $checksum =~ ^[[:xdigit:]]{64}$ ]]; then
    printf 'Computed an invalid SHA-256 for %s: %s\n' \
      "$release_tag" "$checksum" >&2
    exit 1
  fi
done

install -d "$output_dir"
sed \
  -e "s/@SERVERVER@/$pkgver/g" \
  -e "s/@SERVER_SHA256@/$bundle_checksum/g" \
  -e "s/@SERVER_LICENSE_SHA256@/$license_checksum/g" \
  "$template" > "$output_dir/PKGBUILD"
install -m644 "$package_license" "$output_dir/LICENSE"

if grep -Eq '@[A-Z0-9_]+@' "$output_dir/PKGBUILD"; then
  printf 'Rendered PKGBUILD still contains template tokens\n' >&2
  exit 1
fi

bash -n "$output_dir/PKGBUILD"
printf 'Rendered mangatan-extension-server %s with bundle SHA-256 %s\n' \
  "$pkgver" "$bundle_checksum"
