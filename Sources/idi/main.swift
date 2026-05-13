import AppKit
import SwiftUI

@MainActor private var appDelegate: AppDelegate?

MainActor.assumeIsolated {
    let app = NSApplication.shared
    appDelegate = AppDelegate()

    app.delegate = appDelegate
    app.setActivationPolicy(.accessory)
    app.run()
}
