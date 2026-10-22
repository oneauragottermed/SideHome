//
//  SideHomeModel.swift
//  SideHome
//

import SwiftUI

class SideHomeModel: ObservableObject {
    static let shared = SideHomeModel()
    static let chooseIPANotification = Notification.Name("SideHomeChooseIPA")
    private static let wallpaperURL = LCPath.docPath.appendingPathComponent("SideHomeWallpaper")

    /// Shows LiveContainer's original UI (Settings → Advanced) instead of the home screen.
    @Published var showLibrary = false
    /// A guest app is open full-screen, so the bottom-edge swipe belongs to SideHome first.
    @Published var appInFront = false
    /// Set by LCAppListView while an IPA is being installed (0...1), nil otherwise.
    @Published var installProgress: Float? = nil
    @Published var wallpaper: UIImage? = UIImage(contentsOfFile: SideHomeModel.wallpaperURL.path)
    /// Home-screen order as LCAppInfo.relativeBundlePath values. Apps not listed go at the end.
    @Published var iconOrder: [String] = UserDefaults.standard.stringArray(forKey: "SideHomeIconOrder") ?? [] {
        didSet { UserDefaults.standard.set(iconOrder, forKey: "SideHomeIconOrder") }
    }
    /// Icon badges set by guest apps, keyed by the guest's bundle identifier.
    @Published var badges: [String: Int] = UserDefaults.standard.dictionary(forKey: "SideHomeBadges") as? [String: Int] ?? [:] {
        didSet { UserDefaults.standard.set(badges, forKey: "SideHomeBadges") }
    }

    func setWallpaper(_ data: Data?) {
        if let data {
            try? data.write(to: Self.wallpaperURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: Self.wallpaperURL)
        }
        wallpaper = data.flatMap(UIImage.init(data:))
    }

    func orderedApps(_ apps: [LCAppModel]) -> [LCAppModel] {
        let rank = Dictionary(iconOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return apps.enumerated()
            .sorted { a, b in
                (rank[a.element.appInfo.relativeBundlePath ?? ""] ?? Int.max, a.offset) <
                (rank[b.element.appInfo.relativeBundlePath ?? ""] ?? Int.max, b.offset)
            }
            .map(\.element)
    }

    func move(_ app: LCAppModel, to target: LCAppModel, in apps: [LCAppModel]) {
        var order = orderedApps(apps).compactMap { $0.appInfo.relativeBundlePath }
        guard let from = order.firstIndex(of: app.appInfo.relativeBundlePath ?? ""),
              let to = order.firstIndex(of: target.appInfo.relativeBundlePath ?? "") else { return }
        order.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        iconOrder = order
    }
}

extension LCAppModel: Identifiable {}

// MARK: Liquid Glass

enum SideHomeGlassMode: String, CaseIterable {
    case clear, tinted, off
}

private struct SideHomeGlass<S: Shape>: ViewModifier {
    @AppStorage("SideHomeGlassMode") private var mode: SideHomeGlassMode = .clear
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), SharedModel.isLiquidGlassEnabled, mode != .off {
            content.glassEffect(mode == .clear ? Glass.clear : Glass.regular, in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}

/// A swipe up from the bottom edge, for built-in apps (guest apps use SideHomeAppHost's own gesture).
private struct SideHomeHomeGesture: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.overlay {
            VStack {
                Spacer()
                Color.clear
                    .frame(height: 30)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 10).onEnded { value in
                        if value.translation.height < -60 { action() }
                    })
            }
            .ignoresSafeArea()
        }
    }
}

extension View {
    func sideHomeGlass<S: Shape>(_ shape: S) -> some View {
        modifier(SideHomeGlass(shape: shape))
    }

    func sideHomeHomeGesture(_ action: @escaping () -> Void) -> some View {
        modifier(SideHomeHomeGesture(action: action))
    }

    /// While on, the first swipe from the bottom goes to SideHome and only a second one leaves to real iOS.
    @ViewBuilder func sideHomeDefersHomeGesture(_ enabled: Bool) -> some View {
        if #available(iOS 16.0, *) {
            defersSystemGestures(on: enabled ? .bottom : [])
        } else {
            self
        }
    }

    @ViewBuilder func sideHomeZoomSource(id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder func sideHomeZoom(id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
