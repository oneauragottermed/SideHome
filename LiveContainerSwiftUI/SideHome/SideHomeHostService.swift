//
//  SideHomeHostService.swift
//  SideHome
//
//  The SideHome end of SideHomeBridge.h: posts guest notifications as SideHome (labelled with
//  the guest's name and icon), keeps per-app badges and plays guest haptics.
//

import UIKit
import UserNotifications

@objc class SideHomeHostService: NSObject {
    /// userInfo keys added to every guest notification
    static let appKey = "SideHomeApp"
    static let titleKey = "SideHomeTitle"
    private static let server = SideHomeHostServerImpl()

    /// Passed to every LiveProcess launch by AppSceneViewController.
    @objc static var endpoint: NSXPCListenerEndpoint? { server.listener.endpoint }

    /// Call at launch so taps on notifications that launched SideHome are handled.
    static func start() {
        UNUserNotificationCenter.current().delegate = server
    }

    static func app(bundleId: String) -> LCAppModel? {
        let model = DataManager.shared.model
        return (model.apps + model.hiddenApps).first { $0.appInfo.bundleIdentifier() == bundleId }
    }

    static func open(bundleId: String) {
        guard let app = app(bundleId: bundleId) else { return }
        Task { try? await app.runApp(multitask: true) }
    }
}

private class SideHomeHostServerImpl: NSObject, SideHomeHostServer, NSXPCListenerDelegate, UNUserNotificationCenterDelegate {
    let listener = NSXPCListener.anonymous()

    override init() {
        super.init()
        listener.delegate = self
        listener.resume()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: SideHomeHostServer.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    // MARK: SideHomeHostServer (called on an XPC queue)

    func post(_ request: UNNotificationRequest, fromApp bundleId: String) {
        DispatchQueue.main.async {
            let app = SideHomeHostService.app(bundleId: bundleId)
            let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
            var userInfo = content.userInfo
            userInfo[SideHomeHostService.appKey] = bundleId
            userInfo[SideHomeHostService.titleKey] = content.title
            content.userInfo = userInfo
            content.threadIdentifier = bundleId
            // iOS always shows SideHome's icon, so name the app in the title and attach its icon
            if let app {
                content.subtitle = [content.title, content.subtitle].filter { !$0.isEmpty }.joined(separator: " · ")
                content.title = app.displayName
                if let png = app.appInfo.iconIsDarkIcon(false)?.pngData() {
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
                    if (try? png.write(to: url)) != nil,
                       let attachment = try? UNNotificationAttachment(identifier: "icon", url: url) {
                        content.attachments = [attachment]
                    }
                }
            }
            let center = UNUserNotificationCenter.current()
            // Guests are told they're authorized, so SideHome asks iOS the first time one posts
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: request.trigger))
            }
        }
    }

    func removePending(_ identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func requestAuthorization(_ options: UInt, reply: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: UNAuthorizationOptions(rawValue: options)) { granted, _ in
            reply(granted)
        }
    }

    func setBadge(_ count: Int, fromApp bundleId: String) {
        DispatchQueue.main.async {
            let home = SideHomeModel.shared
            home.badges[bundleId] = count > 0 ? count : nil
            let total = home.badges.values.reduce(0, +)
            if #available(iOS 16.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(total)
            } else {
                UIApplication.shared.applicationIconBadgeNumber = total
            }
        }
    }

    func playHaptic(kind: SideHomeHapticKind, value: Int) {
        DispatchQueue.main.async {
            switch kind {
            case .notification:
                UINotificationFeedbackGenerator().notificationOccurred(UINotificationFeedbackGenerator.FeedbackType(rawValue: value) ?? .success)
            case .impact:
                UIImpactFeedbackGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle(rawValue: value) ?? .medium).impactOccurred()
            default:
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let content = notification.request.content
        guard let bundleId = content.userInfo[SideHomeHostService.appKey] as? String else {
            completionHandler([.banner, .list, .sound])
            return
        }
        // SideHome is open: show our own banner with the guest's icon instead of the system one
        let title = content.userInfo[SideHomeHostService.titleKey] as? String ?? content.title
        DispatchQueue.main.async {
            SideHomeBanner.show(bundleId: bundleId, title: title, message: content.body)
        }
        completionHandler([.list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let bundleId = response.notification.request.content.userInfo[SideHomeHostService.appKey] as? String {
            // Give the home screen a moment to appear when the tap launched SideHome
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                SideHomeHostService.open(bundleId: bundleId)
            }
        }
        completionHandler()
    }
}
