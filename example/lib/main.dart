import 'package:flutter/material.dart';
import 'package:arabic_tts_reader/arabic_tts_reader.dart';

void main() {
  // Optional: Initialize with custom settings
  ArabicTTSReader.initialize(
    tokenUrl: 'http://localhost:8080/token',
    enableLogging: true,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const String arabicStory = 
      'وَٱلتِّينِ وَٱلزَّيۡتُونِ، وَطُورِ سِينِينَ، وَهَٰذَا ٱلۡبَلَدِ ٱلۡأَمِينِ، لَقَدْ خَلَقۡنَا ٱلۡإِنسَٰنَ فِيٓ أَحۡسَنِ تَقۡوِيمٖ، ثُمَّ رَدَدۡنَٰهُ أَسۡفَلَ سَٰفِلِينَ، إِلَّا ٱلَّذِينَ ءَامَنُواْ وَعَمِلُواْ ٱلصَّٰلِحَٰتِ فَلَهُمۡ أَجۡرٌ غَيۡرُ مَمۡنُونٖ، فَمَا يُكَذِّبُكَ بَعۡدُ بِٱلدِّينِ؟ أَلَيۡسَ ٱللَّهُ بِأَحۡكَمِ ٱلۡحَٰكِمِينَ؟';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                arabicStory,
                style: const TextStyle(
                  fontSize: 28,
                  height: 2.0,
                  fontFamily: 'Arial',
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ).wrapWithTTS(),
            ],
          ),
        ),
      ),
    );
  }
}

// Extension to make any Text widget TTS-enabled
extension TTSTextExtension on Text {
  Widget wrapWithTTS() => ReadingText(child: this);
}