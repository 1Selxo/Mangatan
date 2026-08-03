#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --output DIRECTORY [--ios]" >&2
  exit 2
}

output=""
ios_runtime=false
while (($#)); do
  case "$1" in
    --output)
      (($# >= 2)) || usage
      output=$2
      shift 2
      ;;
    --ios)
      ios_runtime=true
      shift
      ;;
    *) usage ;;
  esac
done
[[ -n "$output" ]] || usage

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd -- "$script_dir/.." && pwd)
server_dir="$repo_dir/third_party/mihon_server"
output=$(mkdir -p "$output" && cd "$output" && pwd)

if [[ -z "${JAVA_HOME:-}" || ! -x "$JAVA_HOME/bin/java" ]]; then
  echo "JAVA_HOME must point to JDK 21 or newer." >&2
  exit 1
fi
java_major=$("$JAVA_HOME/bin/java" -version 2>&1 |
  sed -n '1s/.*version "\([0-9][0-9]*\).*/\1/p')
if [[ -z "$java_major" || "$java_major" -lt 21 ]]; then
  echo "JDK 21 or newer is required; found ${java_major:-unknown}." >&2
  exit 1
fi

rm -rf -- "$output"/*
gradle_args=(
  :server:clean
  :server:shadowJar
  --no-daemon
  --stacktrace
)
if $ios_runtime; then
  gradle_args+=("-PiosRuntime=true")
fi
(
  cd "$server_dir"
  ./gradlew "${gradle_args[@]}"
)

shopt -s nullglob
jars=("$server_dir"/server/build/MExtensionServer-*.jar)
if ((${#jars[@]} != 1)); then
  echo "Expected exactly one server JAR, found ${#jars[@]}." >&2
  printf '  %s\n' "${jars[@]}" >&2
  exit 1
fi
cp "${jars[0]}" "$output/MExtensionServer.jar"
cp "$server_dir/LICENSE" "$output/M-Extension-Server-LICENSE.txt"
cp "$server_dir/README.md" "$output/M-Extension-Server-README.md"
cp "$repo_dir/third_party/newpipe_extractor/LICENSE" \
  "$output/NewPipe-Extractor-LICENSE.txt"
cp "$repo_dir/third_party/newpipe_extractor/VENDORED.md" \
  "$output/NewPipe-Extractor-SOURCE.txt"

if ! $ios_runtime; then
  modules='java.base,java.compiler,java.datatransfer,java.desktop,java.instrument,java.logging,java.management,java.naming,java.prefs,java.scripting,java.se,java.security.jgss,java.security.sasl,java.sql,java.transaction.xa,java.xml,jdk.attach,jdk.crypto.ec,jdk.jdi,jdk.management,jdk.net,jdk.unsupported,jdk.unsupported.desktop,jdk.zipfs,jdk.accessibility'
  "$JAVA_HOME/bin/jlink" \
    --add-modules "$modules" \
    --output "$output/jre" \
    --strip-debug \
    --no-man-pages \
    --no-header-files \
    --compress=2
  test -x "$output/jre/bin/java"
fi

test -s "$output/MExtensionServer.jar"
echo "Built vendored Mihon server bundle at $output"
