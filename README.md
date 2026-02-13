# Simple Whisper

A native macOS speech-to-text app powered by [WhisperKit](https://github.com/argmaxinc/WhisperKit). Press a hotkey, speak, and the transcription is typed directly into any text field.

## Requirements

- macOS 14.0+
- Apple Silicon (recommended) or Intel Mac
- Microphone permission
- Accessibility permission (for global hotkey and auto-type)

## Build

```bash
xcodebuild build -scheme SimpleWhisper -configuration Debug \
  -project SimpleWhisper/SimpleWhisper.xcodeproj
```

Or open in Xcode:

```bash
open SimpleWhisper/SimpleWhisper.xcodeproj
```

No external dependency managers needed — WhisperKit is included via Swift Package Manager.

## Usage

1. **Launch the app** — The Settings window opens. Go to the **Model** tab and download a Whisper model (Base is recommended for most users).
2. **Grant permissions** — Allow Microphone and Accessibility access when prompted.
3. **Start transcribing** — Hold `Fn+Control` (or your custom hotkey), speak, then release. The transcription is typed at your cursor.

### Optional: AI Enhancement

Enable **AI Enhance** in settings to clean up transcriptions with an LLM. Requires an OpenAI or Anthropic API key.

## Architecture

```
SimpleWhisper/
├── Models/          # AppState (Observable), enums, localization strings
├── Services/        # Audio recording, Whisper inference, LLM, hotkey, config
├── Views/           # SwiftUI settings, popover states, floating pill
└── Theme/           # Design tokens (colors, spacing, sizing)
```

Key design decisions:

- **SwiftUI + AppKit hybrid** — SwiftUI for views, `NSPanel` for the always-on-top floating pill.
- **Observable singleton** — `AppState` drives the entire UI via Swift Observation.
- **Actor-isolated inference** — `WhisperService` runs transcription off the main thread.
- **No external assets** — Sound effects are synthesized in-memory; icons use SF Symbols.
- **Persistent config** — Settings and history stored at `~/.simple-whisper/`.

## License

MIT
