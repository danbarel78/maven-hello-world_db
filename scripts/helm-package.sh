#!/usr/bin/env bash
set -euo pipefail

# Package the Helm chart into a .tgz whose file name follows the chart version.
# Usage: ./helm-package.sh [ChartPath] [OutputDir]
# Output (stdout): <OutputDir>/<ChartName>-<ChartVersion>.tgz

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_PATH="${1:-$SCRIPT_DIR/../myapp/helm}"
OUTPUT_DIR="${2:-$SCRIPT_DIR/../outputs/helm}"

# The helm CLI is required.
if ! command -v helm >/dev/null 2>&1; then
    echo "helm was not found on PATH" >&2
    exit 1
fi

CHART_FILE="$CHART_PATH/Chart.yaml"
if [[ ! -f "$CHART_FILE" ]]; then
    echo "Could not locate Chart.yaml at '$CHART_FILE'" >&2
    exit 1
fi

# Extract the chart name and version. Only top-level keys are matched, so
# `appVersion:`/`apiVersion:` are never confused with `version:`.
# POSIX sed/tr keep this working with the BSD tools shipped on macOS, and
# `tr -d '\r'` tolerates a CRLF-influenced Chart.yaml.
CHART_NAME=$(tr -d '\r' < "$CHART_FILE" | sed -n 's/^name:[[:space:]]*\([^[:space:]]*\).*/\1/p' | head -1)
CHART_VERSION=$(tr -d '\r' < "$CHART_FILE" | sed -n 's/^version:[[:space:]]*\([^[:space:]]*\).*/\1/p' | head -1)
if [[ -z "$CHART_NAME" || -z "$CHART_VERSION" ]]; then
    echo "Could not parse name/version from '$CHART_FILE'" >&2
    exit 1
fi

# Package the chart. `helm package` names the file <name>-<version>.tgz.
# Send helm's own output to stderr so stdout carries only the resulting path.
mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR/$CHART_NAME-"*.tgz
helm package "$CHART_PATH" --destination "$OUTPUT_DIR" >&2

# Print the resulting package path (normalised, since OUTPUT_DIR may contain "..").
echo "$(cd "$OUTPUT_DIR" && pwd)/$CHART_NAME-$CHART_VERSION.tgz"
