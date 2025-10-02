#!/bin/bash

# Script to bump version for all workspace packages
# Usage: ./bump-version.sh
# Interactive mode only - prompts for new version

# Show usage if help is requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0"
    echo ""
    echo "Bump version for all workspace packages interactively."
    echo "Shows current version and prompts for new version."
    echo "Press Enter without input to cancel the operation."
    echo ""
    echo "Example:"
    echo "  $0"
    echo ""
    exit 0
fi

# Force interactive mode - ignore any command line arguments
if [ ! -z "$1" ]; then
    echo "Note: This script only works in interactive mode. Ignoring command line arguments."
    echo ""
fi

# Get current version and display it
echo "=== Version Bump Tool ==="
echo ""
CURRENT_VERSION=$(uv version --short 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$CURRENT_VERSION" ]; then
    echo "Error: Could not determine current version. Make sure you're in a UV workspace."
    exit 1
fi

echo "Current version: $CURRENT_VERSION"
echo ""
echo "Enter new version (or press Enter to cancel): "
read -p "> " NEW_VERSION

# Check if user wants to cancel
if [ -z "$NEW_VERSION" ]; then
    echo "Operation cancelled."
    exit 0
fi

# Validate version format (basic check)
if [[ ! $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-](alpha|beta|rc|dev)[0-9]*)?$ ]]; then
    echo "Error: Invalid version format. Expected format: X.Y.Z or X.Y.Z-suffix"
    exit 1
fi

echo ""
echo "Updating all packages from $CURRENT_VERSION to $NEW_VERSION..."
echo ""

# Discover all workspace packages automatically
echo "Discovering workspace packages..."

# Method 1: Try to get packages from uv show command
WORKSPACE_PACKAGES=""

# Method 2: Parse pyproject.toml for workspace members (most reliable)
if [ -z "$WORKSPACE_PACKAGES" ]; then
    WORKSPACE_PACKAGES=$(grep -A 20 '\[tool\.uv\.workspace\]' pyproject.toml | \
                        grep -E '^\s*"[^"]+",?\s*$' | \
                        sed 's/.*"\([^"]*\)".*/\1/' | \
                        xargs -I {} basename {} | \
                        grep -v '^\.' | \
                        grep -E '^[a-zA-Z][a-zA-Z0-9_-]*[a-zA-Z0-9]?$')
fi

# Method 3: Alternative parsing if the above fails
if [ -z "$WORKSPACE_PACKAGES" ]; then
    WORKSPACE_PACKAGES=$(awk '/\[tool\.uv\.workspace\]/,/^\[/ {
        if (/^\s*"[^"]+",?\s*$/) {
            gsub(/.*"([^"]*)".*/, "\\1");
            gsub(/.*\//, "");
            if (!/^\./ && /^[a-zA-Z][a-zA-Z0-9_-]*[a-zA-Z0-9]?$/) print
        }
    }' pyproject.toml)
fi

if [ -z "$WORKSPACE_PACKAGES" ]; then
    echo "Error: Could not discover workspace packages. Please check your workspace configuration."
    exit 1
fi

# Create arrays to store package names and their old versions
declare -a PACKAGE_NAMES
declare -a OLD_VERSIONS
declare -a NEW_VERSIONS
declare -a UPDATE_STATUS

# Add root package first
PACKAGE_NAMES+=("genai-agent-template (root)")
OLD_VERSIONS+=("$CURRENT_VERSION")

# Update root package
echo "Updating root package..."
if uv version $NEW_VERSION >/dev/null 2>&1; then
    NEW_VERSIONS+=("$NEW_VERSION")
    UPDATE_STATUS+=("✓")
else
    NEW_VERSIONS+=("$CURRENT_VERSION")
    UPDATE_STATUS+=("✗")
fi

# Update all workspace packages
echo "Updating workspace packages..."
for pkg in $WORKSPACE_PACKAGES; do
    # Get current version of the package
    PKG_CURRENT_VERSION=$(uv version --package "$pkg" --short 2>/dev/null)
    if [ -z "$PKG_CURRENT_VERSION" ]; then
        PKG_CURRENT_VERSION="unknown"
    fi

    PACKAGE_NAMES+=("$pkg")
    OLD_VERSIONS+=("$PKG_CURRENT_VERSION")

    echo "  Updating $pkg..."
    if uv version --package "$pkg" "$NEW_VERSION" >/dev/null 2>&1; then
        NEW_VERSIONS+=("$NEW_VERSION")
        UPDATE_STATUS+=("✓")
    else
        NEW_VERSIONS+=("$PKG_CURRENT_VERSION")
        UPDATE_STATUS+=("✗")
    fi
done

echo ""
echo "================================================================================"
echo "                            📋 UPDATE SUMMARY                                   "
echo "================================================================================"
echo ""

# Calculate column widths
MAX_PKG_LEN=0
MAX_OLD_LEN=0
MAX_NEW_LEN=0

for i in "${!PACKAGE_NAMES[@]}"; do
    # Account for prefixes in package names
    if [[ "${PACKAGE_NAMES[$i]}" == *"(root)"* ]]; then
        PKG_LEN=$((${#PACKAGE_NAMES[$i]} + 7))  # Extra space for "[ROOT] " prefix
    else
        PKG_LEN=$((${#PACKAGE_NAMES[$i]} + 7))  # Extra space for "       " indentation
    fi
    OLD_LEN=${#OLD_VERSIONS[$i]}
    NEW_LEN=${#NEW_VERSIONS[$i]}

    [ $PKG_LEN -gt $MAX_PKG_LEN ] && MAX_PKG_LEN=$PKG_LEN
    [ $OLD_LEN -gt $MAX_OLD_LEN ] && MAX_OLD_LEN=$OLD_LEN
    [ $NEW_LEN -gt $MAX_NEW_LEN ] && MAX_NEW_LEN=$NEW_LEN
done

# Ensure minimum widths (account for header text without emojis for better compatibility)
[ $MAX_PKG_LEN -lt 25 ] && MAX_PKG_LEN=25  # "Package" + padding
[ $MAX_OLD_LEN -lt 12 ] && MAX_OLD_LEN=12  # "Old Version"
[ $MAX_NEW_LEN -lt 12 ] && MAX_NEW_LEN=12  # "New Version"

# Print table header with clean formatting
echo "+$(printf "%*s" $((MAX_PKG_LEN + 2)) | tr ' ' '-')+$(printf "%*s" $((MAX_OLD_LEN + 2)) | tr ' ' '-')+$(printf "%*s" $((MAX_NEW_LEN + 2)) | tr ' ' '-')+----------+"
printf "| %-${MAX_PKG_LEN}s | %-${MAX_OLD_LEN}s | %-${MAX_NEW_LEN}s | Status   |\n" "Package" "Old Version" "New Version"
echo "+$(printf "%*s" $((MAX_PKG_LEN + 2)) | tr ' ' '-')+$(printf "%*s" $((MAX_OLD_LEN + 2)) | tr ' ' '-')+$(printf "%*s" $((MAX_NEW_LEN + 2)) | tr ' ' '-')+----------+"

# Print table rows with better formatting
for i in "${!PACKAGE_NAMES[@]}"; do
    # Add special formatting for root package
    if [[ "${PACKAGE_NAMES[$i]}" == *"(root)"* ]]; then
        # Remove the redundant "(root)" suffix and just use [ROOT] prefix
        ROOT_NAME=$(echo "${PACKAGE_NAMES[$i]}" | sed 's/ (root)//')
        PKG_NAME="[ROOT] ${ROOT_NAME}"
    else
        PKG_NAME="       ${PACKAGE_NAMES[$i]}"
    fi

    # Format status with consistent spacing
    if [ "${UPDATE_STATUS[$i]}" == "✓" ]; then
        STATUS_DISPLAY="   OK   "
    else
        STATUS_DISPLAY="  FAIL  "
    fi

    printf "| %-${MAX_PKG_LEN}s | %-${MAX_OLD_LEN}s | %-${MAX_NEW_LEN}s | %s |\n" \
        "$PKG_NAME" "${OLD_VERSIONS[$i]}" "${NEW_VERSIONS[$i]}" "$STATUS_DISPLAY"
done

echo "+$(printf "%*s" $((MAX_PKG_LEN + 2)) | tr ' ' '-')+$(printf "%*s" $((MAX_OLD_LEN + 2)) | tr ' ' '-')+$(printf "%*s" $((MAX_NEW_LEN + 2)) | tr ' ' '-')+----------+"
echo ""

# Count successful updates
SUCCESS_COUNT=0
for status in "${UPDATE_STATUS[@]}"; do
    if [ "$status" == "✓" ]; then
        ((SUCCESS_COUNT++))
    fi
done

TOTAL_COUNT=${#PACKAGE_NAMES[@]}

# Pretty result summary
echo "================================================================================"
if [ $SUCCESS_COUNT -eq $TOTAL_COUNT ]; then
    echo "                          🎉 SUCCESS! ALL PACKAGES UPDATED                      "
    echo "================================================================================"
    echo ""
    printf "                       ✅ All %2d packages updated successfully!\n" $TOTAL_COUNT
    echo ""
    echo "                              🚀 Ready for deployment!"
else
    FAILED_COUNT=$((TOTAL_COUNT - SUCCESS_COUNT))
    echo "                               ⚠️  PARTIAL SUCCESS                             "
    echo "================================================================================"
    echo ""
    printf "                       ✅ %2d out of %2d packages updated successfully\n" $SUCCESS_COUNT $TOTAL_COUNT
    printf "                       ❌ %2d package(s) failed to update\n" $FAILED_COUNT
    echo ""
    echo "                        🔍 Please check the failed packages above"
fi
echo ""
echo "================================================================================"
