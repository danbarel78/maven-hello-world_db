#!/usr/bin/env bash
set -euo pipefail

# Compute the release version for the CI/CD pipeline.
# Usage: ./version.sh <BuildId> [PomPath]
# Output: Major.Minor.BuildId

BUILD_ID="${1:-}"
if [[ -z "$BUILD_ID" ]]; then
    echo "Usage: $0 <BuildId> [PomPath]" >&2
    exit 1
fi

# A leading dash means an option landed where the build id is expected.
if [[ "$BUILD_ID" == -* ]]; then
    echo "BuildId '$BUILD_ID' looks like an option. Usage: $0 <BuildId> [PomPath] (no leading dashes)" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PARENT="$(dirname "$SCRIPT_DIR")"

# Echo the first entry that is a pom.xml (or a folder holding one), or fail.
resolve_pom() {
    local candidate
    for candidate in "$@"; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
        if [[ -f "$candidate/pom.xml" ]]; then
            printf '%s\n' "$candidate/pom.xml"
            return 0
        fi
    done
    return 1
}

if [[ -n "${2:-}" ]]; then
    # An explicit path is authoritative: never fall back to a different pom.
    if ! POM_PATH="$(resolve_pom "$2")"; then
        echo "Could not locate pom.xml at '$2' (from '$PWD')" >&2
        exit 1
    fi
else
    # The layout is not guaranteed: the repo root may sit above the script, the
    # pom may live next to the script, or the script may have been copied
    # elsewhere. Probe the well-known locations instead of trusting one guess,
    # preferring the documented "repo root with an app subfolder" layout.
    # Bases to probe, most trustworthy first, skipping folders already listed so
    # the reported candidates never repeat.
    BASES=("$SCRIPT_PARENT")
    if [[ "$PWD" != "$SCRIPT_PARENT" ]]; then
        BASES+=("$PWD")
    fi
    if [[ "$SCRIPT_DIR" != "$SCRIPT_PARENT" && "$SCRIPT_DIR" != "$PWD" ]]; then
        BASES+=("$SCRIPT_DIR")
    fi

    CANDIDATES=()
    for base in "${BASES[@]}"; do
        CANDIDATES+=("$base/myapp")
    done
    for base in "${BASES[@]}"; do
        CANDIDATES+=("$base")
    done

    if ! POM_PATH="$(resolve_pom "${CANDIDATES[@]}")"; then
        echo "Could not locate pom.xml, so the project version cannot be read." >&2
        echo "" >&2
        echo "Looked for:" >&2
        for candidate in "${CANDIDATES[@]}"; do
            echo "  $candidate/pom.xml" >&2
        done
        echo "" >&2
        echo "Script folder:  $SCRIPT_DIR" >&2
        echo "Current folder: $PWD" >&2
        echo "Pass a pom path as the second argument to point at the file explicitly." >&2
        exit 1
    fi
fi

# Extract the text of the project's own <version> element. Any <parent> block is
# skipped first, because its <version> would otherwise be picked up instead.
# POSIX awk keeps this working with the BSD tools shipped on macOS, and
# `tr -d '\r'` tolerates a pom.xml checked out with CRLF endings (the CR would
# otherwise survive into the value and defeat the Major.Minor check below).
POM_VERSION=$(tr -d '\r' < "$POM_PATH" | awk '
    /<parent>/   { in_parent = 1 }
    /<\/parent>/ { in_parent = 0; next }
    !in_parent && /<version>/ {
        line = $0
        sub(/^.*<version>/, "", line)
        sub(/<\/version>.*$/, "", line)
        gsub(/^[ \t]+|[ \t]+$/, "", line)
        print line
        exit
    }
')

if [[ -z "$POM_VERSION" ]]; then
    echo "No <version> element found in '$POM_PATH'" >&2
    exit 1
fi

# Strip suffix (e.g. -SNAPSHOT).
STRIPPED="${POM_VERSION%%-*}"

# Validate Major.Minor format; the minor segment must itself be numeric.
if [[ ! "$STRIPPED" =~ ^[0-9]+\.[0-9]+($|\.) ]]; then
    echo "Pom version '$POM_VERSION' is not in Major.Minor format" >&2
    exit 1
fi

MAJOR="${STRIPPED%%.*}"
MINOR="${STRIPPED#*.}"
MINOR="${MINOR%%.*}"

echo "${MAJOR}.${MINOR}.${BUILD_ID}"
