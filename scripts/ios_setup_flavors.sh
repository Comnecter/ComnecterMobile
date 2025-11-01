#!/bin/bash

# Setup iOS schemes and build configurations for staging/production flavors
# This script creates Xcode schemes that work with Flutter's flavor system

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$PROJECT_DIR/ios"
SCHEMES_DIR="$IOS_DIR/Runner.xcodeproj/xcshareddata/xcschemes"
PROJECT_FILE="$IOS_DIR/Runner.xcodeproj/project.pbxproj"

echo "🍎 Setting up iOS flavors (staging/production)..."

# Create schemes directory if it doesn't exist
mkdir -p "$SCHEMES_DIR"

# Check if Xcode project exists
if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Error: Xcode project not found at $PROJECT_FILE"
    exit 1
fi

echo "✅ Xcode project found"
echo "📝 Note: Xcode schemes need to be created manually in Xcode for full flavor support."
echo ""
echo "To set up iOS flavors properly:"
echo "1. Open ios/Runner.xcworkspace in Xcode"
echo "2. Go to Product > Scheme > Manage Schemes"
echo "3. Duplicate the Runner scheme to create 'Runner Staging' and 'Runner Production'"
echo "4. Configure each scheme to use appropriate build configurations"
echo ""
echo "Or use the build-config.sh script to switch manually:"
echo "  ./ios/build-config.sh staging    # Switch to staging"
echo "  ./ios/build-config.sh production  # Switch to production"
echo ""
echo "Then run: flutter run"

