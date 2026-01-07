#!/bin/bash

#===============================================================================
# SDK Setup Script
#
# Downloads/copies and extracts the Red5 Pro iOS SDK from a provided URL
# or local file path, and updates project.yml to use the local SDK path.
#
# Usage:
#   ./scripts/setup-sdk.sh <zip-url-or-path>
#
# Examples:
#   ./scripts/setup-sdk.sh https://example.com/red5pro-ios-sdk-v1.0.0.zip
#   ./scripts/setup-sdk.sh /path/to/red5pro-ios-sdk.zip
#   ./scripts/setup-sdk.sh ~/Downloads/red5pro-ios-sdk.zip
#===============================================================================

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_DIR="${PROJECT_DIR}/red5pro-ios-sdk"
PROJECT_YML="${PROJECT_DIR}/project.yml"

#-------------------------------------------------------------------------------
# Helper functions
#-------------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    echo "Usage: $0 <zip-url-or-path>"
    echo ""
    echo "Arguments:"
    echo "  zip-url-or-path    URL or local file path to the Red5 Pro iOS SDK zip file"
    echo ""
    echo "Examples:"
    echo "  $0 https://example.com/red5pro-ios-sdk-v1.0.0.zip"
    echo "  $0 /path/to/red5pro-ios-sdk.zip"
    echo "  $0 ~/Downloads/red5pro-ios-sdk.zip"
    exit 1
}

#-------------------------------------------------------------------------------
# Validate arguments
#-------------------------------------------------------------------------------

if [[ $# -lt 1 ]]; then
    log_error "Missing required argument: zip URL or path"
    usage
fi

ZIP_SOURCE="$1"
ZIP_FILE="${PROJECT_DIR}/red5pro-ios-sdk.zip"

#-------------------------------------------------------------------------------
# Get the SDK zip (download or copy)
#-------------------------------------------------------------------------------

if [[ "${ZIP_SOURCE}" =~ ^https?:// ]]; then
    # Source is a URL - download it
    log_info "Downloading SDK from: ${ZIP_SOURCE}"

    if command -v curl &> /dev/null; then
        curl -L -o "${ZIP_FILE}" "${ZIP_SOURCE}" --progress-bar
    elif command -v wget &> /dev/null; then
        wget -O "${ZIP_FILE}" "${ZIP_SOURCE}"
    else
        log_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi

    if [[ ! -f "${ZIP_FILE}" ]]; then
        log_error "Download failed - zip file not created"
        exit 1
    fi

    log_success "Downloaded SDK zip file"
else
    # Source is a local file path - expand ~ and validate
    ZIP_SOURCE="${ZIP_SOURCE/#\~/$HOME}"
    
    if [[ ! -f "${ZIP_SOURCE}" ]]; then
        log_error "File not found: ${ZIP_SOURCE}"
        exit 1
    fi

    if [[ ! "${ZIP_SOURCE}" =~ \.zip$ ]]; then
        log_warning "File does not have .zip extension: ${ZIP_SOURCE}"
    fi

    log_info "Copying SDK from: ${ZIP_SOURCE}"
    cp "${ZIP_SOURCE}" "${ZIP_FILE}"

    if [[ ! -f "${ZIP_FILE}" ]]; then
        log_error "Copy failed - zip file not created"
        exit 1
    fi

    log_success "Copied SDK zip file"
fi

#-------------------------------------------------------------------------------
# Clean up existing SDK directory
#-------------------------------------------------------------------------------

if [[ -d "${SDK_DIR}" ]]; then
    log_warning "Removing existing SDK directory: ${SDK_DIR}"
    rm -rf "${SDK_DIR}"
fi

#-------------------------------------------------------------------------------
# Extract the SDK
#-------------------------------------------------------------------------------

log_info "Extracting SDK to: ${SDK_DIR}"

# Create a temporary directory for extraction
TEMP_EXTRACT_DIR="${PROJECT_DIR}/.sdk-extract-temp"
rm -rf "${TEMP_EXTRACT_DIR}"
mkdir -p "${TEMP_EXTRACT_DIR}"

# Extract to temp directory first
unzip -q "${ZIP_FILE}" -d "${TEMP_EXTRACT_DIR}"

# Handle nested directory structure (common with GitHub releases)
# If the zip contains a single top-level directory, move its contents
EXTRACTED_ITEMS=("${TEMP_EXTRACT_DIR}"/*)
if [[ ${#EXTRACTED_ITEMS[@]} -eq 1 ]] && [[ -d "${EXTRACTED_ITEMS[0]}" ]]; then
    # Single directory inside zip - move it to SDK_DIR
    mv "${EXTRACTED_ITEMS[0]}" "${SDK_DIR}"
else
    # Multiple items or files - move the temp dir to SDK_DIR
    mv "${TEMP_EXTRACT_DIR}" "${SDK_DIR}"
fi

# Clean up temp directory if it still exists
rm -rf "${TEMP_EXTRACT_DIR}"

# Clean up the zip file
rm -f "${ZIP_FILE}"

if [[ ! -d "${SDK_DIR}" ]]; then
    log_error "Extraction failed - SDK directory not created"
    exit 1
fi

log_success "SDK extracted to: ${SDK_DIR}"

#-------------------------------------------------------------------------------
# Update project.yml
#-------------------------------------------------------------------------------

log_info "Updating project.yml..."

if [[ ! -f "${PROJECT_YML}" ]]; then
    log_error "project.yml not found at: ${PROJECT_YML}"
    exit 1
fi

# Update the Red5ProSDK path from relative parent to local directory
# Matches patterns like:
#   path: ../red5pro-ios-sdk/distribution
#   path: ../red5pro-ios-sdk
#   path: /some/absolute/path
# And replaces with the local path

# Use sed to replace the path under Red5ProSDK
# This handles the YAML structure where Red5ProSDK is followed by path:
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS sed requires empty string for -i
    sed -i '' 's|path: .*/red5pro-ios-sdk.*|path: ./red5pro-ios-sdk|' "${PROJECT_YML}"
else
    # GNU sed
    sed -i 's|path: .*/red5pro-ios-sdk.*|path: ./red5pro-ios-sdk|' "${PROJECT_YML}"
fi

log_success "Updated project.yml"

#-------------------------------------------------------------------------------
# Verify the SDK structure
#-------------------------------------------------------------------------------

log_info "Verifying SDK structure..."

DISTRIBUTION_DIR="${SDK_DIR}"
if [[ -d "${DISTRIBUTION_DIR}" ]]; then
    log_success "Found distribution directory"
    
    # Check for Package.swift (Swift Package)
    if [[ -f "${DISTRIBUTION_DIR}/Package.swift" ]]; then
        log_success "Found Package.swift - SDK is ready for use"
    else
        log_warning "Package.swift not found in distribution directory"
        log_warning "The SDK structure might be different than expected"
    fi
else
    log_warning "No 'distribution' subdirectory found in SDK"
    log_warning "You may need to adjust the path in project.yml manually"
    
    # List what was extracted
    echo ""
    log_info "Contents of ${SDK_DIR}:"
    ls -la "${SDK_DIR}"
fi

#-------------------------------------------------------------------------------
# Summary
#-------------------------------------------------------------------------------

echo ""
echo "==============================================================================="
log_success "SDK setup completed!"
echo "==============================================================================="
echo ""
echo "  SDK Location:  ${SDK_DIR}"
echo "  project.yml:   Updated to use ./red5pro-ios-sdk"
echo ""
echo "Next steps:"
echo "  1. Run 'xcodegen generate' to regenerate the Xcode project"
echo "  2. Open the project in Xcode or run the build script"
echo ""

