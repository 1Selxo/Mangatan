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

# The revision upstream's own release named MExtensionServer-v1.0.6.0-r1.jar.
# Bump this when re-vendoring; see the ProductRevision comment below for why it
# is pinned here and why it must stay numeric.
vendored_revision="r1"

if [[ -z "${JAVA_HOME:-}" || ! -x "$JAVA_HOME/bin/java" ]]; then
  echo "JAVA_HOME must point to JDK 21 or newer." >&2
  exit 1
fi
# Match the first line that actually carries `version "…"` rather than line 1.
# With JAVA_TOOL_OPTIONS or _JAVA_OPTIONS exported, the JVM prints
# `Picked up JAVA_TOOL_OPTIONS: …` first, and anchoring to line 1 rejected a
# valid JDK 21 with "found unknown".
java_major=$("$JAVA_HOME/bin/java" -version 2>&1 |
  sed -n 's/.*version "\([0-9][0-9]*\).*/\1/p' | head -n 1)
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
# Pin the build revision. Upstream's build.gradle.kts derives it from
# `git rev-list HEAD --count`, which inside this tree counts *Mangatan's*
# history: the JAR name, its manifest and the version code extensions read
# through `AppInfo.getVersionCode()` would all change on every unrelated commit,
# and collapse to 1 under CI's shallow checkout. Must stay numeric — the server
# does `REVISION.trimStart('r').toInt()` at class-init, so a commit hash here
# throws NumberFormatException on startup.
(
  cd "$server_dir"
  ProductRevision="$vendored_revision" ./gradlew "${gradle_args[@]}"
)

shopt -s nullglob
jars=("$server_dir"/server/build/MExtensionServer-*.jar)
if ((${#jars[@]} != 1)); then
  echo "Expected exactly one server JAR, found ${#jars[@]}." >&2
  printf '  %s\n' "${jars[@]}" >&2
  exit 1
fi
# Keep the Gradle archive name. It carries the `vX.Y.Z` the app parses out of the
# basename (findExtensionServerJar / extractExtensionServerVersion); flattening it
# to a bare `MExtensionServer.jar` makes Settings report the 1.0.0 fallback and
# offer a perpetual bogus update against upstream's GitHub releases.
cp "${jars[0]}" "$output/$(basename "${jars[0]}")"
cp "$server_dir/LICENSE" "$output/M-Extension-Server-LICENSE.txt"
cp "$server_dir/README.md" "$output/M-Extension-Server-README.md"
cp "$repo_dir/third_party/newpipe_extractor/LICENSE" \
  "$output/NewPipe-Extractor-LICENSE.txt"
cp "$repo_dir/third_party/newpipe_extractor/VENDORED.md" \
  "$output/NewPipe-Extractor-SOURCE.txt"
# The JAR is shaded, so it carries more than MPL/GPL code. Most components keep
# their own notices inside the JAR; this file accounts for all of them and for
# logback, which ships none.
cp "$server_dir/BUNDLED_NOTICES.md" "$output/THIRD_PARTY_NOTICES.md"

if ! $ios_runtime; then
  # `jdk.localedata` is a deliberate addition to upstream's module list (see
  # third_party/mihon_server/build_jre.sh), not an accident to be tidied away on
  # the next re-vendor. Without it the image resolves 5 locales instead of ~1069,
  # so `DateTimeFormatter.ofPattern("d MMMM yyyy", es)` formats "15 Jan 2024" and
  # fails to parse "15 enero 2024". Extension `SimpleDateFormat` calls are
  # bytecode-rewritten onto ICU4J and unaffected, but anything reaching for
  # java.time or DateFormatSymbols with a non-root locale is not. Costs ~11 MiB.
  modules='java.base,java.compiler,java.datatransfer,java.desktop,java.instrument,java.logging,java.management,java.naming,java.prefs,java.scripting,java.se,java.security.jgss,java.security.sasl,java.sql,java.transaction.xa,java.xml,jdk.attach,jdk.crypto.ec,jdk.jdi,jdk.localedata,jdk.management,jdk.net,jdk.unsupported,jdk.unsupported.desktop,jdk.zipfs,jdk.accessibility'
  "$JAVA_HOME/bin/jlink" \
    --add-modules "$modules" \
    --output "$output/jre" \
    --strip-debug \
    --no-man-pages \
    --no-header-files \
    --compress=zip-6
  test -x "$output/jre/bin/java"
fi

server_jar="$output/$(basename "${jars[0]}")"
test -s "$server_jar"
echo "Built vendored Mihon server bundle at $output"
echo "Server JAR: $server_jar"
