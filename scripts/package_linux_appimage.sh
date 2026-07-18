#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Package an existing Flutter Linux bundle as an AppImage.

This helper never builds the Flutter app or downloads appimagetool.

Usage:
  ./scripts/package_linux_appimage.sh \
    --bundle PATH \
    --output PATH \
    [--appimagetool PATH_OR_COMMAND] \
    [--arch x86_64]

Options:
  --bundle PATH        Existing Flutter Linux bundle directory.
  --output PATH        New AppImage output path; must not already exist.
  --appimagetool PATH  Existing appimagetool executable. Defaults to the
                       appimagetool command on PATH.
  --arch ARCH          AppImage architecture. Only x86_64 is currently
                       supported because the tracked torrent library is x86-64.
  -h, --help           Show this help text.
USAGE
}

die() {
  printf '[linux-appimage] error: %s\n' "$*" >&2
  exit 1
}

bundle_path=
output_path=
appimagetool_value=appimagetool
appimage_arch=

while (($#)); do
  case "$1" in
    --bundle)
      (($# >= 2)) || die '--bundle requires a path.'
      bundle_path=$2
      shift
      ;;
    --bundle=*)
      bundle_path=${1#--bundle=}
      ;;
    --output)
      (($# >= 2)) || die '--output requires a path.'
      output_path=$2
      shift
      ;;
    --output=*)
      output_path=${1#--output=}
      ;;
    --appimagetool)
      (($# >= 2)) || die '--appimagetool requires a path or command.'
      appimagetool_value=$2
      shift
      ;;
    --appimagetool=*)
      appimagetool_value=${1#--appimagetool=}
      ;;
    --arch)
      (($# >= 2)) || die '--arch requires a value.'
      appimage_arch=$2
      shift
      ;;
    --arch=*)
      appimage_arch=${1#--arch=}
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
  shift
done

[[ "$(uname -s)" == Linux ]] || die 'AppImages must be packaged on Linux.'
[[ -n "$bundle_path" ]] || die '--bundle is required.'
[[ -n "$output_path" ]] || die '--output is required.'
[[ -d "$bundle_path" ]] || die "bundle directory was not found: $bundle_path"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
bundle_dir="$(cd -- "$bundle_path" && pwd -P)"

[[ -x "$bundle_dir/mangayomi" ]] || \
  die "bundle does not contain an executable mangayomi binary: $bundle_dir"
[[ -d "$bundle_dir/data" ]] || die "bundle is missing its data directory: $bundle_dir"
[[ -d "$bundle_dir/lib" ]] || die "bundle is missing its lib directory: $bundle_dir"

if [[ "$appimagetool_value" == */* ]]; then
  [[ -x "$appimagetool_value" ]] || \
    die "appimagetool is not executable: $appimagetool_value"
  appimagetool_dir="$(cd -- "$(dirname -- "$appimagetool_value")" && pwd -P)"
  appimagetool="$appimagetool_dir/$(basename -- "$appimagetool_value")"
else
  appimagetool="$(command -v "$appimagetool_value" || true)"
  [[ -n "$appimagetool" ]] || \
    die "appimagetool was not found on PATH: $appimagetool_value"
fi

if [[ -z "$appimage_arch" ]]; then
  case "$(uname -m)" in
    x86_64 | amd64)
      appimage_arch=x86_64
      ;;
    *)
      die 'only x86_64 AppImages are supported by the tracked native libraries.'
      ;;
  esac
fi
case "$appimage_arch" in
  x86_64) ;;
  *) die "unsupported AppImage architecture: $appimage_arch" ;;
esac

output_parent="$(dirname -- "$output_path")"
mkdir -p -- "$output_parent"
output_parent="$(cd -- "$output_parent" && pwd -P)"
output_file="$output_parent/$(basename -- "$output_path")"
[[ ! -e "$output_file" ]] || die "output already exists: $output_file"

desktop_source="$repo_root/linux/mangayomi.desktop"
app_run_source="$repo_root/linux/packaging/appimage/AppRun"
icon_source="$repo_root/assets/app_icons/icon-red.png"
[[ -f "$desktop_source" ]] || die "desktop entry was not found: $desktop_source"
[[ -f "$app_run_source" ]] || die "AppRun was not found: $app_run_source"
[[ -f "$icon_source" ]] || die "icon was not found: $icon_source"
grep -Fqx 'Exec=/usr/bin/mangayomi %u' "$desktop_source" || \
  die 'desktop entry has an unexpected Exec command.'

work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT
app_dir="$work_dir/Mangatan.AppDir"
mkdir -p -- "$app_dir/usr/bin"
cp -a -- "$bundle_dir/." "$app_dir/usr/bin/"
install -m 0755 -- "$app_run_source" "$app_dir/AppRun"
install -m 0644 -- "$icon_source" "$app_dir/mangayomi.png"
sed 's|^Exec=/usr/bin/mangayomi %u$|Exec=mangayomi %u|' \
  "$desktop_source" >"$app_dir/mangayomi.desktop"

printf '[linux-appimage] Packaging %s\n' "$output_file"
ARCH="$appimage_arch" "$appimagetool" "$app_dir" "$output_file"
printf '[linux-appimage] Created %s\n' "$output_file"
