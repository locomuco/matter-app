#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# get_chip_sdk.sh
#
# Downloads or builds the CHIP Android SDK (CHIPController.aar +
# SetupPayloadParser.jar) and places them in android/app/libs/.
#
# Usage:
#   bash android/get_chip_sdk.sh [--build | --ci]
#
#   --ci     Download the latest successful build artifact from
#            connectedhomeip GitHub Actions (requires gh CLI + authentication).
#   --build  Clone connectedhomeip and build from source (slow, ~1–2 h).
#            Requires: Android NDK 28.x, Python 3.10+, CMake 3.25+, Java 17.
#
# After running successfully, re-run:
#   flutter build apk --debug
# to compile with the real CHIP SDK instead of the stub.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBS_DIR="$SCRIPT_DIR/app/libs"
CHIP_REPO="https://github.com/project-chip/connectedhomeip"
CHIP_TAG="${CHIP_TAG:-v1.5.0.0}"   # override via env: CHIP_TAG=v1.4.2.0 bash ...

mkdir -p "$LIBS_DIR"

MODE="${1:---build}"

# ── CI download via GitHub CLI ─────────────────────────────────────────────
if [[ "$MODE" == "--ci" ]]; then
    if ! command -v gh &>/dev/null; then
        echo "Error: GitHub CLI (gh) not found. Install from https://cli.github.com/"
        exit 1
    fi
    echo "Searching for latest successful Android CHIPTool run..."
    RUN_ID=$(gh run list \
        --repo project-chip/connectedhomeip \
        --workflow "Build example - Android" \
        --status success \
        --limit 1 \
        --json databaseId \
        --jq '.[0].databaseId')
    echo "Downloading artifact from run $RUN_ID..."
    TMPDIR=$(mktemp -d)
    gh run download "$RUN_ID" \
        --repo project-chip/connectedhomeip \
        --name "android-CHIPTool-artifacts" \
        --dir "$TMPDIR"
    cp "$TMPDIR"/CHIPController.aar    "$LIBS_DIR/"
    cp "$TMPDIR"/SetupPayloadParser.jar "$LIBS_DIR/" 2>/dev/null || true
    rm -rf "$TMPDIR"
    echo "Done. AARs placed in $LIBS_DIR"
    exit 0
fi

# ── Build from source ──────────────────────────────────────────────────────
if [[ "$MODE" == "--build" ]]; then
    WORK_DIR="${CHIP_BUILD_DIR:-/tmp/connectedhomeip}"

    if [[ ! -d "$WORK_DIR" ]]; then
        echo "Cloning connectedhomeip $CHIP_TAG into $WORK_DIR ..."
        git clone --depth 1 --branch "$CHIP_TAG" "$CHIP_REPO" "$WORK_DIR"
    else
        echo "Using existing clone at $WORK_DIR"
    fi

    cd "$WORK_DIR"

    echo "Syncing sub-modules (Android platform, shallow)..."
    ./scripts/checkout_submodules.py --shallow --platform android --recursive

    echo "Activating build environment..."
    source scripts/activate.sh

    echo "Building android-arm64-chip-tool (this takes ~1–2 hours)..."
    ./scripts/build/build_examples.py \
        --target android-arm64-chip-tool \
        build

    echo "Copying outputs to $LIBS_DIR ..."
    cp out/android-arm64-chip-tool/lib/CHIPController.aar    "$LIBS_DIR/"
    cp out/android-arm64-chip-tool/lib/SetupPayloadParser.jar "$LIBS_DIR/" 2>/dev/null || true

    echo "Done. AARs placed in $LIBS_DIR"
    echo "Now run: flutter build apk --debug"
    exit 0
fi

echo "Unknown option: $MODE"
echo "Usage: bash get_chip_sdk.sh [--build | --ci]"
exit 1
