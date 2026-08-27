// Service worker do FCM na web. O nome do arquivo é fixo — o
// firebase_messaging procura exatamente por ele na raiz.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCBQcsuRElCLITPP3EIRAkwVZQq5QrKjZw',
  authDomain: 'multiplicado-a36cf.firebaseapp.com',
  projectId: 'multiplicado-a36cf',
  storageBucket: 'multiplicado-a36cf.firebasestorage.app',
  messagingSenderId: '390130821317',
  appId: '1:390130821317:web:5affa4e33920f8a73968ac',
  measurementId: 'G-7T6569MQNR',
});

const messaging = firebase.messaging();

// Estilo por urgência, espelhando os canais do Android. A web não tem canal
// nem som próprio: o que dá para controlar é imagem, vibração e se a
// notificação some sozinha.
function estiloPara(level) {
  if (level === 'EMERGENCY') {
    return {
      icon: '/icons/Icon-192.png',
      image: '/assets/assets/images/notif_emergencia.png',
      vibrate: [900, 300, 900, 300, 900, 300, 900],
      // Emergência espera ser tocada; some sozinha seria perdê-la.
      requireInteraction: true,
      tag: 'kids-emergencia',
    };
  }
  if (level === 'URGENT') {
    return {
      icon: '/icons/Icon-192.png',
      image: '/assets/assets/images/notif_urgente.png',
      vibrate: [500, 250, 500],
      requireInteraction: true,
      tag: 'kids-urgente',
    };
  }
  return { icon: '/icons/Icon-192.png', tag: 'aviso' };
}

// Com a aba fechada ou em segundo plano quem desenha é o service worker.
messaging.onBackgroundMessage((payload) => {
  const n = payload.notification || {};
  const d = payload.data || {};
  self.registration.showNotification(n.title || 'Multiplicado', {
    body: n.body || '',
    data: d,
    ...estiloPara(d.level),
  });
});

// Toque na notificação: reaproveita uma aba aberta em vez de abrir outra, e
// leva à tela que resolve o assunto.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const d = event.notification.data || {};
  const destino =
    d.type === 'kids_ack' && d.sessionId
      ? `/kids/sessions/${d.sessionId}`
      : d.type === 'kids_alert'
        ? '/meus-filhos/alertas'
        : '/notifications';

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((abas) => {
        for (const aba of abas) {
          if ('focus' in aba) {
            aba.navigate(new URL(destino, self.location.origin).href);
            return aba.focus();
          }
        }
        return self.clients.openWindow(destino);
      }),
  );
});
