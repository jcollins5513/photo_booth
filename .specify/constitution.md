# Constitution v2.1.1 - Automated Vehicle Photo Booth

## Core Principles

### 1. Simplicity First
- **Projects**: Keep to minimum viable projects (1-2 max)
- **Frameworks**: Use frameworks directly, avoid unnecessary abstractions
- **Data Models**: Single, clear data model per domain
- **Patterns**: Avoid over-engineering, prefer direct implementation

### 2. Architecture Guidelines
- **Libraries**: Every feature as a library when possible
- **CLI**: One CLI per library for testing and operations
- **Documentation**: Comprehensive docs for each library
- **Dependencies**: Minimize external dependencies

### 3. Testing (NON-NEGOTIABLE)
- **TDD Cycle**: RED → GREEN → Refactor strictly enforced
- **Test Order**: Contract → Integration → E2E → Unit
- **Real Dependencies**: Use actual dependencies, not mocks
- **Integration Tests**: Required for all new features
- **FORBIDDEN**: Implementation before tests, skipping RED phase

### 4. Observability
- **Structured Logging**: Use OSLog for all logging
- **Error Context**: Comprehensive error information
- **Monitoring**: Performance and error tracking

### 5. Versioning
- **Semantic Versioning**: Clear version numbers
- **Build Increments**: Every change increments build
- **Breaking Changes**: Proper handling and documentation

## Project-Specific Rules

### iOS Development
- **SwiftUI**: Primary UI framework
- **Core Data**: For metadata persistence
- **File System**: For image storage
- **AVFoundation**: For camera functionality
- **Vision Framework**: For ML integration

### Testing Requirements
- **Unit Tests**: All services and ViewModels
- **Integration Tests**: Complete workflows
- **UI Tests**: User interaction flows
- **Contract Tests**: Service interfaces

### Performance Standards
- **Real-time Processing**: 5-10 FPS for vision
- **Photo Capture**: <1 second response time
- **Memory Management**: Efficient image handling
- **Battery Optimization**: Background processing

## Quality Gates

### Before Implementation
- [ ] Constitution check passed
- [ ] All unknowns resolved
- [ ] Test plan created
- [ ] Architecture approved

### During Implementation
- [ ] Tests written first (RED)
- [ ] Implementation makes tests pass (GREEN)
- [ ] Code refactored (REFACTOR)
- [ ] Integration tests passing

### Before Release
- [ ] All tests passing
- [ ] Performance benchmarks met
- [ ] Security review completed
- [ ] Documentation updated

## Violations and Justifications

| Violation | Justification | Alternative Rejected |
|-----------|---------------|---------------------|
| Mobile app architecture | User interface required for camera workflow | CLI insufficient for camera preview |
| Firebase integration | Multi-user authentication needed | Local-only auth insufficient |

## Enforcement

- **Code Reviews**: All changes reviewed against constitution
- **Automated Checks**: CI/CD validates compliance
- **Documentation**: All decisions documented
- **Regular Reviews**: Constitution updated as needed
