#!/bin/bash

echo "🧹 Resetting Swift Package Manager caches..."

# Clear Xcode derived data
echo "Clearing Xcode derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData

# Clear SPM cache
echo "Clearing SPM cache..."
rm -rf ~/Library/Caches/org.swift.swiftpm

# Resolve package dependencies
echo "Resolving package dependencies..."
xcodebuild -resolvePackageDependencies

echo "✅ SPM reset complete! New files should now be visible."
