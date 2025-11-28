import 'package:logger/logger.dart';
import '../../arabic_tts_reader.dart';

class TTSLogger {
  static final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  static void info(String message) {
    if (ArabicTTSReader.enableLogging) {
      _logger.i('[TTS] $message');
    }
  }

  static void debug(String message) {
    if (ArabicTTSReader.enableLogging) {
      _logger.d('[TTS] $message');
    }
  }

  static void warning(String message) {
    if (ArabicTTSReader.enableLogging) {
      _logger.w('[TTS] $message');
    }
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (ArabicTTSReader.enableLogging) {
      _logger.e('[TTS] $message', error: error, stackTrace: stackTrace);
    }
  }
}