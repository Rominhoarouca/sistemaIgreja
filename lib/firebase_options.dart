// Opções do Firebase por plataforma (projeto `multiplicado-a36cf`).
//
// Equivalente ao que o `flutterfire configure` gera. Os valores vêm de
// `ios/Runner/GoogleService-Info.plist`, `android/app/google-services.json` e
// da configuração web do console.
//
// As chaves aqui não são segredo: as `apiKey` do Firebase são identificadores
// públicos do projeto, embarcados em todo app cliente. O que protege o backend
// são as Security Rules e as restrições de origem/app na chave — não escondê-la.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        // O app macOS usa o mesmo bundle id do iOS; se ganhar um registro
        // próprio no console, troque aqui.
        return ios;
      default:
        throw UnsupportedError(
          'Firebase não configurado para $defaultTargetPlatform. '
          'Rode `flutterfire configure` para adicionar a plataforma.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCBQcsuRElCLITPP3EIRAkwVZQq5QrKjZw',
    appId: '1:390130821317:web:5affa4e33920f8a73968ac',
    messagingSenderId: '390130821317',
    projectId: 'multiplicado-a36cf',
    authDomain: 'multiplicado-a36cf.firebaseapp.com',
    storageBucket: 'multiplicado-a36cf.firebasestorage.app',
    measurementId: 'G-7T6569MQNR',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB_rspDmdShfYZammSmWGPZaehMiptPWXo',
    appId: '1:390130821317:android:afdf37f8376e854a3968ac',
    messagingSenderId: '390130821317',
    projectId: 'multiplicado-a36cf',
    storageBucket: 'multiplicado-a36cf.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD_NCZT2en9ws-ixkVTSpBrefaaTyxzyMg',
    appId: '1:390130821317:ios:d763bda4e732035a3968ac',
    messagingSenderId: '390130821317',
    projectId: 'multiplicado-a36cf',
    storageBucket: 'multiplicado-a36cf.firebasestorage.app',
    iosBundleId: 'br.com.multiplicado',
  );
}
