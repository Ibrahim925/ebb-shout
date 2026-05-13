# Ebb Shout — Design Spec

**Date:** 2026-05-11  
**Status:** Approved

---

## Context

Ebb Shout is a macOS menubar app that lets users dictate text into any focused application using their voice. It is a fully local, open-source alternative to Wispr Flow. Speech recognition uses [ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp), while text enhancement and user profiling remain local via a locally-running Ollama instance and files on disk.

The name "Ebb Shout" is a deliberate inversion of "Wispr Flow."

---

## Stack

| Concern | Choice |
|---|---|
| Platform | macOS only |
| Language | Swift + SwiftUI |
| Speech-to-text | whisper.cpp `whisper-cli` |
| Text enhancement | Ollama Gemma (default: `gemma4:latest`) |
| Inference runtime | Ollama (`http://localhost:11434`) |
| Persistence | UserDefaults (settings) + JSON files in `~/Library/Application Support/EbbShout/` |

---

## Architecture

Actor-based concurrent pipeline. Each stage is a Swift `actor`, communicating via async/await. A shared `AppState` (`@Observable`) carries pipeline state and drives the HUD reactively.

```
HotKeyManager
    │  (hotkey event)
    ▼
AudioCaptureActor        ← AVAudioEngine → temp WAV file
    │  (audio file path)
    ▼
TranscriptionActor       ← whisper.cpp `whisper-cli` → raw transcript
    │  (raw string)       ← injects UserProfileManager.vocabularyHint as initial_prompt
    ▼
EnhancementActor         ← OllamaClient (Gemma) → polished text
    │  (polished string)  ← injects mode system prompt + UserProfileManager.styleContext
    ▼
InjectionActor           ← AXUIElement → focused app
    │
    ▼
UserProfileManager.recordRun(words, mode)
```

`OllamaClient` is a URLSession-based HTTP client used for local text enhancement. `TranscriptionActor` invokes a local `whisper-cli` executable configured in Settings.

---

## File Structure

```
EbbShout/
  App/
    EbbShoutApp.swift          # Entry point, menu bar setup, Settings scene
    AppState.swift             # @Observable shared pipeline state
  Actors/
    AudioCaptureActor.swift    # AVAudioEngine, buffers to temp WAV, deletes on done
    TranscriptionActor.swift   # Calls whisper.cpp whisper-cli with audio + vocab hint
    EnhancementActor.swift     # Calls OllamaClient with transcript + mode + style context
    InjectionActor.swift       # AXUIElement text injection into focused app
  Services/
    OllamaClient.swift         # URLSession HTTP client for localhost:11434
    HotKeyManager.swift        # CGEvent tap for global hotkeys
    UserProfileManager.swift   # Loads/saves profile.json, derives vocab + style context
    MetricsManager.swift       # Loads/saves metrics.json, computes stats
  UI/
    MenuBarController.swift    # NSStatusItem, SF Symbol state cycling
    HUDView.swift              # NSPanel pill HUD, hover-expand animation
    SettingsView.swift         # SwiftUI Settings scene
    MetricsView.swift          # Stats window
  Models/
    RecordingMode.swift        # enum: casual, regular, formal
    PipelineStage.swift        # enum: idle, recording, transcribing, enhancing, done
    UserProfile.swift          # Codable: vocab, perModeStyle, wordFrequency
    Metrics.swift              # Codable: totalWords, totalSeconds, dailyActivity, streak
```

---

## Activation

| Gesture | Behaviour |
|---|---|
| Short tap (`⌥Space`) | Toggle — press to start, press again to stop |
| Hold (`⌥Space`) | Hold-to-record — release ends recording |

`HotKeyManager` uses a `CGEvent` tap registered at session creation. Default hotkey is `⌥Space`; user-configurable in Settings.

---

## Modes

Three modes, selected via the HUD (hover to expand) or Settings. Mode is persisted in UserDefaults.

| Mode | Gemma behaviour |
|---|---|
| **Casual** | Lowercase, minimal punctuation, contractions kept, filler words stripped |
| **Regular** | Proper capitalisation, light punctuation, natural sentence flow, filler words stripped |
| **Formal** | Full punctuation, structured sentences, professional tone, intelligently restructured |

Each mode maps to a distinct Gemma system prompt. The `UserProfileManager` appends a 2–3 sentence learned style note to each prompt after sufficient usage history.

---

## HUD

- **Component:** `NSPanel` with `.nonactivatingPanel` + `.hudWindow` style — never steals focus.
- **Position:** Bottom-centre of the main screen, above the Dock.
- **Default (compact):** Frosted-glass pill — waveform bars + status label + current mode name (muted).
- **Hover (expanded):** Pill grows vertically to reveal three mode chips (Casual / Regular / Formal). Clicking a chip switches mode immediately, even mid-recording.
- **Pipeline state colours:**
  - Recording → red waveform
  - Transcribing → yellow spinner
  - Enhancing → purple spinner
  - Done → green checkmark, fades out after 1.5 s
  - Idle → hidden

---

## Text Injection

`InjectionActor` uses `AXUIElementCreateSystemWide()` to get the focused UI element, then sets its value or simulates typed characters via the Accessibility API. Requires Accessibility permission (guided on first launch). Does not touch the clipboard.

---

## Adaptive Memory (`UserProfileManager`)

Stored at `~/Library/Application Support/EbbShout/profile.json`.

**Vocabulary learning:**
- After each run, all words in the raw transcript are added to a frequency map.
- Words appearing ≥ 5 times that aren't in a common English word list are surfaced as candidate custom vocabulary.
- Confirmed vocab words are injected into Whisper as `initial_prompt` on the next run.
- User can manually add/remove words in Settings → Dictionary.

**Style learning:**
- After every 20 runs per mode, the last 20 enhanced outputs for that mode are sent to Gemma with the prompt: *"Summarise the writing style of these samples in 2–3 sentences."*
- The resulting summary is saved as `perModeStyle[mode]` and prepended to that mode's system prompt on future runs.
- Style summary is regenerated every 20 runs thereafter.

---

## Metrics (`MetricsManager`)

Stored at `~/Library/Application Support/EbbShout/metrics.json`.

**Tracked:**
- Total words injected (cumulative)
- Total recording seconds (for speed calculation)
- Daily activity map (date → word count, for heatmap)
- Current and longest streak (consecutive days with ≥ 1 session)

**Derived on display:**
- **Time saved** = `totalWords / 130 - totalWords / 40` (speaking vs avg typing speed in minutes)
- **Avg dictation speed** = `totalWords / totalRecordingMinutes` wpm
- **Activity heatmap** = last 12 weeks of daily activity
- **Streak** = consecutive days ending today with ≥ 1 session

**Metrics window** (`MetricsView.swift`) is opened from the menu bar. Displays:
1. Words dictated (hero)
2. Time saved (hero, purple)
3. Current streak with 🔥
4. Avg dictation speed with ⚡
5. 12-week activity heatmap
6. Personal dictionary count + word chip preview

---

## Settings

SwiftUI `Settings` scene (appears at `Ebb Shout → Settings…`). Sections:

- **General:** Launch at login, default mode
- **Hotkey:** Configurable key combo (recorder UI)
- **Models:** Ollama server URL, Whisper model name, Gemma model name
- **Dictionary:** List of custom vocabulary words; add/remove manually
- **Privacy:** Button to wipe `profile.json` and `metrics.json`

---

## Permissions & Onboarding

First-launch window walks through:
1. Check Ollama is running at configured URL
2. Confirm `whisper-cli` and a GGML model file are configured
3. Pull Gemma model if not present (`ollama pull gemma4:latest`)
4. Request Microphone permission
5. Guide user to System Settings → Privacy → Accessibility to grant access

---

## Privacy

- Audio is captured to a temp file in `FileManager.default.temporaryDirectory`, transcribed locally, then deleted immediately after `TranscriptionActor` finishes.
- No telemetry, no analytics, and no external API calls. Text enhancement requests go to `localhost:11434` by default.
- All persistent data (`profile.json`, `metrics.json`) is local and user-deletable from Settings.

---

## Open Source

**License:** MIT — permissive, contributor-friendly, standard for macOS open source tools.

**Repository structure:**
```
.
├── EbbShout/                  # Xcode project source
├── docs/
│   └── superpowers/specs/     # Design docs
├── .github/
│   └── workflows/
│       └── ci.yml             # GitHub Actions: build check on every PR
├── .gitignore                 # Xcode, macOS, SPM standard ignores
├── LICENSE                    # MIT
├── README.md                  # Setup, prerequisites, build instructions
└── CONTRIBUTING.md            # PR guidelines, code style, issue templates
```

**README must include:**
- What Ebb Shout is and why it exists
- Prerequisites: macOS 14+, Xcode 15+, Ollama installed
- Setup: `ollama pull gemma4:latest`, build whisper.cpp, and download a GGML model with `models/download-ggml-model.sh`
- Build & run instructions (Xcode and `xcodebuild`)
- Link to the design spec

**CONTRIBUTING must include:**
- How to file a bug (include macOS version, Ollama version, steps to reproduce)
- How to propose a feature (open an issue first, discuss before PRing)
- Code style: SwiftFormat with default rules, no force unwraps, actors for shared mutable state
- PR checklist: builds cleanly, no new warnings, manually tested the changed flow

**`.github/workflows/ci.yml`:** Runs `xcodebuild build` on every push and PR targeting `main`. No test runner required for v1 — build success is the gate.

---

## Design Language

Ebb Shout uses a minimal, serif-first aesthetic inspired by Notion — unhurried, editorial, high whitespace.

**Typography:**
- **New York** (Apple's built-in serif, similar character to Times New Roman) for all window headings, metric hero numbers, and onboarding copy
- **SF Pro** for UI labels, captions, and HUD status text (legibility at small sizes)

**Colours (both light and dark mode supported):**
- Backgrounds: system materials (`NSVisualEffectView` / `.regularMaterial`) — adapts automatically
- Accent: single muted purple (`#7B61FF`) used sparingly for the "time saved" hero and active HUD state
- All other text: system label colours — no hardcoded greys

**Windows (Settings, Metrics, Onboarding):**
- Fixed-width, centred content column (max 560 pt)
- Generous vertical padding between sections (24–32 pt)
- Dividers instead of card borders where possible — flat, not skeuomorphic
- No gradients, no drop shadows on window content (the OS handles window chrome)

**HUD:**
- Frosted glass (`NSVisualEffectView`, `.hudWindow` material) — blends into any background
- New York for the mode name label; SF Pro for the status label
- Waveform bars use the muted red during recording only — all other states use monochrome

**Icons:**
- SF Symbols throughout — no custom icon assets except the app icon
- App icon: simple wordmark or abstract microphone mark, monochrome, works at all sizes

---

## Verification

1. **Build & launch:** Xcode → Run. Menu bar icon appears.
2. **Hotkey:** Press `⌥Space`, speak a sentence, release. Text appears in focused app.
3. **Hold-to-record:** Hold `⌥Space`, speak, release. Same result.
4. **HUD states:** Observe pill transitions through Recording → Transcribing → Enhancing → Done → hidden.
5. **Hover expand:** Hover over pill during recording; mode chips appear. Click to switch mode.
6. **Modes:** Dictate the same sentence in Casual vs Formal; verify Gemma output differs appropriately.
7. **Adaptive memory:** After 5+ uses of an unusual word, verify it appears in Settings → Dictionary.
8. **Metrics:** Open metrics window; verify word count increments after each session.
9. **Accessibility:** Revoke Accessibility permission; verify graceful error shown rather than crash.
10. **Ollama down:** Stop Ollama; verify HUD shows an error state instead of hanging.
