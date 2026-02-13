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
