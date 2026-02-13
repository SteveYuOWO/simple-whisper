# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Simple Whisper is a native macOS app for speech-to-text transcription using OpenAI's Whisper model. Built with SwiftUI + AppKit. Currently in early development — the UI and state management are implemented with mock simulation, but actual audio recording and Whisper inference are not yet integrated.

## Build & Run

The Xcode project lives in `SimpleWhisper/`. All xcodebuild commands should run from that directory.

```bash
# Build
xcodebuild build -scheme SimpleWhisper -configuration Debug -project SimpleWhisper/SimpleWhisper.xcodeproj

# Run tests
xcodebuild test -scheme SimpleWhisper -project SimpleWhisper/SimpleWhisper.xcodeproj

# Open in Xcode
open SimpleWhisper/SimpleWhisper.xcodeproj
```

No external dependencies (SPM, CocoaPods, or Carthage). No linter configured.

## Architecture

**Entry point:** `SimpleWhisper/SimpleWhisper/SimpleWhisperApp.swift` — `@main` SwiftUI App with a single Settings window.

**State management:** `AppState` (`Models/AppState.swift`) is an `@Observable` singleton passed via SwiftUI environment. It manages:
- Transcription state machine: `idle → recording → processing → done → idle`
- User settings (language, model, microphone, hotkey, feature toggles)
- `simulateFullCycle()` provides a mock demo flow with timers

**Three UI surfaces:**
1. **SettingsView** — Main window with sidebar navigation (General / Model / Input tabs). Reusable row components in `Views/Settings/`.
2. **PopoverView** — State-driven popover with sub-views per transcription state (`Views/Popover/`): IdleView, RecordingView, ProcessingView, DoneView.
3. **FloatingPillView** — Compact floating NSPanel overlay (`FloatingPanelController`) showing transcription status as a pill indicator.

**Localization:** Dual-language (English/Chinese) via `AppLanguage` enum in `Models/Strings.swift`. All strings are hardcoded in Swift — no `.strings` files.

**Theming:** `Theme.swift` defines a `Theme` struct with light/dark color sets and a `DS` enum for design constants (spacing, corner radii, sizing).

## Key Conventions

- Views access state via `@Environment(AppState.self)` and use `@Bindable` for two-way binding
- `FloatingPanelController` uses NSPanel (AppKit) for the always-on-top floating overlay
- Design file at `design/simple-whisper.pen` — use Pencil MCP tools only (not Read/Grep)
- `scripts/generate_appicon.swift` generates all macOS icon sizes from code

## Design Workflow

- **Design first**: All UI changes must be designed on Pencil (`.pen` file) before implementing Swift code
- **Design → Code sync**: When the .pen design is updated, the corresponding SwiftUI code must be updated to match. Spawn a sub-agent to update the code in parallel if the change is clear.
- **Code → Design sync**: When making small SwiftUI tweaks (styling, layout, copy changes), immediately sync those changes back to the .pen design file.
- **Bidirectional rule**: At the end of any UI task, both the .pen file and Swift code must reflect the same state. If either is out of date, update it before considering the task done.
- Design file: `design/simple-whisper.pen`

## Agent Orchestration

When a task involves multiple independent layers (design, SwiftUI views, models, localization), maximize parallelism by spawning sub-agents concurrently:

- **Design + Code in parallel**: If the .pen design already exists, launch SwiftUI implementation agents simultaneously. If designing from scratch, design first, then parallelize code implementation.
- **Research in parallel**: When exploring unfamiliar areas, spawn multiple Explore agents to investigate different parts of the codebase simultaneously.
- **Localization in parallel**: `Strings.swift` updates (en + zh) can run in parallel with view/model changes.
- **Build + Validate**: After code changes, run `xcodebuild build` to verify compilation.

### Parallelism Rules
1. **Always** send independent sub-agent calls in a single message (multiple Task tool blocks) — never sequentially when they don't depend on each other.
2. **Design updates** can run in parallel with code changes if the design intent is already clear.
3. **Model + View** changes can be parallel if the model interface is defined first.

### Anti-patterns
- Do NOT spawn a sub-agent for a task you can do in 1-2 tool calls yourself.
- Do NOT duplicate work — if you delegate research to a sub-agent, don't also search for the same thing.
- Do NOT parallelize tasks with hard dependencies (e.g., View code before the Model it depends on exists).
