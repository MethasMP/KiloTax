import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "kilotax/hardware_telemetry"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1. Configure the native hardware immortality engine (Bluetooth & Location)
    KiloTaxBackgroundEngine.shared.configure()

    // 2. Register native method channel with Flutter engine
    let controller = window?.rootViewController as? FlutterViewController
    if let controller = controller {
      let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "setTargetBluetoothName":
          let name = call.arguments as? String
          KiloTaxBackgroundEngine.shared.setTargetBluetoothName(name)
          result(true)
        case "getCompletedNativeTrips":
          let trips = KiloTaxBackgroundEngine.shared.getCompletedNativeTrips()
          result(trips)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
