/// Implementação vazia para iOS/Android.
///
/// Nessas plataformas quem desenha a notificação em primeiro plano é o
/// `flutter_local_notifications`. Este arquivo existe só para o import
/// condicional resolver fora da web — `package:web` não compila em mobile.
Future<void> showWebNotification({
  required String title,
  required String body,
  required String level,
  required Map<String, String> data,
}) async {}
