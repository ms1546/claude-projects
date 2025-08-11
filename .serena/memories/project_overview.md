# TrainAlert Project Overview

## Project Purpose
TrainAlert is an iOS app designed to prevent oversleeping on trains using location-based and AI-generated notifications. The app helps users wake up before reaching their destination station.

## Tech Stack
- **Language**: Swift 5.9
- **UI Framework**: SwiftUI
- **iOS Version**: iOS 16.0+ (minimum deployment target)
- **Architecture**: MVVM pattern with Combine
- **Development Environment**: Xcode 15.0+ on M2 Mac

## Key Technologies
- Core Location (GPS positioning)
- UserNotifications (local notifications)
- MapKit (maps and station location)
- Core Data (data persistence)
- URLSession (API communication)
- BackgroundTasks (background processing)

## External APIs
- HeartRails Express API (station information, lines, delays)
- OpenAI API (ChatGPT for generating notification messages)

## Project Structure
```
TrainAlert/
├── Models/         # Core Data entities, data models
├── Views/          # SwiftUI views
├── ViewModels/     # MVVM view models with Combine
├── Services/       # API clients, managers (LocationManager, NotificationManager, etc.)
├── Resources/      # Assets, Info.plist
├── Utilities/      # Extensions, helpers
└── docs/           # Project documentation
```

## Current Implementation Status
The project already has:
- Core Data setup with Station, Alert, History entities
- LocationManager with dynamic accuracy adjustment
- NotificationManager with AI-generated messages
- Complete UI screens (Home, Settings, History, Alert Setup)
- OpenAI integration for character-based notifications
- Design system with SwiftUI components
- Existing background modes configured in Info.plist

## Background Processing Requirements (Ticket #012)
Currently working on optimizing background processing with requirements:
- Battery consumption under 5%/hour
- Notification delivery rate over 99%
- Reliable extended background operation