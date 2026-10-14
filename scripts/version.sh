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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POM_PATH="${2:-$SCRIPT_DIR/../myapp/pom.xml}"

if [[ ! -f "$POM_PATH" ]]; then
    echo "Could not locate pom.xml at '$POM_PATH'" >&2
    exit 1
fi

# Extract the <version> element text.
POM_VERSION=$(grep -oP '(?<=<version>)[^<]+' "$POM_PATH" | head -1)
if [[ -z "$POM_VERSION" ]]; then
    echo "No <version> element found in '$POM_PATH'" >&2
    exit 1
fi

# Strip suffix (e.g. -SNAPSHOT).
STRIPPED="${POM_VERSION%%-*}"

# Validate Major.Minor format.
if [[ ! "$STRIPPED" =~ ^[0-9]+\.[0-9]+ ]]; then
    echo "Pom version '$POM_VERSION' is not in Major.Minor format" >&2
    exit 1
fi

MAJOR="${STRIPPED%%.*}"
MINOR="${STRIPPED#*.}"
MINOR="${MINOR%%.*}"

echo "${MAJOR}.${MINOR}.${BUILD_ID}"
