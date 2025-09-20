# Photo Booth Project Constitution

## Core Principles

### I. iOS-First Architecture
Every feature is designed for iOS 26 and iPhone 17 as the primary target platform. The app leverages the latest iOS capabilities including advanced CoreML models, enhanced Vision framework, and iPhone 17's improved Neural Engine for real-time vehicle detection and photo capture.

### II. Real-Time Computer Vision
The system prioritizes real-time vehicle position detection using on-device CoreML models optimized for iPhone 17's Neural Engine. All vision processing must maintain 5-10 FPS performance with sub-second photo capture response times.

### III. Test-First Development (NON-NEGOTIABLE)
TDD mandatory: Tests written → User approved → Tests fail → Then implement; Red-Green-Refactor cycle strictly enforced. All camera functionality, CoreML model integration, and photo capture workflows must have comprehensive test coverage.

### IV. Offline-First Design
Core functionality must work without internet connection. Photo sessions, vehicle detection, and local storage are fully offline-capable. Only authentication and optional cloud sync require network connectivity.

### V. User Experience Excellence
The app provides intuitive visual guidance for vehicle positioning, clear feedback for photo capture success, and seamless session management. All interactions are optimized for single-handed use while driving.

## Technology Stack Requirements

**Platform**: iOS 26.0+ (iPhone 17 optimized)  
**Language**: Swift 5.9+  
**Frameworks**: SwiftUI, AVFoundation, Vision, CoreML, Firebase Auth  
**Storage**: Core Data (metadata), File System (photos)  
**Testing**: XCTest, XCUITest  
**Performance**: Real-time vision processing, <1 second photo capture  

## Development Workflow

**Constitution Compliance**: All code changes must pass constitution checks before merge  
**Testing Gates**: 100% test coverage for camera and vision functionality  
**Performance Validation**: Real-time processing benchmarks must be maintained  
**Code Review**: All PRs must verify iOS 26 compatibility and iPhone 17 optimization  

## Governance

Constitution supersedes all other practices. Amendments require documentation, approval, and migration plan. All development must align with iOS 26 capabilities and iPhone 17 hardware optimization.

**Version**: 1.0.0 | **Ratified**: 2024-12-19 | **Last Amended**: 2024-12-19