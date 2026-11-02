import SwiftUI

@main
struct MacSliderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private var settings: Settings { Settings.shared }

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView(controller: SliderController.shared)
                .environment(settings)
        } label: {
            Image(systemName: menuSymbol)
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)

    }

    @MainActor private var menuSymbol: String {
        if !settings.isEnabled { return "rectangle.dashed" }
        return SliderController.shared.isMuted ? "rectangle.inset.filled" : "rectangle.inset.filled"
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only. LSUIElement in Info.plist does the same for bundled builds; this covers `swift run`.
        NSApp.setActivationPolicy(.accessory)

        Task { @MainActor in
            SliderController.shared.start()
            if !Settings.shared.hasCompletedOnboarding {
                // Give the MenuBarExtra a beat to register, then open the guide.
                try? await Task.sleep(for: .milliseconds(400))
                OnboardingWindow.show()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

/// Plain AppKit window for the setup guide, so it can be opened from anywhere (including the app delegate).
@MainActor
enum OnboardingWindow {
    private static var window: NSWindow?

    static func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = OnboardingView(controller: SliderController.shared, onDone: { close() })
            .environment(Settings.shared)
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 420),
                         styleMask: [.titled, .closable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.contentView = NSHostingView(rootView: view)
        w.center()
        w.isReleasedWhenClosed = false
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func close() {
        window?.close()
        window = nil
    }
}
