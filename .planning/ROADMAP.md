# idi Roadmap

## Phase 1 — Native menu bar MVP
- Create Swift/AppKit menu-bar app shell.
- Add `NSStatusItem` with live compact status text.
- Add SwiftUI `NSPopover` content for CPU, memory, network, disk, and battery modules.
- Add Preferences for refresh interval, density, launch-at-login placeholder, and module visibility.
- Add working Pause/Resume and Quit actions.
- Verify with `swift build`.

## Phase 2 — Real core telemetry
- Replace mock CPU values with host CPU sampling.
- Replace mock memory values with physical memory/pressure sampling.
- Add network interface throughput sampling.
- Add disk capacity/activity sampling.
- Add IOKit battery/power source sampling.

## Phase 3 — Menu bar customization
- Add multiple optional status items.
- Add compact/balanced/detailed menu bar renderers.
- Persist preferences with UserDefaults.
- Add launch-at-login using `SMAppService`.

## Phase 4 — Alerts and diagnostics
- Add normal/warning/critical visual states.
- Add sustained-threshold checks and cooldowns.
- Add optional Notification Center alerts.

## Phase 5 — Advanced modules
- Research safe sensor/fan/GPU access.
- Add weather and clock modules only after privacy and network policy is explicit.
- Add optional detail window if the menu popover becomes too dense.

## Deprecated direction
The earlier Electron/Vite dashboard scaffold was a wrong-direction prototype and must not drive the product architecture. idi is native menu-bar-first.
