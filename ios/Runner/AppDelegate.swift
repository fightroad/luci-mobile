import Flutter
import Network
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var localNetworkBrowser: NWBrowser?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "luci_mobile/local_network",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "triggerPermission" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.triggerLocalNetworkPermission()
      result(nil)
    }
  }

  private func triggerLocalNetworkPermission() {
    localNetworkBrowser?.cancel()

    let browser = NWBrowser(
      for: .bonjour(type: "_http._tcp", domain: nil),
      using: NWParameters()
    )
    browser.stateUpdateHandler = { _, _ in }
    browser.browseResultsChangedHandler = { _, _ in }
    browser.start(queue: .main)
    localNetworkBrowser = browser

    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      self?.localNetworkBrowser?.cancel()
      self?.localNetworkBrowser = nil
    }
  }
}
