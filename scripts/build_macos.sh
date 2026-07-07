#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Build the macOS app and open it by default.

Usage:
  ./scripts/build_macos.sh [debug|profile|release] [options]

Options:
  --debug       Build a debug app. This is the default.
  --profile     Build a profile app.
  --release     Build a release app.
  --clean       Run flutter clean before building.
  --no-open     Build only; do not open the app afterward.
  --open        Open the app after building. This is the default.
  -h, --help    Show this help text.

Examples:
  ./scripts/build_macos.sh
  ./scripts/build_macos.sh --release
  ./scripts/build_macos.sh --clean --no-open

Extra Flutter build flags can be passed after --:
  ./scripts/build_macos.sh --release -- --verbose
USAGE
}

log() {
  printf '[macos-build] %s\n' "$*"
}

die() {
  printf '[macos-build] error: %s\n' "$*" >&2
  exit 1
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"

build_mode="debug"
open_app=1
clean_first=0
flutter_args=()

while (($#)); do
  case "$1" in
    debug | --debug)
      build_mode="debug"
      ;;
    profile | --profile)
      build_mode="profile"
      ;;
    release | --release)
      build_mode="release"
      ;;
    --open)
      open_app=1
      ;;
    --no-open)
      open_app=0
      ;;
    --clean)
      clean_first=1
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      flutter_args+=("$@")
      break
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
  shift
done

[[ "$(uname -s)" == "Darwin" ]] || die "macOS builds must be run on macOS."
command -v flutter >/dev/null 2>&1 || die "flutter was not found on PATH."

case "$build_mode" in
  debug)
    build_config="Debug"
    ;;
  profile)
    build_config="Profile"
    ;;
  release)
    build_config="Release"
    ;;
  *)
    die "unsupported build mode: $build_mode"
    ;;
esac

cd "$repo_root"

if ((clean_first)); then
  log "Cleaning Flutter build output"
  flutter clean
fi

log "Building macOS $build_mode app"
build_command=(flutter build macos "--$build_mode")
if ((${#flutter_args[@]})); then
  build_command+=("${flutter_args[@]}")
fi
"${build_command[@]}"

app_name="$(
  awk -F ' = ' '/^PRODUCT_NAME = / { print $2; exit }' \
    "$repo_root/macos/Runner/Configs/AppInfo.xcconfig"
)"
app_name="${app_name:-Mangatan}"
app_path="$repo_root/build/macos/Build/Products/$build_config/$app_name.app"

if [[ ! -d "$app_path" ]]; then
  app_path="$(
    find "$repo_root/build/macos/Build/Products/$build_config" \
      -maxdepth 1 \
      -name '*.app' \
      -print \
      -quit
  )"
fi

[[ -n "$app_path" && -d "$app_path" ]] || die "built app was not found."

log "Built $app_path"

if ((open_app)); then
  log "Opening app"
  open "$app_path"
fi
