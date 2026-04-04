# Contributing

## Setup

1. Open [FriSpeak.xcodeproj](/Users/kaushal/workspace/XCode/FriSpeak/FriSpeak.xcodeproj) in Xcode.
2. Use the `FriSpeak` scheme.
3. Make sure Microphone and Accessibility permissions can be granted when running locally.

## Build

```bash
xcodebuild -project FriSpeak.xcodeproj -scheme FriSpeak -configuration Debug -sdk macosx CODE_SIGNING_ALLOWED=NO build
```

## Test

```bash
xcodebuild -project FriSpeak.xcodeproj -scheme FriSpeak -destination 'platform=macOS' test
```

Prompt-harness check:

```bash
python3 FriSpeak/scripts/optimize_intelligence_prompt.py \
  --provider apple \
  --prompt-file FriSpeak/scripts/apple_prompt_candidate.txt
```

## Repo Conventions

- Keep user-visible behavior covered by XCTest where practical.
- When changing prompt behavior, update both:
  - XCTest coverage in [FriSpeakTests](/Users/kaushal/workspace/XCode/FriSpeak/FriSpeakTests)
  - prompt harness cases in [intelligence_prompt_cases.json](/Users/kaushal/workspace/XCode/FriSpeak/FriSpeak/scripts/intelligence_prompt_cases.json)
- Keep the root [README.md](/Users/kaushal/workspace/XCode/FriSpeak/README.md) current when setup or architecture changes.
- Avoid adding generated artifacts or local caches to the repo.

## Pull Requests

- Keep changes scoped.
- Include a short testing note with the commands you ran.
- Call out any model, dependency, or prompt changes explicitly.
