//
//  SideHomeView.swift
//  SideHome
//

import SwiftUI
import UniformTypeIdentifiers

/// App root: the SideHome home screen on top of LiveContainer's original UI.
struct SideHomeRootView: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @ObservedObject private var home = SideHomeModel.shared

    var body: some View {
        ZStack {
            // LiveContainer's own UI stays mounted even while hidden: it runs the startup checks, handles
            // deep links (certificate import, installs) and owns the install flow.
            LCTabView()
                .safeAreaInset(edge: .top) {
                    HStack {
                        Button {
                            home.showLibrary = false
                        } label: {
                            Label("Home", systemImage: "house.fill")
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
                }
                .opacity(home.showLibrary ? 1 : 0)
                .allowsHitTesting(home.showLibrary)

            if !home.showLibrary {
                SideHomeScreen()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: home.showLibrary)
        .sideHomeDefersSystemGestures(deferredEdges)
        .onAppear { SideHomeNav.install() }
        // Presented, so it covers running guest apps too
        .fullScreenCover(item: $home.overlay) { overlay in
            SideHomeOverlayView(overlay: overlay)
                .environmentObject(sharedModel)
                .sideHomeClearPresentation()
        }
    }

    /// Top swipes open SideHome's Notification/Control Center; bottom swipes in an app go home.
    private var deferredEdges: Edge.Set {
        if home.showLibrary { return [] }
        return home.appInFront ? [.top, .bottom] : [.top]
    }
}

struct SideHomeScreen: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @ObservedObject private var home = SideHomeModel.shared
    @AppStorage("SideHomeShowIconLabels") private var showLabels = true
    @State private var editing = false
    @State private var draggingKey: String?
    @State private var settingsApp: LCAppModel?
    @State private var appToDelete: LCAppModel?
    @State private var errorMessage: String?
    @State private var openFolderID: String?
    @State private var newFolderApp: LCAppModel?
    @State private var renamingFolderID: String?
    @State private var folderName = ""
    @Namespace private var zoom

    private let iconsPerPage = 24
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)

    private var pages: [[SideHomeItem]] {
        let items = home.items(sharedModel.apps)
        guard !items.isEmpty else { return [[]] }
        return stride(from: 0, to: items.count, by: iconsPerPage).map {
            Array(items[$0..<min($0 + iconsPerPage, items.count)])
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                grid
                bottomRow
                dock
            }
            .background { SideHomeWallpaper() }
            .overlay { SideHomeTopEdgeSwipe() }
            .overlay(alignment: .topTrailing) { doneButton }

            folderOverlay
            dialogs
        }
        .fullScreenCover(isPresented: $home.settingsOpen) {
            SideHomeSettingsView()
                .environmentObject(sharedModel)
                .sideHomeZoom(id: "settings", in: zoom)
        }
        .sheet(item: $settingsApp) { app in
            NavigationView {
                LCAppSettingsView(model: app)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { settingsApp = nil }
                        }
                    }
            }
            .navigationViewStyle(.stack)
            .environmentObject(sharedModel)
        }
    }

    // MARK: Layout

    private var grid: some View {
        TabView {
            ForEach(pages.indices, id: \.self) { page in
                LazyVGrid(columns: columns, spacing: 26) {
                    ForEach(pages[page]) { item in
                        itemView(item)
                    }
                    if page == pages.count - 1, let progress = home.installProgress {
                        installingIcon(progress)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: pages.count > 1 ? .always : .never))
    }

    @ViewBuilder private func itemView(_ item: SideHomeItem) -> some View {
        switch item {
        case .app(let app):
            appIcon(app, inFolder: nil)
        case .folder(let folder):
            folderIcon(folder)
        }
    }

    /// The Search pill, with the glass button that toggles the navigation island on the left.
    private var bottomRow: some View {
        ZStack {
            Button {
                home.present(.search)
            } label: {
                Label("Search", systemImage: "magnifyingglass")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .sideHomeGlass(Capsule())
            }
            HStack {
                Button {
                    home.navOpen.toggle()
                } label: {
                    Image(systemName: home.navOpen ? "xmark" : "arrow.left.arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .sideHomeGlass(Circle())
                }
                .accessibilityLabel(home.navOpen ? "Hide Navigation" : "Show Navigation")
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }

    private var dock: some View {
        HStack(spacing: 28) {
            SideHomeBuiltInIcon(symbol: "gearshape.fill", colors: [Color(white: 0.62), Color(white: 0.38)]) {
                home.settingsOpen = true
            }
            .sideHomeZoomSource(id: "settings", in: zoom)

            SideHomeBuiltInIcon(symbol: "square.and.arrow.down.fill", colors: [.blue, .indigo]) {
                chooseIPA()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .sideHomeGlass(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
        // Swiping up on the dock opens the app switcher (the bottom edge itself belongs to iOS here)
        .gesture(DragGesture(minimumDistance: 20).onEnded { value in
            if value.translation.height < -40 {
                SideHomeAppHost.showSwitcher()
            }
        })
    }

    @ViewBuilder private var doneButton: some View {
        if editing {
            Button("Done") {
                withAnimation { editing = false }
            }
            .font(.body.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .sideHomeGlass(Capsule())
            .padding(.trailing, 16)
        }
    }

    @ViewBuilder private var folderOverlay: some View {
        if let id = openFolderID, let folder = home.folders.first(where: { $0.id == id }) {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture { closeFolder() }
                VStack(spacing: 18) {
                    Text(folder.name)
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3), spacing: 22) {
                        ForEach(home.apps(in: folder, from: sharedModel.apps)) { app in
                            appIcon(app, inFolder: folder)
                        }
                    }
                    .padding(.vertical, 22)
                    .padding(.horizontal, 8)
                    .sideHomeGlass(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    .padding(.horizontal, 32)
                }
            }
            .environment(\.colorScheme, .dark)
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
    }

    /// Zero-size host for the alerts, to keep the body's modifier chain short.
    private var dialogs: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .alert(Text("Delete “\(appToDelete?.displayName ?? "")”?"),
                   isPresented: Binding(get: { appToDelete != nil }, set: { if !$0 { appToDelete = nil } }),
                   presenting: appToDelete) { app in
                Button("Delete App", role: .destructive) { delete(app) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Deleting this app will also delete its data.")
            }
            .alert(Text("Couldn’t Open App"),
                   isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("New Folder", isPresented: Binding(get: { newFolderApp != nil }, set: { if !$0 { newFolderApp = nil } })) {
                TextField("Folder Name", text: $folderName)
                Button("Create") {
                    if let key = newFolderApp?.appInfo.relativeBundlePath {
                        withAnimation(.spring()) { home.createFolder(named: folderName, with: key) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Rename Folder", isPresented: Binding(get: { renamingFolderID != nil }, set: { if !$0 { renamingFolderID = nil } })) {
                TextField("Folder Name", text: $folderName)
                Button("Save") {
                    if let id = renamingFolderID { home.renameFolder(id, to: folderName) }
                }
                Button("Cancel", role: .cancel) {}
            }
    }

    // MARK: Icons

    private func appIcon(_ app: LCAppModel, inFolder folder: SideHomeFolder?) -> some View {
        let key = app.appInfo.relativeBundlePath ?? ""
        return Button {
            guard !editing else { return }
            launch(app)
        } label: {
            SideHomeIcon(label: showLabels ? app.displayName : nil, frameKey: key, badge: badge(for: app)) {
                Image(uiImage: app.appInfo.iconIsDarkIcon(false) ?? UIImage())
                    .resizable()
            }
        }
        .buttonStyle(SideHomeIconButtonStyle())
        .modifier(SideHomeJiggle(active: editing))
        .contextMenu { appMenu(app, key: key, folder: folder) }
        // Long-press then drag reorders icons, like SpringBoard
        .modifier(SideHomeReorder(key: key, enabled: folder == nil, dragging: $draggingKey, editing: $editing) { dragged, target in
            home.move(dragged, to: target, in: sharedModel.apps)
        })
    }

    @ViewBuilder private func appMenu(_ app: LCAppModel, key: String, folder: SideHomeFolder?) -> some View {
        Button {
            settingsApp = app
        } label: {
            Label("App Settings", systemImage: "gearshape")
        }
        if folder != nil {
            Button {
                withAnimation(.spring()) { home.removeFromFolders(key) }
            } label: {
                Label("Remove from Folder", systemImage: "folder.badge.minus")
            }
        } else {
            Menu {
                ForEach(home.folders) { target in
                    Button(target.name) {
                        withAnimation(.spring()) { home.addToFolder(key, folderID: target.id) }
                    }
                }
                Button {
                    folderName = ""
                    newFolderApp = app
                } label: {
                    Label("New Folder…", systemImage: "folder.badge.plus")
                }
            } label: {
                Label("Add to Folder", systemImage: "folder")
            }
            Button {
                withAnimation { editing = true }
            } label: {
                Label("Edit Home Screen", systemImage: "apps.iphone")
            }
        }
        Button(role: .destructive) {
            appToDelete = app
        } label: {
            Label("Delete App", systemImage: "trash")
        }
    }

    private func folderIcon(_ folder: SideHomeFolder) -> some View {
        let apps = home.apps(in: folder, from: sharedModel.apps)
        return Button {
            guard !editing else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { openFolderID = folder.id }
        } label: {
            SideHomeIcon(label: showLabels ? folder.name : nil, badge: apps.reduce(0) { $0 + badge(for: $1) }) {
                SideHomeFolderPreview(apps: apps)
            }
        }
        .buttonStyle(SideHomeIconButtonStyle())
        .modifier(SideHomeJiggle(active: editing))
        .contextMenu {
            Button {
                folderName = folder.name
                renamingFolderID = folder.id
            } label: {
                Label("Rename Folder", systemImage: "pencil")
            }
            Button {
                withAnimation { editing = true }
            } label: {
                Label("Edit Home Screen", systemImage: "apps.iphone")
            }
            Button(role: .destructive) {
                withAnimation(.spring()) { home.deleteFolder(folder.id) }
            } label: {
                Label("Remove Folder", systemImage: "folder.badge.minus")
            }
        }
        .modifier(SideHomeReorder(key: folder.orderKey, enabled: true, dragging: $draggingKey, editing: $editing) { dragged, target in
            home.move(dragged, to: target, in: sharedModel.apps)
        })
    }

    private func installingIcon(_ progress: Float) -> some View {
        SideHomeIcon(label: showLabels ? "Installing…" : nil) {
            ZStack {
                Color.black.opacity(0.35)
                Circle()
                    .trim(from: 0, to: CGFloat(max(progress, 0.02)))
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 30, height: 30)
                    .animation(.linear, value: progress)
            }
            .background(.ultraThinMaterial)
        }
    }

    private func badge(for app: LCAppModel) -> Int {
        home.badges[app.appInfo.bundleIdentifier() ?? ""] ?? 0
    }

    // MARK: Actions

    private func launch(_ app: LCAppModel) {
        if openFolderID != nil { closeFolder() }
        Task {
            do {
                try await app.runApp(multitask: true)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func closeFolder() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { openFolderID = nil }
    }

    /// LCAppListView owns the install flow; ask it to show its IPA picker.
    private func chooseIPA() {
        sharedModel.selectedTab = .apps
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: SideHomeModel.chooseIPANotification, object: nil)
        }
    }

    /// Same steps as LCAppBannerViewController.uninstall, always removing the app's data like iOS does.
    private func delete(_ app: LCAppModel) {
        SideHomeAppHost.terminateApps(bundleId: app.appInfo.relativeBundlePath ?? "")
        do {
            guard let bundlePath = app.appInfo.bundlePath() else {
                throw CocoaError(.fileNoSuchFile)
            }
            try FileManager.default.removeItem(atPath: bundlePath)
            sharedModel.apps.removeAll { $0 == app }
            home.badges[app.appInfo.bundleIdentifier() ?? ""] = nil
            home.removeFromFolders(app.appInfo.relativeBundlePath ?? "")
            for container in app.appInfo.containers {
                let dataUUID = container.folderName
                try? FileManager.default.removeItem(at: LCPath.dataPath.appendingPathComponent(dataUUID))
                LCUtils.removeAppKeychain(dataUUID: dataUUID)
                sharedModel.appDataFolderNames.removeAll { $0 == dataUUID }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: Components

struct SideHomeWallpaper: View {
    @ObservedObject private var home = SideHomeModel.shared

    var body: some View {
        GeometryReader { geometry in
            if let image = home.wallpaper {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            } else {
                LinearGradient(colors: [Color(white: 0.16), Color(white: 0.04)], startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
    }
}

struct SideHomeIcon<Content: View>: View {
    var label: String?
    /// When set, the icon reports its on-screen frame so a launched app can zoom out of it.
    var frameKey: String? = nil
    var badge = 0
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 5) {
            content
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .background(GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            if let frameKey { SideHomeAppHost.iconFrames[frameKey] = geometry.frame(in: .global) }
                        }
                        .onChange(of: geometry.frame(in: .global)) { frame in
                            if let frameKey { SideHomeAppHost.iconFrames[frameKey] = frame }
                        }
                })
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text(badge > 999 ? "999+" : "\(badge)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .frame(minWidth: 24, minHeight: 24)
                            .background(Color.red, in: Capsule())
                            .offset(x: 8, y: -8)
                    }
                }
            if let label {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .frame(width: 76)
            }
        }
    }
}

private struct SideHomeBuiltInIcon: View {
    let symbol: String
    let colors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SideHomeIcon {
                ZStack {
                    LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                    Image(systemName: symbol)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(SideHomeIconButtonStyle())
    }
}

struct SideHomeIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? -0.3 : 0)
    }
}

private struct SideHomeJiggle: ViewModifier {
    let active: Bool
    @State private var tilt = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active ? (tilt ? 2 : -2) : 0))
            .animation(active ? .easeInOut(duration: 0.13).repeatForever(autoreverses: true) : .default, value: tilt)
            .onAppear { if active { tilt.toggle() } }
            .onChange(of: active) { isActive in
                if isActive { tilt.toggle() }
            }
    }
}

private struct SideHomeDropDelegate: DropDelegate {
    let targetKey: String
    @Binding var dragging: String?
    let move: (String, String) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != targetKey else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            move(dragging, targetKey)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

/// Drag to reorder: long-press lifts the icon (and enters edit mode), dropping on another icon moves it there.
private struct SideHomeReorder: ViewModifier {
    let key: String
    let enabled: Bool
    @Binding var dragging: String?
    @Binding var editing: Bool
    let move: (String, String) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .onDrag {
                    dragging = key
                    withAnimation { editing = true }
                    return NSItemProvider(object: key as NSString)
                }
                .onDrop(of: [.text], delegate: SideHomeDropDelegate(targetKey: key, dragging: $dragging, move: move))
        } else {
            content
        }
    }
}

/// Folder icon: a glass tile with up to nine mini icons.
private struct SideHomeFolderPreview: View {
    let apps: [LCAppModel]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(14), spacing: 4), count: 3), spacing: 4) {
            ForEach(Array(apps.prefix(9))) { app in
                Image(uiImage: app.appInfo.iconIsDarkIcon(false) ?? UIImage())
                    .resizable()
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
            }
        }
        .frame(width: 62, height: 62)
        .sideHomeGlass(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Swipe down from the status bar: the left half opens Notification Center, the right half Control Center.
/// Fills the screen so the strip lands exactly on the status bar; the rest isn't hit-testable.
struct SideHomeTopEdgeSwipe: View {
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Color.clear
                    .frame(height: 44)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 10).onEnded { value in
                        guard value.translation.height > 40 else { return }
                        let leftHalf = value.startLocation.x < geometry.size.width / 2
                        SideHomeModel.shared.present(leftHalf ? .notificationCenter : .controlCenter)
                    })
                Spacer()
            }
        }
        .ignoresSafeArea()
    }
}
