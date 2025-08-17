# Technology Stack

## Platform & Requirements
- **Platform**: iOS 17.0+ (iPhone and iPad)
- **Development**: Xcode 15.0+, macOS Sonoma+
- **Language**: Swift 5.0
- **Architecture**: SwiftUI with MVVM pattern

## Core Frameworks
- **SwiftUI**: Primary UI framework for declarative interface design
- **Vision**: VisionKit for camera-based object detection and recognition
- **Core ML**: Apple Foundation Models for on-device AI processing
- **LocalAuthentication**: Face ID/Touch ID integration with Secure Enclave
- **AVFoundation**: Camera capture and processing
- **CryptoKit**: End-to-end encryption for financial data storage

## Data Persistence
- **AppStorage**: Primary storage mechanism for user preferences and data
- **JSON Encoding/Decoding**: Structured data serialization for transactions, budgets, and streaks
- **Secure Storage**: All financial data encrypted using CryptoKit before storage

## Build System
- **Xcode Project**: Standard iOS app project structure
- **Bundle ID**: `com.aicoder2009.Penny`
- **Deployment Target**: iOS 17.0 minimum
- **Supported Devices**: iPhone and iPad (portrait-optimized)

## Common Commands

### Building & Running
```bash
# Open project in Xcode
open Penny.xcodeproj

# Build and run (Xcode)
# Select target device/simulator and press Cmd+R
```

### Project Structure
```bash
# Clean build folder
# Product → Clean Build Folder (Shift+Cmd+K)

# Archive for distribution
# Product → Archive (Cmd+Shift+B)
```

## Development Patterns
- **MVVM Architecture**: ViewModels manage business logic, Views handle presentation
- **ObservableObject**: State management using `@StateObject` and `@ObservedObject`
- **Async Processing**: Background queues for data persistence and AI processing
- **Error Handling**: Graceful degradation with user-friendly error messages