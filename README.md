# FriSpeak

FriSpeak is a macOS push-to-talk dictation app for writing into any focused text field.

It supports:
- local native transcription with Apple Speech
- local generative transcription with Omnilingual ASR 300M Core ML, Omnilingual ASR 1B MLX 4-bit, or Parakeet TDT Core ML
- remote transcription and text processing through OpenRouter
- optional text intelligence with Apple Intelligence, OpenRouter, or a local MLX model

FriSpeak is designed around a simple workflow: hold a hotkey, speak, release, and have the cleaned text inserted into the active app with caret-aware formatting.

## Download

The easiest way to install FriSpeak is from the latest GitHub release:

- Download [FriSpeak.dmg](https://github.com/FriDev/FriSpeak/releases/latest/download/FriSpeak.dmg)
- Open the DMG
- Drag `FriSpeak.app` into `Applications`
- Launch FriSpeak and complete onboarding

## Current Status

The project is usable and builds locally in Xcode. It also includes:
- onboarding for permissions and model setup
- local model download and preload flows
- prompt harnesses for evaluating cleanup and insertion behavior
- XCTest coverage for insertion formatting and intelligence sanitization

This repository currently vendors a Prism MLX fork under `Vendor/mlx-swift` so the local Bonsai 1-bit model can run.

## Features

- Global push-to-talk dictation workflow
- Dictation into arbitrary macOS apps through Accessibility APIs
- Three speech pipelines:
  - `Apple Native`
  - `Local Generative` using Omnilingual ASR 300M Core ML or Parakeet TDT Core ML on the Neural Engine, or Omnilingual ASR 1B MLX 4-bit on the Metal GPU
  - `Remote` using OpenRouter
- Three intelligence backends:
  - `Apple Intelligence`
  - `Local MLX` using `prism-ml/Bonsai-8B-mlx-1bit`
  - `Remote` using OpenRouter
- Cursor-aware insertion adaptation
- Clipboard-safe text insertion
- Dictation history with diagnostics
- Prompt harnesses for evaluating cleanup and insertion edge cases

## Requirements

- macOS 14 or later
- Xcode 16 or later
- Apple Silicon Mac recommended for local model performance
- Microphone permission
- Accessibility permission

For local MLX builds, the repo already includes the vendored Prism MLX fork used by the project.

## Quick Start

1. Open [FriSpeak.xcodeproj](/Users/kaushal/workspace/XCode/FriSpeak/FriSpeak.xcodeproj).
2. Build and run the `FriSpeak` scheme.
3. Grant Microphone and Accessibility permissions during onboarding.
4. Choose a speech model.
5. Optionally configure an intelligence backend and prompt.
6. Hold the configured hotkey, speak, and release to insert text.

## Project Layout

- [FriSpeak](/Users/kaushal/workspace/XCode/FriSpeak/FriSpeak): app source
- [FriSpeakTests](/Users/kaushal/workspace/XCode/FriSpeak/FriSpeakTests): XCTest coverage for formatting and intelligence behavior
- [FriSpeak/scripts](/Users/kaushal/workspace/XCode/FriSpeak/FriSpeak/scripts): prompt harnesses and helper scripts
- [Vendor/mlx-swift](/Users/kaushal/workspace/XCode/FriSpeak/Vendor/mlx-swift): vendored Prism MLX fork for local 1-bit Bonsai support

## Building

Debug build:

```bash
xcodebuild -project FriSpeak.xcodeproj -scheme FriSpeak -configuration Debug -sdk macosx CODE_SIGNING_ALLOWED=NO build
```

Run tests:

```bash
xcodebuild -project FriSpeak.xcodeproj -scheme FriSpeak -destination 'platform=macOS' test
```

## Testing

The repo currently has two main test layers:

1. XCTest unit coverage in [FriSpeakTests](/Users/kaushal/workspace/XCode/FriSpeak/FriSpeakTests)
   - caret-aware insertion formatting
   - intelligence output sanitization
   - local MLX token budgeting
2. Prompt harnesses in [FriSpeak/scripts](/Users/kaushal/workspace/XCode/FriSpeak/FriSpeak/scripts)
   - model cleanup behavior
   - insertion adaptation edge cases

Run the prompt harness:

```bash
python3 FriSpeak/scripts/optimize_intelligence_prompt.py \
  --provider apple \
  --prompt-file FriSpeak/scripts/apple_prompt_candidate.txt
```

## OpenRouter Setup

OpenRouter is optional. If you want remote speech or remote intelligence:

1. Create an API key at `https://openrouter.ai/`
2. Open FriSpeak configuration
3. Enter the API key
4. Select a remote model

Remote speech is automatically enabled when the selected model supports audio input.

## Known Constraints

- The local speech model paths are heavier than Apple native dictation. The 300M Core ML and Parakeet TDT Core ML options target the Neural Engine; the 1B MLX 4-bit option targets the Metal GPU and uses more unified memory.
- The vendored Prism MLX fork is intentional and currently required for `prism-ml/Bonsai-8B-mlx-1bit`.
- Apple Intelligence prompt-following is useful but still less reliable than deterministic formatting for some caret-boundary cases, so FriSpeak includes local post-processing guards.

## Contributing

See [CONTRIBUTING.md](/Users/kaushal/workspace/XCode/FriSpeak/CONTRIBUTING.md).

## License

Apache License 2.0. See [LICENSE](/Users/kaushal/workspace/XCode/FriSpeak/LICENSE).
