# Suggested Commands for TrainAlert Development

## Testing Commands
```bash
# Unit tests
xcodebuild test -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 15'

# UI tests  
xcodebuild test -scheme TrainAlertUITests -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:TrainAlertTests/OpenAIClientTests

# Run specific test method
xcodebuild test -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:TrainAlertTests/OpenAIClientTests/testAPICall
```

## Build Commands
```bash
# Build for simulator
xcodebuild build -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 15'

# Build for device
xcodebuild build -scheme TrainAlert -destination 'generic/platform=iOS'

# Archive for TestFlight
xcodebuild archive -scheme TrainAlert -archivePath ./build/TrainAlert.xcarchive

# Export IPA
xcodebuild -exportArchive -archivePath ./build/TrainAlert.xcarchive -exportPath ./build -exportOptionsPlist ExportOptions.plist
```

## Linting and Formatting
```bash
# Run SwiftLint
swiftlint

# Run SwiftLint with auto-correct
swiftlint --fix

# Run SwiftLint on specific file
swiftlint lint --path TrainAlert/Services/LocationManager.swift

# Generate SwiftLint report
swiftlint lint --reporter html > swiftlint_report.html
```

## macOS/Darwin Specific Commands
```bash
# List files (macOS version)
ls -la

# Find files
find . -name "*.swift" -type f

# Search in files
grep -r "LocationManager" TrainAlert/

# Use ripgrep (faster alternative)
rg "LocationManager" TrainAlert/

# Change directory
cd TrainAlert/

# Show file content
cat TrainAlert/Services/LocationManager.swift

# Show file with line numbers
cat -n TrainAlert/Services/LocationManager.swift
```

## Git Commands
```bash
# Check status
git status

# Add files
git add .

# Commit changes
git commit -m "Implement background task optimization"

# Push to remote
git push origin feature/ticket-012-background_processing

# Create new branch
git checkout -b feature/ticket-012-background_processing

# Merge branch
git checkout main
git merge feature/ticket-012-background_processing
```

## Xcode Project Commands
```bash
# Open project in Xcode
open TrainAlert.xcodeproj

# Clean build folder
xcodebuild clean -scheme TrainAlert

# Show available schemes
xcodebuild -list

# Show available destinations
xcodebuild -showdestinations -scheme TrainAlert
```

## Development Workflow Commands
```bash
# Install dependencies (if using Swift Package Manager)
swift package resolve

# Generate documentation
swift-doc generate TrainAlert/ --output docs/

# Run performance profiling
instruments -t "Time Profiler" TrainAlert.app

# Check code coverage
xcodebuild test -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 15' -enableCodeCoverage YES
```