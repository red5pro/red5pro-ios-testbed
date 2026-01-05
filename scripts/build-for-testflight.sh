#!/bin/bash

#===============================================================================
# Build Script for TestFlight Distribution
# 
# This script generates the Xcode project from project.yml using XcodeGen,
# builds an IPA, and optionally uploads to TestFlight.
#
# Prerequisites:
#   - Xcode installed with command line tools
#   - XcodeGen installed (brew install xcodegen)
#   - Valid Apple Developer account with App Store Connect access
#   - Provisioning profiles and certificates configured
#
# Environment Variables (required for upload):
#   - APP_STORE_CONNECT_API_KEY_ID: App Store Connect API Key ID
#   - APP_STORE_CONNECT_ISSUER_ID: App Store Connect Issuer ID
#   - APP_STORE_CONNECT_API_KEY_PATH: Path to .p8 API key file
#
# Usage:
#   ./scripts/build-for-testflight.sh [--upload] [--scheme SCHEME] [--config CONFIG]
#===============================================================================

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SCHEME="WebRTCTestBed"
CONFIGURATION="Debug"
UPLOAD_TO_TESTFLIGHT=false
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${SCHEME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
IPA_PATH="${EXPORT_PATH}/${SCHEME}.ipa"

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

cleanup() {
    if [[ -d "${BUILD_DIR}" ]]; then
        log_info "Cleaning up build directory..."
        rm -rf "${BUILD_DIR}"
    fi
}

#-------------------------------------------------------------------------------
# Parse arguments
#-------------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case $1 in
        --upload)
            UPLOAD_TO_TESTFLIGHT=true
            shift
            ;;
        --scheme)
            SCHEME="$2"
            shift 2
            ;;
        --config)
            CONFIGURATION="$2"
            shift 2
            ;;
        --clean)
            cleanup
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --upload        Upload IPA to TestFlight after build"
            echo "  --scheme NAME   Xcode scheme to build (default: WebRTCTestBed)"
            echo "  --config NAME   Build configuration (default: Release)"
            echo "  --clean         Clean build directory before building"
            echo "  --help, -h      Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

#-------------------------------------------------------------------------------
# Verify prerequisites
#-------------------------------------------------------------------------------

log_info "Checking prerequisites..."

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    log_error "xcodebuild not found. Please install Xcode and command line tools."
    exit 1
fi

# Check for XcodeGen
if ! command -v xcodegen &> /dev/null; then
    log_warning "XcodeGen not found. Attempting to install via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install xcodegen
    else
        log_error "Homebrew not found. Please install XcodeGen manually: brew install xcodegen"
        exit 1
    fi
fi

# Print versions
log_info "Xcode version: $(xcodebuild -version | head -n 1)"
log_info "XcodeGen version: $(xcodegen --version)"

#-------------------------------------------------------------------------------
# Generate Xcode project
#-------------------------------------------------------------------------------

log_info "Generating Xcode project from project.yml..."
cd "${PROJECT_DIR}"

if [[ ! -f "project.yml" ]]; then
    log_error "project.yml not found in ${PROJECT_DIR}"
    exit 1
fi

xcodegen generate --spec project.yml

if [[ ! -d "${SCHEME}.xcodeproj" ]]; then
    log_error "Failed to generate Xcode project"
    exit 1
fi

log_success "Xcode project generated successfully"

#-------------------------------------------------------------------------------
# Resolve Swift Package Manager dependencies
#-------------------------------------------------------------------------------

log_info "Resolving Swift Package Manager dependencies..."
xcodebuild -resolvePackageDependencies \
    -project "${SCHEME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -clonedSourcePackagesDirPath "${BUILD_DIR}/SourcePackages"

log_success "Package dependencies resolved"

#-------------------------------------------------------------------------------
# Create build directory
#-------------------------------------------------------------------------------

mkdir -p "${BUILD_DIR}"
mkdir -p "${EXPORT_PATH}"

#-------------------------------------------------------------------------------
# Create ExportOptions.plist for App Store distribution
#-------------------------------------------------------------------------------

EXPORT_OPTIONS_PATH="${BUILD_DIR}/ExportOptions.plist"

log_info "Creating ExportOptions.plist..."

cat > "${EXPORT_OPTIONS_PATH}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF

#-------------------------------------------------------------------------------
# Build archive
#-------------------------------------------------------------------------------

log_info "Building archive for scheme: ${SCHEME}, configuration: ${CONFIGURATION}..."

ARCHIVE_CMD="xcodebuild archive \
    -project ${SCHEME}.xcodeproj \
    -scheme ${SCHEME} \
    -configuration ${CONFIGURATION} \
    -archivePath ${ARCHIVE_PATH} \
    -destination generic/platform=iOS \
    -clonedSourcePackagesDirPath ${BUILD_DIR}/SourcePackages \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic"

if command -v xcpretty &> /dev/null; then
    eval "${ARCHIVE_CMD}" | xcpretty --color
else
    eval "${ARCHIVE_CMD}"
fi

if [[ ! -d "${ARCHIVE_PATH}" ]]; then
    log_error "Archive failed - no archive created"
    exit 1
fi

log_success "Archive created at: ${ARCHIVE_PATH}"

#-------------------------------------------------------------------------------
# Export IPA
#-------------------------------------------------------------------------------

log_info "Exporting IPA..."

EXPORT_CMD="xcodebuild -exportArchive \
    -archivePath ${ARCHIVE_PATH} \
    -exportOptionsPlist ${EXPORT_OPTIONS_PATH} \
    -exportPath ${EXPORT_PATH} \
    -allowProvisioningUpdates"

if command -v xcpretty &> /dev/null; then
    eval "${EXPORT_CMD}" | xcpretty --color
else
    eval "${EXPORT_CMD}"
fi

if [[ ! -f "${IPA_PATH}" ]]; then
    # Try to find the IPA with any name
    IPA_FILE=$(find "${EXPORT_PATH}" -name "*.ipa" -type f | head -n 1)
    if [[ -n "${IPA_FILE}" ]]; then
        IPA_PATH="${IPA_FILE}"
    else
        log_error "Export failed - no IPA created"
        exit 1
    fi
fi

log_success "IPA created at: ${IPA_PATH}"

#-------------------------------------------------------------------------------
# Upload to TestFlight (optional)
#-------------------------------------------------------------------------------

if [[ "${UPLOAD_TO_TESTFLIGHT}" == true ]]; then
    log_info "Uploading to TestFlight..."

    # Check for App Store Connect API credentials
    if [[ -z "${APP_STORE_CONNECT_API_KEY_ID:-}" ]] || \
       [[ -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]] || \
       [[ -z "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]]; then
        log_error "Missing App Store Connect API credentials."
        log_error "Please set the following environment variables:"
        log_error "  - APP_STORE_CONNECT_API_KEY_ID"
        log_error "  - APP_STORE_CONNECT_ISSUER_ID"
        log_error "  - APP_STORE_CONNECT_API_KEY_PATH"
        exit 1
    fi

    if [[ ! -f "${APP_STORE_CONNECT_API_KEY_PATH}" ]]; then
        log_error "API key file not found: ${APP_STORE_CONNECT_API_KEY_PATH}"
        exit 1
    fi

    xcrun altool --upload-app \
        --type ios \
        --file "${IPA_PATH}" \
        --apiKey "${APP_STORE_CONNECT_API_KEY_ID}" \
        --apiIssuer "${APP_STORE_CONNECT_ISSUER_ID}" \
        --verbose

    log_success "Successfully uploaded to TestFlight!"
else
    log_info "Skipping TestFlight upload. Use --upload flag to enable."
fi

#-------------------------------------------------------------------------------
# Summary
#-------------------------------------------------------------------------------

echo ""
echo "==============================================================================="
log_success "Build completed successfully!"
echo "==============================================================================="
echo ""
echo "  Archive:  ${ARCHIVE_PATH}"
echo "  IPA:      ${IPA_PATH}"
echo ""

if [[ "${UPLOAD_TO_TESTFLIGHT}" == false ]]; then
    echo "To upload manually, run:"
    echo ""
    echo "  xcrun altool --upload-app --type ios --file \"${IPA_PATH}\" \\"
    echo "    --apiKey \"\$APP_STORE_CONNECT_API_KEY_ID\" \\"
    echo "    --apiIssuer \"\$APP_STORE_CONNECT_ISSUER_ID\""
    echo ""
fi

