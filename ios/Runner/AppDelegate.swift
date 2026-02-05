import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // ✅ Badge 관리용 Method Channel 등록
    let controller = window?.rootViewController as! FlutterViewController
    let badgeChannel = FlutterMethodChannel(
      name: "com.nobsalon.nailedu/badge",
      binaryMessenger: controller.binaryMessenger
    )
    
    badgeChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "clearBadge":
        // iOS 앱 아이콘 배지를 0으로 설정 (= 제거)
        UIApplication.shared.applicationIconBadgeNumber = 0
        result(true)
      case "setBadge":
        // 필요시 배지 숫자 설정 (현재는 미사용)
        if let args = call.arguments as? [String: Any],
           let count = args["count"] as? Int {
          UIApplication.shared.applicationIconBadgeNumber = count
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "count required", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
