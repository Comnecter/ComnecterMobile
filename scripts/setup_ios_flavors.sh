#!/bin/bash

# Setup iOS Xcode schemes for Flutter flavors (staging/production)
# This script creates the necessary Xcode schemes that Flutter requires for --flavor to work

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$PROJECT_DIR/ios"
WORKSPACE="$IOS_DIR/Runner.xcworkspace"
PROJECT="$IOS_DIR/Runner.xcodeproj"
SCHEMES_DIR="$PROJECT/xcshareddata/xcschemes"

echo "🍎 Setting up iOS flavors for Flutter..."

# Check prerequisites
if [ ! -d "$PROJECT" ]; then
    echo "❌ Error: Xcode project not found at $PROJECT"
    exit 1
fi

# Ensure schemes directory exists
mkdir -p "$SCHEMES_DIR"

# Create staging scheme
echo "📝 Creating 'staging' scheme..."
cat > "$SCHEMES_DIR/staging.xcscheme" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1510"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "97C146ED1CF9000F007C117D"
               BuildableName = "Runner.app"
               BlueprintName = "Runner"
               ReferencedContainer = "container:Runner.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "331C8081294A63A400263BE5"
               BuildableName = "RunnerTests.xctest"
               BlueprintName = "RunnerTests"
               ReferencedContainer = "container:Runner.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "97C146ED1CF9000F007C117D"
            BuildableName = "Runner.app"
            BlueprintName = "Runner"
            ReferencedContainer = "container:Runner.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Profile"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "97C146ED1CF9000F007C117D"
            BuildableName = "Runner.app"
            BlueprintName = "Runner"
            ReferencedContainer = "container:Runner.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
EOF

# Create production scheme
echo "📝 Creating 'production' scheme..."
cp "$SCHEMES_DIR/staging.xcscheme" "$SCHEMES_DIR/production.xcscheme"

# Make schemes visible to Flutter by ensuring they're marked as shared
# Flutter looks for schemes in xcshareddata/xcschemes directory (which we just created)

echo ""
echo "✅ Xcode schemes created successfully!"
echo ""
echo "📋 Created schemes:"
echo "   - staging (for staging environment)"
echo "   - production (for production environment)"
echo ""
echo "🧪 Testing the setup..."
echo ""

# Verify schemes are visible to xcodebuild
if xcodebuild -list -workspace "$WORKSPACE" 2>/dev/null | grep -q "staging\|production"; then
    echo "✅ Schemes are accessible via xcodebuild"
else
    echo "⚠️  Schemes created but may need Xcode to recognize them"
    echo "   Try opening the workspace in Xcode: open $WORKSPACE"
fi

echo ""
echo "✅ iOS flavor setup complete!"
echo ""
echo "🚀 You can now use:"
echo "   flutter run --flavor staging"
echo "   flutter run --flavor production"
echo ""
echo "📝 Note: Before running with a flavor, make sure to run:"
echo "   ./ios/build-config.sh staging    # or production"
echo "   This switches the Firebase config and bundle ID"

