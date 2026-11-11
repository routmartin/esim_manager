import Flutter
import UIKit
import Foundation
import CoreTelephony

public class EsimManagerPlugin: NSObject, FlutterPlugin {
  private var channel: FlutterMethodChannel

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "esim_manager", binaryMessenger: registrar.messenger())
    let instance = EsimManagerPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isEsimSupported":
      result(isEsimSupported())

    case "listProfiles":
      // iOS: retrieving installed eSIM profiles programmatically is limited; return empty list.
      result([Any]())

    case "removeProfile":
      // Requires system UI / entitlements; not implemented.
      result(false)

    case "getActiveProfile":
      result(NSNull())

    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)

    case "installEsim":
      guard let args = call.arguments as? [String: Any] else {
        result(false)
        return
      }
      let lpa = (args["lpa"] as? String)
        ?? (args["activationCode"] as? String)
        ?? (args["lpaString"] as? String)
      guard let lpa = lpa else {
        result(false)
        return
      }
      installEsimViaLpa(lpaString: lpa, result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Asks the OS directly whether this device can use eSIM, so new iPhone/iPad
  /// models work without maintaining a hardcoded model-identifier list.
  /// Note: returns false on the iOS Simulator.
  private func isEsimSupported() -> Bool {
    if #available(iOS 12.1, *) {
      let supported = CTCellularPlanProvisioning().supportsCellularPlan()
      NSLog("[esim] supportsCellularPlan=\(supported) ios=\(UIDevice.current.systemVersion)")
      return supported
    }
    return false
  }

  private func installEsimViaLpa(lpaString: String, result: @escaping FlutterResult) {
    // Construct Apple's official LPA provisioning URL
    let encoded = lpaString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? lpaString
    let urlString = "https://esimsetup.apple.com/esim_qrcode_provisioning?carddata=\(encoded)"
    guard let url = URL(string: urlString) else {
      NSLog("[esim] installEsim failed: could not build URL")
      result(false)
      return
    }

    DispatchQueue.main.async {
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:]) { success in
          // `success` only means the URL opened, not that the eSIM was installed.
          result(success)
        }
      } else {
        NSLog("[esim] installEsim failed: canOpenURL returned false")
        result(false)
      }
    }
  }
}