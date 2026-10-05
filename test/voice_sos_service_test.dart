import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tourist_safety/services/voice_sos_service.dart';

void main() {
  group('VoiceSosService.isSosTrigger', () {
    test('waits for the prior recognition session before restarting', () async {
      final session = VoiceSosRecognitionSession();

      expect(session.begin(), isTrue);
      expect(session.begin(), isFalse);

      final stopped = session.waitForStop();
      session.markStopped();
      expect(await stopped, isTrue);

      expect(session.begin(), isTrue);
      expect(session.isActive, isTrue);
      expect(VoiceSosService.isSosTrigger('SOS'), isTrue);
      session.markStopped();
      expect(session.begin(), isTrue);
      expect(VoiceSosService.isSosTrigger('S O S'), isTrue);
    });

    test('uses a long single recognition session for browser speech', () {
      expect(VoiceSosService.listenDuration, const Duration(seconds: 30));
      expect(VoiceSosService.pauseDuration, const Duration(seconds: 10));
    });

    test('processes non-empty browser interim results', () {
      expect(VoiceSosService.shouldProcessRecognitionResult('SOS'), isTrue);
      expect(VoiceSosService.shouldProcessRecognitionResult(''), isFalse);
    });

    test('accepts the configured emergency phrases', () {
      for (final phrase in [
        'SOS',
        'sos',
        'S O S',
        'S.O.S.',
        'help',
        'help me',
        'emergency',
      ]) {
        expect(VoiceSosService.isSosTrigger(phrase), isTrue, reason: phrase);
      }
    });

    test('does not trigger on unrelated sentences containing a phrase', () {
      for (final phrase in [
        'I need help',
        'say SOS',
        'emergency services',
        'I heard someone say help me',
      ]) {
        expect(VoiceSosService.isSosTrigger(phrase), isFalse, reason: phrase);
      }
    });

    test('detects active SOS records without blocking resolved records', () {
      expect(
        VoiceSosService.hasActiveSos([
          {'status': 'resolved'},
          {'status': 'active'},
        ]),
        isTrue,
      );
      expect(
        VoiceSosService.hasActiveSos([
          {'status': 'resolved'},
          {'status': 'acknowledged'},
        ]),
        isFalse,
      );
      expect(VoiceSosService.hasActiveSos([]), isFalse);
    });
  });
}
