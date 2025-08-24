#!/bin/bash
# Core Dataのリセットスクリプト

echo "🧹 Cleaning DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/TrainAlert-*

echo "📱 Removing app from simulator..."
xcrun simctl uninstall booted trainalert.TrainAlert 2>/dev/null || true

echo "🔨 Clean build..."
xcodebuild clean -workspace TrainAlert.xcworkspace -scheme TrainAlert -quiet

echo "✅ Complete! Now open Xcode and run the project."