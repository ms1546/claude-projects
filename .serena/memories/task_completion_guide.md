# Task Completion Guide

## When a Task is Completed

### 1. Code Quality Checks
```bash
# Run SwiftLint to ensure code style compliance
swiftlint

# Fix any linting issues
swiftlint --fix
```

### 2. Testing Requirements
```bash
# Run unit tests to ensure functionality
xcodebuild test -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 15'

# Run UI tests for interface changes
xcodebuild test -scheme TrainAlertUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

### 3. Build Verification
```bash
# Ensure project builds successfully
xcodebuild build -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 15'

# Test on multiple devices/simulators if needed
xcodebuild build -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 14'
```

### 4. File Requirements Verification
- **CRITICAL**: Ensure all Swift files end with a newline character
- SwiftLint will enforce this with error severity
- Check that no files have trailing whitespace
- Verify proper indentation and formatting

### 5. Documentation Updates
- Update relevant documentation files if needed
- Add code comments for complex logic
- Update API documentation if public interfaces changed

### 6. Performance Verification
For background processing tasks specifically:
- Test battery consumption stays under 5%/hour
- Verify notification delivery rate exceeds 99%
- Test extended background operation reliability

### 7. iOS-Specific Testing
- Test on iOS 16.0 (minimum supported version)
- Verify location permissions work correctly
- Test background app refresh functionality
- Verify notification permissions and delivery

### 8. Commit and Documentation
```bash
# Stage changes
git add .

# Commit with descriptive message
git commit -m "feat: implement background task manager for ticket #012

- Add BackgroundTaskManager with BGTaskScheduler
- Implement battery-optimized location updates  
- Add crash reporting and background logging
- Configure geofencing and significant location changes
- Handle Low Power Mode detection and adjustment"

# Update ticket status
# Mark completed tasks in docs/tickets/012_background_processing.md
```

### 9. Final Verification Checklist
- [ ] Code compiles without warnings
- [ ] All tests pass
- [ ] SwiftLint validation passes
- [ ] Files end with newlines
- [ ] Performance meets requirements
- [ ] Background modes work correctly
- [ ] Error handling is comprehensive
- [ ] User privacy is respected
- [ ] Accessibility features work
- [ ] Documentation is updated