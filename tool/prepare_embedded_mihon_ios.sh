#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd "$script_dir/.." && pwd)
generated_dir="$repo_dir/ios/EmbeddedMihon/runtime"
framework_dir="$repo_dir/ios/Frameworks/OpenJDK.xcframework"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/mangatan-embedded-mihon.XXXXXX")
trap 'find "$work_dir" -depth -delete' EXIT

server_repository="https://github.com/ippo-michi/M-Extension-Server.git"
server_commit="f64273694e67e2784742db1f28329794a7c78876"
openjdk_framework_url="https://github.com/ippo-michi/Mangatan/releases/download/embedded-openjdk-ios13-v1/OpenJDK.xcframework.zip"
openjdk_framework_sha256="c227e55eb3adb0578fff3064828668365f21e02af13430ab8f207553b6d6f7eb"
openjdk_bundle_url="https://github.com/ippo-michi/Mangatan/releases/download/embedded-openjdk-ios13-v1/java_bundle-device.zip"
openjdk_bundle_sha256="4101f1890483e6903917b0437d9fcacc626d394ce52507385b8675009507eb76"

if [[ -z "${JAVA_HOME:-}" || ! -x "$JAVA_HOME/bin/javac" ]]; then
  echo "JAVA_HOME must point to a JDK 21 or newer." >&2
  exit 1
fi

java_major=$("$JAVA_HOME/bin/java" -version 2>&1 |
  sed -n '1s/.*version "\([0-9][0-9]*\).*/\1/p')
if [[ -z "$java_major" || "$java_major" -lt 21 ]]; then
  echo "JDK 21 or newer is required; found ${java_major:-unknown}." >&2
  exit 1
fi

download_and_verify() {
  local url=$1
  local sha256=$2
  local destination=$3
  curl --fail --location --retry 3 --output "$destination" "$url"
  (
    cd "$(dirname "$destination")"
    printf '%s  %s\n' "$sha256" "$(basename "$destination")" |
      shasum -a 256 --check
  )
}

echo "Building pinned M-Extension-Server $server_commit"
git init -q "$work_dir/server"
git -C "$work_dir/server" remote add origin "$server_repository"
git -C "$work_dir/server" fetch --depth 1 origin "$server_commit"
git -C "$work_dir/server" -c advice.detachedHead=false \
  checkout --detach FETCH_HEAD
(
  cd "$work_dir/server"
  GRADLE_USER_HOME="${GRADLE_USER_HOME:-$work_dir/gradle}" \
    ./gradlew :server:shadowJar -PiosRuntime=true --no-daemon
)
server_jar=$(find "$work_dir/server/server/build" -maxdepth 1 \
  -type f -name 'MExtensionServer-*.jar' -print -quit)
if [[ -z "$server_jar" ]]; then
  echo "The embedded extension server JAR was not produced." >&2
  exit 1
fi
if "$JAVA_HOME/bin/jar" tf "$server_jar" |
  grep -Eq '^(ch/qos/logback|org/cef|dev/datlag/kcef)/'; then
  echo "The iOS server JAR contains excluded desktop runtime classes." >&2
  exit 1
fi
server_entries="$work_dir/server-entries.txt"
"$JAVA_HOME/bin/jar" tf "$server_jar" > "$server_entries"
for required_resource in r_styles.ini r_values.ini; do
  if ! grep -qx "$required_resource" "$server_entries"; then
    echo "The iOS server JAR is missing $required_resource." >&2
    exit 1
  fi
done

echo "Downloading verified OpenJDK Mobile runtime"
download_and_verify \
  "$openjdk_framework_url" \
  "$openjdk_framework_sha256" \
  "$work_dir/OpenJDK.xcframework.zip"
download_and_verify \
  "$openjdk_bundle_url" \
  "$openjdk_bundle_sha256" \
  "$work_dir/java_bundle-device.zip"
unzip -q "$work_dir/OpenJDK.xcframework.zip" -d "$work_dir/framework"
unzip -q "$work_dir/java_bundle-device.zip" -d "$work_dir/java-bundle"
runtime_archive=$(find "$work_dir/framework/OpenJDK.xcframework" \
  -type f -name 'libdevice.a' -print -quit)
if [[ -z "$runtime_archive" ]]; then
  echo "The OpenJDK XCFramework does not contain libdevice.a." >&2
  exit 1
fi
runtime_objects="$work_dir/runtime-objects"
mkdir "$runtime_objects"
(
  cd "$runtime_objects"
  ar -x "$runtime_archive"
)
python3 "$repo_dir/tool/verify_macho_min_ios.py" \
  --maximum 13.0 "$runtime_objects"

echo "Building java.util.logging compatibility shim"
shim_source="$repo_dir/tool/ios_jul_shim"
shim_classes="$work_dir/logging-shim-classes"
mkdir -p "$shim_classes"
"$JAVA_HOME/bin/javac" \
  --patch-module "java.logging=$shim_source" \
  -d "$shim_classes" \
  "$shim_source/java/util/logging/Level.java" \
  "$shim_source/java/util/logging/Logger.java"
"$JAVA_HOME/bin/jar" \
  --create \
  --file "$work_dir/java-logging-shim.jar" \
  -C "$shim_classes" .

echo "Staging embedded iOS runtime"
find "$generated_dir" -depth -delete 2>/dev/null || true
find "$framework_dir" -depth -delete 2>/dev/null || true
mkdir -p "$generated_dir/lib/security"
mkdir -p "$(dirname "$framework_dir")"
cp -R "$work_dir/framework/OpenJDK.xcframework" "$framework_dir"
cp "$work_dir/java-bundle/java_bundle-device/lib/modules" \
  "$generated_dir/lib/modules"
cp "$work_dir/java-bundle/java_bundle-device/release" \
  "$generated_dir/release"
cp "$JAVA_HOME/lib/security/cacerts" \
  "$generated_dir/lib/security/cacerts"
cp "$server_jar" "$generated_dir/MExtensionServer.jar"
cp "$work_dir/java-logging-shim.jar" \
  "$generated_dir/java-logging-shim.jar"
cp "$repo_dir/ios/EmbeddedMihon/THIRD_PARTY_NOTICES.md" \
  "$generated_dir/THIRD_PARTY_NOTICES.md"

test -f "$framework_dir/Info.plist"
test -f "$generated_dir/lib/modules"
test -f "$generated_dir/MExtensionServer.jar"
echo "Embedded Mihon iOS runtime is ready."
