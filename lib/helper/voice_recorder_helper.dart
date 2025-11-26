// lib/helper/voice_recorder_helper.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

/// Simple value object for a finished recording.
class RecordedAudio {
  final String filePath;
  final int durationSeconds;

  const RecordedAudio({
    required this.filePath,
    required this.durationSeconds,
  });
}

/// Controller that encapsulates all voice recording logic:
/// - microphone permission
/// - recorder lifecycle
/// - elapsed time tracking
///
/// It does NOT upload or send messages – the calling page handles that.
///
/// Usage:
///   final _recorder = VoiceRecorderController(
///     debugTag: 'DM',
///     onTick: () => setState(() {}),
///   );
///
///   await _recorder.start();
///   final recorded = await _recorder.stop();
class VoiceRecorderController {
  final String debugTag;
  final VoidCallback? onTick;

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  Timer? _timer;
  bool _initialized = false;
  bool _isRecording = false;
  int _seconds = 0;

  VoiceRecorderController({
    this.debugTag = 'Recorder',
    this.onTick,
  });

  bool get isRecording => _isRecording;
  int get durationSeconds => _seconds;

  String get formattedDuration {
    final m = (durationSeconds ~/ 60).toString();
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('Microphone permission not granted ($debugTag)');
      return;
    }

    await _recorder.openRecorder();
    _initialized = true;
    debugPrint('🎙 $debugTag recorder initialized');
  }

  Future<bool> start() async {
    await _ensureInitialized();
    if (!_initialized) return false;
    if (_isRecording) return false;

    try {
      final fileName =
          'voice_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _recorder.startRecorder(
        toFile: fileName,
        codec: Codec.aacADTS,
        numChannels: 1,
        sampleRate: 16000,
      );

      _isRecording = true;
      _seconds = 0;

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _seconds++;
        if (onTick != null) {
          onTick!();
        }
      });

      debugPrint('🎙 $debugTag started recording: $fileName');
      return true;
    } catch (e) {
      debugPrint('Error starting $debugTag recording: $e');
      return false;
    }
  }

  Future<RecordedAudio?> stop() async {
    if (!_isRecording) return null;

    _timer?.cancel();
    _timer = null;

    String? path;
    try {
      path = await _recorder.stopRecorder();
      debugPrint('🎙 $debugTag stopped recording. Path: $path');
    } catch (e) {
      debugPrint('Error stopping $debugTag recorder: $e');
    }

    _isRecording = false;

    if (path == null) return null;
    if (_seconds < 1) {
      debugPrint('$debugTag voice message too short (<1s), not returning.');
      return null;
    }

    return RecordedAudio(
      filePath: path,
      durationSeconds: _seconds,
    );
  }

  Future<void> dispose() async {
    _timer?.cancel();
    try {
      await _recorder.closeRecorder();
    } catch (_) {
      // ignore
    }
  }
}
