#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"

REPO_NAME="VolumeButtonKit-src"
REPO_URL="https://github.com/Navideck/VolumeButtonKit.git"
REPO_REF="main"
SOURCE_FILE="${REPO_NAME}/Sources/VolumeButtonKit/VolumeButtonKit.swift"
TARGET_FILE="volume_button_listener/Sources/volume_button_listener/VolumeButtonKit.swift"

rm -rf "${REPO_NAME}"
git clone --depth 1 --branch "${REPO_REF}" "${REPO_URL}" "${REPO_NAME}"
cp "${SOURCE_FILE}" "${TARGET_FILE}"
rm -rf "${REPO_NAME}"
