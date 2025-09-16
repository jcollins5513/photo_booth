# Quickstart Guide: Automated Vehicle Photo Booth

**Date**: 2024-12-19  
**Phase**: 1 - Design  
**Status**: Complete

## Overview

This guide provides step-by-step instructions for setting up and using the Automated Vehicle Photo Booth system. The system automatically captures vehicle photos from multiple angles using computer vision technology.

## Prerequisites

### Hardware Requirements
- iPhone with iOS 16.0 or later
- iPhone with Neural Engine (A12 Bionic or later for optimal performance)
- Camera mount or tripod for stable iPhone positioning
- Adequate lighting for vehicle photography
- Space for vehicle positioning (minimum 20x30 feet)

### Software Requirements
- Vehicle Photo Booth app installed
- Camera permissions granted
- User account created and authenticated

## Installation and Setup

### 1. App Installation
```bash
# Install from App Store (when available)
# Or install from development build
```

### 2. Initial Setup
1. **Launch the app** and grant camera permissions when prompted
2. **Create account** using email and password
3. **Sign in** to access the main dashboard
4. **Configure preferences** (optional):
   - Photo quality settings
   - Confidence thresholds
   - Storage preferences

### 3. Camera Mount Setup
1. **Position iPhone** at eye level, 15-20 feet from vehicle area
2. **Ensure stable mount** to prevent camera movement
3. **Frame the area** where vehicle will be positioned
4. **Test camera preview** to verify proper framing

## User Workflow

### Starting a Photo Session

#### Step 1: Create New Session
1. **Tap "New Session"** on the main dashboard
2. **Enter vehicle identifier**:
   - Vehicle name (e.g., "2023 Honda Civic")
   - Stock number (e.g., "STK12345")
   - VIN (e.g., "1HGCV1F3XLA123456")
3. **Add optional notes** (e.g., "Front bumper damage")
4. **Tap "Start Session"**

#### Step 2: Position Vehicle
1. **Review target positions** displayed on screen
2. **Drive vehicle** to first position (Front Driver 3/4 view)
3. **Wait for detection** - app will show "Positioning..." status
4. **Hold position** when "Capturing..." appears
5. **Listen for capture sound** and visual confirmation

#### Step 3: Complete Photo Sequence
Repeat for all 8 angles:
1. **Front Driver 3/4** (45° from front)
2. **Front View** (straight on)
3. **Front Passenger 3/4** (-45° from front)
4. **Side View** (90° from front)
5. **Rear Passenger 3/4** (-135° from front)
6. **Rear View** (180° from front)
7. **Rear Driver 3/4** (135° from front)
8. **Opposite Side** (270° from front)

#### Step 4: Review and Complete
1. **Review captured photos** in session summary
2. **Retake any photos** if needed (tap photo to retake)
3. **Tap "Complete Session"** to save all photos
4. **View in Gallery** or start new session

## Testing Scenarios

### Acceptance Test 1: Full Photo Session
**Objective**: Verify complete photo session workflow

**Steps**:
1. Launch app and authenticate
2. Create new session for test vehicle
3. Follow on-screen instructions for all 8 angles
4. Verify each photo is captured automatically
5. Complete session and review photos

**Expected Results**:
- All 8 photos captured successfully
- Photos show correct vehicle angles
- Session completed in under 10 minutes
- Photos saved in organized folder structure

### Acceptance Test 2: Vision Detection Accuracy
**Objective**: Verify automatic position detection

**Steps**:
1. Start photo session
2. Position vehicle at each target angle
3. Observe detection confidence scores
4. Verify auto-capture triggers within 1 second
5. Test with slightly off-angle positions

**Expected Results**:
- Detection confidence >0.8 for correct positions
- Auto-capture triggers within 1 second
- No false captures for incorrect positions
- Visual feedback provided for positioning

### Acceptance Test 3: Error Handling
**Objective**: Verify graceful error handling

**Steps**:
1. Test with poor lighting conditions
2. Test with partial vehicle obstruction
3. Test camera permission denial
4. Test app backgrounding during session
5. Test network connectivity issues

**Expected Results**:
- Appropriate error messages displayed
- Fallback to manual capture when needed
- Session state preserved during interruptions
- Graceful degradation of functionality

### Acceptance Test 4: Data Management
**Objective**: Verify photo storage and organization

**Steps**:
1. Complete multiple photo sessions
2. Verify each session creates separate folder
3. Check photo file naming and metadata
4. Test photo viewing in gallery
5. Test session history and management

**Expected Results**:
- Each session creates unique folder
- Photos named with angle type and timestamp
- Metadata correctly stored in Core Data
- Gallery displays organized photo sets
- Session history accessible and searchable

## Troubleshooting

### Common Issues

#### Camera Not Detecting Vehicle
**Symptoms**: App shows "Positioning..." but never captures
**Solutions**:
- Ensure adequate lighting
- Check camera lens cleanliness
- Verify vehicle is fully in frame
- Try manual capture button
- Restart camera session

#### Poor Photo Quality
**Symptoms**: Photos appear blurry or dark
**Solutions**:
- Check lighting conditions
- Verify camera focus settings
- Ensure vehicle is stationary
- Clean camera lens
- Adjust photo quality settings

#### App Crashes During Session
**Symptoms**: App closes unexpectedly
**Solutions**:
- Restart app and resume session
- Check available storage space
- Close other apps to free memory
- Update to latest app version
- Contact support if persistent

#### Slow Performance
**Symptoms**: Delayed detection or capture
**Solutions**:
- Close background apps
- Ensure device has adequate battery
- Check for iOS updates
- Restart device
- Verify Neural Engine compatibility

### Performance Optimization

#### For Best Results
- Use iPhone with Neural Engine (A12 or later)
- Ensure adequate lighting (natural light preferred)
- Keep camera mount stable and secure
- Close unnecessary apps before starting session
- Use device while connected to power for long sessions

#### Storage Management
- Regularly review and delete old sessions
- Export important photos to Photos app
- Monitor available storage space
- Use cloud backup if available
- Archive completed sessions

## Advanced Features

### Manual Capture Mode
- Tap manual capture button if auto-detection fails
- Useful for challenging lighting or positioning
- Maintains session flow and organization

### Session Resume
- App automatically saves session progress
- Resume interrupted sessions
- Continue from last captured angle

### Photo Export
- Export individual photos to Photos app
- Share photos via AirDrop or Messages
- Export entire session as ZIP file
- Generate photo reports with metadata

### Settings Customization
- Adjust confidence thresholds
- Modify photo quality settings
- Configure auto-capture timing
- Set storage preferences
- Customize user interface

## Support and Resources

### Getting Help
- Check troubleshooting section above
- Review app documentation
- Contact support via in-app feedback
- Submit bug reports with session details

### Best Practices
- Practice with test vehicle before important sessions
- Maintain consistent lighting conditions
- Keep camera mount position consistent
- Regularly clean camera lens
- Backup important photo sessions

### System Requirements
- iOS 16.0 or later
- iPhone with Neural Engine recommended
- 2GB available storage minimum
- Camera permissions required
- Internet connection for authentication only

---

**Version**: 1.0.0  
**Last Updated**: 2024-12-19  
**Next Review**: 2024-12-26
