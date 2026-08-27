/// Exibição de notificação em primeiro plano na web.
///
/// O import condicional evita que `package:web` entre no build de iOS/Android,
/// onde ele não compila.
library;
export 'web_notifications_stub.dart'
    if (dart.library.js_interop) 'web_notifications_web.dart';
