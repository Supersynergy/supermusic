import AppKit
import Foundation
import SwiftUI

// MARK: - NotchPlayerController

/// Positions a floating HUD window anchored to the MacBook notch.
///
/// On Macs without a notch the window appears at the top-center of the
/// main screen (same visual position, just no physical notch beneath it).
///
/// Usage:
/// ```swift
/// let ctrl = NotchPlayerController(vm: nowPlayingViewModel)
/// ctrl.install()    // call once at app launch
/// ```
@MainActor
public final class NotchPlayerController {

    // MARK: - Constants

    private static let collapsedSize = CGSize(width: 200, height: 36)
    private static let expandedSize  = CGSize(width: 320, height: 420)
    private static let animDuration: TimeInterval = 0.22

    // MARK: - State

    private let vm: NowPlayingViewModel
    private var window: NSPanel?
    private var hostingController: NSHostingController<NotchPlayerView>?
    private var isExpanded = false

    public init(vm: NowPlayingViewModel) {
        self.vm = vm
    }

    // MARK: - Public API

    public func install() {
        guard self.window == nil else { return }

        let panel = NSPanel(
            contentRect: self.collapsedFrame(),
            styleMask: [.nonActivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isOpaque = false
        panel.hidesOnDeactivate = false

        let view = NotchPlayerView(vm: self.vm, isExpanded: false) { [weak self] in
            self?.toggle()
        }
        let hc = NSHostingController(rootView: view)
        hc.view.frame = panel.contentView?.bounds ?? .zero
        hc.view.autoresizingMask = [.width, .height]
        hc.view.wantsLayer = true
        hc.view.layer?.backgroundColor = .clear
        panel.contentView?.addSubview(hc.view)

        self.hostingController = hc
        self.window = panel

        panel.orderFrontRegardless()
        self.setupTracking()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reposition()
        }
    }

    // MARK: - Layout

    private func notchScreen() -> NSScreen {
        NSScreen.screens.first(where: { $0.localizedName.lowercased().contains("built-in") })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private func collapsedFrame() -> NSRect {
        let screen = self.notchScreen()
        let sw = screen.frame.width
        let sh = screen.frame.height
        let w  = Self.collapsedSize.width
        let h  = Self.collapsedSize.height
        return NSRect(x: (sw - w) / 2, y: sh - h, width: w, height: h)
    }

    private func expandedFrame() -> NSRect {
        let screen = self.notchScreen()
        let sw = screen.frame.width
        let sh = screen.frame.height
        let w  = Self.expandedSize.width
        let h  = Self.expandedSize.height
        let x  = (sw - w) / 2
        let y  = sh - h - 4
        return NSRect(x: x, y: y, width: w, height: h)
    }

    private func reposition() {
        guard let window else { return }
        let frame = self.isExpanded ? self.expandedFrame() : self.collapsedFrame()
        window.setFrame(frame, display: true, animate: false)
    }

    // MARK: - Expand / Collapse

    private func toggle() {
        self.isExpanded ? self.collapse() : self.expand()
    }

    private func expand() {
        guard !self.isExpanded, let window else { return }
        self.isExpanded = true
        self.updateView()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Self.animDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(self.expandedFrame(), display: true)
        }
        window.hasShadow = true
    }

    private func collapse() {
        guard self.isExpanded, let window else { return }
        self.isExpanded = false
        self.updateView()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Self.animDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().setFrame(self.collapsedFrame(), display: true)
        } completionHandler: {
            self.window?.hasShadow = false
        }
    }

    private func updateView() {
        let expanded = self.isExpanded
        let view = NotchPlayerView(vm: self.vm, isExpanded: expanded) { [weak self] in
            self?.toggle()
        }
        self.hostingController?.rootView = view
    }

    // MARK: - Mouse tracking

    private func setupTracking() {
        guard let contentView = self.window?.contentView else { return }
        let area = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: contentView,
            userInfo: nil
        )
        contentView.addTrackingArea(area)

        NSEvent.addLocalMonitorForEvents(matching: [.mouseEntered, .mouseExited]) { [weak self] event in
            guard let self, let window = self.window,
                  event.window == window else { return event }
            if event.type == .mouseEntered {
                self.expand()
            } else if event.type == .mouseExited {
                self.collapse()
            }
            return event
        }
    }
}
