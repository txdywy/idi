# Native Menu Bar MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build idi as a native macOS menu-bar-first system monitor MVP.

**Architecture:** AppKit owns app lifecycle, status item, and popover anchoring. SwiftUI renders the compact monitoring popover. A telemetry store publishes short-history metric snapshots that can later be backed by native collectors.

**Tech Stack:** Swift 6, Swift Package Manager, AppKit, SwiftUI, Combine/Foundation.

---

## Tasks
- [ ] Create SwiftPM executable package metadata.
- [ ] Implement AppDelegate with accessory activation, NSStatusItem, NSPopover, and Quit handling.
- [ ] Implement telemetry models and mock/native-shaped TelemetryStore with timer refresh.
- [ ] Implement SwiftUI popover UI sized for menu bar use, not a web dashboard.
- [ ] Implement compact sparkline and metric section components.
- [ ] Update planning docs to mark Electron dashboard as wrong-direction prototype and native menu bar as primary.
- [ ] Verify with `swift build`.
