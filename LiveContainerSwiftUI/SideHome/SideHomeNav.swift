//
//  SideHomeNav.swift
//  SideHome
//
//  The glass navigation island (Back, Home, Forward). It lives in its own small window so it floats
//  above running guest apps. It opens when an app opens, closes when you go home, and the glass
//  button on the home screen toggles it.
//

import Combine
import SwiftUI

enum SideHomeNav {
    private static var window: UIWindow?
    private static var subscriptions: Set<AnyCancellable> = []
    private static let size = CGSize(width: 230, height: 64)
    /// On the home screen the island sits just above the dock instead of at the very bottom
    private static let homeLift: CGFloat = 104

    static func install() {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .normal + 1
        window.backgroundColor = .clear
        let host = UIHostingController(rootView: SideHomeNavIsland())
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = true
        self.window = window

        let home = SideHomeModel.shared
        // @Published fires before the value changes, so read the new state on the next run loop turn
        home.$navOpen.removeDuplicates().sink { open in
            DispatchQueue.main.async { show(open) }
        }.store(in: &subscriptions)
        home.$appInFront.removeDuplicates().sink { _ in
            DispatchQueue.main.async { UIView.animate(withDuration: 0.3) { layout() } }
        }.store(in: &subscriptions)
    }

    private static func layout() {
        guard let window, let scene = window.windowScene else { return }
        let bounds = scene.screen.bounds
        let safeBottom = scene.windows.first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 0
        let lift = SideHomeModel.shared.appInFront ? 0 : homeLift
        // Frame changes are only reliable with an identity transform
        let transform = window.transform
        window.transform = .identity
        window.frame = CGRect(x: (bounds.width - size.width) / 2,
                              y: bounds.height - safeBottom - size.height - lift,
                              width: size.width, height: size.height)
        window.transform = transform
    }

    private static func show(_ open: Bool) {
        guard let window else { return }
        let shrunk = CGAffineTransform(scaleX: 0.85, y: 0.85)
        if open {
            window.transform = .identity
            layout()
            window.transform = shrunk
            window.alpha = 0
            window.isHidden = false
        }
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            window.alpha = open ? 1 : 0
            window.transform = open ? .identity : shrunk
        } completion: { _ in
            // Hidden when closed so it doesn't block touches on the app underneath
            if !SideHomeModel.shared.navOpen { window.isHidden = true }
        }
    }
}

private struct SideHomeNavIsland: View {
    @ObservedObject private var home = SideHomeModel.shared

    var body: some View {
        HStack(spacing: 30) {
            button("chevron.backward", label: "Back", enabled: home.canGoBack, action: SideHomeAppHost.goBack)
            button("house.fill", label: "Home", enabled: true, action: SideHomeAppHost.goHome)
            button("chevron.forward", label: "Forward", enabled: home.canGoForward, action: SideHomeAppHost.goForward)
        }
        .padding(.horizontal, 26)
        .frame(height: 56)
        .sideHomeGlass(Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .dark)
    }

    private func button(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }
}
