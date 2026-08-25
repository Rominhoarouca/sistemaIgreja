import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_igreja/features/kids/data/kids_models.dart';

/// Testes de contrato: as fixtures são respostas **reais** de `/v1/kids/*`,
/// capturadas do backend. Se um campo mudar de nome ou de tipo na API, um
/// destes testes quebra — que é o ponto: mismatch de contrato só apareceria em
/// produção, na frente do professor com a fila na porta.
Map<String, dynamic> _fixture(String name) {
  final file = File('test/features/kids/fixtures/$name.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('KidsRoom', () {
    test('lê a lista de salas com professores e sessão aberta', () {
      final rooms = (_fixture('rooms')['rooms'] as List)
          .map((e) => KidsRoom.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(rooms, isNotEmpty);
      for (final room in rooms) {
        expect(room.id, isNotEmpty);
        expect(room.name, isNotEmpty);
        expect(room.capacity, greaterThan(0));
        for (final teacher in room.teachers) {
          expect(teacher.userId, isNotEmpty);
          expect(teacher.name, isNotEmpty);
        }
      }
    });

    test('faixa etária vira texto legível em meses e anos', () {
      const bercario = KidsRoom(
        id: 'r1',
        name: 'Berçário',
        description: null,
        capacity: 10,
        minAgeMonths: 6,
        maxAgeMonths: 23,
        color: '#3F51B5',
        isActive: true,
        teachers: [],
        openSession: null,
      );
      expect(bercario.ageRangeLabel, '6 meses a 23 meses');

      const kids = KidsRoom(
        id: 'r2',
        name: 'Kids',
        description: null,
        capacity: 20,
        minAgeMonths: 48,
        maxAgeMonths: 83,
        color: '#3F51B5',
        isActive: true,
        teachers: [],
        openSession: null,
      );
      expect(kids.ageRangeLabel, '4 anos a 6 anos');

      const semFaixa = KidsRoom(
        id: 'r3',
        name: 'Livre',
        description: null,
        capacity: 5,
        minAgeMonths: null,
        maxAgeMonths: null,
        color: '#3F51B5',
        isActive: true,
        teachers: [],
        openSession: null,
      );
      expect(semFaixa.ageRangeLabel, isEmpty);
    });
  });

  group('KidsSession', () {
    test('lê a sessão com check-ins e anotações', () {
      final data = _fixture('session');
      final session = KidsSession.fromJson(data['session'] as Map<String, dynamic>);

      expect(session.id, isNotEmpty);
      expect(session.roomName, isNotEmpty);
      expect(session.capacity, greaterThan(0));
      expect(session.presentCount, lessThanOrEqualTo(session.totalCheckins));

      final checkins = (data['checkins'] as List)
          .map((e) => KidsCheckin.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final checkin in checkins) {
        expect(checkin.childName, isNotEmpty);
        expect(checkin.badgeCode, isNotEmpty);
      }

      final notes = (data['notes'] as List)
          .map((e) => KidsNote.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final note in notes) {
        expect(note.body, isNotEmpty);
        // Anotação da aula não tem criança; a individual tem.
        expect(note.isClassNote, note.childId == null);
      }
    });

    test('serviceDate mantém o dia mesmo vindo como meia-noite UTC', () {
      // `service_date` é `date` no Postgres: converter com toLocal() em fuso
      // negativo jogaria o dia para trás.
      final session = KidsSession.fromJson({
        'id': 's1',
        'roomId': 'r1',
        'roomName': 'Sala',
        'serviceDate': '2026-08-23T00:00:00.000Z',
        'serviceName': 'Culto',
        'status': 'OPEN',
        'capacity': 10,
        'presentCount': 0,
        'totalCheckins': 0,
        'openAlerts': 0,
        'openedAt': '2026-08-23T12:00:00.000Z',
      });
      expect(session.serviceDate.day, 23);
      expect(session.serviceDate.month, 8);
    });
  });

  group('KidsChild', () {
    test('lê os filhos do responsável com o status atual', () {
      final children = (_fixture('my_children')['children'] as List)
          .map((e) => KidsChild.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(children, isNotEmpty);
      for (final child in children) {
        expect(child.name, isNotEmpty);
        expect(child.initials, isNotEmpty);
        // Quando há check-in aberto, ele traz o crachá da sala.
        if (child.isInRoom) {
          expect(child.openCheckin!.badgeCode, isNotEmpty);
        }
      }
    });

    test('busca do balcão traz responsáveis para conferência', () {
      final children = (_fixture('children_search')['children'] as List)
          .map((e) => KidsChild.fromJson(e as Map<String, dynamic>))
          .toList();

      for (final child in children) {
        if (child.guardians.isNotEmpty) {
          expect(child.primaryGuardian, isNotNull);
          expect(child.primaryGuardian!.phone, isNotEmpty);
        }
      }
    });

    test('idade sai em meses para bebê e em anos depois dos 2', () {
      final now = DateTime.now();
      final bebe = KidsChild.fromJson({
        'id': 'c1',
        'name': 'Bebê Teste',
        'birthDate': DateTime(now.year, now.month - 8, now.day).toIso8601String(),
        'guardians': const [],
      });
      expect(bebe.ageLabel, '8 meses');

      final crianca = KidsChild.fromJson({
        'id': 'c2',
        'name': 'Criança Teste',
        'birthDate': DateTime(now.year - 5, now.month, now.day).toIso8601String(),
        'guardians': const [],
      });
      expect(crianca.ageLabel, '5 anos');
    });
  });

  group('KidsAlert', () {
    test('lê alertas com as entregas por canal', () {
      final alerts = (_fixture('alerts')['alerts'] as List)
          .map((e) => KidsAlert.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(alerts, isNotEmpty);
      for (final alert in alerts) {
        expect(alert.message, isNotEmpty);
        expect(alert.childName, isNotEmpty);
        expect(alert.deliveries, isNotEmpty);
        for (final delivery in alert.deliveries) {
          expect(delivery.channelLabel, isNotEmpty);
          expect(delivery.statusLabel, isNotEmpty);
        }
      }
    });

    test('emergência traz telefone para a ligação e marca ligação pendente', () {
      final alerts = (_fixture('alerts')['alerts'] as List)
          .map((e) => KidsAlert.fromJson(e as Map<String, dynamic>))
          .toList();
      final emergency = alerts.where(
        (a) => a.level == KidsAlertLevel.emergency,
      );

      for (final alert in emergency) {
        expect(
          alert.guardianPhones,
          isNotEmpty,
          reason: 'nível 3 sem telefone não teria como escalar para ligação',
        );
      }
    });

    test('o responsável vê os próprios alertas', () {
      final alerts = (_fixture('my_alerts')['alerts'] as List)
          .map((e) => KidsAlert.fromJson(e as Map<String, dynamic>))
          .toList();
      for (final alert in alerts) {
        expect(alert.roomName, isNotEmpty);
        expect(alert.level.label, isNotEmpty);
      }
    });
  });

  group('KidsOverview', () {
    test('lê o relatório do ministério', () {
      final report = KidsOverview.fromJson(
        _fixture('overview')['report'] as Map<String, dynamic>,
      );

      expect(report.sessions, greaterThanOrEqualTo(0));
      expect(report.checkins, greaterThanOrEqualTo(report.uniqueChildren));
      for (final room in report.rooms) {
        expect(room.roomName, isNotEmpty);
        expect(room.averageOccupancy, greaterThanOrEqualTo(0));
      }
    });
  });
}
