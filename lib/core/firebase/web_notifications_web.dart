import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Notificação em primeiro plano na web.
///
/// Com a aba em foco o FCM não desenha nada — nem o navegador, nem o service
/// worker: a mensagem chega ao `onMessage` do Dart e para ali. É o mesmo buraco
/// que o `flutter_local_notifications` cobre no Android, e aqui quem cobre é a
/// Notification API.
///
/// Vai pelo registro do service worker, e não por `new Notification(...)`:
/// só o registro aceita `image`, `vibrate` e `requireInteraction`, e é ele que
/// entrega o clique ao `notificationclick` do `firebase-messaging-sw.js` —
/// assim o toque leva à mesma tela, com a aba em foco ou não.
Future<void> showWebNotification({
  required String title,
  required String body,
  required String level,
  required Map<String, String> data,
}) async {
  try {
    if (web.Notification.permission != 'granted') return;

    final registro = await web.window.navigator.serviceWorker.ready.toDart;

    final opcoes = <String, Object?>{
      'body': body,
      'icon': '/icons/Icon-192.png',
      'data': data,
      ..._estilo(level),
    };

    (registro as JSObject).callMethod<JSAny?>(
      'showNotification'.toJS,
      title.toJS,
      opcoes.jsify(),
    );
  } catch (e) {
    debugPrint('WebNotifications: exibição falhou ($e)');
  }
}

/// Espelha os canais do Android. A web não tem som próprio nem canal; o que dá
/// para controlar é imagem, vibração e se a notificação some sozinha.
Map<String, Object?> _estilo(String level) => switch (level) {
  'EMERGENCY' => {
    'image': '/assets/assets/images/notif_emergencia.png',
    'vibrate': [900, 300, 900, 300, 900, 300, 900],
    'requireInteraction': true,
    'tag': 'kids-emergencia',
  },
  'URGENT' => {
    'image': '/assets/assets/images/notif_urgente.png',
    'vibrate': [500, 250, 500],
    'requireInteraction': true,
    'tag': 'kids-urgente',
  },
  _ => {'tag': 'aviso'},
};
