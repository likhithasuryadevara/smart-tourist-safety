import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceSosRecognitionSession {
  Completer<void>? _stopped;
  bool _active = false;

  bool get isActive => _active;

  bool begin() {
    if (_active) return false;
    _active = true;
    _stopped = Completer<void>();
    return true;
  }

  void markStopped() {
    _active = false;
    final stopped = _stopped;
    if (stopped != null && !stopped.isCompleted) stopped.complete();
  }

  Future<bool> waitForStop({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final stopped = _stopped;
    if (stopped == null || stopped.isCompleted) return true;

    try {
      await stopped.future.timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }
}

class VoiceSosService {
  static const Duration listenDuration = Duration(seconds: 30);
  static const Duration pauseDuration = Duration(seconds: 10);
  static const Set<String> triggerPhrases = {
    'sos',
    's o s',
    'help',
    'help me',
    'emergency',
  };

  final stt.SpeechToText _speech = stt.SpeechToText();

  Timer? _sessionTimer;
  Timer? _sessionSettleTimer;
  Future<void> _releaseFuture = Future<void>.value();
  Completer<void>? _startCompletion;
  final VoiceSosRecognitionSession _recognitionSession =
      VoiceSosRecognitionSession();
  int _screenGeneration = 0;
  bool _initialized = false;
  bool _starting = false;
  bool _isListening = false;
  bool _triggerDetected = false;
  bool _sessionReachedListening = false;

  ValueChanged<bool>? _onListeningChanged;
  void Function(String transcript, bool isTrigger)? _onResult;
  ValueChanged<String>? _onError;
  ValueChanged<String>? _onTrigger;
  ValueChanged<String>? _onDiagnostic;
  VoidCallback? _onSessionEnded;

  static bool isSosTrigger(String recognizedText) {
    final normalized = recognizedText
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    return triggerPhrases.contains(normalized);
  }

  static bool hasActiveSos(Iterable<Map<String, dynamic>> sosRecords) =>
      sosRecords.any((record) => record['status'] == 'active');

  static bool shouldProcessRecognitionResult(String recognizedWords) =>
      recognizedWords.trim().isNotEmpty;

  bool shouldRetryAutomatically(String message) {
    final normalized = message.toLowerCase();
    return _initialized &&
        !normalized.contains('permission') &&
        !normalized.contains('denied') &&
        !normalized.contains('not supported') &&
        !normalized.contains('unavailable') &&
        !normalized.contains('microphone') &&
        !normalized.contains('audio');
  }

  bool get isSessionSettled =>
      !_recognitionSession.isActive && !_starting;

  Future<bool> startListening({
    required ValueChanged<bool> onListeningChanged,
    required void Function(String transcript, bool isTrigger) onResult,
    required ValueChanged<String> onError,
    required ValueChanged<String> onTrigger,
    required ValueChanged<String> onDiagnostic,
    required VoidCallback onSessionEnded,
  }) async {
    await _releaseFuture;
    if (_starting) {
      onError('Voice SOS is already starting. Please wait.');
      return false;
    }
    if (_speech.isListening || _recognitionSession.isActive) {
      _reportDiagnostic(
        'listen() prevented: previous recognition session has not settled',
      );
      return false;
    }
    if (_isListening) return true;

    final generation = _screenGeneration;
    _starting = true;
    final startCompletion = Completer<void>();
    _startCompletion = startCompletion;
    _onListeningChanged = onListeningChanged;
    _onResult = onResult;
    _onError = onError;
    _onTrigger = onTrigger;
    _onDiagnostic = onDiagnostic;
    _onSessionEnded = onSessionEnded;
    _triggerDetected = false;
    _sessionReachedListening = false;
    _sessionSettleTimer?.cancel();

    try {
      if (generation != _screenGeneration) return false;

      _reportDiagnostic('service initialization started');
      if (!_isSupportedPlatform) {
        _reportDiagnostic('Unavailable: unsupported platform');
        _onError?.call(
          'Voice SOS is not supported on this platform. Use Android, iOS, or Chrome.',
        );
        return false;
      }

      if (!_initialized) {
        final options =
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? <stt.SpeechConfigOption>[stt.SpeechToText.androidNoBluetooth]
            : null;
        _reportDiagnostic('speech_to_text initialize() called');
        _initialized = await _speech.initialize(
          onError: _handleSpeechError,
          onStatus: _handleSpeechStatus,
          options: options,
        );
        _reportDiagnostic(
          'initialize() ${_initialized ? 'succeeded' : 'failed'}; '
          'isAvailable=${_speech.isAvailable}',
        );
        _reportDiagnostic(
          _speech.isAvailable
              ? 'Speech recognition available'
              : 'Unavailable: speech recognition initialization failed',
        );
        if (generation != _screenGeneration) {
          if (_initialized) await _speech.cancel();
          return false;
        }
      }

      if (!_initialized) {
        final hasPermission = await _speech.hasPermission;
        _reportDiagnostic('initialize failed; hasPermission=$hasPermission');
        _reportDiagnostic('isAvailable=${_speech.isAvailable}');
        _onError?.call(
          hasPermission
              ? 'Speech recognition is unavailable. Check your device or browser support.'
              : 'Microphone permission is required for Voice SOS. Allow it in app or site settings, then reopen the dashboard to retry.',
        );
        return false;
      }

      final hasPermission = await _speech.hasPermission;
      _reportDiagnostic('hasPermission=$hasPermission');
      _reportDiagnostic(
        hasPermission
            ? kIsWeb
                  ? 'Microphone permission/support check granted by speech_to_text; '
                        'the browser authorizes microphone access when listen() starts'
                  : 'Microphone permission granted'
            : 'Microphone permission denied',
      );
      _reportDiagnostic('isAvailable=${_speech.isAvailable}');
      if (!hasPermission) {
        _onError?.call(
          'Microphone permission is required for Voice SOS. Allow it in app or site settings, then reopen the dashboard to retry.',
        );
        return false;
      }
      if (generation != _screenGeneration) {
        if (_initialized) await _speech.cancel();
        return false;
      }

      _reportDiagnostic('listen() called');
      _reportDiagnostic(
        'listen options: listenFor=${listenDuration.inSeconds}s, '
        'pauseFor=${pauseDuration.inSeconds}s, partialResults=true, '
        'cancelOnError=true, listenMode=dictation, localeId=en-US',
      );
      if (!_recognitionSession.begin()) {
        _reportDiagnostic(
          'listen() prevented: recognition session is already active',
        );
        return false;
      }
      await _speech.listen(
        onResult: _handleSpeechResult,
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
          listenFor: listenDuration,
          pauseFor: pauseDuration,
          listenMode: stt.ListenMode.dictation,
          localeId: 'en-US',
        ),
      );

      if (generation != _screenGeneration) {
        await _speech.cancel();
        return false;
      }

      _sessionTimer?.cancel();
      _sessionTimer = Timer(listenDuration + const Duration(seconds: 3), () {
        if (!_isListening) return;
        _reportDiagnostic('recognition session stopped: listen timeout');
        unawaited(_speech.cancel());
      });

      _setListening(true);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Voice SOS failed to start: $error\n$stackTrace');
      _reportDiagnostic(
        'listen/start failure: ${_friendlyError(error.toString())}',
      );
      _setListening(false);
      _recognitionSession.markStopped();
      _onError?.call(_friendlyError(error.toString()));
      return false;
    } finally {
      _starting = false;
      if (identical(_startCompletion, startCompletion)) {
        _startCompletion = null;
      }
      if (!startCompletion.isCompleted) startCompletion.complete();
    }
  }

  Future<void> detachScreen() {
    _screenGeneration++;
    final release = _releaseScreen();
    _releaseFuture = release;
    return release;
  }

  Future<void> _releaseScreen() async {
    final pendingStart = _startCompletion;
    if (pendingStart != null) await pendingStart.future;

    await cancelListening();
    _sessionSettleTimer?.cancel();
    _onListeningChanged = null;
    _onResult = null;
    _onError = null;
    _onTrigger = null;
    _onDiagnostic = null;
    _onSessionEnded = null;
  }

  Future<void> cancelListening() async {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _sessionSettleTimer?.cancel();
    try {
      if (_initialized && _speech.isListening) {
        await _speech.cancel();
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to stop Voice SOS listening: $error\n$stackTrace');
      _onError?.call('Voice SOS could not stop listening. Please try again.');
    } finally {
      _setListening(false);
    }
  }

  Future<bool> waitForSessionToStop({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (_recognitionSession.isActive) {
      _reportDiagnostic('waiting for current recognition session to settle');
      final stopped = await _recognitionSession.waitForStop(timeout: timeout);
      if (!stopped) {
        _reportDiagnostic('recognition session did not settle before timeout');
        return false;
      }
    }

    final isStopped =
        !_speech.isListening &&
        !_recognitionSession.isActive &&
        !_sessionReachedListening &&
        !_starting;
    _reportDiagnostic(
      isStopped
          ? 'recognition session confirmed stopped'
          : 'recognition session is still active; restart withheld',
    );
    return isStopped;
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    final transcript = result.recognizedWords.trim();
    final isFinal = result.finalResult;
    _reportDiagnostic(
      'RESULT\nwords=$transcript\nfinal=$isFinal\n'
      'resultType=${result.resultTypeValue.name}',
    );
    if (isFinal) _reportDiagnostic('recognized final result received');
    if (!shouldProcessRecognitionResult(transcript) || _triggerDetected) return;

    final isTrigger = isSosTrigger(transcript);
    _reportDiagnostic(
      'recognized words="$transcript"; trigger match=$isTrigger',
    );
    _onResult?.call(transcript, isTrigger);
    if (isTrigger) {
      _triggerDetected = true;
      unawaited(_finishTrigger(transcript));
    }
  }

  Future<void> _finishTrigger(String transcript) async {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (error, stackTrace) {
      debugPrint('Unable to stop after Voice SOS trigger: $error\n$stackTrace');
    }
    _setListening(false);
    _reportDiagnostic(
      'recognition session stopped after trigger "$transcript"',
    );
    _onTrigger?.call(transcript);
  }

  void _handleSpeechStatus(String status) {
    _reportDiagnostic('recognition status callback: $status');
    if (status == stt.SpeechToText.listeningStatus) {
      _reportDiagnostic('listening status received');
      _sessionReachedListening = true;
      _setListening(true);
    } else if (status == stt.SpeechToText.notListeningStatus) {
      _reportDiagnostic(
        'browser recognition ended; waiting for the adapter to settle',
      );
      _sessionTimer?.cancel();
      _sessionTimer = null;
      _setListening(false);
      _sessionSettleTimer?.cancel();
      _sessionSettleTimer = Timer(const Duration(milliseconds: 400), () {
        if (_speech.isListening) {
          _reportDiagnostic(
            'recognizer still active after end status; waiting for terminal status',
          );
          return;
        }
        _finishRecognitionSession();
      });
    } else if (status == stt.SpeechToText.doneStatus) {
      _reportDiagnostic('recognition adapter reported terminal done status');
      _sessionTimer?.cancel();
      _sessionTimer = null;
      _sessionSettleTimer?.cancel();
      _finishRecognitionSession();
    }
  }

  void _finishRecognitionSession() {
    final wasActive = _sessionReachedListening || _isListening;
    _sessionReachedListening = false;
    _setListening(false);
    _recognitionSession.markStopped();
    if (!wasActive) return;

    _reportDiagnostic('recognition session fully settled');
    if (!_triggerDetected) _onSessionEnded?.call();
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    debugPrint('Voice SOS recognition error: ${error.errorMsg}');
    _reportDiagnostic('recognition error callback: ${error.errorMsg}');
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _setListening(false);
    _onError?.call(_friendlyError(error.errorMsg));
  }

  void _setListening(bool listening) {
    if (_isListening == listening) return;
    _isListening = listening;
    _onListeningChanged?.call(listening);
  }

  void _reportDiagnostic(String message) {
    final status = 'Voice SOS: $message';
    debugPrint(status);
    _onDiagnostic?.call(status);
  }

  String _friendlyError(String error) {
    final normalized = error.toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('denied') ||
        normalized.contains('not-allowed')) {
      return 'Microphone permission is required for Voice SOS. Allow it in app or site settings, then reopen the dashboard to retry.';
    }
    if (normalized.contains('network')) {
      return 'Voice recognition needs an internet connection. Check your connection and try again.';
    }
    if (normalized.contains('no_match') ||
        normalized.contains('no speech') ||
        normalized.contains('speech_timeout') ||
        normalized.contains('timeout')) {
      return 'No speech was recognized. Voice SOS monitoring will resume automatically.';
    }
    if (normalized.contains('audio') ||
        normalized.contains('microphone') ||
        normalized.contains('busy')) {
      return 'The microphone is unavailable. Check that it is connected and not being used by another app.';
    }
    if (normalized.contains('not supported') ||
        normalized.contains('unavailable') ||
        normalized.contains('recognizer')) {
      return 'Speech recognition is unavailable. Use a supported device or browser.';
    }
    return 'Voice recognition encountered a problem. Voice SOS monitoring will retry automatically.';
  }

  bool get _isSupportedPlatform =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
