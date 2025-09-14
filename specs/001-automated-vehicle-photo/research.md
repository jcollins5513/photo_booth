# Research Findings: Automated Vehicle Photo Booth

**Date**: 2024-12-19  
**Phase**: 0 - Research  
**Status**: Complete

## CoreML Model Training for Vehicle Angle Classification

**Decision**: Use CreateML with custom training data for vehicle angle classification  
**Rationale**: CreateML provides the easiest path to create CoreML models optimized for iOS devices, with built-in image classification capabilities and automatic optimization for Neural Engine acceleration.  
**Alternatives considered**: 
- TensorFlow Lite conversion: More complex setup, requires Python environment
- Pre-trained models: Limited to generic object detection, not specific angle classification
- Custom Vision API: Requires internet connection, violates offline requirement

**Implementation approach**:
- Collect training dataset of 200+ images per angle (8 angles = 1600+ images minimum)
- Use CreateML's Image Classifier template
- Train on diverse vehicle types, lighting conditions, and backgrounds
- Export as .mlmodel file for iOS integration

## Firebase Auth SDK Integration for iOS

**Decision**: Use Firebase Auth SDK with email/password authentication  
**Rationale**: Firebase Auth provides secure, scalable authentication with minimal setup, supports offline authentication tokens, and integrates seamlessly with iOS.  
**Alternatives considered**:
- Local authentication only: Insufficient for multi-user scenarios
- Custom backend: Overkill for MVP, adds complexity
- Sign in with Apple: Good for App Store, but limits user base

**Implementation approach**:
- Add Firebase SDK via Swift Package Manager
- Configure Firebase project and GoogleService-Info.plist
- Implement email/password sign up and sign in flows
- Store authentication state in UserDefaults for session persistence
- Handle offline authentication with cached tokens

## AVFoundation Camera Setup and Real-time Capture

**Decision**: Use AVCaptureSession with AVCapturePhotoOutput for high-quality still images  
**Rationale**: AVFoundation provides the most control over camera settings, supports high-resolution capture, and integrates well with Vision framework for real-time analysis.  
**Alternatives considered**:
- UIImagePickerController: Limited control over camera settings
- Third-party camera libraries: Unnecessary complexity for core functionality

**Implementation approach**:
- Set up AVCaptureSession with rear camera
- Configure AVCaptureVideoPreviewLayer for live preview
- Use AVCapturePhotoOutput for high-resolution still capture
- Implement continuous autofocus and auto-exposure
- Handle camera permissions and error states
- Optimize for vehicle photography (focus distance, exposure settings)

## Vision Framework Integration with CoreML

**Decision**: Use VNClassifyImageRequest with custom CoreML model for real-time classification  
**Rationale**: Vision framework provides optimized image analysis pipeline, automatic image preprocessing, and seamless CoreML integration with GPU acceleration.  
**Alternatives considered**:
- Direct CoreML inference: Requires manual image preprocessing
- Custom image processing: Reinventing wheel, less optimized

**Implementation approach**:
- Load CoreML model using VNCoreMLModel
- Create VNClassifyImageRequest for angle classification
- Process camera frames at 5-10 FPS for real-time detection
- Implement confidence thresholds (0.8+ for auto-capture)
- Handle multiple classifications and select highest confidence
- Add fallback to manual capture for low confidence scenarios

## Local Storage Architecture and Core Data Schema

**Decision**: Use Core Data for metadata with file system storage for images  
**Rationale**: Core Data provides robust data modeling, relationships, and querying capabilities for session metadata, while file system storage is more efficient for large image files.  
**Alternatives considered**:
- SQLite directly: More complex, less iOS integration
- All file system: Difficult to query and manage relationships
- All Core Data with binary data: Performance issues with large images

**Implementation approach**:
- Core Data entities: PhotoSession, VehiclePhoto, UserAccount, PhotoAngle
- File system structure: Documents/Vehicles/{sessionId}/images/
- Image storage: JPEG format, 1920x1080 resolution for balance of quality/size
- Metadata storage: File paths, timestamps, confidence scores, angle types
- Implement data migration and cleanup for old sessions

## Additional Technical Decisions

### Error Handling Strategy
**Decision**: Comprehensive error handling with user-friendly messages and fallback options  
**Implementation**: Use Result types, structured logging with OSLog, and graceful degradation (manual capture if auto-detection fails)

### Performance Optimization
**Decision**: Optimize for real-time processing with minimal battery drain  
**Implementation**: Use background queues for ML processing, implement frame skipping for performance, and optimize CoreML model size

### Testing Strategy
**Decision**: Comprehensive testing with real device testing for camera functionality  
**Implementation**: Unit tests for business logic, integration tests for services, UI tests for user flows, and manual testing with actual vehicles

### Security and Privacy
**Decision**: Local-first approach with secure authentication  
**Implementation**: Store photos locally only, use Keychain for sensitive data, implement secure authentication flows, and provide clear privacy policy

## Research Validation

All technical unknowns have been resolved with specific implementation approaches. The chosen technologies provide:
- ✅ Offline functionality (CoreML, local storage)
- ✅ Real-time performance (Vision framework, optimized models)
- ✅ User-friendly interface (SwiftUI, AVFoundation)
- ✅ Scalable architecture (Core Data, modular services)
- ✅ Security and privacy (local storage, secure auth)

**Status**: Ready for Phase 1 - Design & Contracts
