import SwiftUI
import AppKit

final class UnborderedSearchFieldCell: NSSearchFieldCell {
    override var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }

    override func drawFocusRingMask(withFrame cellFrame: NSRect, in controlView: NSView) {
        // Intentionally empty: suppress focus ring mask
    }
}

final class UnborderedSearchField: NSSearchField {
    override class var cellClass: AnyClass? {
        get { UnborderedSearchFieldCell.self }
        set {}
    }

    override var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }

    override func drawFocusRingMask() {
        // Intentionally empty: suppress focus ring mask
    }
}

public struct NativeSearchField: NSViewRepresentable {
    @Binding public var text: String
    public var prompt: String

    public init(text: Binding<String>, prompt: String = "Search files or URLs...") {
        self._text = text
        self.prompt = prompt
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    public func makeNSView(context: Context) -> NSSearchField {
        let searchField = UnborderedSearchField()
        searchField.focusRingType = .none
        searchField.bezelStyle = .roundedBezel
        searchField.placeholderString = prompt
        searchField.font = .systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        searchField.sendsWholeSearchString = false
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = context.coordinator

        if let cell = searchField.cell as? NSSearchFieldCell {
            cell.focusRingType = .none
        }

        context.coordinator.searchField = searchField
        return searchField
    }

    public func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if nsView.placeholderString != prompt {
            nsView.placeholderString = prompt
        }
        nsView.focusRingType = .none
        nsView.cell?.focusRingType = .none
    }

    public class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        weak var searchField: NSSearchField?
        private var clickMonitor: Any?

        init(text: Binding<String>) {
            self._text = text
            super.init()
            setupGlobalClickMonitor()
        }

        deinit {
            if let monitor = clickMonitor {
                NSEvent.removeMonitor(monitor)
                clickMonitor = nil
            }
        }

        private func setupGlobalClickMonitor() {
            clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self,
                      let searchField = self.searchField,
                      let window = searchField.window,
                      let firstResponder = window.firstResponder as? NSView else {
                    return event
                }

                // Determine if the search field or its field editor currently has focus
                let isFocused: Bool
                if firstResponder === searchField {
                    isFocused = true
                } else if let fieldEditor = firstResponder as? NSTextView,
                          fieldEditor.delegate === searchField {
                    isFocused = true
                } else {
                    isFocused = false
                }

                if isFocused {
                    // Check if the click happened outside the search field bounds
                    let clickInWindow = event.locationInWindow
                    let clickInField = searchField.convert(clickInWindow, from: nil)

                    if !searchField.bounds.contains(clickInField) {
                        DispatchQueue.main.async {
                            window.makeFirstResponder(nil)
                        }
                    }
                }

                return event
            }
        }

        public func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            self.text = field.stringValue
        }

        public func searchFieldDidStartSearching(_ sender: NSSearchField) {
            self.text = sender.stringValue
        }

        public func searchFieldDidEndSearching(_ sender: NSSearchField) {
            self.text = sender.stringValue
        }
    }
}
