//
//  SideHomeView.swift
//  SideHome
//

import SwiftUI
import UniformTypeIdentifiers

/// App root: the SideHome home screen on top of LiveContainer's original UI.
struct SideHomeRootView: View {
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
        .sideHomeDefersHomeGesture(home.appInFront)
    }
}

struct SideHomeScreen: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @ObservedObject private var home = SideHomeModel.shared
    @AppStorage("SideHomeShowIconLabels") private var showLabels = true
    @State private var settingsOpen = false
    @State private var editing = false
    @State private var draggingApp: LCAppModel?
    @State private var settingsApp: LCAppModel?
    @State private var appToDelete: LCAppModel?
    @State private var errorMessage: String?
    @Namespace private var zoom

    private let iconsPerPage = 24
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)

    private var pages: [[LCAppModel]] {
        let apps = home.orderedApps(sharedModel.apps)
        guard !apps.isEmpty else { return [[]] }
        return stride(from: 0, to: apps.count, by: iconsPerPage).map {
            Array(apps[$0..<min($0 + iconsPerPage, apps.count)])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                ForEach(pages.indices, id: \.self) { page in
                    LazyVGrid(columns: columns, spacing: 26) {
                        ForEach(pages[page]) { app in
                            appIcon(app)
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

            dock
        }
        .background { SideHomeWallpaper() }
        .overlay(alignment: .topTrailing) {
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
        .fullScreenCover(isPresented: $settingsOpen) {
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
    }

    // MARK: Icons

    private func appIcon(_ app: LCAppModel) -> some View {
        let key = app.appInfo.relativeBundlePath ?? ""
        return Button {
            guard !editing else { return }
            Task {
                do {
                    try await app.runApp(multitask: true)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } label: {
            SideHomeIcon(label: showLabels ? app.displayName : nil, frameKey: key) {
                Image(uiImage: app.appInfo.iconIsDarkIcon(false) ?? UIImage())
                    .resizable()
            }
        }
        .buttonStyle(SideHomeIconButtonStyle())
        .modifier(SideHomeJiggle(active: editing))
        .contextMenu {
            Button {
                settingsApp = app
            } label: {
                Label("App Settings", systemImage: "gearshape")
            }
            Button {
                withAnimation { editing = true }
            } label: {
                Label("Edit Home Screen", systemImage: "apps.iphone")
            }
            Button(role: .destructive) {
                appToDelete = app
            } label: {
                Label("Delete App", systemImage: "trash")
            }
        }
        // Long-press then drag reorders icons, like SpringBoard
        .onDrag {
            draggingApp = app
            withAnimation { editing = true }
            return NSItemProvider(object: key as NSString)
        }
        .onDrop(of: [.text], delegate: SideHomeDropDelegate(target: app, dragging: $draggingApp) { dragged, target in
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

    private var dock: some View {
        HStack(spacing: 28) {
            SideHomeBuiltInIcon(symbol: "gearshape.fill", colors: [Color(white: 0.62), Color(white: 0.38)]) {
                settingsOpen = true
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
    }

    // MARK: Actions

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
                LinearGradient(colors: [Color(red: 0.12, green: 0.18, blue: 0.48),
                                        Color(red: 0.52, green: 0.22, blue: 0.62),
                                        Color(red: 0.96, green: 0.48, blue: 0.42)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
    }
}

struct SideHomeIcon<Content: View>: View {
    var label: String?
    /// When set, the icon reports its on-screen frame so a launched app can zoom out of it.
    var frameKey: String? = nil
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

private struct SideHomeIconButtonStyle: ButtonStyle {
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
    let target: LCAppModel
    @Binding var dragging: LCAppModel?
    let move: (LCAppModel, LCAppModel) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            move(dragging, target)
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
