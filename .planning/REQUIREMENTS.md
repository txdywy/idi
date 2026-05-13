# idi Requirements

## Current MVP: Native macOS menu bar monitor
### Functional requirements
1. Launch as a macOS menu-bar app, not a web/dashboard-first app.
2. Create a compact `NSStatusItem` in the system menu bar.
3. Update the menu-bar title with live summary telemetry.
4. Open a compact popover from the status item.
5. Show CPU, memory, network, disk, and battery/power modules in the popover.
6. Show short in-memory sparkline histories for modules.
7. Provide footer actions for Preferences, Pause/Resume, and Quit.
8. Preferences must control refresh interval, density, and visible modules.
9. Pause/Resume must actually stop/start telemetry refresh.
10. Closing popover or preferences must leave the menu-bar app running.

### Non-functional requirements
1. Use native macOS APIs for the shell: AppKit `NSStatusItem` and `NSPopover`.
2. Use SwiftUI for compact menu-sized UI surfaces.
3. Keep telemetry collectors separate from UI so mock data can be replaced by native collectors.
4. Avoid copying proprietary UI assets, exact layouts, text, or icons from referenced apps.
5. Keep refresh intervals conservative and timer-tolerant to avoid power impact.

## Later phases
- Native CPU and memory collectors using public APIs and Mach host statistics.
- Network throughput collectors using Network/SystemConfiguration-compatible interfaces.
- Battery/power collectors using IOKit power source APIs.
- Disk capacity and activity collectors.
- Multiple configurable menu bar items.
- Launch at login using `SMAppService`.
- Visual alert states, then optional Notification Center alerts with anti-noise controls.
- Sensors, fans, GPU, weather, and time modules after core menu-bar UX is reliable.
