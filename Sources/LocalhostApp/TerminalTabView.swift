import SwiftUI
import AppKit
import SwiftTerm

struct TerminalTabView: NSViewRepresentable {
    let session: TerminalSession

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        container.wantsLayer = true
        let terminal = session.terminalView
        terminal.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            terminal.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            terminal.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            terminal.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Match the padding strip to the terminal's background so it looks like one surface.
        nsView.layer?.backgroundColor = session.terminalView.nativeBackgroundColor.cgColor
        // Make sure the terminal grabs focus when the tab is shown.
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(session.terminalView)
        }
    }
}
