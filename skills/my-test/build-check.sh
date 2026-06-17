#!/usr/bin/env bash
# build-check.sh — Maven build verification script for use with the maven-build-check skill.
# Usage: bash build-check.sh [maven-args]
# Exit codes: 0 = BUILD SUCCESS, 1 = BUILD FAILURE or pre-flight error

set -uo pipefail

MAVEN_ARGS="${*}"
JAVA_MIN_VERSION=17

# ── Pre-flight: verify Java version ─────────────────────────────────────────
java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
if [[ -z "$java_version" ]]; then
    echo "ERROR: Java not found on PATH. Run: sdk use java 17.0.19-amzn"
    exit 1
fi
if [[ "$java_version" -lt "$JAVA_MIN_VERSION" ]]; then
    echo "ERROR: Java $JAVA_MIN_VERSION required but Java $java_version is active."
    echo "       Run: sdk use java 17.0.19-amzn"
    exit 1
fi

# ── Pre-flight: verify pom.xml exists ───────────────────────────────────────
if [[ ! -f "pom.xml" ]]; then
    echo "ERROR: No pom.xml found in $(pwd). Run this script from the project root."
    exit 1
fi

PROJECT_NAME=$(grep -m1 '<artifactId>' pom.xml | sed 's/.*<artifactId>\(.*\)<\/artifactId>.*/\1/' | xargs)

echo "════════════════════════════════════════════════════"
echo " Maven Build Check"
echo " Project : $PROJECT_NAME"
echo " Java    : $java_version"
echo " Args    : mvn clean verify $MAVEN_ARGS"
echo " CWD     : $(pwd)"
echo "════════════════════════════════════════════════════"
echo ""

# ── Run the build ────────────────────────────────────────────────────────────
# shellcheck disable=SC2086
mvn clean verify $MAVEN_ARGS 2>&1
BUILD_EXIT_CODE=$?

echo ""
echo "════════════════════════════════════════════════════"
if [[ $BUILD_EXIT_CODE -eq 0 ]]; then
    echo " RESULT : BUILD SUCCESS ✅"
else
    echo " RESULT : BUILD FAILURE ❌"
fi
echo "════════════════════════════════════════════════════"

exit $BUILD_EXIT_CODE
