import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../arabic_tts_reader.dart';
import 'livekit_audio_manager.dart';
import 'models/tts_config.dart';
import 'utils/logger.dart';

class TTSService {
  late final LiveKitAudioManager _audioManager;
  bool _isInitialized = false;
  
  TTSService() {
    _audioManager = LiveKitAudioManager();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      TTSLogger.info('Initializing TTS service');
      await _audioManager.initialize();
      _isInitialized = true;
      TTSLogger.info('TTS service initialized successfully');
    } catch (e) {
      TTSLogger.error('Failed to initialize TTS service', e);
      rethrow;
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    TTSLogger.info('Speaking text: ${text.substring(0, text.length.clamp(0, 50))}...');
    
    try {
      // Request TTS from our Python agent via LiveKit
      await _audioManager.requestTTS(text);
      
      // Wait for audio to complete
      await _audioManager.waitForCompletion();
      
      TTSLogger.info('TTS completed successfully');
    } catch (e) {
      TTSLogger.error('Failed to speak text', e);
      rethrow;
    }
  }

  void dispose() {
    _audioManager.dispose();
    _isInitialized = false;
  }
}