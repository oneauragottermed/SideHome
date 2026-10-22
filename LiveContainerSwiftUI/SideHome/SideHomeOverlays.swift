//
//  SideHomeOverlays.swift
//  SideHome
//
//  Notification Center, Control Center and Search. Presented from SideHomeRootView without the
//  sheet animation, so each one animates itself in and calls `close` once it has animated out.
//

import AVFoundation
import MediaPlayer
import SwiftUI
import UserNotifications

struct SideHomeOverlayView: View {
    let overlay: SideHomeOverlay

    var body: some View {
        Group {
            switch overlay {
            case .notificationCenter:
                SideHomeNotificationCenter(close: close)
            case .controlCenter:
                SideHomeControlCenter(close: close)
            case .search:
                SideHomeSearch(close: close)
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private func close() {
        SideHomeModel.shared.present(nil)
    }
}

/// Animates an overlay in on appear; `dismiss` animates it out, then calls `close`.
private struct SideHomeOverlayTransition: ViewModifier {
    let fromTop: Bool
    let close: () -> Void
    @Binding var shown: Bool

    func body(content: Content) -> some View {
        content
            .offset(y: fromTop && !shown ? -900 : 0)
            .opacity(shown ? 1 : 0)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .opacity(shown ? 1 : 0)
            )
            .onAppear {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) { shown = true }
            }
            .sideHomeHomeGesture { SideHomeOverlayTransition.dismiss($shown, close: close) }
    }

    static func dismiss(_ shown: Binding<Bool>, close: @escaping () -> Void) {
        withAnimation(.easeIn(duration: 0.22)) { shown.wrappedValue = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24, execute: close)
    }
}

// MARK: Notification Center

private struct SideHomeNotificationCenter: View {
    let close: () -> Void
    @State private var shown = false
    @State private var notifications: [UNNotification] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                VStack(spacing: 0) {
                    Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.title3.weight(.semibold))
                    Text(Date(), style: .time)
                        .font(.system(size: 76, weight: .bold, design: .rounded))
                }
                .padding(.top, 24)
                .padding(.bottom, 16)

                if notifications.isEmpty {
                    Text("No Older Notifications")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                } else {
                    HStack {
                        Text("Notification Center").font(.title3.weight(.bold))
                        Spacer()
                        Button("Clear All") {
                            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                            withAnimation { notifications = [] }
                        }
                    }
                    .padding(.horizontal, 6)
                    ForEach(notifications, id: \.request.identifier) { notification in
                        row(notification)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 60)
        }
        .modifier(SideHomeOverlayTransition(fromTop: true, close: close, shown: $shown))
        .onAppear(perform: load)
    }

    private func load() {
        UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
            DispatchQueue.main.async {
                notifications = delivered.sorted { $0.date > $1.date }
            }
        }
    }

    private func row(_ notification: UNNotification) -> some View {
        let content = notification.request.content
        let bundleId = content.userInfo[SideHomeHostService.appKey] as? String
        let app = bundleId.flatMap { SideHomeHostService.app(bundleId: $0) }
        let savedTitle = content.userInfo[SideHomeHostService.titleKey] as? String ?? content.title
        let title = savedTitle.isEmpty ? (app?.displayName ?? content.title) : savedTitle
        return Button {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
            SideHomeOverlayTransition.dismiss($shown, close: close)
            if let bundleId {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { SideHomeHostService.open(bundleId: bundleId) }
            }
        } label: {
            HStack(alignment: .top, spacing: 11) {
                Image(uiImage: app?.appInfo.iconIsDarkIcon(false) ?? UIImage())
                    .resizable()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(notification.date, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if !content.body.isEmpty {
                        Text(content.body)
                            .font(.subheadline)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sideHomeGlass(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: Control Center

private struct SideHomeControlCenter: View {
    let close: () -> Void
    @AppStorage("SideHomeGlassMode") private var glassMode: SideHomeGlassMode = .clear
    @State private var shown = false
    @State private var brightness = UIScreen.main.brightness
    @State private var torchOn = AVCaptureDevice.default(for: .video)?.torchMode == .on

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                LazyVGrid(columns: [GridItem(.fixed(70), spacing: 12), GridItem(.fixed(70))], spacing: 12) {
                    tile("Flashlight", "flashlight.on.fill", on: torchOn, action: toggleTorch)
                    tile("Glass: \(glassMode.rawValue.capitalized)", "circle.hexagongrid.fill", on: glassMode != .off, action: cycleGlass)
                    tile("App Switcher", "square.stack.3d.up.fill", on: false) {
                        SideHomeOverlayTransition.dismiss($shown, close: close)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { SideHomeAppHost.showSwitcher() }
                    }
                    tile("Close All Apps", "xmark.circle.fill", on: false) {
                        SideHomeAppHost.terminateAll()
                    }
                }
                .padding(12)
                .sideHomeGlass(RoundedRectangle(cornerRadius: 30, style: .continuous))

                SideHomeVerticalSlider(value: $brightness, symbol: "sun.max.fill")
                    .frame(width: 76, height: 196)
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.2.fill")
                SideHomeVolumeSlider()
                    .frame(height: 34)
            }
            .padding(.horizontal, 18)
            .frame(width: 340, height: 64)
            .sideHomeGlass(RoundedRectangle(cornerRadius: 30, style: .continuous))

            Spacer()
        }
        .padding(.top, 70)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { SideHomeOverlayTransition.dismiss($shown, close: close) }
        .modifier(SideHomeOverlayTransition(fromTop: true, close: close, shown: $shown))
        .onChange(of: brightness) { value in
            UIScreen.main.brightness = value
        }
    }

    private func tile(_ title: String, _ symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(on ? .black : .white)
                    .frame(width: 56, height: 56)
                    .background(on ? Color.white : Color.white.opacity(0.15), in: Circle())
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 70)
        }
        .buttonStyle(.plain)
    }

    private func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch,
              (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = torchOn ? .off : .on
        device.unlockForConfiguration()
        torchOn.toggle()
    }

    private func cycleGlass() {
        let modes = SideHomeGlassMode.allCases
        glassMode = modes[((modes.firstIndex(of: glassMode) ?? 0) + 1) % modes.count]
    }
}

private struct SideHomeVerticalSlider: View {
    @Binding var value: CGFloat
    let symbol: String

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Rectangle().fill(Color.white.opacity(0.15))
                Rectangle()
                    .fill(Color.white)
                    .frame(height: geometry.size.height * value)
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(value > 0.15 ? .gray : .white)
                    .padding(.bottom, 16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                value = min(max(1 - drag.location.y / geometry.size.height, 0), 1)
            })
        }
    }
}

/// The system volume slider (apps can't set the volume any other way).
private struct SideHomeVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.tintColor = .white
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

// MARK: Search

private struct SideHomeSearch: View {
    let close: () -> Void
    @EnvironmentObject private var sharedModel: SharedModel
    @State private var shown = false
    @State private var query = ""
    @FocusState private var focused: Bool
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)

    private var results: [LCAppModel] {
        query.isEmpty
            ? Array(sharedModel.apps.prefix(8))
            : sharedModel.apps.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search", text: $query)
                        .focused($focused)
                        .submitLabel(.go)
                        .onSubmit {
                            if let first = results.first { open(first) }
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .sideHomeGlass(Capsule())
                Button("Cancel") { SideHomeOverlayTransition.dismiss($shown, close: close) }
                    .foregroundColor(.white)
            }

            Text(query.isEmpty ? "Suggestions" : (results.isEmpty ? "No Results" : "Apps"))
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 22) {
                ForEach(results) { app in
                    Button {
                        open(app)
                    } label: {
                        SideHomeIcon(label: app.displayName) {
                            Image(uiImage: app.appInfo.iconIsDarkIcon(false) ?? UIImage())
                                .resizable()
                        }
                    }
                    .buttonStyle(SideHomeIconButtonStyle())
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .modifier(SideHomeOverlayTransition(fromTop: false, close: close, shown: $shown))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focused = true }
        }
    }

    private func open(_ app: LCAppModel) {
        SideHomeOverlayTransition.dismiss($shown, close: close)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Task { try? await app.runApp(multitask: true) }
        }
    }
}
