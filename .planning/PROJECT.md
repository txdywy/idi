# idi Project

## Purpose
idi is a free, original macOS menu-bar system monitor inspired by the broad category of tools such as iStat Menus. Its primary surface is the macOS menu bar: compact status items plus dropdown/popover panels for CPU, memory, network, disk, battery, sensors, alerts, and related system data.

## Product stance
- Menu-bar-first: the app should launch into the macOS menu bar without showing a dashboard window by default.
- Free-first: no ads, tracking, or licensing gates.
- Original visual identity: dense, refined, modern macOS instrumentation rather than copied proprietary layouts or assets.
- Native-first: use AppKit/SwiftUI for real menu bar behavior, low overhead, and future access to native telemetry APIs.

## Technical direction
- Swift Package executable for the current native MVP.
- AppKit owns `NSStatusItem`, `NSPopover`, app lifecycle, and Quit behavior.
- SwiftUI renders the popover and preferences surfaces.
- Telemetry models are shaped for native collectors and currently use safe mock/live demo values.

## Success criteria for current MVP
- `swift build` succeeds.
- Launching the executable creates a macOS menu bar status item.
- Clicking the status item opens a compact monitoring popover.
- Popover shows CPU, memory, network, disk, and battery modules with short histories.
- Preferences can change refresh interval, density, and visible modules.
- Pause/resume affects telemetry refresh.
