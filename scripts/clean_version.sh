#!/bin/sh

# Exit the script if any statement returns a non-true return value
set -e

# Project ${PRODUCT_NAME}-Info.plist
PROJECT_INFOPLIST_PATH="${PROJECT_DIR}/${INFOPLIST_FILE}"

# App settings Root.plist file
APP_SETTINGS_ROOTPLIST_PATH="${SRCROOT}/resources/Settings.bundle/Root.plist"

CURRENT_GIT_LONG_VERSION=""
CURRENT_GIT_TAG_VERSION=""
CURRENT_GIT_COMMIT_COUNT=""
CURRENT_GIT_COMMIT_SHORT_HASH=""
CURRENT_GIT_BRANCH=""

CURRENT_VERSION=$CURRENT_GIT_TAG_VERSION
CURRENT_BUILD_NUMBER=$CURRENT_GIT_COMMIT_COUNT
CURRENT_VERSION_AND_BUILD_NUMBER=""

# Version
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $CURRENT_VERSION" "${PROJECT_INFOPLIST_PATH}"

# Build Number
/usr/libexec/PlistBuddy -c "Set CFBundleVersion $CURRENT_BUILD_NUMBER" "${PROJECT_INFOPLIST_PATH}"