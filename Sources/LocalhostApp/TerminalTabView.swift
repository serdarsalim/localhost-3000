import SwiftUI
import AppKit
import SwiftTerm

struct TerminalTabView: NSViewRepresentable {
    let session: TerminalSession

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        let terminal = session.terminalView
        terminal.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            terminal.topAnchor.constraint(equalTo: container.topAnchor),
            terminal.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Make sure the terminal grabs focus when the tab is shown.
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(session.terminalView)
        }
    }
}
