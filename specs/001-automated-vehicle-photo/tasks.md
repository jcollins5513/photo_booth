# Tasks: Automated Vehicle Photo Booth

**Input**: Design documents from `/specs/001-automated-vehicle-photo/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → If not found: ERROR "No implementation plan found"
   → Extract: tech stack, libraries, structure
2. Load optional design documents:
   → data-model.md: Extract entities → model tasks
   → contracts/: Each file → contract test task
   → research.md: Extract decisions → setup tasks
3. Generate tasks by category:
   → Setup: project init, dependencies, linting
   → Tests: contract tests, integration tests
   → Core: models, services, CLI commands
   → Integration: DB, middleware, logging
   → Polish: unit tests, performance, docs
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness:
   → All contracts have tests?
   → All entities have models?
   → All endpoints implemented?
9. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Mobile**: `ios/Photo_Booth/`, `api/` (Firebase backend)
- Paths shown below assume mobile app structure per plan.md

## Phase 3.1: Setup
- [ ] T001 Create iOS project structure in ios/Photo_Booth/
- [ ] T002 Initialize Xcode project with SwiftUI, AVFoundation, Vision, CoreML dependencies
- [ ] T003 [P] Configure SwiftLint and code formatting in ios/Photo_Booth/
- [ ] T004 [P] Set up Firebase project and GoogleService-Info.plist in ios/Photo_Booth/
- [ ] T005 [P] Configure Core Data model in ios/Photo_Booth/Resources/CoreDataModel.xcdatamodeld
- [ ] T006 [P] Set up test targets and configurations in ios/Photo_Booth/

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**
- [ ] T007 [P] Contract test CameraServiceProtocol in ios/Photo_Booth/Photo_BoothTests/ContractTests/CameraServiceContractTests.swift
- [ ] T008 [P] Contract test VisionServiceProtocol in ios/Photo_Booth/Photo_BoothTests/ContractTests/VisionServiceContractTests.swift
- [ ] T009 [P] Contract test AuthenticationService in ios/Photo_Booth/Photo_BoothTests/ContractTests/AuthenticationServiceContractTests.swift
- [ ] T010 [P] Integration test photo session workflow in ios/Photo_Booth/Photo_BoothTests/IntegrationTests/PhotoSessionIntegrationTests.swift
- [ ] T011 [P] Integration test camera capture flow in ios/Photo_Booth/Photo_BoothTests/IntegrationTests/CameraIntegrationTests.swift
- [ ] T012 [P] Integration test vision detection flow in ios/Photo_Booth/Photo_BoothTests/IntegrationTests/VisionIntegrationTests.swift
- [ ] T013 [P] Integration test authentication flow in ios/Photo_Booth/Photo_BoothTests/IntegrationTests/AuthenticationIntegrationTests.swift
- [ ] T014 [P] Integration test storage and data persistence in ios/Photo_Booth/Photo_BoothTests/IntegrationTests/StorageIntegrationTests.swift

## Phase 3.3: Core Implementation (ONLY after tests are failing)
- [ ] T015 [P] PhotoSession Core Data entity in ios/Photo_Booth/Models/PhotoSession.swift
- [ ] T016 [P] VehiclePhoto Core Data entity in ios/Photo_Booth/Models/VehiclePhoto.swift
- [ ] T017 [P] UserAccount Core Data entity in ios/Photo_Booth/Models/UserAccount.swift
- [ ] T018 [P] PhotoAngle Core Data entity in ios/Photo_Booth/Models/PhotoAngle.swift
- [ ] T019 [P] CameraService implementation in ios/Photo_Booth/Services/CameraService.swift
- [ ] T020 [P] VisionService implementation in ios/Photo_Booth/Services/VisionService.swift
- [ ] T021 [P] AuthenticationService implementation in ios/Photo_Booth/Services/AuthenticationService.swift
- [ ] T022 [P] StorageService implementation in ios/Photo_Booth/Services/StorageService.swift
- [ ] T023 [P] SessionManager service in ios/Photo_Booth/Services/SessionManager.swift
- [ ] T024 [P] Core Data stack setup in ios/Photo_Booth/Services/CoreDataStack.swift

## Phase 3.4: ViewModels (MVVM Pattern)
- [ ] T025 [P] AuthenticationViewModel in ios/Photo_Booth/ViewModels/AuthenticationViewModel.swift
- [ ] T026 [P] CameraViewModel in ios/Photo_Booth/ViewModels/CameraViewModel.swift
- [ ] T027 [P] SessionViewModel in ios/Photo_Booth/ViewModels/SessionViewModel.swift
- [ ] T028 [P] GalleryViewModel in ios/Photo_Booth/ViewModels/GalleryViewModel.swift
- [ ] T029 [P] DashboardViewModel in ios/Photo_Booth/ViewModels/DashboardViewModel.swift

## Phase 3.5: User Interface (SwiftUI)
- [ ] T030 [P] AuthenticationView in ios/Photo_Booth/Views/Authentication/AuthenticationView.swift
- [ ] T031 [P] DashboardView in ios/Photo_Booth/Views/Dashboard/DashboardView.swift
- [ ] T032 [P] CameraPreviewView in ios/Photo_Booth/Views/Camera/CameraPreviewView.swift
- [ ] T033 [P] SessionView in ios/Photo_Booth/Views/Camera/SessionView.swift
- [ ] T034 [P] PhotoCaptureView in ios/Photo_Booth/Views/Camera/PhotoCaptureView.swift
- [ ] T035 [P] GalleryView in ios/Photo_Booth/Views/Gallery/GalleryView.swift
- [ ] T036 [P] SessionListView in ios/Photo_Booth/Views/Gallery/SessionListView.swift
- [ ] T037 [P] PhotoDetailView in ios/Photo_Booth/Views/Gallery/PhotoDetailView.swift
- [ ] T038 [P] SettingsView in ios/Photo_Booth/Views/Settings/SettingsView.swift

## Phase 3.6: Integration and Navigation
- [ ] T039 [P] App navigation structure in ios/Photo_Booth/App/VehiclePhotoBoothApp.swift
- [ ] T040 [P] Main ContentView with navigation in ios/Photo_Booth/App/ContentView.swift
- [ ] T041 [P] Dependency injection container in ios/Photo_Booth/Utils/DependencyContainer.swift
- [ ] T042 [P] App configuration and constants in ios/Photo_Booth/Utils/Constants.swift
- [ ] T043 [P] Extensions and utilities in ios/Photo_Booth/Utils/Extensions/

## Phase 3.7: CoreML Model Integration
- [ ] T044 [P] Vehicle angle classification model in ios/Photo_Booth/Resources/VehicleAngleClassifier.mlmodel
- [ ] T045 [P] Model loading and management in ios/Photo_Booth/Services/ModelManager.swift
- [ ] T046 [P] Image preprocessing utilities in ios/Photo_Booth/Utils/ImageProcessor.swift
- [ ] T047 [P] Confidence threshold configuration in ios/Photo_Booth/Services/ConfigurationService.swift

## Phase 3.8: File System and Storage
- [ ] T048 [P] File system manager in ios/Photo_Booth/Services/FileSystemManager.swift
- [ ] T049 [P] Image compression and optimization in ios/Photo_Booth/Utils/ImageOptimizer.swift
- [ ] T050 [P] Session metadata management in ios/Photo_Booth/Services/SessionMetadataManager.swift
- [ ] T051 [P] Photo export and sharing utilities in ios/Photo_Booth/Utils/PhotoExporter.swift

## Phase 3.9: Error Handling and Logging
- [ ] T052 [P] Error handling framework in ios/Photo_Booth/Utils/ErrorHandler.swift
- [ ] T053 [P] Structured logging with OSLog in ios/Photo_Booth/Utils/Logger.swift
- [ ] T054 [P] User feedback and notifications in ios/Photo_Booth/Utils/UserFeedback.swift
- [ ] T055 [P] Performance monitoring in ios/Photo_Booth/Utils/PerformanceMonitor.swift

## Phase 3.10: Polish and Optimization
- [ ] T056 [P] Unit tests for ViewModels in ios/Photo_Booth/Photo_BoothTests/UnitTests/ViewModelTests/
- [ ] T057 [P] Unit tests for Services in ios/Photo_Booth/Photo_BoothTests/UnitTests/ServiceTests/
- [ ] T058 [P] Unit tests for Utils in ios/Photo_Booth/Photo_BoothTests/UnitTests/UtilsTests/
- [ ] T059 [P] UI tests for user workflows in ios/Photo_Booth/Photo_BoothTests/UITests/
- [ ] T060 [P] Performance optimization and memory management
- [ ] T061 [P] Accessibility support and VoiceOver compatibility
- [ ] T062 [P] Localization and internationalization setup
- [ ] T063 [P] App Store metadata and screenshots
- [ ] T064 [P] Documentation and code comments
- [ ] T065 [P] Final testing and validation

## Dependencies
- Tests (T007-T014) before implementation (T015-T051)
- Core Data entities (T015-T018) before services (T019-T024)
- Services (T019-T024) before ViewModels (T025-T029)
- ViewModels (T025-T029) before Views (T030-T038)
- Core implementation before integration (T039-T051)
- All implementation before polish (T056-T065)

## Parallel Execution Examples

### Phase 3.1 Setup (Parallel)
```
# Launch T003-T006 together:
Task: "Configure SwiftLint and code formatting in ios/Photo_Booth/"
Task: "Set up Firebase project and GoogleService-Info.plist in ios/Photo_Booth/"
Task: "Configure Core Data model in ios/Photo_Booth/Resources/CoreDataModel.xcdatamodeld"
Task: "Set up test targets and configurations in ios/Photo_Booth/"
```

### Phase 3.2 Contract Tests (Parallel)
```
# Launch T007-T014 together:
Task: "Contract test CameraServiceProtocol in ios/Photo_Booth/Photo_BoothTests/ContractTests/CameraServiceContractTests.swift"
Task: "Contract test VisionServiceProtocol in ios/Photo_Booth/Photo_BoothTests/ContractTests/VisionServiceContractTests.swift"
Task: "Contract test AuthenticationService in ios/Photo_Booth/Photo_BoothTests/ContractTests/AuthenticationServiceContractTests.swift"
Task: "Integration test photo session workflow in ios/Photo_Booth/Photo_BoothTests/IntegrationTests/PhotoSessionIntegrationTests.swift"
Task: "Integration test camera capture flow in ios/Photo_Booth/Photo_BoothTests/IntegrationTests/CameraIntegrationTests.swift"
Task: "Integration test vision detection flow in ios/Photo_Booth/Photo_BoothTests/IntegrationTests/VisionIntegrationTests.swift"
Task: "Integration test authentication flow in ios/Photo_Booth/Photo_BoothTests/IntegrationTests/AuthenticationIntegrationTests.swift"
Task: "Integration test storage and data persistence in ios/Photo_Booth/Photo_BoothTests/IntegrationTests/StorageIntegrationTests.swift"
```

### Phase 3.3 Core Models (Parallel)
```
# Launch T015-T018 together:
Task: "PhotoSession Core Data entity in ios/Photo_Booth/Models/PhotoSession.swift"
Task: "VehiclePhoto Core Data entity in ios/Photo_Booth/Models/VehiclePhoto.swift"
Task: "UserAccount Core Data entity in ios/Photo_Booth/Models/UserAccount.swift"
Task: "PhotoAngle Core Data entity in ios/Photo_Booth/Models/PhotoAngle.swift"
```

### Phase 3.3 Core Services (Parallel)
```
# Launch T019-T024 together:
Task: "CameraService implementation in ios/Photo_Booth/Services/CameraService.swift"
Task: "VisionService implementation in ios/Photo_Booth/Services/VisionService.swift"
Task: "AuthenticationService implementation in ios/Photo_Booth/Services/AuthenticationService.swift"
Task: "StorageService implementation in ios/Photo_Booth/Services/StorageService.swift"
Task: "SessionManager service in ios/Photo_Booth/Services/SessionManager.swift"
Task: "Core Data stack setup in ios/Photo_Booth/Services/CoreDataStack.swift"
```

## Notes
- [P] tasks = different files, no dependencies
- Verify tests fail before implementing
- Commit after each task
- Avoid: vague tasks, same file conflicts
- Follow TDD: Red → Green → Refactor cycle
- Use contract-based testing for all services
- Implement comprehensive error handling
- Optimize for real-time performance

## Task Generation Rules
*Applied during main() execution*

1. **From Contracts**:
   - CameraServiceContract → T007 contract test
   - VisionServiceContract → T008 contract test
   - AuthenticationAPI → T009 contract test
   
2. **From Data Model**:
   - PhotoSession → T015 model task
   - VehiclePhoto → T016 model task
   - UserAccount → T017 model task
   - PhotoAngle → T018 model task
   
3. **From User Stories**:
   - Photo session workflow → T010 integration test
   - Camera capture flow → T011 integration test
   - Vision detection → T012 integration test
   - Authentication → T013 integration test
   - Storage persistence → T014 integration test

4. **Ordering**:
   - Setup → Tests → Models → Services → ViewModels → Views → Integration → Polish
   - Dependencies block parallel execution

## Validation Checklist
*GATE: Checked by main() before returning*

- [x] All contracts have corresponding tests
- [x] All entities have model tasks
- [x] All tests come before implementation
- [x] Parallel tasks truly independent
- [x] Each task specifies exact file path
- [x] No task modifies same file as another [P] task
- [x] TDD approach enforced with failing tests first
- [x] Comprehensive coverage of all requirements
- [x] Proper dependency ordering maintained
