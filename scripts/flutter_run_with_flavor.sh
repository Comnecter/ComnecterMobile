#!/bin/bash

# Flutter run script with flavor support for both Android and iOS
# Usage: ./scripts/flutter_run_with_flavor.sh [staging|production] [additional flutter args]

set -e

FLAVOR=${1:-staging}
shift || true  # Remove first argument, keep rest for flutter

if [ "$FLAVOR" != "staging" ] && [ "$FLAVOR" != "production" ]; then
    echo "❌ Error: Invalid flavor '$FLAVOR'. Use 'staging' or 'production'"
    exit 1
fi

echo "🚀 Running Flutter with flavor: $FLAVOR"

# Get the platform (iOS or Android)
PLATFORM=$(uname)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# For iOS, switch configuration first
if [[ "$*" == *"-d"* ]] && [[ "$*" == *"ios"* ]] || [[ "$*" == *"-d"* ]] && [[ "$*" == *"iPhone"* ]] || [[ -z "$*" ]]; then
    # Check if running on iOS (either explicit or default)
    echo "🍎 iOS detected - switching to $FLAVOR configuration..."
    cd "$PROJECT_DIR/ios"
    ./build-config.sh "$FLAVOR"
    cd "$PROJECT_DIR"
fi

# Run Flutter with the flavor
# For Android, --flavor works natively
# For iOS, the config is already switched
if [[ "$*" == *"-d"* ]] && [[ "$*" == *"android"* ]]; then
    # Android - use --flavor flag
    echo "🤖 Android detected - using --flavor $FLAVOR"
    flutter run --flavor "$FLAVOR" "$@"
elif [[ "$*" == *"-d"* ]] && ([[ "$*" == *"ios"* ]] || [[ "$*" == *"iPhone"* ]]); then
    # iOS - config already switched, run without flavor flag
    echo "🍎 Running on iOS..."
    flutter run "$@"
else
    # Default - try Android first with flavor, fallback to iOS
    echo "📱 Detecting platform..."
    if flutter devices | grep -q "android"; then
        echo "🤖 Running on Android with flavor $FLAVOR"
        flutter run --flavor "$FLAVOR" "$@"
    else
        echo "🍎 Running on iOS (config already switched)"
        flutter run "$@"
    fi
fi

