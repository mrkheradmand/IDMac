import SwiftUI
import AppKit

public struct WindowAccessor: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.tabbingMode = .disallowed
                window.tabbingIdentifier = ""
                MenuBarManager.shared.registerMainWindow(window)
            }
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.tabbingMode = .disallowed
                window.tabbingIdentifier = ""
                MenuBarManager.shared.registerMainWindow(window)
            }
        }
    }
}

public struct ContentView: View {
    public init() {}

    public var body: some View {
        MainSplitView()
            .frame(minWidth: 800, minHeight: 500)
            .background(WindowAccessor())
    }
}
