# Vehicle Photo Booth - AI Assistant Context

## Project Overview
Automated Vehicle Photo Booth iOS application that uses computer vision to automatically capture vehicle photos from multiple angles. Built with SwiftUI, AVFoundation, Vision framework, and CoreML.

## Technology Stack
- **Language**: Swift 5.9
- **Platform**: iOS 15.0+
- **UI Framework**: SwiftUI
- **Camera**: AVFoundation
- **Computer Vision**: Vision framework + CoreML
- **Authentication**: Firebase Auth SDK
- **Storage**: Core Data + Local file system
- **Testing**: XCTest, XCUITest

## Architecture
- **Pattern**: MVVM (Model-View-ViewModel)
- **Services**: CameraService, VisionService, AuthenticationService, StorageService
- **Data**: Core Data for metadata, Documents directory for images
- **Real-time**: 5-10 FPS vision processing, 1-second capture response

## Key Features
- 8-angle vehicle photo sequence (front, front-left, front-right, side, rear-right, rear, rear-left, opposite-side)
- Automatic position detection using CoreML model
- Real-time camera preview with visual feedback
- Local storage with organized folder structure
- User authentication and session management
- Offline-capable core functionality

## Current Development Status
- ✅ Feature specification complete
- ✅ Implementation plan complete
- ✅ Research and design complete
- ✅ Contracts and data model defined
- 🔄 Ready for task generation and implementation

## Recent Changes (Last 3)
1. **2024-12-19**: Created comprehensive implementation plan with contracts and data model
2. **2024-12-19**: Completed research phase with technical decisions for CoreML, Firebase, and AVFoundation
3. **2024-12-19**: Established project structure and planning system

## Development Guidelines
- Follow TDD approach with tests written first
- Use contract-based testing for service interfaces
- Implement comprehensive error handling
- Optimize for real-time performance and battery life
- Maintain offline functionality for core features
- Use structured logging with OSLog

## File Structure
```
ios/VehiclePhotoBooth/
├── Models/ (Core Data entities)
├── Views/ (SwiftUI views)
├── ViewModels/ (MVVM view models)
├── Services/ (Business logic services)
├── Resources/ (Assets, Core Data model)
└── Tests/ (Unit, integration, UI tests)
```

## Next Steps
- Generate detailed implementation tasks
- Set up iOS project structure
- Implement core services with contract tests
- Create user interface with SwiftUI
- Integrate computer vision and camera functionality
