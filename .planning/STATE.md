---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: complete
stopped_at: context exhaustion at 76% (2026-05-13)
last_updated: "2026-05-13T11:05:22.604Z"
---

# idi State

## Current status

idi is a native macOS menu-bar system monitor app with a mature original industrial-cockpit product layer: ordered menu-bar instruments, bounded local telemetry history, local alert rules, process attribution limits, and distributable release packaging without copying proprietary iStat UI, text, assets, colors, or layouts.

## Implemented

- Native AppKit `NSStatusItem` menu-bar shell with popover content sized for the cockpit surface.
- Original dark-glass cockpit `NSPopover` with top command header, left module rail, selected-module hero/detail stage, dense grid chart, grouped table/details, and bottom command footer.
- Selected-module navigation is stable by module name, falls back to the first visible module when disabled/unavailable, and shows a Preferences action for the empty state.
- Persisted module ordering with Preferences Up/Down controls; popover rail, visible modules, primary menu-bar module display, separate status-item updates, and summaries respect the saved order.
- Footer commands for Preferences, Refresh Now, Pause/Resume, Copy Summary, and Quit; Copy Summary writes visible telemetry to `NSPasteboard`.
- Right-click quick menu on menu-bar status items for Open Cockpit, Pause/Resume, Refresh Now, Copy Summary, Preferences, and Quit.
- Custom cockpit-style Preferences control center with Monitoring, Modules, Menu Bar, Alerts, and System/Privacy sections.
- CPU, memory, network, disk, battery/power collectors.
- GPU details through Metal device APIs, including explicit public-API-limited rows for utilization, memory used, frequency, temperature, and power.
- Expanded read-only AppleSMC CPU/GPU/battery/enclosure temperature keys plus fan actual/min/max attempts with graceful fallback.
- Explicit fan safety UI state: fan control is read-only / disabled for safety.
- Weather module using Open-Meteo with caching and fallback behavior.
- Time and local calendar/time-zone module.
- Running app and top process attribution using `NSWorkspace` and `ps`, with Top CPU, Top Memory, and Recent Average/Peak table sections backed by recent per-PID history.
- Preferences for refresh interval, density, visible modules, module order, primary menu-bar display style, separate menu-bar items, launch at login, notifications, CPU/memory/disk high thresholds, battery-low threshold, and sensor-high threshold.
- Bounded in-memory telemetry history per module with 5-minute min/average/max/sample summaries in the popover detail view.
- UserDefaults preference persistence.
- Normal/warning/critical state aggregation.
- Optional macOS notifications for warning/critical states with cooldown.
- Launch-at-login wiring through ServiceManagement.
- Pause/Resume and Quit actions.
- `.app` bundle generation with `LSUIElement`, generated icon, and ad-hoc codesigning.
- Unit tests for health state and preferences persistence.

## Public iStat-style parity matrix

| Area | Covered idi fields | Safe implementation / intentional alternative |
| --- | --- | --- |
| CPU | Aggregate usage, per-core usage rows, active core count, thermal state, 1/5/15 load averages, system uptime | Uses safe Mach host CPU APIs and `ProcessInfo`; no privileged kernel extension or private UI cloning. |
| Memory | Used/total summary, active, wired, compressed, inactive, speculative, free, file cache estimate, swap used/total | Uses `host_statistics64` VM counters and `sysctlbyname("vm.swapusage")`; keeps pressure summary. |
| Disk | Mounted local volume list, available/total per volume, read/write activity sampling, startup-volume summary | Uses mounted volume resource values and safe IORegistry storage counters; SMART row explicitly says supported hardware/privileges are required instead of pretending. |
| Network | Aggregate upload/download rates, per-interface private IPv4 rows, per-interface upload/download rates, connectivity status | Uses `getifaddrs`; public IP is explicitly not queried silently. |
| Battery/Power | Charge percent, time remaining, cycle count, condition/health, power source, adapter/power source details, desktop fallback | Uses IOKit power source keys when exposed; gracefully reports unavailable fields. |
| Sensors/Fans | Temperature key attempts, fan actual/min/max read attempts, thermal fallback | AppleSMC is read-only; fan control writes and SMC writes are deliberately not implemented. |
| GPU | Metal device list/name, location when available, headless/removable/low-power, unified memory, recommended working set; explicit UI rows for utilization, memory used, frequency, temperature, and power | Implemented with public Metal APIs. Utilization, live memory used, frequency, and power are marked public API-limited in the UI; temperature links to Sensors when read-only SMC exposes it. |
| Weather | Configured Shanghai Open-Meteo current temp, humidity, wind, precipitation, pressure, visibility, UV, short forecast rows | Labels Shanghai as configured location; does not request current-location permission. |
| Time | Local date/time, week/day-of-year rows, time zone, world clocks | Uses Foundation calendars only; no Calendar permission request. |
| Apps | Running app count, foreground apps, process table rows for fixed sort/filter-like sections: Top CPU, Top Memory, Recent Average/Peak | Uses `NSWorkspace` and `ps`; no Accessibility permission requirement and no terminate/kill actions. |
| Detail UI | Module-specific headers, graph legends with min/max/current, grouped detail rows, and Apps table presentation | Implemented in original idi visual direction without copying proprietary iStat UI/text/assets/layouts. |
| Customization | Popover module visibility, persisted module order, separate module menu-bar items, and primary menu-bar display style: Summary vs Modules | Implemented as simple persisted options with Up/Down ordering controls instead of drag-and-drop. |
| Alerts/preferences | Notification enablement plus CPU/memory/disk high thresholds, battery-low threshold, and sensor-high threshold | Local rules only; no scripting, privileged control, SMC writes, or fan-control writes. |
| Release packaging | `.app`, ad-hoc codesign verification, `.zip`, and `.dmg` when `hdiutil` is available | Not notarized because Developer ID/notary credentials are unavailable. |

## Verification

- `swift test` passes.
- `swift build` passes.
- `scripts/build-app.sh` builds `.build/app/idi.app`.
- `scripts/package-release.sh` creates `.build/release/idi.zip` and `.build/release/idi.dmg` when `hdiutil` is available.
- `codesign --verify --deep --strict .build/app/idi.app` passes.
- Launch smoke test confirms the packaged app starts as a macOS process.
- Release artifacts are ad-hoc signed and explicitly not notarized.

## Run

`scripts/build-app.sh && open .build/app/idi.app`

## Session Continuity

Last session: 2026-05-13T11:05:22.600Z
Stopped at: context exhaustion at 76% (2026-05-13)
Resume file: None
