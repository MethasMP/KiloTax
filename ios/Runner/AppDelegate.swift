import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "kiloclaim/hardware_telemetry"
  private var isTelemetryChannelRegistered = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1. Configure the native hardware immortality engine (Bluetooth, AudioRoute, CoreMotion & Location)
    KiloClaimBackgroundEngine.shared.configure()

    // 2. Register native method channel if rootViewController is already available
    if let controller = window?.rootViewController as? FlutterViewController {
      registerTelemetryChannel(binaryMessenger: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerTelemetryChannel(binaryMessenger: engineBridge.applicationRegistrar.messenger())
  }

  private func registerTelemetryChannel(binaryMessenger: FlutterBinaryMessenger) {
    guard !isTelemetryChannelRegistered else { return }
    isTelemetryChannelRegistered = true

    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "setTargetBluetoothName":
        let name = call.arguments as? String
        KiloClaimBackgroundEngine.shared.setTargetBluetoothName(name)
        result(true)
      case "setTargetBluetoothTarget":
        let args = call.arguments as? [String: Any]
        let name = args?["name"] as? String
        let uuid = args?["uuid"] as? String
        KiloClaimBackgroundEngine.shared.setTargetBluetoothTarget(name: name, uuid: uuid)
        result(true)
      case "getCompletedNativeTrips":
        let trips = KiloClaimBackgroundEngine.shared.getCompletedNativeTrips()
        result(trips)
      case "acknowledgeNativeTripsIngested":
        let tripIds = call.arguments as? [String] ?? []
        KiloClaimBackgroundEngine.shared.acknowledgeNativeTripsIngested(tripIds)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
