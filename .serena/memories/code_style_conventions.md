# Code Style and Conventions

## Swift Style Guide
- Follow Swift's native naming conventions
- Use camelCase for variables, functions
- Use PascalCase for types, protocols
- Prefer value types (struct) over reference types when possible
- Use extensions to organize code
- Follow SOLID principles

## Code Organization
- Use `// MARK: -` comments for organization
- Group related functionality in extensions
- Separate private methods from public interface

## Important Requirements
- **CRITICAL**: All files MUST end with a newline character
- This follows POSIX standards and prevents git diff issues
- SwiftLint will flag files without trailing newlines
- Configure editor to automatically add newlines at EOF

## SwiftLint Configuration
- Custom rule enforces newline at EOF with error severity
- Line length warning at 120 chars, error at 200
- File length warning at 500 lines, error at 1000
- Function body length warning at 50 lines, error at 100
- Uses Xcode reporter format

## SwiftUI Best Practices
```swift
// Use @StateObject for owned objects
@StateObject private var viewModel = AlertViewModel()

// Use @EnvironmentObject for shared state  
@EnvironmentObject var locationManager: LocationManager

// Use @AppStorage for user preferences
@AppStorage("defaultNotificationTime") var notificationTime: Int = 5
```

## iOS Development Patterns
- Always check location authorization before using
- Use appropriate accuracy based on distance to station
- Handle background tasks with BGTaskScheduler
- Store sensitive data in Keychain (never hardcode API keys)
- Use lazy loading for views and implement image caching
- Always provide user-friendly error messages
- Support accessibility (VoiceOver, Dynamic Type)

## Error Handling
- Use custom error enums with localized descriptions
- Provide fallback mechanisms for API failures
- Handle edge cases gracefully
- Log errors appropriately without exposing sensitive info