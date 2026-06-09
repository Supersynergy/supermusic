import SwiftUI

// MARK: - NotchPlayerView

/// The floating HUD anchored to the MacBook notch.
///
/// **Collapsed** (default): a pill showing the current track title with
/// a subtle animated equaliser dot when playing.
/// **Expanded** (on hover / tap): full controls with artwork, scrubber,
/// 5s/10s skip, shuffle, repeat, volume, sleep timer, and speed.
public struct NotchPlayerView: View {

    public let vm: NowPlayingViewModel
    public let isExpanded: Bool
    public let onTap: () -> Void

    @State private var scrubDragFraction: Double?
    @Environment(\.colorScheme) private var colorScheme

    public init(vm: NowPlayingViewModel, isExpanded: Bool, onTap: @escaping () -> Void) {
        self.vm = vm
        self.isExpanded = isExpanded
        self.onTap = onTap
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if self.isExpanded {
                self.expandedView
            } else {
                self.collapsedPill
            }
        }
        .background(self.notchBackground)
        .clipShape(self.notchShape)
        .contentShape(self.notchShape)
        .onTapGesture(perform: self.onTap)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: self.isExpanded)
    }

    // MARK: - Collapsed pill

    private var collapsedPill: some View {
        HStack(spacing: 8) {
            if self.vm.isPlaying {
                EQDots()
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if self.vm.title.isEmpty {
                Text("SuperMusic")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                MarqueeText(self.vm.title, font: .system(size: 11, weight: .semibold), foregroundStyle: Color.primary)
                    .frame(maxWidth: 140)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Expanded view

    private var expandedView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Header: artwork + info
                HStack(spacing: 12) {
                    self.artworkView
                        .frame(width: 60, height: 60)

                    VStack(alignment: .leading, spacing: 3) {
                        if !self.vm.title.isEmpty {
                            MarqueeText(self.vm.title, font: .system(size: 13, weight: .semibold), foregroundStyle: Color.primary)
                        } else {
                            Text("Not playing")
                                .font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        if !self.vm.artist.isEmpty {
                            MarqueeText(self.vm.artist, font: .system(size: 11), foregroundStyle: Color.secondary)
                        }
                        if !self.vm.album.isEmpty {
                            MarqueeText(self.vm.album, font: .system(size: 10), foregroundStyle: Color.secondary.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Scrubber
                if self.vm.duration > 0 {
                    VStack(spacing: 2) {
                        Slider(
                            value: Binding(
                                get: { self.scrubDragFraction ?? (self.vm.position / self.vm.duration) },
                                set: { self.scrubDragFraction = $0 }
                            ),
                            in: 0 ... 1
                        ) { editing in
                            if !editing, let f = self.scrubDragFraction {
                                self.scrubDragFraction = nil
                                Task { await self.vm.scrub(to: f * self.vm.duration) }
                            }
                        }
                        .controlSize(.small)
                        .tint(.accentColor)

                        HStack {
                            Text(self.formatTime(self.vm.position))
                            Spacer()
                            Text("-" + self.formatTime(self.vm.duration - self.vm.position))
                        }
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(.tertiary)
                    }
                }

                // Primary transport: -5s | prev | play/pause | next | +5s
                HStack(spacing: 12) {
                    self.notchButton("gobackward.5", size: 13) {
                        Task { await self.vm.scrub(to: max(0, self.vm.position - 5)) }
                    }
                    self.notchButton("backward.fill", size: 16) {
                        Task { await self.vm.previous() }
                    }

                    Button { Task { await self.vm.playPause() } } label: {
                        ZStack {
                            Circle().fill(Color.accentColor).frame(width: 40, height: 40)
                            Image(systemName: self.vm.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: self.vm.isPlaying ? 0 : 1.5)
                        }
                    }
                    .buttonStyle(.plain)

                    self.notchButton("forward.fill", size: 16) {
                        Task { await self.vm.next() }
                    }
                    self.notchButton("goforward.5", size: 13) {
                        Task { await self.vm.scrub(to: min(self.vm.duration, self.vm.position + 5)) }
                    }
                }

                // Secondary: -10s | shuffle | repeat | mute | +10s
                HStack(spacing: 14) {
                    self.notchButton("gobackward.10", size: 12) {
                        Task { await self.vm.scrub(to: max(0, self.vm.position - 10)) }
                    }
                    self.notchButton("shuffle", size: 12, active: self.vm.shuffleOn) {
                        Task { await self.vm.toggleShuffle() }
                    }
                    self.notchButton(self.repeatIcon, size: 12, active: self.vm.repeatMode != .off) {
                        Task { await self.vm.cycleRepeat() }
                    }
                    self.notchButton(self.vm.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", size: 12, active: self.vm.isMuted) {
                        Task { await self.vm.toggleMute() }
                    }
                    self.notchButton("goforward.10", size: 12) {
                        Task { await self.vm.scrub(to: min(self.vm.duration, self.vm.position + 10)) }
                    }
                }

                // Volume
                HStack(spacing: 6) {
                    Image(systemName: "speaker.fill").font(.caption2).foregroundStyle(.tertiary)
                    Slider(
                        value: Binding(get: { Double(self.vm.volume) }, set: { v in Task { await self.vm.setVolume(Float(v)) } }),
                        in: 0 ... 1
                    )
                    .controlSize(.mini)
                    Image(systemName: "speaker.wave.3.fill").font(.caption2).foregroundStyle(.tertiary)
                }

                // Utility: stop-after | speed- | 1x | speed+ | sleep
                HStack(spacing: 14) {
                    self.notchButton(self.vm.stopAfterCurrent ? "stop.circle.fill" : "stop.circle", size: 12, active: self.vm.stopAfterCurrent) {
                        Task { await self.vm.toggleStopAfterCurrent() }
                    }
                    self.notchButton("minus", size: 11) { Task { await self.vm.decreaseSpeed() } }
                    Button {
                        Task { await self.vm.resetSpeed() }
                    } label: {
                        Text(String(format: "%.1f\u{D7}", self.vm.playbackRate))
                            .font(.system(size: 10, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    self.notchButton("plus", size: 11) { Task { await self.vm.increaseSpeed() } }
                    self.notchButton("moon.zzz", size: 12) { Task { await self.vm.setSleepTimer(minutes: 30) } }
                }
            }
            .padding(16)
        }
        .frame(width: 320, height: 400)
    }

    // MARK: - Artwork

    @ViewBuilder
    private var artworkView: some View {
        Group {
            if let img = self.vm.artwork {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                GradientPlaceholder(seed: 7)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Background + Shape

    private var notchBackground: some View {
        ZStack {
            if self.isExpanded {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(self.colorScheme == .dark ? 0.12 : 0.3), lineWidth: 0.5)
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.85))
            }
        }
    }

    private var notchShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: self.isExpanded ? 20 : 18, style: .continuous)
    }

    // MARK: - Helpers

    private var repeatIcon: String {
        switch self.vm.repeatMode {
        case .off: return "repeat"
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let s = Int(t); return String(format: "%d:%02d", s / 60, s % 60)
    }

    @ViewBuilder
    private func notchButton(_ icon: String, size: CGFloat, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(active ? Color.accentColor : Color.primary.opacity(0.75))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EQDots (animated equaliser indicator)

private struct EQDots: View {
    @State private var phase = false

    private let heights: [[CGFloat]] = [[8, 12, 6], [12, 8, 10]]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0 ..< 3, id: \.self) { i in
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 3, height: self.phase ? self.heights[0][i] : self.heights[1][i])
                    .animation(
                        .easeInOut(duration: 0.4 + Double(i) * 0.1).repeatForever(autoreverses: true),
                        value: self.phase
                    )
            }
        }
        .onAppear { self.phase = true }
    }
}
