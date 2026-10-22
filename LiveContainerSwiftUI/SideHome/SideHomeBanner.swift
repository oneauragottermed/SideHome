//
//  SideHomeBanner.swift
//  SideHome
//
//  iOS-style notification banner shown while SideHome is open. It lives in its own small window
//  at the top so it appears above running guest apps too.
//

import SwiftUI

enum SideHomeBanner {
    private static var window: UIWindow?

    static func show(bundleId: String, title: String, message: String) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }
        let app = SideHomeHostService.app(bundleId: bundleId)

        window?.isHidden = true
        // Only as tall as a banner, so touches below it still reach SideHome
        let newWindow = UIWindow(windowScene: scene)
        newWindow.frame = CGRect(x: 0, y: 0, width: scene.screen.bounds.width, height: 190)
        newWindow.windowLevel = .statusBar
        newWindow.backgroundColor = .clear
        let banner = SideHomeBannerView(
            icon: app?.appInfo.iconIsDarkIcon(false),
            title: title.isEmpty ? (app?.displayName ?? "SideHome") : title,
            message: message,
            onTap: { [weak newWindow] in
                hide(newWindow)
                SideHomeHostService.open(bundleId: bundleId)
            },
            onDismiss: { [weak newWindow] in hide(newWindow) }
        )
        let host = UIHostingController(rootView: banner)
        host.view.backgroundColor = .clear
        newWindow.rootViewController = host
        newWindow.isHidden = false
        window = newWindow
    }

    private static func hide(_ banner: UIWindow?) {
        guard let banner, banner === window else { return }
        banner.isHidden = true
        window = nil
    }
}

private struct SideHomeBannerView: View {
    let icon: UIImage?
    let title: String
    let message: String
    let onTap: () -> Void
    let onDismiss: () -> Void
    @State private var shown = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 11) {
            Image(uiImage: icon ?? UIImage())
                .resizable()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("now")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !message.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .lineLimit(4)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .sideHomeGlass(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .gesture(DragGesture(minimumDistance: 5)
            .onChanged { dragOffset = min($0.translation.height, 0) }
            .onEnded { value in
                if value.translation.height < -30 {
                    dismiss()
                } else {
                    withAnimation(.spring()) { dragOffset = 0 }
                }
            })
        .offset(y: shown ? dragOffset : -190)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { shown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { dismiss() }
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.25)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: onDismiss)
    }
}
