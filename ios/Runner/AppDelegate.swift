import UIKit
import Flutter
import AVKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    private var kazumiTPlayer: KazumiTSystemPlayer?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        let playerChannel = FlutterMethodChannel(name: "com.shaoyou11.kazumit/player", binaryMessenger: engineBridge.applicationRegistrar.messenger())
        playerChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { result(FlutterError(code: "unavailable", message: "播放器不可用", details: nil)); return }
            if call.method == "deviceStatus" {
                UIDevice.current.isBatteryMonitoringEnabled = true
                let device = UIDevice.current
                result(["battery": Int((device.batteryLevel * 100).rounded()), "charging": device.batteryState == .charging || device.batteryState == .full])
            } else if call.method == "openPictureInPicture" {
                guard self.kazumiTPlayer == nil,
                      let args = call.arguments as? [String: Any],
                      let text = args["url"] as? String, let url = URL(string: text),
                      ["http", "https", "file"].contains(url.scheme?.lowercased() ?? ""),
                      let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                      let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController,
                      root.presentedViewController == nil else {
                    result(FlutterError(code: "unavailable", message: "画中画暂不可用", details: nil)); return
                }
                do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback); try AVAudioSession.sharedInstance().setActive(true) }
                catch { result(FlutterError(code: "audio", message: "音频会话不可用", details: nil)); return }
                let controller = KazumiTSystemPlayer()
                self.kazumiTPlayer = controller
                controller.configure(url: url, referer: args["referer"] as? String ?? "",
                                     headers: args["headers"] as? [String: String] ?? [:],
                                     position: (args["position"] as? NSNumber)?.doubleValue ?? 0,
                                     rate: (args["rate"] as? NSNumber)?.floatValue ?? 1,
                                     playing: args["playing"] as? Bool ?? true) { [weak self] position, playing, error in
                    self?.kazumiTPlayer = nil
                    if let error = error { result(FlutterError(code: "playback", message: error, details: nil)) }
                    else { result(["position": position, "playing": playing]) }
                }
                root.present(controller, animated: true)
            } else { result(FlutterMethodNotImplemented) }
        }


        let channel = FlutterMethodChannel(
            name: "com.predidit.kazumi/intent",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "openWithReferer" {
                guard let args = call.arguments else { return }
                if let myArgs = args as? [String: Any],
                   let url = myArgs["url"] as? String,
                   let referer = myArgs["referer"] as? String {
                    self?.openVideoWithReferer(url: url, referer: referer)
                }
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        let storageChannel = FlutterMethodChannel(
            name: "com.predidit.kazumi/storage",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        storageChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "getAvailableStorage" {
                do {
                    let attrs = try FileManager.default.attributesOfFileSystem(
                        forPath: NSHomeDirectory()
                    )
                    if let freeSize = attrs[.systemFreeSize] as? Int64 {
                        result(freeSize)
                    } else {
                        result(-1)
                    }
                } catch {
                    result(-1)
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // TODO: ADD VLC SUPPORT
    // VLC can be downloaded from iOS App Store, but don't know how to build selectable app lists, while checking if it is installled.
    // VLC supports more video formats than AVPlayer but does not support referer while AVPlayer does
    private func openVideoWithReferer(url: String, referer: String) {
        guard let videoUrl = URL(string: url) else { return }

        let headers: [String: String] = [
            "Referer": referer,
        ]
        let asset = AVURLAsset(url: videoUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.videoGravity = AVLayerVideoGravity.resizeAspect

        // Use UIScene API instead of deprecated keyWindow
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        rootViewController.present(playerViewController, animated: true) {
            playerViewController.player?.play()
        }

//        guard let appURL = URL(string: "vlc-x-callback://x-callback-url/stream?url=" + url) else {
//            return
//        }
//        if UIApplication.shared.canOpenURL(appURL) && referer.isEmpty {
//            UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
//        }
    }
}

// System playback handoff: AVKit owns PiP, Flutter resumes at the returned position.
private final class KazumiTSystemPlayer: AVPlayerViewController, AVPlayerViewControllerDelegate {
    private var completion: ((Double, Bool, String?) -> Void)?
    private var statusObservation: NSKeyValueObservation?
    private var timeout: DispatchWorkItem?
    private var inPictureInPicture = false
    private var finished = false
    private var ready = false
    private var targetPosition: Double = 0
    private var desiredRate: Float = 1
    private var shouldPlay = true

    func configure(url: URL, referer: String, headers: [String: String], position: Double, rate: Float,
                   playing: Bool, completion: @escaping (Double, Bool, String?) -> Void) {
        self.completion = completion
        targetPosition = position.isFinite ? max(0, position) : 0
        desiredRate = max(0.25, min(3, rate))
        shouldPlay = playing
        var playbackHeaders = headers
        if !referer.isEmpty && !headers.keys.contains(where: { $0.lowercased() == "referer" }) {
            playbackHeaders["Referer"] = referer
        }
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": playbackHeaders])
        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        player?.allowsExternalPlayback = true
        player?.usesExternalPlaybackWhileExternalScreenIsActive = true
        delegate = self
        allowsPictureInPicturePlayback = true
        if #available(iOS 14.2, *) { canStartPictureInPictureAutomaticallyFromInline = true }
        modalPresentationStyle = .fullScreen
        title = "KazumiT · 画中画 / AirPlay"
        statusObservation = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self = self, !self.finished else { return }
                if item.status == .failed { self.finish(error: "此片源不支持系统播放器"); return }
                guard item.status == .readyToPlay, !self.ready else { return }
                self.ready = true
                self.timeout?.cancel()
                self.player?.seek(to: CMTime(seconds: self.targetPosition, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                    DispatchQueue.main.async {
                        guard let self = self, !self.finished else { return }
                        if self.shouldPlay { self.player?.playImmediately(atRate: self.desiredRate) }
                    }
                }
            }
        }
        let work = DispatchWorkItem { [weak self] in self?.finish(error: "系统播放器加载超时") }
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: work)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !inPictureInPicture && (isBeingDismissed || presentingViewController == nil) { finish() }
    }
    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        inPictureInPicture = true
    }
    func playerViewController(_ playerViewController: AVPlayerViewController, failedToStartPictureInPictureWithError error: Error) {
        inPictureInPicture = false
    }
    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        inPictureInPicture = false
        // Closing the floating window returns to Flutter; restoring keeps AVKit visible.
        if presentingViewController == nil { finish(resume: false) }
    }
    func playerViewController(_ playerViewController: AVPlayerViewController,
                              restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        if presentingViewController != nil { completionHandler(true); return }
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              var root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { completionHandler(false); return }
        while let presented = root.presentedViewController { root = presented }
        root.present(self, animated: true) { completionHandler(true) }
    }
    func finish(error: String? = nil, resume: Bool? = nil) {
        guard !finished else { return }
        finished = true
        timeout?.cancel()
        statusObservation = nil
        let seconds = player?.currentTime().seconds ?? targetPosition
        let playing = error == nil && (resume ?? ((player?.rate ?? 0) > 0))
        player?.pause()
        let callback = completion
        completion = nil
        let done: () -> Void = { callback?(seconds.isFinite ? seconds : self.targetPosition, playing, error) }
        if presentingViewController != nil { dismiss(animated: true, completion: done) } else { done() }
    }
}
