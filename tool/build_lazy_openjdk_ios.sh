#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd "$script_dir/.." && pwd)
static_framework="$repo_dir/ios/Frameworks/OpenJDK.xcframework"
output_framework="$repo_dir/ios/Frameworks/OpenJDKRuntime.framework"
runtime_modules="$repo_dir/ios/EmbeddedMihon/runtime/lib/modules"
runtime_tzdb="$repo_dir/ios/EmbeddedMihon/runtime/lib/tzdb.dat"
runtime_security="$repo_dir/ios/EmbeddedMihon/runtime/lib/security"
runtime_conf="$repo_dir/ios/EmbeddedMihon/runtime/conf"
minimum_ios_version="${IOS_MINIMUM_VERSION:-13.0}"

if [[ "$(uname -s)" != Darwin ]]; then
  echo "The lazy OpenJDK iOS framework must be built on macOS." >&2
  exit 1
fi

static_library=$(find "$static_framework" \
  -type f -name 'libdevice.a' -print -quit)
headers_dir=$(find "$static_framework" \
  -type d -name Headers -print -quit)
if [[ -z "$static_library" || -z "$headers_dir" ]]; then
  echo "OpenJDK.xcframework is incomplete. Prepare the embedded runtime first." >&2
  exit 1
fi
if [[ ! -f "$runtime_modules" ]]; then
  echo "The embedded OpenJDK module image is missing." >&2
  exit 1
fi
if [[ ! -f "$runtime_tzdb" ]]; then
  echo "The embedded OpenJDK timezone database is missing." >&2
  exit 1
fi
if [[ ! -f "$runtime_security/public_suffix_list.dat" ]]; then
  echo "The embedded OpenJDK security data is missing." >&2
  exit 1
fi
if [[ ! -f "$runtime_conf/security/java.security" ]]; then
  echo "The embedded OpenJDK security configuration is missing." >&2
  exit 1
fi

find "$output_framework" -depth -delete 2>/dev/null || true
mkdir -p "$output_framework/Headers" "$output_framework/lib/lib"
cp -R "$headers_dir/." "$output_framework/Headers/"
cp "$script_dir/OpenJDKRuntime-Info.plist" "$output_framework/Info.plist"
cp "$runtime_modules" "$output_framework/lib/lib/modules"
cp "$runtime_tzdb" "$output_framework/lib/lib/tzdb.dat"
cp -R "$runtime_security" "$output_framework/lib/lib/security"
cp -R "$runtime_conf" "$output_framework/lib/conf"

iphone_sdk=$(xcrun --sdk iphoneos --show-sdk-path)
xcrun --sdk iphoneos clang++ \
  -target "arm64-apple-ios${minimum_ios_version}" \
  -isysroot "$iphone_sdk" \
  -dynamiclib \
  -Wl,-all_load \
  "$static_library" \
  "$script_dir/openjdk_runtime_exports.cpp" \
  -Wl,-install_name,@rpath/OpenJDKRuntime.framework/OpenJDKRuntime \
  -Wl,-compatibility_version,1.0.0 \
  -Wl,-current_version,1.0.0 \
  -lz \
  -framework Foundation \
  -framework CoreFoundation \
  -o "$output_framework/OpenJDKRuntime"

test -x "$output_framework/OpenJDKRuntime"
test -f "$output_framework/lib/lib/modules"
test -f "$output_framework/lib/lib/tzdb.dat"
test -f "$output_framework/lib/lib/security/public_suffix_list.dat"
test -f "$output_framework/lib/conf/security/java.security"
python3 "$script_dir/verify_macho_min_ios.py" \
  --maximum "$minimum_ios_version" \
  "$output_framework/OpenJDKRuntime"
echo "Lazy OpenJDK iOS framework is ready."
