import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Foto de perfil já reduzida, pronta para upload.
class ProfilePhoto {
  const ProfilePhoto({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;

  int get sizeKb => (bytes.lengthInBytes / 1024).ceil();
}

/// Lado maior da imagem depois da redução.
///
/// Foto de perfil aparece no app como avatar (no máximo ~112px) e na ficha.
/// 720px cobre telas de alta densidade com folga e derruba uma foto de câmera
/// de vários MB para dezenas de KB — o `image_picker` faz o resize no
/// decoder nativo, então nada do arquivo original chega a trafegar.
const double _kMaxPhotoSide = 720;

/// Qualidade JPEG. 75 é o ponto em que o arquivo cai bastante sem artefato
/// visível no tamanho em que a foto é exibida.
const int _kPhotoQuality = 75;

/// Lado maior da foto do encontro.
///
/// Maior que o do avatar porque essa foto é aberta em tela cheia e entra na
/// montagem do álbum. Ainda assim reduz uma foto de câmera de vários MB para
/// algumas centenas de KB — o suficiente para não esbarrar no limite de corpo
/// do nginx nem penalizar o líder que sobe pelo 4G.
const double kMeetingPhotoMaxSide = 1600;
const int kMeetingPhotoQuality = 80;

/// Pergunta câmera ou galeria e devolve a imagem já reduzida.
/// `null` quando o usuário desiste.
Future<ProfilePhoto?> pickProfilePhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Câmera'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galeria'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;

  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: _kMaxPhotoSide,
    maxHeight: _kMaxPhotoSide,
    imageQuality: _kPhotoQuality,
  );
  if (picked == null) return null;

  // readAsBytes funciona em nativo e web; File(path) só em nativo.
  final bytes = await picked.readAsBytes();
  return ProfilePhoto(bytes: bytes, filename: picked.name);
}
