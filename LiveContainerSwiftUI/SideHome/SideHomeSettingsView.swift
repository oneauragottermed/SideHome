//
//  SideHomeSettingsView.swift
//  SideHome
//

import SwiftUI
import PhotosUI

/// The built-in Settings app, laid out like iOS Settings.
struct SideHomeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sharedModel: SharedModel
    @ObservedObject private var home = SideHomeModel.shared
    @AppStorage("SideHomeGlassMode") private var glassMode: SideHomeGlassMode = .clear
    @AppStorage("SideHomeShowIconLabels") private var showLabels = true

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack(spacing: 14) {
                        SideHomeSettingsIcon(symbol: "house.fill", color: .blue, size: 60)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SideHome").font(.title2.weight(.semibold))
                            Text("Your sideloaded apps, at home").font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    if #available(iOS 16.0, *) {
                        NavigationLink {
                            SideHomeWallpaperView()
                        } label: {
                            row("Wallpaper", "photo.on.rectangle", .cyan)
                        }
                    }
                    NavigationLink {
                        liquidGlass
                    } label: {
                        row("Liquid Glass", "circle.hexagongrid.fill", .blue)
                    }
                    NavigationLink {
                        homeScreen
                    } label: {
                        row("Home Screen", "apps.iphone", .indigo)
                    }
                }

                Section {
                    libraryRow("App Library", "square.stack.3d.up.fill", .orange, tab: .apps)
                    libraryRow("LiveContainer Settings", "gearshape.2.fill", .gray, tab: .settings)
                    libraryRow("Tweaks", "wrench.and.screwdriver.fill", .pink, tab: .tweaks)
                    libraryRow("Sources", "books.vertical.fill", .green, tab: .sources)
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("LiveContainer’s original screens: JIT, certificates, containers, tweaks and app sources.")
                }

                Section {
                    NavigationLink {
                        about
                    } label: {
                        row("About", "info", .gray)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
        .navigationViewStyle(.stack)
        .sideHomeDefersSystemGestures(.bottom)
        .sideHomeHomeGesture { dismiss() }
    }

    private var liquidGlass: some View {
        List {
            Section {
                ZStack {
                    SideHomeWallpaper()
                    HStack(spacing: 20) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color.white.opacity(0.85))
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(14)
                    .sideHomeGlass(RoundedRectangle(cornerRadius: 26, style: .continuous))
                }
                .frame(height: 150)
                .listRowInsets(EdgeInsets())
            }
            Section {
                Picker("Liquid Glass", selection: $glassMode) {
                    Text("Clear").tag(SideHomeGlassMode.clear)
                    Text("Tinted").tag(SideHomeGlassMode.tinted)
                    Text("Off").tag(SideHomeGlassMode.off)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text("Liquid Glass needs iOS 26 or later. When it’s off or unavailable, the dock uses a frosted material.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Liquid Glass")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var homeScreen: some View {
        List {
            Toggle("Show App Names", isOn: $showLabels)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Home Screen")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var about: some View {
        List {
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Apps")
                    Spacer()
                    Text("\(sharedModel.apps.count)").foregroundColor(.secondary)
                }
            }
            Section {
                Link("SideHome on GitHub", destination: URL(string: "https://github.com/oneauragottermed/SideHome")!)
                Link("Based on LiveContainer", destination: URL(string: "https://github.com/LiveContainer/LiveContainer")!)
            } footer: {
                Text("SideHome is free software under the GNU AGPL v3.0, built on LiveContainer.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ symbol: String, _ color: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            SideHomeSettingsIcon(symbol: symbol, color: color, size: 29)
        }
    }

    /// Opens one of LiveContainer's original tabs in place of the home screen.
    private func libraryRow(_ title: String, _ symbol: String, _ color: Color, tab: LCTabIdentifier) -> some View {
        Button {
            sharedModel.selectedTab = tab
            home.showLibrary = true
            dismiss()
        } label: {
            HStack {
                row(title, symbol, color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .foregroundColor(.primary)
    }
}

private struct SideHomeSettingsIcon: View {
    let symbol: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
    }
}

@available(iOS 16.0, *)
private struct SideHomeWallpaperView: View {
    @ObservedObject private var home = SideHomeModel.shared
    @State private var item: PhotosPickerItem?

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    SideHomeWallpaper()
                        .frame(width: 150, height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            Section {
                PhotosPicker(selection: $item, matching: .images) {
                    Text("Choose a New Wallpaper")
                }
                if home.wallpaper != nil {
                    Button("Use Default Wallpaper", role: .destructive) {
                        home.setWallpaper(nil)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Wallpaper")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: item) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    home.setWallpaper(data)
                }
            }
        }
    }
}
