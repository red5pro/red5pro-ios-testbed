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
# Environment Variables (required for CI/manual signing):
#   - CERTIFICATE_PATH: Path to .p12 certificate file
#   - CERTIFICATE_PASSWORD: Password for the .p12 certificate
#   - PROVISIONING_PROFILE_PATH: Path to .mobileprovision file
#
# Environment Variables (optional, for app configuration):
#   - R5PRO_LICENSE: SDK license key to inject into the build
#   - R5PRO_LICENSE_MANAGER: License manager URL to inject into the build
#   - R5PRO_VERSION: Marketing version string (CFBundleShortVersionString, e.g., "2.0")
#   - R5PRO_BUILD: Build number (CFBundleVersion, e.g., "23")
#   - DEVELOPMENT_TEAM: Apple Developer Team ID (defaults to E964K44BWW)
#   - BUNDLE_ID: App bundle identifier (defaults to com.infrared5.test.WebRTCTestBed)
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
TEAM_ID="${DEVELOPMENT_TEAM:-E964K44BWW}"
APP_BUNDLE_ID="${BUNDLE_ID:-com.infrared5.test.WebRTCTestBed}"

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

XCODE_GEN=xcodegen

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    log_error "xcodebuild not found. Please install Xcode and command line tools."
    exit 1
fi

# Check for XcodeGen
if ! command -v ${XCODE_GEN} &> /dev/null; then
    XCODE_GEN=/opt/homebrew/bin/xcodegen
    if ! command -v ${XCODE_GEN} &> /dev/null; then
        log_warning "XcodeGen not found. Attempting to install via Homebrew..."
        if command -v brew &> /dev/null; then
            brew install xcodegen
            XCODE_GEN=xcodegen
        else
            log_error "Homebrew not found. Please install XcodeGen manually: brew install xcodegen"
            exit 1
        fi
    fi
fi

# Print versions
log_info "Xcode version: $(xcodebuild -version | head -n 1)"
log_info "XcodeGen version: $($XCODE_GEN --version)"

#-------------------------------------------------------------------------------
# CI Setup: Install certificate and provisioning profile (if provided)
#-------------------------------------------------------------------------------

MANUAL_SIGNING=false
KEYCHAIN_NAME="${HOME}/Library/Keychains/build.keychain-db"
KEYCHAIN_PASSWORD="build_password"
PROFILE_UUID=""

# Debug: Show signing-related environment variables
echo "=== SIGNING CONFIGURATION CHECK ==="
echo "  CERTIFICATE_PATH: '${CERTIFICATE_PATH:-<not set>}'"
echo "  PROVISIONING_PROFILE_PATH: '${PROVISIONING_PROFILE_PATH:-<not set>}'"
echo "  CERTIFICATE_PASSWORD: '${CERTIFICATE_PASSWORD:+<set>}${CERTIFICATE_PASSWORD:-<not set>}'"
echo "==================================="

if [[ -n "${CERTIFICATE_PATH:-}" ]] && [[ -n "${PROVISIONING_PROFILE_PATH:-}" ]]; then
    log_info "CI environment detected - setting up manual signing..."
    MANUAL_SIGNING=true

    # Validate files exist
    if [[ ! -f "${CERTIFICATE_PATH}" ]]; then
        log_error "Certificate file not found: ${CERTIFICATE_PATH}"
        exit 1
    fi

    if [[ ! -f "${PROVISIONING_PROFILE_PATH}" ]]; then
        log_error "Provisioning profile not found: ${PROVISIONING_PROFILE_PATH}"
        exit 1
    fi

    if [[ -z "${CERTIFICATE_PASSWORD:-}" ]]; then
        log_error "CERTIFICATE_PASSWORD environment variable is required for CI signing"
        exit 1
    fi

    # Create a temporary keychain for the build
    log_info "Creating temporary keychain at: ${KEYCHAIN_NAME}"
    
    # Delete existing keychain if it exists (clean slate)
    security delete-keychain "${KEYCHAIN_NAME}" 2>/dev/null || true
    
    # Create new keychain
    security create-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_NAME}"
    
    # Configure keychain settings (no auto-lock for 6 hours)
    security set-keychain-settings -lut 21600 "${KEYCHAIN_NAME}"
    
    # Unlock the keychain
    security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_NAME}"

    # Add keychain to search list (put our build keychain first so it's searched first)
    EXISTING_KEYCHAINS=$(security list-keychains -d user | tr -d '"' | tr '\n' ' ')
    security list-keychains -d user -s "${KEYCHAIN_NAME}" ${EXISTING_KEYCHAINS}
    
    # Set the build keychain as the default
    security default-keychain -s "${KEYCHAIN_NAME}"
    
    log_info "Keychain search list:"
    security list-keychains -d user

    # Import certificate with -A flag to allow all applications to access
    log_info "Importing certificate from: ${CERTIFICATE_PATH}"
    security import "${CERTIFICATE_PATH}" \
        -k "${KEYCHAIN_NAME}" \
        -P "${CERTIFICATE_PASSWORD}" \
        -A \
        -T /usr/bin/codesign \
        -T /usr/bin/security \
        -T /usr/bin/xcodebuild

    # Allow codesign to access the keychain without prompting
    # This is critical for CI where there's no UI to approve access
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_NAME}"

    # Verify certificate was imported and list available signing identities
    echo "=== CERTIFICATE VERIFICATION ==="
    echo "Signing identities in ${KEYCHAIN_NAME}:"
    security find-identity -v -p codesigning "${KEYCHAIN_NAME}" || echo "  WARNING: No signing identities found in build keychain"
    echo ""
    echo "All available signing identities (all keychains):"
    security find-identity -v -p codesigning || echo "  WARNING: No signing identities found"
    echo "================================"

    # Install provisioning profile
    log_info "Installing provisioning profile..."
    
    # Extract profile information
    PROFILE_PLIST=$(security cms -D -i "${PROVISIONING_PROFILE_PATH}" 2>/dev/null)
    
    # Extract and display profile information for debugging
    echo "=== PROVISIONING PROFILE INFO ==="
    echo "  File: ${PROVISIONING_PROFILE_PATH}"
    echo "${PROFILE_PLIST}" | grep -A1 -E "(Name|TeamIdentifier|UUID|application-identifier)" | head -20 || echo "  Could not extract profile info"
    echo "=================================="
    
    PROFILE_UUID=$(grep -aA1 'UUID' "${PROVISIONING_PROFILE_PATH}" | grep -oE '[a-fA-F0-9-]{36}' | head -1)
    
    # Extract profile name (needed for PROVISIONING_PROFILE_SPECIFIER)
    PROFILE_NAME=$(echo "${PROFILE_PLIST}" | grep -A1 '<key>Name</key>' | grep '<string>' | sed 's/.*<string>\(.*\)<\/string>.*/\1/' | head -1)
    
    if [[ -z "${PROFILE_NAME}" ]]; then
        log_warning "Could not extract profile name, using UUID instead"
        PROFILE_NAME="${PROFILE_UUID}"
    fi
    
    echo "  Extracted Profile Name: ${PROFILE_NAME}"
    echo "  Extracted Profile UUID: ${PROFILE_UUID}"
    
    if [[ -z "${PROFILE_UUID}" ]]; then
        log_error "Could not extract UUID from provisioning profile"
        exit 1
    fi

    PROFILES_DIR="${HOME}/Library/MobileDevice/Provisioning Profiles"
    mkdir -p "${PROFILES_DIR}"
    cp "${PROVISIONING_PROFILE_PATH}" "${PROFILES_DIR}/${PROFILE_UUID}.mobileprovision"

    echo "=== PROVISIONING PROFILE INSTALLED ==="
    echo "  Profile UUID: ${PROFILE_UUID}"
    echo "  Installed to: ${PROFILES_DIR}/${PROFILE_UUID}.mobileprovision"
    ls -la "${PROFILES_DIR}/${PROFILE_UUID}.mobileprovision" || echo "  WARNING: Profile file not found!"
    echo "======================================="
    
    log_success "Manual signing configured (Profile UUID: ${PROFILE_UUID})"

    # Set cleanup trap to remove keychain on exit
    cleanup_keychain() {
        log_info "Cleaning up temporary keychain..."
        security delete-keychain "${KEYCHAIN_NAME}" 2>/dev/null || true
    }
    trap cleanup_keychain EXIT
fi

#-------------------------------------------------------------------------------
# Generate build configuration with injected values
#-------------------------------------------------------------------------------

log_info "Generating build configuration..."
"${PROJECT_DIR}/scripts/generate-build-config.sh"

#-------------------------------------------------------------------------------
# Configure project.yml for manual signing (CI only)
#-------------------------------------------------------------------------------

PROJECT_YML="${PROJECT_DIR}/project.yml"
PROJECT_YML_BACKUP=""

if [[ "${MANUAL_SIGNING}" == true ]]; then
    echo "=== MANUAL SIGNING: Configuring project.yml ==="
    log_info "Configuring project.yml for manual signing..."
    log_info "  Profile UUID: ${PROFILE_UUID}"
    
    # Backup original project.yml
    PROJECT_YML_BACKUP="${PROJECT_DIR}/project.yml.backup"
    cp "${PROJECT_YML}" "${PROJECT_YML_BACKUP}"
    
    # Update signing settings in project.yml for the WebRTCTestBed target
    # This ensures manual signing is applied ONLY to the app target, not SPM packages
    # Using sed to replace the signing settings
    
    # Replace CODE_SIGN_STYLE: Automatic with manual signing settings
    # Note: Using "iPhone Distribution" to match the certificate type
    # Using profile name (not UUID) for PROVISIONING_PROFILE_SPECIFIER
    sed -i '' "s/CODE_SIGN_STYLE: Automatic/CODE_SIGN_STYLE: Manual\\
        CODE_SIGN_IDENTITY: iPhone Distribution\\
        PROVISIONING_PROFILE_SPECIFIER: ${PROFILE_NAME}/" "${PROJECT_YML}"
    
    log_info "Updated project.yml with manual signing configuration"
    echo "[INFO] Modified signing settings in project.yml:"
    echo "----------------------------------------"
    grep -A3 "CODE_SIGN_STYLE" "${PROJECT_YML}" || echo "  (no CODE_SIGN_STYLE found)"
    echo "----------------------------------------"
    
    # Add cleanup to restore original project.yml
    cleanup_project_yml() {
        if [[ -n "${PROJECT_YML_BACKUP}" ]] && [[ -f "${PROJECT_YML_BACKUP}" ]]; then
            log_info "Restoring original project.yml..."
            mv "${PROJECT_YML_BACKUP}" "${PROJECT_YML}"
        fi
    }
    # Chain this cleanup with the keychain cleanup
    original_cleanup=$(trap -p EXIT | sed "s/trap -- '\\(.*\\)' EXIT/\\1/")
    trap "cleanup_project_yml; ${original_cleanup}" EXIT
fi

#-------------------------------------------------------------------------------
# Generate Xcode project
#-------------------------------------------------------------------------------

log_info "Generating Xcode project from project.yml..."
cd "${PROJECT_DIR}"

if [[ ! -f "project.yml" ]]; then
    log_error "project.yml not found in ${PROJECT_DIR}"
    exit 1
fi

# Remove existing .xcodeproj to avoid "item with same name already exists" error
if [[ -d "${SCHEME}.xcodeproj" ]]; then
    log_info "Removing existing ${SCHEME}.xcodeproj..."
    rm -rf "${SCHEME}.xcodeproj"
fi

${XCODE_GEN} generate --spec project.yml

if [[ ! -d "${SCHEME}.xcodeproj" ]]; then
    log_error "Failed to generate Xcode project"
    exit 1
fi

log_success "Xcode project generated successfully"

#-------------------------------------------------------------------------------
# Inject version numbers into Info.plist (if provided)
#-------------------------------------------------------------------------------

INFO_PLIST="${PROJECT_DIR}/Resources/Info.plist"

if [[ -f "${INFO_PLIST}" ]]; then
    if [[ -n "${R5PRO_VERSION:-}" ]]; then
        log_info "Setting CFBundleShortVersionString to: ${R5PRO_VERSION}"
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${R5PRO_VERSION}" "${INFO_PLIST}"
    fi

    if [[ -n "${R5PRO_BUILD:-}" ]]; then
        log_info "Setting CFBundleVersion to: ${R5PRO_BUILD}"
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${R5PRO_BUILD}" "${INFO_PLIST}"
    fi
else
    log_warning "Info.plist not found at ${INFO_PLIST} - skipping version injection"
fi

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

if [[ "${MANUAL_SIGNING}" == true ]]; then
    cat > "${EXPORT_OPTIONS_PATH}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>iPhone Distribution</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>${APP_BUNDLE_ID}</key>
        <string>${PROFILE_UUID}</string>
    </dict>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
EOF
    
    echo "=== EXPORT OPTIONS ==="
    cat "${EXPORT_OPTIONS_PATH}"
    echo "======================"
else
    cat > "${EXPORT_OPTIONS_PATH}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF
fi

log_info "ExportOptions.plist created at: ${EXPORT_OPTIONS_PATH}"

#-------------------------------------------------------------------------------
# Build archive
#-------------------------------------------------------------------------------

log_info "Building archive for scheme: ${SCHEME}, configuration: ${CONFIGURATION}..."

if [[ "${MANUAL_SIGNING}" == true ]]; then
    log_info "Using manual signing for CI..."
    log_info "  Team ID: ${TEAM_ID}"
    log_info "  Bundle ID: ${APP_BUNDLE_ID}"
    log_info "  Profile UUID: ${PROFILE_UUID}"
    
    # Manual signing is configured in project.yml (modified earlier in this script).
    # This approach sets signing settings ONLY on the WebRTCTestBed target, not on
    # SPM package targets (which don't support provisioning profiles).
    # We don't pass signing settings on the command line to avoid them being applied globally.
    
    ARCHIVE_CMD="xcodebuild archive \
        -project ${SCHEME}.xcodeproj \
        -scheme ${SCHEME} \
        -configuration ${CONFIGURATION} \
        -archivePath ${ARCHIVE_PATH} \
        -destination generic/platform=iOS \
        -clonedSourcePackagesDirPath ${BUILD_DIR}/SourcePackages"
else
    log_info "Using automatic signing..."
    ARCHIVE_CMD="xcodebuild archive \
        -project ${SCHEME}.xcodeproj \
        -scheme ${SCHEME} \
        -configuration ${CONFIGURATION} \
        -archivePath ${ARCHIVE_PATH} \
        -destination generic/platform=iOS \
        -clonedSourcePackagesDirPath ${BUILD_DIR}/SourcePackages \
        -allowProvisioningUpdates \
        CODE_SIGN_STYLE=Automatic"
fi

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

# Debug: Check if provisioning profile is embedded in the archive
echo "=== ARCHIVE VERIFICATION ==="
EMBEDDED_PROFILE="${ARCHIVE_PATH}/Products/Applications/${SCHEME}.app/embedded.mobileprovision"
if [[ -f "${EMBEDDED_PROFILE}" ]]; then
    echo "  Embedded profile found: ${EMBEDDED_PROFILE}"
    security cms -D -i "${EMBEDDED_PROFILE}" 2>/dev/null | grep -A1 '<key>Name</key>' | head -2
else
    echo "  WARNING: No embedded.mobileprovision found in archive!"
    echo "  Contents of ${ARCHIVE_PATH}/Products/Applications/${SCHEME}.app/:"
    ls -la "${ARCHIVE_PATH}/Products/Applications/${SCHEME}.app/" | head -15
fi

# List installed provisioning profiles
echo ""
echo "  Installed provisioning profiles:"
ls -la "${HOME}/Library/MobileDevice/Provisioning Profiles/" 2>/dev/null | head -10 || echo "  No profiles directory found"
echo "==============================="

#-------------------------------------------------------------------------------
# Export IPA
#-------------------------------------------------------------------------------

log_info "Exporting IPA..."

# Build the base export command
EXPORT_CMD="xcodebuild -exportArchive \
    -archivePath ${ARCHIVE_PATH} \
    -exportOptionsPlist ${EXPORT_OPTIONS_PATH} \
    -exportPath ${EXPORT_PATH}"

echo "=== EXPORT COMMAND ==="
echo "APP_STORE_CONNECT_API_KEY_ID: ${APP_STORE_CONNECT_API_KEY_ID}"
echo "APP_STORE_CONNECT_ISSUER_ID: ${APP_STORE_CONNECT_ISSUER_ID}"
echo "APP_STORE_CONNECT_API_KEY_PATH: ${APP_STORE_CONNECT_API_KEY_PATH}"
echo "====================="

# Add App Store Connect API authentication if credentials are available
# This is required for app-store-connect method to avoid interactive login
if [[ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" ]] && \
   [[ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]] && \
   [[ -n "${APP_STORE_CONNECT_API_KEY_PATH:-}" ]]; then
    log_info "Using App Store Connect API authentication for export..."
    EXPORT_CMD="${EXPORT_CMD} \
        -authenticationKeyPath \"${APP_STORE_CONNECT_API_KEY_PATH}\" \
        -authenticationKeyID \"${APP_STORE_CONNECT_API_KEY_ID}\" \
        -authenticationKeyIssuerID \"${APP_STORE_CONNECT_ISSUER_ID}\""
elif [[ "${MANUAL_SIGNING}" != true ]]; then
    EXPORT_CMD="${EXPORT_CMD} -allowProvisioningUpdates"
fi

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

