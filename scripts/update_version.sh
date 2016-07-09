#!/bin/bash

# Exit the script if any statement returns a non-true return value
set -e

# Project ${PRODUCT_NAME}-Info.plist
PROJECT_INFOPLIST_PATH="${PROJECT_DIR}/${INFOPLIST_FILE}"

# App settings Root.plist file
APP_SETTINGS_ROOTPLIST_PATH="${SRCROOT}/resources/Settings.bundle/Root.plist"

if [ ! -d ".git" ]; then
	CURRENT_GIT_LONG_VERSION=""
	CURRENT_GIT_TAG_VERSION=""
	CURRENT_GIT_COMMIT_COUNT=""
	CURRENT_GIT_COMMIT_SHORT_HASH=""
	CURRENT_GIT_BRANCH=""
else
	CURRENT_GIT_LONG_VERSION=`git describe --tags`
	CURRENT_GIT_TAG_VERSION=`git describe --abbrev=0 --tags`
	CURRENT_GIT_COMMIT_COUNT=`git rev-list HEAD --count`
	CURRENT_GIT_COMMIT_HASH=`git rev-parse HEAD`
	CURRENT_GIT_COMMIT_SHORT_HASH=`git rev-parse --short HEAD`
	CURRENT_GIT_BRANCH=`git rev-parse --abbrev-ref HEAD`
fi

CURRENT_VERSION=$CURRENT_GIT_TAG_VERSION
CURRENT_BUILD_NUMBER=$CURRENT_GIT_COMMIT_COUNT
CURRENT_VERSION_AND_BUILD_NUMBER="${CURRENT_VERSION} (${CURRENT_BUILD_NUMBER})"

# Version
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $CURRENT_VERSION" "${PROJECT_INFOPLIST_PATH}"

# Build Number
/usr/libexec/PlistBuddy -c "Set CFBundleVersion $CURRENT_BUILD_NUMBER" "${PROJECT_INFOPLIST_PATH}"