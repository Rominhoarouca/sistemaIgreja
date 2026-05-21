import 'package:equatable/equatable.dart';

/// Domain entity — Spiritual Development History
class SpiritualHistoryEntity extends Equatable {
  const SpiritualHistoryEntity({
    required this.id,
    required this.visitorId,
    required this.eventType,
    required this.eventDate,
    this.notes,
  });

  final String id;
  final String visitorId;
  final SpiritualEventType eventType;
  final DateTime eventDate;
  final String? notes;

  @override
  List<Object?> get props => [id];
}

enum SpiritualEventType {
  sentToBaptism,
  baptized,
  sentToLeaderTraining,
  completedTraining,
  becameLeader;

  static SpiritualEventType fromString(String v) => switch (v.toLowerCase()) {
    'enviado_para_batismo' => sentToBaptism,
    'batizado' => baptized,
    'enviado_treinamento' => sentToLeaderTraining,
    'concluiu_treinamento' => completedTraining,
    'tornou_se_lider' => becameLeader,
    _ => sentToBaptism,
  };

  String get value => switch (this) {
    SpiritualEventType.sentToBaptism => 'enviado_para_batismo',
    SpiritualEventType.baptized => 'batizado',
    SpiritualEventType.sentToLeaderTraining => 'enviado_treinamento',
    SpiritualEventType.completedTraining => 'concluiu_treinamento',
    SpiritualEventType.becameLeader => 'tornou_se_lider',
  };

  String get label => switch (this) {
    SpiritualEventType.sentToBaptism => 'Enviado para batismo',
    SpiritualEventType.baptized => 'Batizado',
    SpiritualEventType.sentToLeaderTraining =>
      'Enviado para treinamento de líderes',
    SpiritualEventType.completedTraining => 'Concluiu treinamento',
    SpiritualEventType.becameLeader => 'Tornou-se líder',
  };
}
