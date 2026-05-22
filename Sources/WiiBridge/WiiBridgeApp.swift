import SwiftUI

@main
struct WiiBridgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Wii Bridge", id: "main") {
            MainWindow()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menuView = MenuView()
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 250, height: 350)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: menuView)
        self.popover = popover
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemName: "gamecontroller")
            button.action = #selector(togglePopover(_:))
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let event = NSApplication.shared.currentEvent, event.type == .rightMouseUp {
            // Right click could open main window?
        }

        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(sender)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    @objc func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // In SwiftUI 3+, we usually use openWindow environment variable,
        // but from AppDelegate we can use this trick:
        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
