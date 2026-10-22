//
//  SideHomeModel.swift
//  SideHome
//

import SwiftUI

enum SideHomeOverlay: Identifiable {
    case notificationCenter, controlCenter, search
    var id: Self { self }
}

struct SideHomeFolder: Codable, Hashable, Identifiable {
    var id = UUID().uuidString
    var name: String
    /// LCAppInfo.relativeBundlePath of each app, in order
    var apps: [String]
    var orderKey: String { "folder:\(id)" }
}

/// One spot on the home-screen grid.
enum SideHomeItem: Hashable, Identifiable {
    case app(LCAppModel)
    case folder(SideHomeFolder)

    var id: String { orderKey }
    /// The key stored in SideHomeModel.iconOrder
    var orderKey: String {
        switch self {
        case .app(let app): return app.appInfo.relativeBundlePath ?? ""
        case .folder(let folder): return folder.orderKey
        }
    }
}

class SideHomeModel: ObservableObject {
    static let shared = SideHomeModel()
    static let chooseIPANotification = Notification.Name("SideHomeChooseIPA")
    private static let wallpaperURL = LCPath.docPath.appendingPathComponent("SideHomeWallpaper")

    /// Shows LiveContainer's original UI (Settings → Advanced) instead of the home screen.
    @Published var showLibrary = false
    /// A guest app is open full-screen, so the bottom-edge swipe belongs to SideHome first.
    @Published var appInFront = false
    /// Notification Center, Control Center or Search, shown over everything including guest apps.
    @Published var overlay: SideHomeOverlay?
    /// Set by LCAppListView while an IPA is being installed (0...1), nil otherwise.
    @Published var installProgress: Float? = nil
    @Published var wallpaper: UIImage? = UIImage(contentsOfFile: SideHomeModel.wallpaperURL.path)
    /// Home-screen order as SideHomeItem.orderKey values. Items not listed go at the end.
    @Published var iconOrder: [String] = UserDefaults.standard.stringArray(forKey: "SideHomeIconOrder") ?? [] {
        didSet { UserDefaults.standard.set(iconOrder, forKey: "SideHomeIconOrder") }
    }
    /// Icon badges set by guest apps, keyed by the guest's bundle identifier.
    @Published var badges: [String: Int] = UserDefaults.standard.dictionary(forKey: "SideHomeBadges") as? [String: Int] ?? [:] {
        didSet { UserDefaults.standard.set(badges, forKey: "SideHomeBadges") }
    }
    @Published var folders: [SideHomeFolder] = SideHomeModel.load("SideHomeFolders") ?? [] {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(folders), forKey: "SideHomeFolders") }
    }

    private static func load<T: Decodable>(_ key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    func setWallpaper(_ data: Data?) {
        if let data {
            try? data.write(to: Self.wallpaperURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: Self.wallpaperURL)
        }
        wallpaper = data.flatMap(UIImage.init(data:))
    }

    /// Shows or hides an overlay without the default sheet slide; the overlays animate themselves.
    func present(_ overlay: SideHomeOverlay?) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { self.overlay = overlay }
    }

    // MARK: Grid

    /// Apps outside folders plus non-empty folders, in home-screen order.
    func items(_ apps: [LCAppModel]) -> [SideHomeItem] {
        let foldered = Set(folders.flatMap(\.apps))
        let loose = apps.filter { !foldered.contains($0.appInfo.relativeBundlePath ?? "") }.map(SideHomeItem.app)
        let nonEmpty = folders.filter { !self.apps(in: $0, from: apps).isEmpty }.map(SideHomeItem.folder)
        let rank = Dictionary(iconOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return (loose + nonEmpty).enumerated()
            .sorted { a, b in
                (rank[a.element.orderKey] ?? Int.max, a.offset) < (rank[b.element.orderKey] ?? Int.max, b.offset)
            }
            .map(\.element)
    }

    func move(_ key: String, to targetKey: String, in apps: [LCAppModel]) {
        var order = items(apps).map(\.orderKey)
        guard let from = order.firstIndex(of: key), let to = order.firstIndex(of: targetKey) else { return }
        order.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        iconOrder = order
    }

    // MARK: Folders

    func apps(in folder: SideHomeFolder, from apps: [LCAppModel]) -> [LCAppModel] {
        folder.apps.compactMap { key in apps.first { $0.appInfo.relativeBundlePath == key } }
    }

    func addToFolder(_ appKey: String, folderID: String) {
        var updated = folders
        for index in updated.indices {
            updated[index].apps.removeAll { $0 == appKey }
        }
        if let index = updated.firstIndex(where: { $0.id == folderID }) {
            updated[index].apps.append(appKey)
        }
        folders = updated.filter { !$0.apps.isEmpty }
    }

    func createFolder(named name: String, with appKey: String) {
        removeFromFolders(appKey)
        let folder = SideHomeFolder(name: name.isEmpty ? "Folder" : name, apps: [appKey])
        folders.append(folder)
        // Put the new folder where the app was
        if let index = iconOrder.firstIndex(of: appKey) {
            iconOrder.insert(folder.orderKey, at: index)
        }
    }

    func removeFromFolders(_ appKey: String) {
        var updated = folders
        for index in updated.indices {
            updated[index].apps.removeAll { $0 == appKey }
        }
        folders = updated.filter { !$0.apps.isEmpty }
    }

    func renameFolder(_ id: String, to name: String) {
        guard let index = folders.firstIndex(where: { $0.id == id }), !name.isEmpty else { return }
        folders[index].name = name
    }

    /// Removes the folder; its apps go back onto the home screen.
    func deleteFolder(_ id: String) {
        folders.removeAll { $0.id == id }
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

    /// Swipes from these edges go to SideHome first; only a second swipe reaches real iOS.
    @ViewBuilder func sideHomeDefersSystemGestures(_ edges: Edge.Set) -> some View {
        if #available(iOS 16.0, *) {
            defersSystemGestures(on: edges)
        } else {
            self
        }
    }

    /// Lets a fullScreenCover show what's behind it.
    @ViewBuilder func sideHomeClearPresentation() -> some View {
        if #available(iOS 16.4, *) {
            presentationBackground(.clear)
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
