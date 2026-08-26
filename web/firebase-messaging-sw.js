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

firebase.messaging();
