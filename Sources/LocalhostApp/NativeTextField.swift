import SwiftUI
import AppKit

struct NativeTextField: NSViewRepresentable {
    @Binding var text: String
    var onCommit: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, onCommit: onCommit) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        field.focusRingType = .none
        field.bezelStyle = .roundedBezel
        field.isBordered = true
        field.isEditable = true
        field.isSelectable = true
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        var onCommit: (String) -> Void

        init(text: Binding<String>, onCommit: @escaping (String) -> Void) {
            _text = text
            self.onCommit = onCommit
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }

        // Pass the raw field value directly — don't rely on the binding being flushed yet
        func controlTextDidEndEditing(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            onCommit(field.stringValue)
        }
    }
}
