import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // UIScene plug-in kayıtlarından önce UNUserNotificationCenter delegate'ini ayarla.
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Flutter 3.41+ UIScene yaşam döngüsünde kanallar burada kaydedilir.
    // iOS izinleri Dart Firebase Messaging tarafından yönetilir; bu köprü
    // yalnız kullanıcının uygulama bildirim ayarlarını açar.
    let notificationsChannel = FlutterMethodChannel(
      name: "tr.guncelgundem/notifications",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    notificationsChannel.setMethodCallHandler { call, result in
      guard call.method == "openSettings" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(false)
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in
        result(opened)
      }
    }
  }
}
