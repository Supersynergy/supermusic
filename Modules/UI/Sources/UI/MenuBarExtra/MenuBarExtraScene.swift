import SwiftUI

// MARK: - MenuBarExtraScene

public struct MenuBarExtraScene: View {
    public var vm: NowPlayingViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var scrubDragFraction: Double?

    public init(vm: NowPlayingViewModel) {
        self.vm = vm
    }

    public var body: some View {
        VStack(spacing: 10) {
            // Artwork + Track Info row
            HStack(spacing: 12) {
                self.artworkView
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(
                        self.vm.title.isEmpty ? "Not playing" : self.vm.title,
                        font: .headline,
                        foregroundStyle: Color.primary
                    )
                    if !self.vm.artist.isEmpty {
                        MarqueeText(self.vm.artist, font: .subheadline, foregroundStyle: Color.secondary)
                    }
                    if !self.vm.album.isEmpty {
                        MarqueeText(self.vm.album, font: .caption, foregroundStyle: Color.secondary.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Scrubber + times
            if self.vm.duration > 0 {
                VStack(spacing: 2) {
                    Slider(
                        value: Binding(
                            get: { self.scrubDragFraction ?? (self.vm.position / self.vm.duration) },
                            set: { self.scrubDragFraction = $0 }
                        ),
                        in: 0 ... 1
                    ) { editing in
                        if !editing, let fraction = self.scrubDragFraction {
                            self.scrubDragFraction = nil
                            Task { await self.vm.scrub(to: fraction * self.vm.duration) }
                        }
                    }
                    .controlSize(.small)
                    .tint(.accentColor)

                    HStack {
                        Text(self.formatTime(self.vm.position))
                            .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                        Spacer()
                        Text("-" + self.formatTime(self.vm.duration - self.vm.position))
                            .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }

            // PRIMARY TRANSPORT ROW: skip5 | prev | play/pause | next | skip5
            HStack(spacing: 14) {
                SmartButton(icon: "gobackward.5", size: 14, label: "Back 5s") {
                    Task { await self.vm.scrub(to: max(0, self.vm.position - 5)) }
                }

                SmartButton(icon: "backward.fill", size: 17, label: "Previous") {
                    Task { await self.vm.previous() }
                }

                Button {
                    Task { await self.vm.playPause() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 36, height: 36)
                        Image(systemName: self.vm.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: self.vm.isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(self.vm.isPlaying ? "Pause" : "Play")

                SmartButton(icon: "forward.fill", size: 17, label: "Next") {
                    Task { await self.vm.next() }
                }

                SmartButton(icon: "goforward.5", size: 14, label: "Forward 5s") {
                    Task { await self.vm.scrub(to: min(self.vm.duration, self.vm.position + 5)) }
                }
            }
            .frame(maxWidth: .infinity)

            // SECONDARY ROW: skip10 | shuffle | repeat | mute | skip10
            HStack(spacing: 18) {
                SmartButton(icon: "gobackward.10", size: 13, label: "Back 10s") {
                    Task { await self.vm.scrub(to: max(0, self.vm.position - 10)) }
                }

                SmartButton(
                    icon: "shuffle",
                    size: 13,
                    label: "Shuffle",
                    isActive: self.vm.shuffleOn
                ) {
                    Task { await self.vm.toggleShuffle() }
                }

                SmartButton(
                    icon: self.repeatIcon(self.vm.repeatMode),
                    size: 13,
                    label: "Repeat",
                    isActive: self.vm.repeatMode != .off
                ) {
                    Task { await self.vm.cycleRepeat() }
                }

                SmartButton(
                    icon: self.vm.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    size: 13,
                    label: self.vm.isMuted ? "Unmute" : "Mute",
                    isActive: self.vm.isMuted
                ) {
                    Task { await self.vm.toggleMute() }
                }

                SmartButton(icon: "goforward.10", size: 13, label: "Forward 10s") {
                    Task { await self.vm.scrub(to: min(self.vm.duration, self.vm.position + 10)) }
                }
            }

            // VOLUME ROW
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.caption2).foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(self.vm.volume) },
                        set: { v in Task { await self.vm.setVolume(Float(v)) } }
                    ),
                    in: 0 ... 1
                )
                .controlSize(.mini)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            // UTILITY ROW: stop-after | speed- | speed | speed+ | sleep
            HStack(spacing: 14) {
                SmartButton(
                    icon: self.vm.stopAfterCurrent ? "stop.circle.fill" : "stop.circle",
                    size: 13,
                    label: "Stop after current",
                    isActive: self.vm.stopAfterCurrent
                ) {
                    Task { await self.vm.toggleStopAfterCurrent() }
                }

                SmartButton(icon: "speedometer", size: 13, label: "1\u{D7}") {
                    Task { await self.vm.resetSpeed() }
                }

                SmartButton(icon: "moon.zzz.fill", size: 13, label: "Sleep timer") {
                    Task { await self.vm.setSleepTimer(minutes: 30) }
                }

                SmartButton(icon: "minus", size: 13, label: "Slower") {
                    Task { await self.vm.decreaseSpeed() }
                }

                SmartButton(icon: "plus", size: 13, label: "Faster") {
                    Task { await self.vm.increaseSpeed() }
                }
            }

            Divider()

            // BOTTOM: Open app button
            Button("Open SuperMusic") {
                self.openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.footnote)
        }
        .padding(14)
        .frame(width: 240)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("SuperMusic mini controls")
    }

    // MARK: - Artwork

    @ViewBuilder
    private var artworkView: some View {
        Group {
            if let img = self.vm.artwork {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                GradientPlaceholder(seed: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Helpers

    private func formatTime(_ t: TimeInterval) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let secs = Int(t)
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }

    private func repeatIcon(_ mode: RepeatMode) -> String {
        switch mode {
        case .off: "repeat"
        case .one: "repeat.1"
        case .all: "repeat"
        }
    }
}

// MARK: - SmartButton helper

private struct SmartButton: View {
    let icon: String
    let size: CGFloat
    let label: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            Image(systemName: self.icon)
                .font(.system(size: self.size, weight: .medium))
                .foregroundStyle(self.isActive ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .help(self.label)
        .accessibilityLabel(self.label)
    }
}
