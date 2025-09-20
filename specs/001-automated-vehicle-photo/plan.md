# Implementation Plan: Automated Vehicle Photo Booth

**Branch**: `001-automated-vehicle-photo` | **Date**: 2024-12-19 | **Spec**: [link]
**Input**: Feature specification from `/specs/001-automated-vehicle-photo/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
4. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
5. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, or `GEMINI.md` for Gemini CLI).
6. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
7. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
8. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
iOS application for automated vehicle photography using computer vision to detect vehicle positions and automatically capture photos from multiple angles. The system guides users through a predetermined sequence of photo angles while using on-device ML models to detect when the vehicle is correctly positioned for each shot.

## Technical Context
**Language/Version**: Swift 5.9, iOS 26.0+  
**Primary Dependencies**: SwiftUI, AVFoundation, Vision, CoreML, Firebase Auth SDK  
**Storage**: Local file storage (Documents directory), Core Data for metadata, Firebase for authentication  
**Testing**: XCTest, XCUITest for UI testing  
**Target Platform**: iOS 26.0+ (iPhone 17), optimized for Neural Engine acceleration  
**Project Type**: mobile (iOS app with optional backend integration)  
**Performance Goals**: Real-time vision processing at 5-10 FPS, photo capture within 1 second of position detection  
**Constraints**: Offline-capable core functionality, <10 minute complete photo sessions, local storage only for photos  
**Scale/Scope**: Single-user application, 8 photo angles per session, support for hundreds of vehicle sessions  

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Simplicity**:
- Projects: [2] (ios app, optional api backend)
- Using framework directly? (Yes - SwiftUI, AVFoundation, Vision directly)
- Single data model? (Yes - Core Data for metadata, file system for photos)
- Avoiding patterns? (Yes - direct AVFoundation usage, no unnecessary abstractions)

**Architecture**:
- EVERY feature as library? (No - this is a mobile app, not a library system)
- Libraries listed: [N/A - mobile app architecture]
- CLI per library: [N/A - mobile app with UI]
- Library docs: [N/A - mobile app documentation]

**Testing (NON-NEGOTIABLE)**:
- RED-GREEN-Refactor cycle enforced? (Yes - tests written first)
- Git commits show tests before implementation? (Yes - TDD approach)
- Order: Contract→Integration→E2E→Unit strictly followed? (Yes)
- Real dependencies used? (Yes - actual camera, Core Data, file system)
- Integration tests for: new features, data persistence, camera functionality
- FORBIDDEN: Implementation before test, skipping RED phase

**Observability**:
- Structured logging included? (Yes - OSLog for debugging)
- Frontend logs → backend? (No - local logging only)
- Error context sufficient? (Yes - comprehensive error handling)

**Versioning**:
- Version number assigned? (Yes - 1.0.0)
- BUILD increments on every change? (Yes - Xcode build system)
- Breaking changes handled? (Yes - semantic versioning)

## Project Structure

### Documentation (this feature)
```
specs/001-automated-vehicle-photo/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
# Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [Firebase backend configuration]

ios/
├── Photo_Booth/
│   ├── Photo_Booth.xcodeproj
│   ├── Photo_Booth/
│   │   ├── App/
│   │   │   ├── Photo_BoothApp.swift
│   │   │   └── ContentView.swift
│   │   ├── Models/
│   │   │   ├── PhotoSession.swift
│   │   │   ├── VehiclePhoto.swift
│   │   │   ├── UserAccount.swift
│   │   │   └── PhotoAngle.swift
│   │   ├── Views/
│   │   │   ├── Authentication/
│   │   │   ├── Dashboard/
│   │   │   ├── Camera/
│   │   │   └── Gallery/
│   │   ├── ViewModels/
│   │   │   ├── AuthenticationViewModel.swift
│   │   │   ├── CameraViewModel.swift
│   │   │   └── SessionViewModel.swift
│   │   ├── Services/
│   │   │   ├── CameraService.swift
│   │   │   ├── VisionService.swift
│   │   │   ├── AuthenticationService.swift
│   │   │   └── StorageService.swift
│   │   ├── Resources/
│   │   │   ├── Assets.xcassets
│   │   │   ├── Info.plist
│   │   │   └── CoreDataModel.xcdatamodeld
│   │   └── Utils/
│   │       ├── Extensions/
│   │       └── Constants.swift
│   └── Photo_BoothTests/
│       ├── UnitTests/
│       ├── IntegrationTests/
│       └── UITests/
```

**Structure Decision**: Option 3 - Mobile + API (iOS app with Firebase backend)

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - CoreML model training approach and data requirements
   - Firebase Auth integration patterns for iOS
   - AVFoundation camera setup and permissions handling
   - Vision framework integration with CoreML models
   - Local storage architecture and Core Data schema design

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research CoreML model training for vehicle angle classification"
     Task: "Research Firebase Auth SDK integration patterns for iOS"
     Task: "Research AVFoundation camera setup and real-time capture"
     Task: "Research Vision framework with CoreML for real-time classification"
     Task: "Research local storage patterns and Core Data schema design"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas
   - Tests must fail (no implementation yet)

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `/scripts/bash/update-agent-context.sh cursor` for your AI assistant
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Load `/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (contracts, data model, quickstart)
- Each contract → contract test task [P]
- Each entity → model creation task [P] 
- Each user story → integration test task
- Implementation tasks to make tests pass

**Ordering Strategy**:
- TDD order: Tests before implementation 
- Dependency order: Models before services before UI
- Mark [P] for parallel execution (independent files)

**Estimated Output**: 25-30 numbered, ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Mobile app architecture | User interface required for vehicle photography workflow | CLI-only insufficient for camera preview and user guidance |
| Firebase integration | User authentication requirement | Local-only auth insufficient for multi-user scenarios |

## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [x] Phase 3: Tasks generated (/tasks command)
- [x] Phase 4: Core Implementation complete (TDD Phase 2 - Services & Tests)
- [x] Phase 4: UI Integration complete (ViewModels, Views, Navigation)
- [ ] Phase 4: Camera Integration (Real camera preview and controls)
- [ ] Phase 4: Polish and Optimization (Animations, Performance)
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented

---
*Based on Constitution v2.1.1 - See `/memory/constitution.md`*