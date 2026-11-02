# Contributing to macSlider

Thanks for helping. This page covers setup, tests, and what a reviewable pull request looks like.

## Setup

1. Install Xcode 16 or later.
2. Clone the repository and run `make test`. The gesture engine tests run without a trackpad.
3. Run `make run` to build the app bundle and launch it. Grant Accessibility access when asked.

## Where things live

| Area | Path |
|---|---|
| Touch input and device discovery | `Sources/macSlider/Core/MultitouchService.swift` |
| Gesture recognition (pure logic, own `macSliderCore` target) | `Sources/macSliderCore/` |
| Gesture to action mapping | `Sources/macSlider/Core/SliderController.swift` |
| System calls (keys, audio, display, haptics, event tap) | `Sources/macSlider/Actions/` |
| SwiftUI | `Sources/macSlider/UI/` |
| Tests | `Tests/macSliderTests/` |

## Rules of thumb

- `macSliderCore` imports only Foundation; `GestureEngine` and the touch types live there so the engine builds and tests without the app target. Anything you add there needs a test with synthetic frames.
- Put every private framework call behind a feature check. If `dlsym` returns nil, the feature turns off; the app never crashes.
- UI goes through the helpers in `UI/Components/Glass.swift` so macOS 14 and 15 keep a consistent fallback.
- New settings follow the pattern in `Settings.swift`: a stored property with `didSet` persistence and a default in `init`.
- Prefer System keys mode for anything macOS already has a key for. Direct writes are for continuous control only.

## Pull requests

1. One change per pull request.
2. Run `make test` and `make app` before opening it.
3. Describe how you tested on hardware: Mac model, macOS version, trackpad type.
4. Add a line to `CHANGELOG.md` under Unreleased.

## Reporting a bug

Include your macOS version, Mac model, whether the issue happens in System keys mode or Direct mode, and the output of `log show --predicate 'process == "macSlider"' --last 5m` if the app logged anything.
