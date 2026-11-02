# HAWK — DEVELOPMENT GUIDE

**Target Audience:** iOS Engineers, Audio Systems Engineers, QA Engineers  
**Toolchain:** Swift 6.4.2+, SwiftPM, Xcode 16+  
**Target Environment:** macOS on Apple Silicon (M-series)  

---

## 1. Quick Start

### Building Core Packages via SwiftPM
You can build and test all business logic, audio state machines, lyrics parsers, and data models directly using SwiftPM:

```bash
cd HAWK
swift build
swift test
```

### Xcode App Workflow
When building for the iOS Simulator or physical iPhone 12:
1. Open the project in Xcode (or generate using `./Scripts/generate_project.sh`).
2. Select target `HAWK` and destination `iPhone 12` (or iOS Simulator).
3. Build and Run (`⌘R`).

---

## 2. Coding Guidelines

1. **Swift Concurrency:** All asynchronous operations must use `async/await`. Shared mutable state must be encapsulated within `actor` types. Avoid `@unchecked Sendable` unless backed by rigorous locks.
2. **Apple HIG:** All views must adhere to Apple Human Interface Guidelines. Always support Dynamic Type, Dark/Light modes, and VoiceOver accessibility labels.
3. **Audio Stability:** Do not block audio actor threads with network I/O or file writes. Always decode or fetch streams asynchronously before cueing audio.
4. **Security & Privacy:** Never log raw authentication cookies, tokens, or personal identifiers. Always use the `KeychainStore` for secrets.
