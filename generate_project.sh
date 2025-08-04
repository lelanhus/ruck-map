#!/bin/bash

# Generate RuckMap Xcode project with Watch app support
echo "Generating RuckMap Xcode project..."

# Check if XcodeGen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "XcodeGen not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install xcodegen
    else
        echo "Homebrew not found. Please install XcodeGen manually:"
        echo "https://github.com/yonaskolb/XcodeGen"
        exit 1
    fi
fi

# Generate the project
xcodegen generate

if [ $? -eq 0 ]; then
    echo "✅ Xcode project generated successfully!"
    echo ""
    echo "📱 iOS App: RuckMap target"
    echo "⌚ Watch App: RuckMapWatch + RuckMapWatchExtension targets"
    echo ""
    echo "To build and run:"
    echo "1. Open RuckMap.xcodeproj in Xcode"
    echo "2. Select RuckMap scheme for iPhone app"
    echo "3. Select RuckMapWatch scheme for Watch app"
    echo ""
    echo "Note: Watch app requires physical Apple Watch for location services testing"
else
    echo "❌ Failed to generate Xcode project"
    echo "Check project.yml for configuration issues"
    exit 1
fi