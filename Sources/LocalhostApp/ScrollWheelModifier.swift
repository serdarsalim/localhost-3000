import SwiftUI
import AppKit

private class ScrollCaptureView: NSView {
    var onScroll: ((CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event.deltaY)
    }
}

private struct ScrollWheelCapture: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollCaptureView {
        let view = ScrollCaptureView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollCaptureView, context: Context) {
        nsView.onScroll = onScroll
    }
}

extension View {
    func scrollWheelHandler(onScroll: @escaping (CGFloat) -> Void) -> some View {
        overlay(ScrollWheelCapture(onScroll: onScroll))
    }
}
