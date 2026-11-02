# Handoff: macSlider

Repo: `/Users/friday/Projects/MacSlider`. macOS menu bar app, SwiftPM, Swift 5 mode, macOS 14+ target, Liquid Glass on macOS 26. Read `README.md` for what the app does and `CONTRIBUTING.md` for the layout. This file is what those two leave out: the state of the code and the traps.

## State of the code

The entire codebase was written without a Mac and the app target has **never compiled**. Both attempts so far hit the toolchain, not the code: the Command Line Tools lack the SwiftUI and XCTest/Testing macro plugins, so `make test` and `make run` need full Xcode (`xcode-select -s /Applications/Xcode.app/Contents/Developer`; `make` guards for this). On 2026-11-03 Xcode was not installed on the dev machine, so only the pure-Swift engine could be exercised: it was split into its own `macSliderCore` target, which builds clean with `swift build --target macSliderCore` under the CLT. That split caught one real bug (a local `zone` binding shadowing `zone(for:)`). Your first job is still a green `make test` and then a green `make run`, with Xcode installed.

Treat every file as draft until it compiles and has been touched on hardware. The architecture is sound; expect a dozen small API and isolation fixes, not a redesign.

## First session, in order

1. `make test`. Fix compile errors until the 11 gesture engine tests pass. The engine is pure Swift, so this round surfaces only Swift-language mistakes.
2. `make run`. Fix the app target. Expected hot spots are listed under Likely failures.
3. Grant Accessibility access, open the panel, touch the pad. Confirm finger dots appear and land where the finger is. If y is inverted, the `MTTouch` layout or axis assumption is off; see Trackpad coordinates.
4. Slide the right edge. Confirm the native volume HUD moves. Then left edge, brightness.
5. Only then move to haptics, cursor freeze, Direct mode, corners.

Done means: tests green, both edges change their level on the real trackpad, no crash on sleep/wake.

## Likely failures

In descending order of confidence that they will bite:

- `SliderController` is `@Observable @MainActor`. Closures in `init` reach back through `SliderController.shared` inside `MainActor.assumeIsolated` to avoid capturing `self` before init completes. If the compiler objects, the fallback is: drop `@MainActor` from the class, keep `DispatchQueue.main.async` hops, and mark only the UI-facing properties.
- `Settings` is `@Observable` with `didSet` persistence on stored properties. If the macro rejects `didSet`, switch to explicit `UserDefaults` writes in a `save()` called from the UI `onChange` handlers.
- SF Symbol names in `SettingsPage.cornerRow` (`circle.grid.cross.up.filled`), `MacSliderApp.menuSymbol` (`rectangle.dashed`, `rectangle.inset.filled`), `TrackpadPreview`, and `Settings` enums. A missing symbol renders blank, not a crash. Verify in SF Symbols.app.
- `Glass.swift`: `glassEffect(_:in:)`, `GlassEffectContainer`, `.buttonStyle(.glass)` and `.glassProminent` are macOS 26 APIs behind `#available`. If a signature differs in the installed SDK (the machine has `MacOSX27.0.sdk`), fix it there and nowhere else; every glass surface routes through this file.
- `MediaKey.press(fine:)` sets Shift and Option in the `NSEvent` modifier flags to request quarter steps. Unverified that synthesized system-defined events honour modifiers. If quarter steps do not happen, Direct mode already gives 1/64 steps; point Precise sliding at Direct mode instead of fighting it.
- `HapticEngine` calls private `MTActuatorCreateFromDeviceID` / `MTActuatorOpen` / `MTActuatorActuate`. Actuation IDs 3/4/6 are community lore. If they do nothing, the `NSHapticFeedbackManager` fallback still runs; confirm which path is active by logging `actuator != nil`.
- `CursorFreezer` swallows events from a `CGEventTap`. If the tap fails to create, `install()` silently leaves `tap` nil. Check `isInstalled` after permission is granted.

## Trackpad coordinates

`MTTouch.normalized.position` is assumed `x: 0 left to 1 right`, `y: 0 bottom (near the user) to 1 top`. The whole engine and the preview depend on it. The `MTTouch` struct layout in `Sources/MultitouchBridge/include/MultitouchBridge.h` is the community layout; `state == 4` means touching, `3` means make-touch. If dots in the preview mirror the finger vertically, the fastest check is a `print` in `MultitouchService.deliver`. A user-facing escape hatch already exists: Settings, Edges, Flip vertical axis.

## Invariants to keep

- `macSliderCore` (`GestureEngine`, `Touch`, `TouchFrame`) imports nothing above Foundation and does not depend on the app target. Every rule the engine gains needs a synthetic-frame test in `Tests/macSliderTests/GestureEngineTests.swift`. Files that import SwiftUI must write `macSliderCore.Edge`; SwiftUI has its own `Edge`.
- Every private symbol is resolved with `dlsym` and nil-checked. A missing symbol disables the feature; the app never crashes on a macOS update.
- All gesture handling runs on the main actor. Frames hop from the multitouch thread in `SliderController.init` and nowhere else.
- UI surfaces go through `Glass.swift` so macOS 14/15 keep the Material fallback.
- Enum cases are never named `none` (shadows `Optional.none` under `??`). Current names: `.noModifier`, `.nothing`, `.off`.

## Tooling

- `make test`, `make run`, `make install`, `make clean`. The Makefile refuses the Command Line Tools toolchain.
- `scripts/build-app.sh` assembles `build/macSlider.app` and ad-hoc signs it. `SIGN_IDENTITY="Developer ID Application: ..."` for a real signature. No icon yet; it copies `Resources/AppIcon.icns` if one exists.
- CI (`.github/workflows/ci.yml`) runs `swift test` and the bundle script on `macos-15`. It has not run yet.
- Settings live in `UserDefaults` under `dev.macslider.app`; `defaults delete dev.macslider.app` resets.

## Not built yet

Roadmap items with no code behind them: per-app bindings, DDC for external displays, pressure-based actions, a gesture editor, notarized releases, an app icon. `README.md` advertises the first four as "things we'd love to see", not as shipped.

## Prior art worth reading

When a private API misbehaves, these repos have working, hardware-tested implementations of the same calls: `shashvat1965/slidesense` (CoreAudio fallbacks, NSGlassEffectView HUD, SwiftPM bundle script), `helgafinn/glisse` (TrackpadManager source selection and recovery), `leecdiang/EdgeControl` (edge-ingress false-touch rejection, DDC), `0x1p0/sway-application` (hardware notifications instead of polling). Read for technique; copy no code (different licenses may apply, and macSlider claims independence in its README).