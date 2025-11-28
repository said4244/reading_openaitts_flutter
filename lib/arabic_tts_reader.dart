library arabic_tts_reader;

export 'src/widgets/reading_text.dart';
export 'src/models/tts_config.dart' show TTSVoice;

// Initialize the package
class ArabicTTSReader {
  static void initialize({
    String tokenUrl = 'http://localhost:8080/token',
    bool enableLogging = false,
  }) {
    _tokenUrl = tokenUrl;
    _enableLogging = enableLogging;
  }

  static String _tokenUrl = 'http://localhost:8080/token';
  static bool _enableLogging = false;

  static String get tokenUrl => _tokenUrl;
  static bool get enableLogging => _enableLogging;
}