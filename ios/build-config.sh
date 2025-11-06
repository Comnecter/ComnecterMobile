#!/bin/bash

# iOS Firebase Configuration Switcher
# Usage: ./ios/build-config.sh [staging|production]

set -e

ENV=${1:-staging}

echo "🔄 Switching iOS configuration to: $ENV"

# Get the absolute path to the ios directory
IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER_DIR="$IOS_DIR/Runner"

# Check if Runner directory exists
if [ ! -d "$RUNNER_DIR" ]; then
    echo "❌ Error: Runner directory not found at $RUNNER_DIR"
    exit 1
fi

if [ "$ENV" = "staging" ]; then
    # Switch to staging configuration
    if [ ! -f "$RUNNER_DIR/GoogleService-Info-staging.plist" ]; then
        echo "❌ Error: GoogleService-Info-staging.plist not found"
        exit 1
    fi
    
    # Copy staging config
    cp "$RUNNER_DIR/GoogleService-Info-staging.plist" "$RUNNER_DIR/GoogleService-Info.plist"
    echo "✅ Copied staging Firebase config"
    
    # Update bundle identifier in Info.plist
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' 's/com.comnecter.mobile.production/com.comnecter.mobile.staging/g' "$RUNNER_DIR/Info.plist"
    else
        # Linux
        sed -i 's/com.comnecter.mobile.production/com.comnecter.mobile.staging/g' "$RUNNER_DIR/Info.plist"
    fi
    echo "✅ Updated bundle identifier to: com.comnecter.mobile.staging"
    
elif [ "$ENV" = "production" ]; then
    # Switch to production configuration
    if [ ! -f "$RUNNER_DIR/GoogleService-Info-production.plist" ]; then
        echo "❌ Error: GoogleService-Info-production.plist not found"
        exit 1
    fi
    
    # Copy production config
    cp "$RUNNER_DIR/GoogleService-Info-production.plist" "$RUNNER_DIR/GoogleService-Info.plist"
    echo "✅ Copied production Firebase config"
    
    # Update bundle identifier in Info.plist
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' 's/com.comnecter.mobile.staging/com.comnecter.mobile.production/g' "$RUNNER_DIR/Info.plist"
    else
        # Linux
        sed -i 's/com.comnecter.mobile.staging/com.comnecter.mobile.production/g' "$RUNNER_DIR/Info.plist"
    fi
    echo "✅ Updated bundle identifier to: com.comnecter.mobile.production"
    
else
    echo "❌ Invalid environment: $ENV"
    echo "Usage: $0 [staging|production]"
    exit 1
fi

# Verify configuration
if [ -f "$RUNNER_DIR/GoogleService-Info.plist" ]; then
    echo "✅ Configuration file exists"
else
    echo "❌ Warning: GoogleService-Info.plist not found"
fi

echo "✅ iOS configured for: $ENV"
echo "📱 Now you can run: flutter run"



