# Changelog

All notable changes to macSlider are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com).

## [Unreleased]

### Added

- App icon.
- Downloadable release zip on GitHub Releases.

### Changed

- Gesture engine and touch types moved to a `macSliderCore` target so they build and test on their own.
- Menu panel and settings redesigned: flat low-contrast surfaces, thin lit edge rails on the trackpad preview, level readouts under their edge, aligned settings rows.
- `make run` clears the stale Accessibility grant left by the previous ad-hoc signed build.

### Fixed

- First compile on real hardware: a shadowed `zone(for:)` call in the engine and a `Settings.init` that touched `self` too early.
- Trackpad preview collapsed to zero height in the menu bar popover.

## [0.1.0] - 2026-11-03

### Added

- Right-edge volume and left-edge brightness slides with the native macOS HUD.
- Direct level mode with a Liquid Glass HUD, continuous control through CoreAudio and DisplayServices.
- Haptic ticks in three strengths, with a longer buzz on mute.
- Precise sliding (quarter steps) and Shift-Option fine control.
- Cursor freeze and click suppression while sliding.
- Quick Mute on the top-right corner.
- Media strip on the bottom edge: swipe to skip, optional double-tap to play or pause, reverse swipe.
- Top strip for keyboard backlight or switching Spaces.
- Assignable corner actions: play/pause, mute, Mission Control, show desktop, lock screen, run a Shortcut.
- Swap sides, bottom quarter only, flip vertical axis, required modifier, Magic Mouse support.
- Menu bar panel with a live trackpad preview, glass chips and sliders, and an in-panel settings page.
- Three-step setup guide.
- Open at login, light/dark/system appearance.
- Recovery after sleep and trackpad reconnect.
- Unit tests for the gesture engine.
