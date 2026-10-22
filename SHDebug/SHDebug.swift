//
//  SHDebug.swift
//  A test app for SideHome: every button exercises one thing a guest app can do.
//  Events are logged with timestamps and kept across launches, so you can see what
//  happened while the app was in the background.
//

import AVFoundation
import Photos
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

@main
struct SHDebugApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(Debugger.shared)
                .onOpenURL { Debugger.shared.log("Opened via URL: \($0.absoluteString)") }
        }
        .onChange(of: scenePhase) { phase in
            Debugger.shared.log("Scene is now \(phase)")
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Debugger.shared.log("Launched (launch #\(Debugger.shared.launches))")
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let title = notification.request.content.title
        DispatchQueue.main.async { Debugger.shared.log("Notification arrived while open: \(title)") }
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let title = response.notification.request.content.title
        DispatchQueue.main.async { Debugger.shared.log("Notification tapped: \(title)") }
        completionHandler()
    }
}

final class Debugger: ObservableObject {
    static let shared = Debugger()

    @Published private(set) var lines: [String] = UserDefaults.standard.stringArray(forKey: "SHDebugLog") ?? []
    /// Seconds the process actually ran. A timer only fires while the app isn't suspended.
    @Published private(set) var ticks = 0
    let launchDate = Date()
    let launches: Int
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid
    private let timeFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private init() {
        launches = UserDefaults.standard.integer(forKey: "SHDebugLaunches") + 1
        UserDefaults.standard.set(launches, forKey: "SHDebugLaunches")
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Debugger.shared.ticks += 1
        }
    }

    /// Must be called on the main thread.
    func log(_ text: String) {
        lines.insert("\(timeFormat.string(from: Date()))  \(text)", at: 0)
        lines = Array(lines.prefix(100))
        UserDefaults.standard.set(lines, forKey: "SHDebugLog")
    }

    func clearLog() {
        lines = []
        UserDefaults.standard.removeObject(forKey: "SHDebugLog")
    }

    // MARK: Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.log("Notification permission \(granted ? "granted" : "denied")" + (error.map { ": \($0.localizedDescription)" } ?? ""))
            }
        }
    }

    func notify(after seconds: TimeInterval, title: String, body: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body ?? "Scheduled by SHDebug \(Int(seconds)) s earlier"
        content.sound = .default
        // A time-interval trigger must be > 0, so "now" means 1 second
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error {
                    self.log("Notification failed: \(error.localizedDescription)")
                } else {
                    self.log("Scheduled “\(title)” in \(Int(max(seconds, 1))) s")
                }
            }
        }
    }

    func setBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            DispatchQueue.main.async {
                self.log(error.map { "Badge failed: \($0.localizedDescription)" } ?? "Badge set to \(count)")
            }
        }
    }

    // MARK: Background

    /// Asks iOS for background time and logs a tick every 5 s for 30 s.
    func startBackgroundTask() {
        guard backgroundTask == .invalid else {
            log("Background task already running")
            return
        }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "SHDebug") {
            Debugger.shared.log("Background time expired")
            Debugger.shared.endBackgroundTask()
        }
        log("Background task started, go home now")
        for step in 1...6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step * 5)) {
                let state = UIApplication.shared.applicationState == .background ? "background" : "foreground"
                self.log("Background tick \(step * 5) s (\(state))")
                if step == 6 { self.endBackgroundTask() }
            }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
        log("Background task ended")
    }

    // MARK: Permissions

    func requestCamera() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { self.log("Camera permission \(granted ? "granted" : "denied")") }
        }
    }

    func requestPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            let names: [PHAuthorizationStatus: String] = [.authorized: "granted", .limited: "limited", .denied: "denied", .restricted: "restricted"]
            DispatchQueue.main.async { self.log("Photos permission \(names[status] ?? "not determined")") }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var debug: Debugger
    @Environment(\.openURL) private var openURL
    @AppStorage("SHDebugDarkMode") private var darkMode = false
    @State private var choosingFile = false
    @State private var showingAlert = false
    @State private var typedText = ""

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Ran \(debug.ticks) s of \(Int(Date().timeIntervalSince(debug.launchDate))) s since launch")
                    Text("Launch #\(debug.launches)")
                    Text("Process: \(ProcessInfo.processInfo.processName)")
                    Text("Bundle ID: \(Bundle.main.bundleIdentifier ?? "?")")
                    Text("iOS \(UIDevice.current.systemVersion)")
                } header: {
                    Text("Is the app still running?")
                } footer: {
                    Text("If the first number falls behind the second, the app was suspended. The launch number should go up every time the app is reopened after being closed.")
                }

                Section("Notifications") {
                    button("Ask Notification Permission", "bell.badge") { debug.requestNotificationPermission() }
                    button("Notify Now", "bell") { debug.notify(after: 0, title: "Hello from SHDebug") }
                    button("Notify in 10 s (go home)", "timer") { debug.notify(after: 10, title: "10-second notification") }
                    button("Notify in 60 s (close SideHome)", "moon.zzz") { debug.notify(after: 60, title: "60-second notification") }
                    button("Notify 3 Times (fills Notification Center)", "list.bullet") {
                        for number in 1...3 { debug.notify(after: Double(number), title: "Burst \(number) of 3") }
                    }
                    button("Notify with Long Text", "text.alignleft") {
                        debug.notify(after: 0, title: "A long one", body: String(repeating: "SideHome should cut this text off neatly after a few lines. ", count: 6))
                    }
                    button("Set Random Badge", "app.badge") { debug.setBadge(Int.random(in: 1...99)) }
                    button("Clear Badge", "app") { debug.setBadge(0) }
                }

                Section("Background") {
                    button("Run 30 s Background Task", "hourglass") { debug.startBackgroundTask() }
                }

                Section("Links and Files") {
                    button("Open apple.com in Safari", "safari") {
                        openURL(URL(string: "https://www.apple.com")!) { debug.log("Open Safari: \($0 ? "ok" : "refused")") }
                    }
                    button("Open shdebug:// (own URL scheme)", "link") {
                        openURL(URL(string: "shdebug://hello")!) { debug.log("Open shdebug://: \($0 ? "ok" : "refused")") }
                    }
                    button("Pick a File", "doc") { choosingFile = true }
                    button("Copy Text to Clipboard", "doc.on.doc") {
                        UIPasteboard.general.string = "SHDebug \(Date())"
                        debug.log("Copied to clipboard")
                    }
                    button("Paste from Clipboard", "doc.on.clipboard") {
                        debug.log("Clipboard: \(UIPasteboard.general.string ?? "(empty)")")
                    }
                }

                Section("Interface") {
                    TextField("Type here to test the keyboard", text: $typedText)
                    button("Show Alert", "exclamationmark.bubble") { showingAlert = true }
                    button("Haptic: Success", "waveform") {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        debug.log("Success haptic requested")
                    }
                    button("Haptic: Impact", "hand.tap") {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        debug.log("Impact haptic requested")
                    }
                    button("Haptic: Selection", "dial.low") {
                        UISelectionFeedbackGenerator().selectionChanged()
                        debug.log("Selection haptic requested")
                    }
                    button(darkMode ? "Switch to Light Mode" : "Switch to Dark Mode", "circle.lefthalf.filled") {
                        darkMode.toggle()
                        debug.log("Dark mode \(darkMode ? "on" : "off") (status bar should change too)")
                    }
                }

                Section("Permissions") {
                    button("Ask Camera Permission", "camera") { debug.requestCamera() }
                    button("Ask Photos Permission", "photo") { debug.requestPhotos() }
                }

                Section("Danger") {
                    Button(role: .destructive) {
                        fatalError("SHDebug crash button")
                    } label: {
                        Label("Crash the App", systemImage: "bolt.trianglebadge.exclamationmark")
                    }
                }

                Section {
                    ForEach(Array(debug.lines.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(.caption, design: .monospaced))
                    }
                } header: {
                    HStack {
                        Text("Log")
                        Spacer()
                        Button("Clear") { debug.clearLog() }
                    }
                }
            }
            .navigationTitle("SHDebug")
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(darkMode ? .dark : .light)
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.item]) { result in
            switch result {
            case .success(let url): debug.log("Picked file: \(url.lastPathComponent)")
            case .failure(let error): debug.log("File picker failed: \(error.localizedDescription)")
            }
        }
        .alert("Hello from SHDebug", isPresented: $showingAlert) {
            Button("OK") { debug.log("Alert dismissed") }
        }
    }

    private func button(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
        }
    }
}
