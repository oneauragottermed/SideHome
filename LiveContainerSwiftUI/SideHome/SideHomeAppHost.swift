//
//  SideHomeAppHost.swift
//  SideHome
//
//  Shows multitask guest apps full-screen on top of the SideHome home screen,
//  zooming them out of / back into their home-screen icon like SpringBoard does.
//

import UIKit

@objc class SideHomeAppHost: NSObject {
    /// Icon frames in window coordinates, keyed by LCAppInfo.relativeBundlePath. Reported by SideHomeScreen.
    static var iconFrames: [String: CGRect] = [:]
    /// Running apps keyed by dataUUID. Values are SideHomeAppContainer (typed loosely because it's iOS 16+).
    private static var running: [String: UIViewController] = [:]
    /// dataUUIDs of running apps, most recently opened first (app switcher order).
    private static var recent: [String] = []
    /// Back / Forward history of opened apps (dataUUIDs) and the position of the current one.
    private static var history: [String] = []
    private static var historyIndex = -1
    private static var navigating = false
    /// dataUUID of the app shown full-screen, if any
    private static var front: String?

    /// Called from LCUtils.launchMultitaskGuestApp instead of opening a floating window.
    @objc(presentWithDisplayName:bundleId:dataUUID:completionHandler:)
    class func present(displayName: String?, bundleId: String?, dataUUID: String?, completionHandler: ((NSNumber?, Error?) -> Void)?) -> Bool {
        guard #available(iOS 16.0, *), let bundleId, let dataUUID, let rootVC = keyWindow?.rootViewController else { return false }
        let container = SideHomeAppContainer(bundleId: bundleId, dataUUID: dataUUID, rootVC: rootVC, completionHandler: completionHandler)
        running[dataUUID] = container
        container.zoomIn()
        return true
    }

    /// Re-opens an app that is already running in SideHome. Returns false if it isn't running here.
    @objc class func bringToFront(dataUUID: String) -> Bool {
        guard #available(iOS 16.0, *), let container = running[dataUUID] as? SideHomeAppContainer else { return false }
        container.zoomIn()
        return true
    }

    class func terminateApps(bundleId: String) {
        guard #available(iOS 16.0, *) else { return }
        for case let container as SideHomeAppContainer in running.values where container.bundleId == bundleId {
            container.appSceneVC.terminate()
        }
    }

    /// Shows the app switcher. Returns false when no app is running.
    @discardableResult
    class func showSwitcher() -> Bool {
        guard #available(iOS 16.0, *) else { return false }
        let cards = recent.compactMap { running[$0] as? SideHomeAppContainer }
        guard let rootView = cards.first?.view.superview else { return false }
        SideHomeSwitcher.shared.open(cards: cards, in: rootView)
        return true
    }

    /// Delivers a URL to a running guest app's scene. Returns false if the app isn't running here.
    class func deliver(url: String, toApp bundleKey: String) -> Bool {
        guard #available(iOS 16.0, *),
              let container = running.values.compactMap({ $0 as? SideHomeAppContainer }).first(where: { $0.bundleId == bundleKey })
        else { return false }
        container.appSceneVC.openURLScheme(url)
        return true
    }

    // MARK: Navigation island

    /// Previous app in the history; from the first app, the home screen; from home, the last app.
    class func goBack() {
        guard #available(iOS 16.0, *) else { return }
        if SideHomeModel.shared.appInFront {
            if historyIndex > 0 {
                historyIndex -= 1
                reopen(history[historyIndex])
            } else {
                goHome()
            }
        } else if historyIndex >= 0 {
            reopen(history[historyIndex])
        }
    }

    class func goForward() {
        guard #available(iOS 16.0, *), historyIndex + 1 < history.count else { return }
        historyIndex += 1
        reopen(history[historyIndex])
    }

    /// Closes whatever is open (app, Settings, overlays, LiveContainer screens) and the island.
    class func goHome() {
        let home = SideHomeModel.shared
        home.settingsOpen = false
        home.present(nil)
        home.showLibrary = false
        if #available(iOS 16.0, *), let front, let container = running[front] as? SideHomeAppContainer {
            container.zoomOut()
        }
        home.navOpen = false
    }

    @available(iOS 16.0, *)
    private class func reopen(_ dataUUID: String) {
        navigating = true
        (running[dataUUID] as? SideHomeAppContainer)?.zoomIn()
        navigating = false
    }

    fileprivate class func publishNav() {
        let home = SideHomeModel.shared
        home.canGoBack = home.appInFront || historyIndex >= 0
        home.canGoForward = historyIndex + 1 < history.count
    }

    @available(iOS 16.0, *)
    fileprivate class func hideOthers(except dataUUID: String) {
        for case let container as SideHomeAppContainer in running.values where container.dataUUID != dataUUID && !container.view.isHidden {
            container.view.alpha = 0
            container.view.isHidden = true
        }
    }

    fileprivate class func didGoHome() {
        front = nil
        publishNav()
    }

    class func terminateAll() {
        guard #available(iOS 16.0, *) else { return }
        for case let container as SideHomeAppContainer in running.values {
            container.appSceneVC.terminate()
        }
    }

    fileprivate class func didFocus(dataUUID: String) {
        recent.removeAll { $0 == dataUUID }
        recent.insert(dataUUID, at: 0)
        front = dataUUID
        // Opening an app normally (not via Back/Forward) drops the forward history, like a browser
        if !navigating {
            if historyIndex + 1 < history.count {
                history.removeSubrange((historyIndex + 1)...)
            }
            history.removeAll { $0 == dataUUID }
            history.append(dataUUID)
            historyIndex = history.count - 1
        }
        publishNav()
    }

    fileprivate class func didClose(dataUUID: String) {
        running[dataUUID] = nil
        recent.removeAll { $0 == dataUUID }
        if let index = history.firstIndex(of: dataUUID) {
            history.remove(at: index)
            if index <= historyIndex { historyIndex -= 1 }
        }
        if front == dataUUID { front = nil }
        publishNav()
    }

    fileprivate static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

/// One running guest app. Its view stays in the window even while "at home" (only hidden),
/// because AppSceneViewController drops its delegate when its view leaves the window.
@available(iOS 16.0, *)
private class SideHomeAppContainer: UIViewController, AppSceneViewControllerDelegate {
    let bundleId: String
    let dataUUID: String
    private(set) var appSceneVC: AppSceneViewController!
    private var completionHandler: ((NSNumber?, Error?) -> Void)?
    private let iconCornerRadius: CGFloat = 14
    private let homeStrip = UIView()
    private let topStrip = UIView()

    init(bundleId: String, dataUUID: String, rootVC: UIViewController, completionHandler: ((NSNumber?, Error?) -> Void)?) {
        self.bundleId = bundleId
        self.dataUUID = dataUUID
        self.completionHandler = completionHandler
        super.init(nibName: nil, bundle: nil)

        rootVC.addChild(self)
        view.frame = rootVC.view.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.backgroundColor = .black
        view.clipsToBounds = true
        view.layer.cornerCurve = .continuous
        view.isHidden = true
        rootVC.view.addSubview(view)
        didMove(toParent: rootVC)

        appSceneVC = AppSceneViewController(bundleId: bundleId, dataUUID: dataUUID, delegate: self)
        addChild(appSceneVC)
        appSceneVC.view.frame = view.bounds
        appSceneVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(appSceneVC.view)
        appSceneVC.didMove(toParent: self)

        // Invisible strips over the home-indicator and status-bar areas. Touches on the hosted scene go
        // to the guest process, so SideHome's own swipes need host-owned views on top to land on.
        homeStrip.frame = CGRect(x: 0, y: view.bounds.height - 34, width: view.bounds.width, height: 34)
        homeStrip.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        homeStrip.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(homeSwipe(_:))))
        view.addSubview(homeStrip)
        topStrip.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 44)
        topStrip.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        topStrip.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(topSwipe(_:))))
        view.addSubview(topStrip)
    }

    /// Off while the app is a card in the app switcher, so touches go to the switcher instead.
    func setInteractive(_ interactive: Bool) {
        appSceneVC.view.isUserInteractionEnabled = interactive
        homeStrip.isHidden = !interactive
        topStrip.isHidden = !interactive
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Zoom animations

    /// Transform that maps this full-screen view onto the app's home-screen icon.
    private var iconTransform: CGAffineTransform {
        let bounds = view.bounds
        let icon = SideHomeAppHost.iconFrames[bundleId]
            ?? CGRect(x: bounds.midX - 30, y: bounds.midY - 30, width: 60, height: 60)
        let scale = icon.width / bounds.width
        return CGAffineTransform(translationX: icon.midX - bounds.midX, y: icon.midY - bounds.midY)
            .scaledBy(x: scale, y: scale)
    }

    func zoomIn() {
        guard let superview = view.superview else { return }
        superview.bringSubviewToFront(view)
        if view.isHidden {
            view.transform = iconTransform
            view.layer.cornerRadius = iconCornerRadius / iconTransform.a
            view.alpha = 0
            view.isHidden = false
        }
        statusBarManager?.nativeWindowViewController = appSceneVC
        SideHomeModel.shared.appInFront = true
        SideHomeModel.shared.navOpen = true
        SideHomeAppHost.didFocus(dataUUID: dataUUID)
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.view.transform = .identity
            self.view.layer.cornerRadius = 0
            self.view.alpha = 1
        } completion: { finished in
            // The app now covers the screen, so the one it replaced can be hidden
            if finished { SideHomeAppHost.hideOthers(except: self.dataUUID) }
        }
    }

    func zoomOut(velocity: CGFloat = 0) {
        let target = iconTransform
        statusBarManager?.nativeWindowViewController = nil
        SideHomeModel.shared.appInFront = false
        SideHomeModel.shared.navOpen = false
        SideHomeAppHost.didGoHome()
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: velocity, options: [.beginFromCurrentState]) {
            self.view.transform = target
            self.view.layer.cornerRadius = self.iconCornerRadius / target.a
        }
        // Fade the snapshot into the icon during the last part of the flight, like SpringBoard
        UIView.animate(withDuration: 0.2, delay: 0.2, options: [.beginFromCurrentState]) {
            self.view.alpha = 0
        } completion: { _ in
            if self.view.alpha == 0 { self.view.isHidden = true }
        }
    }

    @objc private func homeSwipe(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view.superview)
        let height = view.bounds.height
        // 0 at rest, 1 when the finger has travelled 40% of the screen upwards
        let progress = min(max(-translation.y / (height * 0.4), 0), 1)
        switch gesture.state {
        case .changed:
            let scale = 1 - 0.55 * progress
            view.transform = CGAffineTransform(translationX: translation.x * 0.6, y: translation.y * 0.6).scaledBy(x: scale, y: scale)
            view.layer.cornerRadius = 40 * progress / scale
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: view.superview).y
            // Swipe up and pause before lifting: app switcher, like iOS
            if gesture.state == .ended && progress > 0.12 && abs(velocity) < 250 && SideHomeAppHost.showSwitcher() {
                return
            }
            if gesture.state == .ended && (progress > 0.25 || velocity < -600) {
                zoomOut(velocity: min(abs(velocity) / height, 3))
            } else {
                zoomIn()
            }
        default:
            break
        }
    }

    /// Swipe down from the status bar: left half Notification Center, right half Control Center.
    @objc private func topSwipe(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        guard gesture.state == .ended, translation.y > 40 else { return }
        let startX = gesture.location(in: view).x - translation.x
        SideHomeModel.shared.present(startX < view.bounds.midX ? .notificationCenter : .controlCenter)
    }

    private var statusBarManager: LCStatusBarManager? {
        view.window?.windowScene?.statusBarManager as? LCStatusBarManager
    }

    private func close() {
        statusBarManager?.nativeWindowViewController = nil
        if !view.isHidden { SideHomeModel.shared.appInFront = false }
        UIView.animate(withDuration: 0.25) {
            self.view.alpha = 0
        } completion: { _ in
            self.appSceneVC.willMove(toParent: nil)
            self.appSceneVC.view.removeFromSuperview()
            self.appSceneVC.removeFromParent()
            self.willMove(toParent: nil)
            self.view.removeFromSuperview()
            self.removeFromParent()
        }
        SideHomeAppHost.didClose(dataUUID: dataUUID)
    }

    // MARK: AppSceneViewControllerDelegate (mirrors AppSceneViewSwiftUI.Coordinator)

    func appSceneVCAppDidExit(_: AppSceneViewController!) {
        DispatchQueue.main.async { self.close() }
    }

    func appSceneVC(_ vc: AppSceneViewController!, didInitializeWithError error: (any Error)!) {
        DispatchQueue.main.async {
            // LCAppModel.runApp awaits this exactly once
            self.completionHandler?(error == nil ? NSNumber(value: vc.pid) : nil, error)
            self.completionHandler = nil
            if error != nil { self.close() }
        }
    }

    func appSceneVCWillActivateScene(_ vc: AppSceneViewController!) {
        vc.updateSettings { settings in
            guard let settings else { return }
            let defaultInsets = vc.view.window?.safeAreaInsets ?? .zero
            settings.peripheryInsets = defaultInsets
            settings.safeAreaInsetsPortrait = defaultInsets
            settings.deviceOrientation = UIDevice.current.orientation
            settings.setInterfaceOrientation(UIApplication.shared.statusBarOrientation)
            if settings.interfaceOrientation().isLandscape {
                settings.setFrame(CGRect(x: 0, y: 0, width: vc.view.frame.size.height, height: vc.view.frame.size.width))
            } else {
                settings.setFrame(CGRect(x: 0, y: 0, width: vc.view.frame.size.width, height: vc.view.frame.size.height))
            }
        }
        vc.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    func appSceneVC(_ vc: AppSceneViewController!, didUpdateFrom settings: UIMutableApplicationSceneSettings!, transitionContext context: Any!, lifecycleActionType actionType: UInt32) {
        settings.interruptionPolicy = 0
        vc.presenter.scene.updateSettings(settings, withTransitionContext: context, completion: nil)
        // actionType 2 is only sent when the scene enters foreground, so a pending URL scheme can be passed here
        if actionType == 2, let launchUrl = UserDefaults.standard.string(forKey: "launchAppUrlScheme") {
            UserDefaults.standard.removeObject(forKey: "launchAppUrlScheme")
            vc.openURLScheme(launchUrl)
        }
    }
}

/// The app switcher: running apps shrink into a carousel of cards over a blurred home screen.
/// Tap a card to open it, swipe it up to quit, tap outside to go home.
@available(iOS 16.0, *)
private final class SideHomeSwitcher: NSObject {
    static let shared = SideHomeSwitcher()
    private var backdrop: UIVisualEffectView?
    private var cards: [SideHomeAppContainer] = []
    private var cardGestures: [UIGestureRecognizer] = []
    /// Horizontal scroll in points; 0 shows the most recent app in the middle
    private var scroll: CGFloat = 0
    private var panStartScroll: CGFloat = 0
    private var panIsVertical = false
    private let scale: CGFloat = 0.62
    private let spacing: CGFloat = 22

    private var bounds: CGRect { backdrop?.bounds ?? .zero }
    private var step: CGFloat { bounds.width * scale + spacing }
    private var maxScroll: CGFloat { max(CGFloat(cards.count - 1) * step, 0) }

    func open(cards: [SideHomeAppContainer], in rootView: UIView) {
        guard backdrop == nil else { return }
        self.cards = cards
        scroll = 0
        SideHomeModel.shared.appInFront = false
        SideHomeModel.shared.navOpen = false
        SideHomeAppHost.didGoHome()

        let backdrop = UIVisualEffectView(effect: nil)
        backdrop.frame = rootView.bounds
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdrop.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backdropTapped)))
        backdrop.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(backdropPanned(_:))))
        // Just below the lowest card, above the SwiftUI home screen
        let lowest = cards.compactMap { rootView.subviews.firstIndex(of: $0.view) }.min() ?? rootView.subviews.count
        rootView.insertSubview(backdrop, at: lowest)
        self.backdrop = backdrop

        for (index, card) in cards.enumerated() {
            card.setInteractive(false)
            if card.view.isHidden {
                card.view.transform = transform(for: index)
                card.view.alpha = 0
                card.view.isHidden = false
            }
            let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:)))
            let pan = UIPanGestureRecognizer(target: self, action: #selector(cardPanned(_:)))
            card.view.addGestureRecognizer(tap)
            card.view.addGestureRecognizer(pan)
            cardGestures += [tap, pan]
        }
        animate {
            backdrop.effect = UIBlurEffect(style: .systemThinMaterialDark)
            self.layoutCards()
        }
    }

    private func transform(for index: Int) -> CGAffineTransform {
        // Most recent in the middle, older apps to the left
        CGAffineTransform(translationX: scroll - CGFloat(index) * step, y: -bounds.height * 0.03)
            .scaledBy(x: scale, y: scale)
    }

    private func layoutCards() {
        for (index, card) in cards.enumerated() {
            card.view.transform = transform(for: index)
            card.view.alpha = 1
            card.view.layer.cornerRadius = 24 / scale
        }
    }

    private func animate(_ changes: @escaping () -> Void) {
        UIView.animate(withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0,
                       options: [.allowUserInteraction, .beginFromCurrentState], animations: changes)
    }

    @objc private func cardTapped(_ gesture: UITapGestureRecognizer) {
        guard let card = cards.first(where: { $0.view === gesture.view }) else { return }
        finish(opening: card)
    }

    @objc private func backdropTapped() {
        finish(opening: nil)
    }

    @objc private func backdropPanned(_ gesture: UIPanGestureRecognizer) {
        scrollCards(gesture)
    }

    @objc private func cardPanned(_ gesture: UIPanGestureRecognizer) {
        guard let index = cards.firstIndex(where: { $0.view === gesture.view }) else { return }
        let translation = gesture.translation(in: backdrop)
        if gesture.state == .began {
            panIsVertical = abs(translation.y) > abs(translation.x)
        }
        guard panIsVertical else {
            scrollCards(gesture)
            return
        }
        let card = cards[index]
        switch gesture.state {
        case .changed:
            card.view.transform = transform(for: index).concatenating(CGAffineTransform(translationX: 0, y: min(translation.y, 0)))
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: backdrop).y
            if gesture.state == .ended && (translation.y < -120 || velocity < -700) {
                quit(at: index)
            } else {
                animate { self.layoutCards() }
            }
        default:
            break
        }
    }

    private func scrollCards(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: backdrop).x
        switch gesture.state {
        case .began:
            panStartScroll = scroll
        case .changed:
            scroll = min(max(panStartScroll + translation, 0), maxScroll)
            layoutCards()
        case .ended, .cancelled:
            // Settle on the nearest card, carrying some of the fling
            let projected = scroll + gesture.velocity(in: backdrop).x * 0.15
            scroll = min(max((projected / step).rounded() * step, 0), maxScroll)
            animate { self.layoutCards() }
        default:
            break
        }
    }

    private func quit(at index: Int) {
        let card = cards.remove(at: index)
        removeGestures(from: card)
        let flyAway = transform(for: index).concatenating(CGAffineTransform(translationX: 0, y: -bounds.height))
        UIView.animate(withDuration: 0.3, animations: {
            card.view.transform = flyAway
            card.view.alpha = 0
        }, completion: { _ in
            card.view.isHidden = true
            card.appSceneVC.terminate()
        })
        if cards.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.finish(opening: nil) }
            return
        }
        scroll = min(scroll, maxScroll)
        animate { self.layoutCards() }
    }

    private func removeGestures(from card: SideHomeAppContainer) {
        for gesture in card.view.gestureRecognizers ?? [] where cardGestures.contains(gesture) {
            card.view.removeGestureRecognizer(gesture)
        }
    }

    private func finish(opening chosen: SideHomeAppContainer?) {
        guard let backdrop else { return }
        let others = cards.filter { $0 !== chosen }
        for card in cards {
            removeGestures(from: card)
            card.setInteractive(true)
        }
        cardGestures = []
        cards = []
        self.backdrop = nil

        chosen?.zoomIn()
        UIView.animate(withDuration: 0.3, animations: {
            backdrop.effect = nil
            for card in others { card.view.alpha = 0 }
        }, completion: { _ in
            backdrop.removeFromSuperview()
            for card in others where card.view.alpha == 0 { card.view.isHidden = true }
        })
    }
}
