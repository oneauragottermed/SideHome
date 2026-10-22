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

    fileprivate class func didClose(dataUUID: String) {
        running[dataUUID] = nil
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

        // Invisible strip over the home-indicator area. Touches on the hosted scene go to the guest
        // process, so the "go home" swipe needs a host-owned view on top to land on.
        let homeStrip = UIView(frame: CGRect(x: 0, y: view.bounds.height - 34, width: view.bounds.width, height: 34))
        homeStrip.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        homeStrip.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(homeSwipe(_:))))
        view.addSubview(homeStrip)
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
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.view.transform = .identity
            self.view.layer.cornerRadius = 0
            self.view.alpha = 1
        }
    }

    func zoomOut(velocity: CGFloat = 0) {
        let target = iconTransform
        statusBarManager?.nativeWindowViewController = nil
        SideHomeModel.shared.appInFront = false
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
            if gesture.state == .ended && (progress > 0.25 || velocity < -600) {
                zoomOut(velocity: min(abs(velocity) / height, 3))
            } else {
                zoomIn()
            }
        default:
            break
        }
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
