# Data Model: Automated Vehicle Photo Booth

**Date**: 2024-12-19  
**Phase**: 1 - Design  
**Status**: Complete

## Core Data Entities

### PhotoSession
Represents a complete photo capture workflow for a single vehicle.

**Attributes**:
- `id`: UUID (Primary Key)
- `vehicleIdentifier`: String (User-provided vehicle name/ID)
- `startDate`: Date
- `endDate`: Date?
- `status`: SessionStatus (enum: active, completed, cancelled)
- `totalAngles`: Int16 (8 for standard sequence)
- `completedAngles`: Int16 (0-8)
- `createdBy`: String (User ID from Firebase Auth)
- `notes`: String? (Optional user notes)

**Relationships**:
- `photos`: ToMany → VehiclePhoto (1:many)
- `user`: ToOne → UserAccount (many:1)

**Validation Rules**:
- `vehicleIdentifier` cannot be empty
- `totalAngles` must be between 1-12
- `completedAngles` cannot exceed `totalAngles`
- `endDate` must be after `startDate` if set

### VehiclePhoto
Represents an individual captured image with metadata.

**Attributes**:
- `id`: UUID (Primary Key)
- `fileName`: String (Unique filename)
- `filePath`: String (Relative path in Documents directory)
- `angleType`: PhotoAngleType (enum: front, frontLeft, frontRight, side, rearRight, rear, rearLeft, oppositeSide)
- `captureDate`: Date
- `confidenceScore`: Double (0.0-1.0 from ML model)
- `isAutoCaptured`: Bool (true if auto-captured, false if manual)
- `fileSize`: Int64 (bytes)
- `imageWidth`: Int32
- `imageHeight`: Int32

**Relationships**:
- `session`: ToOne → PhotoSession (many:1)

**Validation Rules**:
- `fileName` must be unique across all photos
- `filePath` must be valid relative path
- `confidenceScore` must be between 0.0-1.0
- `fileSize` must be greater than 0
- `imageWidth` and `imageHeight` must be positive

### UserAccount
Represents authenticated user with access permissions and session history.

**Attributes**:
- `id`: String (Firebase UID)
- `email`: String
- `displayName`: String?
- `createdDate`: Date
- `lastLoginDate`: Date
- `isActive`: Bool
- `preferences`: Data? (JSON-encoded user preferences)

**Relationships**:
- `sessions`: ToMany → PhotoSession (1:many)

**Validation Rules**:
- `id` must be valid Firebase UID format
- `email` must be valid email format
- `displayName` can be nil but not empty string

### PhotoAngle
Represents a predefined vehicle viewing angle with detection criteria.

**Attributes**:
- `id`: String (Primary Key - enum value)
- `name`: String (Human-readable name)
- `displayName`: String (UI display name)
- `angleDegrees`: Int16 (Approximate angle in degrees)
- `isEnabled`: Bool
- `sortOrder`: Int16 (Display order)
- `confidenceThreshold`: Double (Minimum confidence for auto-capture)

**Relationships**: None (Reference data)

**Validation Rules**:
- `id` must be one of predefined enum values
- `angleDegrees` must be between 0-360
- `confidenceThreshold` must be between 0.0-1.0

## Enums

### SessionStatus
```swift
enum SessionStatus: String, CaseIterable {
    case active = "active"
    case completed = "completed"
    case cancelled = "cancelled"
}
```

### PhotoAngleType
```swift
enum PhotoAngleType: String, CaseIterable {
    case front = "front"
    case frontLeft = "front_left"
    case frontRight = "front_right"
    case side = "side"
    case rearRight = "rear_right"
    case rear = "rear"
    case rearLeft = "rear_left"
    case oppositeSide = "opposite_side"
}
```

## File System Structure

### Documents Directory Layout
```
Documents/
├── Vehicles/
│   ├── {sessionId}/
│   │   ├── metadata.json
│   │   ├── front.jpg
│   │   ├── front_left.jpg
│   │   ├── front_right.jpg
│   │   ├── side.jpg
│   │   ├── rear_right.jpg
│   │   ├── rear.jpg
│   │   ├── rear_left.jpg
│   │   └── opposite_side.jpg
│   └── {anotherSessionId}/
│       └── ...
└── Models/
    └── VehicleAngleClassifier.mlmodel
```

### Metadata JSON Structure
```json
{
    "sessionId": "uuid",
    "vehicleIdentifier": "string",
    "startDate": "ISO8601",
    "endDate": "ISO8601?",
    "status": "active|completed|cancelled",
    "photos": [
        {
            "angleType": "front",
            "fileName": "front.jpg",
            "captureDate": "ISO8601",
            "confidenceScore": 0.95,
            "isAutoCaptured": true,
            "fileSize": 2048576,
            "dimensions": {"width": 1920, "height": 1080}
        }
    ]
}
```

## State Transitions

### PhotoSession Status Flow
```
active → completed (all angles captured)
active → cancelled (user cancels session)
```

### VehiclePhoto Capture Flow
```
detecting → captured (ML model detects position)
detecting → manual_capture (user manually triggers)
captured → (final state)
manual_capture → (final state)
```

## Data Validation Rules

### Session Validation
- Vehicle identifier must be unique within user's sessions
- Cannot create new session if user has active session
- Cannot complete session with less than 8 photos
- Cannot cancel completed session

### Photo Validation
- File must exist at specified path
- Image dimensions must be valid (1920x1080 preferred)
- File size must be reasonable (<10MB)
- Confidence score must be from ML model or 0.0 for manual

### User Validation
- Email must be verified through Firebase Auth
- Display name must be 1-50 characters
- Cannot delete user with existing sessions

## Performance Considerations

### Core Data Optimization
- Use NSFetchRequest with predicates for efficient querying
- Implement batch operations for large data sets
- Use NSManagedObjectContext with appropriate concurrency type
- Implement background context for file operations

### File System Optimization
- Use background queue for file I/O operations
- Implement image compression for storage efficiency
- Cache frequently accessed images
- Implement cleanup for old sessions (configurable retention)

### Memory Management
- Release image data after processing
- Use autorelease pools for batch operations
- Monitor memory usage during ML processing
- Implement image downsampling for previews
