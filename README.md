# Arabic TTS Reader

A Flutter package for creating TTS reading exercises using OpenAI's streaming TTS API and LiveKit for web-compatible audio delivery.

## Features

- 🎯 **Simple API**: Just wrap any Text widget with `.wrapWithTTS()` 
- 🌐 **Web Compatible**: Uses LiveKit WebRTC for reliable audio streaming
- 🎤 **High Quality**: Uses OpenAI's latest `gpt-4o-mini-tts` model
- 📝 **Word Selection**: Click any word to hear its pronunciation
- 🔧 **Zero Configuration**: All settings handled internally

## Quick Start

### 1. Set up the Server

Create a `.env` file:
```env
OPENAI_API_KEY=your_openai_api_key
LIVEKIT_API_KEY=your_livekit_api_key
LIVEKIT_API_SECRET=your_livekit_api_secret
LIVEKIT_URL=wss://cloud.livekit.io
```

Install Python dependencies:
```bash
cd server
pip install -r requirements.txt
```

Run both servers:
```bash
# Terminal 1 - Token Server
python token_server.py

# Terminal 2 - TTS Agent
python tts_agent.py dev
```

### 2. Use in Flutter

Add to `pubspec.yaml`:
```yaml
dependencies:
  arabic_tts_reader: ^0.1.0
```

Minimal example:
```dart
import 'package:flutter/material.dart';
import 'package:arabic_tts_reader/arabic_tts_reader.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'مرحبا بالعالم',
            style: TextStyle(fontSize: 28),
          ).wrapWithTTS(), // That's it!
        ),
      ),
    );
  }
}
```

## How It Works

1. **Click Detection**: The package wraps your Text widget and makes each word clickable
2. **LiveKit Connection**: Establishes a WebRTC connection to the TTS agent
3. **OpenAI TTS**: The agent uses OpenAI's streaming API to generate speech
4. **Audio Delivery**: Audio streams back through LiveKit with low latency

## Configuration (Optional)

Initialize with custom settings:
```dart
void main() {
  ArabicTTSReader.initialize(
    tokenUrl: 'https://your-server.com/token',
    enableLogging: true,
  );
  runApp(MyApp());
}
```

## Running on Web

For local development:
```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

For production, ensure:
- Token server uses HTTPS
- CORS is properly configured
- Valid SSL certificates

## Architecture

```
Flutter App (Web)
    ↓
LiveKit WebRTC Connection
    ↓
Python TTS Agent
    ↓
OpenAI TTS API
```

## Requirements

- Flutter 3.10+
- OpenAI API key with TTS access
- LiveKit Cloud account or self-hosted server
- Python 3.8+ for server components

## Example Arabic Story

The example includes a traditional Arabic story that demonstrates:
- Proper RTL text rendering
- Word-by-word TTS capability
- Clean, minimal UI

## Troubleshooting

1. **No Audio**: Check browser console for WebRTC errors
2. **Connection Failed**: Verify LiveKit credentials
3. **Slow Response**: Ensure good network connection to OpenAI

## License

MIT