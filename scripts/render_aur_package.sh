#!/usr/bin/env bash

set -euo pipefail

usage() {
  printf 'Usage: %s <stable-release-tag> <linux-checksum-file> <output-directory>\n' \
    "${0##*/}" >&2
}

if (( $# != 3 )); then
  usage
  exit 2
fi

release_tag=$1
checksum_file=$2
output_dir=$3

if [[ ! $release_tag =~ ^v[0-9]+([.][0-9]+)*$ ]]; then
  printf 'AUR publishing requires a stable vX.Y.Z-style tag, got: %s\n' \
    "$release_tag" >&2
  exit 1
fi

if [[ ! -f $checksum_file ]]; then
  printf 'Linux checksum file does not exist: %s\n' "$checksum_file" >&2
  exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
template="$repo_root/packaging/arch/PKGBUILD.template"
package_license="$repo_root/packaging/arch/LICENSE"
pkgver=${release_tag#v}
archive_name="Mangatan-${release_tag}-linux-x86_64.tar.gz"

mapfile -t archive_checksums < <(
  awk -v archive="$archive_name" \
    '$2 == archive || $2 == "*" archive { print $1 }' \
    "$checksum_file"
)

if (( ${#archive_checksums[@]} != 1 )) ||
  [[ ! ${archive_checksums[0]} =~ ^[[:xdigit:]]{64}$ ]]; then
  printf 'Expected exactly one SHA-256 entry for %s in %s\n' \
    "$archive_name" "$checksum_file" >&2
  exit 1
fi

checksum_url() {
  curl --fail --location --silent --show-error "$1" |
    sha256sum |
    awk '{ print $1 }'
}

desktop_url="https://raw.githubusercontent.com/1Selxo/Mangatan/${release_tag}/linux/mangayomi.desktop"
license_url="https://raw.githubusercontent.com/1Selxo/Mangatan/${release_tag}/LICENSE"
desktop_checksum=$(checksum_url "$desktop_url")
license_checksum=$(checksum_url "$license_url")

install -d "$output_dir"
sed \
  -e "s/@PKGVER@/$pkgver/g" \
  -e "s/@ARCHIVE_SHA256@/${archive_checksums[0]}/g" \
  -e "s/@DESKTOP_SHA256@/$desktop_checksum/g" \
  -e "s/@LICENSE_SHA256@/$license_checksum/g" \
  "$template" > "$output_dir/PKGBUILD"
install -m644 "$package_license" "$output_dir/LICENSE"

if grep -Eq '@[A-Z0-9_]+@' "$output_dir/PKGBUILD"; then
  printf 'Rendered PKGBUILD still contains template tokens\n' >&2
  exit 1
fi

bash -n "$output_dir/PKGBUILD"
printf 'Rendered mangatan-bin %s with archive SHA-256 %s\n' \
  "$pkgver" "${archive_checksums[0]}"
