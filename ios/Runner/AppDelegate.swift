import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Exigido pelo firebase_messaging: sem este delegate o app não recebe os
    // callbacks de notificação do sistema, e o token APNs não é entregue ao
    // Firebase — `getAPNSToken()` fica nulo para sempre.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Diagnóstico do registro no APNs: sem estes dois callbacks a falha é
  // silenciosa e `getAPNSToken()` apenas fica nulo, sem dizer por quê.
  //
  // `NSLog` e não `print`: em aparelho físico o stdout do processo não é
  // coletado, então um `print` daqui não aparece no syslog do dispositivo e
  // o diagnóstico fica invisível justamente no build que precisamos medir.
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("APNS-DIAG: registro falhou -> %@", error.localizedDescription)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    NSLog("APNS-DIAG: registrado, %d bytes", deviceToken.count)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // O firebase_messaging chama `registerForRemoteNotifications` de dentro de
    // um observer de `UIApplicationDidFinishLaunchingNotification`, instalado
    // no momento em que o plugin é registrado. Com a API de engine implícita o
    // registro dos plugins acontece depois que essa notificação já foi postada,
    // então o observer nunca dispara e o app jamais se registra no APNs —
    // `getAPNSToken()` fica nulo para sempre e nenhum push chega.
    //
    // Disparamos aqui, logo após os plugins existirem, para o callback com o
    // device token encontrar o plugin já pronto para recebê-lo.
    NSLog("APNS-DIAG: plugins registrados, pedindo registro no APNs")
    DispatchQueue.main.async {
      NSLog("APNS-DIAG: chamando registerForRemoteNotifications")
      UIApplication.shared.registerForRemoteNotifications()
    }
  }
}
